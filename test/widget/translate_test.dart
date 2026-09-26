// Translate (IMP-14–IMP-16, Decision 9), driven through the screens: the
// button, the cost line, the preview, the saved copy and its links. A fake
// server answers; nothing touches the network.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:wasfati/db/recipe_repository.dart';
import 'package:wasfati/models/durations.dart';
import 'package:wasfati/models/quantity/convert.dart' show UnitView;
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/recipe_import.dart' show ImportedRecipe;
import 'package:wasfati/models/recipe_translation.dart' show TranslationItem;
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/services/ai_import.dart';

import 'app_test.dart'
    show
        importPhotos,
        openStepsTab,
        photoStore,
        pumpApp,
        settle,
        shown,
        tapOnPage;

const _dict = {
  'Lamb kabsa': 'كبسة لحم',
  'lamb': 'لحم ضأن',
  'basmati rice': 'أرز بسمتي',
  'salt to taste': 'ملح حسب الذوق',
  'Brown the lamb in butter.': 'يحمر اللحم في الزبدة.',
  'Add the rice and cook for 20 minutes.': 'يضاف الأرز ويطبخ 20 دقيقة.',
};

/// A fake server (SRV-11): every text into the target language from
/// [dict], with [lie]'s answers changing numbers (IMP-15).
AiTranslateResult Function(AiTranslateRequest) _server(
  Map<String, String> dict, {
  Map<String, String> lie = const {},
}) =>
    (r) => AiTranslateSuccess(
      [
        for (final i in r.items)
          (id: i.id, text: lie[i.text] ?? dict[i.text] ?? 'ترجمة ${i.id}'),
      ],
      model: 'haiku',
      promptVersion: 't1',
    );

Recipe _english(RecipeRepository repo) {
  final now = repo.now();
  return Recipe(
    id: repo.newId(),
    title: 'Lamb kabsa',
    photoPath: '/photos/lamb.jpg',
    sourceUrl: 'https://example.com/lamb',
    sourceType: SourceType.website,
    servings: 6,
    ingredients: [
      Section(
        id: repo.newId(),
        items: [
          IngredientLine.parse(repo.newId(), '1 kg lamb'),
          IngredientLine.parse(repo.newId(), '3 cups basmati rice'),
          IngredientLine.parse(repo.newId(), 'salt to taste'),
        ],
      ),
    ],
    steps: [
      Section(
        id: repo.newId(),
        items: [
          RecipeStep(id: repo.newId(), text: 'Brown the lamb in butter.'),
          RecipeStep(
            id: repo.newId(),
            text: 'Add the rice and cook for 20 minutes.',
          ),
        ],
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

const _englishImport = AiImportSuccess(
  ImportedRecipe(
    title: 'Lamb kabsa',
    ingredients: [
      (null, ['1 kg lamb', '3 cups basmati rice']),
    ],
    steps: [
      (null, ['Brown the lamb in butter.']),
    ],
  ),
  model: 'haiku',
  promptVersion: '1',
  cached: false,
);

List<(Rational?, Rational?, String?)> _amounts(Recipe r) => [
  for (final s in r.ingredients)
    for (final l in s.items) (l.min, l.max, l.unitId),
];

List<List<Duration>> _timers(Recipe r) => [
  for (final s in r.steps)
    for (final step in s.items) findDurations(step.text),
];

/// Settles until [finder] finds something. A recipe page's translation
/// links (IMP-14) come from a database lookup of their own, which shows no
/// spinner and can outlast [settle] on a busy machine.
Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester);
  }
}

/// A server whose translate answer waits for [answer], so a test can see
/// the progress dialog and cancel it (IMP-4).
class _HeldServer extends NoopAiImportClient {
  final _held = Completer<AiTranslateResult>();
  void answer(AiTranslateResult r) => _held.complete(r);

  @override
  Future<AiTranslateResult> translate({
    required String installId,
    required String target,
    required List<TranslationItem> items,
  }) {
    translateRequests.add((installId: installId, target: target, items: items));
    return _held.future;
  }
}

void main() {
  testWidgets('IMP-14–IMP-16: a saved English recipe — the cost line, the '
      'preview, and Save makes a linked Arabic copy with the same amounts, '
      'units and timers; the original never changes', (tester) async {
    final ai = NoopAiImportClient()
      ..translator = _server(
        _dict,
        lie: {'Add the rice and cook for 20 minutes.': 'يطبخ 25 دقيقة.'},
      );
    final (recipes, settings) = await pumpApp(tester, aiClient: ai);
    final original = (await tester.runAsync(
      () => recipes.save(_english(recipes.repository)),
    ))!;
    await settle(tester);
    await tester.tap(find.text('Lamb kabsa'));
    await settle(tester);

    await tapOnPage(tester, find.text('ترجم إلى العربية'));
    // IMP-16: IMP-3's line before anything is sent.
    expect(
      find.text('سيُستخدم استيراد ذكي واحد الآن · بقي 10 من 10'),
      findsOneWidget,
    );
    expect(ai.translateRequests, isEmpty);
    await tester.tap(find.text('ترجم'));
    await settle(tester);

    // The preview (IMP-5): nothing saved, nothing counted yet.
    expect(find.text('راجع واحفظ'), findsOneWidget);
    expect(find.text('كبسة لحم'), findsOneWidget);
    expect(ai.translateRequests.single.target, 'ar');
    expect(recipes.recipes, hasLength(1));
    expect(settings.aiImportsUsed, 0);
    expect(find.text('ترجم إلى العربية'), findsNothing); // no second one
    // IMP-15: the step whose number changed kept its own text.
    expect(
      find.text('بقيت بعض الأسطر بنصّها الأصلي كي لا تتغيّر أرقامها.'),
      findsOneWidget,
    );

    await tester.tap(find.text('حفظ'));
    await settle(tester);
    expect(settings.aiImportsUsed, 1); // IMP-16: one, when saved
    expect(recipes.recipes, hasLength(2));
    // The copy's page, linked to the original.
    await _waitFor(tester, shown('مترجمة من: Lamb kabsa'));
    expect(shown('مترجمة من: Lamb kabsa'), findsOneWidget);
    expect(shown('لحم ضأن'), findsWidgets);
    // LOOK-13: the steps are in their own tab; the step's duration is its
    // timer pill, once, inside the step, and the sentence ends after it.
    await openStepsTab(tester);
    final step = shown('Add the rice and cook for');
    expect(step, findsOneWidget);
    expect(
      find.descendant(of: step, matching: find.text('20 minutes')),
      findsOneWidget,
    );
    expect(tester.widget<Text>(step).textSpan!.toPlainText(), endsWith('.'));

    final copyId = recipes.recipes.firstWhere((e) => e.id != original.id).id;
    final copy = (await tester.runAsync(() => recipes.repository.get(copyId)))!;
    expect(copy.title, 'كبسة لحم');
    expect(_amounts(copy), _amounts(original));
    expect(_timers(copy), _timers(original));
    expect(copy.translatedFrom, original.id);
    expect(copy.sourceUrl, original.sourceUrl);
    expect(copy.servings, 6);
    expect(copy.cookedCount, 0);
    expect(copy.photoPath, '/photos/lamb.jpg.copy-$copyId'); // its own file

    // Back on the original: unchanged, and linked to its translation.
    await tester.binding.handlePopRoute(); // system Back
    await settle(tester);
    expect(find.text('Lamb kabsa'), findsOneWidget);
    await _waitFor(tester, shown('الترجمة: كبسة لحم'));
    expect(shown('الترجمة: كبسة لحم'), findsOneWidget);
    final again = (await tester.runAsync(
      () => recipes.repository.get(original.id),
    ))!;
    expect(again.title, 'Lamb kabsa');
    expect(again.photoPath, '/photos/lamb.jpg');
    expect(again.ingredients.single.items.map((l) => l.original), [
      '1 kg lamb',
      '3 cups basmati rice',
      'salt to taste',
    ]);

    // Each link opens the other recipe.
    await tester.tap(shown('الترجمة: كبسة لحم'));
    await settle(tester);
    await _waitFor(tester, shown('مترجمة من: Lamb kabsa'));
    expect(shown('مترجمة من: Lamb kabsa'), findsOneWidget);
  });

  testWidgets('IMP-15, REC-4: a server that slips a second line or a group '
      'name into its words changes no line on Save — the copy has the same '
      'three lines and amounts, and nothing the model made up', (tester) async {
    final ai = NoopAiImportClient()
      ..translator = _server(
        _dict,
        lie: {
          // A new line with an amount in words (QTY-1), hidden in a name.
          'lamb': 'لحم ضأن\nنصف كوب سكر',
          // "3 أكواب أرز بسمتي:" would be a group name, its amount dropped.
          'basmati rice': 'أرز بسمتي:',
          // A dual form (QTY-8): "two spoons of salt" for "to taste".
          'salt to taste': 'ملعقتان ملح',
        },
      );
    final (recipes, _) = await pumpApp(tester, aiClient: ai);
    final original = (await tester.runAsync(
      () => recipes.save(_english(recipes.repository)),
    ))!;
    await settle(tester);
    await tester.tap(find.text('Lamb kabsa'));
    await settle(tester);
    await tapOnPage(tester, find.text('ترجم إلى العربية'));
    await tester.tap(find.text('ترجم'));
    await settle(tester);
    expect(find.text('راجع واحفظ'), findsOneWidget);
    expect(
      find.text('بقيت بعض الأسطر بنصّها الأصلي كي لا تتغيّر أرقامها.'),
      findsOneWidget,
    );

    await tester.tap(find.text('حفظ'));
    await settle(tester);
    expect(recipes.recipes, hasLength(2));
    expect(shown('سكر'), findsNothing);
    expect(shown('ملعقتان ملح'), findsNothing);
    final copyId = recipes.recipes.firstWhere((e) => e.id != original.id).id;
    final copy = (await tester.runAsync(() => recipes.repository.get(copyId)))!;
    expect(copy.title, 'كبسة لحم');
    expect(copy.ingredients, hasLength(1));
    expect(copy.ingredients.single.name, isNull);
    expect(copy.ingredients.single.items.map((l) => l.original), [
      '1 kg lamb',
      '3 cups basmati rice',
      'salt to taste',
    ]);
    expect(_amounts(copy), _amounts(original));
    expect(_timers(copy), _timers(original));
  });

  testWidgets('an incomplete translation changes nothing and offers "Try '
      'again", costing nothing (IMP-15, SRV-7)', (tester) async {
    var calls = 0;
    final good = _server(_dict);
    final ai = NoopAiImportClient()
      ..translator = (r) {
        calls++;
        if (calls == 1) {
          return AiTranslateSuccess(
            r.items.sublist(1), // one ID missing
            model: 'm',
            promptVersion: 'p',
          );
        }
        return good(r);
      };
    final (recipes, settings) = await pumpApp(tester, aiClient: ai);
    await tester.runAsync(() => recipes.save(_english(recipes.repository)));
    await settle(tester);
    await tester.tap(find.text('Lamb kabsa'));
    await settle(tester);
    await tapOnPage(tester, find.text('ترجم إلى العربية'));
    await tester.tap(find.text('ترجم'));
    await settle(tester);

    expect(
      find.text('عادت الترجمة ناقصة، ولم يُحتسب أي استيراد. حاول مرة أخرى.'),
      findsOneWidget,
    );
    expect(find.text('راجع واحفظ'), findsNothing);
    expect(photoStore.copies, isEmpty); // nothing made for a bad answer
    await tester.tap(find.text('حاول مرة أخرى'));
    await settle(tester);
    expect(find.text('راجع واحفظ'), findsOneWidget);
    expect(ai.translateRequests, hasLength(2));
    expect(settings.aiImportsUsed, 0);

    // Leaving the preview discards the copy and its photo file (REC-8).
    await tester.binding.handlePopRoute(); // system Back
    await settle(tester);
    await tester.tap(find.text('تجاهل'));
    await settle(tester);
    expect(photoStore.deleted, [photoStore.copies.single]);
    expect(recipes.recipes, hasLength(1));
    expect(settings.aiImportsUsed, 0);
  });

  testWidgets('SRV-11: a recipe too long to translate says so and sends '
      'nothing', (tester) async {
    final ai = NoopAiImportClient()..translator = _server(_dict);
    final (recipes, _) = await pumpApp(tester, aiClient: ai);
    await tester.runAsync(() {
      final repo = recipes.repository;
      final r = _english(repo);
      return recipes.save(
        r.copyWith(
          steps: [
            Section(
              id: repo.newId(),
              items: [
                for (var i = 0; i < 300; i++)
                  RecipeStep(id: repo.newId(), text: 'Stir well.'),
              ],
            ),
          ],
        ),
      );
    });
    await settle(tester);
    await tester.tap(find.text('Lamb kabsa'));
    await settle(tester);
    await tapOnPage(tester, find.text('ترجم إلى العربية'));
    expect(
      find.text('هذه الوصفة أطول من أن تُترجم دفعة واحدة.'),
      findsOneWidget,
    );
    expect(find.textContaining('سيُستخدم استيراد ذكي'), findsNothing);
    await tester.tap(find.text('حسنًا'));
    await settle(tester);
    expect(ai.translateRequests, isEmpty);
  });

  testWidgets('IMP-16: translating inside an AI import\'s own preview costs '
      'nothing more — one import in all, and only the translation is '
      'saved, its draft photo gone', (tester) async {
    final ai = NoopAiImportClient()
      ..nextResult = _englishImport
      ..translator = _server(_dict);
    final (recipes, settings) = await pumpApp(
      tester,
      aiClient: ai,
      savePhoto: (id, _) async => '/photos/$id.jpg',
    );
    importPhotos.next = [img.encodePng(img.Image(width: 800, height: 600))];
    await tester.tap(find.byTooltip('أضف وصفة'));
    await settle(tester);
    await tester.tap(find.text('استيراد من رابط'));
    await settle(tester);
    await tester.tap(find.text('اختر من الصور'));
    await settle(tester);
    await tester.tap(find.text('استيراد'));
    await settle(tester);
    await _waitFor(tester, find.text('راجع واحفظ'));
    expect(find.text('Lamb kabsa'), findsOneWidget);
    expect(photoStore.copies, isEmpty);

    await tapOnPage(tester, find.text('ترجم إلى العربية'));
    // Part of this import: no second cost line.
    expect(find.textContaining('سيُستخدم استيراد ذكي'), findsNothing);
    expect(find.text('كبسة لحم'), findsOneWidget);
    expect(photoStore.copies, hasLength(1));

    await tester.tap(find.text('حفظ'));
    await settle(tester);
    expect(settings.aiImportsUsed, 1);
    final saved = recipes.recipes.single;
    expect(saved.title, 'كبسة لحم');
    expect(saved.photoPath, photoStore.copies.single);
    expect(shown('كبسة لحم'), findsWidgets); // its page is open
    // The import's own draft was discarded, and its photo with it.
    expect(photoStore.deleted, hasLength(1));
    expect(photoStore.deleted.single, isNot(saved.photoPath));
    final full = (await tester.runAsync(
      () => recipes.repository.get(saved.id),
    ))!;
    expect(full.translatedFrom, isNull); // nothing saved to link to
  });

  testWidgets('IMP-16: translating a website import costs one, with the '
      'cost line first; closing the translation returns to the import', (
    tester,
  ) async {
    const page = '''<html><head><script type="application/ld+json">
{"@type":"Recipe","name":"Lamb kabsa","recipeIngredient":["1 kg lamb",
 "3 cups basmati rice"],"recipeInstructions":["Brown the lamb in butter."]}
</script></head></html>''';
    final ai = NoopAiImportClient()..translator = _server(_dict);
    final (recipes, settings) = await pumpApp(
      tester,
      aiClient: ai,
      pages: {'https://site.com/lamb': page},
    );
    await tester.tap(find.byTooltip('أضف وصفة'));
    await settle(tester);
    await tester.tap(find.text('استيراد من رابط'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'https://site.com/lamb');
    await tester.tap(find.text('استيراد'));
    await settle(tester);
    expect(find.text('راجع واحفظ'), findsOneWidget);

    await tapOnPage(tester, find.text('ترجم إلى العربية'));
    expect(
      find.text('سيُستخدم استيراد ذكي واحد الآن · بقي 10 من 10'),
      findsOneWidget,
    );
    await tester.tap(find.text('ترجم'));
    await settle(tester);
    expect(find.text('كبسة لحم'), findsOneWidget);

    await tester.binding.handlePopRoute(); // system Back
    await settle(tester);
    await tester.tap(find.text('تجاهل'));
    await settle(tester);
    // Back on the website import's own preview, still unsaved.
    expect(find.text('Lamb kabsa'), findsOneWidget);
    expect(find.text('ترجم إلى العربية'), findsOneWidget);
    expect(recipes.recipes, isEmpty);
    expect(settings.aiImportsUsed, 0);

    await tapOnPage(tester, find.text('ترجم إلى العربية'));
    await tester.tap(find.text('ترجم'));
    await settle(tester);
    await tester.tap(find.text('حفظ'));
    await settle(tester);
    expect(recipes.recipes.single.title, 'كبسة لحم');
    expect(settings.aiImportsUsed, 1);
  });

  testWidgets('an English app offers "Translate to English" on an Arabic '
      'recipe, and an Arabic app offers nothing on it', (tester) async {
    final ai = NoopAiImportClient()
      ..translator = _server({
        'كبسة لحم': 'Lamb kabsa',
        'لحم ضأن': 'lamb',
        'ارز بسمتي': 'basmati rice',
        'ملح حسب الذوق': 'salt to taste',
        'طماطم': 'tomatoes',
        'للدقوس': 'For the daqous',
        'يحمر اللحم في الزبدة.': 'Brown the lamb in butter.',
        'يضاف الأرز ويترك 15 دقيقة.': 'Add the rice and leave for 15 minutes.',
      });
    await pumpApp(
      tester,
      aiClient: ai,
      withRecipe: true,
      language: LanguagePref.en,
    );
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    await tester.tap(find.text('Translate to English'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Translate'));
    await settle(tester);
    expect(ai.translateRequests.single.target, 'en');
    expect(find.text('Lamb kabsa'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await settle(tester);
    await _waitFor(tester, shown('Translated from: كبسة لحم'));
    expect(shown('Translated from: كبسة لحم'), findsOneWidget);
    expect(shown('1 kg lamb'), findsOneWidget); // English unit, same amount
  });

  testWidgets('IMP-7, SRV-7: out of AI imports says so and sends nothing; '
      "the server's own limit shows its message, with no 'Try again'", (
    tester,
  ) async {
    final ai = NoopAiImportClient()
      ..nextTranslateResult = const AiTranslateError(
        AiImportErrorKind.limitReached,
      );
    final (recipes, settings) = await pumpApp(tester, aiClient: ai);
    await tester.runAsync(() => recipes.save(_english(recipes.repository)));
    await settle(tester);
    await tester.tap(find.text('Lamb kabsa'));
    await settle(tester);

    // The server says the month's imports are gone (SRV-4).
    await tapOnPage(tester, find.text('ترجم إلى العربية'));
    await tester.tap(find.text('ترجم'));
    await settle(tester);
    expect(
      find.text(
        'نفدت الاستيرادات الذكية هذا الشهر. استيراد صفحات المواقع يبقى مجانيًا.',
      ),
      findsOneWidget,
    );
    expect(find.text('حاول مرة أخرى'), findsNothing);
    await tester.tap(find.text('حسنًا'));
    await settle(tester);
    expect(settings.aiImportsUsed, 0);

    // The device's own count is at 0 left: nothing is even asked.
    await tester.runAsync(() async {
      for (var i = 0; i < 10; i++) {
        await settings.recordAiImportSaved();
      }
    });
    await settle(tester);
    await tapOnPage(tester, find.text('ترجم إلى العربية'));
    expect(find.textContaining('نفدت الاستيرادات الذكية هذا الشهر'), findsOne);
    expect(find.textContaining('سيُستخدم استيراد ذكي'), findsNothing);
    expect(ai.translateRequests, hasLength(1));
  });

  testWidgets('LANG-6: at 1.3x text on a phone, the button, the preview and '
      'both links fit', (tester) async {
    final ai = NoopAiImportClient()..translator = _server(_dict);
    final (recipes, _) = await pumpApp(tester, aiClient: ai, textScale: 1.3);
    await tester.runAsync(
      () => recipes.save(
        _english(recipes.repository).copyWith(
          title: 'Slow-cooked lamb kabsa with smoked basmati rice and nuts',
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.textContaining('Slow-cooked'));
    await settle(tester);
    await tapOnPage(tester, find.text('ترجم إلى العربية'));
    await tester.tap(find.text('ترجم'));
    await settle(tester);
    expect(find.text('راجع واحفظ'), findsOneWidget);
    await tester.tap(find.text('حفظ'));
    await settle(tester);
    await _waitFor(tester, shown('مترجمة من: Slow-cooked lamb kabsa'));
    expect(shown('مترجمة من: Slow-cooked lamb kabsa'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    await _waitFor(tester, shown('الترجمة: ترجمة t'));
    expect(shown('الترجمة: ترجمة t'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SCALE-5: editing a recipe keeps its remembered unit view, and '
      'a translated copy keeps its link (IMP-14)', (tester) async {
    final (recipes, _) = await pumpApp(tester);
    final (original, copy) = (await tester.runAsync(() async {
      final repo = recipes.repository;
      final original = (await recipes.save(_english(repo)))!;
      final copy = (await recipes.save(
        _english(repo).copyWith(
          title: 'نسخة',
          translatedFrom: original.id,
          unitView: UnitView.metric,
        ),
      ))!;
      return (original, copy);
    }))!;
    await settle(tester);
    await tester.tap(find.text('نسخة'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).first, 'نسخة معدلة');
    await tester.tap(find.text('حفظ'));
    await settle(tester);
    final back = (await tester.runAsync(
      () => recipes.repository.get(copy.id),
    ))!;
    expect(back.title, 'نسخة معدلة');
    expect(back.unitView, UnitView.metric);
    expect(back.translatedFrom, original.id);
    await _waitFor(tester, shown('مترجمة من: Lamb kabsa'));
    expect(shown('مترجمة من: Lamb kabsa'), findsOneWidget);
  });

  testWidgets('IMP-4: Cancel while it translates drops the answer — no '
      'preview, no photo file left, nothing counted', (tester) async {
    final ai = _HeldServer();
    final (recipes, settings) = await pumpApp(tester, aiClient: ai);
    await tester.runAsync(() => recipes.save(_english(recipes.repository)));
    await settle(tester);
    await tester.tap(find.text('Lamb kabsa'));
    await settle(tester);
    await tapOnPage(tester, find.text('ترجم إلى العربية'));
    await tester.tap(find.text('ترجم'));
    await settle(tester);
    expect(find.text('جارٍ الترجمة…'), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await settle(tester);
    expect(find.text('جارٍ الترجمة…'), findsNothing);
    final sent = ai.translateRequests.single.items;
    ai.answer(_server(_dict)((installId: 'i', target: 'ar', items: sent)));
    await settle(tester);
    expect(find.text('راجع واحفظ'), findsNothing);
    expect(find.text('Lamb kabsa'), findsOneWidget); // still the original
    expect(photoStore.deleted, photoStore.copies);
    expect(photoStore.copies, hasLength(1));
    expect(recipes.recipes, hasLength(1));
    expect(settings.aiImportsUsed, 0);
  });

  testWidgets('an Arabic recipe in an Arabic app has no translate button', (
    tester,
  ) async {
    await pumpApp(tester, withRecipe: true);
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    expect(find.text('ترجم إلى العربية'), findsNothing);
    expect(find.byIcon(Icons.translate), findsNothing);
  });
}
