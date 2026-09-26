// LANG-3 and LANG-5 on screen: numbers in the chosen digits wherever the
// app writes them (validation messages, counters, the plan's ×½), the
// store's prices as the store wrote them (PAY-2), and arrows and icons that
// point the way the language reads.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/widgets/nav_pill.dart';
import 'package:wasfati/l10n/app_localizations.dart';
import 'package:wasfati/models/plan.dart';
import 'package:wasfati/models/quantity/arabic_text.dart'
    show easternDigits, ownIsolate;
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/services/store.dart';

import 'app_test.dart' show plan, pumpApp, settle, shown;

final _lri = String.fromCharCode(0x2066);
final _pdi = String.fromCharCode(0x2069);

AppLocalizations _l10n(LanguagePref language) =>
    lookupAppLocalizations(Locale(language.name));

/// The shell's own tabs, scoped to the NavPill (the recipe and plan
/// pages carry the same icons in their app bars).
Finder _navTab(IconData icon) =>
    find.descendant(of: find.byType(NavPill), matching: find.byIcon(icon));

/// Scopes a text lookup to an open modal sheet, since the library's own
/// quick-chip row underneath (the same labels: بصورة، أقل من ٣٠ دقيقة،
/// مواقع التواصل) stays in the tree while the sheet is open.
Finder _inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

/// Which way the icon inside [button] is drawn: an icon that matches the
/// text direction is flipped in right-to-left text.
bool _pointsRight(WidgetTester tester, Finder button) {
  final f = find.descendant(of: button, matching: find.byType(Icon));
  final icon = tester.widget<Icon>(f).icon!;
  final flipped =
      icon.matchTextDirection &&
      Directionality.of(tester.element(f)) == TextDirection.rtl;
  return (icon == Icons.chevron_right) != flipped;
}

Future<void> _openRecipe(WidgetTester tester) async {
  await tester.tap(find.text('كبسة لحم'));
  await settle(tester);
}

void main() {
  group('LANG-5: direction', () {
    for (final language in [LanguagePref.ar, LanguagePref.en]) {
      testWidgets('${language.name}: the plan\'s week arrows sit at the ends '
          'and point outward, back toward the reading start', (tester) async {
        final l = _l10n(language);
        await pumpApp(tester, language: language, withRecipe: true);
        await tester.tap(_navTab(Icons.calendar_month_outlined));
        await settle(tester);

        final previous = find.byTooltip(l.planPreviousWeek);
        final next = find.byTooltip(l.planNextWeek);
        final previousX = tester.getCenter(previous).dx;
        final nextX = tester.getCenter(next).dx;
        if (language == LanguagePref.ar) {
          // Right to left: the previous week is on the right, pointing right.
          expect(previousX, greaterThan(nextX));
          expect(_pointsRight(tester, previous), isTrue);
          expect(_pointsRight(tester, next), isFalse);
        } else {
          expect(previousX, lessThan(nextX));
          expect(_pointsRight(tester, previous), isFalse);
          expect(_pointsRight(tester, next), isTrue);
        }
      });

      testWidgets('${language.name}: the walkthrough swipes forward in the '
          'reading direction', (tester) async {
        final l = _l10n(language);
        await pumpApp(tester, language: language, withRecipe: true);
        await tester.tap(find.byIcon(Icons.settings_outlined).first);
        await settle(tester);
        await tester.scrollUntilVisible(
          find.text(l.settingsReplayWalkthrough),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        await tester.tap(find.text(l.settingsReplayWalkthrough));
        await settle(tester);
        expect(find.text(l.walkthroughImportTitle), findsOneWidget);

        // Right to left, the next page comes in from the left: a swipe to
        // the right moves forward, the way an Arabic book turns.
        final forward = language == LanguagePref.ar ? 300.0 : -300.0;
        await tester.fling(find.byType(PageView), Offset(forward, 0), 1000);
        await settle(tester);
        expect(find.text(l.walkthroughScaleTitle), findsOneWidget);
        await tester.fling(find.byType(PageView), Offset(-forward, 0), 1000);
        await settle(tester);
        expect(find.text(l.walkthroughImportTitle), findsOneWidget);
      });

      testWidgets('${language.name}: cook mode\'s ingredients icon has its '
          'ticks at the reading start', (tester) async {
        final l = _l10n(language);
        await pumpApp(tester, language: language, withRecipe: true);
        await _openRecipe(tester);
        await tester.tap(find.text(l.startCooking));
        await settle(tester);
        final icon = tester.widget<Icon>(
          find
              .descendant(
                of: find.byTooltip(l.ingredients),
                matching: find.byType(Icon),
              )
              .first,
        );
        expect(
          icon.icon,
          language == LanguagePref.ar ? Icons.checklist_rtl : Icons.checklist,
        );
      });
    }

    testWidgets('the plan: "×٢" and "×½" keep the × first, and "٦ حصص" reads '
        'right to left (QTY-5)', (tester) async {
      final (recipes, _) = await pumpApp(
        tester,
        digits: DigitStyle.arabic,
        withRecipe: true,
      );
      final id = recipes.recipes.single.id;
      await tester.runAsync(() async {
        await plan.add(
          date: plan.today,
          slot: MealSlot.lunch,
          recipeId: id,
          servings: 6,
        );
        await plan.add(
          date: plan.today,
          slot: MealSlot.dinner,
          recipeId: id,
          multiplier: Rational(2),
        );
        await plan.add(
          date: plan.today,
          slot: MealSlot.snack,
          recipeId: id,
          multiplier: Rational.half,
        );
      });
      await settle(tester);
      await tester.tap(_navTab(Icons.calendar_month_outlined));
      await settle(tester);

      // Never "×1/2" or "×2": the glyph and the user's digits, isolated
      // left to right so the × can't move past its number.
      expect(find.text('$_lri×٢$_pdi'), findsOneWidget);
      expect(find.text('$_lri×½$_pdi'), findsOneWidget);
      expect(shown('1/2'), findsNothing);

      final servings = find.text('٦ حصص');
      expect(servings, findsOneWidget);
      expect(tester.widget<Text>(servings).textDirection, isNull);
      expect(Directionality.of(tester.element(servings)), TextDirection.rtl);
    });

    testWidgets('the time filter keeps "٣٠–٦٠" left to right in Arabic text', (
      tester,
    ) async {
      final l = _l10n(LanguagePref.ar);
      await pumpApp(tester, digits: DigitStyle.arabic, withRecipe: true);
      // LOOK-12: every ORG-6 filter, including total time, lives in one
      // sheet behind the search row's accent circle now.
      await tester.tap(find.byTooltip(l.filterAction));
      await settle(tester);
      // The quick-chip row keeps its own "أقل من ٣٠ دقيقة" chip beneath the
      // sheet (both scroll in the same tree), so it's scoped to the sheet
      // itself here (should-fix: `findsWidgets` let the quick chip alone
      // satisfy this without the sheet's own Arabic-digit chip rendering
      // at all).
      expect(_inSheet('أقل من ٣٠ دقيقة'), findsOneWidget);
      expect(find.text('$_lri٣٠–٦٠$_pdi دقيقة'), findsOneWidget);
      expect(find.text('أكثر من ساعة'), findsOneWidget);
    });
  });

  group('LANG-3, QTY-5: the chosen digits everywhere', () {
    testWidgets('the recipe page\'s times are one message each, in ١٢٣', (
      tester,
    ) async {
      await pumpApp(tester, digits: DigitStyle.arabic, withRecipe: true);
      await _openRecipe(tester);
      // LOOK-13: each fact tile's caption, then its value in one message.
      expect(find.text('التحضير'), findsOneWidget);
      expect(find.text('٦٠ دقيقة'), findsOneWidget);
      expect(find.text('الطبخ'), findsOneWidget);
      expect(find.text('١٢٠ دقيقة'), findsOneWidget);
    });

    testWidgets('English with ١٢٣: "Prep" over "٦٠ min"', (tester) async {
      await pumpApp(
        tester,
        language: LanguagePref.en,
        digits: DigitStyle.arabic,
        withRecipe: true,
      );
      await _openRecipe(tester);
      expect(find.text('Prep'), findsOneWidget);
      expect(find.text('٦٠ min'), findsOneWidget);
      expect(find.text('Cook'), findsOneWidget);
      expect(find.text('١٢٠ min'), findsOneWidget);
    });

    testWidgets('the editor: its numbers, its title counter and its limits '
        'in ١٢٣', (tester) async {
      final l = _l10n(LanguagePref.ar);
      await pumpApp(tester, digits: DigitStyle.arabic, withRecipe: true);
      await _openRecipe(tester);
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await settle(tester);

      Finder field(String label) => find.widgetWithText(TextFormField, label);
      String value(String label) =>
          tester.widget<TextFormField>(field(label)).controller!.text;
      expect(value(l.fieldServings), '٦');
      expect(value(l.fieldPrep), '٦٠');
      expect(value(l.fieldCook), '١٢٠');
      expect(find.text('٨/١٢٠'), findsOneWidget); // "كبسة لحم", 8 of 120
      expect(shown('مثل: ٢ كوب أرز'), findsOneWidget); // the hint's example

      await tester.enterText(field(l.fieldServings), '٥٠٠');
      await tester.tap(find.text(l.save));
      await settle(tester);
      expect(find.text('من ١ إلى ١٠٠'), findsOneWidget);
    });

    testWidgets("English with ١٢٣: the editor's limits follow the setting, "
        'but its example ingredient line keeps 123 (QTY-5)', (tester) async {
      final l = _l10n(LanguagePref.en);
      await pumpApp(
        tester,
        language: LanguagePref.en,
        digits: DigitStyle.arabic,
        withRecipe: true,
      );
      await _openRecipe(tester);
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await settle(tester);
      expect(shown('e.g. 2 cups rice'), findsOneWidget);

      final servings = find.widgetWithText(TextFormField, l.fieldServings);
      await tester.enterText(servings, '500');
      await tester.tap(find.text(l.save));
      await settle(tester);
      expect(find.text('١ to ١٠٠'), findsOneWidget);
    });

    testWidgets("English with ١٢٣: an empty plan note's limits read from "
        'one to sixty, never a dash between two Arabic numbers that flips '
        'them (LANG-5, PLAN-2)', (tester) async {
      final l = _l10n(LanguagePref.en);
      await pumpApp(
        tester,
        language: LanguagePref.en,
        digits: DigitStyle.arabic,
        withRecipe: true,
      );
      await tester.tap(_navTab(Icons.calendar_month_outlined));
      await settle(tester);
      // An empty meal's "+ Add" (PLAN-1, PLAN-3).
      await tester.tap(find.text(l.planAdd).hitTestable().first);
      await settle(tester);
      await tester.tap(find.widgetWithText(ListTile, l.planAddNote));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await settle(tester);
      expect(find.text('١ to ٦٠ characters'), findsOneWidget);
    });

    // PAY-2: the store's price exactly as the store wrote it, even in ١٢٣,
    // in its own direction isolate (LANG-5). Its "." and "," are the
    // store's: "Rp 329.000" groups thousands, and the Arabic decimal mark
    // would make it 329 point 000, a thousand times too little.
    for (final (language, price, once) in [
      (LanguagePref.ar, 'AED 14.99', 'مرة واحدة'),
      (LanguagePref.en, 'AED 14.99', 'once'),
      (LanguagePref.ar, 'Rp 329.000', 'مرة واحدة'),
      (LanguagePref.en, r'R$ 1.299,90', 'once'),
    ]) {
      testWidgets('${language.name}: the store\'s price "$price" as the '
          'store wrote it, in ١٢٣ too (PAY-2)', (tester) async {
        final l = _l10n(language);
        await pumpApp(
          tester,
          language: language,
          digits: DigitStyle.arabic,
          storeOverride: NoopPurchaseStore(
            offers: [StoreOffer(product: Product.pro, price: price)],
          ),
        );
        await tester.tap(find.byIcon(Icons.settings_outlined).first);
        await settle(tester);
        await tester.scrollUntilVisible(
          find.text(l.settingsSubscription),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        await tester.tap(find.text(l.settingsSubscription));
        await settle(tester);
        expect(find.text('${ownIsolate(price)} $once'), findsOneWidget);
        expect(shown(easternDigits(price)), findsNothing);
      });
    }
  });
}
