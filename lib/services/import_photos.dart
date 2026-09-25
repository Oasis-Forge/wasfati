import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Pictures for a photo import (IMP-1, IMP-10, IMP-12): a cookbook page, a
/// handwritten recipe, or a screenshot of a post whose caption can't be
/// read. Both come through the system camera and photo picker, so the app
/// declares no `CAMERA` permission (RUN-2).
abstract interface class ImportPhotoPicker {
  /// One photo from the camera; empty if the user cancelled.
  Future<List<Uint8List>> camera();

  /// Up to [max] photos from the gallery, in the order picked; empty if the
  /// user cancelled. An older system picker may ignore [max], so the caller
  /// still keeps only the first [max].
  Future<List<Uint8List>> gallery({required int max});
}

/// The default in tests: returns [next] for either source (or nothing), and
/// records each call as `camera` or `gallery:<max>`.
class NoopImportPhotoPicker implements ImportPhotoPicker {
  List<Uint8List> next = const [];
  final calls = <String>[];

  @override
  Future<List<Uint8List>> camera() async {
    calls.add('camera');
    return next;
  }

  @override
  Future<List<Uint8List>> gallery({required int max}) async {
    calls.add('gallery:$max');
    return next;
  }
}

/// The real picker, over `image_picker`; built only in `main.dart`. The
/// system picker scales each picture down to 1600 px on the device first
/// (and turns HEIC into JPEG); `resizeForImport` then makes sure of
/// IMP-10's size and JPEG quality before anything is sent.
class DeviceImportPhotoPicker implements ImportPhotoPicker {
  DeviceImportPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  static const _side = 1600.0;

  @override
  Future<List<Uint8List>> camera() async {
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _side,
        maxHeight: _side,
      );
      return shot == null ? const [] : [await shot.readAsBytes()];
    } on PlatformException {
      return const []; // no camera app on this phone
    }
  }

  @override
  Future<List<Uint8List>> gallery({required int max}) async {
    if (max < 1) return const [];
    try {
      // image_picker's multi-select needs a limit of at least 2.
      final picked = max == 1
          ? [
              ?await _picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: _side,
                maxHeight: _side,
              ),
            ]
          : await _picker.pickMultiImage(
              maxWidth: _side,
              maxHeight: _side,
              limit: max,
            );
      return [for (final file in picked) await file.readAsBytes()];
    } on PlatformException {
      return const [];
    }
  }
}
