// LOOK-8: every main screen renders in both looks, both brightnesses and
// both languages, at 1.3x text on a 360dp phone, without overflow. Four
// runs (Ink/Saffron x light/dark), language alternated across them so both
// still get covered — the failure mode LOOK-8 guards against (a RenderFlex
// overflow) is far more sensitive to text length and scale than to which
// two brightnesses of the same look are on screen, so the full eight-way
// cross product would multiply run time for little extra confidence.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/theme/colors.dart' show wasfatiColorScheme;

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
}
