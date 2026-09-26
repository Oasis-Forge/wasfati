// LOOK-12, ORG-3–ORG-6, COOK-6: the library home's greeting, the segmented
// all-recipes/cookbooks switch, the search row's quick chips and filter
// sheet, the "تابع الطبخ" resume card, photo vs cover cards, the section
// heading's count, and the cookbook grid with the pushed cookbook screen's
// own banner (ADS-9).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/services/ads.dart';
import 'package:wasfati/widgets/content_direction.dart';
import 'package:wasfati/widgets/recipe_cover.dart';
import 'package:wasfati/widgets/sufra_card.dart';

import '../helpers.dart';
import 'app_test.dart' show pumpApp, settle;

const _allowedAds = AdConsent(
  canRequestAds: true,
  privacyOptionsRequired: false,
);

/// A one-pixel, valid PNG (so `Image.file` decodes it instead of erroring),
/// for the photo-card-vs-cover-card test.
final _onePxPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

String _photoFile(String name) {
  final dir = Directory.systemTemp.createTempSync('wasfati_library_home_test');
  final file = File('${dir.path}/$name.png')..writeAsBytesSync(_onePxPng);
  return file.path;
}

/// Scopes a text lookup to an open modal sheet, since the quick-chip row
/// underneath (same labels: بصورة، أقل من 30 دقيقة، مواقع التواصل) stays in
/// the tree while the sheet is open.
Finder _inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

/// Scopes a text lookup to the section heading's title (a [ContentText]),
/// since the segmented pill can carry the same label («كل الوصفات»).
Finder _heading(String text) =>
    find.descendant(of: find.byType(ContentText), matching: find.text(text));

void main() {
  testWidgets(
    'the greeting follows a fixed clock: morning before noon, evening from '
    'it (LOOK-12)',
    (tester) async {
      await pumpApp(
        tester,
        withRecipe: true,
        libraryClock: () => DateTime(2026, 1, 1, 9),
      );
      expect(find.text('صباح الخير'), findsOneWidget);
      expect(find.text('ماذا نطبخ اليوم؟'), findsOneWidget);
      expect(find.text('مساء الخير'), findsNothing);
    },
  );

  testWidgets('the greeting switches to evening from 12:00 (LOOK-12)', (
    tester,
  ) async {
    await pumpApp(
      tester,
      withRecipe: true,
      libraryClock: () => DateTime(2026, 1, 1, 14),
    );
    expect(find.text('مساء الخير'), findsOneWidget);
    expect(find.text('صباح الخير'), findsNothing);
  });

  testWidgets('the segmented control switches between the recipe grid and the '
      'cookbook grid (LOOK-12)', (tester) async {
    final (recipes, _) = await pumpApp(tester, withRecipe: true);
    await tester.runAsync(() => recipes.repository.saveCookbook('كتابي'));
    await tester.runAsync(() => recipes.load());
    await settle(tester);

    expect(find.text('كبسة لحم'), findsOneWidget);
    expect(find.text('كتابي'), findsNothing);

    await tester.tap(find.text('كتب الطبخ'));
    await settle(tester);
    expect(find.text('كتابي'), findsOneWidget);
    expect(find.text('كبسة لحم'), findsNothing);

    await tester.tap(find.text('كل الوصفات'));
    await settle(tester);
    expect(find.text('كبسة لحم'), findsOneWidget);
  });

  testWidgets('the section heading counts the recipes in view (LOOK-12)', (
    tester,
  ) async {
    final (recipes, _) = await pumpApp(tester);
    final repo = recipes.repository;
    await tester.runAsync(() async {
      await recipes.save(kabsa(repo, title: 'الأولى'));
      await recipes.save(kabsa(repo, title: 'الثانية'));
    });
    await settle(tester);
    expect(_heading('كل الوصفات'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets(
    'a photo card shows the photo; a recipe with none shows its RecipeCover '
    '(LOOK-10, LOOK-12)',
    (tester) async {
      final (recipes, _) = await pumpApp(tester);
      final repo = recipes.repository;
      await tester.runAsync(() async {
        await recipes.save(
          kabsa(repo, title: 'بصورة').copyWith(photoPath: _photoFile('card')),
        );
        await recipes.save(kabsa(repo, title: 'بلا صورة'));
      });
      await settle(tester);

      // should-fix: scoped to each card by its own title, not "some Image
      // and some RecipeCover exist somewhere" — which the two cards being
      // side by side made trivially true either way.
      Finder cardOf(String title) =>
          find.ancestor(of: find.text(title), matching: find.byType(SufraCard));

      expect(
        find.descendant(of: cardOf('بصورة'), matching: find.byType(Image)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardOf('بصورة'),
          matching: find.byType(RecipeCover),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: cardOf('بلا صورة'),
          matching: find.byType(RecipeCover),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cardOf('بلا صورة'), matching: find.byType(Image)),
        findsNothing,
      );
    },
  );

  testWidgets('each quick chip filters, and «الكل» clears them (ORG-6)', (
    tester,
  ) async {
    final (recipes, _) = await pumpApp(tester);
    final repo = recipes.repository;
    await tester.runAsync(() async {
      // Over an hour, no photo, a website source, no tag (the default from
      // `kabsa`): matches nothing but "الكل".
      await recipes.save(kabsa(repo, title: 'الأولى'));
      await recipes.save(
        kabsa(repo, title: 'سريعة').copyWith(prepMinutes: 10, cookMinutes: 15),
      );
      await recipes.save(
        // Never "تيك توك" itself: that's the platform's own source-badge
        // label (Decision 8), and a recipe titled the same would make
        // `find.text` match both the card's title and its badge.
        kabsa(repo, title: 'ريلز سريع').copyWith(
          sourceType: SourceType.social,
          sourceUrl: 'https://www.tiktok.com/@a/video/1',
        ),
      );
      await recipes.save(kabsa(repo, title: 'موسومة').copyWith(tags: ['حار']));
    });
    await settle(tester);
    expect(find.text('4'), findsOneWidget); // the section heading's count

    Future<void> tapChip(String label) async {
      final chip = find.widgetWithText(FilterChip, label);
      final row = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      );
      // The row only mounts chips near the viewport (a `ListView`, however
      // short, is still lazy inside its `Sliver`), so reset to its very
      // start first — deterministic regardless of where the previous tap
      // left the scroll position — then search forward.
      await tester.drag(row, const Offset(-3000, 0));
      await tester.pump();
      for (var i = 0; i < 20 && chip.evaluate().isEmpty; i++) {
        await tester.drag(row, const Offset(150, 0));
        await tester.pump();
      }
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await settle(tester);
    }

    await tapChip('أقل من 30 دقيقة');
    expect(find.text('سريعة'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('الأولى'), findsNothing);

    await tapChip('الكل');
    expect(find.text('4'), findsOneWidget);

    await tapChip('مواقع التواصل');
    expect(find.text('ريلز سريع'), findsOneWidget);
    expect(find.text('الأولى'), findsNothing);

    await tapChip('الكل');
    expect(find.text('4'), findsOneWidget);

    await tapChip('حار'); // one of the up-to-four most-used tags
    expect(find.text('موسومة'), findsOneWidget);
    expect(find.text('الأولى'), findsNothing);

    await tapChip('الكل');
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets(
    'choosing a sheet-only filter (a source, with no quick chip of its own) '
    'updates the heading and the filter circle\'s indicator, with semantics '
    '(ORG-6)',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, withRecipe: true);
      expect(_heading('كل الوصفات'), findsOneWidget);
      expect(find.bySemanticsLabel('تصفية نشطة'), findsNothing);

      await tester.tap(find.byTooltip('تصفية'));
      await settle(tester);
      await tester.tap(_inSheet('موقع إلكتروني')); // sourceWebsite
      await settle(tester);
      await tester.tapAt(const Offset(180, 40)); // the sheet's barrier
      await settle(tester);

      expect(_heading('كل الوصفات'), findsNothing);
      expect(
        _heading('نتائج التصفية'),
        findsOneWidget,
      ); // libraryFilteredHeading
      expect(find.bySemanticsLabel('تصفية نشطة'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'the filter sheet applies each ORG-6 filter (cookbook, photo, source, '
    'time) and «مسح عوامل التصفية» clears them',
    (tester) async {
      final (recipes, _) = await pumpApp(tester);
      final repo = recipes.repository;
      late String bookId;
      await tester.runAsync(() async {
        bookId = await repo.saveCookbook('كتاب');
        // Multi-letter titles (never a single letter): RecipeCover draws a
        // photo-less recipe's own first letter as its cover art (LOOK-10),
        // so a single-letter title would make `find.text` match both the
        // title and the cover, ambiguously.
        await recipes.save(
          kabsa(repo, title: 'أول').copyWith(cookbookIds: [bookId]),
        );
        await recipes.save(
          kabsa(repo, title: 'ثاني').copyWith(photoPath: _photoFile('sheet')),
        );
        await recipes.save(
          kabsa(repo, title: 'ثالث').copyWith(
            sourceType: SourceType.social,
            sourceUrl: 'https://www.instagram.com/p/1',
          ),
        );
        await recipes.save(
          kabsa(repo, title: 'رابع').copyWith(prepMinutes: 5, cookMinutes: 10),
        );
      });
      await settle(tester);

      // The sheet applies every filter live and never closes itself
      // (ORG-6: "never waiting for a Done"), so it stays open through
      // every section below — reopening it via the search row's own
      // filter circle would instead just tap whatever the still-open
      // sheet's own (long, scrolling) content happens to sit under.
      await tester.tap(find.byTooltip('تصفية'));
      await settle(tester);

      // Cookbook.
      await tester.tap(_inSheet('كتاب'));
      await settle(tester);
      expect(find.text('أول'), findsOneWidget);
      expect(find.text('ثاني'), findsNothing);
      await tester.ensureVisible(_inSheet('مسح عوامل التصفية'));
      await settle(tester);
      await tester.tap(_inSheet('مسح عوامل التصفية'));
      await settle(tester);
      expect(find.text('ثاني'), findsOneWidget);

      // Has photo.
      await tester.tap(_inSheet('بصورة'));
      await settle(tester);
      expect(find.text('ثاني'), findsOneWidget);
      expect(find.text('أول'), findsNothing);
      await tester.ensureVisible(_inSheet('مسح عوامل التصفية'));
      await settle(tester);
      await tester.tap(_inSheet('مسح عوامل التصفية'));
      await settle(tester);

      // Source (social).
      await tester.tap(_inSheet('مواقع التواصل'));
      await settle(tester);
      expect(find.text('ثالث'), findsOneWidget);
      expect(find.text('أول'), findsNothing);
      await tester.ensureVisible(_inSheet('مسح عوامل التصفية'));
      await settle(tester);
      await tester.tap(_inSheet('مسح عوامل التصفية'));
      await settle(tester);

      // Total time (under 30).
      await tester.tap(_inSheet('أقل من 30 دقيقة'));
      await settle(tester);
      expect(find.text('رابع'), findsOneWidget);
      expect(find.text('أول'), findsNothing);
      await tester.ensureVisible(_inSheet('مسح عوامل التصفية'));
      await settle(tester);
      await tester.tap(_inSheet('مسح عوامل التصفية'));
      await settle(tester);
      expect(find.text('أول'), findsOneWidget); // every filter cleared
    },
  );

  testWidgets(
    'the "تابع الطبخ" card appears right after leaving cook mode, opens '
    'cook mode at its step, and disappears once the recipe is finished '
    '(LOOK-12, COOK-6)',
    (tester) async {
      await pumpApp(tester, withRecipe: true);
      expect(find.text('تابع الطبخ'), findsNothing);

      // Drives the real flow (should-fix): no `RecipesState.load()` bypass
      // — cook mode's own page write goes through the state layer now
      // (`RecipesState.setCookPage`), so leaving it is enough on its own.
      await tester.tap(find.text('كبسة لحم')); // kabsa: 2 steps (helpers.dart)
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('ابدأ الطبخ'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      await tester.tap(find.text('ابدأ الطبخ'));
      await settle(tester);
      await tester.tap(find.text('التالي')); // step 1 -> step 2 of 2
      await settle(tester);

      await tester.binding.handlePopRoute(); // close cook mode
      await settle(tester);
      await tester.binding.handlePopRoute(); // back to the library
      await settle(tester);

      expect(find.text('تابع الطبخ'), findsOneWidget);
      expect(find.text('الخطوة 2 من 2'), findsOneWidget);

      await tester.tap(find.byTooltip('تابع'));
      await settle(tester);
      expect(find.text('الخطوة 2 من 2'), findsWidgets); // now cook mode itself

      // Finishing the recipe (the "done" page, past the last step) drops
      // it: `latestCookProgress` never resurfaces a page beyond the total.
      await tester.tap(find.text('التالي')); // step 2 -> the "done" page
      await settle(tester);
      await tester.tap(find.text('تم'));
      await settle(tester);
      await tester.binding.handlePopRoute(); // back to the library
      await settle(tester);
      expect(find.text('تابع الطبخ'), findsNothing);
    },
  );

  testWidgets(
    'cookbook tiles show a collage and the count; the pushed cookbook '
    'screen keeps its own banner (ADS-9)',
    (tester) async {
      final (recipes, _) = await pumpApp(
        tester,
        withRecipe: true,
        adServiceOverride: NoopAdService(consent: _allowedAds, fills: true),
      );
      final repo = recipes.repository;
      await tester.runAsync(() async {
        final bookId = await repo.saveCookbook('حلويات');
        final r = recipes.recipes.single;
        final full = (await repo.get(r.id))!;
        await recipes.save(full.copyWith(cookbookIds: [bookId]));
      });
      await settle(tester);

      await tester.tap(find.text('كتب الطبخ'));
      await settle(tester);
      expect(find.text('حلويات'), findsOneWidget);
      expect(find.text('وصفة واحدة'), findsOneWidget); // cookbookRecipes(1,…)
      expect(find.byType(RecipeCover), findsWidgets); // the collage cell

      await tester.tap(find.text('حلويات'));
      await settle(tester);
      // should-fix: the fake banner itself, not just an `AdSlot` that could
      // just as well be empty — `fills: true` above means it must show.
      expect(find.byKey(noopBannerKey), findsOneWidget); // ADS-9
    },
  );

  testWidgets(
    'inside an empty cookbook, «الكل» stays selected, «مسح عوامل التصفية» '
    'never shows, and tapping «الكل» stays scoped to the cookbook '
    '(ORG-1, RUN-1)',
    (tester) async {
      final (recipes, _) = await pumpApp(tester);
      final repo = recipes.repository;
      await tester.runAsync(() async {
        await repo.saveCookbook('فارغ');
        await recipes.save(kabsa(repo, title: 'خارج الكتاب'));
      });
      await settle(tester);

      await tester.tap(find.text('كتب الطبخ'));
      await settle(tester);
      await tester.tap(find.text('فارغ'));
      await settle(tester);

      expect(
        find.text('لا وصفات في هذا الكتاب بعد. أضفها من شاشة تعديل الوصفة.'),
        findsOneWidget,
      );
      expect(find.text('مسح عوامل التصفية'), findsNothing);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'الكل'))
            .selected,
        isTrue,
      );

      await tester.tap(find.widgetWithText(FilterChip, 'الكل'));
      await settle(tester);
      expect(find.text('خارج الكتاب'), findsNothing); // never widened
    },
  );

  testWidgets(
    'the source badge and the meta line\'s servings show inside each card, '
    'in both the list and the grid (REC-3, REC-7)',
    (tester) async {
      // kabsa (helpers.dart): a website source at fatafeat.com, 6 servings.
      await pumpApp(tester, withRecipe: true);
      Finder cardOf(String title) =>
          find.ancestor(of: find.text(title), matching: find.byType(SufraCard));

      expect(
        find.descendant(
          of: cardOf('كبسة لحم'),
          matching: find.text('fatafeat.com'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardOf('كبسة لحم'),
          matching: find.textContaining('حصص'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('عرض شبكي'));
      await settle(tester);
      expect(
        find.descendant(
          of: cardOf('كبسة لحم'),
          matching: find.text('fatafeat.com'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardOf('كبسة لحم'),
          matching: find.textContaining('حصص'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a grid-view ingredient match still shows «يحتوي: …» on the card '
      '(ORG-3)', (tester) async {
    await pumpApp(tester, withRecipe: true);
    await tester.tap(find.byTooltip('عرض شبكي'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'طماطم');
    await settle(tester);
    expect(find.textContaining('يحتوي'), findsOneWidget);
  });

  testWidgets('sorting works inside a cookbook too (ORG-5)', (tester) async {
    final (recipes, _) = await pumpApp(tester);
    final repo = recipes.repository;
    await tester.runAsync(() async {
      final bookId = await repo.saveCookbook('كتاب');
      await recipes.save(
        kabsa(repo, title: 'موز').copyWith(cookbookIds: [bookId]),
      );
      await recipes.save(
        kabsa(repo, title: 'أرز').copyWith(cookbookIds: [bookId]),
      );
    });
    await settle(tester);

    await tester.tap(find.text('كتب الطبخ'));
    await settle(tester);
    await tester.tap(find.text('كتاب'));
    await settle(tester);

    await tester.tap(find.byTooltip('الترتيب'));
    await settle(tester);
    await tester.tap(find.text('أ–ي'));
    await settle(tester);

    final order = tester
        .widgetList<ContentText>(find.byType(ContentText))
        .map((w) => w.text)
        .toList();
    expect(order.indexOf('أرز'), lessThan(order.indexOf('موز')));
  });
}
