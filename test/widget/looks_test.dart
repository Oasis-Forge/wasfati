// LOOK-8: every main screen renders in both looks, both brightnesses and
// both languages, at 1.3x text on a 360dp phone, without overflow. Four
// runs (Ink/Saffron x light/dark), language alternated across them so both
// still get covered — the failure mode LOOK-8 guards against (a RenderFlex
// overflow) is far more sensitive to text length and scale than to which
// two brightnesses of the same look are on screen, so the full eight-way
// cross product would multiply run time for little extra confidence.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/theme/colors.dart' show wasfatiColorScheme;
import 'package:wasfati/theme/decor.dart';
import 'package:wasfati/widgets/digit_box.dart';

import 'app_test.dart' show pumpApp, settle;

void main() {
  final cases = [
    (style: AppStyle.ink, theme: ThemePref.light, language: LanguagePref.ar),
    (style: AppStyle.ink, theme: ThemePref.dark, language: LanguagePref.en),
    (
      style: AppStyle.saffron,
      theme: ThemePref.light,
      language: LanguagePref.en,
    ),
    (style: AppStyle.saffron, theme: ThemePref.dark, language: LanguagePref.ar),
  ];

  for (final c in cases) {
    testWidgets(
      '${c.style.name}/${c.theme.name}/${c.language.name} at 1.3x on 360dp: '
      'every main screen renders with no overflow (LOOK-8, LANG-6)',
      (tester) async {
        final (_, settings) = await pumpApp(
          tester,
          language: c.language,
          textScale: 1.3,
          withRecipe: true,
        );
        // A real (non-fake-timer) DB write, called outside any widget
        // event handler, needs to escape the fake-async zone or it never
        // resolves (ramadan_test.dart's own comment, same reason).
        await tester.runAsync(
          () => settings.update(
            settings.settings.copyWith(style: c.style, theme: c.theme),
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'library');

        // The recipe page (ingredients through AmountLine and RailHeading,
        // the hero photo/cards/chips through Decor). Already on screen —
        // one recipe, no scroll needed (and the library's TabBarView
        // keeps more than one Scrollable mounted, so scrollUntilVisible's
        // own default `scrollable` finder can't disambiguate here).
        await tester.tap(find.text('كبسة لحم'));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'recipe');

        // Cook mode (LOOK-7's ledge, COOK-2's sizes in both looks). A
        // generous single drag (never past the list's own clamped end)
        // rather than scrollUntilVisible/ensureVisible: both of those stop
        // as soon as the button's leading edge merely enters the cache
        // extent, which can still leave its centre — what tap() targets —
        // a few pixels past the bottom of a 360x800 view at 1.3x text.
        await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
        await settle(tester);
        await tester.tap(find.byIcon(Icons.soup_kitchen_outlined));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'cook mode');

        await tester.tap(find.byIcon(Icons.close).first);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'back to recipe');

        // The editor.
        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'editor');

        await tester.tap(find.byType(BackButton).first);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'back to recipe');

        await tester.tap(find.byType(BackButton).first);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'back to library');

        // The meal plan and groceries (the shell's own tabs) — scoped to
        // the NavigationBar itself: the recipe and plan pages carry their
        // own AppBar actions with these same icons ("planAddToPlan",
        // "addToGroceries"), so an unscoped find.byIcon can tap the wrong
        // one once the plan/groceries tabs are mounted underneath.
        Finder navTab(IconData icon) => find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(icon),
        );
        await tester.tap(navTab(Icons.calendar_month_outlined));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'plan');

        await tester.tap(navTab(Icons.shopping_basket_outlined));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'groceries');

        await tester.tap(navTab(Icons.menu_book_outlined));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'back to library');

        // Import.
        await tester.tap(find.byIcon(Icons.link).first);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'import');

        await tester.tap(find.byType(BackButton).first);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'back to library');

        // Settings, with the new "الطراز"/"Look" row (LOOK-1).
        await tester.tap(find.byIcon(Icons.settings_outlined).first);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'settings');
      },
    );
  }

  // should-fix, platform review: the branch's one new control — the "الطراز"
  // / Look row settings_screen.dart adds — had no test tapping it; every
  // existing looks test only sets the look programmatically
  // (`settings.update(...copyWith(style: ...))`) and never touches the row
  // itself.
  testWidgets(
    'Settings: tapping زعفران changes the theme at once, no restart (LOOK-1)',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await settle(tester);
      // The Look row sits below the fold (past language/digits/units/week
      // start): a plain ListView still virtualises its own children by
      // viewport, so it isn't mounted until scrolled into view (the same
      // reason test/widget/ramadan_test.dart's own Settings test scrolls).
      await tester.scrollUntilVisible(
        find.text('زعفران'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);

      BuildContext context() => tester.element(find.text('زعفران'));
      final beforeBrightness = Theme.of(context()).brightness;
      expect(
        Theme.of(context()).colorScheme.primary,
        wasfatiColorScheme(AppStyle.ink, beforeBrightness).primary,
        reason: 'Ink is the default look',
      );

      await tester.tap(find.text('زعفران'));
      await settle(tester);

      // Still the same Settings screen — no navigation, no restart — with
      // its theme now Saffron's, and the light/dark setting untouched.
      expect(find.text('زعفران'), findsOneWidget);
      final afterBrightness = Theme.of(context()).brightness;
      expect(afterBrightness, beforeBrightness);
      expect(
        Theme.of(context()).colorScheme.primary,
        wasfatiColorScheme(AppStyle.saffron, afterBrightness).primary,
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
          of: find.byType(NavigationBar),
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
          of: find.byType(NavigationBar),
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
    await tester.ensureVisible(find.text('ابدأ الطبخ'));
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
    await tester.tap(find.text('شوربة'));
    await settle(tester);
    await tester.tap(find.text('×½'));
    await settle(tester);
    expect(boxed('×½'), findsOneWidget);
  });
}
