import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:wasfati/models/ramadan.dart';

/// The table entry for a given Hijri year, so tests read by year, not index.
RamadanMonth _year(int hijriYear) =>
    ramadanTable.firstWhere((m) => m.hijriYear == hijriYear);

void main() {
  group('RAM-2: the Umm al-Qura table', () {
    test('1 Ramadan 1445 is 11 March 2024 (public record)', () {
      final m = _year(1445);
      expect(m.start, DateTime(2024, 3, 11));
    });

    test('1 Ramadan 1446 is 1 March 2025 (public record)', () {
      final m = _year(1446);
      expect(m.start, DateTime(2025, 3, 1));
    });

    test('1 Ramadan 1448 falls between 6 and 10 February 2027 '
        '(roadmap launch anchor)', () {
      final m = _year(1448);
      expect(m.start.isAfter(DateTime(2027, 2, 5)), isTrue);
      expect(m.start.isBefore(DateTime(2027, 2, 11)), isTrue);
    });

    test('runs 1445 through 1480 unbroken, oldest first', () {
      expect(ramadanTable.first.hijriYear, 1445);
      expect(ramadanTable.last.hijriYear, 1480);
      expect(ramadanTable.length, 36);
      for (var i = 1; i < ramadanTable.length; i++) {
        expect(
          ramadanTable[i].hijriYear,
          ramadanTable[i - 1].hijriYear + 1,
          reason: 'entry $i does not follow the previous Hijri year',
        );
      }
    });

    test('every month is 29 or 30 days', () {
      for (final m in ramadanTable) {
        expect(
          m.length,
          anyOf(29, 30),
          reason: 'hijriYear ${m.hijriYear} has length ${m.length}',
        );
      }
    });

    test('each start is 353-356 days after the previous one '
        "(a Hijri year is 354 or 355 days, ±1 for Umm al-Qura's "
        'irregular months)', () {
      for (var i = 1; i < ramadanTable.length; i++) {
        final diff = ramadanTable[i].start
            .difference(ramadanTable[i - 1].start)
            .inDays;
        expect(
          diff,
          inInclusiveRange(353, 356),
          reason:
              'hijriYear ${ramadanTable[i].hijriYear} starts $diff days '
              'after ${ramadanTable[i - 1].hijriYear}',
        );
      }
    });
  });

  group('RamadanMonth.dayOf and contains', () {
    // 1445: 11 March 2024, 30 days -> last day 9 April, eid 10 April.
    final ramadan1445 = _year(1445);

    test('day 1 is 1 Ramadan', () {
      expect(ramadan1445.dayOf(DateTime(2024, 3, 11)), 1);
      expect(ramadan1445.contains(DateTime(2024, 3, 11)), isTrue);
    });

    test('the last day is [length]', () {
      expect(ramadan1445.dayOf(DateTime(2024, 4, 9)), 30);
      expect(ramadan1445.contains(DateTime(2024, 4, 9)), isTrue);
    });

    test('the day before Ramadan is outside it', () {
      expect(ramadan1445.dayOf(DateTime(2024, 3, 10)), isNull);
      expect(ramadan1445.contains(DateTime(2024, 3, 10)), isFalse);
    });

    test('Eid (1 Shawwal) is outside Ramadan', () {
      expect(ramadan1445.eid, DateTime(2024, 4, 10));
      expect(ramadan1445.dayOf(DateTime(2024, 4, 10)), isNull);
      expect(ramadan1445.contains(DateTime(2024, 4, 10)), isFalse);
    });

    test('shifted(+1) moves every day of the month, start to last', () {
      final shifted = ramadan1445.shifted(1);
      expect(shifted.hijriYear, ramadan1445.hijriYear);
      expect(shifted.length, ramadan1445.length);
      expect(shifted.start, ramadan1445.start.add(const Duration(days: 1)));
      expect(shifted.last, ramadan1445.last.add(const Duration(days: 1)));
      expect(shifted.eid, ramadan1445.eid.add(const Duration(days: 1)));
      for (var i = 0; i < ramadan1445.length; i++) {
        final movedDay = ramadan1445.start.add(Duration(days: i + 1));
        expect(
          shifted.dayOf(movedDay),
          i + 1,
          reason: 'day ${i + 1} did not move with the rest of the month',
        );
      }
    });

    group('DATE-1: a DST change is counted by calendar days, not hours', () {
      setUpAll(tzdata.initializeTimeZones);

      // dayOf only ever reads [date]'s year/month/day fields, so the field
      // checks below hold whatever the machine's own time zone is (this
      // suite runs on a fixed-offset host with no DST of its own) — they
      // don't by themselves prove the *arithmetic* is DST-safe. That's
      // what calendarDaysBetween is tested for directly, below: it's fed
      // two real instants (via package:timezone, independent of the host)
      // that a naive `.difference().inDays` gets wrong.
      test('calendarDaysBetween counts calendar days, not elapsed hours '
          '(should-fix: the previous DST tests here could not actually '
          'fail on this host)', () {
        final ny = tz.getLocation('America/New_York');
        // Spring forward, 10 March 2024: that local day is only 23h.
        final beforeSpring = tz.TZDateTime(ny, 2024, 3, 10);
        final afterSpring = tz.TZDateTime(ny, 2024, 3, 11);
        expect(calendarDaysBetween(beforeSpring, afterSpring), 1);
        // What the old `.difference().inDays` code did instead: rounded
        // the 23-hour gap down to 0, losing a day (the bug DATE-1 rules
        // out).
        expect(afterSpring.difference(beforeSpring).inDays, 0);

        // Fall back, 3 November 2024: that local day is 25h.
        final beforeFall = tz.TZDateTime(ny, 2024, 11, 3);
        final afterFall = tz.TZDateTime(ny, 2024, 11, 4);
        expect(calendarDaysBetween(beforeFall, afterFall), 1);
      });

      test('spring-forward (Europe/London, 31 March 2024, a 23-hour day)', () {
        final london = tz.getLocation('Europe/London');
        // Synthetic fixture, not a table entry: 25 March-3 April 2024,
        // chosen only because it straddles the UK's spring DST change.
        const fixture = RamadanMonth(9990, 2024, 3, 25, 10);
        expect(fixture.dayOf(tz.TZDateTime(london, 2024, 3, 30)), 6);
        expect(fixture.dayOf(tz.TZDateTime(london, 2024, 3, 31)), 7);
        expect(fixture.dayOf(tz.TZDateTime(london, 2024, 4, 1)), 8);
      });

      test('fall-back (Europe/London, 27 October 2024, a 25-hour day)', () {
        final london = tz.getLocation('Europe/London');
        // Synthetic fixture, not a table entry: 24-31 October 2024,
        // chosen only because it straddles the UK's autumn DST change.
        const fixture = RamadanMonth(9991, 2024, 10, 24, 8);
        expect(fixture.dayOf(tz.TZDateTime(london, 2024, 10, 26)), 3);
        expect(fixture.dayOf(tz.TZDateTime(london, 2024, 10, 27)), 4);
        expect(fixture.dayOf(tz.TZDateTime(london, 2024, 10, 28)), 5);
      });
    });
  });

  group('RAM-2: currentOrNextRamadan', () {
    test('during Ramadan, returns that Ramadan', () {
      final m = _year(1450); // 16 January 2029, 29 days.
      final today = m.start.add(const Duration(days: 5));
      final result = currentOrNextRamadan(today);
      expect(result?.hijriYear, 1450);
    });

    test('on the day Ramadan ends, still returns that Ramadan', () {
      final m = _year(1450);
      final result = currentOrNextRamadan(m.last);
      expect(result?.hijriYear, 1450);
    });

    test('the day after it ends (Eid), returns next year\'s Ramadan', () {
      final m = _year(1450);
      final result = currentOrNextRamadan(m.eid);
      expect(result?.hijriYear, 1451);
    });

    test('past the table, returns null', () {
      final result = currentOrNextRamadan(
        ramadanTable.last.eid.add(const Duration(days: 1)),
      );
      expect(result, isNull);
    });

    test('shiftFor applies per Hijri year only', () {
      // Shifts 1447 a day later and leaves every other year alone.
      int shiftFor(int hijriYear) => hijriYear == 1447 ? 1 : 0;

      final unshifted1447 = _year(1447);
      final onOriginalStart = currentOrNextRamadan(
        unshifted1447.start,
        shiftFor: shiftFor,
      );
      // The unshifted table start is now the day *before* the shifted
      // Ramadan begins, so it still counts as "not yet started": the
      // shifted 1447 still qualifies as current (its shifted last day is
      // on or after today).
      expect(onOriginalStart?.hijriYear, 1447);
      expect(
        onOriginalStart?.start,
        unshifted1447.start.add(const Duration(days: 1)),
      );

      // A neighboring year is untouched by the 1447-only shift.
      final unshifted1446 = _year(1446);
      final onNeighborStart = currentOrNextRamadan(
        unshifted1446.start,
        shiftFor: shiftFor,
      );
      expect(onNeighborStart?.hijriYear, 1446);
      expect(onNeighborStart?.start, unshifted1446.start);
    });
  });
}
