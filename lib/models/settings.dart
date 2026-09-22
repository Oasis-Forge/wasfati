import 'dart:convert';
import 'dart:ui' show Locale;

import 'grocery.dart';
import 'library.dart';
import 'quantity/format.dart';

enum LanguagePref { system, ar, en }

/// LANG-1's resolver, shared by `MaterialApp` (as its
/// `localeListResolutionCallback`) and by `main.dart`, so the language RUN-6
/// picks for the sample recipe always matches the language the app actually
/// starts in (should-fix, review): an explicit Settings choice wins;
/// otherwise the first device-preferred locale Wasfati ships (ar or en),
/// wherever it sits in the device's list; otherwise English.
Locale appLanguage(LanguagePref pref, List<Locale> deviceLocales) {
  switch (pref) {
    case LanguagePref.ar:
      return const Locale('ar');
    case LanguagePref.en:
      return const Locale('en');
    case LanguagePref.system:
      for (final l in deviceLocales) {
        if (l.languageCode == 'ar' || l.languageCode == 'en') {
          return Locale(l.languageCode);
        }
      }
      return const Locale('en');
  }
}

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
    this.lastBackupAt, // BAK-8
    this.backupReminderSnoozedUntil, // BAK-8: "Later", for 30 days
    this.backupReminderOff = false, // BAK-8: the Settings switch
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

  /// When a backup was last made or restored (BAK-8), or null if never.
  final DateTime? lastBackupAt;

  /// Set by "Later" on the library's backup reminder card (BAK-8); the card
  /// stays hidden until this time.
  final DateTime? backupReminderSnoozedUntil;

  /// The Settings switch that turns BAK-8's reminder off for good.
  final bool backupReminderOff;

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
    DateTime? lastBackupAt,
    DateTime? backupReminderSnoozedUntil,
    bool? backupReminderOff,
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
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    backupReminderSnoozedUntil:
        backupReminderSnoozedUntil ?? this.backupReminderSnoozedUntil,
    backupReminderOff: backupReminderOff ?? this.backupReminderOff,
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
    'lastBackupAt': lastBackupAt?.millisecondsSinceEpoch,
    'backupReminderSnoozedUntil':
        backupReminderSnoozedUntil?.millisecondsSinceEpoch,
    'backupReminderOff': backupReminderOff,
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
      lastBackupAt: _msToUtc(m['lastBackupAt']),
      backupReminderSnoozedUntil: _msToUtc(m['backupReminderSnoozedUntil']),
      backupReminderOff: m['backupReminderOff'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings && other.toJson() == toJson();

  @override
  int get hashCode => toJson().hashCode;
}

DateTime? _msToUtc(Object? ms) => ms == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);
