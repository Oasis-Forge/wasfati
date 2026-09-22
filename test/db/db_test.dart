import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wasfati/db/db_helper.dart';
import 'package:wasfati/db/recipe_repository.dart';
import 'package:wasfati/models/quantity/convert.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/services/photo_store.dart' show NoopPhotoStore;

import '../helpers.dart';

Future<int> _version(Database db) async =>
    (await db.rawQuery('PRAGMA user_version')).single.values.single! as int;

void main() {
  group('migrations', () {
    test('every step, from the oldest schema up, runs in order', () async {
      for (var from = 1; from <= DBHelper.version; from++) {
        final db = await memoryDb(upTo: from);
        expect(await _version(db), from);
        await db.close();
      }
      final db = await memoryDb();
      expect(await _version(db), DBHelper.version);
    });

    test(
      'step 2 upgrades a version-1 database and keeps its recipes',
      () async {
        sqfliteFfiInit();
        final path = '${Directory.systemTemp.path}/wasfati_upgrade_test.db';
        await databaseFactoryFfi.deleteDatabase(path);
        final old = await DBHelper.open(databaseFactoryFfi, path, upTo: 1);
        final ids = CountingIds();
        final clock = FakeClock();
        final v1 = RecipeRepository(old, clock: clock.call, ids: ids.call);
        // Written the way version 1 wrote rows: no unit_view column yet.
        final r = kabsa(v1);
        final row = r.toMap()..remove('unit_view');
        await old.insert('recipes', row);
        await old.close();

        final db = await DBHelper.open(databaseFactoryFfi, path);
        expect(await _version(db), DBHelper.version);
        final repo = RecipeRepository(db, clock: clock.call, ids: ids.call);
        final back = (await repo.get(r.id))!;
        expect(back.title, r.title);
        expect(back.unitView, UnitView.asWritten); // null → as written

        await repo.setUnitView(r.id, UnitView.metric); // SCALE-5 remembered
        expect((await repo.get(r.id))!.unitView, UnitView.metric);
        await db.close();
        await databaseFactoryFfi.deleteDatabase(path);
      },
    );

    test('step 5 marks a pre-0.13 database as already offered the sample '
        '(RUN-6, must-fix, review): a recipe that sat only in the trash '
        'before this version must not be lost to the purge and then read as '
        'an empty, never-offered library', () async {
      sqfliteFfiInit();
      final path =
          '${Directory.systemTemp.path}/wasfati_sample_upgrade_test.db';
      await databaseFactoryFfi.deleteDatabase(path);
      final clock = FakeClock();
      final ids = CountingIds();

      final old = await DBHelper.open(databaseFactoryFfi, path, upTo: 4);
      final oldRepo = RecipeRepository(old, clock: clock.call, ids: ids.call);
      final r = await oldRepo.save(kabsa(oldRepo));
      await oldRepo.delete(r.id); // trashed under the old schema, unpurged
      await old.close();

      // Reopening at the current schema runs step 5, which must see this
      // recipe row (even trashed) and mark the database as already
      // offered, before anything ever gets a chance to purge it away.
      final db = await DBHelper.open(databaseFactoryFfi, path);
      expect(await _version(db), DBHelper.version);
      final repo = RecipeRepository(db, clock: clock.call, ids: ids.call);

      clock.advance(const Duration(days: 31));
      await repo.purgeTrash(); // DEL-2: the trashed recipe is gone now
      expect(await repo.list(), isEmpty);

      final added = await repo.addSampleOnFirstRun(arabic: true);
      expect(added, isFalse);
      expect(await repo.list(), isEmpty);

      await db.close();
      await databaseFactoryFfi.deleteDatabase(path);
    });

    test(
      'REC-1, REC-2, DEL-1: every record table has id, times, deleted_at',
      () async {
        final db = await memoryDb();
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' AND name NOT IN ('meta', 'android_metadata')",
        );
        expect(tables, isNotEmpty);
        for (final t in tables) {
          final cols = (await db.rawQuery('PRAGMA table_info(${t['name']})'))
              .map((c) => c['name'])
              .toSet();
          expect(
            cols,
            containsAll(['id', 'created_at', 'updated_at', 'deleted_at']),
            reason: '${t['name']}',
          );
        }
      },
    );
  });

  group('RecipeRepository', () {
    test('a recipe round-trips with groups, parsed lines and steps', () async {
      final (repo, _, _) = await testRepo();
      final saved = await repo.save(kabsa(repo));
      final back = (await repo.get(saved.id))!;

      expect(back.title, 'كبسة لحم');
      expect(back.servings, 6);
      expect(back.totalMinutes, 180);
      expect(back.ingredients.map((s) => s.name), [null, 'للدقوس']);
      final lamb = back.ingredients.first.items.first;
      expect(lamb.original, '1 كيلو جرام لحم ضأن'); // REC-5 kept verbatim
      expect(
        (lamb.min, lamb.unitId, lamb.name),
        (Rational.one, 'kg', 'لحم ضأن'),
      );
      final rice = back.ingredients.first.items[1];
      expect((rice.min, rice.unitId), (Rational(3), 'cup')); // Eastern digits
      expect(back.ingredients.first.items[2].min, isNull); // to taste, QTY-2
      expect(back.steps.single.items.map((s) => s.text), [
        'يحمر اللحم في الزبدة.',
        'يضاف الأرز ويترك 15 دقيقة.',
      ]);
    });

    test(
      'removed lines are soft-deleted, not dropped (DEL-1, BAK-3)',
      () async {
        final (repo, clock, _) = await testRepo();
        final r = await repo.save(kabsa(repo));
        clock.advance(const Duration(minutes: 5));
        final first = r.ingredients.first;
        await repo.save(
          r.copyWith(
            ingredients: [
              Section(id: first.id, items: first.items.take(1).toList()),
              r.ingredients.last,
            ],
          ),
        );
        final back = (await repo.get(r.id))!;
        expect(back.ingredients.first.items.length, 1);
      },
    );

    test('an invalid recipe is refused before anything is written', () async {
      final (repo, _, _) = await testRepo();
      final bad = kabsa(repo, title: '   ');
      await expectLater(repo.save(bad), throwsArgumentError);
      expect(await repo.list(), isEmpty);
    });

    test(
      'list is newest first and leaves out deleted recipes (ORG-7)',
      () async {
        final (repo, clock, _) = await testRepo();
        final a = await repo.save(kabsa(repo, title: 'أ'));
        clock.advance(const Duration(minutes: 1));
        await repo.save(kabsa(repo, title: 'ب'));
        expect((await repo.list()).map((r) => r.title), ['ب', 'أ']);

        await repo.delete(a.id);
        expect((await repo.list()).map((r) => r.title), ['ب']);
        expect(await repo.get(a.id), isNull);

        await repo.restore(a.id); // DEL-2 undo
        expect((await repo.list()).length, 2);
        expect((await repo.get(a.id))!.ingredients.first.items.length, 3);
      },
    );

    test(
      'the trash is purged after 30 days, with photo paths (DEL-2, REC-8)',
      () async {
        final (repo, clock, _) = await testRepo();
        final r = await repo.save(kabsa(repo).copyWith(photoPath: '/p/a.jpg'));
        await repo.delete(r.id);

        clock.advance(const Duration(days: 29));
        expect(await repo.purgeTrash(), isEmpty);

        clock.advance(const Duration(days: 2));
        expect(await repo.purgeTrash(), ['/p/a.jpg']);
        await expectLater(repo.restore(r.id), throwsStateError);
      },
    );

    test('ORG-6, BAK-9: a recipe whose photo file is missing after a device '
        'backup restore is forgotten, without bumping updated_at', () async {
      final (repo, _, _) = await testRepo();
      final present = await repo.save(
        kabsa(repo, title: 'أ').copyWith(photoPath: '/p/present.jpg'),
      );
      final missing = await repo.save(
        kabsa(repo, title: 'ب').copyWith(photoPath: '/p/missing.jpg'),
      );
      final beforeUpdatedAt = (await repo.get(missing.id))!.updatedAt;

      await repo.forgetMissingPhotos(
        const NoopPhotoStore(missing: {'/p/missing.jpg'}),
      );

      // The photo that's still there is untouched...
      expect((await repo.get(present.id))!.photoPath, '/p/present.jpg');
      // ...the missing one is cleared, so ORG-6's "بصورة" filter, the
      // thumbnail and the share all agree there's no photo...
      final after = await repo.get(missing.id);
      expect(after!.photoPath, isNull);
      // ...but this is device-local housekeeping, not a change the user
      // made (should-fix, review): bumping updated_at would make this
      // device wrongly win a later backup merge (BAK-3) for a photo the
      // user never touched.
      expect(after.updatedAt, beforeUpdatedAt);
    });

    test('forgetMissingPhotos is cheap and never throws with nothing to sweep '
        '(ORG-6, BAK-9)', () async {
      final (repo, _, _) = await testRepo();
      await repo.save(kabsa(repo)); // no photo_path at all
      await repo.forgetMissingPhotos(const NoopPhotoStore());
      expect((await repo.list()).single.photoPath, isNull);
    });

    test('the install ID is created once and then kept (SRV-4)', () async {
      final (repo, _, _) = await testRepo();
      final first = await repo.installId();
      expect(await repo.installId(), first);
    });
  });
}
