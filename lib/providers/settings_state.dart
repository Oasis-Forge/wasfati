import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../models/quantity/arabic_text.dart';
import '../models/quantity/format.dart';
import '../models/settings.dart';
import '../services/ids.dart';

/// The settings, kept as one JSON value in the meta table, so backups carry
/// them (BAK-1). A change applies at once, without a restart (LANG-1).
class SettingsState extends ChangeNotifier {
  SettingsState(this._db, {Clock? clock}) : _clock = clock ?? systemClock;

  final Database _db;
  final Clock _clock;
  static const _key = 'settings';

  /// IMP-7, PAY-7: the free tier's AI imports a calendar month. Premium's
  /// 100 (fair use, SRV-4) comes from `PurchasesState.aiImportQuota`,
  /// passed as [quota] to [aiImportsLeft].
  static const freeAiImportsPerMonth = 10;

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  /// Reads the stored settings. With none stored yet — a fresh install —
  /// the digit style starts as [deviceLocales]' own (RUN-3, [deviceDigits]),
  /// so setup opens with the device's answer already chosen; nothing is
  /// written until the user changes something.
  Future<void> load({List<Locale> deviceLocales = const []}) async {
    final rows = await _db.query('meta', where: 'key = ?', whereArgs: [_key]);
    _settings = rows.isEmpty
        ? AppSettings(digits: deviceDigits(deviceLocales))
        : AppSettings.fromJson(rows.single['value'] as String);
    notifyListeners();
  }

  /// RUN-3: the setup page's language choice, `'ar'` or `'en'`. Choosing
  /// the language the device already resolves to keeps "System default"
  /// (LANG-1), so the app goes on following the phone; choosing the other
  /// one pins it, exactly like the Settings row. Applies at once.
  Future<void> chooseSetupLanguage(String code, List<Locale> deviceLocales) {
    final device = appLanguage(LanguagePref.system, deviceLocales);
    final pref = code == device.languageCode
        ? LanguagePref.system
        : (code == 'ar' ? LanguagePref.ar : LanguagePref.en);
    return update(_settings.copyWith(language: pref));
  }

  /// RUN-3, QTY-5: the setup page's digit style. Applies at once.
  Future<void> chooseDigits(DigitStyle digits) =>
      update(_settings.copyWith(digits: digits));

  /// RUN-4: setup and the walkthrough are done (finished or skipped), so
  /// neither shows again on its own; Settings can still replay the
  /// walkthrough.
  Future<void> completeFirstRun() =>
      update(_settings.copyWith(firstRunComplete: true));

  /// Writes first, then applies (reliable writes).
  Future<void> update(AppSettings next) async {
    await _db.insert('meta', {
      'key': _key,
      'value': next.toJson(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _settings = next;
    notifyListeners();
  }

  /// `'YYYY-MM'` for the current calendar month, in local time (IMP-7,
  /// Decision 4: the quota resets on the 1st at 00:00 local).
  String get _currentAiImportMonth {
    final local = _clock().toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}';
  }

  /// IMP-7: AI imports saved so far this calendar month. Reads as 0 the
  /// moment the month turns over, without needing a write — the stored
  /// count only means something together with the month it was for.
  int get aiImportsUsed => _settings.aiImportsMonth == _currentAiImportMonth
      ? _settings.aiImportsUsed
      : 0;

  /// IMP-7: AI imports left this calendar month, out of [quota] (the free
  /// tier's 10 by default).
  int aiImportsLeft({int quota = freeAiImportsPerMonth}) =>
      (quota - aiImportsUsed).clamp(0, quota);

  /// IMP-7, Decision 4: local midnight on the 1st of next month, when the
  /// quota resets.
  DateTime get aiImportsResetAt {
    final local = _clock().toLocal();
    return DateTime(local.year, local.month + 1, 1);
  }

  /// IMP-7: the save path calls this, and only the save path — never a
  /// cancelled or failed preview, which costs nothing. Rolls the count
  /// over to the current month first if the last save was in an earlier
  /// one, so a save right after the boundary starts a fresh month's count
  /// rather than adding to a stale one.
  Future<void> recordAiImportSaved() => update(
    _settings.copyWith(
      aiImportsUsed: aiImportsUsed + 1,
      aiImportsMonth: _currentAiImportMonth,
    ),
  );

  Locale? get locale => switch (_settings.language) {
    LanguagePref.system => null,
    LanguagePref.ar => const Locale('ar'),
    LanguagePref.en => const Locale('en'),
  };

  ThemeMode get themeMode => switch (_settings.theme) {
    ThemePref.system => ThemeMode.system,
    ThemePref.light => ThemeMode.light,
    ThemePref.dark => ThemeMode.dark,
  };

  DigitStyle get digits => _settings.digits;

  /// A whole number in the chosen digit style (QTY-5, Decision 5).
  String number(int n) =>
      digits == DigitStyle.arabic ? easternDigits('$n') : '$n';

  /// Text the platform formatted, with its digits put into the chosen style
  /// (QTY-5): dates read in 123 by default, even in Arabic.
  String inDigits(String text) =>
      digits == DigitStyle.arabic ? easternDigits(text) : westernDigits(text);
}
