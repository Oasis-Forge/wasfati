// LOOK-8, LANG-6: every screen renders in both looks, both brightnesses
// and both languages, at 1.3x text on a 360dp phone, without overflow. Four
// runs (Ink/Saffron x light/dark), language and digit style alternated
// across them so every pairing is still covered — the failure mode LOOK-8
// guards against (a RenderFlex overflow) is far more sensitive to text
// length and scale than to which two brightnesses of the same look are on
// screen, so the full cross product would multiply run time for little
// extra confidence. Setup and a fresh install's walkthrough have their own
// 1.3x runs in first_run_test.dart; here the walkthrough is replayed from
// Settings in the chosen digits.
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderFlex, RenderParagraph;
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/widgets/nav_pill.dart';
import 'package:wasfati/l10n/app_localizations.dart';
import 'package:wasfati/models/grocery.dart';
import 'package:wasfati/models/plan.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/services/ads.dart';
import 'package:wasfati/services/store.dart';
import 'package:wasfati/theme/colors.dart' show wasfatiColorScheme;
import 'package:wasfati/theme/decor.dart';
import 'package:wasfati/widgets/sufra_card.dart';
import 'package:wasfati/widgets/ad_slot.dart';
import 'package:wasfati/widgets/digit_box.dart';

import '../helpers.dart' show kabsa;
import 'app_test.dart'
    show groceries, openStepsTab, plan, pumpApp, settle, tapOnPage;

const _offers = [
  StoreOffer(product: Product.pro, price: 'AED 14.99'),
  StoreOffer(
    product: Product.premium,
    plan: PremiumPlan.monthly,
    price: 'AED 9.99',
  ),
  StoreOffer(
    product: Product.premium,
    plan: PremiumPlan.yearly,
    price: 'AED 79.99',
  ),
];

const _englishTitle = 'Slow-roasted chicken shawarma wraps with garlic sauce';

/// An English recipe with long words, beside the Arabic kabsa, so both
/// directions of content are on every list and page.
Recipe _englishRecipe(String id, DateTime now) => Recipe(
  id: id,
  title: _englishTitle,
  servings: 4,
  prepMinutes: 25,
  cookMinutes: 90,
  ingredients: [
    Section(
      id: '$id-i',
      items: [
        IngredientLine.parse('$id-1', '1.5 kg boneless chicken thighs'),
        IngredientLine.parse('$id-2', '2 tbsp shawarma spice mix'),
      ],
    ),
  ],
  steps: [
    Section(
      id: '$id-s',
      items: [
        RecipeStep(
          id: '$id-3',
          text: 'Roast for 90 minutes, then rest for 10 minutes.',
        ),
      ],
    ),
  ],
  createdAt: now,
  updatedAt: now,
);

/// Drags [scrollable] a screen at a time to its end, checking each view.
Future<void> _scrollThrough(
  WidgetTester tester,
  Finder scrollable,
  String reason,
) async {
  for (var i = 0; i < 20; i++) {
    final position = tester.state<ScrollableState>(scrollable).position;
    if (position.pixels >= position.maxScrollExtent) return;
    await tester.drag(scrollable, const Offset(0, -500));
    await settle(tester);
    _fits(tester, '$reason, ${i + 1} down');
  }
}

/// Fails when anything overflowed since the last check, naming what the
/// overflowing row or column shows, so a failure says where to look.
void _fits(WidgetTester tester, String where) {
  final error = tester.takeException();
  if (error == null) return;
  final culprits = [
    for (final box in tester.allRenderObjects)
      if (box is RenderFlex && box.toString().contains('OVERFLOWING'))
        find
            .descendant(
              of: find.byElementPredicate((e) => e.renderObject == box),
              matching: find.byType(Text),
            )
            .evaluate()
            .map((e) => (e.widget as Text).data ?? '')
            .join(' | '),
  ];
  fail('$where: $error ${culprits.join('; ')}');
}

void main() {
  final cases = [
    (
      style: AppStyle.ink,
      theme: ThemePref.light,
      language: LanguagePref.ar,
      digits: DigitStyle.western,
    ),
    (
      style: AppStyle.ink,
      theme: ThemePref.dark,
      language: LanguagePref.en,
      digits: DigitStyle.arabic,
    ),
    (
      style: AppStyle.saffron,
      theme: ThemePref.light,
      language: LanguagePref.en,
      digits: DigitStyle.western,
    ),
    (
      style: AppStyle.saffron,
      theme: ThemePref.dark,
      language: LanguagePref.ar,
      digits: DigitStyle.arabic,
    ),
  ];

  for (final c in cases) {
    testWidgets(
      '${c.style.name}/${c.theme.name}/${c.language.name}/${c.digits.name} '
      'at 1.3x on 360dp: every screen renders with no overflow (LOOK-8, '
      'LANG-6)',
      (tester) async {
        final l = lookupAppLocalizations(Locale(c.language.name));
        final (recipes, settings) = await pumpApp(
          tester,
          language: c.language,
          digits: c.digits,
          textScale: 1.3,
          withRecipe: true,
          // A store selling both tiers and an ad network that fills, so the
          // banner, its "remove ads" link and every price are on screen.
          storeOverride: NoopPurchaseStore(offers: _offers),
          adServiceOverride: NoopAdService(
            consent: const AdConsent(
              canRequestAds: true,
              privacyOptionsRequired: true,
            ),
            fills: true,
          ),
        );
        // A real (non-fake-timer) DB write, called outside any widget
        // event handler, needs to escape the fake-async zone or it never
        // resolves (ramadan_test.dart's own comment, same reason).
        await tester.runAsync(() async {
          await settings.update(
            settings.settings.copyWith(style: c.style, theme: c.theme),
          );
          final kabsa = recipes.recipes.single;
          final repo = recipes.repository;
          final english = await recipes.save(
            _englishRecipe(repo.newId(), repo.now()),
          );
          await recipes.saveCookbook(l.walkthroughDemoRecipe);
          // The plan and groceries with rows in them, not their empty
          // states: servings, a ×½, a full-length note, and lines from
          // both recipes.
          await plan.add(
            date: plan.today,
            slot: MealSlot.lunch,
            recipeId: kabsa.id,
            servings: 6,
          );
          await plan.add(
            date: plan.today,
            slot: MealSlot.dinner,
            recipeId: english!.id,
            multiplier: Rational.half,
          );
          await plan.add(
            date: plan.today,
            slot: MealSlot.snack,
            note: 'ب' * PlanEntry.maxNote,
          );
          await groceries.add([
            IncomingLine(
              name: 'لحم ضأن',
              min: Rational(3, 2),
              unitId: 'kg',
              recipeId: kabsa.id,
            ),
            IncomingLine(
              name: 'boneless chicken thighs',
              min: Rational(3, 2),
              unitId: 'kg',
              recipeId: english.id,
            ),
          ]);
          await groceries.addByHand('ملعقة كبيرة سكر بني ناعم للتزيين');
        });
        await settle(tester);
        _fits(tester, 'library');
        // PAY-5's small target fits on the slot's own line, above the ad.
        expect(find.text(l.adSlotRemoveAds), findsOneWidget);
        expect(
          tester.getSize(find.text(l.adSlotRemoveAds)).height,
          lessThanOrEqualTo(AdSlot.targetLine),
        );

        await tester.tap(find.text(l.tabCookbooks));
        await settle(tester);
        _fits(tester, 'cookbooks');
        await tester.tap(find.text(l.tabAllRecipes));
        await settle(tester);

        // The recipe page (LOOK-13): the cover header, the facts, the scale
        // card and the ingredients, then the Steps tab, top to bottom each,
        // and the "more" sheet.
        final back = c.language == LanguagePref.ar ? 'رجوع' : 'Back';
        await tester.tap(find.text('كبسة لحم'));
        await settle(tester);
        _fits(tester, 'recipe');
        await _scrollThrough(tester, find.byType(Scrollable).first, 'recipe');
        await openStepsTab(tester, label: l.steps);
        _fits(tester, 'recipe steps');
        await _scrollThrough(
          tester,
          find.byType(Scrollable).first,
          'recipe steps',
        );
        await tester.tap(find.byTooltip(l.moreActions));
        await settle(tester);
        _fits(tester, 'recipe more');
        await tester.tapAt(const Offset(180, 40)); // the sheet's barrier
        await settle(tester);

        // Cook mode (COOK-2's sizes, LOOK-14), from the action bar.
        await tester.tap(find.text(l.startCooking));
        await settle(tester);
        _fits(tester, 'cook mode');
        await tester.tap(find.byTooltip(l.ingredients).first);
        await settle(tester);
        _fits(tester, 'cook ingredients');
        await tester.tapAt(const Offset(180, 40)); // the sheet's barrier
        await settle(tester);
        // Every step, then the last page (mark as cooked, done).
        while (find.text(l.markCooked).evaluate().isEmpty) {
          await tester.tap(find.text(l.nextStep));
          await settle(tester);
          _fits(tester, 'cook mode step');
        }
        _fits(tester, 'cook mode done');

        await tester.tap(find.byTooltip(l.closeCooking));
        await settle(tester);
        _fits(tester, 'back to recipe');

        // The editor, top to bottom.
        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await settle(tester);
        _fits(tester, 'editor');
        await _scrollThrough(tester, find.byType(Scrollable).first, 'editor');

        await tester.tap(find.byType(BackButton).first);
        await settle(tester);
        _fits(tester, 'back to recipe');

        await tester.tap(find.byTooltip(back));
        await settle(tester);
        _fits(tester, 'back to library');

        // The English recipe's page too: content in the other direction.
        // The library home's own rhythm (`sectionGap`, LOOK-12) can sit a
        // card lower on screen than the fixed nav pill leaves room for at
        // this text scale, so it's scrolled into view rather than assumed
        // to already be on screen.
        await tester.scrollUntilVisible(
          find.text(_englishTitle),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        await tester.tap(find.text(_englishTitle));
        await settle(tester);
        _fits(tester, 'English recipe');
        await openStepsTab(tester, label: l.steps);
        _fits(tester, 'English recipe steps');
        await tester.tap(find.byTooltip(back));
        await settle(tester);

        // The meal plan and groceries (the shell's own tabs) — scoped to
        // the NavPill itself: the recipe and plan pages carry their
        // own AppBar actions with these same icons ("planAddToPlan",
        // "addToGroceries"), so an unscoped find.byIcon can tap the wrong
        // one once the plan/groceries tabs are mounted underneath.
        Finder navTab(IconData icon) => find.descendant(
          of: find.byType(NavPill),
          matching: find.byIcon(icon),
        );
        await tester.tap(navTab(Icons.calendar_month_outlined));
        await settle(tester);
        _fits(tester, 'plan');
        await _scrollThrough(tester, find.byType(Scrollable).first, 'plan');

        await tester.tap(navTab(Icons.shopping_basket_outlined));
        await settle(tester);
        _fits(tester, 'groceries');
        await tester.tap(find.text(l.groceriesByRecipe));
        await settle(tester);
        _fits(tester, 'groceries by recipe');
        await tester.tap(find.text(l.groceriesByAisle));
        await settle(tester);

        await tester.tap(navTab(Icons.menu_book_outlined));
        await settle(tester);
        _fits(tester, 'back to library');

        // The add sheet (LOOK-11), then import through its first tile.
        await tester.tap(find.byTooltip(l.recipesAdd));
        await settle(tester);
        _fits(tester, 'add sheet');
        await tester.tap(find.text(l.importTitle));
        await settle(tester);
        _fits(tester, 'import');

        await tester.tap(find.byTooltip(back));
        await settle(tester);
        _fits(tester, 'back to library');

        // Settings, top to bottom, with the Look row (LOOK-1) and the
        // paying rows (PAY-5, PAY-11, ADS-5).
        await tester.tap(find.byIcon(Icons.settings_outlined).first);
        await settle(tester);
        _fits(tester, 'settings');
        final settingsList = find.byType(Scrollable).first;

        // The purchase screen, from its Settings row (PAY-5, PAY-10).
        await tester.scrollUntilVisible(
          find.text(l.settingsSubscription),
          300,
          scrollable: settingsList,
        );
        await settle(tester);
        _fits(tester, 'settings, paying');
        await tester.tap(find.text(l.settingsSubscription));
        await settle(tester);
        _fits(tester, 'purchase');
        await _scrollThrough(tester, find.byType(Scrollable).first, 'purchase');
        await tester.tap(find.byTooltip(l.purchaseClose));
        await settle(tester);

        // The walkthrough, replayed: each of its four pages (RUN-4).
        await tester.scrollUntilVisible(
          find.text(l.settingsReplayWalkthrough),
          300,
          scrollable: settingsList,
        );
        await settle(tester);
        await tester.tap(find.text(l.settingsReplayWalkthrough));
        await settle(tester);
        final pages = [
          l.walkthroughImportTitle,
          l.walkthroughScaleTitle,
          l.walkthroughCookTitle,
          l.walkthroughPlanTitle,
        ];
        for (final (i, title) in pages.indexed) {
          expect(find.text(title), findsOneWidget);
          _fits(tester, 'walkthrough $i');
          await tester.tap(
            find.text(i < 3 ? l.walkthroughNext : l.walkthroughStart),
          );
          await settle(tester);
        }
        _fits(tester, 'back to settings');

        await _scrollThrough(tester, settingsList, 'settings');
      },
    );
  }

  // LANG-6: the purchase screen's other states, in both languages at 1.3x:
  // both tiers owned (Premium's "Manage or cancel"), and nothing for sale
  // yet ("Coming soon" in both cards, PAY-3).
  for (final language in [LanguagePref.ar, LanguagePref.en]) {
    for (final (name, owned, offers) in [
      ('both tiers owned', {Product.pro, Product.premium}, _offers),
      ('nothing for sale', <Product>{}, const <StoreOffer>[]),
    ]) {
      testWidgets('${language.name}: the purchase screen with $name fits at '
          '1.3x on 360dp (LANG-6, PAY-10)', (tester) async {
        final l = lookupAppLocalizations(Locale(language.name));
        await pumpApp(
          tester,
          language: language,
          digits: DigitStyle.arabic,
          textScale: 1.3,
          storeOverride: NoopPurchaseStore(owned: owned, offers: offers),
        );
        await tester.tap(find.byIcon(Icons.settings_outlined).first);
        await settle(tester);
        await tester.scrollUntilVisible(
          find.text(l.settingsSubscription),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        _fits(tester, 'settings, paying');
        await tester.tap(find.text(l.settingsSubscription));
        await settle(tester);
        _fits(tester, 'purchase');
        await _scrollThrough(tester, find.byType(Scrollable).first, 'purchase');
      });
    }
  }

  // LOOK-1: the Look row opens its sheet, which shows both accents as
  // swatches with their names; choosing one applies at once, no restart.
  testWidgets(
    'Settings: choosing حبر in the Look sheet changes the theme at once, no '
    'restart (LOOK-1, Decision 23)',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await settle(tester);

      BuildContext context() => tester.element(find.text('الطراز'));
      final beforeBrightness = Theme.of(context()).brightness;
      expect(
        Theme.of(context()).colorScheme.primary,
        wasfatiColorScheme(AppStyle.saffron, beforeBrightness).primary,
        reason: 'Saffron is the default look for a new install (Decision 23)',
      );
      // The row says which accent is on, beside a dot in it.
      expect(find.text('زعفران'), findsOneWidget);

      await tester.tap(find.text('الطراز'));
      await settle(tester);
      // The sheet: both accents, each by name, the current one ticked.
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('زعفران')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      await tester.tap(find.descendant(of: sheet, matching: find.text('حبر')));
      await settle(tester);

      // Still the same Settings screen — no navigation, no restart — with
      // its theme now Ink's, and the light/dark setting untouched.
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('حبر'), findsOneWidget);
      final afterBrightness = Theme.of(context()).brightness;
      expect(afterBrightness, beforeBrightness);
      expect(
        Theme.of(context()).colorScheme.primary,
        wasfatiColorScheme(AppStyle.ink, afterBrightness).primary,
      );
    },
  );

  // LOOK-6, design-styles.md "Settings": each group is one card, its rows
  // split by the look's row hairline; LOOK-2 still holds, so every row,
  // string and control is where it was in both accents.
  for (final style in AppStyle.values) {
    testWidgets('${style.name}: Settings groups its rows on one card, split '
        'by the look\'s hairlines (LOOK-6)', (tester) async {
      final (_, settings) = await pumpApp(tester);
      await tester.runAsync(
        () => settings.update(settings.settings.copyWith(style: style)),
      );
      await settle(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await settle(tester);

      final decor = Decor.of(tester.element(find.text('١٢٣')));
      // The look-and-language group: its four rows on one card, the
      // digits inline, split by three hairlines.
      final group = find.ancestor(
        of: find.text('١٢٣'),
        matching: find.byType(SufraCard),
      );
      expect(group, findsOneWidget);
      for (final label in ['الطراز', 'المظهر', 'اللغة', 'الأرقام', '123']) {
        expect(
          find.descendant(of: group, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: group,
          matching: find.byWidgetPredicate(
            (w) => w is Divider && w.color == decor.rowHairline,
          ),
        ),
        findsNWidgets(3),
      );
      // Each row at least 60dp tall, its icon on a 36dp tile.
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.text('المظهر'),
                matching: find.byType(InkWell),
              ),
            )
            .height,
        greaterThanOrEqualTo(60),
      );
    });

    // LOOK-2: the accent changes colour only — the strip marks the chosen
    // day, today and a day with entries the same way in both (PLAN-1).
    testWidgets('${style.name}: the plan\'s week strip fills the chosen day '
        'with ink and its accent dot, and marks a day with entries with the '
        'herb dot (LOOK-2, PLAN-1)', (tester) async {
      final (_, settings) = await pumpApp(tester, withRecipe: true);
      await tester.runAsync(() async {
        await settings.update(
          settings.settings.copyWith(
            style: style,
            weekStart: WeekStart.saturday,
          ),
        );
        await plan.add(
          date: DateTime(2026, 9, 21),
          slot: MealSlot.lunch,
          note: 'مطعم',
        );
      });
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavPill),
          matching: find.byIcon(Icons.calendar_month_outlined),
        ),
      );
      await settle(tester);

      Finder pill(String key) => find.byKey(ValueKey('plan-day-$key'));
      Color? dot(String key) =>
          (tester
                      .widget<Container>(
                        find.descendant(
                          of: pill(key),
                          matching: find.byKey(const ValueKey('plan-dot')),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color;
      final cs = Theme.of(tester.element(pill('2026-09-19'))).colorScheme;
      final today = tester.widget<Container>(
        find
            .descendant(
              of: pill('2026-09-19'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((today.decoration! as ShapeDecoration).color, cs.onSurface);
      expect(dot('2026-09-19'), cs.primary);
      expect(dot('2026-09-21'), cs.secondary);
      expect(dot('2026-09-20'), Colors.transparent);
    });

    // must-fix, look-pass review (carried over from the day cards): a
    // screen reader reads each day as one control, not a loose run of
    // numbers and dots.
    testWidgets('${style.name}: a screen reader hears each day of the strip '
        'as one selectable button: its date, "اليوم" and its meals', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final (_, settings) = await pumpApp(tester, withRecipe: true);
      await tester.runAsync(
        () => settings.update(settings.settings.copyWith(style: style)),
      );
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavPill),
          matching: find.byIcon(Icons.calendar_month_outlined),
        ),
      );
      await settle(tester);

      // Today (the fake clock's Saturday 19 September), chosen.
      final today = find.bySemanticsLabel(
        RegExp(r'^السبت، 19 سبتمبر، اليوم، لا وجبات$'),
      );
      expect(today, findsOneWidget);
      expect(
        tester.getSemantics(today),
        isSemantics(
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      // Its short name and number aren't nodes of their own.
      expect(find.bySemanticsLabel('سبت'), findsNothing);
      semantics.dispose();
    });
  }

  // LOOK-5: the numbers that step in place go through DigitBox, which
  // reads exactly like the plain Text it replaced (same find.text match).
  testWidgets('cook mode\'s step numeral and running timer, and the '
      'recipe\'s ×factor readout, are boxed digits (LOOK-5)', (tester) async {
    final (recipes, _) = await pumpApp(tester, withRecipe: true);
    Finder boxed(String text) =>
        find.ancestor(of: find.text(text), matching: find.byType(DigitBox));

    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    await tester.tap(find.text('ابدأ الطبخ'));
    await settle(tester);
    expect(boxed('الخطوة 1 من 2'), findsWidgets);

    await tester.tap(find.text('التالي'));
    await settle(tester);
    await tester.tap(find.text('ابدأ مؤقت 15:00'));
    await settle(tester);
    // The running band's countdown (LOOK-14), beside its step, and the
    // timer card's own. The countdown may already have ticked: this clock
    // is real.
    expect(
      find.descendant(
        of: find.byType(DigitBox),
        matching: find.textContaining(RegExp(r'^1[45]:\d\d$')),
      ),
      findsNWidgets(2),
    );
    expect(find.text('الخطوة 2'), findsOneWidget);
    await tester.tap(find.byTooltip('إغلاق وضع الطبخ'));
    await settle(tester);
    await tester.tap(find.byTooltip('رجوع'));
    await settle(tester);

    // Three servings at ×½ isn't a whole number of servings, so the
    // stepper shows the factor itself (SCALE-2).
    await tester.runAsync(() async {
      final repo = recipes.repository;
      final now = repo.now();
      await recipes.save(
        Recipe(
          id: repo.newId(),
          title: 'شوربة',
          servings: 3,
          ingredients: [
            Section(
              id: repo.newId(),
              items: [IngredientLine.parse(repo.newId(), '3 كوب ماء')],
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
    await settle(tester);
    // The library home's own rhythm (`sectionGap`, LOOK-12) can now sit the
    // newest recipe's tile lower on a short phone than the fixed nav pill's
    // own space leaves room for — scrolled into view rather than assumed
    // to already be on screen.
    await tester.scrollUntilVisible(
      find.text('شوربة'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await tester.tap(find.text('شوربة'));
    await settle(tester);
    await tapOnPage(tester, find.text('×½'));
    expect(boxed('×½'), findsOneWidget);
  });

  // LOOK-8: the library home's own worst case for its leading slivers —
  // the header, the backup reminder (10+ recipes, never backed up) and the
  // "تابع الطبخ" resume card, all on screen together, with a filled ad
  // banner too — on both a tall and a short 360dp phone.
  for (final language in [LanguagePref.ar, LanguagePref.en]) {
    for (final (label, height) in [('360x800', 800.0), ('360x640', 640.0)]) {
      testWidgets(
        '${language.name}/$label at 1.3x: the resume card, the backup '
        'reminder and a filled banner together fit with no overflow '
        '(LOOK-8)',
        (tester) async {
          tester.view.physicalSize = Size(1080, height * 3);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);

          final (recipes, _) = await pumpApp(
            tester,
            language: language,
            textScale: 1.3,
            withRecipe: true,
            adServiceOverride: NoopAdService(
              consent: const AdConsent(
                canRequestAds: true,
                privacyOptionsRequired: false,
              ),
              fills: true,
            ),
          );
          late String id;
          await tester.runAsync(() async {
            final repo = recipes.repository;
            id = recipes.recipes.single.id;
            for (var i = 0; i < 9; i++) {
              await recipes.save(kabsa(repo, title: 'وصفة $i'));
            }
            await recipes.setCookPage(id, 1, 2);
          });
          await settle(tester);

          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('كبسة لحم'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await settle(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  // LANG-6: the editor's three-in-a-row number fields, whose own label was
  // fixed to wrap (`Text(label, maxLines: 2)`) rather than silently
  // ellipsize a floating label — measured with the app's own bundled font,
  // not the test font (whose every glyph is 1em square), since only the
  // real glyph widths reproduce the wrap the fix depends on.
  group('LANG-6: the editor\'s servings/prep/cook labels never clip at '
      '1.3x on 360dp', () {
    setUpAll(() async {
      final loader = FontLoader('IBMPlexSansArabic');
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        final bytes = File('assets/fonts/IBMPlexSansArabic-$weight.ttf')
            .readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    });

    for (final language in [LanguagePref.ar, LanguagePref.en]) {
      testWidgets(language.name, (tester) async {
        final l = lookupAppLocalizations(Locale(language.name));
        await pumpApp(
          tester,
          language: language,
          textScale: 1.3,
          withRecipe: true,
        );
        await tester.scrollUntilVisible(
          find.text('كبسة لحم'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        await tester.tap(find.text('كبسة لحم'));
        await settle(tester);
        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await settle(tester);
        await tester.scrollUntilVisible(
          find.text(l.fieldServings),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);

        for (final label in [l.fieldServings, l.fieldPrep, l.fieldCook]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        }
      });
    }
  });
}
