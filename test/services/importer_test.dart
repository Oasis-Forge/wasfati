import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/recipe.dart';
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
}
