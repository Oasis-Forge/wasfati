import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/library.dart';

import '../helpers.dart';

void main() {
  test('cookbooks and tags are saved with the recipe and read back', () async {
    final (repo, _, _) = await testRepo();
    final ramadan = await repo.saveCookbook('رمضان');
    final quick = await repo.saveCookbook('عشاء سريع');
    final saved = await repo.save(
      kabsa(repo).copyWith(cookbookIds: [ramadan, quick], tags: ['حار', 'لحم']),
    );

    final back = (await repo.get(saved.id))!;
    expect(back.cookbookIds, [ramadan, quick]); // cookbook order (ORG-1)
    expect(back.tags, ['حار', 'لحم']);
    expect((await repo.cookbooks()).map((c) => c.name), ['رمضان', 'عشاء سريع']);

    // Removing one of each is a soft delete of the link (DEL-1, BAK-3).
    await repo.save(back.copyWith(cookbookIds: [quick], tags: ['حار']));
    final again = (await repo.get(saved.id))!;
    expect(again.cookbookIds, [quick]);
    expect(again.tags, ['حار']);
  });

  test('tags match after Arabic normalization (ORG-2, ORG-4)', () async {
    final (repo, _, _) = await testRepo();
    await repo.save(kabsa(repo, title: 'أ').copyWith(tags: ['حارّ']));
    await repo.save(kabsa(repo, title: 'ب').copyWith(tags: ['حار']));
    expect(await repo.tagsInUse(), ['حارّ']); // one tag, used twice
  });

  test('more than 20 tags, or a long one, is refused (ORG-2)', () async {
    final (repo, _, _) = await testRepo();
    await expectLater(
      repo.save(
        kabsa(repo).copyWith(tags: [for (var i = 0; i < 21; i++) 't$i']),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repo.save(kabsa(repo).copyWith(tags: ['x' * 31])),
      throwsArgumentError,
    );
  });

  test('deleting a cookbook keeps its recipes (ORG-1)', () async {
    final (repo, _, _) = await testRepo();
    final book = await repo.saveCookbook('حلويات');
    final r = await repo.save(kabsa(repo).copyWith(cookbookIds: [book]));
    await repo.deleteCookbook(book);

    expect(await repo.cookbooks(), isEmpty);
    expect((await repo.get(r.id))!.cookbookIds, isEmpty);
    expect((await repo.library()).single.id, r.id);
  });

  test('cookbook names are 1–60 characters; rename keeps the ID', () async {
    final (repo, _, _) = await testRepo();
    await expectLater(repo.saveCookbook('  '), throwsArgumentError);
    await expectLater(repo.saveCookbook('x' * 61), throwsArgumentError);
    final id = await repo.saveCookbook('فطور');
    expect(await repo.saveCookbook('فطور الجمعة', id: id), id);
    expect((await repo.cookbooks()).single.name, 'فطور الجمعة');
  });

  test('the library index finds a recipe by ingredient (ORG-3)', () async {
    final (repo, _, _) = await testRepo();
    final book = await repo.saveCookbook('رمضان');
    await repo.save(kabsa(repo).copyWith(cookbookIds: [book], tags: ['عزايم']));
    final entries = await repo.library();
    final hits = runLibraryQuery(entries, const LibraryQuery(text: 'طماطم'));
    expect(hits.single.matchedIngredient, 'طماطم'); // from the sauce group
    expect(entries.single.cookbookIds, {book});
    expect(entries.single.tags, ['عزايم']);
  });

  test('mark as cooked counts and dates it (REC-9, COOK-6)', () async {
    final (repo, clock, _) = await testRepo();
    final r = await repo.save(kabsa(repo));
    clock.advance(const Duration(hours: 1));
    await repo.markCooked(r.id);
    await repo.markCooked(r.id);
    final back = (await repo.get(r.id))!;
    expect(back.cookedCount, 2);
    expect(back.lastCookedAt, clock.now);
  });

  test('cook mode resumes on its page within 12 hours (COOK-6)', () async {
    final (repo, clock, _) = await testRepo();
    await repo.setCookPage('a', 3);
    clock.advance(const Duration(hours: 11));
    expect(await repo.cookPage('a'), 3);
    clock.advance(const Duration(hours: 2));
    expect(await repo.cookPage('a'), isNull);
  });
}
