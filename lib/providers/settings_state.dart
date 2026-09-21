import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../models/quantity/arabic_text.dart';
import '../models/quantity/format.dart';
import '../models/settings.dart';

/// The settings, kept as one JSON value in the meta table, so backups carry
/// them (BAK-1). A change applies at once, without a restart (LANG-1).
class SettingsState extends ChangeNotifier {
  SettingsState(this._db);

  final Database _db;
  static const _key = 'settings';

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  Future<void> load() async {
    final rows = await _db.query('meta', where: 'key = ?', whereArgs: [_key]);
    _settings = AppSettings.fromJson(
      rows.isEmpty ? null : rows.single['value'] as String,
    );
    notifyListeners();
  }

  /// Writes first, then applies (reliable writes).
  Future<void> update(AppSettings next) async {
    await _db.insert('meta', {
      'key': _key,
      'value': next.toJson(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _settings = next;
    notifyListeners();
  }

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
