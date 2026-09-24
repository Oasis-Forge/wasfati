// Backup engine tests (BAK-1–BAK-10). Rule IDs are cited in each test's
// name so a failure points straight at the behavior it's checking.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:wasfati/db/db_helper.dart';
import 'package:wasfati/db/plan_repository.dart';
import 'package:wasfati/db/recipe_repository.dart';
import 'package:wasfati/models/aisles.dart';
import 'package:wasfati/models/plan.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/services/backup.dart';

import '../helpers.dart';

/// Rows for [table] in both databases, sorted by id, with [ignoreColumns]
/// left out (only ever `photo_path`: a restore always gives a recipe's
/// photo a fresh name, REC-8).
Future<void> expectSameTable(
  Database a,
  Database b,
  String table, {
  Set<String> ignoreColumns = const {},
}) async {
  List<Map<String, Object?>> normalize(List<Map<String, Object?>> rows) {
    final copies = [
      for (final r in rows)
        {
          for (final e in r.entries)
            if (!ignoreColumns.contains(e.key)) e.key: e.value,
        },
    ];
    copies.sort((x, y) => (x['id']! as String).compareTo(y['id']! as String));
    return copies;
  }

  expect(
    normalize(await b.query(table)),
    normalize(await a.query(table)),
    reason: table,
  );
}

/// Every record table a backup carries (BAK-6), in no particular order.
const _recordTables = [
  'recipes',
  'sections',
  'ingredient_lines',
  'steps',
  'cookbooks',
  'cookbook_recipes',
  'tags',
  'recipe_tags',
  'plan_entries',
  'grocery_items',
  'grocery_amounts',
  'aisle_choices',
];

/// Re-encodes [bytes]' `backup.json` after [edit] changes its decoded map,
/// keeping every other zip entry (the photos) untouched. Lets a test force
/// a specific row invalid without hand-building a whole backup.
List<int> _withEditedJson(
  List<int> bytes,
  Map<String, Object?> Function(Map<String, Object?> json) edit,
) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final out = Archive();
  for (final file in archive.files) {
    if (file.name == 'backup.json') continue;
    out.addFile(ArchiveFile.bytes(file.name, file.content as List<int>));
  }
  final json = jsonDecode(
    utf8.decode(archive.findFile('backup.json')!.content),
  ) as Map<String, Object?>;
  out.addFile(ArchiveFile.string('backup.json', jsonEncode(edit(json))));
  return ZipEncoder().encodeBytes(out);
}

List<int> _zipOf(Map<String, Object?> json) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('backup.json', jsonEncode(json)));
  return ZipEncoder().encodeBytes(archive);
}

Map<String, Object?> _minimalJson({
  String app = 'wasfati',
  int? schemaVersion,
  Map<String, Object?>? tables,
  Map<String, Object?>? meta,
  String? createdAt,
}) => {
  'app': app,
  'appVersion': '0.1.0',
  'schemaVersion': schemaVersion ?? DBHelper.version,
  'createdAt': createdAt ?? DateTime.utc(2026, 1, 1).toIso8601String(),
  'tables': tables ?? const {},
  'meta': meta ?? const {'settings': null, 'install_id': null},
};

void main() {
  group('createBackup / inspect (BAK-1, BAK-5, BAK-7)', () {
    test('counts recipes, cookbooks, plan weeks and grocery items', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);

      final r1 = await f.recipes.save(kabsa(f.recipes, title: 'وصفة ١'));
      await f.recipes.save(kabsa(f.recipes, title: 'وصفة ٢'));
      final trashed = await f.recipes.save(kabsa(f.recipes, title: 'محذوفة'));
      await f.recipes.delete(trashed.id); // ORG-7: never counted

      await f.recipes.saveCookbook('حلويات');
      await f.recipes.saveCookbook('مقبلات');

      final week1 = DateTime.utc(2026, 9, 21);
      final week2 = week1.add(const Duration(days: 8));
      await f.plans.save(
        PlanEntry(
          id: f.ids(),
          date: week1,
          slot: MealSlot.lunch,
          recipeId: r1.id,
          createdAt: f.clock.now,
          updatedAt: f.clock.now,
        ),
      );
      await f.plans.save(
        PlanEntry(
          id: f.ids(),
          date: week2,
          slot: MealSlot.dinner,
          recipeId: r1.id,
          createdAt: f.clock.now,
          updatedAt: f.clock.now,
        ),
      );

      await f.groceries.addByHand('طماطم');
      await f.groceries.addByHand('بصل');

      final bytes = await f.backup.createBackup();
      final preview = await f.backup.inspect(bytes);

      expect(preview.recipeCount, 2);
      expect(preview.cookbookCount, 2);
      expect(preview.planWeeks, 2);
      expect(preview.groceryItemCount, 2);
      expect(preview.schemaVersion, DBHelper.version);
      expect(preview.createdAt, f.clock.now);
    });

    test(
      'backup.json uses ISO dates, top-level and per record (BAK-5)',
      () async {
        final f = await testBackupFixture();
        addTearDown(f.dispose);
        await f.recipes.save(kabsa(f.recipes));
        final bytes = await f.backup.createBackup();
        final archive = ZipDecoder().decodeBytes(bytes);
        final json = jsonDecode(
          utf8.decode(archive.findFile('backup.json')!.content),
        ) as Map<String, Object?>;
        expect(json['createdAt'], f.clock.now.toIso8601String());
        expect(DateTime.parse(json['createdAt']! as String), f.clock.now);

        // should-fix, several reviews: only the top-level createdAt used to
        // be ISO; every record's own created_at/updated_at/deleted_at were
        // still plain millisecond ints, which BAK-5 rules out for a format
        // meant to become permanent at the first release.
        final tables = (json['tables']! as Map).cast<String, Object?>();
        final recipeRow = (tables['recipes']! as List)
            .cast<Map<String, Object?>>()
            .single;
        expect(recipeRow['created_at'], isA<String>());
        expect(DateTime.parse(recipeRow['created_at']! as String), f.clock.now);
        expect(recipeRow['deleted_at'], isNull); // still null, not "null" ISO
      },
    );
  });

  group('restore(replace) round-trip (BAK-6, BAK-7, REC-8)', () {
    test('gives back identical rows for every table, and the photo along with them', () async {
      final source = await testBackupFixture();
      addTearDown(source.dispose);
      final target = await testBackupFixture();
      addTearDown(target.dispose);

      const photoBytes = [1, 2, 3, 4, 5, 6, 7, 8, 9];
      final photoFile = File(p.join(source.photosDir.path, 'r1.jpg'))
        ..writeAsBytesSync(photoBytes);

      final cookbookId = await source.recipes.saveCookbook('حلويات');
      final saved = await source.recipes.save(
        kabsa(source.recipes, title: 'كبسة').copyWith(
          photoPath: photoFile.path,
          cookbookIds: [cookbookId],
          tags: ['سريع'],
        ),
      );
      await source.plans.save(
        PlanEntry(
          id: source.ids(),
          date: DateTime.utc(2026, 9, 21),
          slot: MealSlot.lunch,
          recipeId: saved.id,
          createdAt: source.clock.now,
          updatedAt: source.clock.now,
        ),
      );
      await source.groceries.addByHand('أرز');
      final item = (await source.groceries.list()).single;
      await source.groceries.moveToAisle(
        item.id,
        Aisle.grains,
      ); // aisle_choices

      final bytes = await source.backup.createBackup();
      final result = await target.backup.restore(
        bytes,
        mode: RestoreMode.replace,
      );
      expect(result.mode, RestoreMode.replace);
      expect(result.perTable['recipes'], const TableMergeCount(added: 1));

      for (final table in _recordTables) {
        await expectSameTable(
          source.db,
          target.db,
          table,
          ignoreColumns: table == 'recipes' ? {'photo_path'} : const {},
        );
      }

      final targetRow = (await target.db.query('recipes')).single;
      final newPhotoPath = targetRow['photo_path']! as String;
      expect(newPhotoPath, isNot(photoFile.path));
      expect(p.isWithin(target.photosDir.path, newPhotoPath), isTrue);
      expect(await File(newPhotoPath).readAsBytes(), photoBytes);
    });

    test(
      'a photo missing from the zip leaves photo_path null (BAK-6)',
      () async {
        final source = await testBackupFixture();
        addTearDown(source.dispose);
        final target = await testBackupFixture();
        addTearDown(target.dispose);

        final ghostPath = p.join(source.photosDir.path, 'gone.jpg');
        await source.recipes.save(
          kabsa(source.recipes).copyWith(photoPath: ghostPath), // never written
        );

        final bytes = await source.backup.createBackup();
        await target.backup.restore(bytes, mode: RestoreMode.replace);

        final row = (await target.db.query('recipes')).single;
        expect(row['photo_path'], isNull);
      },
    );
  });

  group('restore(merge) (BAK-3)', () {
    test('newer local wins, newer backup wins, a deletion propagates, a newer '
        'local deletion stays, and an unknown id is added', () async {
      final local = await testBackupFixture();
      addTearDown(local.dispose);
      final remote = await testBackupFixture();
      addTearDown(remote.dispose);

      final day1 = DateTime.utc(2026, 1, 1);
      final day2 = DateTime.utc(2026, 1, 2);
      final day3 = DateTime.utc(2026, 1, 3);
      final day4 = DateTime.utc(2026, 1, 4);

      Future<void> put(
        BackupFixture f,
        String id,
        String title,
        DateTime at,
      ) async {
        f.clock.now = at;
        await f.recipes.save(
          Recipe(id: id, title: title, createdAt: at, updatedAt: at),
        );
      }

      // r-a: local is newer -> unchanged.
      await put(local, 'r-a', 'A من الجهاز', day2);
      await put(remote, 'r-a', 'A من النسخة القديمة', day1);

      // r-b: the backup is newer -> updated.
      await put(local, 'r-b', 'B قديم', day1);
      await put(remote, 'r-b', 'B جديد', day2);

      // r-d: live locally; the backup deletes it later -> updated (deleted).
      await put(local, 'r-d', 'D', day1);
      await put(remote, 'r-d', 'D', day1);
      remote.clock.now = day3;
      await remote.recipes.delete('r-d');

      // r-e: deleted locally after the backup's row -> stays deleted.
      await put(remote, 'r-e', 'E', day1);
      await put(local, 'r-e', 'E', day1);
      local.clock.now = day4;
      await local.recipes.delete('r-e');

      // r-f: only in the backup -> added.
      await put(remote, 'r-f', 'F', day1);

      final bytes = await remote.backup.createBackup();
      final result = await local.backup.restore(bytes, mode: RestoreMode.merge);

      expect(result.mode, RestoreMode.merge);
      expect(
        result.perTable['recipes'],
        const TableMergeCount(added: 1, updated: 2, unchanged: 2),
      );

      Future<Map<String, Object?>> row(String id) async =>
          (await local.db.query(
            'recipes',
            where: 'id = ?',
            whereArgs: [id],
          )).single;

      expect((await row('r-a'))['title'], 'A من الجهاز'); // local wins
      expect((await row('r-b'))['title'], 'B جديد'); // backup wins
      expect((await row('r-d'))['deleted_at'], isNotNull); // propagated
      expect((await row('r-e'))['deleted_at'], isNotNull); // stayed deleted
      expect((await row('r-f'))['title'], 'F'); // added
    });

    test('merge keeps this phone\'s settings and install ID; replace takes '
        'the file\'s (BAK-7)', () async {
      final local = await testBackupFixture();
      addTearDown(local.dispose);
      final remote = await testBackupFixture();
      addTearDown(remote.dispose);

      const localSettings = AppSettings(language: LanguagePref.ar);
      const remoteSettings = AppSettings(language: LanguagePref.en);
      await local.db.insert('meta', {
        'key': 'settings',
        'value': localSettings.toJson(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await remote.db.insert('meta', {
        'key': 'settings',
        'value': remoteSettings.toJson(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      const localInstallId = 'local-install-id';
      const remoteInstallId = 'remote-install-id';
      await local.db.insert('meta', {
        'key': 'install_id',
        'value': localInstallId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await remote.db.insert('meta', {
        'key': 'install_id',
        'value': remoteInstallId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final bytes = await remote.backup.createBackup();

      await local.backup.restore(bytes, mode: RestoreMode.merge);
      expect(await local.recipes.installId(), localInstallId);
      final afterMerge = await local.db.query(
        'meta',
        where: 'key = ?',
        whereArgs: ['settings'],
      );
      expect(afterMerge.single['value'], localSettings.toJson());

      await local.backup.restore(bytes, mode: RestoreMode.replace);
      expect(await local.recipes.installId(), remoteInstallId);
      final afterReplace = await local.db.query(
        'meta',
        where: 'key = ?',
        whereArgs: ['settings'],
      );
      expect(afterReplace.single['value'], remoteSettings.toJson());
    });
  });

  group('must-fix (BAK-3): a recipe edited on both phones merges as one '
      'coherent unit, never a blend', () {
    test(
      'the newer side supplies its whole set of sections, ingredient '
      "lines and steps; none of the older side's rows are left behind",
      () async {
        final local = await testBackupFixture(idPrefix: 'lo');
        addTearDown(local.dispose);
        final remote = await testBackupFixture(idPrefix: 're');
        addTearDown(remote.dispose);

        const recipeId = 'shared-recipe';
        final day1 = DateTime.utc(2026, 1, 1);
        final day2 = DateTime.utc(2026, 1, 2); // remote edited later, wins

        local.clock.now = day1;
        await local.recipes.save(
          Recipe(
            id: recipeId,
            title: 'قبل التعديل',
            ingredients: [
              Section(
                id: local.ids(),
                items: [
                  IngredientLine.parse(local.ids(), 'كوب أرز'),
                  IngredientLine.parse(local.ids(), 'ملعقة ملح'),
                ],
              ),
            ],
            steps: [
              Section(
                id: local.ids(),
                items: [RecipeStep(id: local.ids(), text: 'يُغسل الأرز.')],
              ),
            ],
            createdAt: day1,
            updatedAt: day1,
          ),
        );

        remote.clock.now = day2;
        await remote.recipes.save(
          Recipe(
            id: recipeId,
            title: 'بعد التعديل',
            ingredients: [
              Section(
                id: remote.ids(),
                items: [
                  IngredientLine.parse(remote.ids(), 'كوب سكر'),
                  IngredientLine.parse(remote.ids(), 'بيضتان'),
                  IngredientLine.parse(remote.ids(), 'كوب دقيق'),
                ],
              ),
            ],
            steps: [
              Section(
                id: remote.ids(),
                items: [
                  RecipeStep(id: remote.ids(), text: 'تُخفق البيضات.'),
                  RecipeStep(id: remote.ids(), text: 'يُضاف السكر والدقيق.'),
                ],
              ),
            ],
            createdAt: day1,
            updatedAt: day2,
          ),
        );

        final bytes = await remote.backup.createBackup();
        final result = await local.backup.restore(
          bytes,
          mode: RestoreMode.merge,
        );
        expect(result.perTable['recipes'], const TableMergeCount(updated: 1));

        final restored = await local.recipes.get(recipeId);
        expect(restored, isNotNull);
        expect(restored!.title, 'بعد التعديل'); // the newer side's row

        // Exactly the newer side's ingredient lines, in order, none of
        // the older side's mixed in.
        final lines = restored.ingredients
            .expand((s) => s.items)
            .map((l) => l.original)
            .toList();
        expect(lines, ['كوب سكر', 'بيضتان', 'كوب دقيق']);

        // Exactly the newer side's steps, in order.
        final steps = restored.steps
            .expand((s) => s.items)
            .map((s) => s.text)
            .toList();
        expect(steps, ['تُخفق البيضات.', 'يُضاف السكر والدقيق.']);

        // None of the older (local) side's rows survive at all, live or
        // otherwise — the losing side's content is dropped, not merged.
        final allLines = await local.db.query(
          'ingredient_lines',
          where: 'recipe_id = ?',
          whereArgs: [recipeId],
        );
        expect(
          allLines.map((r) => r['original_text']),
          everyElement(isNot(anyOf('كوب أرز', 'ملعقة ملح'))),
        );
        final allSteps = await local.db.query(
          'steps',
          where: 'recipe_id = ?',
          whereArgs: [recipeId],
        );
        expect(
          allSteps.map((r) => r['text']),
          everyElement(isNot('يُغسل الأرز.')),
        );
      },
    );
  });

  group('should-fix, review: a merge trashes the untouched sample once real '
      'recipes arrive (RUN-6)', () {
    test('the new phone\'s untouched sample is trashed once a merge from '
        'the old phone brings in a real recipe', () async {
      final newPhone = await testBackupFixture(idPrefix: 'new');
      addTearDown(newPhone.dispose);
      final oldPhone = await testBackupFixture(idPrefix: 'old');
      addTearDown(oldPhone.dispose);

      // The new phone's first launch offers the sample (RUN-6) before the
      // user ever restores anything.
      final added = await newPhone.recipes.addSampleOnFirstRun(arabic: true);
      expect(added, isTrue);
      final sample = (await newPhone.recipes.list()).single;

      // The old phone has its own real recipe.
      await oldPhone.recipes.save(kabsa(oldPhone.recipes));

      final bytes = await oldPhone.backup.createBackup();
      final result = await newPhone.backup.restore(
        bytes,
        mode: RestoreMode.merge,
      );

      expect(result.perTable['recipes']!.added, 1); // the kabsa only
      final titles = (await newPhone.recipes.list()).map((r) => r.id);
      expect(titles, isNot(contains(sample.id))); // the sample is gone
      expect(
        (await newPhone.recipes.list()).map((r) => r.title),
        contains('كبسة لحم'),
      );
    });

    test('a sample the user already touched (renamed, cooked, scaled…) '
        'survives the same merge', () async {
      final newPhone = await testBackupFixture(idPrefix: 'new');
      addTearDown(newPhone.dispose);
      final oldPhone = await testBackupFixture(idPrefix: 'old');
      addTearDown(oldPhone.dispose);

      await newPhone.recipes.addSampleOnFirstRun(arabic: true);
      final sample = (await newPhone.recipes.list()).single;
      newPhone.clock.now = newPhone.clock.now.add(const Duration(days: 1));
      await newPhone.recipes.markCooked(sample.id); // updated_at moves on

      await oldPhone.recipes.save(kabsa(oldPhone.recipes));
      final bytes = await oldPhone.backup.createBackup();
      await newPhone.backup.restore(bytes, mode: RestoreMode.merge);

      final ids = (await newPhone.recipes.list()).map((r) => r.id);
      expect(ids, contains(sample.id)); // no longer untouched, so it stays
    });

    test('a merge that adds no recipe (everything already existed) leaves '
        'the sample alone', () async {
      final newPhone = await testBackupFixture(idPrefix: 'new');
      addTearDown(newPhone.dispose);

      await newPhone.recipes.addSampleOnFirstRun(arabic: true);
      final sample = (await newPhone.recipes.list()).single;

      // A backup of this same phone: merging it back in adds nothing.
      final bytes = await newPhone.backup.createBackup();
      final result = await newPhone.backup.restore(
        bytes,
        mode: RestoreMode.merge,
      );

      expect(result.perTable['recipes']!.added, 0);
      final ids = (await newPhone.recipes.list()).map((r) => r.id);
      expect(ids, contains(sample.id));
    });
  });

  group('a failed restore changes nothing', () {
    test(
      'a constraint violation partway through rolls everything back',
      () async {
        final source = await testBackupFixture();
        addTearDown(source.dispose);
        final target = await testBackupFixture();
        addTearDown(target.dispose);

        const photoBytes = [9, 9, 9];
        final photoFile = File(p.join(source.photosDir.path, 'p.jpg'))
          ..writeAsBytesSync(photoBytes);
        await source.recipes.save(
          kabsa(source.recipes).copyWith(photoPath: photoFile.path),
        );
        final goodBytes = await source.backup.createBackup();

        // A baseline the target already had before the bad restore.
        await target.recipes.save(kabsa(target.recipes, title: 'الأصلية'));
        final beforeRecipes = await target.db.query('recipes');
        final beforeLines = await target.db.query('ingredient_lines');
        final beforePhotos = target.photosDir.listSync().length;

        final brokenBytes = _withEditedJson(goodBytes, (json) {
          final tables = (json['tables']! as Map).cast<String, Object?>();
          final lines = (tables['ingredient_lines']! as List)
              .cast<Map<String, Object?>>()
              .map(Map<String, Object?>.from)
              .toList();
          lines.first['recipe_id'] = 'does-not-exist'; // breaks the FK
          return {
            ...json,
            'tables': {...tables, 'ingredient_lines': lines},
          };
        });

        await expectLater(
          target.backup.restore(brokenBytes, mode: RestoreMode.replace),
          throwsA(anything),
        );

        expect(await target.db.query('recipes'), beforeRecipes);
        expect(await target.db.query('ingredient_lines'), beforeLines);
        expect(target.photosDir.listSync().length, beforePhotos); // no orphan
      },
    );
  });

  group('BAK-2: automatic backups', () {
    test(
      'one is made before every restore, and only the latest 3 are kept',
      () async {
        final f = await testBackupFixture();
        addTearDown(f.dispose);
        await f.recipes.save(kabsa(f.recipes));
        final bytes = await f.backup.createBackup();

        for (var i = 0; i < 5; i++) {
          f.clock.advance(const Duration(minutes: 1));
          await f.backup.restore(bytes, mode: RestoreMode.merge);
        }

        final list = await f.backup.automaticBackups();
        expect(list.length, BackupService.keepAutoBackups);
        // Newest first.
        for (var i = 0; i + 1 < list.length; i++) {
          expect(list[i].createdAt.isAfter(list[i + 1].createdAt), isTrue);
        }
      },
    );

    test('BAK-7: restoring from one of them puts that data back', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      final r = await f.recipes.save(kabsa(f.recipes, title: 'قبل الحذف'));

      // The auto backup made here (BAK-2) is a snapshot of the state above.
      f.clock.advance(const Duration(minutes: 1));
      await f.backup.restore(
        await f.backup.createBackup(),
        mode: RestoreMode.merge,
      );
      final auto = (await f.backup.automaticBackups()).single;

      await f.recipes.delete(r.id);
      expect(await f.recipes.get(r.id), isNull);

      // replace (not merge): the deletion happened after the snapshot, so
      // a merge would keep it deleted (BAK-3, the newer row wins).
      await f.backup.restoreAuto(auto, mode: RestoreMode.replace);
      final restored = await f.recipes.get(r.id);
      expect(restored?.title, 'قبل الحذف'); // back, not deleted
    });
  });

  group('BAK-4: schema versions', () {
    test('a newer schema is refused, nothing is touched', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      await f.recipes.save(kabsa(f.recipes));
      final before = await f.db.query('recipes');

      final bytes = _zipOf(_minimalJson(schemaVersion: DBHelper.version + 1));

      Future<void> expectRefused(Future<void> Function() action) async {
        try {
          await action();
          fail('expected a BackupError');
        } on BackupError catch (e) {
          expect(e.kind, BackupErrorKind.newerSchema);
          expect(e.foundSchemaVersion, DBHelper.version + 1);
        }
      }

      await expectRefused(() => f.backup.inspect(bytes));
      await expectRefused(
        () => f.backup.restore(bytes, mode: RestoreMode.replace),
      );
      expect(await f.db.query('recipes'), before);
    });

    test('a backup written at schema 3 restores into schema 4', () async {
      final oldDb = await memoryDb(upTo: 3);
      final oldIds = CountingIds();
      final oldClock = FakeClock();
      final oldRecipes = RecipeRepository(
        oldDb,
        clock: oldClock.call,
        ids: oldIds.call,
      );
      final oldPlans = PlanRepository(
        oldDb,
        clock: oldClock.call,
        ids: oldIds.call,
      );
      final saved = await oldRecipes.save(kabsa(oldRecipes));
      await oldPlans.save(
        PlanEntry(
          id: oldIds(),
          date: DateTime.utc(2026, 1, 5),
          slot: MealSlot.lunch,
          recipeId: saved.id,
          createdAt: oldClock.now,
          updatedAt: oldClock.now,
        ),
      );

      const v3Tables = [
        'recipes',
        'sections',
        'ingredient_lines',
        'steps',
        'cookbooks',
        'cookbook_recipes',
        'tags',
        'recipe_tags',
        'plan_entries',
      ];
      final tables = {for (final t in v3Tables) t: await oldDb.query(t)};
      await oldDb.close();

      final bytes = _zipOf(
        _minimalJson(
          schemaVersion: 3,
          tables: tables,
          meta: const {'settings': null, 'install_id': 'old-install'},
          createdAt: oldClock.now.toIso8601String(),
        ),
      );

      final target = await testBackupFixture();
      addTearDown(target.dispose);

      final preview = await target.backup.inspect(bytes);
      expect(preview.schemaVersion, 3);
      expect(preview.recipeCount, 1);

      final result = await target.backup.restore(
        bytes,
        mode: RestoreMode.replace,
      );
      expect(result.perTable['recipes'], const TableMergeCount(added: 1));
      expect(result.perTable['plan_entries'], const TableMergeCount(added: 1));

      final row = (await target.db.query('recipes')).single;
      expect(row['title'], 'كبسة لحم');
      // The migration ran the app's own later steps too (step 4): the
      // grocery tables exist and are simply empty for this old backup.
      expect(await target.db.query('grocery_items'), isEmpty);
    });
  });

  group('a file that is not a usable backup', () {
    test('bytes that are not a zip', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      final before = await f.db.query('recipes');
      final bytes = utf8.encode('not a zip file, just some plain text bytes');

      await expectLater(
        f.backup.inspect(bytes),
        throwsA(
          isA<BackupError>().having(
            (e) => e.kind,
            'kind',
            BackupErrorKind.notAZip,
          ),
        ),
      );
      await expectLater(
        f.backup.restore(bytes, mode: RestoreMode.merge),
        throwsA(isA<BackupError>()),
      );
      expect(await f.db.query('recipes'), before);
    });

    test('a zip with no backup.json', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      final archive = Archive()..addFile(ArchiveFile.string('hello.txt', 'hi'));
      final bytes = ZipEncoder().encodeBytes(archive);

      await expectLater(
        f.backup.inspect(bytes),
        throwsA(
          isA<BackupError>().having(
            (e) => e.kind,
            'kind',
            BackupErrorKind.notWasfati,
          ),
        ),
      );
    });

    test('a zip whose backup.json names a different app', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      final bytes = _zipOf(_minimalJson(app: 'some_other_app'));

      await expectLater(
        f.backup.inspect(bytes),
        throwsA(
          isA<BackupError>().having(
            (e) => e.kind,
            'kind',
            BackupErrorKind.notWasfati,
          ),
        ),
      );
    });

    test('damaged JSON', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      final before = await f.db.query('recipes');
      final archive = Archive()
        ..addFile(ArchiveFile.string('backup.json', '{not valid json'));
      final bytes = ZipEncoder().encodeBytes(archive);

      await expectLater(
        f.backup.inspect(bytes),
        throwsA(
          isA<BackupError>().having(
            (e) => e.kind,
            'kind',
            BackupErrorKind.damagedJson,
          ),
        ),
      );
      await expectLater(
        f.backup.restore(bytes, mode: RestoreMode.replace),
        throwsA(isA<BackupError>()),
      );
      expect(await f.db.query('recipes'), before);
    });

    test('must-fix, review: a photo entry named to escape the scratch folder '
        '(zip slip) never writes outside it', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      final archive = Archive()
        ..addFile(ArchiveFile.string('backup.json', jsonEncode(_minimalJson())))
        // Two `..` segments climb out of `photos/` and then out of the
        // scratch folder itself (backup.dart's `_extractPhotos`), landing
        // in its parent — exactly the shape a crafted backup.json still
        // gets past `_openBackup` with (a bare `"app": "wasfati"` is
        // enough), and exactly what the fixed containment check must skip.
        ..addFile(
          ArchiveFile.bytes(
            'photos/../../escaped.txt',
            utf8.encode('should never land here'),
          ),
        );
      final bytes = ZipEncoder().encodeBytes(archive);

      await f.backup.restore(bytes, mode: RestoreMode.merge);

      expect(
        await File(p.join(f.backupsDir.path, 'escaped.txt')).exists(),
        isFalse,
      );
    });
  });

  group('shouldRemindBackup (BAK-8)', () {
    final now = DateTime.utc(2026, 9, 22);

    test('fewer than 10 recipes never reminds', () {
      expect(shouldRemindBackup(9, now, const AppSettings()), isFalse);
    });

    test('10+ recipes and never backed up reminds', () {
      expect(shouldRemindBackup(10, now, const AppSettings()), isTrue);
    });

    test('backed up 29 days ago does not remind yet', () {
      final settings = AppSettings(
        lastBackupAt: now.subtract(const Duration(days: 29)),
      );
      expect(shouldRemindBackup(10, now, settings), isFalse);
    });

    test('backed up 30+ days ago reminds again', () {
      final settings = AppSettings(
        lastBackupAt: now.subtract(const Duration(days: 30)),
      );
      expect(shouldRemindBackup(10, now, settings), isTrue);
    });

    test('snoozed ("Later") does not remind until the snooze ends', () {
      final settings = AppSettings(
        backupReminderSnoozedUntil: now.add(const Duration(days: 1)),
      );
      expect(shouldRemindBackup(20, now, settings), isFalse);
      final ended = AppSettings(
        backupReminderSnoozedUntil: now.subtract(const Duration(days: 1)),
      );
      expect(shouldRemindBackup(20, now, ended), isTrue);
    });

    test('turned off in Settings never reminds', () {
      const settings = AppSettings(backupReminderOff: true);
      expect(shouldRemindBackup(999, now, settings), isFalse);
    });
  });

  group('exportText (BAK-10)', () {
    late BackupFixture f;

    setUp(() async {
      f = await testBackupFixture();
    });
    tearDown(() => f.dispose());

    String export(List<Recipe> recipes) => f.backup.exportText(
      recipes,
      ingredientsHeading: 'المقادير',
      stepsHeading: 'الطريقة',
      footerLine: 'من تطبيق وصفاتي',
      notScaledMark: '*',
      unscaledLineText: (line, mark) => '$line $mark',
      servingsLabel: (n) => '$n حصص',
      prepTimeLabel: (m) => 'تحضير $m د',
      cookTimeLabel: (m) => 'طبخ $m د',
      sourceLabel: (url) => 'المصدر: $url',
    );

    test('all recipes, separated by a clear divider', () async {
      final cookbookId = await f.recipes.saveCookbook('كتاب');
      final a = await f.recipes.save(kabsa(f.recipes, title: 'وصفة أ'));
      final b = await f.recipes.save(
        kabsa(f.recipes, title: 'وصفة ب').copyWith(cookbookIds: [cookbookId]),
      );

      final text = export([
        (await f.recipes.get(a.id))!,
        (await f.recipes.get(b.id))!,
      ]);

      expect(text, contains('وصفة أ'));
      expect(text, contains('وصفة ب'));
      expect(text, contains(exportDivider));
      expect('وصفة'.allMatches(text).length, greaterThanOrEqualTo(2));
    });

    test('one cookbook only', () async {
      final cookbookId = await f.recipes.saveCookbook('كتاب');
      final inBook = await f.recipes.save(
        kabsa(
          f.recipes,
          title: 'داخل الكتاب',
        ).copyWith(cookbookIds: [cookbookId]),
      );
      await f.recipes.save(kabsa(f.recipes, title: 'خارج الكتاب'));

      final library = await f.recipes.library();
      final onlyThisBook = [
        for (final e in library)
          if (e.cookbookIds.contains(cookbookId)) (await f.recipes.get(e.id))!,
      ];
      expect(onlyThisBook.map((r) => r.id), [inBook.id]);

      final text = export(onlyThisBook);
      expect(text, contains('داخل الكتاب'));
      expect(text, isNot(contains('خارج الكتاب')));
      expect(text, isNot(contains(exportDivider))); // one recipe, no divider
    });
  });

  group('BAK-1, DATE-1: backupFileName uses the local calendar date', () {
    test(
      'a DateTime already in local time is used as-is, not shifted to UTC',
      () {
        // Not a UTC DateTime: .toLocal() on it is a no-op wherever this
        // test runs, so it's deterministic in any timezone. It stands in
        // for "2:30 AM local time, the far side of a UTC day boundary"
        // (should-fix, platform review: the old code formatted the UTC
        // instant directly, so a backup made just after local midnight but
        // before UTC midnight — or the reverse — carried the wrong date).
        final local = DateTime(2026, 9, 23, 2, 30);
        expect(backupFileName(local), 'wasfati-backup-2026-09-23.zip');
      },
    );
  });

  group('must-fix: a structurally odd but syntactically valid backup.json '
      'never escapes as a raw TypeError/FormatException (BAK-7 "changes '
      'nothing and says so"; several reviews)', () {
    test('a table that is not a list of rows', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      final bytes = _zipOf(_minimalJson(tables: {'recipes': 'oops'}));

      await expectLater(
        f.backup.inspect(bytes),
        throwsA(
          isA<BackupError>().having(
            (e) => e.kind,
            'kind',
            BackupErrorKind.damagedJson,
          ),
        ),
      );
      await expectLater(
        f.backup.restore(bytes, mode: RestoreMode.merge),
        throwsA(isA<BackupError>()),
      );
    });

    test('a createdAt that does not parse as a date', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      final bytes = _zipOf(_minimalJson(createdAt: 'not-a-date'));

      await expectLater(
        f.backup.inspect(bytes),
        throwsA(
          isA<BackupError>().having(
            (e) => e.kind,
            'kind',
            BackupErrorKind.damagedJson,
          ),
        ),
      );
    });

    test('a plan entry row with no date at all', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      final bytes = _zipOf(
        _minimalJson(
          tables: {
            'plan_entries': [
              {
                'id': 'p-1',
                'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
                'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
              },
            ],
          },
        ),
      );

      await expectLater(
        f.backup.inspect(bytes),
        throwsA(
          isA<BackupError>().having(
            (e) => e.kind,
            'kind',
            BackupErrorKind.damagedJson,
          ),
        ),
      );
    });
  });

  group('must-fix: automatic backups survive a bad clock and a failed '
      'restore (BAK-2; adversary review probes P1, P2, P10)', () {
    test('a phone clock running behind never lets pruning delete the backup '
        'just made (probe P2)', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      final bytes = await f.backup.createBackup(); // an empty-ish file

      for (var i = 0; i < BackupService.keepAutoBackups; i++) {
        f.clock.advance(const Duration(minutes: 1));
        await f.backup.restore(bytes, mode: RestoreMode.merge);
      }

      await f.recipes.save(kabsa(f.recipes, title: 'جديدة لا تعوض'));
      f.clock.now = f.clock.now.subtract(const Duration(days: 1));
      await f.backup.restore(bytes, mode: RestoreMode.replace);

      final autos = await f.backup.automaticBackups();
      expect(autos, hasLength(BackupService.keepAutoBackups));
      var found = false;
      for (final auto in autos) {
        final preview = await f.backup.inspect(
          await File(auto.path).readAsBytes(),
        );
        if (preview.recipeCount == 1) found = true;
      }
      expect(
        found,
        isTrue,
        reason: "the pre-replace snapshot with 'جديدة لا تعوض' must survive",
      );
    });

    test(
      'a restore that fails afterwards leaves the existing automatic '
      'backups untouched, with no stray new one behind (probes P1, P10)',
      () async {
        final f = await testBackupFixture();
        addTearDown(f.dispose);
        await f.recipes.save(kabsa(f.recipes, title: 'الأصل'));
        final goodBytes = await f.backup.createBackup();

        for (var i = 0; i < BackupService.keepAutoBackups; i++) {
          f.clock.advance(const Duration(minutes: 1));
          await f.backup.restore(goodBytes, mode: RestoreMode.merge);
        }
        final before = await f.backup.automaticBackups();
        expect(before, hasLength(BackupService.keepAutoBackups));

        final brokenBytes = _withEditedJson(goodBytes, (json) {
          final tables = (json['tables']! as Map).cast<String, Object?>();
          final lines = (tables['ingredient_lines']! as List)
              .cast<Map<String, Object?>>()
              .map(Map<String, Object?>.from)
              .toList();
          lines.first['recipe_id'] = 'does-not-exist';
          return {
            ...json,
            'tables': {...tables, 'ingredient_lines': lines},
          };
        });

        f.clock.advance(const Duration(minutes: 1));
        await expectLater(
          f.backup.restore(brokenBytes, mode: RestoreMode.replace),
          throwsA(anything),
        );

        final after = await f.backup.automaticBackups();
        expect(after.map((a) => a.path), before.map((a) => a.path));
      },
    );
  });

  group('must-fix: createBackup snapshots one instant (adversary review '
      'probe P15)', () {
    test('a write landing between two tables\' reads can never produce a '
        'file whose child rows outrun their parent', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      await f.recipes.save(kabsa(f.recipes, title: 'الأولى'));

      final backupFuture = f.backup.createBackup(); // not awaited yet
      // Every table read used to be its own un-transactioned
      // `_db.query`, so a write like this one landing between two of
      // them could end up in the file for some tables (its plan entry)
      // but not others (its recipe) — a backup Replace could never
      // restore. Wrapping every read in one transaction rules that out
      // structurally, whatever this test's own scheduling manages to
      // reproduce.
      await f.recipes.save(kabsa(f.recipes, title: 'الثانية'));
      final bytes = await backupFuture;

      final target = await testBackupFixture();
      addTearDown(target.dispose);
      await target.backup.restore(bytes, mode: RestoreMode.replace);

      final ids = (await target.db.query('recipes'))
          .map((r) => r['id'])
          .toSet();
      expect(ids, isNotEmpty);
      for (final line in await target.db.query('ingredient_lines')) {
        expect(ids, contains(line['recipe_id']));
      }
    });
  });

  group('must-fix: aisle_choices, tags and grocery items merge by name '
      'across two installs (aisle_choices.norm_name UNIQUE; ORG-4, GRO-3)', () {
    test("two installs' aisle choice for the same name merges instead of "
        'breaking the UNIQUE constraint (adversary review probe P3)', () async {
      final local = await testBackupFixture(idPrefix: 'lo');
      addTearDown(local.dispose);
      final remote = await testBackupFixture(idPrefix: 're');
      addTearDown(remote.dispose);

      await local.groceries.addByHand('أرز');
      final localItem = (await local.groceries.list()).single;
      await local.groceries.moveToAisle(localItem.id, Aisle.grains);

      remote.clock.now = local.clock.now.add(const Duration(minutes: 1));
      await remote.groceries.addByHand('أرز');
      final remoteItem = (await remote.groceries.list()).single;
      await remote.groceries.moveToAisle(remoteItem.id, Aisle.spices);

      final bytes = await remote.backup.createBackup();
      // Used to throw "UNIQUE constraint failed: aisle_choices.norm_name"
      // and roll back the whole merge, recipes included.
      await local.backup.restore(bytes, mode: RestoreMode.merge);

      final choices = await local.db.query('aisle_choices');
      expect(choices, hasLength(1)); // never a duplicate row for one name
      expect(choices.single['aisle'], Aisle.spices.name); // remote is newer
    });

    test(
      'a tag with the same name on both phones ends up as one (ORG-4)',
      () async {
        final local = await testBackupFixture(idPrefix: 'lo');
        addTearDown(local.dispose);
        final remote = await testBackupFixture(idPrefix: 're');
        addTearDown(remote.dispose);

        await local.recipes.save(
          kabsa(local.recipes, title: 'من الجهاز').copyWith(tags: ['حار']),
        );
        remote.clock.now = local.clock.now.add(const Duration(minutes: 1));
        await remote.recipes.save(
          kabsa(remote.recipes, title: 'من النسخة').copyWith(tags: ['حارّ']),
        );

        final bytes = await remote.backup.createBackup();
        await local.backup.restore(bytes, mode: RestoreMode.merge);

        expect(await local.recipes.tagsInUse(), hasLength(1)); // not two
        expect(await local.db.query('recipes'), hasLength(2)); // both arrived
      },
    );

    test('an open grocery item with the same name on both phones merges its '
        'amounts onto one item (GRO-3)', () async {
      final local = await testBackupFixture(idPrefix: 'lo');
      addTearDown(local.dispose);
      final remote = await testBackupFixture(idPrefix: 're');
      addTearDown(remote.dispose);

      await local.groceries.addByHand('طماطم');
      remote.clock.now = local.clock.now.add(const Duration(minutes: 1));
      await remote.groceries.addByHand('طماطم');

      final bytes = await remote.backup.createBackup();
      await local.backup.restore(bytes, mode: RestoreMode.merge);

      final open = (await local.groceries.list())
          .where((i) => !i.isDone)
          .toList();
      expect(open, hasLength(1)); // one open "طماطم", not two
      expect(open.single.amounts, hasLength(2)); // both amounts kept
    });
  });

  group('should-fix: replacing or losing a merge frees the photo no row '
      'points at any more (adversary review probe P8)', () {
    test('replacing with the same backup three times leaves exactly one '
        'photo file on disk', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      final photoFile = File(p.join(f.photosDir.path, 'p.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      await f.recipes.save(
        kabsa(f.recipes).copyWith(photoPath: photoFile.path),
      );
      final bytes = await f.backup.createBackup();

      await f.backup.restore(bytes, mode: RestoreMode.replace);
      await f.backup.restore(bytes, mode: RestoreMode.replace);
      await f.backup.restore(bytes, mode: RestoreMode.replace);

      final files = f.photosDir.listSync().whereType<File>().toList();
      expect(files, hasLength(1));
      final row = (await f.db.query('recipes')).single;
      expect(row['photo_path'], files.single.path);
    });

    test("a merge that replaces a recipe's photo frees the old file", () async {
      final local = await testBackupFixture(idPrefix: 'lo');
      addTearDown(local.dispose);
      final remote = await testBackupFixture(idPrefix: 're');
      addTearDown(remote.dispose);

      final localPhoto = File(p.join(local.photosDir.path, 'old.jpg'))
        ..writeAsBytesSync([1]);
      await local.recipes.save(
        Recipe(
          id: 'shared-id',
          title: 'محلي',
          photoPath: localPhoto.path,
          createdAt: local.clock.now,
          updatedAt: local.clock.now,
        ),
      );
      final remotePhoto = File(p.join(remote.photosDir.path, 'new.jpg'))
        ..writeAsBytesSync([2]);
      remote.clock.now = local.clock.now.add(const Duration(minutes: 1));
      await remote.recipes.save(
        Recipe(
          id: 'shared-id',
          title: 'من النسخة',
          photoPath: remotePhoto.path,
          createdAt: local.clock.now,
          updatedAt: remote.clock.now,
        ),
      );

      final bytes = await remote.backup.createBackup();
      await local.backup.restore(bytes, mode: RestoreMode.merge);

      expect(File(localPhoto.path).existsSync(), isFalse); // freed
      final row = (await local.db.query('recipes')).single;
      expect(File(row['photo_path']! as String).existsSync(), isTrue);
    });
  });

  group('should-fix: a photo missing only because the backup was made '
      'without it is never read as "removed" (adversary review probe P6)', () {
    test('a winning merge row whose photo was missing at backup time keeps '
        "the local phone's own photo", () async {
      final local = await testBackupFixture(idPrefix: 'lo');
      addTearDown(local.dispose);
      final remote = await testBackupFixture(idPrefix: 're');
      addTearDown(remote.dispose);

      final localPhoto = File(p.join(local.photosDir.path, 'k.jpg'))
        ..writeAsBytesSync([9]);
      await local.recipes.save(
        Recipe(
          id: 'same-id',
          title: 'محلي',
          photoPath: localPhoto.path,
          createdAt: local.clock.now,
          updatedAt: local.clock.now,
        ),
      );
      // The remote install once had this same photo (BAK-9: a device
      // restore brings back the database but not photo files), then
      // renamed the recipe — its photo_path still names a file that
      // simply isn't there any more, not a photo the user removed.
      remote.clock.now = local.clock.now.add(const Duration(minutes: 1));
      await remote.recipes.save(
        Recipe(
          id: 'same-id',
          title: 'أعيدت تسميتها',
          photoPath: p.join(remote.photosDir.path, 'gone.jpg'),
          createdAt: local.clock.now,
          updatedAt: remote.clock.now,
        ),
      );

      final bytes = await remote.backup.createBackup();
      await local.backup.restore(bytes, mode: RestoreMode.merge);

      final row = (await local.db.query('recipes')).single;
      expect(row['title'], 'أعيدت تسميتها'); // the rename did apply
      expect(row['photo_path'], localPhoto.path); // the real photo stayed
      expect(File(localPhoto.path).existsSync(), isTrue);
    });
  });

  group('should-fix: a trashed recipe crosses only as a deletion, never '
      'its content or photo (ORG-7, BAK-6, privacy)', () {
    test('createBackup writes a bare tombstone: no title, no photo', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      final photoFile = File(p.join(f.photosDir.path, 'p.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      final saved = await f.recipes.save(
        kabsa(f.recipes, title: 'سرية').copyWith(photoPath: photoFile.path),
      );
      await f.recipes.delete(saved.id);

      final bytes = await f.backup.createBackup();
      final archive = ZipDecoder().decodeBytes(bytes);
      final json = jsonDecode(
        utf8.decode(archive.findFile('backup.json')!.content),
      ) as Map<String, Object?>;
      final tables = (json['tables']! as Map).cast<String, Object?>();
      final recipesRows = (tables['recipes']! as List)
          .cast<Map<String, Object?>>();
      final row = recipesRows.singleWhere((r) => r['id'] == saved.id);

      expect(row['title'], ''); // no title content
      expect(row.containsKey('photo_path'), isFalse); // no photo reference
      expect(row.containsKey('source_url'), isFalse); // no other content
      expect(
        archive.files.any((f) => f.name.startsWith('photos/')),
        isFalse,
      ); // no photo bytes crossed either
    });

    test(
      'a merge still marks the recipe deleted from a tombstone alone',
      () async {
        final local = await testBackupFixture(idPrefix: 'lo');
        addTearDown(local.dispose);
        final remote = await testBackupFixture(idPrefix: 're');
        addTearDown(remote.dispose);

        await local.recipes.save(
          Recipe(
            id: 'x',
            title: 'يُحذف',
            createdAt: local.clock.now,
            updatedAt: local.clock.now,
          ),
        );
        await remote.recipes.save(
          Recipe(
            id: 'x',
            title: 'يُحذف',
            createdAt: local.clock.now,
            updatedAt: local.clock.now,
          ),
        );
        remote.clock.now = local.clock.now.add(const Duration(minutes: 1));
        await remote.recipes.delete('x');

        final bytes = await remote.backup.createBackup();
        await local.backup.restore(bytes, mode: RestoreMode.merge);

        expect(await local.recipes.get('x'), isNull);
        final row = (await local.db.query(
          'recipes',
          where: 'id = ?',
          whereArgs: ['x'],
        )).single;
        expect(row['deleted_at'], isNotNull);
      },
    );
  });

  group('should-fix: the restore result counts only what the user asked '
      'about (DEL-1)', () {
    test(
      'userFacing excludes structural rows the total still counts',
      () async {
        // Default (unprefixed) id sources on purpose: both fixtures count
        // from the same start, so kabsa()'s recipe, sections, lines and
        // steps get identical ids and timestamps on both sides, and every
        // one of them merges as "unchanged".
        final local = await testBackupFixture();
        addTearDown(local.dispose);
        final remote = await testBackupFixture();
        addTearDown(remote.dispose);
        await local.recipes.save(kabsa(local.recipes, title: 'واحدة'));
        await remote.recipes.save(kabsa(remote.recipes, title: 'واحدة'));

        final bytes = await remote.backup.createBackup();
        final result = await local.backup.restore(
          bytes,
          mode: RestoreMode.merge,
        );

        expect(result.userFacing, const TableMergeCount(unchanged: 1));
        // Sections, lines and steps are still "unchanged" too, so the raw
        // total is bigger — that used to leak into the dialog as a
        // one-recipe restore reporting "10 unchanged".
        expect(result.total.unchanged, greaterThan(1));
      },
    );

    test('a tombstone with nothing local to replace counts as updated, '
        'never added', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      final at = DateTime.utc(2026, 1, 1).toIso8601String();
      final bytes = _zipOf(
        _minimalJson(
          tables: {
            'recipes': [
              {
                'id': 'r-1',
                'title': '',
                'created_at': at,
                'updated_at': at,
                'deleted_at': at,
              },
            ],
          },
        ),
      );
      final result = await f.backup.restore(bytes, mode: RestoreMode.merge);
      expect(result.perTable['recipes'], const TableMergeCount(updated: 1));
    });
  });

  group('accepted (Decision 15): merge can bring back an item purged more '
      'than 30 days ago (DEL-2)', () {
    test("a purge leaves no tombstone, so an old backup's copy comes back as "
        'live on merge', () async {
      final f = await testBackupFixture();
      addTearDown(f.dispose);
      final saved = await f.recipes.save(kabsa(f.recipes, title: 'قديمة'));
      final bytes = await f.backup.createBackup(); // while still live

      await f.recipes.delete(saved.id);
      f.clock.advance(const Duration(days: 31));
      await f.recipes.purgeTrash(); // hard-deleted, no tombstone left
      expect(await f.recipes.get(saved.id), isNull);

      await f.backup.restore(bytes, mode: RestoreMode.merge);
      // Accepted for now (Decision 15, docs/PRODUCT_RULES.md): with no
      // tombstone to compare against, the merge can't tell this was ever
      // deleted, so the old backup's copy is added back as live.
      expect(await f.recipes.get(saved.id), isNotNull);
    });
  });

  group('BAK-6: translation links (IMP-14)', () {
    test('a translated copy\'s link to its original survives a backup, both '
        'on a replace and on a merge into another phone', () async {
      final source = await testBackupFixture();
      addTearDown(source.dispose);
      final original = await source.recipes.save(kabsa(source.recipes));
      final copy = await source.recipes.save(
        kabsa(
          source.recipes,
          title: 'Lamb kabsa',
        ).copyWith(translatedFrom: original.id),
      );
      final bytes = await source.backup.createBackup();

      for (final mode in RestoreMode.values) {
        final target = await testBackupFixture(idPrefix: 'other');
        addTearDown(target.dispose);
        await target.recipes.save(kabsa(target.recipes, title: 'مقلوبة'));
        await target.backup.restore(bytes, mode: mode);
        expect(
          (await target.recipes.get(copy.id))!.translatedFrom,
          original.id,
          reason: '$mode',
        );
        expect(await target.recipes.translationLinks(original.id), (
          from: null,
          translation: (id: copy.id, title: 'Lamb kabsa'),
        ), reason: '$mode');
      }
    });

    test('a backup written at schema 5 restores into schema 6, its recipes '
        'with no translation link', () async {
      final oldDb = await memoryDb(upTo: 5);
      final oldIds = CountingIds();
      final oldClock = FakeClock();
      final oldRecipes = RecipeRepository(
        oldDb,
        clock: oldClock.call,
        ids: oldIds.call,
      );
      final saved = await oldRecipes.save(kabsa(oldRecipes));
      final tables = {for (final t in _recordTables) t: await oldDb.query(t)};
      expect(tables['recipes']!.single.containsKey('translated_from'), isFalse);
      await oldDb.close();

      final bytes = _zipOf(
        _minimalJson(
          schemaVersion: 5,
          tables: tables,
          meta: const {'settings': null, 'install_id': 'old-install'},
          createdAt: oldClock.now.toIso8601String(),
        ),
      );
      final target = await testBackupFixture();
      addTearDown(target.dispose);
      final result = await target.backup.restore(
        bytes,
        mode: RestoreMode.replace,
      );
      expect(result.perTable['recipes'], const TableMergeCount(added: 1));
      final back = (await target.recipes.get(saved.id))!;
      expect(back.title, 'كبسة لحم');
      expect(back.translatedFrom, isNull);
      expect(
        (await target.db.query('recipes')).single['translated_from'],
        isNull,
      );
    });
  });
}
