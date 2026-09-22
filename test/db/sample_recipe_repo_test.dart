import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('RUN-6: sample recipe on first run', () {
    test(
      'adds exactly one recipe on an empty database (Arabic title)',
      () async {
        final (repo, _, _) = await testRepo();
        final added = await repo.addSampleOnFirstRun(arabic: true);
        expect(added, isTrue);
        final all = await repo.list();
        expect(all, hasLength(1));
        expect(all.single.title, 'شوربة عدس');
      },
    );

    test('English title when arabic is false', () async {
      final (repo, _, _) = await testRepo();
      final added = await repo.addSampleOnFirstRun(arabic: false);
      expect(added, isTrue);
      expect((await repo.list()).single.title, 'Red lentil soup');
    });

    test('a second call adds nothing', () async {
      final (repo, _, _) = await testRepo();
      await repo.addSampleOnFirstRun(arabic: true);
      final again = await repo.addSampleOnFirstRun(arabic: true);
      expect(again, isFalse);
      expect(await repo.list(), hasLength(1));
    });

    test('deleting it never brings it back (DEL-1)', () async {
      final (repo, _, _) = await testRepo();
      await repo.addSampleOnFirstRun(arabic: true);
      final sample = (await repo.list()).single;
      await repo.delete(sample.id);
      expect(await repo.list(), isEmpty);

      final again = await repo.addSampleOnFirstRun(arabic: true);
      expect(again, isFalse);
      expect(await repo.list(), isEmpty);
    });

    test('purging the trashed sample never brings it back (DEL-2)', () async {
      final (repo, clock, _) = await testRepo();
      await repo.addSampleOnFirstRun(arabic: true);
      final sample = (await repo.list()).single;
      await repo.delete(sample.id);
      clock.advance(const Duration(days: 31));
      await repo.purgeTrash();
      expect(await repo.list(), isEmpty);

      final again = await repo.addSampleOnFirstRun(arabic: true);
      expect(again, isFalse);
      expect(await repo.list(), isEmpty);
    });

    test('a database that already has a recipe never gets the sample, and '
        'the flag is set anyway (even once that recipe is gone)', () async {
      final (repo, clock, _) = await testRepo();
      final r = await repo.save(kabsa(repo));
      final added = await repo.addSampleOnFirstRun(arabic: true);
      expect(added, isFalse);
      expect(await repo.list(), hasLength(1)); // still just the kabsa

      await repo.delete(r.id);
      clock.advance(const Duration(days: 31));
      await repo.purgeTrash();
      expect(await repo.list(), isEmpty);

      final again = await repo.addSampleOnFirstRun(arabic: true);
      expect(again, isFalse);
      expect(await repo.list(), isEmpty);
    });

    test('a database with only a trashed recipe (never purged) never gets '
        'the sample either, and the flag stays set once it is purged too '
        '(should-fix, review: this used to stop at the first call and never '
        'check that the flag was set anyway)', () async {
      final (repo, clock, _) = await testRepo();
      final r = await repo.save(kabsa(repo));
      await repo.delete(r.id); // trashed, not purged: still a row
      expect(await repo.list(), isEmpty); // no live recipes

      final added = await repo.addSampleOnFirstRun(arabic: true);
      expect(added, isFalse);
      expect(await repo.list(), isEmpty);

      clock.advance(const Duration(days: 31));
      await repo.purgeTrash();
      expect(await repo.list(), isEmpty);

      final again = await repo.addSampleOnFirstRun(arabic: true);
      expect(again, isFalse);
      expect(await repo.list(), isEmpty);
    });
  });
}
