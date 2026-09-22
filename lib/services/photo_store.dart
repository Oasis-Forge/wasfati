import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Recipe photos (REC-8): picked with the system photo picker, resized to at
/// most 1600 px at JPEG quality 85, and kept in the app's private storage.
abstract interface class PhotoStore {
  /// Picks a photo and returns its saved path, or null if the user cancelled.
  Future<String?> pickFromGallery(String recipeId);

  /// Deletes a saved photo; a missing file is not an error.
  Future<void> delete(String path);

  /// Whether the file at [path] still exists (ORG-6, BAK-9): Android's
  /// device backup excludes `photos/` on purpose, so a restore can bring
  /// back a database row whose photo file never came along. The repair
  /// sweep (`RecipeRepository.forgetMissingPhotos`) asks this once per
  /// recipe with a `photo_path`, at app start.
  Future<bool> exists(String path);
}

/// The default in tests: picks nothing, deletes nothing, and — unless a
/// test says otherwise — claims every path still exists, so a test that
/// never touches photos never has its recipes swept out from under it.
class NoopPhotoStore implements PhotoStore {
  const NoopPhotoStore({this.missing = const {}});

  /// Paths this fake reports as gone (for the sweep's own tests).
  final Set<String> missing;

  @override
  Future<String?> pickFromGallery(String recipeId) async => null;
  @override
  Future<void> delete(String path) async {}
  @override
  Future<bool> exists(String path) async => !missing.contains(path);
}

/// The real store; built only in `main.dart`.
class DevicePhotoStore implements PhotoStore {
  DevicePhotoStore([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickFromGallery(String recipeId) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final dir = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'photos'),
    );
    await dir.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final target = p.join(dir.path, '$recipeId-$stamp.jpg');
    await File(picked.path).copy(target);
    return target;
  }

  @override
  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<bool> exists(String path) => File(path).exists();
}
