import 'package:flutter/foundation.dart';

import '../db/plan_repository.dart';
import '../models/plan.dart';
import '../models/quantity/rational.dart';
import '../models/ramadan.dart';

/// The days the plan screen shows (PLAN-1, RAM-4) and everything that
/// changes it. Writes go to the database first and change state only
/// after they succeed; a failed write leaves the plan as it was and sets
/// [lastError] (reliable writes).
class PlanState extends ChangeNotifier {
  /// [ramadanMonths] is the calendar this state reads Ramadan dates from
  /// (RAM-2), defaulting to the real, built-in [ramadanTable]. Tests pass
  /// their own list, so they don't depend on that table being filled in.
  PlanState(this._repo, {this._ramadanMonths = ramadanTable});

  final PlanRepository _repo;
  final List<RamadanMonth> _ramadanMonths;

  DateTime _start = dateOnly(DateTime.now());
  // A sane default before showWeek/showRange is ever called, so an early
  // write's _reload() always has a range to query (mirrors the pre-RAM-4
  // behaviour, where `days` was computed from _start on every read).
  List<DateTime> _days = weekDays(dateOnly(DateTime.now()));
  List<PlanEntry> _entries = const [];
  bool _loaded = false;
  Object? _lastError;

  bool _ramadanMode = false;
  int _ramadanShift = 0;
  int? _ramadanShiftYear;

  /// The first day of the range being shown (a week, or a Ramadan month
  /// while the "رمضان" view is open, RAM-4).
  DateTime get weekStart => _start;

  /// Its days, in order: 7 for a week, or a Ramadan month's 29 or 30.
  List<DateTime> get days => _days;

  /// Today as a local calendar date (DATE-1).
  DateTime get today => dateOnly(_repo.now().toLocal());

  bool get loaded => _loaded;
  Object? get lastError => _lastError;
  PlanRepository get repository => _repo;

  /// Whether Ramadan mode is on, as last told by [setRamadanMode] (RAM-1).
  bool get ramadanMode => _ramadanMode;

  /// Every entry of the shown range, in day and meal order.
  List<PlanEntry> get entries => _entries;

  /// The entries planned for one meal of one day (PLAN-1).
  List<PlanEntry> entriesFor(DateTime day, MealSlot slot) => [
    for (final e in _entries)
      if (e.slot == slot && dateKey(e.date) == dateKey(day)) e,
  ];

  /// Which of [day]'s slots already hold an entry, for [slotsFor] (RAM-1).
  Set<MealSlot> slotsWithEntries(DateTime day) => {
    for (final s in MealSlot.values)
      if (entriesFor(day, s).isNotEmpty) s,
  };

  /// Shows the week starting at [start] and loads it.
  Future<void> showWeek(DateTime start) async {
    _start = dateOnly(start);
    _days = weekDays(_start);
    await _reload();
    _loaded = true;
    notifyListeners();
  }

  /// The week before or after the one shown (PLAN-1).
  Future<void> shiftWeeks(int weeks) =>
      showWeek(DateTime(_start.year, _start.month, _start.day + weeks * 7));

  /// Shows an arbitrary inclusive range, day by day: the whole Ramadan
  /// month for the "رمضان" view (RAM-4). "Add to groceries" (PLAN-5) then
  /// lists this range's entries, same as it does the week's.
  Future<void> showRange(DateTime from, DateTime to) async {
    _start = dateOnly(from);
    final end = dateOnly(to);
    _days = [
      for (
        var d = _start;
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        d,
    ];
    await _reload();
    _loaded = true;
    notifyListeners();
  }

  /// Tells the plan whether Ramadan mode is on and the local sighting
  /// shift (RAM-1, RAM-2), so entries sort and label by it. The screen
  /// calls this whenever Settings' Ramadan fields change; it reloads only
  /// when that actually changes what's shown.
  Future<void> setRamadanMode(
    bool mode, {
    int shift = 0,
    int? shiftYear,
  }) async {
    final changed =
        mode != _ramadanMode ||
        shift != _ramadanShift ||
        shiftYear != _ramadanShiftYear;
    _ramadanMode = mode;
    _ramadanShift = shift;
    _ramadanShiftYear = shiftYear;
    if (!changed) return;
    if (_loaded) {
      await _reload();
    } else {
      // Nothing shown yet (before the first showWeek/showRange): still
      // yield once, so notifyListeners below never fires synchronously
      // from a caller's build/didChangeDependencies ("setState during
      // build" — the plan screen calls this there, RAM-1, RAM-2).
      await Future<void>.value();
    }
    notifyListeners();
  }

  int _shiftFor(int hijriYear) =>
      hijriYear == _ramadanShiftYear ? _ramadanShift : 0;

  /// The Ramadan [today] is in, or the next one, from the injected
  /// calendar (RAM-2); null past it, or before it's filled in.
  RamadanMonth? ramadanFor(DateTime today) => currentOrNextRamadanIn(
    today,
    months: _ramadanMonths,
    shiftFor: _shiftFor,
  );

  /// The Ramadan month [day] itself falls in, or null (RAM-2): for that
  /// day's Hijri label and for sorting its slots (RAM-1).
  RamadanMonth? ramadanMonthOf(DateTime day) =>
      ramadanMonthContaining(day, months: _ramadanMonths, shiftFor: _shiftFor);

  /// The Ramadan month Settings' shift row should show for [today]
  /// (RAM-2, should-fix): see [ramadanMonthForShiftRow].
  RamadanMonth? ramadanMonthForShiftRowAt(DateTime today) =>
      ramadanMonthForShiftRow(
        today,
        months: _ramadanMonths,
        shiftFor: _shiftFor,
      );

  /// Whether [day] is عيد الفطر, the day after some Ramadan in the
  /// calendar ends (RAM-2).
  bool isEid(DateTime day) => _ramadanMonths.any(
    (m) => dateKey(m.shifted(_shiftFor(m.hijriYear)).eid) == dateKey(day),
  );

  Future<void> _reload() async {
    _entries = await _repo.entriesBetween(
      _days.first,
      _days.last,
      ramadanMode: _ramadanMode,
      ramadanMonthFor: ramadanMonthOf,
    );
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
