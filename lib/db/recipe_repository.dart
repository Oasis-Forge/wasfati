import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/cookbook.dart';
import '../models/library.dart';
import '../models/quantity/arabic_text.dart';
import '../models/quantity/convert.dart';
import '../models/recipe.dart';
import '../models/sample_recipe.dart';
import '../services/ids.dart';

/// A recipe row for lists and search, without its sections.
class RecipeSummary {
  const RecipeSummary({
    required this.id,
    required this.title,
    this.photoPath,
    required this.sourceType,
    this.totalMinutes,
    required this.cookedCount,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? photoPath;
  final SourceType sourceType;
  final int? totalMinutes;
  final int cookedCount;
  final DateTime createdAt;
}

/// Reads and writes recipes. Every save is one transaction, so a recipe is
/// never half written (reliable writes).
class RecipeRepository {
  RecipeRepository(this._db, {Clock? clock, IdSource? ids})
    : _clock = clock ?? systemClock,
      _ids = ids ?? uuidV4;

  final Database _db;
  final Clock _clock;
  final IdSource _ids;

  static const trashDays = 30; // DEL-2

  /// The database, for the other states that keep rows in it (settings).
  Database get db => _db;

  String newId() => _ids();
  DateTime now() => _clock();

  /// Inserts or updates [recipe] with its sections, lines and steps. Rows no
  /// longer in the recipe are soft-deleted (DEL-1), so a backup merge still
  /// sees the deletion (BAK-3). Returns the recipe as saved.
  Future<Recipe> save(Recipe recipe) async {
    final problem = recipe.validate();
    if (problem != null) {
      throw ArgumentError.value(recipe.id, 'recipe', 'invalid $problem');
    }
    final now = _clock();
    final saved = recipe.copyWith(updatedAt: now);
    await _db.transaction((tx) async {
      await _upsert(tx, 'recipes', saved.toMap());
      final keepSections = <String>{};
      final keepLines = <String>{};
      final keepSteps = <String>{};

      for (final (i, s) in saved.ingredients.indexed) {
        keepSections.add(s.id);
        await _upsertChild(tx, 'sections', s.id, now, {
          'recipe_id': saved.id,
          'kind': 'ingredients',
          'position': i,
          'name': s.name,
        });
        for (final (j, line) in s.items.indexed) {
          keepLines.add(line.id);
          await _upsertChild(tx, 'ingredient_lines', line.id, now, {
            ...line.toMap()..remove('id'),
            'recipe_id': saved.id,
            'section_id': s.id,
            'position': j,
          });
        }
      }
      for (final (i, s) in saved.steps.indexed) {
        keepSections.add(s.id);
        await _upsertChild(tx, 'sections', s.id, now, {
          'recipe_id': saved.id,
          'kind': 'steps',
          'position': i,
          'name': s.name,
        });
        for (final (j, step) in s.items.indexed) {
          keepSteps.add(step.id);
          await _upsertChild(tx, 'steps', step.id, now, {
            'recipe_id': saved.id,
            'section_id': s.id,
            'position': j,
            'text': step.text,
          });
        }
      }
      await _softDeleteOthers(tx, 'ingredient_lines', saved.id, keepLines, now);
      await _softDeleteOthers(tx, 'steps', saved.id, keepSteps, now);
      await _softDeleteOthers(tx, 'sections', saved.id, keepSections, now);
      await _syncLinks(
        tx,
        'cookbook_recipes',
        'cookbook_id',
        saved.id,
        saved.cookbookIds.toSet(),
        now,
      );
      await _syncLinks(
        tx,
        'recipe_tags',
        'tag_id',
        saved.id,
        await _tagIds(tx, saved.tags, now),
        now,
      );
    });
    return saved;
  }

  /// A recipe with its live sections, or null if missing or deleted.
  Future<Recipe?> get(String id) async {
    final rows = await _db.query(
      'recipes',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final sections = await _db.query(
      'sections',
      where: 'recipe_id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      orderBy: 'position',
    );
    final lines = await _db.query(
      'ingredient_lines',
      where: 'recipe_id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      orderBy: 'position',
    );
    final steps = await _db.query(
      'steps',
      where: 'recipe_id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      orderBy: 'position',
    );
    List<Map<String, Object?>> of(List<Map<String, Object?>> rows, Object s) =>
        rows.where((r) => r['section_id'] == s).toList();

    final cookbooks = await _db.rawQuery(
      'SELECT cr.cookbook_id FROM cookbook_recipes cr '
      'JOIN cookbooks c ON c.id = cr.cookbook_id '
      'WHERE cr.recipe_id = ? AND cr.deleted_at IS NULL '
      'AND c.deleted_at IS NULL ORDER BY c.position, c.name',
      [id],
    );
    final tags = await _db.rawQuery(
      'SELECT t.name FROM recipe_tags rt JOIN tags t ON t.id = rt.tag_id '
      'WHERE rt.recipe_id = ? AND rt.deleted_at IS NULL '
      'AND t.deleted_at IS NULL ORDER BY rt.created_at, t.name',
      [id],
    );

    return Recipe.fromMap(
      rows.single,
      cookbookIds: [for (final r in cookbooks) r['cookbook_id']! as String],
      tags: [for (final r in tags) r['name']! as String],
      ingredients: [
        for (final s in sections.where((s) => s['kind'] == 'ingredients'))
          Section(
            id: s['id']! as String,
            name: s['name'] as String?,
            items: of(lines, s['id']!).map(IngredientLine.fromMap).toList(),
          ),
      ],
      steps: [
        for (final s in sections.where((s) => s['kind'] == 'steps'))
          Section(
            id: s['id']! as String,
            name: s['name'] as String?,
            items: [
              for (final r in of(steps, s['id']!))
                RecipeStep(id: r['id']! as String, text: r['text']! as String),
            ],
          ),
      ],
    );
  }

  /// Live recipes, newest first (ORG-5's default order). Deleted recipes
  /// appear nowhere (ORG-7).
  Future<List<RecipeSummary>> list() async {
    final rows = await _db.query(
      'recipes',
      columns: [
        'id',
        'title',
        'photo_path',
        'source_type',
        'prep_minutes',
        'cook_minutes',
        'cooked_count',
        'created_at',
      ],
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );
    return [
      for (final r in rows)
        RecipeSummary(
          id: r['id']! as String,
          title: r['title']! as String,
          photoPath: r['photo_path'] as String?,
          sourceType: SourceType.values.byName(r['source_type']! as String),
          totalMinutes: r['prep_minutes'] == null && r['cook_minutes'] == null
              ? null
              : ((r['prep_minutes'] as int?) ?? 0) +
                    ((r['cook_minutes'] as int?) ?? 0),
          cookedCount: r['cooked_count']! as int,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            r['created_at']! as int,
            isUtc: true,
          ),
        ),
    ];
  }

  /// Every live recipe as a search index entry (ORG-3–ORG-7): its title,
  /// ingredient names, tags, notes and cookbooks, in four queries.
  Future<List<LibraryEntry>> library() async {
    final recipes = await _db.query(
      'recipes',
      columns: [
        'id',
        'title',
        'photo_path',
        'source_type',
        'prep_minutes',
        'cook_minutes',
        'cooked_count',
        'last_cooked_at',
        'created_at',
        'notes',
      ],
      where: 'deleted_at IS NULL',
    );
    final names = <String, List<String>>{};
    for (final r in await _db.rawQuery(
      'SELECT recipe_id, name FROM ingredient_lines '
      'WHERE deleted_at IS NULL ORDER BY position',
    )) {
      (names[r['recipe_id']! as String] ??= []).add(r['name']! as String);
    }
    final tags = <String, List<String>>{};
    for (final r in await _db.rawQuery(
      'SELECT rt.recipe_id, t.name FROM recipe_tags rt '
      'JOIN tags t ON t.id = rt.tag_id '
      'WHERE rt.deleted_at IS NULL AND t.deleted_at IS NULL',
    )) {
      (tags[r['recipe_id']! as String] ??= []).add(r['name']! as String);
    }
    final books = <String, Set<String>>{};
    for (final r in await _db.rawQuery(
      'SELECT cr.recipe_id, cr.cookbook_id FROM cookbook_recipes cr '
      'JOIN cookbooks c ON c.id = cr.cookbook_id '
      'WHERE cr.deleted_at IS NULL AND c.deleted_at IS NULL',
    )) {
      (books[r['recipe_id']! as String] ??= {}).add(
        r['cookbook_id']! as String,
      );
    }
    DateTime? date(Object? ms) => ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);
    return [
      for (final r in recipes)
        LibraryEntry(
          id: r['id']! as String,
          title: r['title']! as String,
          photoPath: r['photo_path'] as String?,
          sourceType: SourceType.values.byName(r['source_type']! as String),
          totalMinutes: r['prep_minutes'] == null && r['cook_minutes'] == null
              ? null
              : ((r['prep_minutes'] as int?) ?? 0) +
                    ((r['cook_minutes'] as int?) ?? 0),
          cookedCount: r['cooked_count']! as int,
          lastCookedAt: date(r['last_cooked_at']),
          createdAt: date(r['created_at'])!,
          notes: r['notes'] as String?,
          ingredientNames: names[r['id']] ?? const [],
          tags: tags[r['id']] ?? const [],
          cookbookIds: books[r['id']] ?? const {},
        ),
    ];
  }

  /// Live cookbooks in their order (ORG-1).
  Future<List<Cookbook>> cookbooks() async => [
    for (final r in await _db.query(
      'cookbooks',
      where: 'deleted_at IS NULL',
      orderBy: 'position, name',
    ))
      Cookbook.fromMap(r),
  ];

  /// Creates a cookbook, or renames it when [id] is given (ORG-1: 1–60
  /// characters). Returns its ID.
  Future<String> saveCookbook(String name, {String? id}) async {
    final n = name.trim();
    if (n.isEmpty || n.length > Cookbook.maxName) {
      throw ArgumentError.value(name, 'name', 'must be 1–60 characters');
    }
    final now = _clock().millisecondsSinceEpoch;
    if (id != null) {
      final c = await _db.update(
        'cookbooks',
        {'name': n, 'updated_at': now},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
      if (c != 1) throw StateError('No cookbook $id');
      return id;
    }
    final newId = _ids();
    final last = await _db.rawQuery(
      'SELECT MAX(position) AS p FROM cookbooks WHERE deleted_at IS NULL',
    );
    await _db.insert('cookbooks', {
      'id': newId,
      'name': n,
      'position': ((last.single['p'] as int?) ?? -1) + 1,
      'created_at': now,
      'updated_at': now,
    });
    return newId;
  }

  /// Deletes a cookbook and its links; its recipes stay (ORG-1, DEL-1).
  Future<void> deleteCookbook(String id) async {
    final now = _clock().millisecondsSinceEpoch;
    await _db.transaction((tx) async {
      await tx.update(
        'cookbooks',
        {'deleted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await tx.update(
        'cookbook_recipes',
        {'deleted_at': now, 'updated_at': now},
        where: 'cookbook_id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
    });
  }

  /// Tags in use by live recipes, most used first, for suggestions (ORG-2).
  Future<List<String>> tagsInUse() async => [
    for (final r in await _db.rawQuery(
      'SELECT t.name, COUNT(*) AS n FROM recipe_tags rt '
      'JOIN tags t ON t.id = rt.tag_id '
      'JOIN recipes r ON r.id = rt.recipe_id '
      'WHERE rt.deleted_at IS NULL AND t.deleted_at IS NULL '
      'AND r.deleted_at IS NULL GROUP BY t.id ORDER BY n DESC, t.name',
    ))
      r['name']! as String,
  ];

  /// Remembers how a recipe's amounts are shown (SCALE-5).
  Future<void> setUnitView(String id, UnitView view) async {
    final c = await _db.update(
      'recipes',
      {
        'unit_view': view == UnitView.asWritten ? null : view.name,
        'updated_at': _clock().millisecondsSinceEpoch,
      },
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    if (c != 1) throw StateError('No recipe $id');
  }

  /// How many people a recipe is written for (REC-7), or null. A planned
  /// meal starts from it (PLAN-2).
  Future<int?> servingsOf(String id) async {
    final rows = await _db.query(
      'recipes',
      columns: ['servings'],
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : rows.single['servings'] as int?;
  }

  /// The live recipe imported from [normalizedUrl], if any (IMP-9).
  Future<String?> findBySourceUrl(String normalizedUrl) async {
    final rows = await _db.query(
      'recipes',
      columns: ['id'],
      where: 'source_url = ? AND deleted_at IS NULL',
      whereArgs: [normalizedUrl],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['id']! as String;
  }

  /// "Mark as cooked" (REC-9, COOK-6): one more cook, and when.
  Future<void> markCooked(String id) async {
    final now = _clock().millisecondsSinceEpoch;
    final c = await _db.rawUpdate(
      'UPDATE recipes SET cooked_count = cooked_count + 1, '
      'last_cooked_at = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL',
      [now, now, id],
    );
    if (c != 1) throw StateError('No recipe $id');
  }

  static const _cookKey = 'cook_progress';
  static const resumeWindow = Duration(hours: 12); // COOK-6

  /// The cook-mode page to resume on, if left within 12 hours (COOK-6).
  Future<int?> cookPage(String recipeId) async {
    final all = await _cookProgress();
    final p = all[recipeId];
    if (p == null) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(
      p['at']! as int,
      isUtc: true,
    );
    if (_clock().difference(at) > resumeWindow) return null;
    return p['page']! as int;
  }

  /// Remembers the cook-mode page; entries older than 12 hours are dropped.
  Future<void> setCookPage(String recipeId, int page) async {
    final all = await _cookProgress();
    final now = _clock();
    all.removeWhere(
      (_, v) =>
          now.difference(
            DateTime.fromMillisecondsSinceEpoch(v['at']! as int, isUtc: true),
          ) >
          resumeWindow,
    );
    all[recipeId] = {'page': page, 'at': now.millisecondsSinceEpoch};
    await _db.insert('meta', {
      'key': _cookKey,
      'value': jsonEncode(all),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Map<String, Object?>>> _cookProgress() async {
    final rows = await _db.query(
      'meta',
      where: 'key = ?',
      whereArgs: [_cookKey],
    );
    if (rows.isEmpty) return {};
    final m =
        jsonDecode(rows.single['value']! as String) as Map<String, Object?>;
    return {
      for (final e in m.entries)
        e.key: (e.value! as Map).cast<String, Object?>(),
    };
  }

  /// Moves a recipe to the trash (DEL-1). Its children stay as they are, so
  /// [restore] brings the whole recipe back.
  Future<void> delete(String id) => _setDeleted(id, _clock());

  /// Undo for [delete] (DEL-2).
  Future<void> restore(String id) => _setDeleted(id, null);

  Future<void> _setDeleted(String id, DateTime? at) async {
    final count = await _db.update(
      'recipes',
      {
        'deleted_at': at?.millisecondsSinceEpoch,
        'updated_at': _clock().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('No recipe $id');
  }

  /// Removes recipes deleted more than 30 days ago, with their children
  /// (DEL-2). Returns their photo paths so the caller can delete the files
  /// (REC-8).
  Future<List<String>> purgeTrash() async {
    final cutoff = _clock()
        .subtract(const Duration(days: trashDays))
        .millisecondsSinceEpoch;
    final photos = <String>[];
    await _db.transaction((tx) async {
      final old = await tx.query(
        'recipes',
        columns: ['id', 'photo_path'],
        where: 'deleted_at IS NOT NULL AND deleted_at < ?',
        whereArgs: [cutoff],
      );
      for (final r in old) {
        final id = r['id']! as String;
        if (r['photo_path'] != null) photos.add(r['photo_path']! as String);
        for (final t in [
          'ingredient_lines',
          'steps',
          'sections',
          'cookbook_recipes',
          'recipe_tags',
          'plan_entries', // a purged recipe takes its planned meals (PLAN-6)
        ]) {
          await tx.delete(t, where: 'recipe_id = ?', whereArgs: [id]);
        }
        await tx.delete('recipes', where: 'id = ?', whereArgs: [id]);
      }
    });
    return photos;
  }

  /// The anonymous install ID the import server needs (SRV-4). Created once,
  /// kept in the database, so backups include it (REC-11).
  Future<String> installId() async {
    final rows = await _db.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['install_id'],
    );
    if (rows.isNotEmpty) return rows.single['value']! as String;
    final id = _ids();
    await _db.insert('meta', {'key': 'install_id', 'value': id});
    return id;
  }

  static const _sampleOfferedKey = 'sample_offered';

  /// The built-in sample recipe (RUN-6), offered once: only on a phone
  /// with no recipes at all (deleted ones count too), and never again once
  /// this has run, whether or not it added anything. Returns whether it
  /// added the sample.
  Future<bool> addSampleOnFirstRun({required bool arabic}) async {
    final offered = await _db.query(
      'meta',
      where: 'key = ?',
      whereArgs: [_sampleOfferedKey],
    );
    var added = false;
    if (offered.isEmpty) {
      final count = Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM recipes'),
      );
      if (count == 0) {
        await save(sampleRecipe(arabic: arabic, now: _clock()));
        added = true;
      }
    }
    await _db.insert('meta', {
      'key': _sampleOfferedKey,
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return added;
  }

  /// The IDs of tags named [names], creating the missing ones. Names match
  /// after Arabic normalization, so "حار" and "حارّ" are one tag (ORG-4).
  Future<Set<String>> _tagIds(
    Transaction tx,
    List<String> names,
    DateTime now,
  ) async {
    if (names.isEmpty) return {};
    final existing = <String, String>{
      for (final r in await tx.query(
        'tags',
        columns: ['id', 'name'],
        where: 'deleted_at IS NULL',
      ))
        normalizeArabic(r['name']! as String): r['id']! as String,
    };
    final ids = <String>{};
    for (final raw in names) {
      final name = raw.trim();
      final key = normalizeArabic(name);
      var id = existing[key];
      if (id == null) {
        id = _ids();
        existing[key] = id;
        await tx.insert('tags', {
          'id': id,
          'name': name,
          'created_at': now.millisecondsSinceEpoch,
          'updated_at': now.millisecondsSinceEpoch,
        });
      }
      ids.add(id);
    }
    return ids;
  }

  /// Makes [recipeId]'s live links in [table] exactly [targets]: missing
  /// ones are added, extra ones soft-deleted (DEL-1, BAK-3).
  Future<void> _syncLinks(
    Transaction tx,
    String table,
    String column,
    String recipeId,
    Set<String> targets,
    DateTime now,
  ) async {
    final ms = now.millisecondsSinceEpoch;
    final live = await tx.query(
      table,
      columns: ['id', column],
      where: 'recipe_id = ? AND deleted_at IS NULL',
      whereArgs: [recipeId],
    );
    final have = <String>{};
    for (final r in live) {
      final target = r[column]! as String;
      if (targets.contains(target) && have.add(target)) continue;
      await tx.update(
        table,
        {'deleted_at': ms, 'updated_at': ms},
        where: 'id = ?',
        whereArgs: [r['id']],
      );
    }
    for (final target in targets.difference(have)) {
      await tx.insert(table, {
        'id': _ids(),
        'recipe_id': recipeId,
        column: target,
        'created_at': ms,
        'updated_at': ms,
      });
    }
  }

  Future<void> _upsert(
    Transaction tx,
    String table,
    Map<String, Object?> row,
  ) => tx.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> _upsertChild(
    Transaction tx,
    String table,
    String id,
    DateTime now,
    Map<String, Object?> values,
  ) async {
    final updated = await tx.update(
      table,
      {...values, 'updated_at': now.millisecondsSinceEpoch, 'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      await tx.insert(table, {
        ...values,
        'id': id,
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });
    }
  }

  Future<void> _softDeleteOthers(
    Transaction tx,
    String table,
    String recipeId,
    Set<String> keep,
    DateTime now,
  ) async {
    final placeholders = List.filled(keep.length, '?').join(',');
    await tx.update(
      table,
      {
        'deleted_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      },
      where:
          'recipe_id = ? AND deleted_at IS NULL'
          '${keep.isEmpty ? '' : ' AND id NOT IN ($placeholders)'}',
      whereArgs: [recipeId, ...keep],
    );
  }
}
