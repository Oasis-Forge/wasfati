import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/db/recipe_repository.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/providers/recipes_state.dart';
import 'package:wasfati/providers/review_prompt_state.dart';
import 'package:wasfati/providers/settings_state.dart';
import 'package:wasfati/services/store_review.dart';

import '../helpers.dart';

/// RUN-5 end to end over the real state: the library decides "saved an
/// import" and "marked as cooked", Settings keeps when the store was asked.
void main() {
  late RecipeRepository repo;
  late FakeClock clock;
  late RecipesState recipes;
  late SettingsState settings;
  late NoopStoreReview store;
  late ReviewPrompt prompt;

  setUp(() async {
    final (r, c, _) = await testRepo();
    repo = r;
    clock = c;
    recipes = RecipesState(repo);
    await recipes.load();
    settings = SettingsState(repo.db, clock: clock.call);
    await settings.update(const AppSettings(firstRunComplete: true));
    store = NoopStoreReview();
    prompt = ReviewPrompt(
      store: store,
      settings: settings,
      recipes: recipes,
      clock: clock.call,
    );
  });

  /// An imported recipe (website, like the competitor research's kabsa).
  Future<Recipe> saveImport() async => (await recipes.save(kabsa(repo)))!;

  /// A recipe written by hand.
  Future<Recipe> saveWritten() async => (await recipes.save(
    kabsa(repo, title: 'عدس').copyWith(sourceType: SourceType.written),
  ))!;

  test('nothing saved, nothing cooked: the store is never asked', () async {
    expect(await prompt.afterCooking(), isFalse);
    expect(store.requests, 0);
    expect(settings.settings.reviewAskedAt, isNull);
  });

  test('an import saved but nothing cooked: not asked', () async {
    await saveImport();
    expect(await prompt.afterCooking(), isFalse);
    expect(store.requests, 0);
  });

  test('a recipe cooked but no import ever saved: not asked', () async {
    final r = await saveWritten();
    await recipes.markCooked(r.id);
    expect(await prompt.afterCooking(), isFalse);
    expect(store.requests, 0);
  });

  test('an import saved and a recipe cooked — not necessarily the same one '
      '— asks once, and remembers when', () async {
    await saveImport();
    final written = await saveWritten();
    await recipes.markCooked(written.id);

    expect(await prompt.afterCooking(), isTrue);
    expect(store.requests, 1);
    expect(settings.settings.reviewAskedAt, clock.now);

    // Stored, so a restart doesn't forget it.
    final reloaded = SettingsState(repo.db);
    await reloaded.load();
    expect(reloaded.settings.reviewAskedAt, clock.now);
  });

  test('then not again for 120 days, and again after', () async {
    final r = await saveImport();
    await recipes.markCooked(r.id);
    expect(await prompt.afterCooking(), isTrue);

    clock.advance(const Duration(days: 1));
    expect(await prompt.afterCooking(), isFalse);
    clock.advance(const Duration(days: 118)); // day 119
    expect(await prompt.afterCooking(), isFalse);
    expect(store.requests, 1);

    clock.advance(const Duration(days: 1)); // day 120
    expect(await prompt.afterCooking(), isTrue);
    expect(store.requests, 2);
  });

  test(
    'never while the first run is under way (setup, the walkthrough)',
    () async {
      await settings.update(const AppSettings(firstRunComplete: false));
      final r = await saveImport();
      await recipes.markCooked(r.id);
      expect(await prompt.afterCooking(), isFalse);
      expect(store.requests, 0);
      expect(settings.settings.reviewAskedAt, isNull);
    },
  );

  test('an import that was deleted no longer counts', () async {
    final imported = await saveImport();
    final written = await saveWritten();
    await recipes.markCooked(written.id);
    await recipes.delete(imported.id);
    expect(await prompt.afterCooking(), isFalse);
    expect(store.requests, 0);
  });

  test('a write that fails asks nothing and throws nothing (cook mode '
      'doesn\'t wait for it)', () async {
    final r = await saveImport();
    await recipes.markCooked(r.id);
    await repo.db.close();
    expect(await prompt.afterCooking(), isFalse);
    expect(store.requests, 0);
  });

  test('two closes at once ask the store only once', () async {
    final r = await saveImport();
    await recipes.markCooked(r.id);
    final both = await Future.wait([
      prompt.afterCooking(),
      prompt.afterCooking(),
    ]);
    expect(both.where((asked) => asked), hasLength(1));
    expect(store.requests, 1);
  });
}
