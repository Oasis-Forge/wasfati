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
import 'package:flutter/semantics.dart' show SemanticsNode;
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
import 'package:wasfati/widgets/ad_slot.dart';
import 'package:wasfati/widgets/digit_box.dart';

import '../helpers.dart' show kabsa;
import 'app_test.dart' show groceries, plan, pumpApp, settle;

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

        // The recipe page (ingredients through AmountLine and RailHeading,
        // the hero photo/cards/chips through Decor).
        await tester.tap(find.text('كبسة لحم'));
        await settle(tester);
        _fits(tester, 'recipe');

        // Cook mode (LOOK-7's ledge, COOK-2's sizes in both looks). A
        // generous single drag (never past the list's own clamped end)
        // rather than scrollUntilVisible/ensureVisible: both of those stop
        // as soon as the button's leading edge merely enters the cache
        // extent, which can still leave its centre — what tap() targets —
        // a few pixels past the bottom of a 360x800 view at 1.3x text.
        await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
        await settle(tester);
        _fits(tester, 'recipe, scrolled');
        await tester.tap(find.byIcon(Icons.soup_kitchen_outlined));
        await settle(tester);
        _fits(tester, 'cook mode');
        await tester.tap(find.byTooltip(l.ingredients));
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

        await tester.tap(find.byType(BackButton).first);
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
        await tester.tap(find.byType(BackButton).first);
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

        await tester.tap(find.byType(BackButton).first);
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

  // should-fix, platform review: the branch's one new control — the "الطراز"
  // / Look row settings_screen.dart adds — had no test tapping it; every
  // existing looks test only sets the look programmatically
  // (`settings.update(...copyWith(style: ...))`) and never touches the row
  // itself.
  testWidgets(
    'Settings: tapping حبر changes the theme at once, no restart (LOOK-1, '
    'Decision 23)',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await settle(tester);
      // The Look row sits below the fold (past language/digits/units/week
      // start): a plain ListView still virtualises its own children by
      // viewport, so it isn't mounted until scrolled into view (the same
      // reason test/widget/ramadan_test.dart's own Settings test scrolls).
      await tester.scrollUntilVisible(
        find.text('حبر'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);

      BuildContext context() => tester.element(find.text('حبر'));
      final beforeBrightness = Theme.of(context()).brightness;
      expect(
        Theme.of(context()).colorScheme.primary,
        wasfatiColorScheme(AppStyle.saffron, beforeBrightness).primary,
        reason: 'Saffron is the default look for a new install (Decision 23)',
      );

      await tester.tap(find.text('حبر'));
      await settle(tester);

      // Still the same Settings screen — no navigation, no restart — with
      // its theme now Ink's, and the light/dark setting untouched.
      expect(find.text('حبر'), findsOneWidget);
      final afterBrightness = Theme.of(context()).brightness;
      expect(afterBrightness, beforeBrightness);
      expect(
        Theme.of(context()).colorScheme.primary,
        wasfatiColorScheme(AppStyle.ink, afterBrightness).primary,
      );
    },
  );

  // LOOK-6: Decor's grouped-row fill, card shape and row hairline were
  // built for both looks and read nowhere (Known bugs). Settings' groups
  // and the plan's day cards now draw with them; LOOK-2 still holds, so
  // every row, string and control is where it was.
  for (final style in AppStyle.values) {
    testWidgets('${style.name}: Settings groups its rows in the look\'s '
        'fill, card shape and hairlines (LOOK-6)', (tester) async {
      final (_, settings) = await pumpApp(tester);
      await tester.runAsync(
        () => settings.update(settings.settings.copyWith(style: style)),
      );
      await settle(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await settle(tester);

      final decor = Decor.of(tester.element(find.text('١٢٣')));
      // The digit-style group: its two rows in one Material drawn with
      // the look's own fill and card shape, split by one hairline.
      final group = find.ancestor(
        of: find.text('١٢٣'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Material &&
              w.shape == decor.cardShape &&
              w.color == decor.groupedRowFill,
        ),
      );
      expect(group, findsOneWidget);
      expect(
        find.descendant(of: group, matching: find.text('123')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: group,
          matching: find.byWidgetPredicate(
            (w) => w is Divider && w.color == decor.rowHairline,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('${style.name}: the plan\'s day cards take the look\'s '
        'fill and card shape, and only today carries its rail (LOOK-6)', (
      tester,
    ) async {
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

      final decor = Decor.of(tester.element(find.text('اليوم')));
      final dayCards = find.byWidgetPredicate(
        (w) =>
            w is Material &&
            w.shape == decor.cardShape &&
            w.color == decor.groupedRowFill,
      );
      final today = find.ancestor(of: find.text('اليوم'), matching: dayCards);
      expect(today, findsOneWidget);
      final rail = find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == decor.railColor,
      );
      // One rail across every day card built, and it's today's.
      expect(find.descendant(of: dayCards, matching: rail), findsOneWidget);
      expect(find.descendant(of: today, matching: rail), findsOneWidget);
      expect(
        tester.getSize(find.descendant(of: today, matching: rail)).width,
        decor.railWidth,
      );
    });

    // must-fix, look-pass review: the day card's Card became a Material,
    // which dropped the semantics container Card adds, and TalkBack read
    // all seven days as one flat run of dates, meals and add buttons.
    testWidgets('${style.name}: a screen reader still reads each day card '
        'as one group: date, "اليوم", meals, then its add buttons', (
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

      // Today (the fake clock's Saturday 19 September) is one node whose
      // label runs date, "اليوم", then the four meals.
      final today = find.bySemanticsLabel(
        RegExp(r'^السبت، 19 سبتمبر\nاليوم\nفطور\nغداء\nعشاء\nوجبة خفيفة$'),
      );
      expect(today, findsOneWidget);
      // The date is no longer a node of its own, loose among other days'.
      expect(find.bySemanticsLabel('السبت، 19 سبتمبر'), findsNothing);
      expect(find.bySemanticsLabel('اليوم'), findsNothing);
      // Its four add buttons (IconButtons, named by their tooltip) sit
      // inside it, one per meal.
      final adds = <String>[];
      void collect(SemanticsNode node) {
        if (node.tooltip == 'إضافة') adds.add(node.tooltip);
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      collect(tester.getSemantics(today));
      expect(adds, hasLength(4));
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
    // Decision 23's larger type scale can push the button out of the
    // ListView's initial build range.
    await tester.scrollUntilVisible(
      find.text('ابدأ الطبخ'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await tester.tap(find.text('ابدأ الطبخ'));
    await settle(tester);
    expect(boxed('الخطوة 1 من 2'), findsWidgets);

    await tester.tap(find.text('التالي'));
    await settle(tester);
    await tester.tap(find.text('15:00'));
    await settle(tester);
    // The countdown may already have ticked: this clock is real.
    final running = find.textContaining(RegExp(r'^1[45]:\d\d · الخطوة 2$'));
    expect(running, findsOneWidget);
    expect(
      find.ancestor(of: running, matching: find.byType(DigitBox)),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('إغلاق وضع الطبخ'));
    await settle(tester);
    await tester.tap(find.byType(BackButton).first);
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
    await tester.tap(find.text('×½'));
    await settle(tester);
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
