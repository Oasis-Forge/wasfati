import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/recipe_import.dart';
import 'package:wasfati/services/ai_import.dart';
import 'package:wasfati/services/importer.dart';
import 'package:wasfati/services/web_import.dart';

import '../helpers.dart';

/// Serves made-up pages; never touches the network.
class FakeFetcher implements PageFetcher {
  FakeFetcher(this.pages);
  final Map<String, String> pages;
  final fetched = <Uri>[];

  @override
  Future<String> page(Uri url) async {
    fetched.add(url);
    final p = pages[url.toString()];
    if (p == null) throw const ImportException(ImportFailure.unreachable);
    return p;
  }

  @override
  Future<Uint8List?> image(Uri url) async => Uint8List.fromList([1, 2, 3]);
}

const kabsaPage = '''<html><head><script type="application/ld+json">
{"@type":"Recipe","name":"كبسة دجاج","image":"/img/k.jpg","recipeYield":"4 حصص",
 "totalTime":"PT1H","recipeIngredient":["١ ك دجاج","كوبين ارز بسمتي",
 "ملح حسب الذوق"],"recipeInstructions":[{"@type":"HowToStep",
 "text":"يحمر الدجاج"},{"@type":"HowToStep","text":"يضاف الرز لمدة 20 دقيقة"}]}
</script></head></html>''';

void main() {
  test('a recipe site becomes a draft with parsed lines and a photo', () async {
    final (repo, _, _) = await testRepo();
    final fetcher = FakeFetcher({
      'https://www.site.com/kabsa?utm_source=x': kabsaPage,
    });
    final importer = Importer(
      fetcher,
      repo,
      savePhoto: (id, bytes) async => '/photos/$id.jpg',
    );
    final r = await importer.fromUrl('https://www.site.com/kabsa?utm_source=x');

    expect(r.title, 'كبسة دجاج');
    expect((r.servings, r.cookMinutes), (4, 60));
    expect(r.sourceType, SourceType.website);
    expect(r.sourceUrl, 'https://site.com/kabsa'); // IMP-9 normalized
    expect(r.photoPath, '/photos/${r.id}.jpg');
    final lines = r.ingredients.single.items;
    expect((lines[0].min, lines[0].unitId), (Rational.one, 'kg')); // "١ ك"
    expect((lines[1].min, lines[1].unitId), (Rational(2), 'cup')); // كوبين
    expect(lines[2].min, isNull); // to taste
    expect(r.steps.single.items.map((s) => s.text), [
      'يحمر الدجاج',
      'يضاف الرز لمدة 20 دقيقة',
    ]);
    // Nothing is saved yet: the user saves from the preview (IMP-5).
    expect(await repo.library(), isEmpty);
  });

  test('failures: not a link, unreachable, no recipe data', () async {
    final (repo, _, _) = await testRepo();
    final importer = Importer(
      FakeFetcher({'https://news.com/a': '<html><p>news</p></html>'}),
      repo,
      savePhoto: (_, _) async => null,
    );
    Future<ImportFailure?> fail(String url) async {
      try {
        await importer.fromUrl(url);
        return null;
      } on ImportException catch (e) {
        return e.failure;
      }
    }

    expect(await fail('كبسة'), ImportFailure.invalidUrl);
    expect(await fail('ftp://x.com/a'), ImportFailure.invalidUrl);
    expect(await fail('https://down.com/a'), ImportFailure.unreachable);
    expect(await fail('https://news.com/a'), ImportFailure.noRecipe);
  });

  test('a page already saved is found by its normalized URL (IMP-9)', () async {
    final (repo, _, _) = await testRepo();
    final importer = Importer(
      FakeFetcher({'https://site.com/kabsa': kabsaPage}),
      repo,
      savePhoto: (_, _) async => null,
    );
    await repo.save(await importer.fromUrl('https://site.com/kabsa'));
    expect(
      await importer.duplicateOf('http://www.site.com/kabsa/?fbclid=1'),
      isNotNull,
    );
    expect(await importer.duplicateOf('https://site.com/other'), isNull);
  });

  test('shared text becomes a draft (IMP-13)', () async {
    final (repo, _, _) = await testRepo();
    final importer = Importer(FakeFetcher({}), repo);
    final r = importer.fromText(
      'شوربة عدس\nالمقادير:\nكوب عدس\nالطريقة:\nيسلق العدس',
    );
    expect(r.title, 'شوربة عدس');
    expect(r.ingredients.single.items.single.unitId, 'cup');
    expect(r.steps.single.items.single.text, 'يسلق العدس');
    expect(r.sourceType, SourceType.written);
  });

  group('fromAi (IMP-3, SRV-1): the response goes through QTY-1 like any '
      'other line', () {
    test('a social link\'s AI result is parsed on the device, normalized '
        'and tagged social (Decision 17, IMP-9)', () async {
      final (repo, _, _) = await testRepo();
      final ai = NoopAiImportClient()
        ..nextResult = const AiImportSuccess(
          ImportedRecipe(
            title: 'شوربة عدس',
            servings: 4,
            ingredients: [
              (null, ['٢ كوب دقيق', '١ كيلو دجاج', 'ملح حسب الذوق']),
            ],
            steps: [
              (null, ['يغسل العدس جيدا']),
            ],
          ),
          model: 'haiku',
          promptVersion: '1',
          cached: false,
        );
      final importer = Importer(
        FakeFetcher({}),
        repo,
        savePhoto: (_, _) async => null,
        aiClient: ai,
      );
      final r = await importer.fromAi(
        installId: 'inst-1',
        url: 'https://www.tiktok.com/@a/video/1?is_from_webapp=1',
      );

      expect(r.title, 'شوربة عدس');
      expect(r.sourceType, SourceType.social);
      // IMP-9: normalized the same way a website import would be.
      expect(r.sourceUrl, 'https://tiktok.com/@a/video/1');
      final lines = r.ingredients.single.items;
      // Amounts, units and notes all come from the device's own parser
      // (QTY-1), never the server (Decision 17) — the server only ever
      // sent verbatim text.
      expect((lines[0].min, lines[0].unitId), (Rational(2), 'cup')); // كوب
      expect((lines[1].min, lines[1].unitId), (Rational.one, 'kg')); // كيلو
      expect(lines[2].min, isNull); // حسب الذوق: to taste
      expect(r.steps.single.items.single.text, 'يغسل العدس جيدا');
      expect(ai.requests.single.installId, 'inst-1');
    });

    test('pasted text has no source URL and is tagged written', () async {
      final (repo, _, _) = await testRepo();
      final ai = NoopAiImportClient()
        ..nextResult = const AiImportSuccess(
          ImportedRecipe(
            title: 'كبسة',
            ingredients: [
              (null, ['3 أكواب أرز']),
            ],
          ),
          model: 'haiku',
          promptVersion: '1',
          cached: false,
        );
      final importer = Importer(FakeFetcher({}), repo, aiClient: ai);
      final r = await importer.fromAi(installId: 'inst-1', text: 'كبسة دجاج');

      expect(r.sourceType, SourceType.written);
      expect(r.sourceUrl, isNull);
      expect(ai.requests.single.text, 'كبسة دجاج');
      expect(ai.requests.single.url, isNull);
    });

    test('the original caption is kept, collapsed, in the recipe\'s notes '
        '(IMP-6, should-fix, review)', () async {
      final (repo, _, _) = await testRepo();
      final ai = NoopAiImportClient()
        ..nextResult = const AiImportSuccess(
          ImportedRecipe(
            title: 'كبسة',
            ingredients: [
              (null, ['3 أكواب أرز']),
            ],
          ),
          model: 'haiku',
          promptVersion: '1',
          cached: false,
        );
      final importer = Importer(FakeFetcher({}), repo, aiClient: ai);
      final r = await importer.fromAi(
        installId: 'inst-1',
        text: 'كبسة دجاج\nمكونات لذيذة\n\nمع الأرز',
      );
      // Line breaks collapsed to single spaces; nothing dropped.
      expect(r.notes, 'كبسة دجاج مكونات لذيذة مع الأرز');
    });

    test(
      'a social link\'s AI import keeps no notes: the server never sends '
      'the page text back, and the device never fetched it (IMP-6)',
      () async {
        final (repo, _, _) = await testRepo();
        final ai = NoopAiImportClient()
          ..nextResult = const AiImportSuccess(
            ImportedRecipe(title: 'ريل'),
            model: 'haiku',
            promptVersion: '1',
            cached: false,
          );
        final importer = Importer(FakeFetcher({}), repo, aiClient: ai);
        final r = await importer.fromAi(
          installId: 'inst-1',
          url: 'https://www.tiktok.com/@a/video/1',
        );
        expect(r.notes, isNull);
      },
    );

    test('every server error kind surfaces as AiImportException(kind), '
        'never a bare exception (SRV-7)', () async {
      final (repo, _, _) = await testRepo();
      for (final kind in AiImportErrorKind.values) {
        final ai = NoopAiImportClient()..nextResult = AiImportError(kind);
        final importer = Importer(FakeFetcher({}), repo, aiClient: ai);
        await expectLater(
          () => importer.fromAi(installId: 'i', text: 'x'),
          throwsA(isA<AiImportException>().having((e) => e.kind, 'kind', kind)),
        );
      }
    });

    test('a saved AI-imported link is found as a duplicate the same way a '
        'website import is (IMP-9, "both paths")', () async {
      final (repo, _, _) = await testRepo();
      final ai = NoopAiImportClient()
        ..nextResult = const AiImportSuccess(
          ImportedRecipe(title: 'ريل تيك توك'),
          model: 'haiku',
          promptVersion: '1',
          cached: false,
        );
      final importer = Importer(FakeFetcher({}), repo, aiClient: ai);
      final saved = await importer.fromAi(
        installId: 'inst-1',
        url: 'https://www.tiktok.com/@a/video/1',
      );
      await repo.save(saved);

      expect(
        await importer.duplicateOf('https://tiktok.com/@a/video/1?si=xyz'),
        isNotNull,
      );
      expect(
        await importer.duplicateOf('https://tiktok.com/@a/video/2'),
        isNull,
      );
    });
  });

  group('needsAiImport (IMP-2, IMP-3): the routing decision', () {
    test('no recipe data or an unreachable page both route to AI', () {
      expect(needsAiImport(ImportFailure.noRecipe), isTrue);
      expect(needsAiImport(ImportFailure.unreachable), isTrue);
    });

    test('a genuinely invalid link never goes to AI', () {
      expect(needsAiImport(ImportFailure.invalidUrl), isFalse);
    });

    test('a real device-first failure from fromUrl is one needsAiImport '
        'agrees should retry', () async {
      final (repo, _, _) = await testRepo();
      final importer = Importer(
        FakeFetcher({'https://news.com/a': '<html><p>news</p></html>'}),
        repo,
        savePhoto: (_, _) async => null,
      );
      try {
        await importer.fromUrl('https://news.com/a');
        fail('expected ImportException');
      } on ImportException catch (e) {
        expect(needsAiImport(e.failure), isTrue); // -> retry via fromAi
      }
    });
  });

  group('fromPhotos (IMP-1, IMP-10)', () {
    const found = AiImportSuccess(
      ImportedRecipe(
        title: 'معمول',
        ingredients: [
          (null, ['٣ أكواب سميد', '0 ماء ورد']),
        ],
        steps: [
          (null, ['يعجن السميد']),
        ],
      ),
      model: 'haiku',
      promptVersion: '1',
      cached: false,
    );

    test('each photo is resized to at most 1600 px JPEG before it is sent, '
        'with no url or text', () async {
      final (repo, _, _) = await testRepo();
      final ai = NoopAiImportClient()..nextResult = found;
      final importer = Importer(
        FakeFetcher({}),
        repo,
        savePhoto: (_, _) async => null,
        aiClient: ai,
      );
      final wide = pngOf(3200, 1200);
      final tall = pngOf(900, 2400);
      await importer.fromPhotos(installId: 'inst-1', images: [wide, tall]);

      final sent = ai.requests.single;
      expect((sent.installId, sent.url, sent.text), ('inst-1', null, null));
      expect(sent.images, hasLength(2));
      final first = img.decodeJpg(sent.images![0])!;
      final second = img.decodeJpg(sent.images![1])!;
      expect((first.width, first.height), (1600, 600)); // order kept
      expect((second.width, second.height), (600, 1600));
    });

    test('the first photo becomes the recipe photo, and the lines go through '
        'QTY-1 on the device', () async {
      final (repo, _, _) = await testRepo();
      final ai = NoopAiImportClient()..nextResult = found;
      final saved = <(String, Uint8List)>[];
      final importer = Importer(
        FakeFetcher({}),
        repo,
        savePhoto: (id, bytes) async {
          saved.add((id, bytes));
          return '/photos/$id.jpg';
        },
        aiClient: ai,
      );
      final page1 = pngOf(40, 30);
      final page2 = pngOf(30, 40);
      final r = await importer.fromPhotos(
        installId: 'inst-1',
        images: [page1, page2],
      );

      expect(r.title, 'معمول');
      expect(r.sourceType, SourceType.photo);
      expect(r.sourceUrl, isNull); // a photo has no link (IMP-8)
      expect(r.photoPath, '/photos/${r.id}.jpg');
      expect(saved.single, (r.id, page1)); // the first page, only
      final lines = r.ingredients.single.items;
      expect((lines[0].min, lines[0].unitId), (Rational(3), 'cup'));
      expect(lines[1].min, isNull); // "0" is no amount (QTY-1)
      expect(await repo.library(), isEmpty); // nothing saved yet (IMP-5)
    });

    test('a failed import saves no photo file', () async {
      final (repo, _, _) = await testRepo();
      final ai = NoopAiImportClient()
        ..nextResult = const AiImportError(AiImportErrorKind.tooLarge);
      var saves = 0;
      final importer = Importer(
        FakeFetcher({}),
        repo,
        savePhoto: (_, _) async {
          saves++;
          return '/photos/x.jpg';
        },
        aiClient: ai,
      );
      await expectLater(
        importer.fromPhotos(installId: 'i', images: [pngOf(20, 20)]),
        throwsA(
          isA<AiImportException>().having(
            (e) => e.kind,
            'kind',
            AiImportErrorKind.tooLarge,
          ),
        ),
      );
      expect(saves, 0);
    });

    test('a picture the device cannot read sends nothing at all', () async {
      final (repo, _, _) = await testRepo();
      final ai = NoopAiImportClient()..nextResult = found;
      final importer = Importer(FakeFetcher({}), repo, aiClient: ai);
      await expectLater(
        importer.fromPhotos(
          installId: 'i',
          images: [
            pngOf(20, 20),
            Uint8List.fromList(const [1, 2, 3]),
          ],
        ),
        throwsA(
          isA<AiImportException>().having(
            (e) => e.kind,
            'kind',
            AiImportErrorKind.unreadablePhoto,
          ),
        ),
      );
      expect(ai.requests, isEmpty);
    });
  });
}

/// A plain PNG of the given size, like a screenshot straight from the
/// picker.
Uint8List pngOf(int width, int height) =>
    img.encodePng(img.Image(width: width, height: height));
