// LOOK-7, LOOK-11, Decision 23: the navigation pill (four tabs and the
// centre "+") and the add sheet it opens.
import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/settings.dart' show AppStyle, LanguagePref;
import 'package:wasfati/screens/settings_screen.dart';
import 'package:wasfati/theme/app_theme.dart';
import 'package:wasfati/theme/decor.dart';
import 'package:wasfati/widgets/ad_slot.dart';
import 'package:wasfati/widgets/nav_pill.dart';

import 'app_test.dart' show importPhotos, pumpApp, settle;

Finder navTab(IconData icon) =>
    find.descendant(of: find.byType(NavPill), matching: find.byIcon(icon));

/// The `Column` (icon, label, dot) for one tab, so the dot can be checked
/// as *that* tab's own, not just "a dot exists somewhere in the pill".
Finder tabColumn(IconData icon) =>
    find.ancestor(of: navTab(icon), matching: find.byType(Column)).first;

/// The 4x4 dot painted only under the selected tab (never colour alone,
/// LOOK-3/LOOK-7): a circle in the theme's accent, inside [NavPill].
Finder _dot(BuildContext context) => find.descendant(
  of: find.byType(NavPill),
  matching: find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle &&
        (w.decoration as BoxDecoration).color ==
            Theme.of(context).colorScheme.primary,
  ),
);

void main() {
  // The app's own font, not the test font (whose every glyph is 1em
  // square): the add sheet's clip check below has to measure the same
  // wrapping the bundled IBM Plex font actually produces.
  setUpAll(() async {
    final loader = FontLoader('IBMPlexSansArabic');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final bytes = File('assets/fonts/IBMPlexSansArabic-$weight.ttf')
          .readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  group('NavPill (LOOK-7)', () {
    testWidgets('switches tabs and marks the current one by colour and a '
        'dot, never colour alone', (tester) async {
      await pumpApp(tester, withRecipe: true);

      NavPillTab tabAt(int i) =>
          tester.widget<NavPill>(find.byType(NavPill)).tabs[i];
      int currentIndex() =>
          tester.widget<NavPill>(find.byType(NavPill)).currentIndex;
      final context = tester.element(find.byType(NavPill));
      final decor = Decor.of(context);
      Color? iconColor(IconData icon) =>
          tester.widget<Icon>(navTab(icon)).color;

      expect(currentIndex(), 0); // starts on the library
      expect(find.text('كبسة لحم'), findsOneWidget);
      // Exactly one dot, and it's under the selected (library) tab, not
      // just somewhere in the pill.
      expect(_dot(context), findsOneWidget);
      expect(
        find.descendant(
          of: tabColumn(Icons.menu_book_outlined),
          matching: _dot(context),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tabColumn(Icons.calendar_month_outlined),
          matching: _dot(context),
        ),
        findsNothing,
      );
      expect(iconColor(Icons.menu_book_outlined), decor.navActive);
      expect(iconColor(Icons.calendar_month_outlined), decor.navInactive);

      await tester.tap(navTab(Icons.calendar_month_outlined));
      await settle(tester);
      expect(currentIndex(), 1);
      // The plan's own content is on screen — not just the pill's label
      // (both read "الخطة"): its empty state is Plan-only text.
      expect(find.text('خطط أسبوعك'), findsOneWidget);
      expect(_dot(context), findsOneWidget);
      expect(iconColor(Icons.calendar_month_outlined), decor.navActive);
      expect(iconColor(Icons.menu_book_outlined), decor.navInactive);

      await tester.tap(navTab(Icons.shopping_basket_outlined));
      await settle(tester);
      expect(currentIndex(), 2);
      expect(find.text('قائمة المشتريات فارغة'), findsOneWidget);
      expect(_dot(context), findsOneWidget);
      expect(iconColor(Icons.shopping_basket_outlined), decor.navActive);

      await tester.tap(navTab(Icons.settings_outlined));
      await settle(tester);
      expect(currentIndex(), 3);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(_dot(context), findsOneWidget);
      expect(iconColor(Icons.settings_outlined), decor.navActive);

      await tester.tap(navTab(Icons.menu_book_outlined));
      await settle(tester);
      expect(currentIndex(), 0);
      expect(find.text('كبسة لحم'), findsOneWidget);
      expect(tabAt(0).icon, Icons.menu_book_outlined); // order unchanged
      expect(_dot(context), findsOneWidget);
    });

    testWidgets(
      'the pill always shows, even with an empty library (Settings lives '
      'in it now)',
      (tester) async {
        await pumpApp(tester);
        expect(find.byType(NavPill), findsOneWidget);
        expect(find.text('لا توجد وصفات بعد'), findsOneWidget);
      },
    );

    testWidgets(
      'Settings shows with no back button hosted in the pill, and still '
      'works when pushed from elsewhere (LOOK-7), and system Back returns '
      'to the library rather than exiting the app',
      (tester) async {
        await pumpApp(tester);
        await tester.tap(navTab(Icons.settings_outlined));
        await settle(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.byType(BackButton), findsNothing);

        // Pushed as an ordinary route (as some other entry point could),
        // it behaves like any other pushed screen: a back button that pops.
        // Not awaited: `Navigator.push`'s future only completes once the
        // pushed route is *popped* (later, by the "tap back" below), so
        // awaiting it here would deadlock the test against itself.
        final context = tester.element(find.byType(SettingsScreen));
        unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        );
        await settle(tester);
        expect(find.byType(BackButton), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await settle(tester);
        expect(find.byType(BackButton), findsNothing);

        // System Back, on the Settings tab itself: back to the library
        // (tab 0), never a closed app.
        expect(tester.widget<NavPill>(find.byType(NavPill)).currentIndex, 3);
        await tester.binding.handlePopRoute();
        await settle(tester);
        expect(tester.widget<NavPill>(find.byType(NavPill)).currentIndex, 0);
        expect(find.byType(SettingsScreen), findsNothing);
      },
    );

    testWidgets(
      'the pill stays clear of the bottom system inset (gesture/3-button '
      'navigation), never sitting under it, and the raised "+" is '
      'hit-testable at its own top edge',
      (tester) async {
        const inset = 48.0;
        const screenHeight = 800.0;
        // The real view, not a MediaQuery override: `Scaffold` reads its
        // bottom inset from `MediaQuery.paddingOf`, which itself comes from
        // the binding's own view padding — an override on a wrapper
        // `MediaQuery` above `MaterialApp` never reaches it, so a test that
        // sets one this way would still pass with the fix reverted.
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3;
        tester.view.padding = const FakeViewPadding(bottom: inset * 3);
        addTearDown(tester.view.reset);

        var pressed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: wasfatiTheme(AppStyle.saffron, Brightness.light),
            home: Scaffold(
              bottomNavigationBar: NavPill(
                tabs: const [
                  NavPillTab(icon: Icons.menu_book_outlined, label: 'أ'),
                  NavPillTab(icon: Icons.calendar_month_outlined, label: 'ب'),
                  NavPillTab(icon: Icons.shopping_basket_outlined, label: 'ج'),
                  NavPillTab(icon: Icons.settings_outlined, label: 'د'),
                ],
                currentIndex: 0,
                onTabSelected: (_) {},
                onAddPressed: () => pressed = true,
                addTooltip: 'أضف وصفة',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // `NavPill` itself (the `Padding`) necessarily reaches the screen's
        // physical bottom edge — that's how a `bottomNavigationBar` is
        // positioned, padding included. What has to clear the inset is the
        // pill's own visible box (the `Stack` the raise/fill live in, sized
        // to exactly `_pillHeight + _raise`), not that outer padding box.
        final pillBottom = tester
            .getRect(
              find.descendant(
                of: find.byType(NavPill),
                matching: find.byType(Stack),
              ),
            )
            .bottom;
        expect(pillBottom, lessThanOrEqualTo(screenHeight - inset - 12));

        // The raised "+" is hit-testable right at its own top edge — not
        // painted outside NavPill's own box.
        final addRect = tester.getRect(find.byTooltip('أضف وصفة'));
        await tester.tapAt(Offset(addRect.center.dx, addRect.top + 1));
        await tester.pump();
        expect(pressed, isTrue);
      },
    );
  });

  group('The add sheet (LOOK-11)', () {
    testWidgets(
      'the centre "+" opens it with its four options in this order, each '
      'opening its own flow',
      (tester) async {
        await pumpApp(tester, withRecipe: true);
        await tester.tap(find.byTooltip('أضف وصفة'));
        await settle(tester);

        expect(find.text('أضف وصفة'), findsWidgets); // the sheet's own title
        final tileTexts = [
          'استيراد من رابط',
          'من صورة',
          'الصق نصًا',
          'أضفها بنفسك',
        ];
        for (final t in tileTexts) {
          expect(find.text(t), findsOneWidget, reason: t);
        }
        // In this fixed order (LOOK-2: never reordered).
        final positions = [
          for (final t in tileTexts) tester.getTopLeft(find.text(t)).dy,
        ];
        expect(positions[0], lessThan(positions[2])); // link above paste text
        expect(positions[1], lessThan(positions[3])); // photo above by hand
        // Same fixed order *within* a row too (LOOK-2): in RTL, the first
        // tile of each pair sits to the right of the second, not just above
        // it — this would still pass if link/photo (or paste/by-hand) were
        // swapped within their row.
        expect(
          tester.getCenter(find.text('استيراد من رابط')).dx,
          greaterThan(tester.getCenter(find.text('من صورة')).dx),
        );
        expect(
          tester.getCenter(find.text('الصق نصًا')).dx,
          greaterThan(tester.getCenter(find.text('أضفها بنفسك')).dx),
        );
        // ADS-1/LOOK-11: no upsell, no ad anywhere in the sheet.
        expect(find.text('استيرادات ذكية أكثر مع بريميوم'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(AdSlot),
          ),
          findsNothing,
        );

        // "استيراد من رابط" opens the import screen on its link field
        // (IMP-1/2).
        await tester.tap(find.text('استيراد من رابط'));
        await settle(tester);
        expect(find.text('الصق رابط الوصفة'), findsOneWidget);
        await tester.tap(find.byType(BackButton).first);
        await settle(tester);

        // "من صورة" opens straight to the camera/gallery choice — not the
        // link field — with the choice reachable without touching one.
        await tester.tap(find.byTooltip('أضف وصفة'));
        await settle(tester);
        await tester.tap(find.text('من صورة'));
        await settle(tester);
        expect(find.text('الصق رابط الوصفة'), findsNothing);
        expect(find.text('التقط صورة'), findsOneWidget);
        await tester.tap(find.text('اختر من الصور'));
        await settle(tester);
        expect(importPhotos.calls, contains(startsWith('gallery:')));
        await tester.tap(find.byType(BackButton).first);
        await settle(tester);

        // "الصق نصًا" opens the multi-line paste box (not the link field),
        // and it can actually import — the cost line and a real
        // استيراد/إلغاء choice, never "هذا لا يبدو رابطًا." (IMP-1, IMP-3).
        await tester.tap(find.byTooltip('أضف وصفة'));
        await settle(tester);
        await tester.tap(find.text('الصق نصًا'));
        await settle(tester);
        expect(find.text('الصق رابط الوصفة'), findsNothing);
        await tester.enterText(
          find.widgetWithText(TextField, 'الصق نصًا'),
          'شوربة عدس بالكمون',
        );
        await tester.tap(find.text('استيراد').first);
        await settle(tester);
        expect(find.text('هذا لا يبدو رابطًا.'), findsNothing);
        expect(
          find.textContaining('سيُستخدم استيراد ذكي واحد الآن'),
          findsOneWidget,
        );
        await tester.tap(find.text('إلغاء'));
        await settle(tester);
        await tester.tap(find.byType(BackButton).first);
        await settle(tester);

        // "أضفها بنفسك" opens the editor directly.
        await tester.tap(find.byTooltip('أضف وصفة'));
        await settle(tester);
        await tester.tap(find.text('أضفها بنفسك'));
        await settle(tester);
        expect(find.byType(TextFormField), findsWidgets);
        expect(find.text('حفظ'), findsOneWidget);
      },
    );

    testWidgets(
      'the quota card shows the imports left, in the accent, and the reset '
      'date/free-website caption, from the same state the import screen '
      'already uses (IMP-7)',
      (tester) async {
        final (_, settings) = await pumpApp(tester, withRecipe: true);
        await tester.tap(find.byTooltip('أضف وصفة'));
        await settle(tester);

        expect(find.text('الاستيراد الذكي'), findsOneWidget);
        expect(find.text('10 من 10 متبقية'), findsOneWidget);
        expect(
          find.text(
            'تتجدد في الأول من كل شهر · '
            'استيراد صفحات المواقع يبقى مجانيًا وبلا حدود.',
          ),
          findsOneWidget,
        );
        // ADS-1/LOOK-11: no upsell, no ad in the sheet.
        expect(find.text('استيرادات ذكية أكثر مع بريميوم'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(AdSlot),
          ),
          findsNothing,
        );

        // The add sheet is a bottom sheet, not a pushed screen, so it has
        // no back button to tap (unlike an ImportScreen pushed from one of
        // its tiles, above): dismiss it the way its own tiles would,
        // through the Navigator that showed it.
        Navigator.of(tester.element(find.text('أضف وصفة').first)).pop();
        await settle(tester);
        await tester.runAsync(() async {
          for (var i = 0; i < 3; i++) {
            await settings.recordAiImportSaved();
          }
        });
        await tester.tap(find.byTooltip('أضف وصفة'));
        await settle(tester);
        expect(find.text('7 من 10 متبقية'), findsOneWidget);
      },
    );

    testWidgets(
      'at English 1.3x on a 360dp phone, no tile label/description clips '
      'and the two tiles sharing a row stay the same height (LOOK-8)',
      (tester) async {
        await pumpApp(
          tester,
          language: LanguagePref.en,
          textScale: 1.3,
          withRecipe: true,
        );
        await tester.tap(find.byTooltip('Add a recipe'));
        await settle(tester);

        // Not a single RenderParagraph in the sheet silently clipped —
        // whether it's a tile's label/description or anything else in it.
        final paragraphs = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(RichText),
        );
        for (final element in paragraphs.evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          expect(paragraph.didExceedMaxLines, isFalse);
        }

        Finder tileOf(String label) => find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (w) => w is ConstrainedBox && w.constraints.minHeight == 144,
          ),
        );
        double heightOf(String label) =>
            tester.getSize(tileOf(label).first).height;

        expect(
          heightOf('Import from a link'),
          heightOf('From a photo'),
          reason: 'the first row\'s two tiles must share one height',
        );
        expect(
          heightOf('Paste text'),
          heightOf('Add by hand'),
          reason: 'the second row\'s two tiles must share one height',
        );
      },
    );
  });
}
