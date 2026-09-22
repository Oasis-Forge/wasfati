import 'package:sqflite/sqflite.dart';

import '../models/plan.dart';
import '../models/ramadan.dart';
import '../services/ids.dart';

/// Reads and writes the meal plan (PLAN-1–PLAN-6). Entries live in their
/// own table, so planning never touches a recipe (PLAN-3).
class PlanRepository {
  PlanRepository(this._db, {Clock? clock, IdSource? ids})
    : _clock = clock ?? systemClock,
      _ids = ids ?? uuidV4;

  final Database _db;
  final Clock _clock;
  final IdSource _ids;

  String newId() => _ids();
  DateTime now() => _clock();

  /// Live entries from [from] to [to] (both included), in day, meal and
  /// position order. An entry whose recipe is in the trash is left out and
  /// comes back when the recipe is restored (PLAN-6, DEL-1).
  ///
  /// The meal order within a day follows [slotsFor], not the raw enum
  /// index (RAM-1): pass [ramadanMode] and [ramadanMonthFor] (the Ramadan
  /// month a day falls in, if any) to sort Ramadan days as suhoor, iftar,
  /// snack. Both default to "never Ramadan", the plain order.
  Future<List<PlanEntry>> entriesBetween(
    DateTime from,
    DateTime to, {
    bool ramadanMode = false,
    RamadanMonth? Function(DateTime day)? ramadanMonthFor,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT p.* FROM plan_entries p '
      'LEFT JOIN recipes r ON r.id = p.recipe_id '
      'WHERE p.deleted_at IS NULL AND p.date BETWEEN ? AND ? '
      'AND (p.recipe_id IS NULL OR r.deleted_at IS NULL)',
      [dateKey(from), dateKey(to)],
    );
    final entries = [for (final r in rows) PlanEntry.fromMap(r)];
    _sortInDayOrder(
      entries,
      ramadanMode: ramadanMode,
      ramadanMonthFor: ramadanMonthFor,
    );
    return entries;
  }

  /// The next meal this recipe is planned for, from [from] on, or null
  /// (PLAN-6). Same-day ties follow [slotsFor] (RAM-1); see
  /// [entriesBetween].
  Future<PlanEntry?> nextFor(
    String recipeId,
    DateTime from, {
    bool ramadanMode = false,
    RamadanMonth? Function(DateTime day)? ramadanMonthFor,
  }) async {
    final rows = await _db.query(
      'plan_entries',
      where: 'deleted_at IS NULL AND recipe_id = ? AND date >= ?',
      whereArgs: [recipeId, dateKey(from)],
      orderBy: 'date',
    );
    if (rows.isEmpty) return null;
    final entries = [for (final r in rows) PlanEntry.fromMap(r)];
    _sortInDayOrder(
      entries,
      ramadanMode: ramadanMode,
      ramadanMonthFor: ramadanMonthFor,
    );
    return entries.first;
  }

  /// Adds or updates an entry. A new one goes last in its meal, which holds
  /// at most [PlanEntry.maxPerSlot] (PLAN-2).
  Future<PlanEntry> save(PlanEntry entry) async {
    final problem = entry.validate();
    if (problem != null) {
      throw ArgumentError.value(entry.id, 'entry', 'invalid: $problem');
    }
    final known = await _db.query(
      'plan_entries',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    var saved = entry.copyWith(updatedAt: _clock());
    if (known.isEmpty) {
      final taken = await _count(entry.date, entry.slot);
      if (taken >= PlanEntry.maxPerSlot) {
        throw StateError('a meal holds ${PlanEntry.maxPerSlot} entries');
      }
      saved = saved.copyWith(position: taken);
    }
    await _db.insert(
      'plan_entries',
      saved.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return saved;
  }

  /// Moves an entry to another day or meal, or copies it there (PLAN-4).
  /// Returns the entry that ended up at the new place.
  Future<PlanEntry> moveTo(
    PlanEntry entry,
    DateTime date,
    MealSlot slot, {
    bool copy = false,
  }) async {
    final now = _clock();
    final moved = entry.copyWith(
      id: copy ? _ids() : entry.id,
      date: dateOnly(date),
      slot: slot,
      position: await _count(date, slot),
      updatedAt: now,
    );
    if (copy) {
      final fresh = PlanEntry(
        id: moved.id,
        date: moved.date,
        slot: moved.slot,
        recipeId: moved.recipeId,
        note: moved.note,
        servings: moved.servings,
        multiplier: moved.multiplier,
        position: moved.position,
        createdAt: now,
        updatedAt: now,
      );
      return save(fresh);
    }
    await _db.update(
      'plan_entries',
      moved.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    return moved;
  }

  /// Moves an entry to the trash (DEL-1); [restore] undoes it (DEL-2).
  Future<void> remove(String id) => _setDeleted([id], _clock());

  Future<void> restore(Iterable<String> ids) => _setDeleted(ids, null);

  /// Clears every entry between [from] and [to] (PLAN-4) and returns their
  /// IDs, so Undo can put them back.
  Future<List<String>> clearRange(DateTime from, DateTime to) async {
    final rows = await _db.query(
      'plan_entries',
      columns: ['id'],
      where: 'deleted_at IS NULL AND date BETWEEN ? AND ?',
      whereArgs: [dateKey(from), dateKey(to)],
    );
    final ids = [for (final r in rows) r['id']! as String];
    await _setDeleted(ids, _clock());
    return ids;
  }

  /// Drops entries deleted more than [RecipeRepository.trashDays] days ago
  /// (DEL-2). Run at start, with the recipe trash.
  Future<void> purgeTrash({int days = 30}) async {
    final cutoff = _clock()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    await _db.delete(
      'plan_entries',
      where: 'deleted_at IS NOT NULL AND deleted_at < ?',
      whereArgs: [cutoff],
    );
  }

  /// Marks these entries as sent to groceries, so adding the same week
  /// twice doesn't double the list (PLAN-5).
  Future<void> markAddedToGroceries(Iterable<String> ids, DateTime at) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    final marks = List.filled(list.length, '?').join(',');
    await _db.update(
      'plan_entries',
      {
        'added_to_groceries_at': at.millisecondsSinceEpoch,
        'updated_at': _clock().millisecondsSinceEpoch,
      },
      where: 'id IN ($marks)',
      whereArgs: list,
    );
  }

  Future<void> _setDeleted(Iterable<String> ids, DateTime? at) async {
    if (ids.isEmpty) return;
    final marks = List.filled(ids.length, '?').join(',');
    await _db.update(
      'plan_entries',
      {
        'deleted_at': at?.millisecondsSinceEpoch,
        'updated_at': _clock().millisecondsSinceEpoch,
      },
      where: 'id IN ($marks)',
      whereArgs: ids.toList(),
    );
  }

  Future<int> _count(DateTime date, MealSlot slot) async =>
      Sqflite.firstIntValue(
        await _db.rawQuery(
          'SELECT COUNT(*) FROM plan_entries '
          'WHERE deleted_at IS NULL AND date = ? AND slot = ?',
          [dateKey(date), slot.name],
        ),
      ) ??
      0;

  /// Sorts [entries] by day, then meal in that day's display order (RAM-1:
  /// [slotsFor], never the raw enum index), then position and add time.
  static void _sortInDayOrder(
    List<PlanEntry> entries, {
    required bool ramadanMode,
    RamadanMonth? Function(DateTime day)? ramadanMonthFor,
  }) {
    final withEntries = <String, Set<MealSlot>>{};
    for (final e in entries) {
      (withEntries[dateKey(e.date)] ??= {}).add(e.slot);
    }
    // Computed once per day, not once per comparison, and [ramadanMonthFor]
    // is never even called with the mode off (should-fix, performance):
    // every reload used to look Ramadan up for every same-day tie, mode on
    // or off.
    final orderCache = <String, List<MealSlot>>{};
    List<MealSlot> orderFor(DateTime day) => orderCache.putIfAbsent(
      dateKey(day),
      () => slotsFor(
        day,
        ramadan: ramadanMode,
        month: ramadanMode ? ramadanMonthFor?.call(day) : null,
        withEntries: withEntries[dateKey(day)] ?? const {},
      ),
    );
    entries.sort((a, b) {
      final day = a.date.compareTo(b.date);
      if (day != 0) return day;
      final order = orderFor(a.date);
      final slot = order.indexOf(a.slot).compareTo(order.indexOf(b.slot));
      if (slot != 0) return slot;
      final at = a.position.compareTo(b.position);
      return at != 0 ? at : a.createdAt.compareTo(b.createdAt);
    });
  }
}
