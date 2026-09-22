import 'quantity/rational.dart';
import 'ramadan.dart';
import 'settings.dart';

/// The meals a day is planned by (PLAN-1). [suhoor] and [iftar] are
/// appended after [snack] so they're stored by name (`slot.name`, see
/// [PlanEntry.toMap]) and never disturb the others' saved rows (RAM-1).
/// Which of these a given day actually shows, and in what order, comes
/// from [slotsFor] — never this raw declaration order.
enum MealSlot { breakfast, lunch, dinner, snack, suhoor, iftar }

/// A day's slots, in display order (RAM-1):
/// - An ordinary day (or Ramadan mode off): breakfast, lunch, dinner,
///   snack, then suhoor/iftar only if [withEntries] already has them —
///   they're never normally offered outside Ramadan.
/// - A Ramadan day with the mode on: suhoor, iftar, snack, then any of
///   breakfast/lunch/dinner in [withEntries], under their own name, so
///   nothing already planned is hidden.
List<MealSlot> slotsFor(
  DateTime day, {
  required bool ramadan,
  RamadanMonth? month,
  Set<MealSlot> withEntries = const {},
}) {
  final inRamadan = ramadan && (month?.contains(dateOnly(day)) ?? false);
  if (inRamadan) {
    return [
      MealSlot.suhoor,
      MealSlot.iftar,
      MealSlot.snack,
      for (final s in [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner])
        if (withEntries.contains(s)) s,
    ];
  }
  return [
    MealSlot.breakfast,
    MealSlot.lunch,
    MealSlot.dinner,
    MealSlot.snack,
    for (final s in [MealSlot.suhoor, MealSlot.iftar])
      if (withEntries.contains(s)) s,
  ];
}

/// Maps [wanted] onto one of [offered] when it isn't already there
/// (RAM-1): so a preselected or previously picked meal that the current
/// day doesn't show — the last meal used before Ramadan started, or the
/// last one used inside it — lands on that day's real equivalent instead
/// of silently offering a slot the day hides (must-fix). Falls back to
/// the first offered slot, or [wanted] itself if nothing is offered
/// (never happens in practice: every day offers at least one slot).
MealSlot slotOnDay(MealSlot wanted, List<MealSlot> offered) {
  if (offered.contains(wanted)) return wanted;
  const toRamadan = {
    MealSlot.breakfast: MealSlot.suhoor,
    MealSlot.lunch: MealSlot.iftar,
    MealSlot.dinner: MealSlot.iftar,
  };
  // iftar -> lunch, not dinner: lunch is the day's main meal (PLAN-1's
  // own order), the closest ordinary equivalent of iftar.
  const toOrdinary = {
    MealSlot.suhoor: MealSlot.breakfast,
    MealSlot.iftar: MealSlot.lunch,
  };
  final mapped = toRamadan[wanted] ?? toOrdinary[wanted];
  if (mapped != null && offered.contains(mapped)) return mapped;
  return offered.isNotEmpty ? offered.first : wanted;
}

/// The Ramadan month [day] falls in, from [months] (default the built-in
/// table), shifted per [shiftFor] (RAM-2). Mirrors [RamadanMonth.contains]
/// over a whole calendar, for a specific day rather than "today".
RamadanMonth? ramadanMonthContaining(
  DateTime day, {
  List<RamadanMonth> months = ramadanTable,
  int Function(int hijriYear)? shiftFor,
}) {
  final d = dateOnly(day);
  for (final m in months) {
    final shifted = m.shifted(shiftFor?.call(m.hijriYear) ?? 0);
    // Skip the day-by-day check unless [d] can possibly be in this month
    // (should-fix, performance): looking up a day outside any Ramadan
    // used to check all 36 rows regardless.
    if (d.isBefore(shifted.start) || shifted.last.isBefore(d)) continue;
    if (shifted.contains(d)) return shifted;
  }
  return null;
}

/// The Ramadan [today] is in, or the next one, from [months] (default the
/// built-in table); shifted per [shiftFor] (RAM-2). The same rule as
/// [currentOrNextRamadan], but over an injectable calendar, so Ramadan
/// mode's own tests don't depend on the real dates in [ramadanTable].
RamadanMonth? currentOrNextRamadanIn(
  DateTime today, {
  List<RamadanMonth> months = ramadanTable,
  int Function(int hijriYear)? shiftFor,
}) {
  final d = dateOnly(today);
  for (final m in months) {
    final r = m.shifted(shiftFor?.call(m.hijriYear) ?? 0);
    if (!r.last.isBefore(d)) return r;
  }
  return null;
}

/// The Ramadan month Settings' shift row should show for [today] (RAM-2):
/// the same year [currentOrNextRamadanIn] would, but decided without the
/// shift being edited for that year, and with one extra day of grace past
/// its unshifted last day.
///
/// Without the grace, editing the shift right at the boundary can flip
/// which year the row targets mid-edit: on the last day of Ramadan,
/// shifting -1 turns "today" into Eid, so a plain [currentOrNextRamadanIn]
/// call would jump the row to next year — and since only one shift is
/// stored per year (BAK-6), pressing "+" next would then silently
/// overwrite *that* year's shift instead of undoing this one's
/// (should-fix). The extra day covers every shift from -1 to +1, so the
/// row stays on the same year for the whole time any of those shifts
/// could apply to it.
RamadanMonth? ramadanMonthForShiftRow(
  DateTime today, {
  List<RamadanMonth> months = ramadanTable,
  int Function(int hijriYear)? shiftFor,
}) {
  final d = dateOnly(today);
  for (final m in months) {
    if (!m.shifted(1).last.isBefore(d)) {
      return m.shifted(shiftFor?.call(m.hijriYear) ?? 0);
    }
  }
  return null;
}

/// Whether [today] is anywhere from 7 days before [month] to its last day
/// (RAM-3, RAM-4): the window the card and the "رمضان" view can appear in.
bool inRamadanWindow(DateTime today, RamadanMonth month) {
  final d = dateOnly(today);
  final windowStart = DateTime(month.year, month.month, month.day - 7);
  return !d.isBefore(windowStart) && !d.isAfter(month.last);
}

/// Days from [today] until [month] starts; 0 or negative once it has
/// (RAM-3's count). Counted with [calendarDaysBetween], not
/// [DateTime.difference] (DATE-1): a daylight-saving change between
/// [today] and [month]'s start must never drop or add a day.
int daysUntilRamadan(DateTime today, RamadanMonth month) =>
    calendarDaysBetween(dateOnly(today), month.start);

/// RAM-3's card: shown while the mode is off, [today] is in the window
/// (RAM-3, RAM-4) and it wasn't dismissed for this Ramadan's Hijri year
/// already; null otherwise. The mode never turns itself on.
class RamadanCard {
  const RamadanCard(this.month, this.daysUntil);

  final RamadanMonth month;

  /// Days until [month] starts; 0 or less once Ramadan has (the card then
  /// reads "رمضان كريم" instead of a countdown).
  final int daysUntil;

  bool get started => daysUntil <= 0;
}

RamadanCard? ramadanCard(
  RamadanMonth? month,
  DateTime today, {
  required bool mode,
  int? dismissedYear,
}) {
  if (mode || month == null) return null;
  if (dismissedYear == month.hijriYear) return null;
  if (!inRamadanWindow(today, month)) return null;
  return RamadanCard(month, daysUntilRamadan(today, month));
}

/// One planned meal (PLAN-2): a recipe or a short note, on one day, in one
/// slot. A recipe entry carries its own servings, which scale what it sends
/// to groceries (PLAN-5); the recipe itself never changes.
class PlanEntry {
  const PlanEntry({
    required this.id,
    required this.date,
    required this.slot,
    this.recipeId,
    this.note,
    this.servings,
    this.multiplier,
    this.position = 0,
    this.addedToGroceriesAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  static const maxNote = 60; // PLAN-2
  static const maxServings = 100; // REC-7
  static const maxPerSlot = 10; // PLAN-2

  /// What a recipe with no servings can be planned by instead (SCALE-2).
  static final List<Rational> multipliers = [
    Rational.half,
    Rational.one,
    Rational(2),
    Rational(3),
  ];

  final String id;

  /// A local calendar date with no time, so the entry stays on its day
  /// whatever the time zone (DATE-1).
  final DateTime date;
  final MealSlot slot;

  /// Set for a recipe entry; [note] is set instead for a written one.
  final String? recipeId;
  final String? note;

  /// How many people this meal is for (1–100), or null to follow the recipe.
  final int? servings;

  /// Used instead of [servings] when the recipe has none (SCALE-2).
  final Rational? multiplier;

  final int position;

  /// When this entry's ingredients were last added to the grocery list, so
  /// adding a week twice doesn't double it (PLAN-5).
  final DateTime? addedToGroceriesAt;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isNote => recipeId == null;

  PlanEntry copyWith({
    DateTime? date,
    MealSlot? slot,
    String? id,
    String? note,
    int? servings,
    Rational? multiplier,
    int? position,
    DateTime? addedToGroceriesAt,
    DateTime? updatedAt,
  }) => PlanEntry(
    id: id ?? this.id,
    date: date ?? this.date,
    slot: slot ?? this.slot,
    recipeId: recipeId,
    note: note ?? this.note,
    servings: servings ?? this.servings,
    multiplier: multiplier ?? this.multiplier,
    position: position ?? this.position,
    addedToGroceriesAt: addedToGroceriesAt ?? this.addedToGroceriesAt,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt,
  );

  /// What's wrong with this entry, or null when it's fine (PLAN-2).
  String? validate() {
    final text = note?.trim() ?? '';
    if ((recipeId == null) == text.isEmpty) return 'recipe or note';
    if (recipeId == null) {
      if (text.length > maxNote) return 'note is longer than $maxNote';
      if (servings != null || multiplier != null) return 'a note has no amount';
      return null;
    }
    if (servings != null && multiplier != null) return 'servings or multiplier';
    if (servings != null && (servings! < 1 || servings! > maxServings)) {
      return 'servings is not 1–$maxServings';
    }
    if (multiplier != null && !multipliers.contains(multiplier)) {
      return 'unknown multiplier';
    }
    return null;
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'date': dateKey(date),
    'slot': slot.name,
    'recipe_id': recipeId,
    'note': note?.trim(),
    'servings': servings,
    'mult_num': multiplier?.numerator,
    'mult_den': multiplier?.denominator,
    'position': position,
    'added_to_groceries_at': addedToGroceriesAt?.millisecondsSinceEpoch,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
  };

  factory PlanEntry.fromMap(Map<String, Object?> m) {
    final num = m['mult_num'] as int?;
    final den = m['mult_den'] as int?;
    return PlanEntry(
      id: m['id']! as String,
      date: dateFromKey(m['date']! as String),
      slot: MealSlot.values.firstWhere(
        (s) => s.name == m['slot'],
        orElse: () => MealSlot.dinner,
      ),
      recipeId: m['recipe_id'] as String?,
      note: m['note'] as String?,
      servings: m['servings'] as int?,
      multiplier: num == null || den == null ? null : Rational(num, den),
      position: (m['position'] as int?) ?? 0,
      addedToGroceriesAt: _time(m['added_to_groceries_at']),
      createdAt: _time(m['created_at'])!,
      updatedAt: _time(m['updated_at'])!,
      deletedAt: _time(m['deleted_at']),
    );
  }
}

/// The same day with the time dropped (DATE-1).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `2026-09-20`, how a day is stored and compared.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime dateFromKey(String key) => DateTime(
  int.parse(key.substring(0, 4)),
  int.parse(key.substring(5, 7)),
  int.parse(key.substring(8, 10)),
);

/// Regions whose week starts on Saturday, from Unicode CLDR's first-day
/// data (PLAN-1). Everything not listed here or in [_sundayRegions] starts
/// on Monday, CLDR's own default.
const _saturdayRegions = {
  'AE', 'AF', 'BH', 'DJ', 'DZ', 'EG', 'IQ', 'IR', //
  'JO', 'KW', 'LY', 'OM', 'QA', 'SD', 'SY',
};

const _sundayRegions = {
  'BD', 'BR', 'BS', 'BW', 'BZ', 'CA', 'CO', 'DO', 'ET', 'GT', 'HK', 'HN', //
  'ID', 'IL', 'IN', 'JM', 'JP', 'KE', 'KH', 'KR', 'LA', 'MM', 'MO', 'MT',
  'MX', 'MZ', 'NI', 'NP', 'PA', 'PE', 'PH', 'PK', 'PR', 'PT', 'PY', 'SA',
  'SG', 'SV', 'TH', 'TT', 'TW', 'US', 'VE', 'YE', 'ZA', 'ZW',
};

/// Which weekday a week starts on (PLAN-1): the setting when it names a
/// day, else the phone's [region] from CLDR's data, else Saturday in Arabic
/// and Sunday in English.
int firstWeekday(WeekStart pref, {String? region, required bool arabic}) {
  switch (pref) {
    case WeekStart.saturday:
      return DateTime.saturday;
    case WeekStart.sunday:
      return DateTime.sunday;
    case WeekStart.monday:
      return DateTime.monday;
    case WeekStart.auto:
      final r = region?.toUpperCase();
      if (r != null && _saturdayRegions.contains(r)) return DateTime.saturday;
      if (r != null && _sundayRegions.contains(r)) return DateTime.sunday;
      if (r != null) return DateTime.monday;
      return arabic ? DateTime.saturday : DateTime.sunday;
  }
}

/// The start of the week [day] falls in, for a week starting on [first].
DateTime weekStartFor(DateTime day, int first) {
  final d = dateOnly(day);
  final back = (d.weekday - first + 7) % 7;
  return DateTime(d.year, d.month, d.day - back);
}

/// The 7 days of the week beginning at [start].
List<DateTime> weekDays(DateTime start) => [
  for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i),
];

DateTime? _time(Object? ms) => ms == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);
