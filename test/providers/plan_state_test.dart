import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/plan.dart';
import 'package:wasfati/models/ramadan.dart';
import 'package:wasfati/providers/plan_state.dart';

import '../helpers.dart';

/// The week of Saturday 19 September 2026, the fake clock's "today".
final saturday = DateTime(2026, 9, 19);

/// A Ramadan positioned near it, not a real table entry (RAM-2), so this
/// doesn't depend on the built-in calendar's actual dates.
final testRamadan = const RamadanMonth(1448, 2026, 9, 22, 30);

void main() {
  group('Ramadan mode over an injected month', () {
    test('ramadanFor and ramadanMonthOf read the injected calendar', () async {
      final (repo, _, _, _) = await testPlanRepo();
      final state = PlanState(repo, ramadanMonths: [testRamadan]);

      expect(state.ramadanFor(saturday)?.hijriYear, 1448);
      expect(state.ramadanMonthOf(testRamadan.start)?.hijriYear, 1448);
      expect(state.ramadanMonthOf(saturday), isNull); // before it starts
      expect(state.isEid(testRamadan.eid), isTrue);
      expect(state.isEid(testRamadan.last), isFalse);
    });

    test('the Hijri day and its number follow RamadanMonth.dayOf', () async {
      final (repo, _, _, _) = await testPlanRepo();
      final state = PlanState(repo, ramadanMonths: [testRamadan]);
      final day5 = DateTime(2026, 9, 26); // 22..26 = days 1..5
      expect(state.ramadanMonthOf(day5)!.dayOf(day5), 5);
    });

    test('the card\'s window: 7 days before through the last day (RAM-3)', () {
      // Pure function, not PlanState-specific, but exercised the same way
      // the plan screen would over the injected month.
      expect(ramadanCard(testRamadan, saturday, mode: false)?.daysUntil, 3);
      expect(
        ramadanCard(testRamadan, DateTime(2026, 9, 14), mode: false),
        isNull,
      );
    });

    test('the dismissed year hides the card only for that Ramadan', () {
      expect(
        ramadanCard(
          testRamadan,
          saturday,
          mode: false,
          dismissedYear: testRamadan.hijriYear,
        ),
        isNull,
      );
      expect(
        ramadanCard(
          testRamadan,
          saturday,
          mode: false,
          dismissedYear: testRamadan.hijriYear - 1,
        ),
        isNotNull,
      );
    });

    test(
      'showRange loads a whole Ramadan month (RAM-4), not the 7-day week',
      () async {
        final (repo, recipes, _, _) = await testPlanRepo();
        final state = PlanState(repo, ramadanMonths: [testRamadan]);
        final r = await recipes.save(kabsa(recipes));
        await state.showWeek(saturday);
        await state.add(
          date: testRamadan.start,
          slot: MealSlot.iftar,
          recipeId: r.id,
          servings: 6,
        );

        await state.showRange(testRamadan.start, testRamadan.last);
        expect(state.days.length, 30); // day 1 to 30 (RAM-4)
        expect(dateKey(state.days.first), dateKey(testRamadan.start));
        expect(dateKey(state.days.last), dateKey(testRamadan.last));
        expect(state.entries.single.slot, MealSlot.iftar);

        // "الأسبوع" comes back to the week that was showing, not today's.
        await state.showWeek(saturday);
        expect(state.days.length, 7);
      },
    );

    test('setRamadanMode sorts a Ramadan day as suhoor, iftar, snack (RAM-1), '
        'and reloads only when it actually changes something', () async {
      final (repo, _, _, _) = await testPlanRepo();
      final state = PlanState(repo, ramadanMonths: [testRamadan]);
      await state.showRange(testRamadan.start, testRamadan.start);
      await state.add(
        date: testRamadan.start,
        slot: MealSlot.snack,
        note: 'تمر',
      );
      await state.add(
        date: testRamadan.start,
        slot: MealSlot.iftar,
        note: 'شوربة',
      );
      await state.add(
        date: testRamadan.start,
        slot: MealSlot.suhoor,
        note: 'بيض',
      );

      // Mode off: the raw enum order, snack (index 3) before suhoor/iftar.
      await state.setRamadanMode(false);
      expect(state.entries.map((e) => e.note), ['تمر', 'بيض', 'شوربة']);

      // Mode on: suhoor, iftar, then snack (RAM-1's display order).
      await state.setRamadanMode(true);
      expect(state.entries.map((e) => e.note), ['بيض', 'شوربة', 'تمر']);
    });

    test('the shift moves the whole month, resetting for another year '
        '(RAM-2)', () async {
      final (repo, _, _, _) = await testPlanRepo();
      final state = PlanState(repo, ramadanMonths: [testRamadan]);

      await state.setRamadanMode(true, shift: -1, shiftYear: 1448);
      final shifted = state.ramadanFor(saturday)!;
      expect(dateKey(shifted.start), '2026-09-21'); // a day earlier

      // A different Hijri year's shift setting doesn't apply to this one.
      await state.setRamadanMode(true, shift: -1, shiftYear: 1449);
      final unshifted = state.ramadanFor(saturday)!;
      expect(dateKey(unshifted.start), dateKey(testRamadan.start));
    });

    test('ramadanMonthForShiftRowAt keeps Settings\' shift row on the same '
        'year across the boundary a -1 shift creates (should-fix)', () async {
      // testRamadan's last day is 2026-10-21 (start 9-22, length 30).
      final nextYear = RamadanMonth(
        testRamadan.hijriYear + 1,
        2027,
        testRamadan.month,
        testRamadan.day,
        29,
      );
      final (repo, _, _, _) = await testPlanRepo();
      final state = PlanState(repo, ramadanMonths: [testRamadan, nextYear]);
      final lastDay = testRamadan.last;

      await state.setRamadanMode(true, shift: -1, shiftYear: 1448);
      // Plain lookup jumps a year early once the shift makes "today" Eid.
      expect(state.ramadanFor(lastDay)?.hijriYear, 1449);
      // The shift row stays on 1448, so "+" next can undo this shift
      // instead of silently writing a different year's.
      expect(state.ramadanMonthForShiftRowAt(lastDay)?.hijriYear, 1448);
    });
  });

  group('PLAN-2: a note', () {
    test('setNote changes its text in place: same entry, day and meal; '
        'more than 60 characters is refused and leaves it as it was', () async {
      final (repo, _, _, _) = await testPlanRepo();
      final state = PlanState(repo);
      await state.showWeek(saturday);
      final added = await state.add(
        date: saturday,
        slot: MealSlot.dinner,
        note: 'مطعم',
      );

      expect(await state.setNote(added!, 'بقايا الأمس'), isTrue);
      final changed = state.entries.single;
      expect(
        (changed.id, changed.note, changed.slot, dateKey(changed.date)),
        (added.id, 'بقايا الأمس', MealSlot.dinner, dateKey(saturday)),
      );

      expect(await state.setNote(changed, 'ا' * 61), isFalse);
      expect(state.entries.single.note, 'بقايا الأمس');
    });
  });
}
