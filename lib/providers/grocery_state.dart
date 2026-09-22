import 'package:flutter/foundation.dart';

import '../db/grocery_repository.dart';
import '../models/aisles.dart';
import '../models/grocery.dart';

/// The grocery list (GRO-1–GRO-7) and everything that changes it. Writes go
/// to the database first and change state only after they succeed; a
/// failed write leaves the list as it was and sets [lastError] for the
/// screen to show (reliable writes).
///
/// The "By aisle"/"By recipe" view choice isn't kept here: it's
/// [GroceryView] in `AppSettings`, read and written through `SettingsState`
/// (GRO-5, should-fix: it used to reset on every restart).
class GroceryState extends ChangeNotifier {
  GroceryState(this._repo);

  final GroceryRepository _repo;

  List<GroceryItem> _items = const [];
  bool _loaded = false;
  Object? _lastError;

  /// Live items, aisle then name (GRO-5, ORG-5).
  List<GroceryItem> get items => _items;

  /// Live items not yet done, in list order (GRO-5).
  List<GroceryItem> get toBuy => [
    for (final i in _items)
      if (!i.isDone) i,
  ];

  /// Live items already done, for the collapsed "تم" section (GRO-5).
  List<GroceryItem> get done => [
    for (final i in _items)
      if (i.isDone) i,
  ];

  bool get loaded => _loaded;
  Object? get lastError => _lastError;
  GroceryRepository get repository => _repo;

  Future<void> load() async {
    await _reload();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _reload() async {
    _items = await _repo.list();
  }

  /// Adds lines from a recipe's page (GRO-2) or the plan (PLAN-5).
  Future<bool> add(List<IncomingLine> lines) async =>
      await _write(() async {
        await _repo.add(lines);
        await _reload();
        return true;
      }) ??
      false;

  /// Adds one line typed by hand (GRO-1).
  Future<bool> addByHand(String text) async =>
      await _write(() async {
        await _repo.addByHand(text);
        await _reload();
        return true;
      }) ??
      false;

  /// Ticks or unticks an item (GRO-5).
  Future<bool> setDone(String id, bool done) async =>
      await _write(() async {
        await _repo.setDone(id, done);
        await _reload();
        return true;
      }) ??
      false;

  /// Moves an item to another aisle (GRO-4).
  Future<bool> moveToAisle(String id, Aisle aisle) async =>
      await _write(() async {
        await _repo.moveToAisle(id, aisle);
        await _reload();
        return true;
      }) ??
      false;

  /// Takes out only this recipe's amounts (GRO-5's "By recipe" view);
  /// returns the removed amount and item IDs, for Undo (DEL-2, should-fix:
  /// "Remove" had no Undo), or null on a failed write.
  Future<({List<String> amountIds, List<String> itemIds})?> removeRecipe(
    String recipeId,
  ) => _write(() async {
    final removed = await _repo.removeRecipe(recipeId);
    await _reload();
    return removed;
  });

  /// Undo for [removeRecipe] (DEL-2).
  Future<bool> restoreRecipe(
    Iterable<String> amountIds,
    Iterable<String> itemIds,
  ) async =>
      await _write(() async {
        await _repo.restoreRemoved(amountIds, itemIds);
        await _reload();
        return true;
      }) ??
      false;

  /// Clears the done items and returns their IDs, for Undo (GRO-5, DEL-2).
  Future<List<String>?> clearDone() => _write(() async {
    final ids = await _repo.clearDone();
    await _reload();
    return ids;
  });

  /// Clears the whole list and returns the IDs, for Undo (GRO-5, DEL-2).
  Future<List<String>?> clearAll() => _write(() async {
    final ids = await _repo.clearAll();
    await _reload();
    return ids;
  });

  /// Undo for [clearDone] and [clearAll] (DEL-2).
  Future<bool> restore(Iterable<String> ids) async =>
      await _write(() async {
        await _repo.restore(ids);
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
    final before = _items;
    try {
      final result = await op();
      _lastError = null;
      notifyListeners();
      return result;
    } catch (e) {
      _items = before; // nothing the op changed in memory survives
      _lastError = e;
      notifyListeners();
      return null;
    }
  }
}
