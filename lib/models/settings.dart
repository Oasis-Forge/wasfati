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

  AppSettings copyWith({
    LanguagePref? language,
    DigitStyle? digits,
    UnitSystem? units,
    WeekStart? weekStart,
    ThemePref? theme,
    LibrarySort? sort,
    bool? grid,
    GroceryView? groceryView,
  }) => AppSettings(
    language: language ?? this.language,
    digits: digits ?? this.digits,
    units: units ?? this.units,
    weekStart: weekStart ?? this.weekStart,
    theme: theme ?? this.theme,
    sort: sort ?? this.sort,
    grid: grid ?? this.grid,
    groceryView: groceryView ?? this.groceryView,
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
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings && other.toJson() == toJson();

  @override
  int get hashCode => toJson().hashCode;
}
