import 'package:sqflite/sqflite.dart';

import '../models/recipe.dart';
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

    return Recipe.fromMap(
      rows.single,
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
