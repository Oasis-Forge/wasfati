import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

/// The system's save-to and open dialogs for backups and exports (BAK-6,
/// BAK-7, BAK-10). The real implementation is backed by Android's Storage
/// Access Framework, so the user picks Drive, Files or any folder, and the
/// app never asks for a storage permission (RUN-2).
abstract interface class BackupFiles {
  /// Opens the system's "save to" dialog for [bytes] suggested as [name]
  /// (with [mimeType]). True if the user saved it somewhere, false if they
  /// cancelled. Throws [BackupFilesError] if the platform couldn't complete
  /// the save at all.
  Future<bool> saveBytes(String name, List<int> bytes, String mimeType);

  /// Opens the system's file picker. The picked file's bytes, or null if
  /// the user cancelled. Throws [BackupFilesError] if the platform picker
  /// itself failed to hand back a file (must-fix, platform review).
  Future<List<int>?> openFile();
}

/// Thrown by [BackupFiles.saveBytes] and [BackupFiles.openFile] when the
/// platform dialog itself fails (a provider hand-off it couldn't finish),
/// as opposed to returning false/null for "the user cancelled". The caller
/// shows a translated message rather than letting this escape unhandled
/// (must-fix, platform review).
class BackupFilesError implements Exception {
  const BackupFilesError();
}

/// The default in tests: no dialog opens. Every [saveBytes] call is
/// recorded in [saved]; [nextOpen] is what the next [openFile] returns.
class NoopBackupFiles implements BackupFiles {
  final saved = <({String name, List<int> bytes, String mimeType})>[];
  List<int>? nextOpen;

  @override
  Future<bool> saveBytes(String name, List<int> bytes, String mimeType) async {
    saved.add((name: name, bytes: bytes, mimeType: mimeType));
    return true;
  }

  @override
  Future<List<int>?> openFile() async => nextOpen;
}

/// The real dialogs, over `flutter_file_dialog`; built only in `main.dart`.
///
/// Chosen for RUN-2: its Android manifest declares no `<uses-permission>` at
/// all (checked in the pub cache before adding it), because it opens
/// Android's own Storage Access Framework pickers instead of touching
/// external storage directly. `file_picker` was the other candidate; at the
/// version available here it ships no Android manifest of its own either,
/// but `flutter_file_dialog` also covers the save dialog with the same
/// no-permission guarantee in one package, so there's one plugin for both
/// halves of BAK-6/BAK-7 instead of two.
class DeviceBackupFiles implements BackupFiles {
  const DeviceBackupFiles();

  @override
  Future<bool> saveBytes(String name, List<int> bytes, String mimeType) async {
    try {
      final saved = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          data: Uint8List.fromList(bytes),
          fileName: name,
          mimeTypesFilter: [mimeType],
        ),
      );
      return saved != null;
    } on PlatformException {
      throw const BackupFilesError();
    }
  }

  @override
  Future<List<int>?> openFile() async {
    final String? path;
    try {
      path = await FlutterFileDialog.pickFile(
        // No extension or narrow MIME filter (must-fix, platform review):
        // `fileExtensionsFilter` makes the plugin itself refuse (with a
        // PlatformException, not a null "cancelled") any file whose name
        // doesn't end in exactly `.zip`, and a single `application/zip`
        // filter greys out real backups a provider reports under a
        // different MIME type (Drive often uses
        // `application/x-zip-compressed` for zips uploaded from Windows).
        // `BackupService.inspect`'s own PK-signature check already tells a
        // genuine non-zip file apart (BackupErrorKind.notAZip).
        params: const OpenFileDialogParams(
          mimeTypesFilter: [
            'application/zip',
            'application/x-zip-compressed',
            'application/octet-stream',
          ],
        ),
      );
    } on PlatformException {
      throw const BackupFilesError();
    }
    if (path == null) return null;
    try {
      return await File(path).readAsBytes();
    } finally {
      // The plugin copies the picked file into the app's cache before
      // handing back this path (`copyFileToCacheDir`, on by default) and
      // never removes it on its own (must-fix, platform review): clean up
      // the whole per-pick folder now that the bytes are read.
      final dir = File(path).parent;
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }
}
