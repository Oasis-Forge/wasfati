import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/quantity/format.dart';
import '../models/recipe.dart';
import '../services/backup.dart';
import '../services/backup_files.dart';
import '../services/recipe_pages.dart' show ShareStorage;
import '../services/sharer.dart';
import 'settings_state.dart';

/// The backup, restore and export flow (BAK-1–BAK-10): the calls into
/// [BackupService] and [BackupFiles] (plus [Sharer]/[ShareStorage] for
/// sharing, and [SettingsState] for BAK-8's `lastBackupAt`), and the flow
/// state around them — busy, the last restore's result, the last error.
/// Moved out of `settings_screen.dart` (CLAUDE.md: screens stay
/// presentational): the screen keeps only the UI itself — the buttons, the
/// two-step "استبدال" confirmation (BAK-7), the progress indicator, and
/// picking a message for whatever this state reports.
class BackupState extends ChangeNotifier {
  BackupState({
    required BackupService backup,
    required BackupFiles files,
    required Sharer sharer,
    required ShareStorage shareStorage,
    required SettingsState settings,
    // Named parameters can't be private, so `this._field` isn't available
    // here (same as BackupService's own constructor, services/backup.dart).
  }) : _backup = backup, // ignore: prefer_initializing_formals
       _files = files, // ignore: prefer_initializing_formals
       _sharer = sharer, // ignore: prefer_initializing_formals
       _shareStorage = shareStorage, // ignore: prefer_initializing_formals
       _settings = settings; // ignore: prefer_initializing_formals

  final BackupService _backup;
  final BackupFiles _files;
  final Sharer _sharer;
  final ShareStorage _shareStorage;
  final SettingsState _settings;

  bool _busy = false;
  List<AutoBackup>? _autoBackups;
  Object? _lastError;
  RestoreResult? _lastRestoreResult;

  /// True while a Save, Share, Restore or Export is in flight (wrapped in
  /// [guarded]), so the screen can disable its rows and show the progress
  /// indicator — the same single flag the screen used to keep locally.
  bool get busy => _busy;

  /// The automatic backups (BAK-2, BAK-7), newest first; null until
  /// [loadAutoBackups] has run once.
  List<AutoBackup>? get autoBackups => _autoBackups;

  /// What the last action threw, if anything (cleared on the next
  /// successful [guarded] action).
  Object? get lastError => _lastError;

  /// The last restore's per-table counts (BAK-3), for a test or a screen
  /// that wants them without re-reading the dialog.
  RestoreResult? get lastRestoreResult => _lastRestoreResult;

  /// Runs one backup action at a time (BAK-7's flow, several confirmation
  /// dialogs included), so a second tap can't overlap it. Busy for the
  /// WHOLE [action], not just its own engine calls — exactly as the
  /// screen's own former `_guarded` was — because the caller's [action]
  /// closure is what shows dialogs and waits on the user mid-flow.
  Future<void> guarded(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await action();
      _lastError = null;
    } catch (e) {
      _lastError = e;
      rethrow; // the screen still needs the exception itself to pick a message
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> loadAutoBackups() async {
    _autoBackups = await _backup.automaticBackups();
    notifyListeners();
  }

  /// The injected clock (BAK-8), shared with [BackupService.now].
  DateTime now() => _backup.now();

  // ---------------------------------------------------------------------
  // BAK-1, BAK-6, BAK-8: Save and Share.
  // ---------------------------------------------------------------------

  /// Creates a backup and saves it through the system's dialog (BAK-1,
  /// BAK-6). True if actually saved (false if the user cancelled);
  /// [SettingsState.settings.lastBackupAt] moves only on a real save
  /// (BAK-8). Exceptions propagate — the caller shows its own message.
  Future<bool> save() async {
    final bytes = await _backup.createBackup();
    final now = _backup.now();
    final saved = await _files.saveBytes(
      backupFileName(now),
      bytes,
      backupMimeType,
    );
    if (saved) {
      await _settings.update(_settings.settings.copyWith(lastBackupAt: now));
    }
    return saved;
  }

  /// BAK-6: shares the same zip [save] would save, written first to the
  /// share cache ([ShareStorage.pagesDir], SHARE-4), then handed to the
  /// share sheet. Sharing is the other way a backup can leave the phone
  /// (principle 2), so it counts as "the last backup" (BAK-8) too.
  Future<void> share() async {
    final bytes = await _backup.createBackup();
    final dir = await _shareStorage.pagesDir();
    await dir.create(recursive: true);
    final now = _backup.now();
    final file = File(p.join(dir.path, backupFileName(now)));
    await file.writeAsBytes(bytes);
    await _sharer.shareFiles([file.path]);
    await _settings.update(_settings.settings.copyWith(lastBackupAt: now));
  }

  // ---------------------------------------------------------------------
  // BAK-4, BAK-7: restoring.
  // ---------------------------------------------------------------------

  /// Opens the system's file picker (BAK-7). Throws [BackupFilesError] if
  /// the platform picker itself failed; null if the user cancelled.
  Future<List<int>?> openFile() => _files.openFile();

  /// A previous automatic backup's own bytes (BAK-2, BAK-7).
  Future<List<int>> readAutoBackup(AutoBackup auto) =>
      File(auto.path).readAsBytes();

  /// Counts to preview before restoring [bytes] (BAK-7). Throws
  /// [BackupError] for a file that isn't a Wasfati backup, is damaged, or
  /// is from a newer schema (BAK-4); nothing is changed either way.
  Future<BackupPreview> inspect(List<int> bytes) => _backup.inspect(bytes);

  /// Restores [bytes] (BAK-3, BAK-7) and reloads [autoBackups] afterward —
  /// an automatic backup lives only in this phone's own storage (BAK-9), so
  /// restoring is never itself a copy that left the phone (should-fix,
  /// platform review): only [save] and [share] count as "the last backup"
  /// for BAK-8's reminder. The caller still reloads every OTHER state that
  /// reads this data (recipes, plan, groceries, settings) — this only
  /// touches what [BackupService] and [BackupFiles] own.
  Future<RestoreResult> finishRestore(
    List<int> bytes, {
    required RestoreMode mode,
  }) async {
    final result = await _backup.restore(bytes, mode: mode);
    _lastRestoreResult = result;
    await loadAutoBackups();
    return result;
  }

  // ---------------------------------------------------------------------
  // BAK-10: export.
  // ---------------------------------------------------------------------

  /// All of [recipes], or one cookbook's, as text (BAK-10).
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
  }) => _backup.exportText(
    recipes,
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
  );

  /// Saves [bytes] through the system's dialog (BAK-10); true if actually
  /// saved.
  Future<bool> exportBytes(String name, List<int> bytes, String mimeType) =>
      _files.saveBytes(name, bytes, mimeType);
}
