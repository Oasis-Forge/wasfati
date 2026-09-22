// The backup engine (BAK-1–BAK-10): one zip holding backup.json and a
// photos/ folder, over the database, the photos directory and a clock.
// Nothing here reaches the network (principle 2): a backup is written or
// read only when the caller hands it bytes, through the system's own save
// and open dialogs (services/backup_files.dart).
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../db/db_helper.dart';
import '../models/plan.dart' show dateFromKey, dateKey, weekStartFor;
import '../models/quantity/arabic_text.dart' show normalizeArabic;
import '../models/quantity/format.dart';
import '../models/recipe.dart';
import '../models/recipe_share.dart';
import '../models/settings.dart';
import 'ids.dart';

/// The record tables a backup carries (BAK-6), parents before children so a
/// restore can insert in this order with foreign keys on. `meta` is handled
/// separately (only `settings` and `install_id`; `cook_progress` is
/// transient and never backed up).
const _tableOrder = [
  'recipes',
  'cookbooks',
  'tags',
  'sections',
  'ingredient_lines',
  'steps',
  'cookbook_recipes',
  'recipe_tags',
  'plan_entries',
  'grocery_items',
  'grocery_amounts',
  'aisle_choices',
];

/// The same tables, children before parents, so a **replace** can hard-clear
/// every one of them without a foreign-key violation.
const _deleteOrder = [
  'ingredient_lines',
  'steps',
  'cookbook_recipes',
  'recipe_tags',
  'plan_entries',
  'sections',
  'grocery_amounts',
  'aisle_choices',
  'recipes',
  'cookbooks',
  'tags',
  'grocery_items',
];

/// The user-facing tables (BAK-3, DEL-1): the ones a restore's result
/// counts to the user. The rest (sections, ingredient lines, steps, links,
/// amounts, aisle choices) are structure the user never asked about
/// directly, so they'd only make "Added 14" read as noise for a one-recipe
/// restore (should-fix, platform review).
const _userFacingTables = {
  'recipes',
  'cookbooks',
  'plan_entries',
  'grocery_items',
};

/// `wasfati-backup-YYYY-MM-DD.zip` (BAK-1, BAK-6), on [createdAt]'s local
/// calendar date (DATE-1): [createdAt] is always UTC (the app's clock), so
/// this converts it itself rather than trust every caller to remember
/// (should-fix, platform review: a backup made after local midnight but
/// before UTC midnight, or the reverse, used to carry the wrong date).
String backupFileName(DateTime createdAt) {
  final local = createdAt.toLocal();
  return 'wasfati-backup-'
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}.zip';
}

const backupMimeType = 'application/zip';

/// A clear divider between recipes in [BackupService.exportText] (BAK-10).
const exportDivider = '──────────';

/// Why [BackupService.inspect] or [BackupService.restore] refused a file
/// (BAK-4, BAK-7). In every case the file changes nothing.
enum BackupErrorKind {
  /// The bytes aren't a zip archive at all.
  notAZip,

  /// A zip, but not a Wasfati backup: no `backup.json`, or a different
  /// `"app"` value in it.
  notWasfati,

  /// `backup.json` couldn't be parsed as JSON, is missing a field a backup
  /// must have, or has one in a shape this reader doesn't understand (a
  /// table that isn't a list of rows, a date that doesn't parse, and so on;
  /// must-fix, several reviews: this used to escape as a raw TypeError or
  /// FormatException instead of a message the screen could show).
  damagedJson,

  /// The backup's schema is newer than this app understands (BAK-4): the
  /// app needs to be updated first.
  newerSchema,
}

/// Thrown by [BackupService.inspect] and [BackupService.restore]; the
/// caller shows a message from [kind] (translated, LANG-2).
class BackupError implements Exception {
  const BackupError(this.kind, {this.foundSchemaVersion});

  final BackupErrorKind kind;

  /// Set only for [BackupErrorKind.newerSchema]: the schema version the
  /// file was made at.
  final int? foundSchemaVersion;

  @override
  String toString() =>
      'BackupError($kind, foundSchemaVersion: $foundSchemaVersion)';
}

/// Counts to show before a restore (BAK-7): "١٢٠ وصفة، ٤ كتب طبخ، ٣ أسابيع
/// في الخطة". Deleted rows (DEL-1) are never counted (ORG-7).
class BackupPreview {
  const BackupPreview({
    required this.recipeCount,
    required this.cookbookCount,
    required this.planWeeks,
    required this.groceryItemCount,
    required this.schemaVersion,
    required this.createdAt,
  });

  final int recipeCount;
  final int cookbookCount;

  /// The number of distinct calendar weeks the file's live plan entries
  /// fall in.
  final int planWeeks;
  final int groceryItemCount;
  final int schemaVersion;
  final DateTime createdAt;
}

/// Merge or replace (BAK-7).
enum RestoreMode { merge, replace }

/// How many rows one table gained from a restore (BAK-3).
class TableMergeCount {
  const TableMergeCount({this.added = 0, this.updated = 0, this.unchanged = 0});

  final int added;
  final int updated;
  final int unchanged;

  TableMergeCount operator +(TableMergeCount o) => TableMergeCount(
    added: added + o.added,
    updated: updated + o.updated,
    unchanged: unchanged + o.unchanged,
  );

  @override
  bool operator ==(Object other) =>
      other is TableMergeCount &&
      other.added == added &&
      other.updated == updated &&
      other.unchanged == unchanged;

  @override
  int get hashCode => Object.hash(added, updated, unchanged);

  @override
  String toString() =>
      'TableMergeCount(added: $added, updated: $updated, unchanged: $unchanged)';
}

/// What a restore did (BAK-3), per table and in total.
class RestoreResult {
  const RestoreResult(this.perTable, this.mode);

  final Map<String, TableMergeCount> perTable;
  final RestoreMode mode;

  /// Every table, structure included. Kept for tests that check a specific
  /// table; the user-facing dialog uses [userFacing] instead (DEL-1,
  /// should-fix: this used to be what the dialog showed, so restoring one
  /// recipe reported "10 unchanged" for its sections, lines and steps).
  TableMergeCount get total =>
      perTable.values.fold(const TableMergeCount(), (a, b) => a + b);

  /// Recipes, cookbooks, plan entries and grocery items only: what the
  /// result dialog shows, so the numbers match what the preview sheet
  /// promised (should-fix, platform review).
  TableMergeCount get userFacing => [
    for (final e in perTable.entries)
      if (_userFacingTables.contains(e.key)) e.value,
  ].fold(const TableMergeCount(), (a, b) => a + b);
}

/// One automatic backup (BAK-2), kept in `<app support>/backups/`.
class AutoBackup {
  const AutoBackup({required this.path, required this.createdAt});
  final String path;
  final DateTime createdAt;
}

/// BAK-8: with at least 10 recipes and no backup in the last 30 days (or
/// ever), the library shows the reminder card, unless it's snoozed or
/// turned off.
bool shouldRemindBackup(int recipeCount, DateTime now, AppSettings settings) {
  const minRecipes = 10;
  const reminderGap = Duration(days: 30);
  if (settings.backupReminderOff) return false;
  if (recipeCount < minRecipes) return false;
  final snoozedUntil = settings.backupReminderSnoozedUntil;
  if (snoozedUntil != null && now.isBefore(snoozedUntil)) return false;
  final last = settings.lastBackupAt;
  if (last == null) return true;
  return now.difference(last) >= reminderGap;
}

/// Creates, inspects and restores Wasfati backups (BAK-1–BAK-10), over the
/// database, the app's private photos folder and a clock. Every restore
/// runs in one transaction: a failure changes nothing.
class BackupService {
  BackupService(
    this._db, {
    required DatabaseFactory factory,
    required Directory photosDir,
    required Directory backupsDir,
    required String appVersion,
    Clock? clock,
    IdSource? ids,
    // Named parameters can't be private, so `this._field` (the lint's own
    // fix) isn't available here; these stay explicit assignments.
  }) : _factory = factory, // ignore: prefer_initializing_formals
       _photosDir = photosDir, // ignore: prefer_initializing_formals
       _backupsDir = backupsDir, // ignore: prefer_initializing_formals
       _appVersion = appVersion, // ignore: prefer_initializing_formals
       _clock = clock ?? systemClock,
       _ids = ids ?? uuidV4;

  final Database _db;
  final DatabaseFactory _factory;
  final Directory _photosDir;
  final Directory _backupsDir;
  final String _appVersion;
  final Clock _clock;
  final IdSource _ids;

  static const appId = 'wasfati';

  /// BAK-7: how many automatic backups (BAK-2) are kept.
  static const keepAutoBackups = 3;

  /// The injected clock (BAK-8), so the screens that decide when to remind
  /// or label a backup share the same "now" a test's [Clock] controls,
  /// instead of each reaching for [DateTime.now] on its own.
  DateTime now() => _clock();

  // ---------------------------------------------------------------------
  // BAK-1, BAK-6: creating a backup.
  // ---------------------------------------------------------------------

  /// Builds the backup zip: `backup.json` plus a `photos/` folder holding
  /// every live recipe's photo. A trashed recipe (ORG-7) crosses only as a
  /// deletion (BAK-3): a bare tombstone with no title and no photo, per
  /// BAK-6 ("records in the trash come along only as deletions"; should-fix,
  /// platform/privacy review — this used to carry the full row and photo).
  /// Every `*_at` column is written as an ISO-8601 UTC string (BAK-5); the
  /// database itself keeps them as milliseconds, so [_tablesOf] converts
  /// back to milliseconds the moment a file is read, and nothing past that
  /// boundary needs to know the file format differs from the database.
  Future<List<int>> createBackup() async {
    final archive = Archive();
    // Must-fix, adversary review (probe P15): every table is read inside
    // one transaction, so a write landing between two reads can never
    // produce a backup whose child rows point at a parent it doesn't have.
    final snapshot = await _db.transaction((tx) async {
      final tables = <String, List<Map<String, Object?>>>{};
      for (final table in _tableOrder) {
        tables[table] = await tx.query(table);
      }
      return tables;
    });

    final exported = await _exportRecipeRows(snapshot['recipes']!, archive);
    final tables = <String, List<Map<String, Object?>>>{
      for (final entry in snapshot.entries)
        entry.key: [
          for (final row
              in entry.key == 'recipes' ? exported.rows : entry.value)
            _rowToIso(row),
        ],
    };

    final json = {
      'app': appId,
      'appVersion': _appVersion,
      'schemaVersion': DBHelper.version,
      'createdAt': _clock().toIso8601String(), // BAK-5
      'tables': tables,
      'meta': await _metaForBackup(),
      // REC-8, should-fix (adversary review P6): recipes whose photo file
      // was already missing when this backup was made, so a merge can tell
      // that apart from "the user removed the photo" and leave a winning
      // local photo alone instead of nulling it out.
      'photosMissingAtBackup': exported.missingPhotoIds,
    };
    archive.addFile(ArchiveFile.string('backup.json', jsonEncode(json)));
    return ZipEncoder().encodeBytes(archive);
  }

  /// Rewrites each live row's `photo_path` to `photos/<file name>` inside
  /// the zip (REC-8) and adds the file's bytes to [archive]. A recipe whose
  /// photo file is missing on disk is backed up with no photo, rather than
  /// failing the whole backup, and its id is returned in `missingPhotoIds`
  /// so a merge doesn't read the missing photo as an intentional removal.
  /// A trashed row (`deleted_at` set) is reduced to a tombstone: no title,
  /// no photo, nothing else a merge doesn't need to propagate the deletion.
  Future<({List<Map<String, Object?>> rows, List<String> missingPhotoIds})>
  _exportRecipeRows(List<Map<String, Object?>> rows, Archive archive) async {
    final usedNames = <String>{};
    final out = <Map<String, Object?>>[];
    final missing = <String>[];
    for (final row in rows) {
      if (row['deleted_at'] != null) {
        out.add({
          'id': row['id'],
          // 'title' has no default and is NOT NULL (db_helper.dart): a
          // tombstone still needs a value, just not the real one.
          'title': '',
          'created_at': row['created_at'],
          'updated_at': row['updated_at'],
          'deleted_at': row['deleted_at'],
        });
        continue;
      }
      final path = row['photo_path'] as String?;
      if (path == null) {
        out.add(row);
        continue;
      }
      final file = File(path);
      if (!await file.exists()) {
        out.add({...row, 'photo_path': null});
        missing.add(row['id']! as String);
        continue;
      }
      final name = _uniqueZipName(p.basename(path), usedNames);
      archive.addFile(
        ArchiveFile.bytes('photos/$name', await file.readAsBytes()),
      );
      out.add({...row, 'photo_path': 'photos/$name'});
    }
    return (rows: out, missingPhotoIds: missing);
  }

  String _uniqueZipName(String base, Set<String> used) {
    var name = base;
    var n = 1;
    while (!used.add(name)) {
      name = '${p.basenameWithoutExtension(base)}-${n++}${p.extension(base)}';
    }
    return name;
  }

  /// `settings` (the JSON string, unchanged) and `install_id`; never
  /// `cook_progress`, which is transient.
  Future<Map<String, Object?>> _metaForBackup() async {
    final rows = await _db.query(
      'meta',
      where: 'key IN (?, ?)',
      whereArgs: ['settings', 'install_id'],
    );
    final byKey = {for (final r in rows) r['key']: r['value']};
    return {'settings': byKey['settings'], 'install_id': byKey['install_id']};
  }

  // ---------------------------------------------------------------------
  // BAK-4, BAK-7: reading a backup before restoring it.
  // ---------------------------------------------------------------------

  /// Counts to show before restoring [bytes] (BAK-7). Throws
  /// [BackupError] for a file that isn't a Wasfati backup, is damaged, or
  /// is from a newer schema (BAK-4); nothing is changed either way.
  Future<BackupPreview> inspect(List<int> bytes) async {
    final opened = _openBackup(bytes);
    try {
      final tables = _tablesOf(opened.json);
      List<Map<String, Object?>> live(String table) =>
          (tables[table] ?? const []).where(_isLive).toList();

      return BackupPreview(
        recipeCount: live('recipes').length,
        cookbookCount: live('cookbooks').length,
        planWeeks: _distinctWeeks(live('plan_entries')),
        groceryItemCount: live('grocery_items').length,
        schemaVersion: opened.schemaVersion,
        createdAt: DateTime.parse(opened.json['createdAt']! as String),
      );
    } on BackupError {
      rethrow;
    } catch (_) {
      // must-fix, several reviews: a structurally odd but syntactically
      // valid backup.json (a table that isn't a list, a row that isn't a
      // map, an unparseable date) used to throw a raw TypeError or
      // FormatException here, which escaped the screen's `on BackupError`
      // handler and showed the user nothing at all.
      throw const BackupError(BackupErrorKind.damagedJson);
    }
  }

  static bool _isLive(Map<String, Object?> row) => row['deleted_at'] == null;

  static int _distinctWeeks(List<Map<String, Object?>> planEntries) {
    final weeks = <String>{};
    for (final row in planEntries) {
      final date = dateFromKey(row['date']! as String);
      weeks.add(dateKey(weekStartFor(date, DateTime.monday)));
    }
    return weeks.length;
  }

  // ---------------------------------------------------------------------
  // BAK-2, BAK-3, BAK-4, BAK-7: restoring.
  // ---------------------------------------------------------------------

  /// Restores [bytes] into the database (BAK-3, BAK-7). First saves an
  /// automatic backup of the current data (BAK-2), then merges or replaces
  /// in one transaction, so a failure partway through changes nothing —
  /// neither the database nor any photo file copied along the way. The
  /// automatic backup itself is only pruned to the newest [keepAutoBackups]
  /// once the restore below actually commits, and is deleted instead of
  /// kept if it doesn't, so a failed or repeatedly retried restore can
  /// never push out, or fail to make, a real snapshot of the data it was
  /// about to change (must-fix, adversary review P1).
  ///
  /// A backup older than [DBHelper.version] is migrated first: its rows go
  /// into a temporary database opened at the backup's own schema version,
  /// which is then reopened at the current version so the app's own schema
  /// steps run on it, exactly as a real upgrade would (BAK-4).
  Future<RestoreResult> restore(
    List<int> bytes, {
    required RestoreMode mode,
  }) async {
    final opened = _openBackup(bytes);
    Map<String, List<Map<String, Object?>>> tables;
    Map<String, Object?> meta;
    Set<String> missingPhotoIds;
    try {
      tables = _tablesOf(opened.json);
      if (opened.schemaVersion < DBHelper.version) {
        tables = await _migrateTables(tables, opened.schemaVersion);
      }
      meta = (opened.json['meta'] as Map?)?.cast<String, Object?>() ?? const {};
      missingPhotoIds =
          ((opened.json['photosMissingAtBackup'] as List?) ?? const [])
              .cast<String>()
              .toSet();
    } on BackupError {
      rethrow;
    } catch (_) {
      throw const BackupError(BackupErrorKind.damagedJson);
    }

    final autoPath = await _writeAutoBackup();

    final copiedPhotos = <String>[];
    final obsoletePhotos = <String>[];
    try {
      final result = await _db.transaction(
        (tx) => mode == RestoreMode.replace
            ? _replaceInto(
                tx,
                tables,
                meta,
                opened.archive,
                copiedPhotos,
                obsoletePhotos,
              )
            : _mergeInto(
                tx,
                tables,
                opened.archive,
                copiedPhotos,
                obsoletePhotos,
                missingPhotoIds,
              ),
      );
      await _pruneAutoBackups();
      // should-fix, adversary review (probe P8): the photo files a replace
      // or a losing merge row left behind. Only deleted on success — on
      // failure the transaction rolled back, so these paths are still what
      // the (unchanged) database points at.
      for (final path in obsoletePhotos) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
      return result;
    } catch (_) {
      for (final path in copiedPhotos) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
      final f = File(autoPath);
      if (await f.exists()) await f.delete();
      rethrow;
    }
  }

  /// Restores from one of [automaticBackups] (BAK-7).
  Future<RestoreResult> restoreAuto(
    AutoBackup auto, {
    required RestoreMode mode,
  }) => restore(File(auto.path).readAsBytesSync(), mode: mode);

  Future<RestoreResult> _replaceInto(
    Transaction tx,
    Map<String, List<Map<String, Object?>>> tables,
    Map<String, Object?> meta,
    Archive archive,
    List<String> copiedPhotos,
    List<String> obsoletePhotos,
  ) async {
    // should-fix (adversary review P8): every photo this phone currently
    // has, so replacing it can free the ones no row will point at any more
    // once the new rows are in.
    obsoletePhotos.addAll([
      for (final r in await tx.query('recipes', columns: ['photo_path']))
        if (r['photo_path'] != null) r['photo_path']! as String,
    ]);
    for (final table in _deleteOrder) {
      await tx.delete(table);
    }
    final counts = <String, TableMergeCount>{};
    for (final table in _tableOrder) {
      final rows = tables[table] ?? const [];
      var added = 0;
      var updated = 0;
      for (final raw in rows) {
        final row = table == 'recipes'
            ? await _withMaterializedPhoto(raw, archive, copiedPhotos)
            : raw;
        await tx.insert(table, row);
        // DEL-1: a tombstone that arrives with nothing local to replace it
        // still isn't a record the user added; count it with the updates
        // instead of inflating "added" (should-fix, platform review).
        if (raw['deleted_at'] != null) {
          updated++;
        } else {
          added++;
        }
      }
      counts[table] = TableMergeCount(added: added, updated: updated);
    }
    // BAK-7: replace takes the file's settings and install ID.
    if (meta['settings'] != null) {
      await tx.insert('meta', {
        'key': 'settings',
        'value': meta['settings'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    if (meta['install_id'] != null) {
      await tx.insert('meta', {
        'key': 'install_id',
        'value': meta['install_id'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    return RestoreResult(counts, RestoreMode.replace);
  }

  /// BAK-3: per table, per row by id. Missing locally → added; present →
  /// the later `updated_at` wins, deletions included (DEL-1). Merge never
  /// touches `meta`, so this phone's settings and install ID stay.
  ///
  /// `tags`, `grocery_items` and `aisle_choices` also match by their
  /// natural key (a normalized name) when the id is unknown here, because
  /// two installs give the same conceptual tag, item or aisle choice
  /// different random ids (REC-2): a plain id merge would duplicate a tag
  /// (ORG-4) or an open grocery item (GRO-3), and for `aisle_choices` — one
  /// row per name, `norm_name` UNIQUE — it would break the database outright
  /// instead of merging (must-fix, several reviews). `recipe_tags` and
  /// `grocery_amounts` follow, with the backup's tag/item id remapped to
  /// whichever local one it was matched onto.
  Future<RestoreResult> _mergeInto(
    Transaction tx,
    Map<String, List<Map<String, Object?>>> tables,
    Archive archive,
    List<String> copiedPhotos,
    List<String> obsoletePhotos,
    Set<String> missingPhotoIds,
  ) async {
    final counts = <String, TableMergeCount>{};
    final tagIdRemap = <String, String>{};
    final itemIdRemap = <String, String>{};

    for (final table in _tableOrder) {
      var added = 0;
      var updated = 0;
      var unchanged = 0;

      for (final raw0 in tables[table] ?? const []) {
        // Explicitly typed (not left to the switch expression's own
        // inference): a map literal built only from `{...raw0, k: v}` with
        // no surrounding type context can otherwise come out as
        // `Map<dynamic, dynamic>` at runtime, which `tx.insert` then
        // rejects.
        final Map<String, Object?> raw = switch (table) {
          'recipe_tags' when tagIdRemap.containsKey(raw0['tag_id']) =>
            <String, Object?>{...raw0, 'tag_id': tagIdRemap[raw0['tag_id']]},
          'grocery_amounts' when itemIdRemap.containsKey(raw0['item_id']) =>
            <String, Object?>{...raw0, 'item_id': itemIdRemap[raw0['item_id']]},
          _ => raw0,
        };
        final id = raw['id']! as String;
        final existing = await tx.query(
          table,
          where: 'id = ?',
          whereArgs: [id],
        );

        if (existing.isEmpty) {
          // A remapped `recipe_tags` row can now name a (recipe, tag) pair
          // this phone already links; don't add a second link for it.
          if (table == 'recipe_tags' && raw['tag_id'] != raw0['tag_id']) {
            final dup = await tx.query(
              table,
              where: 'recipe_id = ? AND tag_id = ? AND deleted_at IS NULL',
              whereArgs: [raw['recipe_id'], raw['tag_id']],
            );
            if (dup.isNotEmpty) {
              unchanged++;
              continue;
            }
          }

          String? localId;
          if (table == 'tags' && raw['deleted_at'] == null) {
            localId = await _matchTagId(tx, raw['name']! as String);
          } else if (table == 'grocery_items' &&
              raw['deleted_at'] == null &&
              raw['done_at'] == null) {
            localId = await _matchOpenGroceryItemId(
              tx,
              raw['norm_name']! as String,
            );
          } else if (table == 'aisle_choices') {
            localId = await _matchAisleChoiceId(
              tx,
              raw['norm_name']! as String,
            );
          }

          if (localId == null) {
            final row = table == 'recipes'
                ? await _withMaterializedPhoto(raw, archive, copiedPhotos)
                : raw;
            await tx.insert(table, row);
            if (table == 'tags') tagIdRemap[id] = id;
            if (table == 'grocery_items') itemIdRemap[id] = id;
            if (raw['deleted_at'] != null) {
              updated++;
            } else {
              added++;
            }
            continue;
          }

          // Same conceptual row, a different id: fold onto the local one
          // instead of inserting a duplicate.
          if (table == 'tags') tagIdRemap[id] = localId;
          if (table == 'grocery_items') itemIdRemap[id] = localId;
          final local = (await tx.query(
            table,
            where: 'id = ?',
            whereArgs: [localId],
          )).single;
          if ((raw['updated_at']! as int) > (local['updated_at']! as int)) {
            final patch = table == 'tags'
                ? {'name': raw['name'], 'updated_at': raw['updated_at']}
                : {'aisle': raw['aisle'], 'updated_at': raw['updated_at']};
            await tx.update(
              table,
              patch,
              where: 'id = ?',
              whereArgs: [localId],
            );
            updated++;
          } else {
            unchanged++;
          }
          continue;
        }

        final localUpdated = existing.single['updated_at']! as int;
        final backupUpdated = raw['updated_at']! as int;
        if (backupUpdated > localUpdated) {
          Map<String, Object?> row;
          if (table == 'recipes') {
            final oldPhoto = existing.single['photo_path'] as String?;
            final keepLocalPhoto =
                raw['photo_path'] == null &&
                oldPhoto != null &&
                missingPhotoIds.contains(id);
            if (keepLocalPhoto) {
              // REC-8, should-fix (adversary review P6): the backup's
              // photo was missing when it was made, not removed by the
              // user — don't let a winning row null out a photo this
              // phone still actually has.
              row = {...raw, 'photo_path': oldPhoto};
            } else {
              row = await _withMaterializedPhoto(raw, archive, copiedPhotos);
              final newPhoto = row['photo_path'] as String?;
              if (oldPhoto != null && oldPhoto != newPhoto) {
                obsoletePhotos.add(oldPhoto);
              }
            }
          } else {
            row = raw;
          }
          await tx.update(table, row, where: 'id = ?', whereArgs: [id]);
          updated++;
        } else {
          unchanged++;
        }
      }
      counts[table] = TableMergeCount(
        added: added,
        updated: updated,
        unchanged: unchanged,
      );
    }
    return RestoreResult(counts, RestoreMode.merge);
  }

  /// The id of a live local tag whose name normalizes (ORG-4) the same as
  /// [name], if any.
  Future<String?> _matchTagId(Transaction tx, String name) async {
    final key = normalizeArabic(name);
    for (final r in await tx.query('tags', where: 'deleted_at IS NULL')) {
      if (normalizeArabic(r['name']! as String) == key) {
        return r['id']! as String;
      }
    }
    return null;
  }

  /// The id of a local grocery item with this exact `norm_name` that's
  /// still open (GRO-3: only open items merge by name), if any.
  Future<String?> _matchOpenGroceryItemId(
    Transaction tx,
    String normName,
  ) async {
    final rows = await tx.query(
      'grocery_items',
      columns: ['id'],
      where: 'norm_name = ? AND done_at IS NULL AND deleted_at IS NULL',
      whereArgs: [normName],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['id']! as String;
  }

  /// The id of the local aisle choice for this exact `norm_name`, if any
  /// (the column is globally UNIQUE, so there's at most one).
  Future<String?> _matchAisleChoiceId(Transaction tx, String normName) async {
    final rows = await tx.query(
      'aisle_choices',
      columns: ['id'],
      where: 'norm_name = ?',
      whereArgs: [normName],
    );
    return rows.isEmpty ? null : rows.single['id']! as String;
  }

  /// Copies [row]'s photo (if any) into the photos folder under a fresh
  /// name and returns the row with `photo_path` pointing at it. A photo the
  /// zip doesn't have leaves `photo_path` null rather than dangling.
  Future<Map<String, Object?>> _withMaterializedPhoto(
    Map<String, Object?> row,
    Archive archive,
    List<String> copiedPhotos,
  ) async {
    final inZip = row['photo_path'] as String?;
    if (inZip == null) return row;
    final entry = archive.files.where((f) => f.name == inZip).firstOrNull;
    if (entry == null) return {...row, 'photo_path': null};
    await _photosDir.create(recursive: true);
    final name = '${_ids()}${p.extension(inZip)}';
    final file = File(p.join(_photosDir.path, name));
    await file.writeAsBytes(entry.content);
    copiedPhotos.add(file.path);
    return {...row, 'photo_path': file.path};
  }

  // ---------------------------------------------------------------------
  // BAK-2: automatic backups.
  // ---------------------------------------------------------------------

  /// Writes a new automatic backup and returns its path, without pruning
  /// (the caller prunes only once it knows the restore this snapshot is
  /// for actually succeeded).
  Future<String> _writeAutoBackup() async {
    await _backupsDir.create(recursive: true);
    final bytes = await createBackup();
    final existing = await automaticBackups();
    final newestExisting = existing.isEmpty
        ? 0
        : existing
              .map((a) => a.createdAt.millisecondsSinceEpoch)
              .reduce((a, b) => a > b ? a : b);
    final now = _clock().millisecondsSinceEpoch;
    // Must-fix, adversary review (probe P2): if the phone's clock is behind
    // the newest backup already on file, this brand-new one must still
    // sort as the newest, or the very next prune deletes it on the spot.
    final stamp = now > newestExisting ? now : newestExisting + 1;
    final finalFile = File(p.join(_backupsDir.path, 'auto-$stamp.zip'));
    // Written under a temporary name first, then renamed in place: a
    // process death or a full disk mid-write can then never leave a
    // truncated file under its final auto-*.zip name, which would sit in
    // the list, fail to open, and take a slot a good snapshot needed
    // (should-fix, adversary review P11b).
    final partFile = File('${finalFile.path}.part');
    await partFile.writeAsBytes(bytes);
    await partFile.rename(finalFile.path);
    return finalFile.path;
  }

  Future<void> _pruneAutoBackups() async {
    final all = await automaticBackups();
    for (final old in all.skip(keepAutoBackups)) {
      final f = File(old.path);
      if (await f.exists()) await f.delete();
    }
  }

  /// The automatic backups kept in `<app support>/backups/` (BAK-2, BAK-7),
  /// newest first.
  Future<List<AutoBackup>> automaticBackups() async {
    if (!await _backupsDir.exists()) return [];
    final backups = <AutoBackup>[];
    await for (final entry in _backupsDir.list()) {
      if (entry is! File) continue;
      final stem = p.basenameWithoutExtension(entry.path);
      if (!stem.startsWith('auto-') || p.extension(entry.path) != '.zip') {
        continue;
      }
      final ms = int.tryParse(stem.substring('auto-'.length));
      if (ms == null) continue;
      backups.add(
        AutoBackup(
          path: entry.path,
          createdAt: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        ),
      );
    }
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  // ---------------------------------------------------------------------
  // BAK-4: migrating an older backup's rows with the app's own schema steps.
  // ---------------------------------------------------------------------

  Future<Map<String, List<Map<String, Object?>>>> _migrateTables(
    Map<String, List<Map<String, Object?>>> oldTables,
    int fromVersion,
  ) async {
    await _backupsDir.create(recursive: true);
    final path = p.join(_backupsDir.path, 'migrate-${_ids()}.db');
    await _factory.deleteDatabase(path);
    var tmp = await DBHelper.open(
      _factory,
      path,
      upTo: fromVersion,
      singleInstance: false,
    );
    try {
      await tmp.transaction((tx) async {
        for (final table in _tableOrder) {
          for (final row in oldTables[table] ?? const []) {
            await tx.insert(table, row);
          }
        }
      });
      await tmp.close();
      // Reopening at no fixed version runs every remaining schema step, the
      // same migration a real upgrade would run (CLAUDE.md conventions).
      tmp = await DBHelper.open(_factory, path, singleInstance: false);
      final migrated = <String, List<Map<String, Object?>>>{};
      for (final table in _tableOrder) {
        migrated[table] = await tmp.query(table);
      }
      return migrated;
    } finally {
      await tmp.close();
      await _factory.deleteDatabase(path);
    }
  }

  // ---------------------------------------------------------------------
  // Opening and validating a backup file (shared by inspect and restore).
  // ---------------------------------------------------------------------

  /// Every `*_at` column, milliseconds (as the database keeps it) to ISO
  /// (BAK-5): the top-level `createdAt` was already ISO; this brings every
  /// record's own timestamps in line with it (should-fix, several reviews).
  static Map<String, Object?> _rowToIso(Map<String, Object?> row) => {
    for (final e in row.entries)
      e.key: (e.key.endsWith('_at') && e.value is int)
          ? DateTime.fromMillisecondsSinceEpoch(
              e.value! as int,
              isUtc: true,
            ).toIso8601String()
          : e.value,
  };

  /// The inverse of [_rowToIso], applied the moment a file is read so nothing
  /// past [_tablesOf] has to know the file's own format differs from the
  /// database's.
  static Map<String, Object?> _rowFromIso(Map<String, Object?> row) => {
    for (final e in row.entries)
      e.key: (e.key.endsWith('_at') && e.value is String)
          ? DateTime.parse(e.value! as String).millisecondsSinceEpoch
          : e.value,
  };

  Map<String, List<Map<String, Object?>>> _tablesOf(Map<String, Object?> json) {
    final raw = (json['tables']! as Map).cast<String, Object?>();
    return {
      for (final entry in raw.entries)
        entry.key: (entry.value! as List)
            .cast<Map<String, Object?>>()
            .map(Map<String, Object?>.from)
            .map(_rowFromIso)
            .toList(),
    };
  }

  ({Map<String, Object?> json, Archive archive, int schemaVersion}) _openBackup(
    List<int> bytes,
  ) {
    // ZipDecoder doesn't throw for bytes with no "end of central
    // directory" record (it just returns an archive with no files), so a
    // truly non-zip file is caught here by its missing `PK` signature
    // instead, before notWasfati below ever gets a chance to fire for it.
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw const BackupError(BackupErrorKind.notAZip);
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const BackupError(BackupErrorKind.notAZip);
    }
    final entry = archive.files
        .where((f) => f.name == 'backup.json')
        .firstOrNull;
    if (entry == null) throw const BackupError(BackupErrorKind.notWasfati);

    Map<String, Object?> json;
    try {
      final decoded = jsonDecode(utf8.decode(entry.content));
      if (decoded is! Map) throw const FormatException();
      json = decoded.cast<String, Object?>();
    } catch (_) {
      throw const BackupError(BackupErrorKind.damagedJson);
    }

    if (json['app'] != appId) {
      throw const BackupError(BackupErrorKind.notWasfati);
    }

    final schemaVersion = json['schemaVersion'];
    if (schemaVersion is! int) {
      throw const BackupError(BackupErrorKind.damagedJson);
    }
    if (schemaVersion > DBHelper.version) {
      throw BackupError(
        BackupErrorKind.newerSchema,
        foundSchemaVersion: schemaVersion,
      );
    }
    if (json['tables'] is! Map || json['createdAt'] is! String) {
      throw const BackupError(BackupErrorKind.damagedJson);
    }
    return (json: json, archive: archive, schemaVersion: schemaVersion);
  }

  // ---------------------------------------------------------------------
  // BAK-10: export.
  // ---------------------------------------------------------------------

  /// All of [recipes], or one cookbook's, as a single text (BAK-10): each
  /// recipe in the shared-text format (SHARE-2, [recipeShareText]), at its
  /// own remembered view (SCALE-5) and no scaling, joined by
  /// [exportDivider]. Amounts read as on screen (QTY-5), not BAK-5's plain
  /// decimals; that rule is only for `backup.json`.
  String exportText(
    List<Recipe> recipes, {
    DigitStyle digits = DigitStyle.western,
    required String ingredientsHeading,
    required String stepsHeading,
    required String footerLine,
    required String notScaledMark,
    required String Function(String line, String mark) unscaledLineText,
    required String Function(int servings) servingsLabel,
    required String Function(int minutes) prepTimeLabel,
    required String Function(int minutes) cookTimeLabel,
    required String Function(String url) sourceLabel,
  }) => recipes
      .map(
        (r) => recipeShareText(
          r,
          view: r.unitView,
          digits: digits,
          ingredientsHeading: ingredientsHeading,
          stepsHeading: stepsHeading,
          footerLine: footerLine,
          notScaledMark: notScaledMark,
          unscaledLineText: unscaledLineText,
          servingsLabel: servingsLabel,
          prepTimeLabel: prepTimeLabel,
          cookTimeLabel: cookTimeLabel,
          sourceLabel: sourceLabel,
        ),
      )
      .join('\n\n$exportDivider\n\n');
}
