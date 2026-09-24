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
  }

  /// Saves [recipe]; returns it as saved, or null if the write failed.
  Future<Recipe?> save(Recipe recipe) => _write(() async {
    final saved = await _repo.save(recipe);
    await _reload();
    return saved;
  });

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
