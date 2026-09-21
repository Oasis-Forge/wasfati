import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wasfati/db/db_helper.dart';
import 'package:wasfati/db/grocery_repository.dart';
import 'package:wasfati/db/plan_repository.dart';
import 'package:wasfati/db/recipe_repository.dart';
import 'package:wasfati/models/aisles.dart';
import 'package:wasfati/models/grocery.dart';
import 'package:wasfati/models/plan.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/providers/grocery_state.dart';
import 'package:wasfati/providers/settings_state.dart';

import '../helpers.dart';

void main() {
  group('migration', () {
    test(
      'step 4 upgrades a version-3 database and keeps plan and recipes',
      () async {
        sqfliteFfiInit();
        final path =
            '${Directory.systemTemp.path}/wasfati_grocery_upgrade_test.db';
        await databaseFactoryFfi.deleteDatabase(path);
        final old = await DBHelper.open(databaseFactoryFfi, path, upTo: 3);
        final clock = FakeClock();
        final ids = CountingIds();
        final v3Recipes = RecipeRepository(
          old,
          clock: clock.call,
          ids: ids.call,
        );
        final r = await v3Recipes.save(kabsa(v3Recipes));
        final v3Plan = PlanRepository(old, clock: clock.call, ids: ids.call);
        await v3Plan.save(
          PlanEntry(
            id: v3Plan.newId(),
            date: DateTime(2026, 9, 19),
            slot: MealSlot.lunch,
            recipeId: r.id,
            servings: 4,
            createdAt: v3Plan.now(),
            updatedAt: v3Plan.now(),
          ),
        );
        await old.close();

        final db = await DBHelper.open(databaseFactoryFfi, path);
        expect(
          (await db.rawQuery('PRAGMA user_version')).single.values.single,
          DBHelper.version,
        );
        final recipes = RecipeRepository(db, clock: clock.call, ids: ids.call);
        expect((await recipes.get(r.id))!.title, r.title);
        final plan = PlanRepository(db, clock: clock.call, ids: ids.call);
        expect(
          (await plan.entriesBetween(
            DateTime(2026, 9, 19),
            DateTime(2026, 9, 19),
          )).single.recipeId,
          r.id,
        );

        // The new tables exist and are empty; nothing else broke.
        final groceries = GroceryRepository(
          db,
          clock: clock.call,
          ids: ids.call,
        );
        expect(await groceries.list(), isEmpty);
        await db.close();
        await databaseFactoryFfi.deleteDatabase(path);
      },
    );
  });

  group('GroceryRepository', () {
    late GroceryRepository groceries;
    late RecipeRepository recipes;
    late FakeClock clock;
    late CountingIds ids;

    setUp(() async {
      final (g, r, c, i) = await testGroceryRepo();
      groceries = g;
      recipes = r;
      clock = c;
      ids = i;
    });

    IncomingLine line(
      String name, {
      Rational? min,
      Rational? max,
      String? unitId,
      String? recipeId,
    }) => IncomingLine(
      name: name,
      min: min,
      max: max,
      unitId: unitId,
      recipeId: recipeId,
    );

    test(
      'GRO-3: a new line merges into the open item with the same name',
      () async {
        await groceries.add([line('طماطم', min: Rational(2), unitId: 'piece')]);
        await groceries.add([
          line('الطماطم', min: Rational.one, unitId: 'can'),
        ]);

        final items = await groceries.list();
        expect(items.length, 1);
        expect(items.single.amounts.length, 2);
        expect(totalOf(items.single.amounts), [
          // Labelled "piece" next to another part (GRO-3, should-fix).
          (Rational(2), 'piece'),
          (Rational.one, 'can'),
        ]);
      },
    );

    test(
      'a done item is never merged into; a new line starts a new item',
      () async {
        await groceries.add([
          line('طماطم', min: Rational.one, unitId: 'piece'),
        ]);
        final first = (await groceries.list()).single;
        await groceries.setDone(first.id, true);

        await groceries.add([
          line('طماطم', min: Rational.one, unitId: 'piece'),
        ]);
        final items = await groceries.list();
        expect(items.length, 2);
        expect(items.where((i) => i.doneAt == null).length, 1);
        expect(items.where((i) => i.doneAt != null).length, 1);
      },
    );

    test(
      'GRO-4: moving an item to an aisle is remembered for that name',
      () async {
        await groceries.add([
          line('كزبرة', min: Rational.one, unitId: 'bunch'),
        ]);
        final item = (await groceries.list()).single;
        await groceries.moveToAisle(item.id, Aisle.meat);
        expect((await groceries.list()).single.aisle, Aisle.meat);

        // Once it's done, the next line with the same name starts a new item,
        // but in the remembered aisle.
        await groceries.setDone(item.id, true);
        await groceries.add([line('كزبرة', min: Rational(2), unitId: 'bunch')]);
        final next = (await groceries.list()).firstWhere(
          (i) => i.doneAt == null,
        );
        expect(next.aisle, Aisle.meat);
      },
    );

    test('GRO-4: moving two items with the same name upserts one aisle_choices '
        'row in place (should-fix, adversary review: INSERT OR REPLACE used '
        'to give the choice a new ID and created_at on every move, breaking '
        "BAK-3's merge-by-ID)", () async {
      await groceries.add([line('كزبرة', min: Rational.one)]);
      final first = (await groceries.list()).single;
      await groceries.moveToAisle(first.id, Aisle.spices);
      final rowsAfterFirst = await groceries.db.query('aisle_choices');
      expect(rowsAfterFirst.length, 1);
      final firstId = rowsAfterFirst.single['id'];
      final firstCreatedAt = rowsAfterFirst.single['created_at'];

      clock.advance(const Duration(minutes: 1));
      await groceries.setDone(first.id, true);
      await groceries.add([line('كزبرة', min: Rational(2))]);
      final second = (await groceries.list()).firstWhere(
        (i) => i.doneAt == null,
      );
      await groceries.moveToAisle(second.id, Aisle.produce);

      final rows = await groceries.db.query('aisle_choices');
      expect(rows.length, 1); // still one row, not a second
      expect(rows.single['id'], firstId); // same ID (BAK-3 merge-by-ID)
      expect(rows.single['created_at'], firstCreatedAt); // unchanged
      expect(rows.single['aisle'], Aisle.produce.name); // updated in place
    });

    test('GRO-1: a hand-typed line is parsed and added', () async {
      await groceries.addByHand('2 كيلو طماطم');
      final item = (await groceries.list()).single;
      expect(item.name, 'طماطم');
      expect(item.handAdded, isTrue);
      expect(totalOf(item.amounts), [(Rational(2), 'kg')]);
    });

    test('a hand-typed line with no amount is to-taste (QTY-2)', () async {
      await groceries.addByHand('ملح');
      final item = (await groceries.list()).single;
      expect(totalOf(item.amounts), [(null, null)]);
    });

    test("GRO-7: removeRecipe takes out only that recipe's amounts", () async {
      await groceries.add([
        line('بصل', min: Rational(2), unitId: 'can', recipeId: 'r1'),
        line('بصل', min: Rational.one, unitId: 'can', recipeId: 'r2'),
      ]);
      await groceries.removeRecipe('r1');
      final item = (await groceries.list()).single;
      expect(totalOf(item.amounts), [(Rational.one, 'can')]);
    });

    test(
      'GRO-7: an item left with no amounts and not hand-added disappears',
      () async {
        await groceries.add([
          line('بصل', min: Rational(2), unitId: 'piece', recipeId: 'r1'),
        ]);
        await groceries.removeRecipe('r1');
        expect(await groceries.list(), isEmpty);
      },
    );

    test(
      'a hand-added item is protected even with no live amounts left',
      () async {
        await groceries.add([
          line('بصل', min: Rational(2), unitId: 'piece', recipeId: 'r1'),
        ]);
        await groceries.addByHand('بصل'); // sets hand_added, adds an amount
        final item = (await groceries.list()).single;
        expect(item.handAdded, isTrue);
        expect(item.amounts.length, 2);

        // Simulate that hand amount having gone away on its own, so only the
        // recipe's is left before removeRecipe runs.
        final handAmount = item.amounts.firstWhere((a) => a.recipeId == null);
        await groceries.db.update(
          'grocery_amounts',
          {'deleted_at': clock.now.millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [handAmount.id],
        );
        await groceries.removeRecipe('r1');
        expect((await groceries.list()).map((i) => i.id), [item.id]);
      },
    );

    test('DEL-2: removeRecipe returns the amount and item IDs it took out, and '
        'restoreRemoved is its Undo (must-fix, two reviews: "Remove" had no '
        'Undo)', () async {
      await groceries.add([
        line('بصل', min: Rational(2), unitId: 'piece', recipeId: 'r1'),
      ]);
      final removed = await groceries.removeRecipe('r1');
      expect(removed.amountIds, hasLength(1));
      expect(removed.itemIds, hasLength(1)); // the item was emptied too
      expect(await groceries.list(), isEmpty);

      await groceries.restoreRemoved(removed.amountIds, removed.itemIds);
      final item = (await groceries.list()).single;
      expect(totalOf(item.amounts), [(Rational(2), null)]);
    });

    test('GRO-2: water and ice never make it into the list', () async {
      await groceries.add([
        line('ماء', min: Rational.one, unitId: 'l'),
        line('مكعبات ثلج', min: Rational(10)),
        line('طماطم', min: Rational.one, unitId: 'piece'),
      ]);
      expect((await groceries.list()).map((i) => i.name), ['طماطم']);
    });

    test('the list is aisle then name (GRO-5, ORG-5)', () async {
      // Aisles are pinned by hand here, not left to aisleFor's table, so
      // this only tests list()'s own ordering (GRO-4 is aisles.dart's own).
      await groceries.add([line('لحم', min: Rational.one, unitId: 'kg')]);
      await groceries.add([line('طماطم', min: Rational.one, unitId: 'piece')]);
      await groceries.add([line('بصل', min: Rational.one, unitId: 'piece')]);
      final items = await groceries.list();
      await groceries.moveToAisle(
        items.firstWhere((i) => i.name == 'لحم').id,
        Aisle.meat,
      );
      await groceries.moveToAisle(
        items.firstWhere((i) => i.name == 'طماطم').id,
        Aisle.produce,
      );
      await groceries.moveToAisle(
        items.firstWhere((i) => i.name == 'بصل').id,
        Aisle.produce,
      );
      final ordered = await groceries.list();
      // Produce (GRO-4's first aisle) before meat; within produce, بصل
      // before طماطم (Arabic alphabetical order, ORG-5).
      expect(ordered.map((i) => i.name), ['بصل', 'طماطم', 'لحم']);
    });

    test(
      'GRO-5, DEL-2: clearDone and clearAll offer Undo, then purge',
      () async {
        await groceries.add([line('بصل', min: Rational.one, unitId: 'piece')]);
        await groceries.add([
          line('طماطم', min: Rational.one, unitId: 'piece'),
        ]);
        final onion = (await groceries.list()).firstWhere(
          (i) => i.name == 'بصل',
        );
        await groceries.setDone(onion.id, true);

        final doneIds = await groceries.clearDone();
        expect(doneIds.length, 1);
        expect((await groceries.list()).length, 1);
        await groceries.restore(doneIds);
        expect((await groceries.list()).length, 2);

        final allIds = await groceries.clearAll();
        expect(allIds.length, 2);
        expect(await groceries.list(), isEmpty);

        clock.advance(const Duration(days: 29));
        await groceries.purgeTrash();
        await groceries.restore(allIds); // still there before 30 days
        expect((await groceries.list()).length, 2);

        await groceries.clearAll();
        clock.advance(const Duration(days: 31));
        await groceries.purgeTrash();
        expect(await groceries.db.query('grocery_items'), isEmpty);
        expect(await groceries.db.query('grocery_amounts'), isEmpty);
      },
    );

    test(
      'unticking with the same name already open merges into it, instead '
      'of showing the ingredient twice (should-fix, adversary review)',
      () async {
        await groceries.add([line('بصل', min: Rational(2))]);
        final first = (await groceries.list()).single;
        await groceries.setDone(first.id, true);
        await groceries.add([line('بصل', min: Rational(3))]); // a new item
        await groceries.setDone(first.id, false); // untick the first back

        final items = await groceries.list();
        expect(items.where((i) => !i.isDone), hasLength(1)); // just one open
        expect(totalOf(items.firstWhere((i) => !i.isDone).amounts), [
          (Rational(5), null), // 2 + 3, merged
        ]);
      },
    );

    test('restoring a cleared item merges into a duplicate added meanwhile '
        '(should-fix, adversary review: an Undo could otherwise leave two '
        'open items with the same name)', () async {
      await groceries.add([line('بصل', min: Rational(2))]);
      final allIds = await groceries.clearAll();
      await groceries.add([line('بصل', min: Rational(3))]);
      await groceries.restore(allIds);

      final items = await groceries.list();
      expect(items.where((i) => !i.isDone), hasLength(1));
      expect(totalOf(items.firstWhere((i) => !i.isDone).amounts), [
        (Rational(5), null),
      ]);
    });

    test(
      'GRO-7: a recipe purge succeeds even with grocery amounts pointing at it',
      () async {
        final r = await recipes.save(kabsa(recipes));
        await groceries.add([
          line('لحم ضأن', min: Rational.one, unitId: 'kg', recipeId: r.id),
        ]);
        await recipes.delete(r.id);
        clock.advance(const Duration(days: 31));
        await recipes.purgeTrash(); // no FK, so this must not throw

        final item = (await groceries.list()).single;
        expect(item.amounts.single.recipeId, r.id); // still names it (GRO-7)
      },
    );

    test(
      'PLAN-5: a plan entry\'s scaled lines are added, then marked',
      () async {
        final r = await recipes.save(kabsa(recipes));
        final plan = PlanRepository(
          groceries.db,
          clock: clock.call,
          ids: ids.call,
        );
        final entry = await plan.save(
          PlanEntry(
            id: plan.newId(),
            date: DateTime(2026, 9, 20),
            slot: MealSlot.dinner,
            recipeId: r.id,
            servings: 12, // double the recipe's 6 (SCALE-2)
            createdAt: plan.now(),
            updatedAt: plan.now(),
          ),
        );
        final recipe = (await recipes.get(r.id))!;
        final factor = Rational(entry.servings!, recipe.servings!);

        await groceries.add(
          groceryLinesForRecipe(recipe, factor, planEntryId: entry.id),
        );
        await plan.markAddedToGroceries([entry.id], plan.now());

        final lamb = (await groceries.list()).firstWhere(
          (i) => i.name.contains('لحم'),
        );
        expect(totalOf(lamb.amounts), [(Rational(2), 'kg')]); // 1 kg × 2

        final updated = (await plan.entriesBetween(
          entry.date,
          entry.date,
        )).single;
        expect(updated.addedToGroceriesAt, isNotNull);
      },
    );

    test(
      'PLAN-5: several plan entries of the same scaled line round once, at '
      'the end, not per entry (must-fix, two reviews: double rounding)',
      () async {
        // Six plan entries of "1 بيضة" (1 egg) at ×1/6 each would store
        // 1/2 (SCALE-3's "never down to nothing" floor) if rounded before
        // merging, showing 3 eggs on the list. Carried exact, they merge
        // to exactly 1 egg.
        final r = await recipes.save(
          kabsa(recipes).copyWith(
            servings: 6,
            ingredients: [
              Section(
                id: recipes.newId(),
                items: [IngredientLine.parse(recipes.newId(), '1 بيضة')],
              ),
            ],
          ),
        );
        final recipe = (await recipes.get(r.id))!;
        for (var i = 0; i < 6; i++) {
          await groceries.add(
            groceryLinesForRecipe(recipe, Rational(1, 6), planEntryId: 'p$i'),
          );
        }
        final egg = (await groceries.list()).single;
        // A count-only item stays a bare number (GRO-3).
        expect(totalOf(egg.amounts), [(Rational.one, null)]);
      },
    );
  });

  group('GroceryState', () {
    test('load, add, and a failed write rolls back', () async {
      final (repo, _, _, _) = await testGroceryRepo();
      final state = GroceryState(repo);
      await state.load();
      expect(state.items, isEmpty);

      final ok = await state.add([
        IncomingLine(name: 'بصل', min: Rational(2), unitId: 'piece'),
      ]);
      expect(ok, isTrue);
      expect(state.items.single.name, 'بصل');
      expect(state.lastError, isNull);

      final before = state.items;
      final failed = await state.setDone('missing', true);
      expect(failed, isFalse);
      expect(state.lastError, isA<StateError>());
      expect(state.items, before);
      state.clearError();
      expect(state.lastError, isNull);
    });

    test('toBuy and done split the list; clearDone offers Undo', () async {
      final (repo, _, _, _) = await testGroceryRepo();
      final state = GroceryState(repo);
      await state.add([
        const IncomingLine(name: 'بصل', min: Rational.one, unitId: 'piece'),
      ]);
      await state.add([
        const IncomingLine(name: 'طماطم', min: Rational.one, unitId: 'piece'),
      ]);
      final onion = state.items.firstWhere((i) => i.name == 'بصل');
      await state.setDone(onion.id, true);

      expect(state.toBuy.map((i) => i.name), ['طماطم']);
      expect(state.done.map((i) => i.name), ['بصل']);

      final ids = await state.clearDone();
      expect(ids!.length, 1);
      expect(state.done, isEmpty);
      await state.restore(ids);
      expect(state.done.map((i) => i.name), ['بصل']);
    });

    test(
      'GRO-5: the "By recipe" view choice is remembered in AppSettings, '
      'so it survives a reload (should-fix: it used to reset on restart)',
      () async {
        final (repo, _, _, _) = await testGroceryRepo();
        final settings = SettingsState(repo.db);
        await settings.load();
        expect(settings.settings.groceryView, GroceryView.byAisle);
        await settings.update(
          settings.settings.copyWith(groceryView: GroceryView.byRecipe),
        );

        // A fresh SettingsState on the same database, standing in for the
        // app restarting.
        final reloaded = SettingsState(repo.db);
        await reloaded.load();
        expect(reloaded.settings.groceryView, GroceryView.byRecipe);
      },
    );
  });
}
