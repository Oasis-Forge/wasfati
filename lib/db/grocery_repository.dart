import 'package:sqflite/sqflite.dart';

import '../models/aisles.dart';
import '../models/grocery.dart';
import '../models/quantity/parser.dart';
import '../services/ids.dart';

/// Reads and writes the grocery list (GRO-1–GRO-7). An item is a row; its
/// amounts are separate rows, so merging (GRO-3) is just attaching a new
/// amount to the right item, and the number shown is computed from them
/// (see [totalOf] in `models/grocery.dart`).
class GroceryRepository {
  GroceryRepository(this._db, {Clock? clock, IdSource? ids})
    : _clock = clock ?? systemClock,
      _ids = ids ?? uuidV4;

  final Database _db;
  final Clock _clock;
  final IdSource _ids;

  /// The database, for tests that need to reach past this repository's API.
  Database get db => _db;

  String newId() => _ids();
  DateTime now() => _clock();

  /// Live items with their live amounts: aisles in GRO-4's order, then by
  /// name (Arabic alphabetical, ORG-5's normalized-key order).
  Future<List<GroceryItem>> list() async {
    final itemRows = await _db.query(
      'grocery_items',
      where: 'deleted_at IS NULL',
    );
    final amountRows = await _db.query(
      'grocery_amounts',
      where: 'deleted_at IS NULL',
    );
    final byItem = <String, List<Map<String, Object?>>>{};
    for (final r in amountRows) {
      (byItem[r['item_id']! as String] ??= []).add(r);
    }
    final items = [
      for (final r in itemRows)
        GroceryItem.fromMap(
          r,
          amounts: (byItem[r['id']] ?? const [])
              .map(GroceryAmount.fromMap)
              .toList(),
        ),
    ];
    items.sort((a, b) {
      final aisle = a.aisle.index.compareTo(b.aisle.index);
      return aisle != 0 ? aisle : a.normName.compareTo(b.normName);
    });
    return items;
  }

  /// Merges [lines] into the list (GRO-3, PLAN-5): each joins the open (not
  /// done) item whose name matches after [groceryKey], or starts a new one.
  /// A line for water or ice is dropped (GRO-2).
  Future<void> add(List<IncomingLine> lines) async {
    final wanted = [
      for (final l in lines)
        if (!isWaterOrIce(l.name)) l,
    ];
    if (wanted.isEmpty) return;
    final now = _clock();
    await _db.transaction((tx) async {
      for (final line in wanted) {
        final itemId = await _openItemFor(tx, line.name, now);
        await tx.insert('grocery_amounts', {
          'id': _ids(),
          'item_id': itemId,
          'num': line.min?.numerator,
          'den': line.min?.denominator,
          'max_num': line.max?.numerator,
          'max_den': line.max?.denominator,
          'unit_id': line.unitId,
          'recipe_id': line.recipeId,
          'plan_entry_id': line.planEntryId,
          'created_at': now.millisecondsSinceEpoch,
          'updated_at': now.millisecondsSinceEpoch,
        });
      }
    });
  }

  /// Adds one line typed by hand (GRO-1), parsed like a recipe line.
  Future<void> addByHand(String text) async {
    final p = parseIngredient(text);
    if (p.name.trim().isEmpty) return;
    final now = _clock();
    await _db.transaction((tx) async {
      final itemId = await _openItemFor(tx, p.name, now, handAdded: true);
      await tx.insert('grocery_amounts', {
        'id': _ids(),
        'item_id': itemId,
        'num': p.min?.numerator,
        'den': p.min?.denominator,
        'max_num': p.max?.numerator,
        'max_den': p.max?.denominator,
        'unit_id': p.unitId,
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });
    });
  }

  /// Ticks or unticks an item (GRO-5): ticking moves it into "تم". Unticking
  /// can bring back a name another open item already has (e.g. it was
  /// added again while this one was done); when it does, the two are
  /// merged instead of showing the list twice (should-fix, adversary
  /// review: "untick with the same name open leaves one item").
  Future<void> setDone(String id, bool done) async {
    final now = _clock();
    await _db.transaction((tx) async {
      final c = await tx.update(
        'grocery_items',
        {
          'done_at': done ? now.millisecondsSinceEpoch : null,
          'updated_at': now.millisecondsSinceEpoch,
        },
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
      if (c != 1) throw StateError('No grocery item $id');
      if (!done) await _dedupeOpen(tx, id, now);
    });
  }

  /// If item [id] is open (not done) and another open item already has its
  /// name, merges [id]'s amounts into that other item and removes [id]:
  /// [setDone] and [restore] both call this, so unticking or an Undo never
  /// leaves two open items with the same name on the list.
  Future<void> _dedupeOpen(Transaction tx, String id, DateTime now) async {
    final rows = await tx.query(
      'grocery_items',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    if (rows.isEmpty) return; // already gone; nothing to dedupe
    final row = rows.single;
    if (row['done_at'] != null) return; // done items don't clash with open
    final key = row['norm_name']! as String;
    final others = await tx.query(
      'grocery_items',
      columns: ['id', 'hand_added'],
      where: 'norm_name = ? AND id != ? AND done_at IS NULL AND deleted_at IS NULL',
      whereArgs: [key, id],
      limit: 1,
    );
    if (others.isEmpty) return;
    final target = others.single['id']! as String;
    final ms = now.millisecondsSinceEpoch;
    await tx.update(
      'grocery_amounts',
      {'item_id': target, 'updated_at': ms},
      where: 'item_id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    if ((row['hand_added']! as int) == 1 &&
        (others.single['hand_added']! as int) == 0) {
      await tx.update(
        'grocery_items',
        {'hand_added': 1, 'updated_at': ms},
        where: 'id = ?',
        whereArgs: [target],
      );
    }
    await tx.update(
      'grocery_items',
      {'deleted_at': ms, 'updated_at': ms},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Moves an item to another aisle and remembers the choice for its name
  /// (GRO-4), so the next item with this name starts there too. Upserts in
  /// place (never `INSERT OR REPLACE`, which would delete and reinsert the
  /// row under a new ID and `created_at`, breaking BAK-3's merge-by-ID for
  /// aisle choices, should-fix, adversary review).
  Future<void> moveToAisle(String id, Aisle aisle) async {
    final now = _clock().millisecondsSinceEpoch;
    await _db.transaction((tx) async {
      final rows = await tx.query(
        'grocery_items',
        columns: ['norm_name'],
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
      if (rows.isEmpty) throw StateError('No grocery item $id');
      final key = rows.single['norm_name']! as String;
      await tx.update(
        'grocery_items',
        {'aisle': aisle.name, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      final updated = await tx.update(
        'aisle_choices',
        {'aisle': aisle.name, 'updated_at': now},
        where: 'norm_name = ?',
        whereArgs: [key],
      );
      if (updated == 0) {
        await tx.insert('aisle_choices', {
          'id': _ids(),
          'norm_name': key,
          'aisle': aisle.name,
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  /// Deleting a recipe leaves the list alone; this only runs when the user
  /// asks to remove it from "By recipe" (GRO-5, GRO-7). Soft-deletes the
  /// recipe's amounts, then any item left with no live amounts that isn't
  /// hand-added, and returns both sets of IDs for Undo (DEL-2, should-fix:
  /// "Remove" had no Undo).
  Future<({List<String> amountIds, List<String> itemIds})> removeRecipe(
    String recipeId,
  ) async {
    final now = _clock().millisecondsSinceEpoch;
    final amountIds = <String>[];
    final itemIds = <String>[];
    await _db.transaction((tx) async {
      final affected = await tx.query(
        'grocery_amounts',
        columns: ['id', 'item_id'],
        where: 'recipe_id = ? AND deleted_at IS NULL',
        whereArgs: [recipeId],
      );
      amountIds.addAll([for (final r in affected) r['id']! as String]);
      if (amountIds.isEmpty) return;
      final marks = List.filled(amountIds.length, '?').join(',');
      await tx.update(
        'grocery_amounts',
        {'deleted_at': now, 'updated_at': now},
        where: 'id IN ($marks)',
        whereArgs: amountIds,
      );
      final itemsTouched = {for (final r in affected) r['item_id']! as String};
      for (final itemId in itemsTouched) {
        final left =
            Sqflite.firstIntValue(
              await tx.rawQuery(
                'SELECT COUNT(*) FROM grocery_amounts '
                'WHERE item_id = ? AND deleted_at IS NULL',
                [itemId],
              ),
            ) ??
            0;
        if (left > 0) continue;
        final item = await tx.query(
          'grocery_items',
          columns: ['hand_added'],
          where: 'id = ? AND deleted_at IS NULL',
          whereArgs: [itemId],
        );
        if (item.isEmpty || (item.single['hand_added']! as int) == 1) {
          continue;
        }
        await tx.update(
          'grocery_items',
          {'deleted_at': now, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [itemId],
        );
        itemIds.add(itemId);
      }
    });
    return (amountIds: amountIds, itemIds: itemIds);
  }

  /// Undo for [removeRecipe] (DEL-2): brings back the amounts and any item
  /// it took out.
  Future<void> restoreRemoved(
    Iterable<String> amountIds,
    Iterable<String> itemIds,
  ) async {
    final ids = amountIds.toList();
    final items = itemIds.toList();
    if (ids.isEmpty && items.isEmpty) return;
    final now = _clock().millisecondsSinceEpoch;
    await _db.transaction((tx) async {
      if (ids.isNotEmpty) {
        final marks = List.filled(ids.length, '?').join(',');
        await tx.update(
          'grocery_amounts',
          {'deleted_at': null, 'updated_at': now},
          where: 'id IN ($marks)',
          whereArgs: ids,
        );
      }
      if (items.isNotEmpty) {
        final marks = List.filled(items.length, '?').join(',');
        await tx.update(
          'grocery_items',
          {'deleted_at': null, 'updated_at': now},
          where: 'id IN ($marks)',
          whereArgs: items,
        );
      }
    });
  }

  /// Clears the items already ticked (GRO-5) and returns their IDs, for
  /// Undo (DEL-2).
  Future<List<String>> clearDone() => _clearWhere('done_at IS NOT NULL');

  /// Clears every live item (GRO-5) and returns their IDs, for Undo (DEL-2).
  Future<List<String>> clearAll() => _clearWhere('1 = 1');

  Future<List<String>> _clearWhere(String extra) async {
    final now = _clock().millisecondsSinceEpoch;
    final rows = await _db.query(
      'grocery_items',
      columns: ['id'],
      where: 'deleted_at IS NULL AND $extra',
    );
    final ids = [for (final r in rows) r['id']! as String];
    if (ids.isEmpty) return ids;
    final marks = List.filled(ids.length, '?').join(',');
    await _db.update(
      'grocery_items',
      {'deleted_at': now, 'updated_at': now},
      where: 'id IN ($marks)',
      whereArgs: ids,
    );
    return ids;
  }

  /// Undo for [clearDone] and [clearAll] (DEL-2). A restored item that's
  /// open can also collide with one added while it was cleared; [_dedupeOpen]
  /// merges those too.
  Future<void> restore(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    final now = _clock();
    final ms = now.millisecondsSinceEpoch;
    final marks = List.filled(list.length, '?').join(',');
    await _db.transaction((tx) async {
      await tx.update(
        'grocery_items',
        {'deleted_at': null, 'updated_at': ms},
        where: 'id IN ($marks)',
        whereArgs: list,
      );
      for (final id in list) {
        await _dedupeOpen(tx, id, now);
      }
    });
  }

  /// Drops items and amounts deleted more than [days] ago (DEL-2). Run at
  /// start, with the recipe and plan trash.
  Future<void> purgeTrash({int days = 30}) async {
    final cutoff = _clock()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    await _db.transaction((tx) async {
      final old = await tx.query(
        'grocery_items',
        columns: ['id'],
        where: 'deleted_at IS NOT NULL AND deleted_at < ?',
        whereArgs: [cutoff],
      );
      for (final r in old) {
        await tx.delete(
          'grocery_amounts',
          where: 'item_id = ?',
          whereArgs: [r['id']],
        );
        await tx.delete('grocery_items', where: 'id = ?', whereArgs: [r['id']]);
      }
      // An amount can be deleted on its own (removeRecipe) while its item
      // stays live, holding other amounts.
      await tx.delete(
        'grocery_amounts',
        where: 'deleted_at IS NOT NULL AND deleted_at < ?',
        whereArgs: [cutoff],
      );
    });
  }

  /// The open (not done, not deleted) item named [name], or a new one
  /// (GRO-3): the aisle comes from a remembered choice first, else the
  /// built-in table (GRO-4).
  Future<String> _openItemFor(
    Transaction tx,
    String name,
    DateTime now, {
    bool handAdded = false,
  }) async {
    final key = groceryKey(name);
    // Oldest first, so the target is deterministic even if a dedupe
    // (_dedupeOpen) ever leaves more than one open item with this name
    // for a moment (should-fix, adversary review).
    final open = await tx.query(
      'grocery_items',
      columns: ['id'],
      where: 'norm_name = ? AND done_at IS NULL AND deleted_at IS NULL',
      whereArgs: [key],
      orderBy: 'created_at ASC',
      limit: 1,
    );
    if (open.isNotEmpty) {
      final id = open.single['id']! as String;
      if (handAdded) {
        await tx.update(
          'grocery_items',
          {'hand_added': 1, 'updated_at': now.millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await tx.update(
          'grocery_items',
          {'updated_at': now.millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      return id;
    }
    final id = _ids();
    final chosen = await tx.query(
      'aisle_choices',
      columns: ['aisle'],
      where: 'norm_name = ?',
      whereArgs: [key],
      limit: 1,
    );
    final aisle = chosen.isNotEmpty
        ? Aisle.values
                  .where((a) => a.name == chosen.single['aisle'])
                  .firstOrNull ??
              Aisle.other
        : aisleFor(name);
    await tx.insert('grocery_items', {
      'id': id,
      'name': name,
      'norm_name': key,
      'aisle': aisle.name,
      'hand_added': handAdded ? 1 : 0,
      'created_at': now.millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
    });
    return id;
  }
}
