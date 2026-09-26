// RUN-3–RUN-6: the first launch — setup, the walkthrough, the library with
// the sample — and RUN-5's review prompt after cook mode.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/widgets/nav_pill.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wasfati/db/db_helper.dart';
import 'package:wasfati/db/recipe_repository.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/recipe.dart' show SourceType;
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/providers/settings_state.dart';
import 'package:wasfati/screens/first_run_screen.dart';
import 'package:wasfati/screens/walkthrough_screen.dart';
import 'package:wasfati/widgets/recipe_cover.dart';

import '../helpers.dart';
import 'app_test.dart'
    show clock, dirOf, pumpApp, reviewPrompt, settle, shown, storeReview;

// Every walkthrough page's heading, in order, in each language.
const _arPages = [
  'احفظ الوصفات من أي منشور',
  'مقادير تتضاعف بعربية سليمة',
  'اطبخ خطوة بخطوة',
  'خطّط لأسبوعك وتسوّق من قائمة واحدة',
];
const _enPages = [
  'Save recipes from any post',
  'Amounts that scale, in proper Arabic',
  'Cook one step at a time',
  'Plan the week, shop from one list',
];

/// A phone whose own languages are [locales].
void _device(WidgetTester tester, List<Locale> locales) {
  tester.platformDispatcher.localesTestValue = locales;
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

/// A fresh install: an empty database, nothing stored, loaded the way
/// `main.dart` loads it.
Future<SettingsState> _freshInstall(
  WidgetTester tester, {
  double textScale = 1,
  bool disableAnimations = false,
}) async {
  final db = (await tester.runAsync(() => memoryDb()))!;
  final (_, settings) = await pumpApp(
    tester,
    existingDb: db,
    textScale: textScale,
    disableAnimations: disableAnimations,
  );
  return settings;
}

Future<AppSettings> _stored(WidgetTester tester) async {
  final reloaded = SettingsState(reviewPrompt.recipes.repository.db);
  await tester.runAsync(reloaded.load);
  return reloaded.settings;
}

/// RUN-3: which answer card of a question is chosen, by the labels it
/// shows ("العربية"/"English", "123"/"١٢٣"); null when none is.
String? _selected(WidgetTester tester, List<String> labels) {
  final chosen = [
    for (final label in labels)
      if (tester
          .widget<SetupChoiceCard>(find.widgetWithText(SetupChoiceCard, label))
          .selected)
        label,
  ];
  expect(
    chosen.length,
    lessThanOrEqualTo(1),
    reason: 'one answer per question',
  );
  return chosen.singleOrNull;
}

String? _language(WidgetTester tester) =>
    _selected(tester, const ['العربية', 'English']);
String? _digits(WidgetTester tester) => _selected(tester, const ['123', '١٢٣']);

void main() {
  testWidgets('a fresh install: setup, then the walkthrough, then the library '
      'with the sample (RUN-3, RUN-4, RUN-6)', (tester) async {
    _device(tester, const [Locale('ar', 'SA')]);
    final settings = await _freshInstall(tester);

    // Setup: only the language and the digits, each with the device's own
    // answer already chosen — Gulf Arabic writes 123 (Decision 5).
    expect(find.text('أهلًا بك في وصفاتي'), findsOneWidget);
    expect(_language(tester), 'العربية');
    expect(_digits(tester), '123');
    // Two questions, two large cards each — and nothing else to answer.
    expect(find.byType(SetupChoiceCard), findsNWidgets(4));
    expect(find.byType(TextField), findsNothing); // no account, no profile
    expect(find.byType(NavPill), findsNothing); // not the library yet

    await tester.tap(find.text('متابعة'));
    await settle(tester);

    // The walkthrough: four pages, Skip on each but the last. Page 1 draws three saved
    // recipes as tiles, each with where it came from.
    expect(find.text(_arPages[0]), findsOneWidget);
    expect(find.text('أهلًا بك في وصفاتي'), findsNothing);
    for (final tile in ['شوربة عدس', 'فتوش', 'كبسة دجاج']) {
      expect(find.text(tile), findsOneWidget);
    }
    for (final badge in [
      Icons.music_note,
      Icons.camera_alt_outlined,
      Icons.public,
    ]) {
      expect(find.byIcon(badge), findsOneWidget);
    }

    await tester.tap(find.text('التالي'));
    await settle(tester);
    expect(find.text(_arPages[1]), findsOneWidget);
    // The claim, made by the app's own formatter: doubled, the unit agrees.
    expect(shown('3 أكواب أرز'), findsOneWidget);
    expect(shown('4 ملاعق كبيرة زيت زيتون'), findsOneWidget);
    expect(find.text('4 حصص'), findsOneWidget);

    await tester.tap(find.text('التالي'));
    await settle(tester);
    expect(find.text(_arPages[2]), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget); // the timer read from the step

    await tester.tap(find.text('التالي'));
    await settle(tester);
    expect(find.text(_arPages[3]), findsOneWidget);
    expect(find.text('التالي'), findsNothing);
    // Skip would do what the main button does, so the last page has none.
    expect(find.text('تخطَّ'), findsNothing);

    await tester.tap(find.text('إلى وصفاتي'));
    await settle(tester);

    // The library, with the sample in the language setup ended in.
    expect(find.text('شوربة عدس'), findsOneWidget);
    expect(find.text(_arPages[3]), findsNothing);
    expect(settings.settings.firstRunComplete, isTrue);
    expect((await _stored(tester)).firstRunComplete, isTrue);
    expect(storeReview.requests, 0); // RUN-5: never during the first run
  });

  // Every page but the last, which has no Skip (its button already ends it).
  for (var page = 0; page < _arPages.length - 1; page++) {
    testWidgets('Skip on page ${page + 1} ends the walkthrough in the library '
        '(RUN-4)', (tester) async {
      _device(tester, const [Locale('ar')]);
      await _freshInstall(tester);
      await tester.tap(find.text('متابعة'));
      await settle(tester);
      for (var i = 0; i < page; i++) {
        await tester.tap(find.text('التالي'));
        await settle(tester);
      }
      expect(find.text(_arPages[page]), findsOneWidget);

      await tester.tap(find.text('تخطَّ'));
      await settle(tester);

      expect(find.text(_arPages[page]), findsNothing);
      expect(find.text('شوربة عدس'), findsOneWidget);
      expect((await _stored(tester)).firstRunComplete, isTrue);
    });
  }

  testWidgets('choices apply at once and persist; the sample follows the '
      'language chosen (RUN-3, LANG-1, RUN-6)', (tester) async {
    _device(tester, const [Locale('ar', 'SA')]);
    await _freshInstall(tester);

    await tester.tap(find.text('English'));
    await settle(tester);
    // The page itself switched, with no restart.
    expect(find.text('Welcome to Wasfati'), findsOneWidget);
    expect(find.text('أهلًا بك في وصفاتي'), findsNothing);
    expect(dirOf(tester, find.text('Welcome to Wasfati')), TextDirection.ltr);

    await tester.tap(find.text('١٢٣'));
    await settle(tester);
    expect(_digits(tester), '١٢٣');
    expect(_language(tester), 'English');

    // Stored at once, before Continue.
    final stored = await _stored(tester);
    expect(stored.language, LanguagePref.en);
    expect(stored.digits, DigitStyle.arabic);
    expect(stored.firstRunComplete, isFalse);

    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text(_enPages[0]), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await settle(tester);

    expect(find.text('Red lentil soup'), findsOneWidget);
    expect(find.text('شوربة عدس'), findsNothing);
  });

  for (final (locale, next) in [
    (const Locale('en', 'US'), 'Continue'),
    (const Locale('ar', 'SA'), 'متابعة'),
  ]) {
    testWidgets('${locale.languageCode}: page 1 shows all three source '
        'badges, none hidden under the middle card (RUN-4)', (tester) async {
      _device(tester, [locale]);
      await _freshInstall(tester);
      await tester.tap(find.text(next));
      await settle(tester);
      // The middle card: its cover plus the card's 8dp padding.
      final middle = tester
          .getRect(
            find.byWidgetPredicate(
              (w) => w is RecipeCover && w.recipeId == 'walkthrough-fattoush',
            ),
          )
          .inflate(8);
      for (final icon in [Icons.music_note, Icons.public]) {
        final badge = tester.getRect(find.byIcon(icon));
        expect(
          badge.overlaps(middle),
          isFalse,
          reason: '$icon badge at $badge is under the middle card $middle',
        );
      }
    });
  }

  testWidgets('back from the walkthrough reopens setup; another language '
      'chosen there is the sample\'s, since it comes only as the walkthrough '
      'ends (RUN-4, RUN-6)', (tester) async {
    _device(tester, const [Locale('ar', 'SA')]);
    await _freshInstall(tester);
    await tester.tap(find.text('متابعة'));
    await settle(tester);
    expect(find.text(_arPages[0]), findsOneWidget);
    expect(reviewPrompt.recipes.recipes, isEmpty); // not offered yet

    await tester.binding.handlePopRoute(); // system Back
    await settle(tester);
    expect(find.text('أهلًا بك في وصفاتي'), findsOneWidget);
    await tester.tap(find.text('English'));
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);
    await tester.tap(find.text('Skip'));
    await settle(tester);

    expect(find.text('Red lentil soup'), findsOneWidget);
    expect(find.text('شوربة عدس'), findsNothing);
    expect(reviewPrompt.recipes.recipes, hasLength(1));
  });

  testWidgets('a device that writes ١٢٣ gets it preselected, and the '
      'walkthrough draws in it (RUN-3, QTY-5)', (tester) async {
    _device(tester, const [Locale('ar', 'EG')]);
    await _freshInstall(tester);
    expect(_digits(tester), '١٢٣');

    await tester.tap(find.text('متابعة'));
    await settle(tester);
    await tester.tap(find.text('التالي'));
    await settle(tester);
    expect(shown('٣ أكواب أرز'), findsOneWidget);
    expect(find.text('٤ حصص'), findsOneWidget);
    await tester.tap(find.text('التالي'));
    await settle(tester);
    expect(find.text('٢٥:٠٠'), findsOneWidget);
  });

  testWidgets('an upgraded install goes straight to the library (RUN-4)', (
    tester,
  ) async {
    _device(tester, const [Locale('ar')]);
    final db = (await tester.runAsync(() async {
      sqfliteFfiInit();
      final path = '${Directory.systemTemp.path}/wasfati_first_run_widget.db';
      await databaseFactoryFfi.deleteDatabase(path);
      // What 0.16 left on the phone: a recipe and an install ID, no
      // settings ever changed.
      final old = await DBHelper.open(
        databaseFactoryFfi,
        path,
        upTo: 6,
        singleInstance: false,
      );
      final ids = CountingIds(prefix: 'old');
      final repo = RecipeRepository(old, ids: ids.call);
      await repo.save(kabsa(repo));
      await repo.installId();
      await old.close();
      return DBHelper.open(databaseFactoryFfi, path, singleInstance: false);
    }))!;
    final (_, settings) = await pumpApp(tester, existingDb: db);

    expect(find.text('كبسة لحم'), findsOneWidget);
    expect(find.byType(NavPill), findsOneWidget);
    expect(find.text('أهلًا بك في وصفاتي'), findsNothing);
    expect(find.text(_arPages[0]), findsNothing);
    expect(settings.settings.firstRunComplete, isTrue);
  });

  testWidgets('replayed from Settings, it just closes at the end, and Skip '
      'too (RUN-4)', (tester) async {
    final (_, settings) = await pumpApp(tester, withRecipe: true);
    await tester.tap(find.byTooltip('الإعدادات'));
    await settle(tester);
    final replay = find.text('اعرض الجولة التعريفية مجددًا');
    await tester.scrollUntilVisible(replay, 300);
    await settle(tester);
    await tester.tap(replay);
    await settle(tester);
    expect(find.text(_arPages[0]), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('التالي'));
      await settle(tester);
    }
    // It returns to Settings, so it says Done, never "Go to my recipes",
    // and no Skip beside it.
    expect(find.text('إلى وصفاتي'), findsNothing);
    expect(find.text('تخطَّ'), findsNothing);
    final done = find.widgetWithText(FilledButton, 'تم');
    expect(done, findsOneWidget);
    await tester.tap(done);
    await settle(tester);
    expect(find.text(_arPages[3]), findsNothing);
    expect(replay, findsOneWidget); // back in Settings

    await tester.tap(replay);
    await settle(tester);
    await tester.tap(find.text('تخطَّ'));
    await settle(tester);
    expect(find.text(_arPages[0]), findsNothing);
    expect(replay, findsOneWidget);
    expect(settings.settings.firstRunComplete, isTrue);
  });

  testWidgets('with reduce motion on, Next jumps instead of sliding (RUN-4)', (
    tester,
  ) async {
    _device(tester, const [Locale('ar')]);
    await _freshInstall(tester, disableAnimations: true);
    await tester.tap(find.text('متابعة'));
    await settle(tester);

    await tester.tap(find.text('التالي'));
    await tester.pump(); // one frame: no slide to wait for
    expect(find.text(_arPages[1]), findsOneWidget);
    expect(find.text(_arPages[0]), findsNothing);
  });

  testWidgets('without reduce motion, Next slides', (tester) async {
    _device(tester, const [Locale('ar')]);
    await _freshInstall(tester);
    await tester.tap(find.text('متابعة'));
    await settle(tester);

    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-slide: both pages are on screen.
    expect(find.text(_arPages[0]), findsOneWidget);
    expect(find.text(_arPages[1]), findsOneWidget);
    await settle(tester);
    expect(find.text(_arPages[0]), findsNothing);
  });

  for (final (language, style) in [
    (const Locale('ar'), AppStyle.ink),
    (const Locale('en'), AppStyle.saffron),
    (const Locale('ar'), AppStyle.saffron),
    (const Locale('en'), AppStyle.ink),
  ]) {
    testWidgets('setup and every walkthrough page fit at 1.3x on a 360dp '
        'phone: ${language.languageCode}, ${style.name} (LANG-6, LOOK-8)', (
      tester,
    ) async {
      _device(tester, [language]);
      final settings = await _freshInstall(tester, textScale: 1.3);
      await tester.runAsync(
        () => settings.update(settings.settings.copyWith(style: style)),
      );
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'setup');

      final ar = language.languageCode == 'ar';
      await tester.tap(find.text(ar ? 'متابعة' : 'Continue'));
      await settle(tester);
      for (var i = 0; i < 4; i++) {
        expect(find.text((ar ? _arPages : _enPages)[i]), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'page ${i + 1}');
        if (i < 3) {
          await tester.tap(find.text(ar ? 'التالي' : 'Next'));
          await settle(tester);
        }
      }
    });
  }

  testWidgets('an English phone gets English and 123 preselected, as large '
      'cards on the page colour (RUN-3)', (tester) async {
    _device(tester, const [Locale('en', 'US')]);
    await _freshInstall(tester);
    expect(find.text('Welcome to Wasfati'), findsOneWidget);
    expect(_language(tester), 'English');
    expect(_digits(tester), '123');
    // Each card is a large target, never under 48dp.
    for (final label in ['العربية', 'English', '123', '١٢٣']) {
      final card = find.widgetWithText(SetupChoiceCard, label);
      expect(tester.getSize(card).height, greaterThanOrEqualTo(72));
    }
    // The chosen card says so to a screen reader, not by colour alone.
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.widgetWithText(SetupChoiceCard, 'English')),
      matchesSemantics(
        isSelected: true,
        hasSelectedState: true,
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        label: 'English',
      ),
    );
    // "123" and "١٢٣" read aloud as the same number, so each digit answer
    // is named by its kind as well.
    expect(
      tester.getSemantics(find.widgetWithText(SetupChoiceCard, '123')).label,
      'Western digits (123)',
    );
    expect(
      tester.getSemantics(find.widgetWithText(SetupChoiceCard, '١٢٣')).label,
      'Arabic digits (١٢٣)',
    );
    semantics.dispose();
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('a setup card scales to 0.97 while pressed, like every '
      'tappable card (design-styles.md, Motion #1)', (tester) async {
    _device(tester, const [Locale('en', 'US')]);
    await _freshInstall(tester);
    final card = find.widgetWithText(SetupChoiceCard, '١٢٣');
    double scale() => tester
        .widget<AnimatedScale>(
          find.descendant(of: card, matching: find.byType(AnimatedScale)),
        )
        .scale;
    expect(scale(), 1);
    final press = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(), 0.97);
    await press.up();
    await settle(tester);
    expect(scale(), 1);
    expect(_digits(tester), '١٢٣');
  });

  for (final (locale, rtl) in [
    (const Locale('ar'), true),
    (const Locale('en'), false),
  ]) {
    testWidgets('the page dots fill from the reading start — '
        '${rtl ? 'the right, in Arabic' : 'the left, in English'} (RUN-4)', (
      tester,
    ) async {
      _device(tester, [locale]);
      await _freshInstall(tester);
      await tester.tap(find.text(rtl ? 'متابعة' : 'Continue'));
      await settle(tester);

      Finder dot(int page) => find.byKey(WalkthroughScreen.dotKey(page));
      double x(int page) => tester.getCenter(dot(page)).dx;
      double width(int page) => tester.getSize(dot(page)).width;
      Color? colour(int page) {
        final box = tester.widget<AnimatedContainer>(dot(page)).decoration;
        return (box! as BoxDecoration).color;
      }

      // Page 1's dot comes first in the reading direction, and is the long
      // one.
      for (var i = 1; i < 4; i++) {
        expect(rtl ? x(i - 1) > x(i) : x(i - 1) < x(i), isTrue);
      }
      expect(width(0), greaterThan(width(1)));
      final accent = colour(0);
      expect(colour(1), isNot(accent));

      await tester.tap(find.text(rtl ? 'التالي' : 'Next'));
      await settle(tester);
      // Page 2: the first two dots are filled, the second is the long one.
      expect(colour(0), accent);
      expect(colour(1), accent);
      expect(colour(2), isNot(accent));
      expect(width(1), greaterThan(width(0)));
      // Skip sits at the top, at the end of the reading direction, as the
      // mockup draws it.
      final skip = tester.getCenter(find.text(rtl ? 'تخطَّ' : 'Skip'));
      expect(skip.dy, lessThan(100));
      expect(rtl ? skip.dx < 180 : skip.dx > 180, isTrue);
    });
  }

  group('RUN-5: the store\'s review prompt', () {
    Future<void> openCookMode(WidgetTester tester) async {
      // Decision 23's larger type scale can push "ابدأ الطبخ" out of the
      // ListView's initial build range.
      await tester.scrollUntilVisible(
        find.text('ابدأ الطبخ'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      await tester.tap(find.text('ابدأ الطبخ'));
      await settle(tester);
    }

    Future<void> toLastPage(WidgetTester tester) async {
      while (find.text('تم طبخها').evaluate().isEmpty) {
        await tester.tap(find.text('التالي'));
        await settle(tester);
      }
    }

    testWidgets('comes right after cook mode closes from its last page, once '
        'there is a saved import and a cooked recipe — never from the close '
        'button, and not again within 120 days', (tester) async {
      // The kabsa is a website import (IMP-2), saved from the import
      // preview, which is what records "saved an import" (app_test.dart).
      final (_, settings) = await pumpApp(tester, withRecipe: true);
      await tester.runAsync(settings.recordImportSaved);
      await tester.tap(find.text('كبسة لحم'));
      await settle(tester);

      // Closed part-way through: never.
      await openCookMode(tester);
      await tester.tap(find.byTooltip('إغلاق وضع الطبخ'));
      await settle(tester);
      expect(storeReview.requests, 0);

      // "Done" with nothing marked as cooked yet: not yet.
      await openCookMode(tester);
      await toLastPage(tester);
      await tester.tap(find.text('تم'));
      await settle(tester);
      expect(storeReview.requests, 0);

      // "Mark as cooked" closes cook mode too: now both conditions hold.
      await openCookMode(tester);
      await toLastPage(tester);
      await tester.tap(find.text('تم طبخها'));
      await settle(tester);
      expect(storeReview.requests, 1);
      expect(settings.settings.reviewAskedAt, clock.now);
      // Back on the recipe (Decision 23's larger type scale can leave the
      // button out of the ListView's initial build range here too).
      await tester.scrollUntilVisible(
        find.text('ابدأ الطبخ'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ابدأ الطبخ'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // the snackbar goes
      await settle(tester);

      // Cooked again, the next day: the 120 days aren't up.
      clock.advance(const Duration(days: 1));
      await openCookMode(tester);
      await toLastPage(tester);
      await tester.tap(find.text('تم'));
      await settle(tester);
      expect(storeReview.requests, 1);
    });

    testWidgets('a library with only recipes written by hand never asks', (
      tester,
    ) async {
      final (recipes, _) = await pumpApp(tester);
      await tester.runAsync(() async {
        final repo = recipes.repository;
        final r = kabsa(repo);
        await recipes.save(r.copyWith(sourceType: SourceType.written));
      });
      await settle(tester);
      await tester.tap(find.text('كبسة لحم'));
      await settle(tester);
      await openCookMode(tester);
      await toLastPage(tester);
      await tester.tap(find.text('تم طبخها'));
      await settle(tester);
      expect(recipes.recipes.single.cookedCount, 1);
      expect(storeReview.requests, 0);
    });
  });
}
