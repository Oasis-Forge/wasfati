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
}

/// The default in tests: picks nothing, deletes nothing.
class NoopPhotoStore implements PhotoStore {
  const NoopPhotoStore();
  @override
  Future<String?> pickFromGallery(String recipeId) async => null;
  @override
  Future<void> delete(String path) async {}
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
}
