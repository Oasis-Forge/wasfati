// Importer.translate (IMP-14–IMP-16, SRV-11): what leaves the device, the
// checks on what comes back, and the saved copy. Never touches the network:
// a fake server answers.
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/db/recipe_repository.dart';
import 'package:wasfati/models/durations.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/recipe_translation.dart';
import 'package:wasfati/services/ai_import.dart';
import 'package:wasfati/services/importer.dart';
import 'package:wasfati/services/photo_store.dart';

import '../helpers.dart';
import 'importer_test.dart' show FakeFetcher;

/// Records every photo copy; each copy is a new path.
class _CopyingPhotos extends NoopPhotoStore {
  final copies = <(String, String)>[];
  @override
  Future<String?> copy(String path, String recipeId) async {
    copies.add((path, recipeId));
    return '$path.copy-$recipeId';
  }
}

/// A fake server that puts every text into Arabic from [dict], and — the
/// test IMP-15 names — changes numbers wherever [lie] has an answer.
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
    photoPath: '/photos/kabsa.jpg',
    sourceUrl: 'https://example.com/kabsa',
    sourceType: SourceType.website,
    servings: 6,
    prepMinutes: 30,
    cookMinutes: 90,
    ingredients: [
      Section(
        id: repo.newId(),
        items: [
          IngredientLine.parse(repo.newId(), '1 kg lamb'),
          IngredientLine.parse(repo.newId(), '3 cups basmati rice'),
          IngredientLine.parse(repo.newId(), '2-3 tomatoes'),
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
          RecipeStep(id: repo.newId(), text: 'Rest for 10 minutes.'),
        ],
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

const _dict = {
  'Lamb kabsa': 'كبسة لحم',
  'lamb': 'لحم ضأن',
  'basmati rice': 'أرز بسمتي',
  'tomatoes': 'طماطم',
  'salt to taste': 'ملح حسب الذوق',
  'Brown the lamb in butter.': 'يحمر اللحم في الزبدة.',
  'Add the rice and cook for 20 minutes.': 'يضاف الأرز ويطبخ 20 دقيقة.',
  'Rest for 10 minutes.': 'يترك 10 دقائق.',
};

List<(Rational?, Rational?, String?)> _amounts(Recipe r) => [
  for (final s in r.ingredients)
    for (final l in s.items) (l.min, l.max, l.unitId),
];

List<List<Duration>> _timers(Recipe r) => [
  for (final s in r.steps)
    for (final step in s.items) findDurations(step.text),
];

void main() {
  late RecipeRepository repo;
  late NoopAiImportClient server;
  late _CopyingPhotos photos;
  late Importer importer;

  setUp(() async {
    final (r, _, _) = await testRepo();
    repo = r;
    server = NoopAiImportClient();
    photos = _CopyingPhotos();
    importer = Importer(
      FakeFetcher(const {}),
      repo,
      aiClient: server,
      photos: photos,
    );
  });

  test('only words go out, keyed by ID, into the app\'s language '
      '(IMP-15, SRV-11)', () async {
    server.translator = _server(_dict);
    final original = await repo.save(_english(repo));
    await importer.translate(
      installId: 'inst-1',
      recipe: original,
      toArabic: true,
    );
    final sent = server.translateRequests.single;
    expect(sent.installId, 'inst-1');
    expect(sent.target, 'ar');
    expect(sent.items.map((i) => i.text), [
      'Lamb kabsa',
      'lamb',
      'basmati rice',
      'tomatoes',
      'salt to taste',
      'Brown the lamb in butter.',
      'Add the rice and cook for 20 minutes.',
      'Rest for 10 minutes.',
    ]);
    expect(server.requests, isEmpty); // never the import endpoint
  });

  test('IMP-15: a fake server that changes numbers — the saved copy\'s '
      'amounts, units and timers never change', () async {
    server.translator = _server(
      _dict,
      lie: {
        'Add the rice and cook for 20 minutes.': 'يضاف الأرز ويطبخ 25 دقيقة.',
        'Rest for 10 minutes.': 'يترك قليلًا.',
        'salt to taste': 'ملعقة ملح 1',
      },
    );
    final original = await repo.save(_english(repo));
    final out = await importer.translate(
      installId: 'i',
      recipe: original,
      toArabic: true,
      linkToOriginal: true,
    );
    expect(out.keptOriginal, 3);
    final saved = await repo.save(out.recipe);
    final copy = (await repo.get(saved.id))!;
    expect(copy.id, isNot(original.id));
    expect(_amounts(copy), _amounts(original));
    expect(_timers(copy), _timers(original));
    expect(copy.title, 'كبسة لحم');
    expect(copy.steps.single.items.map((s) => s.text), [
      'يحمر اللحم في الزبدة.',
      'Add the rice and cook for 20 minutes.', // 25 ≠ 20: kept
      'Rest for 10 minutes.', // the timer went: kept
    ]);
    // The original is untouched (IMP-14).
    final again = (await repo.get(original.id))!;
    expect(again.title, 'Lamb kabsa');
    expect(
      again.ingredients.single.items.map((l) => l.original),
      original.ingredients.single.items.map((l) => l.original),
    );
    expect(copy.translatedFrom, original.id);
  });

  test('the copy gets its own photo file (REC-8), copied only once the '
      'translation is good', () async {
    server.translator = _server(_dict);
    final original = await repo.save(_english(repo));
    final out = await importer.translate(
      installId: 'i',
      recipe: original,
      toArabic: true,
    );
    expect(photos.copies, [('/photos/kabsa.jpg', out.recipe.id)]);
    expect(out.recipe.photoPath, '/photos/kabsa.jpg.copy-${out.recipe.id}');
    expect(out.recipe.translatedFrom, isNull); // not asked to link

    server.translator = null;
    server.nextTranslateResult = const AiTranslateSuccess(
      [],
      model: 'm',
      promptVersion: 'p',
    );
    await expectLater(
      importer.translate(installId: 'i', recipe: original, toArabic: true),
      throwsA(
        isA<AiImportException>().having(
          (e) => e.kind,
          'kind',
          AiImportErrorKind.badTranslation,
        ),
      ),
    );
    expect(photos.copies, hasLength(1)); // nothing more copied
  });

  test('an ID missing or sent back twice changes nothing: badTranslation '
      '(SRV-7)', () async {
    final original = await repo.save(_english(repo));
    server.translator = (r) => AiTranslateSuccess(
      [...r.items, r.items.first],
      model: 'm',
      promptVersion: 'p',
    );
    await expectLater(
      importer.translate(installId: 'i', recipe: original, toArabic: true),
      throwsA(
        isA<AiImportException>().having(
          (e) => e.kind,
          'kind',
          AiImportErrorKind.badTranslation,
        ),
      ),
    );
    expect((await repo.list()).single.id, original.id);
  });

  test('past SRV-11\'s limits nothing is sent: too large', () async {
    final base = _english(repo);
    final long = base.copyWith(
      steps: [
        Section(
          id: repo.newId(),
          items: [
            for (var i = 0; i < maxTranslateItems; i++)
              RecipeStep(id: repo.newId(), text: 'Stir.'),
          ],
        ),
      ],
    );
    await expectLater(
      importer.translate(installId: 'i', recipe: long, toArabic: true),
      throwsA(
        isA<AiImportException>().having(
          (e) => e.kind,
          'kind',
          AiImportErrorKind.tooLarge,
        ),
      ),
    );
    expect(server.translateRequests, isEmpty);
  });

  test('a server error comes through as its own kind', () async {
    server.nextTranslateResult = const AiTranslateError(
      AiImportErrorKind.limitReached,
    );
    await expectLater(
      importer.translate(
        installId: 'i',
        recipe: _english(repo),
        toArabic: true,
      ),
      throwsA(
        isA<AiImportException>().having(
          (e) => e.kind,
          'kind',
          AiImportErrorKind.limitReached,
        ),
      ),
    );
  });
}
