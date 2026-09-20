import 'quantity/rational.dart';
import 'settings.dart';

/// The meals a day is planned by, in the order they're shown (PLAN-1).
/// Ramadan mode swaps these for suhoor and iftar on Ramadan days (RAM-1).
enum MealSlot { breakfast, lunch, dinner, snack }

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
