import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/app.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/library.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/providers/recipes_state.dart';
import 'package:wasfati/providers/settings_state.dart';

import '../helpers.dart';

/// Lets database work (ffi, real async) finish, then settles the UI.
Future<void> settle(WidgetTester tester) async {
  // Pumps frames instead of pumpAndSettle (a loading spinner never
  // settles), until nothing is loading and no route is moving.
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (i > 3 &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        !tester.binding.hasScheduledFrame) {
      break;
    }
  }
  await tester.pump(const Duration(seconds: 1)); // route transitions
}

Future<(RecipesState, SettingsState)> pumpApp(
  WidgetTester tester, {
  LanguagePref language = LanguagePref.ar,
  DigitStyle digits = DigitStyle.western,
  double textScale = 1,
  bool withRecipe = false,
}) async {
  late RecipesState recipes;
  late SettingsState settings;
  await tester.runAsync(() async {
    final (repo, _, _) = await testRepo();
    settings = SettingsState(repo.db);
    await settings.update(AppSettings(language: language, digits: digits));
    recipes = RecipesState(repo);
    if (withRecipe) await recipes.save(kabsa(repo));
    await recipes.load();
  });
  tester.view.physicalSize = const Size(1080, 2400); // a phone (LANG-6)
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: WasfatiApp(recipes: recipes, settings: settings),
    ),
  );
  await tester.pumpAndSettle();
  return (recipes, settings);
}

final _isolates = RegExp(
  '[${String.fromCharCode(0x2066)}-${String.fromCharCode(0x2069)}]',
);

/// Text as the user reads it: without the invisible left-to-right isolates
/// that wrap amounts inside Arabic lines (QTY-5).
Finder shown(String text) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').replaceAll(_isolates, '').contains(text),
);

TextDirection dirOf(WidgetTester tester, Finder f) =>
    Directionality.of(tester.element(f.first));

void main() {
  testWidgets('Arabic: right to left, empty state (LANG-5, RUN-1)', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('وصفاتي'), findsOneWidget);
    expect(find.text('لا توجد وصفات بعد'), findsOneWidget);
    expect(dirOf(tester, find.text('وصفاتي')), TextDirection.rtl);
  });

  testWidgets('English: left to right', (tester) async {
    await pumpApp(tester, language: LanguagePref.en);
    expect(find.text('No recipes yet'), findsOneWidget);
    expect(dirOf(tester, find.text('Wasfati')), TextDirection.ltr);
  });

  testWidgets('add a recipe: groups, parsed lines, numbered steps', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('أضف وصفة'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'كبسة دجاج');
    await tester.enterText(fields.at(1), '4');
    await tester.enterText(
      fields.at(4),
      '١ ك دجاج\nكوبين ارز\n\nللدقوس:\n2 حبة طماطم',
    );
    await tester.enterText(fields.at(5), '1. يحمر الدجاج\n2. يضاف الأرز');
    await tester.tap(find.text('حفظ'));
    await settle(tester);

    // The recipe page.
    expect(find.text('كبسة دجاج'), findsOneWidget);
    expect(find.text('4 حصص'), findsOneWidget); // REC-7, Arabic plural
    expect(find.text('للدقوس'), findsOneWidget); // REC-4 group heading
    expect(shown('1 كيلو دجاج'), findsOneWidget); // "١ ك" → 1 kg
    expect(shown('2 كوبان ارز'), findsOneWidget); // dual → 2 cups
    expect(find.text('يحمر الدجاج'), findsOneWidget); // numbering removed
    expect(find.text('2'), findsWidgets); // step 2's number

    await tester.binding.handlePopRoute(); // system Back
    await tester.pumpAndSettle();
    expect(find.text('كبسة دجاج'), findsOneWidget); // in the list
  });

  testWidgets('each line reads in its own direction (LANG-5, QTY-5)', (
    tester,
  ) async {
    final (recipes, _) = await pumpApp(tester);
    await tester.runAsync(() async {
      final repo = recipes.repository;
      final now = repo.now();
      await recipes.save(
        Recipe(
          id: repo.newId(),
          title: 'Mixed',
          ingredients: [
            Section(
              id: repo.newId(),
              items: [
                IngredientLine.parse(repo.newId(), '1 kg chicken'),
                IngredientLine.parse(repo.newId(), '٣ كوب رز'),
              ],
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mixed'));
    await settle(tester);

    Text line(String part) => tester.widget<Text>(shown(part).last);
    // The competitor bug seen on the emulator: "kg chicken 1". An English
    // line in the Arabic app reads left to right, amount first.
    expect(line('kg chicken').textDirection, TextDirection.ltr);
    expect(line('3 أكواب رز').textDirection, TextDirection.rtl); // QTY-6
    // Both line up with the app's reading edge (right, in Arabic).
    expect(line('kg chicken').textAlign, TextAlign.right);
  });

  testWidgets('search finds a recipe by ingredient and says so (ORG-3)', (
    tester,
  ) async {
    await pumpApp(tester, withRecipe: true);
    await tester.enterText(find.byType(SearchBar), 'طماطم');
    await tester.pumpAndSettle();
    expect(find.text('كبسة لحم'), findsOneWidget);
    expect(find.textContaining('يحتوي: طماطم'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'بيتزا');
    await tester.pumpAndSettle();
    expect(find.text('لا توجد وصفات مطابقة'), findsOneWidget);
    await tester.tap(find.text('مسح عوامل التصفية'));
    await tester.pumpAndSettle();
    expect(find.text('كبسة لحم'), findsOneWidget);
  });

  testWidgets('create a cookbook and put a recipe in it (ORG-1)', (
    tester,
  ) async {
    await pumpApp(tester, withRecipe: true);
    await tester.tap(find.text('كتب الطبخ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('كتاب طبخ جديد'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'رمضان');
    await tester.tap(find.text('إنشاء'));
    await settle(tester);
    expect(find.text('رمضان'), findsOneWidget);
    expect(find.text('لا وصفات'), findsOneWidget);

    // Put the recipe in it from the editor.
    await tester.tap(find.text('كل الوصفات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    await tester.tap(find.byTooltip('تعديل'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      scrollable: find.byType(Scrollable).first, // the form, not a text box
      find.widgetWithText(FilterChip, 'رمضان'),
      200,
    );
    await tester.tap(find.widgetWithText(FilterChip, 'رمضان'));
    await tester.pump();
    await tester.tap(find.text('حفظ'));
    await settle(tester);
    expect(find.widgetWithText(Chip, 'رمضان'), findsOneWidget); // on the page

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('كتب الطبخ'));
    await tester.pumpAndSettle();
    expect(find.text('وصفة واحدة'), findsOneWidget);
  });

  testWidgets('sort and grid view are remembered (ORG-5)', (tester) async {
    final (_, settings) = await pumpApp(tester, withRecipe: true);
    await tester.tap(find.text('الأحدث إضافة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أ–ي'));
    await settle(tester);
    expect(settings.settings.sort, LibrarySort.az);

    await tester.tap(find.byTooltip('عرض شبكي'));
    await settle(tester);
    expect(settings.settings.grid, isTrue);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('the title is required (REC-3)', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('أضف وصفة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('اكتب اسم الوصفة'), findsOneWidget);
  });

  testWidgets('leaving with changes asks first', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('أضف وصفة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'شوربة');
    await tester.pump(); // the frame that arms the unsaved-changes guard
    await tester.binding.handlePopRoute(); // system Back
    await tester.pumpAndSettle();
    expect(find.text('تجاهل التعديلات؟'), findsOneWidget);
    await tester.tap(find.text('تجاهل'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد وصفات بعد'), findsOneWidget);
  });

  testWidgets('Arabic digits setting shows ١٢٣ (QTY-5, Decision 5)', (
    tester,
  ) async {
    await pumpApp(tester, digits: DigitStyle.arabic, withRecipe: true);
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    expect(find.text('٦ حصص'), findsOneWidget);
    expect(shown('١ كيلو لحم ضأن'), findsOneWidget);
  });

  testWidgets('delete, then Undo brings it back (DEL-1, DEL-2)', (
    tester,
  ) async {
    await pumpApp(tester, withRecipe: true);
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    await tester.tap(find.byTooltip('حذف'));
    await settle(tester);
    expect(find.text('حُذفت الوصفة'), findsOneWidget);
    expect(find.text('كبسة لحم'), findsNothing);

    await tester.tap(find.text('تراجع'));
    await settle(tester);
    expect(find.text('كبسة لحم'), findsOneWidget);
  });

  testWidgets('a language change applies at once (LANG-1)', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('الإعدادات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await settle(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(dirOf(tester, find.text('Settings')), TextDirection.ltr);
  });

  for (final lang in [LanguagePref.ar, LanguagePref.en]) {
    testWidgets('${lang.name} at 1.3× text size: no overflow (LANG-6)', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, textScale: 1.3, withRecipe: true);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('كبسة لحم'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
