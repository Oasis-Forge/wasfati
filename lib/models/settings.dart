import 'dart:convert';

import 'grocery.dart';
import 'library.dart';
import 'quantity/format.dart';

enum LanguagePref { system, ar, en }

/// SCALE-5: which view conversion shows by default.
enum UnitSystem { metric, kitchen }

/// Meal-plan week start; [auto] is Saturday in the Gulf (roadmap 2a).
enum WeekStart { auto, saturday, sunday, monday }

enum ThemePref { system, light, dark }

/// The user's settings, stored as one JSON value in the meta table.
class AppSettings {
  const AppSettings({
    this.language = LanguagePref.system,
    this.digits = DigitStyle.western, // Decision 5
    this.units = UnitSystem.metric,
    this.weekStart = WeekStart.auto,
    this.theme = ThemePref.system,
    this.sort = LibrarySort.recent,
    this.grid = false,
    this.groceryView = GroceryView.byAisle,
    this.ramadanMode = false, // RAM-1: off by default
    this.ramadanShift = 0, // RAM-2: -1, 0 or +1 days
    this.ramadanShiftYear, // the Hijri year ramadanShift is for
    this.ramadanCardDismissedYear, // RAM-3: "ليس الآن", per Hijri year
  });

  final LanguagePref language;
  final DigitStyle digits;
  final UnitSystem units;
  final WeekStart weekStart;
  final ThemePref theme;

  /// The library order and view, remembered (ORG-5).
  final LibrarySort sort;
  final bool grid;

  /// The grocery list's "By aisle"/"By recipe" choice, remembered (GRO-5).
  final GroceryView groceryView;

  /// Whether Ramadan mode is on (RAM-1). Never turned on by the app itself.
  final bool ramadanMode;

  /// The local moon-sighting shift, −1 to +1 days (RAM-2), for the Hijri
  /// year in [ramadanShiftYear]. A shift for another year reads as 0
  /// (see [ramadanShiftFor]), so it resets for the next Ramadan.
  final int ramadanShift;
  final int? ramadanShiftYear;

  /// The Hijri year RAM-3's card was last dismissed for with "ليس الآن",
  /// or null if it never was (for the current one).
  final int? ramadanCardDismissedYear;

  /// The sighting shift that applies to [hijriYear] (RAM-2): [ramadanShift]
  /// when it was set for that year, else 0.
  int ramadanShiftFor(int hijriYear) =>
      hijriYear == ramadanShiftYear ? ramadanShift : 0;

  AppSettings copyWith({
    LanguagePref? language,
    DigitStyle? digits,
    UnitSystem? units,
    WeekStart? weekStart,
    ThemePref? theme,
    LibrarySort? sort,
    bool? grid,
    GroceryView? groceryView,
    bool? ramadanMode,
    int? ramadanShift,
    int? ramadanShiftYear,
    int? ramadanCardDismissedYear,
  }) => AppSettings(
    language: language ?? this.language,
    digits: digits ?? this.digits,
    units: units ?? this.units,
    weekStart: weekStart ?? this.weekStart,
    theme: theme ?? this.theme,
    sort: sort ?? this.sort,
    grid: grid ?? this.grid,
    groceryView: groceryView ?? this.groceryView,
    ramadanMode: ramadanMode ?? this.ramadanMode,
    ramadanShift: ramadanShift ?? this.ramadanShift,
    ramadanShiftYear: ramadanShiftYear ?? this.ramadanShiftYear,
    ramadanCardDismissedYear:
        ramadanCardDismissedYear ?? this.ramadanCardDismissedYear,
  );

  String toJson() => jsonEncode({
    'language': language.name,
    'digits': digits.name,
    'units': units.name,
    'weekStart': weekStart.name,
    'theme': theme.name,
    'sort': sort.name,
    'grid': grid,
    'groceryView': groceryView.name,
    'ramadanMode': ramadanMode,
    'ramadanShift': ramadanShift,
    'ramadanShiftYear': ramadanShiftYear,
    'ramadanCardDismissedYear': ramadanCardDismissedYear,
  });

  /// Unknown or missing values fall back to the defaults, so a backup from a
  /// newer version never breaks settings.
  factory AppSettings.fromJson(String? text) {
    if (text == null) return const AppSettings();
    final m = jsonDecode(text) as Map<String, Object?>;
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return AppSettings(
      language: pick(LanguagePref.values, m['language'], LanguagePref.system),
      digits: pick(DigitStyle.values, m['digits'], DigitStyle.western),
      units: pick(UnitSystem.values, m['units'], UnitSystem.metric),
      weekStart: pick(WeekStart.values, m['weekStart'], WeekStart.auto),
      theme: pick(ThemePref.values, m['theme'], ThemePref.system),
      sort: pick(LibrarySort.values, m['sort'], LibrarySort.recent),
      grid: m['grid'] == true,
      groceryView: pick(
        GroceryView.values,
        m['groceryView'],
        GroceryView.byAisle,
      ),
      ramadanMode: m['ramadanMode'] == true,
      ramadanShift: ((m['ramadanShift'] as int?) ?? 0).clamp(-1, 1),
      ramadanShiftYear: m['ramadanShiftYear'] as int?,
      ramadanCardDismissedYear: m['ramadanCardDismissedYear'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings && other.toJson() == toJson();

  @override
  int get hashCode => toJson().hashCode;
}
