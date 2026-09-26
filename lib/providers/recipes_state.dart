import 'package:flutter/foundation.dart';

import '../db/recipe_repository.dart';
import '../models/cookbook.dart';
import '../models/library.dart';
import '../models/quantity/convert.dart';
import '../models/recipe.dart';

/// The library: recipes as search entries, cookbooks and tags in use.
/// Writes go to the database first and change state only after they
/// succeed; a failed write leaves everything as it was and sets
/// [lastError] for the screen to show (reliable writes).
class RecipesState extends ChangeNotifier {
  RecipesState(this._repo);

  final RecipeRepository _repo;

  List<LibraryEntry> _recipes = const [];
  List<Cookbook> _cookbooks = const [];
  List<String> _tags = const [];
  bool _loaded = false;
  Object? _lastError;
  int _revision = 0;
  CookResume? _resume;

  /// Goes up after every successful write, so screens showing one recipe
  /// know to reload it.
  int get revision => _revision;

  /// Live recipes, newest first (ORG-5's default). Deleted ones are never
  /// here (ORG-7).
  List<LibraryEntry> get recipes => _recipes;
  List<Cookbook> get cookbooks => _cookbooks;

  /// Tags in use, most used first (ORG-2 suggestions).
  List<String> get tags => _tags;
  bool get loaded => _loaded;

  /// The last failed write, cleared by [clearError].
  Object? get lastError => _lastError;

  RecipeRepository get repository => _repo;

  /// The recipes matching [q] (ORG-3–ORG-6).
  List<LibraryHit> query(LibraryQuery q) => runLibraryQuery(_recipes, q);

  /// How many live recipes a cookbook holds.
  int countIn(String cookbookId) =>
      _recipes.where((r) => r.cookbookIds.contains(cookbookId)).length;

  /// IMP-14: the live original recipe [id] was translated from, and its
  /// newest live translation; either is null when there's none.
  Future<({RecipeLink? from, RecipeLink? translation})> translationLinks(
    String id,
  ) => _repo.translationLinks(id);

  /// LOOK-12, COOK-6: the library's "تابع الطبخ" card — the most recently
  /// left cook-mode session still inside its 12-hour resume window, for a
  /// recipe still live (ORG-7 drops a deleted or purged one, even if its
  /// progress row hasn't aged out yet). Null when there's nothing to resume.
  Future<CookResume?> resumableSession() async {
    final p = await _repo.latestCookProgress();
    if (p == null) return null;
    final entry = _recipes.where((r) => r.id == p.recipeId).firstOrNull;
    if (entry == null) return null;
    return CookResume(
      recipeId: entry.id,
      title: entry.title,
      photoPath: entry.photoPath,
      step: p.page,
      totalSteps: p.total,
    );
  }

  /// [resumableSession] cached so the library card doesn't run a fresh
  /// database read on every rebuild/keystroke (should-fix); refreshed
  /// whenever the recipes reload and whenever cook mode reports its page.
  CookResume? get resume => _resume;

  /// Cook mode's own write of its current page (COOK-6, LOOK-12): goes
  /// through the state layer, unlike a direct `repository.setCookPage`
  /// call, so [resume] and every listener (the library's "تابع الطبخ"
  /// card) update immediately on the next page change, not just on some
  /// unrelated rebuild.
  Future<void> setCookPage(String recipeId, int page, int totalSteps) async {
    await _repo.setCookPage(recipeId, page, totalSteps);
    await _refreshResume();
    notifyListeners();
  }

  Future<void> _refreshResume() async {
    _resume = await resumableSession();
  }

  Future<void> load() async {
    await _reload();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _reload() async {
    final entries = await _repo.library();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _recipes = entries;
    _cookbooks = await _repo.cookbooks();
    _tags = await _repo.tagsInUse();
    await _refreshResume();
  }

  /// Saves [recipe]; returns it as saved, or null if the write failed.
  Future<Recipe?> save(Recipe recipe) => _write(() async {
    final saved = await _repo.save(recipe);
    await _reload();
    return saved;
  });

  /// RUN-6: offers the built-in sample once, in the language setup ended
  /// in (RUN-3), so the walkthrough ends in a library that already shows
  /// one. The repository's own rules decide: never on a phone that has, or
  /// ever had, a recipe, and never twice. True if it was added.
  Future<bool> addSampleOnFirstRun({required bool arabic}) async =>
      await _write(() async {
        final added = await _repo.addSampleOnFirstRun(arabic: arabic);
        await _reload();
        return added;
      }) ??
      false;

  /// Moves a recipe to the trash (DEL-1); [restore] undoes it (DEL-2).
  Future<bool> delete(String id) async =>
      await _write(() async {
        await _repo.delete(id);
        await _reload();
        return true;
      }) ??
      false;

  Future<bool> restore(String id) async =>
      await _write(() async {
        await _repo.restore(id);
        await _reload();
        return true;
      }) ??
      false;

  /// "Mark as cooked" (REC-9, COOK-6).
  Future<bool> markCooked(String id) async =>
      await _write(() async {
        await _repo.markCooked(id);
        await _reload();
        return true;
      }) ??
      false;

  /// Remembers a recipe's conversion view (SCALE-5).
  Future<bool> setUnitView(String id, UnitView view) async =>
      await _write(() async {
        await _repo.setUnitView(id, view);
        return true;
      }) ??
      false;

  /// Creates a cookbook, or renames it (ORG-1). Returns its ID, or null.
  Future<String?> saveCookbook(String name, {String? id}) => _write(() async {
    final saved = await _repo.saveCookbook(name, id: id);
    await _reload();
    return saved;
  });

  /// Deletes a cookbook; its recipes stay (ORG-1).
  Future<bool> deleteCookbook(String id) async =>
      await _write(() async {
        await _repo.deleteCookbook(id);
        await _reload();
        return true;
      }) ??
      false;

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  Future<T?> _write<T>(Future<T> Function() op) async {
    final before = (_recipes, _cookbooks, _tags);
    try {
      final result = await op();
      _revision++;
      _lastError = null;
      notifyListeners();
      return result;
    } catch (e) {
      // Roll back anything the op changed in memory.
      _recipes = before.$1;
      _cookbooks = before.$2;
      _tags = before.$3;
      _lastError = e;
      notifyListeners();
      return null;
    }
  }
}
