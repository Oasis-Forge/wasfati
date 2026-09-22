import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/settings.dart';

void main() {
  group('settings round trip through JSON', () {
    test('defaults: Ramadan mode off, no shift, nothing dismissed (RAM-1)', () {
      const s = AppSettings();
      expect(s.ramadanMode, isFalse);
      expect(s.ramadanShift, 0);
      expect(s.ramadanShiftYear, isNull);
      expect(s.ramadanCardDismissedYear, isNull);
    });

    test('every field, including the Ramadan ones, comes back as it went '
        'in (BAK-6: settings travel in backups)', () {
      const s = AppSettings(
        language: LanguagePref.en,
        digits: DigitStyle.arabic,
        weekStart: WeekStart.monday,
        ramadanMode: true,
        ramadanShift: -1,
        ramadanShiftYear: 1448,
        ramadanCardDismissedYear: 1447,
      );
      final back = AppSettings.fromJson(s.toJson());
      expect(back, s);
      expect(back.ramadanMode, isTrue);
      expect(back.ramadanShift, -1);
      expect(back.ramadanShiftYear, 1448);
      expect(back.ramadanCardDismissedYear, 1447);
    });

    test('null settings text falls back to every default', () {
      expect(AppSettings.fromJson(null), const AppSettings());
    });

    test('unknown keys and a missing Ramadan block fall back to defaults '
        '(a backup from an older version)', () {
      final back = AppSettings.fromJson('{"language": "ar", "future": 1}');
      expect(back.ramadanMode, isFalse);
      expect(back.ramadanShift, 0);
      expect(back.ramadanShiftYear, isNull);
      expect(back.language, LanguagePref.ar);
    });

    test('a corrupt shift is clamped to -1..1', () {
      final back = AppSettings.fromJson('{"ramadanShift": 7}');
      expect(back.ramadanShift, 1);
      final back2 = AppSettings.fromJson('{"ramadanShift": -9}');
      expect(back2.ramadanShift, -1);
    });
  });

  group('copyWith', () {
    test('changes only the given Ramadan fields', () {
      const s = AppSettings(
        ramadanMode: true,
        ramadanShift: 1,
        ramadanShiftYear: 1448,
      );
      final next = s.copyWith(ramadanShift: -1);
      expect(next.ramadanMode, isTrue); // untouched
      expect(next.ramadanShift, -1);
      expect(next.ramadanShiftYear, 1448); // untouched
    });

    test('0 is a real value, not treated as "leave alone"', () {
      const s = AppSettings(ramadanShift: 1);
      expect(s.copyWith(ramadanShift: 0).ramadanShift, 0);
    });
  });

  group('RAM-2: ramadanShiftFor resets for another Hijri year', () {
    test('the shift applies only to the year it was set for', () {
      const s = AppSettings(ramadanShift: -1, ramadanShiftYear: 1448);
      expect(s.ramadanShiftFor(1448), -1);
      expect(s.ramadanShiftFor(1449), 0); // next Ramadan: back to 0
    });

    test('no shift ever set reads as 0 for any year', () {
      const s = AppSettings();
      expect(s.ramadanShiftFor(1448), 0);
    });
  });
}
