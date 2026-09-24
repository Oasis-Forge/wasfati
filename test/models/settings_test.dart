import 'package:flutter/widgets.dart' show Locale;
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

    test('default look is Ink (LOOK-1)', () {
      const s = AppSettings();
      expect(s.style, AppStyle.ink);
    });

    test('every field, including the Ramadan ones, comes back as it went '
        'in (BAK-6: settings travel in backups)', () {
      const s = AppSettings(
        language: LanguagePref.en,
        digits: DigitStyle.arabic,
        weekStart: WeekStart.monday,
        style: AppStyle.saffron,
        ramadanMode: true,
        ramadanShift: -1,
        ramadanShiftYear: 1448,
        ramadanCardDismissedYear: 1447,
      );
      final back = AppSettings.fromJson(s.toJson());
      expect(back, s);
      expect(back.style, AppStyle.saffron);
      expect(back.ramadanMode, isTrue);
      expect(back.ramadanShift, -1);
      expect(back.ramadanShiftYear, 1448);
      expect(back.ramadanCardDismissedYear, 1447);
    });

    test('null settings text falls back to every default', () {
      expect(AppSettings.fromJson(null), const AppSettings());
    });

    test('IMP-7: the AI import count and its month round-trip', () {
      const s = AppSettings(aiImportsUsed: 7, aiImportsMonth: '2026-09');
      final back = AppSettings.fromJson(s.toJson());
      expect(back.aiImportsUsed, 7);
      expect(back.aiImportsMonth, '2026-09');
    });

    test('IMP-7: defaults to nothing used and no month yet', () {
      const s = AppSettings();
      expect(s.aiImportsUsed, 0);
      expect(s.aiImportsMonth, isNull);
    });

    test('unknown keys and a missing Ramadan block fall back to defaults '
        '(a backup from an older version)', () {
      final back = AppSettings.fromJson('{"language": "ar", "future": 1}');
      expect(back.ramadanMode, isFalse);
      expect(back.ramadanShift, 0);
      expect(back.ramadanShiftYear, isNull);
      expect(back.language, LanguagePref.ar);
      expect(back.style, AppStyle.ink); // a backup with no LOOK-1 field yet
    });

    test('an unknown style name falls back to Ink (a backup from an older '
        'version, LOOK-1, BAK-6)', () {
      final back = AppSettings.fromJson('{"style": "sunset"}');
      expect(back.style, AppStyle.ink);
    });

    test('a corrupt shift is clamped to -1..1', () {
      final back = AppSettings.fromJson('{"ramadanShift": 7}');
      expect(back.ramadanShift, 1);
      final back2 = AppSettings.fromJson('{"ramadanShift": -9}');
      expect(back2.ramadanShift, -1);
    });
  });

  group('RUN-3, RUN-4: firstRunComplete', () {
    test('a fresh install (nothing stored) starts the first run', () {
      expect(const AppSettings().firstRunComplete, isFalse);
      expect(AppSettings.fromJson(null).firstRunComplete, isFalse);
    });

    test('both answers round-trip through JSON', () {
      for (final done in [false, true]) {
        final s = AppSettings(
          firstRunComplete: done,
          language: LanguagePref.en,
        );
        final back = AppSettings.fromJson(s.toJson());
        expect(back.firstRunComplete, done);
        expect(back, s);
      }
    });

    test('settings stored without it — an install from before the first '
        'run, or its backup restored by "replace" — read as complete', () {
      final back = AppSettings.fromJson('{"language": "ar"}');
      expect(back.firstRunComplete, isTrue);
      expect(back.language, LanguagePref.ar);
    });

    test('copyWith sets it and leaves everything else', () {
      const s = AppSettings(digits: DigitStyle.arabic);
      final next = s.copyWith(firstRunComplete: true);
      expect(next.firstRunComplete, isTrue);
      expect(next.digits, DigitStyle.arabic);
      expect(
        next.copyWith(digits: DigitStyle.western).firstRunComplete,
        isTrue,
      );
    });
  });

  group('RUN-5: reviewAskedAt', () {
    test('never asked by default', () {
      expect(const AppSettings().reviewAskedAt, isNull);
      expect(AppSettings.fromJson('{}').reviewAskedAt, isNull);
    });

    test('round-trips through JSON, and copyWith keeps it', () {
      final at = DateTime.utc(2026, 9, 25, 18, 30);
      final s = AppSettings(reviewAskedAt: at);
      expect(AppSettings.fromJson(s.toJson()).reviewAskedAt, at);
      expect(s.copyWith(grid: true).reviewAskedAt, at);
    });
  });

  group('RUN-3: deviceDigits, the setup page\'s preselected digits', () {
    test('Egyptian Arabic writes ١٢٣', () {
      expect(deviceDigits(const [Locale('ar', 'EG')]), DigitStyle.arabic);
    });

    test('Gulf Arabic, plain Arabic and English keep Decision 5\'s 123', () {
      for (final l in const [
        Locale('ar', 'SA'),
        Locale('ar', 'AE'),
        Locale('ar'),
        Locale('en', 'US'),
        Locale('en'),
      ]) {
        expect(deviceDigits([l]), DigitStyle.western, reason: '$l');
      }
    });

    test('the first locale Wasfati ships decides, like the language', () {
      expect(
        deviceDigits(const [Locale('fr', 'FR'), Locale('ar', 'EG')]),
        DigitStyle.arabic,
      );
      expect(
        deviceDigits(const [Locale('en', 'GB'), Locale('ar', 'EG')]),
        DigitStyle.western,
      );
    });

    test('no locale at all, or none Wasfati ships: 123', () {
      expect(deviceDigits(const []), DigitStyle.western);
      expect(deviceDigits(const [Locale('fr', 'FR')]), DigitStyle.western);
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

    test('changes only style, leaving theme (light/dark) untouched '
        '(LOOK-1: the two are independent)', () {
      const s = AppSettings(theme: ThemePref.dark);
      final next = s.copyWith(style: AppStyle.saffron);
      expect(next.style, AppStyle.saffron);
      expect(next.theme, ThemePref.dark); // untouched
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

  // should-fix, review: main.dart used to read only platformDispatcher's
  // *first* preferred locale, and MaterialApp resolved the full list
  // itself (falling back to supportedLocales.first, "ar", for anything it
  // didn't recognize) — so the two disagreed, and RUN-6's sample recipe
  // could pick a different language than the app actually opened in. One
  // resolver, shared by both, fixes it (LANG-1).
  group('appLanguage (LANG-1, RUN-6): what the app actually starts in', () {
    test('an explicit preference always wins over the device', () {
      expect(
        appLanguage(LanguagePref.ar, const [Locale('en')]),
        const Locale('ar'),
      );
      expect(
        appLanguage(LanguagePref.en, const [Locale('ar')]),
        const Locale('en'),
      );
    });

    test('system: the first device locale Wasfati ships wins, wherever it '
        'sits in the list', () {
      expect(
        appLanguage(LanguagePref.system, const [Locale('ar', 'SA')]),
        const Locale('ar'),
      );
      expect(
        appLanguage(LanguagePref.system, const [Locale('fr'), Locale('ar')]),
        const Locale('ar'),
      );
      expect(
        appLanguage(LanguagePref.system, const [Locale('fr'), Locale('en')]),
        const Locale('en'),
      );
    });

    test('system: falls back to English when nothing on the device matches '
        '(LANG-1)', () {
      expect(
        appLanguage(LanguagePref.system, const [Locale('fr')]),
        const Locale('en'),
      );
      expect(appLanguage(LanguagePref.system, const []), const Locale('en'));
    });
  });
}
