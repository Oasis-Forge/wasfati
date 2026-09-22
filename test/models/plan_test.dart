import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/plan.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/ramadan.dart';
import 'package:wasfati/models/settings.dart';

PlanEntry _entry({
  String? recipeId = 'r1',
  String? note,
  int? servings,
  Rational? multiplier,
}) {
  final now = DateTime.utc(2026, 9, 20);
  return PlanEntry(
    id: 'p1',
    date: DateTime(2026, 9, 20),
    slot: MealSlot.lunch,
    recipeId: recipeId,
    note: note,
    servings: servings,
    multiplier: multiplier,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('PLAN-2: an entry is a recipe or a note', () {
    test('one of the two, never both and never neither', () {
      expect(_entry().validate(), isNull);
      expect(_entry(recipeId: null, note: 'مطعم').validate(), isNull);
      expect(_entry(note: 'مطعم').validate(), isNotNull);
      expect(_entry(recipeId: null).validate(), isNotNull);
    });

    test('a note is 1–60 characters and carries no amount', () {
      expect(_entry(recipeId: null, note: 'م' * 60).validate(), isNull);
      expect(_entry(recipeId: null, note: 'م' * 61).validate(), isNotNull);
      expect(_entry(recipeId: null, note: '   ').validate(), isNotNull);
      expect(
        _entry(recipeId: null, note: 'مطعم', servings: 4).validate(),
        isNotNull,
      );
    });

    test('servings are 1–100, or one of the multipliers, not both', () {
      expect(_entry(servings: 1).validate(), isNull);
      expect(_entry(servings: 100).validate(), isNull);
      expect(_entry(servings: 0).validate(), isNotNull);
      expect(_entry(servings: 101).validate(), isNotNull);
      expect(_entry(multiplier: Rational.half).validate(), isNull);
      expect(_entry(multiplier: Rational(3)).validate(), isNull);
      expect(_entry(multiplier: Rational(5)).validate(), isNotNull);
      expect(
        _entry(servings: 4, multiplier: Rational.one).validate(),
        isNotNull,
      );
    });

    test('a row comes back as it went in', () {
      final e = _entry(servings: 6);
      final back = PlanEntry.fromMap(e.toMap());
      expect(
        (back.id, back.slot, back.servings, back.recipeId),
        (e.id, MealSlot.lunch, 6, 'r1'),
      );
      expect(dateKey(back.date), '2026-09-20');
      final note = PlanEntry.fromMap(
        _entry(recipeId: null, note: 'مطعم', multiplier: null).toMap(),
      );
      expect((note.isNote, note.note), (true, 'مطعم'));
    });
  });

  group('PLAN-1: which day a week starts on', () {
    int auto(String? region, {bool arabic = true}) =>
        firstWeekday(WeekStart.auto, region: region, arabic: arabic);

    test('a chosen day wins over the region', () {
      expect(
        firstWeekday(WeekStart.monday, region: 'EG', arabic: true),
        DateTime.monday,
      );
      expect(
        firstWeekday(WeekStart.saturday, region: 'US', arabic: false),
        DateTime.saturday,
      );
    });

    test('"by region" follows CLDR: Egypt Saturday, Saudi Sunday, UK '
        'Monday', () {
      expect(auto('EG'), DateTime.saturday);
      expect(auto('kw'), DateTime.saturday); // case doesn't matter
      expect(auto('AE'), DateTime.saturday);
      expect(auto('SA'), DateTime.sunday);
      expect(auto('US', arabic: false), DateTime.sunday);
      expect(auto('GB', arabic: false), DateTime.monday);
      expect(auto('DE', arabic: false), DateTime.monday);
    });

    test('with no region, Saturday in Arabic and Sunday in English', () {
      expect(auto(null), DateTime.saturday);
      expect(auto(null, arabic: false), DateTime.sunday);
    });

    test('a week holds its start day and the 6 days after it', () {
      final wednesday = DateTime(2026, 9, 23);
      expect(dateKey(weekStartFor(wednesday, DateTime.saturday)), '2026-09-19');
      expect(dateKey(weekStartFor(wednesday, DateTime.sunday)), '2026-09-20');
      expect(dateKey(weekStartFor(wednesday, DateTime.monday)), '2026-09-21');
      // A Saturday is already the start of its own Saturday week.
      final saturday = DateTime(2026, 9, 19);
      expect(dateKey(weekStartFor(saturday, DateTime.saturday)), '2026-09-19');
      final days = weekDays(weekStartFor(wednesday, DateTime.saturday));
      expect(days.length, 7);
      expect(dateKey(days.last), '2026-09-25');
      expect(dateKey(days[4]), '2026-09-23'); // the day we asked about
    });

    test('a planned day keeps its date whatever the time on it (DATE-1)', () {
      expect(dateKey(dateOnly(DateTime(2026, 9, 20, 23, 30))), '2026-09-20');
      expect(dateFromKey('2026-09-20'), DateTime(2026, 9, 20));
      expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05'); // padded
    });
  });

  // A Ramadan positioned near the app's FakeClock date (2026-09-19), not a
  // real table entry, so this doesn't depend on Umm al-Qura dates changing.
  final testRamadan = const RamadanMonth(1448, 2026, 9, 22, 30);

  group('RAM-1: slotsFor gives a day\'s slots in display order', () {
    test('an ordinary day (mode off) is the usual four, in order', () {
      expect(slotsFor(DateTime(2026, 9, 1), ramadan: false), [
        MealSlot.breakfast,
        MealSlot.lunch,
        MealSlot.dinner,
        MealSlot.snack,
      ]);
    });

    test('the mode is on, but the day is outside Ramadan: unchanged', () {
      expect(
        slotsFor(DateTime(2026, 9, 1), ramadan: true, month: testRamadan),
        [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner, MealSlot.snack],
      );
    });

    test('a Ramadan day with the mode on: suhoor, iftar, snack', () {
      expect(slotsFor(testRamadan.start, ramadan: true, month: testRamadan), [
        MealSlot.suhoor,
        MealSlot.iftar,
        MealSlot.snack,
      ]);
    });

    test('an entry already in an ordinary slot on a Ramadan day stays visible, '
        'under its own name and in its own order (RAM-1: nothing hidden)', () {
      expect(
        slotsFor(
          testRamadan.start,
          ramadan: true,
          month: testRamadan,
          withEntries: {MealSlot.lunch},
        ),
        [MealSlot.suhoor, MealSlot.iftar, MealSlot.snack, MealSlot.lunch],
      );
      expect(
        slotsFor(
          testRamadan.start,
          ramadan: true,
          month: testRamadan,
          withEntries: {MealSlot.dinner, MealSlot.breakfast},
        ),
        [
          MealSlot.suhoor,
          MealSlot.iftar,
          MealSlot.snack,
          MealSlot.breakfast, // breakfast before dinner either way
          MealSlot.dinner,
        ],
      );
    });

    test('an ordinary day only offers suhoor/iftar if they hold entries', () {
      expect(
        slotsFor(
          DateTime(2026, 9, 1),
          ramadan: false,
          withEntries: {MealSlot.suhoor},
        ),
        [
          MealSlot.breakfast,
          MealSlot.lunch,
          MealSlot.dinner,
          MealSlot.snack,
          MealSlot.suhoor,
        ],
      );
    });
  });

  group('RAM-1: slotOnDay maps a slot the day does not offer (must-fix)', () {
    const ramadanSlots = [MealSlot.suhoor, MealSlot.iftar, MealSlot.snack];
    const ordinarySlots = [
      MealSlot.breakfast,
      MealSlot.lunch,
      MealSlot.dinner,
      MealSlot.snack,
    ];

    test('already offered: stays as it is', () {
      expect(slotOnDay(MealSlot.iftar, ramadanSlots), MealSlot.iftar);
      expect(slotOnDay(MealSlot.lunch, ordinarySlots), MealSlot.lunch);
    });

    test('breakfast/lunch/dinner map onto a Ramadan day\'s own slots', () {
      expect(slotOnDay(MealSlot.breakfast, ramadanSlots), MealSlot.suhoor);
      expect(slotOnDay(MealSlot.lunch, ramadanSlots), MealSlot.iftar);
      expect(slotOnDay(MealSlot.dinner, ramadanSlots), MealSlot.iftar);
    });

    test('suhoor/iftar map back onto an ordinary day\'s slots', () {
      expect(slotOnDay(MealSlot.suhoor, ordinarySlots), MealSlot.breakfast);
      // iftar -> lunch (the day's main meal), not dinner.
      expect(slotOnDay(MealSlot.iftar, ordinarySlots), MealSlot.lunch);
    });

    test('nothing offered falls back to the slot itself', () {
      expect(slotOnDay(MealSlot.lunch, const []), MealSlot.lunch);
    });
  });

  group('RAM-2: ramadanMonthForShiftRow picks a stable year (should-fix)', () {
    final months = [
      const RamadanMonth(1447, 2026, 8, 21, 30), // last day 2026-09-19
      const RamadanMonth(1448, 2027, 8, 10, 29),
    ];

    test('on the last day, with no shift, still shows this year', () {
      final m = ramadanMonthForShiftRow(DateTime(2026, 9, 19), months: months);
      expect(m?.hijriYear, 1447);
    });

    test('a -1 shift making "today" Eid does not flip the row to next year '
        '(the bug: currentOrNextRamadanIn would)', () {
      int shiftFor(int y) => y == 1447 ? -1 : 0;
      // Sanity check: this is exactly the case the plain lookup gets
      // wrong, jumping a year early.
      expect(
        currentOrNextRamadanIn(
          DateTime(2026, 9, 19),
          months: months,
          shiftFor: shiftFor,
        )?.hijriYear,
        1448,
      );
      final m = ramadanMonthForShiftRow(
        DateTime(2026, 9, 19),
        months: months,
        shiftFor: shiftFor,
      );
      expect(m?.hijriYear, 1447);
      expect(dateKey(m!.start), '2026-08-20'); // the -1 shift still shows
    });

    test('a +1 shift the day after the unshifted last day is still covered '
        '(the grace day)', () {
      final m = ramadanMonthForShiftRow(DateTime(2026, 9, 20), months: months);
      expect(m?.hijriYear, 1447);
    });

    test(
      'two days after the last day, past every possible shift: moves on',
      () {
        final m = ramadanMonthForShiftRow(
          DateTime(2026, 9, 21),
          months: months,
        );
        expect(m?.hijriYear, 1448);
      },
    );
  });

  group('RAM-2: the injected Ramadan calendar', () {
    test('ramadanMonthContaining finds the day inside, shifted (RAM-2)', () {
      expect(
        ramadanMonthContaining(
          testRamadan.start,
          months: [testRamadan],
        )?.hijriYear,
        1448,
      );
      expect(
        ramadanMonthContaining(DateTime(2026, 9, 21), months: [testRamadan]),
        isNull,
      );
      final shifted = ramadanMonthContaining(
        DateTime(2026, 9, 21),
        months: [testRamadan],
        shiftFor: (_) => -1, // a day earlier, so the 21st is now day 1
      );
      expect(shifted?.start, DateTime(2026, 9, 21));
    });

    test('currentOrNextRamadanIn picks the next one, shifted (RAM-2)', () {
      expect(
        currentOrNextRamadanIn(
          DateTime(2026, 9, 19),
          months: [testRamadan],
        )?.start,
        testRamadan.start,
      );
      expect(
        currentOrNextRamadanIn(DateTime(2026, 11, 1), months: [testRamadan]),
        isNull, // past the (single-entry) table
      );
    });

    test('inRamadanWindow: 7 days before through the last day (RAM-3)', () {
      expect(inRamadanWindow(DateTime(2026, 9, 15), testRamadan), isTrue);
      expect(inRamadanWindow(DateTime(2026, 9, 14), testRamadan), isFalse);
      expect(inRamadanWindow(testRamadan.last, testRamadan), isTrue);
      expect(inRamadanWindow(testRamadan.eid, testRamadan), isFalse);
    });

    test('daysUntilRamadan counts down, 0 or less once it started', () {
      expect(daysUntilRamadan(DateTime(2026, 9, 19), testRamadan), 3);
      expect(daysUntilRamadan(testRamadan.start, testRamadan), 0);
      expect(daysUntilRamadan(DateTime(2026, 9, 25), testRamadan), -3);
    });
  });

  group('RAM-3: ramadanCard', () {
    test('the countdown, while off, in the window, not dismissed', () {
      final card = ramadanCard(testRamadan, DateTime(2026, 9, 19), mode: false);
      expect((card!.daysUntil, card.started), (3, false));
    });

    test('"started" once Ramadan has (the "كريم" text)', () {
      expect(
        ramadanCard(testRamadan, testRamadan.start, mode: false)!.started,
        isTrue,
      );
    });

    test('null while the mode is on: it never turns itself on', () {
      expect(
        ramadanCard(testRamadan, DateTime(2026, 9, 19), mode: true),
        isNull,
      );
    });

    test('null once dismissed for this Ramadan\'s Hijri year, not another', () {
      expect(
        ramadanCard(
          testRamadan,
          DateTime(2026, 9, 19),
          mode: false,
          dismissedYear: 1448,
        ),
        isNull,
      );
      expect(
        ramadanCard(
          testRamadan,
          DateTime(2026, 9, 19),
          mode: false,
          dismissedYear: 1447,
        ),
        isNotNull,
      );
    });

    test('null outside the window, or with no Ramadan at all', () {
      expect(
        ramadanCard(testRamadan, DateTime(2026, 9, 14), mode: false),
        isNull,
      );
      expect(ramadanCard(testRamadan, testRamadan.eid, mode: false), isNull);
      expect(ramadanCard(null, DateTime(2026, 9, 19), mode: false), isNull);
    });
  });
}
