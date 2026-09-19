import 'package:flutter/foundation.dart';

import '../db/recipe_repository.dart';
import '../models/recipe.dart';

/// The recipe list. Writes go to the database first and change state only
/// after they succeed; a failed write leaves the list as it was and sets
/// [lastError] for the screen to show (reliable writes).
class RecipesState extends ChangeNotifier {
  RecipesState(this._repo);

  final RecipeRepository _repo;

  List<RecipeSummary> _recipes = const [];
  bool _loaded = false;
  Object? _lastError;

  List<RecipeSummary> get recipes => _recipes;
  bool get loaded => _loaded;

  /// The last failed write, cleared by [clearError].
  Object? get lastError => _lastError;

  RecipeRepository get repository => _repo;

  Future<void> load() async {
    _recipes = await _repo.list();
    _loaded = true;
    notifyListeners();
  }

  /// Saves [recipe]; returns it as saved, or null if the write failed.
  Future<Recipe?> save(Recipe recipe) => _write(() async {
    final saved = await _repo.save(recipe);
    _recipes = await _repo.list();
    return saved;
  });

  /// Moves a recipe to the trash (DEL-1); [restore] undoes it (DEL-2).
  Future<bool> delete(String id) async =>
      await _write(() async {
        await _repo.delete(id);
        _recipes = _recipes.where((r) => r.id != id).toList();
        return true;
      }) ??
      false;

  Future<bool> restore(String id) async =>
      await _write(() async {
        await _repo.restore(id);
        _recipes = await _repo.list();
        return true;
      }) ??
      false;

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  Future<T?> _write<T>(Future<T> Function() op) async {
    final before = _recipes;
    try {
      final result = await op();
      _lastError = null;
      notifyListeners();
      return result;
    } catch (e) {
      _recipes = before; // roll back anything the op changed in memory
      _lastError = e;
      notifyListeners();
      return null;
    }
  }
}
