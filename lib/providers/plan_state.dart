import 'package:flutter/foundation.dart';

import '../db/plan_repository.dart';
import '../models/plan.dart';
import '../models/quantity/rational.dart';

/// The week the plan screen shows (PLAN-1) and everything that changes it.
/// Writes go to the database first and change state only after they
/// succeed; a failed write leaves the week as it was and sets [lastError]
/// (reliable writes).
class PlanState extends ChangeNotifier {
  PlanState(this._repo);

  final PlanRepository _repo;

  DateTime _start = dateOnly(DateTime.now());
  List<PlanEntry> _entries = const [];
  bool _loaded = false;
  Object? _lastError;

  /// The first day of the week being shown.
  DateTime get weekStart => _start;

  /// Its 7 days, in order.
  List<DateTime> get days => weekDays(_start);

  /// Today as a local calendar date (DATE-1).
  DateTime get today => dateOnly(_repo.now().toLocal());

  bool get loaded => _loaded;
  Object? get lastError => _lastError;
  PlanRepository get repository => _repo;

  /// Every entry of the shown week, in day and meal order.
  List<PlanEntry> get entries => _entries;

  /// The entries planned for one meal of one day (PLAN-1).
  List<PlanEntry> entriesFor(DateTime day, MealSlot slot) => [
    for (final e in _entries)
      if (e.slot == slot && dateKey(e.date) == dateKey(day)) e,
  ];

  /// Shows the week starting at [start] and loads it.
  Future<void> showWeek(DateTime start) async {
    _start = dateOnly(start);
    await _reload();
    _loaded = true;
    notifyListeners();
  }

  /// The week before or after the one shown (PLAN-1).
  Future<void> shiftWeeks(int weeks) =>
      showWeek(DateTime(_start.year, _start.month, _start.day + weeks * 7));

  Future<void> _reload() async {
    final week = days;
    _entries = await _repo.entriesBetween(week.first, week.last);
  }

  /// Plans a recipe or a note for a day and meal (PLAN-3).
  Future<PlanEntry?> add({
    required DateTime date,
    required MealSlot slot,
    String? recipeId,
    String? note,
    int? servings,
    Rational? multiplier,
  }) => _write(() async {
    final now = _repo.now();
    final saved = await _repo.save(
      PlanEntry(
        id: _repo.newId(),
        date: dateOnly(date),
        slot: slot,
        recipeId: recipeId,
        note: note,
        servings: servings,
        multiplier: multiplier,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _reload();
    return saved;
  });

  /// Changes how many people an entry is for (PLAN-2).
  Future<bool> setAmount(
    PlanEntry entry, {
    int? servings,
    Rational? multiplier,
  }) async =>
      await _write(() async {
        await _repo.save(
          entry.copyWith(servings: servings, multiplier: multiplier),
        );
        await _reload();
        return true;
      }) ??
      false;

  /// Moves an entry to another day or meal, or copies it there (PLAN-4).
  Future<bool> moveTo(
    PlanEntry entry,
    DateTime date,
    MealSlot slot, {
    bool copy = false,
  }) async =>
      await _write(() async {
        await _repo.moveTo(entry, date, slot, copy: copy);
        await _reload();
        return true;
      }) ??
      false;

  /// Removes an entry; the recipe itself is untouched (PLAN-4).
  Future<bool> remove(String id) async =>
      await _write(() async {
        await _repo.remove(id);
        await _reload();
        return true;
      }) ??
      false;

  /// Undo for [remove] and [clearWeek] (DEL-2).
  Future<bool> restore(Iterable<String> ids) async =>
      await _write(() async {
        await _repo.restore(ids);
        await _reload();
        return true;
      }) ??
      false;

  /// Clears the shown week and returns the IDs for Undo (PLAN-4).
  Future<List<String>?> clearWeek() => _write(() async {
    final week = days;
    final ids = await _repo.clearRange(week.first, week.last);
    await _reload();
    return ids;
  });

  /// The next meal [recipeId] is planned for, from today on (PLAN-6).
  Future<PlanEntry?> nextFor(String recipeId) => _repo.nextFor(recipeId, today);

  /// Marks these entries as sent to groceries, so adding the same week
  /// twice doesn't double the list (PLAN-5).
  Future<bool> markAddedToGroceries(Iterable<String> ids) async =>
      await _write(() async {
        await _repo.markAddedToGroceries(ids, _repo.now());
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
    final before = _entries;
    try {
      final result = await op();
      _lastError = null;
      notifyListeners();
      return result;
    } catch (e) {
      _entries = before; // nothing the op changed in memory survives
      _lastError = e;
      notifyListeners();
      return null;
    }
  }
}
