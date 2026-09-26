import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:intl/intl.dart' show Intl, NumberFormat;

import 'grocery.dart';
import 'library.dart';
import 'quantity/format.dart';

enum LanguagePref { system, ar, en }

/// LANG-1's resolver, shared by `MaterialApp` (as its concrete `locale:`,
/// kept live by a `WidgetsBindingObserver` in app.dart so a platform locale
/// change applies at once, not just at the next launch) and by `main.dart`,
/// so the language RUN-6 picks for the sample recipe always matches the
/// language the app actually starts in (should-fix, review): an explicit
/// Settings choice wins; otherwise the first device-preferred locale
/// Wasfati ships (ar or en), wherever it sits in the device's list;
/// otherwise English.
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

/// RUN-3: the digit style the device's own locale writes numbers in, to
/// preselect on the setup page. It's the first device locale Wasfati ships
/// (the same one [appLanguage] follows), formatted by `intl`'s own locale
/// data: only a region whose standard numbers are ١٢٣ (Egypt's Arabic, for
/// one) answers [DigitStyle.arabic]. Everything else — Gulf Arabic
/// included, and any device with no Arabic or English locale — keeps
/// Decision 5's 123.
DigitStyle deviceDigits(List<Locale> deviceLocales) {
  for (final l in deviceLocales) {
    if (l.languageCode != 'ar' && l.languageCode != 'en') continue;
    final tag = l.countryCode == null || l.countryCode!.isEmpty
        ? l.languageCode
        : '${l.languageCode}_${l.countryCode}';
    final known = Intl.verifiedLocale(
      tag,
      NumberFormat.localeExists,
      onFailure: (_) => l.languageCode,
    );
    final zero = NumberFormat.decimalPattern(known).format(0);
    return zero == '٠' ? DigitStyle.arabic : DigitStyle.western;
  }
  return DigitStyle.western;
}

/// SCALE-5: which view conversion shows by default.
enum UnitSystem { metric, kitchen }

/// Meal-plan week start; [auto] is Saturday in the Gulf (roadmap 2a).
enum WeekStart { auto, saturday, sunday, monday }

enum ThemePref { system, light, dark }

/// LOOK-1: which of the two looks is drawn — حبر / Ink (the default) or
/// زعفران / Saffron. Independent of [ThemePref] (the light/dark setting),
/// so there are four combinations plus "حسب الجهاز".
enum AppStyle { ink, saffron }

/// The user's settings, stored as one JSON value in the meta table.
class AppSettings {
  const AppSettings({
    this.language = LanguagePref.system,
    this.digits = DigitStyle.western, // Decision 5
    this.units = UnitSystem.metric,
    this.weekStart = WeekStart.auto,
    this.theme = ThemePref.system,
    this.style =
        AppStyle.saffron, // LOOK-1, Decision 23: Saffron is the default
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
    this.aiImportsUsed = 0, // IMP-7: AI imports saved in aiImportsMonth
    this.aiImportsMonth, // 'YYYY-MM', local; null = never used yet
    this.firstRunComplete = false, // RUN-3, RUN-4: a fresh install
    this.reviewAskedAt, // RUN-5: null = the store was never asked
    this.importSaved = false, // RUN-5: no import saved yet
  });

  final LanguagePref language;
  final DigitStyle digits;
  final UnitSystem units;
  final WeekStart weekStart;
  final ThemePref theme;

  /// LOOK-1: the picked look (حبر/Ink or زعفران/Saffron), independent of
  /// [theme]. Stored with the rest of settings, so a backup carries it
  /// (BAK-6).
  final AppStyle style;

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

  /// IMP-7, Decision 4: AI imports saved so far in [aiImportsMonth]. Reads
  /// as 0 once the calendar month has moved on from [aiImportsMonth] —
  /// see `SettingsState.aiImportsUsed`, which is rollover-aware and is
  /// what the app actually reads.
  final int aiImportsUsed;

  /// The local calendar month (`'YYYY-MM'`) [aiImportsUsed] counts,
  /// or null if no AI import has ever been saved on this device.
  final String? aiImportsMonth;

  /// RUN-3, RUN-4: setup and the walkthrough are behind this install —
  /// finished, or skipped. False only on a fresh install (no stored
  /// settings at all); settings stored by a version from before the first
  /// run existed read as true (see [AppSettings.fromJson]), and schema step
  /// 7 marks an upgraded database that already had recipes or an install
  /// ID. ADS-4 reads this too.
  final bool firstRunComplete;

  /// RUN-5: when the store's review prompt was last asked for, or null if
  /// it never was. Asked at most once every 120 days.
  final DateTime? reviewAskedAt;

  /// RUN-5: an import has been saved from the import preview at least once
  /// — a fetched page, or an AI import of a post, a caption or a photo.
  /// Not a recipe typed by hand after a failed import, whatever source it
  /// is tagged with, and not a recipe's tag: a pasted caption's AI import is
  /// tagged as written (IMP-3). Stays true once set.
  final bool importSaved;

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
    AppStyle? style,
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
    int? aiImportsUsed,
    String? aiImportsMonth,
    bool? firstRunComplete,
    DateTime? reviewAskedAt,
    bool? importSaved,
  }) => AppSettings(
    language: language ?? this.language,
    digits: digits ?? this.digits,
    units: units ?? this.units,
    weekStart: weekStart ?? this.weekStart,
    theme: theme ?? this.theme,
    style: style ?? this.style,
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
    aiImportsUsed: aiImportsUsed ?? this.aiImportsUsed,
    aiImportsMonth: aiImportsMonth ?? this.aiImportsMonth,
    firstRunComplete: firstRunComplete ?? this.firstRunComplete,
    reviewAskedAt: reviewAskedAt ?? this.reviewAskedAt,
    importSaved: importSaved ?? this.importSaved,
  );

  String toJson() => jsonEncode({
    'language': language.name,
    'digits': digits.name,
    'units': units.name,
    'weekStart': weekStart.name,
    'theme': theme.name,
    'style': style.name,
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
    'aiImportsUsed': aiImportsUsed,
    'aiImportsMonth': aiImportsMonth,
    'firstRunComplete': firstRunComplete,
    'reviewAskedAt': reviewAskedAt?.millisecondsSinceEpoch,
    'importSaved': importSaved,
  });

  /// Unknown or missing values fall back to the defaults, so a backup from a
  /// newer version never breaks settings.
  ///
  /// One exception, RUN-4: a missing `firstRunComplete` reads as true.
  /// [toJson] always writes it, so stored settings without it were written
  /// by a version from before the first run existed — an install that is
  /// already in use, or a backup of one, which a "replace" restore (BAK-7)
  /// writes over this phone's settings as they are. Neither must be sent
  /// through setup again. Only a fresh install, with no settings stored at
  /// all ([text] null), starts with it false.
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
      style: pick(AppStyle.values, m['style'], AppStyle.saffron),
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
      aiImportsUsed: (m['aiImportsUsed'] as int?) ?? 0,
      aiImportsMonth: m['aiImportsMonth'] as String?,
      firstRunComplete: m['firstRunComplete'] != false,
      reviewAskedAt: _msToUtc(m['reviewAskedAt']),
      importSaved: m['importSaved'] == true,
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
