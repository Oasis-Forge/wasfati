import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/db/plan_repository.dart';
import 'package:wasfati/db/recipe_repository.dart';
import 'package:wasfati/models/plan.dart';
import 'package:wasfati/providers/plan_state.dart';

import '../helpers.dart';

/// The week of Saturday 19 September 2026, the fake clock's "today".
final saturday = DateTime(2026, 9, 19);
final sunday = DateTime(2026, 9, 20);
final monday = DateTime(2026, 9, 21);

void main() {
  late PlanRepository plan;
  late RecipeRepository recipes;
  late FakeClock clock;

  setUp(() async {
    final (p, r, c, _) = await testPlanRepo();
    plan = p;
    recipes = r;
    clock = c;
  });

  Future<PlanEntry> add(
    DateTime day,
    MealSlot slot, {
    String? recipeId,
    String? note,
    int? servings,
  }) => plan.save(
    PlanEntry(
      id: plan.newId(),
      date: day,
      slot: slot,
      recipeId: recipeId,
      note: note,
      servings: servings,
      createdAt: plan.now(),
      updatedAt: plan.now(),
    ),
  );

  test('PLAN-1, PLAN-2: a week reads by day, then meal, then order', () async {
    final r = await recipes.save(kabsa(recipes));
    await add(sunday, MealSlot.dinner, recipeId: r.id, servings: 6);
    await add(saturday, MealSlot.snack, note: 'تمر وقهوة');
    await add(saturday, MealSlot.breakfast, note: 'بيض');
    await add(saturday, MealSlot.breakfast, note: 'خبز');

    final week = await plan.entriesBetween(saturday, monday);
    expect(week.map((e) => e.note ?? 'كبسة'), [
      'بيض', // Saturday, breakfast, added first
      'خبز', // Saturday, breakfast, after it
      'تمر وقهوة', // Saturday, snack
      'كبسة', // Sunday
    ]);
    expect(week[3].servings, 6);
    expect(week[0].position, 0);
    expect(week[1].position, 1);

    // A day outside the range is not in it.
    await add(DateTime(2026, 9, 30), MealSlot.lunch, note: 'بعيد');
    expect((await plan.entriesBetween(saturday, monday)).length, 4);
  });

  test('PLAN-2: a meal holds at most 10 entries', () async {
    for (var i = 0; i < PlanEntry.maxPerSlot; i++) {
      await add(saturday, MealSlot.lunch, note: 'طبق $i');
    }
    await expectLater(
      add(saturday, MealSlot.lunch, note: 'الحادي عشر'),
      throwsStateError,
    );
    // The same meal on another day is still free.
    expect(await add(sunday, MealSlot.lunch, note: 'طبق'), isA<PlanEntry>());
  });

  test(
    'PLAN-6: an entry hides with its recipe and comes back with it',
    () async {
      final r = await recipes.save(kabsa(recipes));
      await add(sunday, MealSlot.lunch, recipeId: r.id);
      expect((await plan.entriesBetween(saturday, monday)).length, 1);

      await recipes.delete(r.id); // DEL-1
      expect(await plan.entriesBetween(saturday, monday), isEmpty);

      await recipes.restore(r.id); // DEL-2
      expect(
        (await plan.entriesBetween(saturday, monday)).single.recipeId,
        r.id,
      );
    },
  );

  test('DEL-2: purging a recipe takes its planned meals with it', () async {
    final r = await recipes.save(kabsa(recipes));
    await add(sunday, MealSlot.lunch, recipeId: r.id);
    await recipes.delete(r.id);
    clock.advance(const Duration(days: 31));
    await recipes.purgeTrash();
    expect(
      await plan.entriesBetween(DateTime(2026, 1, 1), DateTime(2027, 1, 1)),
      isEmpty,
    );
  });

  test('PLAN-4: clearing a week can be undone', () async {
    await add(saturday, MealSlot.lunch, note: 'مندي');
    await add(monday, MealSlot.dinner, note: 'شوربة');
    await add(DateTime(2026, 10, 5), MealSlot.lunch, note: 'أسبوع آخر');

    final cleared = await plan.clearRange(saturday, DateTime(2026, 9, 25));
    expect(cleared.length, 2);
    expect(await plan.entriesBetween(saturday, monday), isEmpty);
    // The other week is untouched.
    expect(
      (await plan.entriesBetween(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 7),
      )).single.note,
      'أسبوع آخر',
    );

    await plan.restore(cleared);
    expect((await plan.entriesBetween(saturday, monday)).length, 2);
  });

  test('PLAN-4: move keeps one entry, copy makes a second', () async {
    final first = await add(saturday, MealSlot.lunch, note: 'كبسة');
    await plan.moveTo(first, monday, MealSlot.dinner);
    final afterMove = await plan.entriesBetween(saturday, monday);
    expect(afterMove.single.id, first.id);
    expect(
      (dateKey(afterMove.single.date), afterMove.single.slot),
      ('2026-09-21', MealSlot.dinner),
    );

    await plan.moveTo(afterMove.single, sunday, MealSlot.lunch, copy: true);
    final afterCopy = await plan.entriesBetween(saturday, monday);
    expect(afterCopy.map((e) => dateKey(e.date)), ['2026-09-20', '2026-09-21']);
    expect(afterCopy.map((e) => e.note), ['كبسة', 'كبسة']);
  });

  test('PLAN-6: the next planned meal skips days gone by', () async {
    final r = await recipes.save(kabsa(recipes));
    await add(DateTime(2026, 9, 10), MealSlot.lunch, recipeId: r.id);
    await add(DateTime(2026, 9, 24), MealSlot.dinner, recipeId: r.id);
    await add(DateTime(2026, 9, 22), MealSlot.lunch, recipeId: r.id);

    final next = await plan.nextFor(r.id, saturday);
    expect(dateKey(next!.date), '2026-09-22');
    expect(await plan.nextFor(r.id, DateTime(2026, 10, 1)), isNull);
    expect(await plan.nextFor('nobody', saturday), isNull);
  });

  test(
    'PLAN-4: a removed entry can be restored, and trash is purged',
    () async {
      final e = await add(sunday, MealSlot.lunch, note: 'مطعم');
      await plan.remove(e.id);
      expect(await plan.entriesBetween(saturday, monday), isEmpty);
      await plan.restore([e.id]);
      expect((await plan.entriesBetween(saturday, monday)).single.note, 'مطعم');

      await plan.remove(e.id);
      clock.advance(const Duration(days: 31));
      await plan.purgeTrash();
      await plan.restore([e.id]); // the row is gone for good now
      expect(await plan.entriesBetween(saturday, monday), isEmpty);
    },
  );

  group('PlanState', () {
    test(
      'shows a week, moves between weeks and rolls back a bad write',
      () async {
        final state = PlanState(plan);
        await state.showWeek(saturday);
        expect(state.loaded, isTrue);
        expect(dateKey(state.days.last), '2026-09-25');
        expect(dateKey(state.today), '2026-09-19');

        await state.add(date: sunday, slot: MealSlot.dinner, note: 'مشاوي');
        expect(state.entriesFor(sunday, MealSlot.dinner).single.note, 'مشاوي');
        expect(state.entriesFor(sunday, MealSlot.lunch), isEmpty);

        await state.shiftWeeks(1);
        expect(dateKey(state.weekStart), '2026-09-26');
        expect(state.entries, isEmpty);
        await state.shiftWeeks(-1);
        expect(state.entries.length, 1);

        // An entry that is neither a recipe nor a note never reaches the week.
        final before = state.entries.length;
        final failed = await state.add(date: sunday, slot: MealSlot.lunch);
        expect(failed, isNull);
        expect(state.lastError, isNotNull);
        expect(state.entries.length, before);
        state.clearError();
        expect(state.lastError, isNull);
      },
    );

    test(
      'PLAN-4: clearing the week reports what it removed, for undo',
      () async {
        final state = PlanState(plan);
        await state.showWeek(saturday);
        await state.add(date: saturday, slot: MealSlot.lunch, note: 'كبسة');
        await state.add(date: monday, slot: MealSlot.dinner, note: 'شوربة');

        final ids = await state.clearWeek();
        expect(ids!.length, 2);
        expect(state.entries, isEmpty);
        await state.restore(ids);
        expect(state.entries.length, 2);
      },
    );
  });
}
