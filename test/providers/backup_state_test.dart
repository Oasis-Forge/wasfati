// BackupState (BAK-1–BAK-10): the flow the Settings screen used to keep in
// its own State fields, now a ChangeNotifier (CLAUDE.md: screens stay
// presentational). Rule IDs are cited per test.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/providers/backup_state.dart';
import 'package:wasfati/providers/settings_state.dart';
import 'package:wasfati/services/backup.dart';
import 'package:wasfati/services/backup_files.dart';
import 'package:wasfati/services/recipe_pages.dart';
import 'package:wasfati/services/sharer.dart';

import '../helpers.dart';

/// A [BackupState] wired to a real [BackupService] fixture, plain fakes for
/// everything else — matching how `main.dart`/`pumpApp` build one. Also
/// creates a temp share directory, deleted with the rest of [fixture] by
/// [_Wired.dispose].
class _Wired {
  _Wired(
    this.state,
    this.fixture,
    this.settings,
    this.files,
    this.sharer,
    this._shareDir,
  );

  final BackupState state;
  final BackupFixture fixture;
  final SettingsState settings;
  final NoopBackupFiles files;
  final NoopSharer sharer;
  final Directory _shareDir;

  Future<void> dispose() async {
    await fixture.dispose();
    if (_shareDir.existsSync()) _shareDir.deleteSync(recursive: true);
  }
}

Future<_Wired> _wired() async {
  final fixture = await testBackupFixture();
  final settings = SettingsState(fixture.db);
  await settings.load();
  final files = NoopBackupFiles();
  final sharer = NoopSharer();
  final shareDir = Directory.systemTemp.createTempSync(
    'wasfati_backup_state_test',
  );
  final state = BackupState(
    backup: fixture.backup,
    files: files,
    sharer: sharer,
    shareStorage: FakeShareStorage(shareDir),
    settings: settings,
  );
  return _Wired(state, fixture, settings, files, sharer, shareDir);
}

void main() {
  test(
    'save (BAK-1, BAK-6, BAK-8): saves a zip and sets lastBackupAt',
    () async {
      final w = await _wired();
      await w.fixture.recipes.save(kabsa(w.fixture.recipes));
      expect(w.state.busy, isFalse);
      expect(w.settings.settings.lastBackupAt, isNull);

      final saved = await w.state.save();

      expect(saved, isTrue);
      expect(w.files.saved, hasLength(1));
      expect(w.files.saved.single.name, endsWith('.zip'));
      expect(w.files.saved.single.mimeType, backupMimeType);
      expect(w.settings.settings.lastBackupAt, isNotNull);
      await w.dispose();
    },
  );

  test('share (BAK-6, BAK-8): shares a zip through Sharer and sets '
      'lastBackupAt', () async {
    final w = await _wired();
    await w.fixture.recipes.save(kabsa(w.fixture.recipes));

    await w.state.share();

    expect(w.sharer.filePaths, hasLength(1));
    expect(w.sharer.filePaths.single.single, endsWith('.zip'));
    expect(w.settings.settings.lastBackupAt, isNotNull);
    await w.dispose();
  });

  test('finishRestore (BAK-2, BAK-3, BAK-9): keeps the result and reloads '
      'autoBackups, without touching lastBackupAt', () async {
    final w = await _wired();
    await w.fixture.recipes.save(kabsa(w.fixture.recipes));
    final bytes = await w.fixture.backup.createBackup();

    expect(w.state.autoBackups, isNull);
    final result = await w.state.finishRestore(bytes, mode: RestoreMode.merge);

    expect(w.state.lastRestoreResult, result);
    expect(w.state.autoBackups, isNotNull); // reloaded by the restore
    // BAK-9: an automatic backup never leaves the phone, so restoring is
    // never itself "the last backup" — only save/share touch it.
    expect(w.settings.settings.lastBackupAt, isNull);
    await w.dispose();
  });

  test('guarded (BAK-7): stays busy for the whole action, and a second call '
      'while busy is a no-op', () async {
    final w = await _wired();
    final started = Completer<void>();
    final release = Completer<void>();

    final future = w.state.guarded(() async {
      started.complete();
      await release.future;
    });
    await started.future;
    expect(w.state.busy, isTrue);

    // One action at a time (BAK-7's flow), so a second tap can't overlap
    // the first.
    var secondRan = false;
    await w.state.guarded(() async => secondRan = true);
    expect(secondRan, isFalse);

    release.complete();
    await future;
    expect(w.state.busy, isFalse);
    await w.dispose();
  });

  test('guarded (BAK-7): an exception is kept as lastError and still '
      'propagates to the caller', () async {
    final w = await _wired();
    await expectLater(
      w.state.guarded(() async => throw StateError('boom')),
      throwsStateError,
    );
    expect(w.state.lastError, isA<StateError>());
    expect(w.state.busy, isFalse); // the finally still clears it
    await w.dispose();
  });
}
