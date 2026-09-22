/// One Ramadan, by the Umm al-Qura calendar built into the app (RAM-2).
class RamadanMonth {
  const RamadanMonth(
    this.hijriYear,
    this.year,
    this.month,
    this.day,
    this.length,
  );

  final int hijriYear; // e.g. 1448
  final int year; // 1 Ramadan, as a local calendar date (DATE-1)
  final int month;
  final int day;
  final int length; // 29 or 30

  /// 1 Ramadan.
  DateTime get start => DateTime(year, month, day);

  /// The last day of Ramadan.
  DateTime get last => DateTime(year, month, day + length - 1);

  /// 1 Shawwal, عيد الفطر (RAM-2).
  DateTime get eid => DateTime(year, month, day + length);

  /// Moved a day earlier or later for the local moon sighting (RAM-2).
  RamadanMonth shifted(int days) {
    final s = DateTime(year, month, day + days);
    return RamadanMonth(hijriYear, s.year, s.month, s.day, length);
  }

  /// The day of Ramadan [date] is (1 to [length]), or null outside it.
  int? dayOf(DateTime date) {
    // A calendar-day count (DATE-1), not a division of a 24-hour span, so
    // a daylight-saving change can't shift it — see [calendarDaysBetween].
    // O(1): looking this up for every day of a range used to walk up to
    // [length] local dates each time (should-fix, performance).
    final n = calendarDaysBetween(start, date);
    return n >= 0 && n < length ? n + 1 : null;
  }

  /// Whether [date] is in Ramadan.
  bool contains(DateTime date) => dayOf(date) != null;
}

/// Whole calendar days from [from] to [to] (negative if [to] is earlier),
/// counted on the calendar date alone (DATE-1). [DateTime.difference]
/// instead divides the real elapsed time by 24 hours, which is wrong by a
/// day across a daylight-saving change — e.g. two local midnights either
/// side of a spring-forward are only 23 hours apart. Using `.utc(...)` on
/// each date's own year/month/day sidesteps that: UTC has no DST, so the
/// gap between two UTC midnights always divides evenly.
int calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Ramadan start dates and lengths from the Umm al-Qura calendar, oldest
/// first (RAM-2). No network: this table is the calendar.
///
/// Generated, not typed from memory: computed by calling
/// `HijriCalendar().hijriToGregorian(hijriYear, 9, 1)` (1 Ramadan) and
/// `hijriToGregorian(hijriYear, 10, 1)` (1 Shawwal, so length = the day
/// difference) from the `hijri` package v3.0.1 (BSD-3-Clause,
/// https://pub.dev/packages/hijri), whose Umm al-Qura lunation table lives
/// in `lib/hijri_array.dart` (`ummAlquraDateArray`). Computed with a
/// throwaway script run outside `lib/` (`dart pub cache add hijri`, then
/// `dart run` against a scratch project depending on it); the `hijri`
/// package itself is not a dependency of this app.
const List<RamadanMonth> ramadanTable = [
  RamadanMonth(1445, 2024, 3, 11, 30), // 1 Shawwal 2024-04-10
  RamadanMonth(1446, 2025, 3, 1, 29), // 1 Shawwal 2025-03-30
  RamadanMonth(1447, 2026, 2, 18, 30), // 1 Shawwal 2026-03-20
  RamadanMonth(1448, 2027, 2, 8, 29), // 1 Shawwal 2027-03-09
  RamadanMonth(1449, 2028, 1, 28, 29), // 1 Shawwal 2028-02-26
  RamadanMonth(1450, 2029, 1, 16, 29), // 1 Shawwal 2029-02-14
  RamadanMonth(1451, 2030, 1, 5, 30), // 1 Shawwal 2030-02-04
  RamadanMonth(1452, 2030, 12, 26, 29), // 1 Shawwal 2031-01-24
  RamadanMonth(1453, 2031, 12, 15, 30), // 1 Shawwal 2032-01-14
  RamadanMonth(1454, 2032, 12, 4, 29), // 1 Shawwal 2033-01-02
  RamadanMonth(1455, 2033, 11, 23, 30), // 1 Shawwal 2033-12-23
  RamadanMonth(1456, 2034, 11, 12, 30), // 1 Shawwal 2034-12-12
  RamadanMonth(1457, 2035, 11, 1, 30), // 1 Shawwal 2035-12-01
  RamadanMonth(1458, 2036, 10, 20, 30), // 1 Shawwal 2036-11-19
  RamadanMonth(1459, 2037, 10, 10, 29), // 1 Shawwal 2037-11-08
  RamadanMonth(1460, 2038, 9, 30, 29), // 1 Shawwal 2038-10-29
  RamadanMonth(1461, 2039, 9, 19, 30), // 1 Shawwal 2039-10-19
  RamadanMonth(1462, 2040, 9, 7, 30), // 1 Shawwal 2040-10-07
  RamadanMonth(1463, 2041, 8, 28, 29), // 1 Shawwal 2041-09-26
  RamadanMonth(1464, 2042, 8, 17, 29), // 1 Shawwal 2042-09-15
  RamadanMonth(1465, 2043, 8, 6, 29), // 1 Shawwal 2043-09-04
  RamadanMonth(1466, 2044, 7, 26, 29), // 1 Shawwal 2044-08-24
  RamadanMonth(1467, 2045, 7, 15, 30), // 1 Shawwal 2045-08-14
  RamadanMonth(1468, 2046, 7, 5, 29), // 1 Shawwal 2046-08-03
  RamadanMonth(1469, 2047, 6, 24, 30), // 1 Shawwal 2047-07-24
  RamadanMonth(1470, 2048, 6, 12, 30), // 1 Shawwal 2048-07-12
  RamadanMonth(1471, 2049, 6, 2, 29), // 1 Shawwal 2049-07-01
  RamadanMonth(1472, 2050, 5, 22, 29), // 1 Shawwal 2050-06-20
  RamadanMonth(1473, 2051, 5, 11, 30), // 1 Shawwal 2051-06-10
  RamadanMonth(1474, 2052, 4, 30, 29), // 1 Shawwal 2052-05-29
  RamadanMonth(1475, 2053, 4, 20, 29), // 1 Shawwal 2053-05-19
  RamadanMonth(1476, 2054, 4, 9, 30), // 1 Shawwal 2054-05-09
  RamadanMonth(1477, 2055, 3, 29, 30), // 1 Shawwal 2055-04-28
  RamadanMonth(1478, 2056, 3, 17, 30), // 1 Shawwal 2056-04-16
  RamadanMonth(1479, 2057, 3, 6, 30), // 1 Shawwal 2057-04-05
  RamadanMonth(1480, 2058, 2, 24, 29), // 1 Shawwal 2058-03-25
];

/// The Ramadan [today] is in, or else the next one; null past the table.
/// [shiftFor] gives the user's sighting shift for a Hijri year (RAM-2).
RamadanMonth? currentOrNextRamadan(
  DateTime today, {
  int Function(int hijriYear)? shiftFor,
}) {
  final d = DateTime(today.year, today.month, today.day);
  for (final m in ramadanTable) {
    final r = m.shifted(shiftFor?.call(m.hijriYear) ?? 0);
    if (!r.last.isBefore(d)) return r;
  }
  return null;
}
