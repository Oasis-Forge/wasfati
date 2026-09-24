import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Why an import failed; each has a translated message (SRV-7 style).
enum ImportFailure { invalidUrl, unreachable, noRecipe }

class ImportException implements Exception {
  const ImportException(this.failure);
  final ImportFailure failure;
  @override
  String toString() => 'ImportException($failure)';
}

/// IMP-2, IMP-3's routing: whether a device-first failure means the link
/// should be retried through AI import (`Importer.fromAi`) instead of
/// shown as a dead end. Only a genuinely invalid link isn't retried —
/// a page with no recipe data, and one the device couldn't fetch at all
/// (many social apps block a plain page fetch), both become an AI import
/// attempt, same as a social link or pasted text (IMP-3).
bool needsAiImport(ImportFailure failure) =>
    failure != ImportFailure.invalidUrl;

/// Fetches a page and its photo straight from the recipe's site (IMP-2):
/// nothing goes through our server.
abstract interface class PageFetcher {
  Future<String> page(Uri url);
  Future<Uint8List?> image(Uri url);
}

/// The real fetcher; built only in `main.dart`.
class DeviceFetcher implements PageFetcher {
  DeviceFetcher([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 20);
  static const _maxPage = 5 * 1024 * 1024;
  static const _headers = {
    'user-agent':
        'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/140.0 Mobile Safari/537.36',
    'accept-language': 'ar,en;q=0.8',
  };

  @override
  Future<String> page(Uri url) async {
    try {
      final r = await _client.get(url, headers: _headers).timeout(_timeout);
      if (r.statusCode >= 400 || r.bodyBytes.length > _maxPage) {
        throw const ImportException(ImportFailure.unreachable);
      }
      // Recipe sites are UTF-8 even when they forget to say so.
      return utf8.decode(r.bodyBytes, allowMalformed: true);
    } on ImportException {
      rethrow;
    } catch (_) {
      throw const ImportException(ImportFailure.unreachable);
    }
  }

  @override
  Future<Uint8List?> image(Uri url) async {
    try {
      final r = await _client.get(url, headers: _headers).timeout(_timeout);
      return r.statusCode == 200 ? r.bodyBytes : null;
    } catch (_) {
      return null; // a recipe without its photo is still a recipe
    }
  }
}

/// Resizes to at most 1600 px on the long side and encodes JPEG 85 (REC-8),
/// in a background isolate so the screen doesn't stall.
Future<Uint8List?> resizeForRecipe(Uint8List bytes) =>
    _resizeToJpeg(bytes, quality: 85);

/// A photo import's picture before it leaves the device (IMP-10): at most
/// 1600 px on the long side, JPEG quality 80. Null when [bytes] isn't an
/// image the device can read, so nothing is sent.
Future<Uint8List?> resizeForImport(Uint8List bytes) =>
    _resizeToJpeg(bytes, quality: 80);

Future<Uint8List?> _resizeToJpeg(Uint8List bytes, {required int quality}) =>
    Isolate.run(() {
      img.Image? decoded;
      try {
        decoded = img.decodeImage(bytes);
      } catch (_) {
        // A few bytes that aren't an image can throw inside a format
        // sniffer rather than return null; either way it's "not an image".
        return null;
      }
      if (decoded == null) return null;
      // A camera photo is often stored sideways with an EXIF turn; the
      // pixels are turned upright here, so the server reads the page the
      // right way up and the recipe photo never depends on the tag.
      final upright = img.bakeOrientation(decoded);
      final long = upright.width > upright.height
          ? upright.width
          : upright.height;
      final out = long > 1600
          ? img.copyResize(
              upright,
              width: upright.width >= upright.height ? 1600 : null,
              height: upright.height > upright.width ? 1600 : null,
            )
          : upright;
      // IMP-10, SRV-9: nothing but the pixels leaves the device or reaches
      // a saved recipe photo. A camera photo's EXIF can carry where it was
      // taken (GPS) and the phone's make and model, and the decoder hands
      // it through to the encoder; the turn it held is already in the
      // pixels above, so dropping it loses nothing.
      out.exif = img.ExifData();
      return Uint8List.fromList(img.encodeJpg(out, quality: quality));
    });

/// Saves an imported photo into the app's private photo folder (REC-8).
Future<String?> saveImportedPhoto(String recipeId, Uint8List bytes) async {
  final jpeg = await resizeForRecipe(bytes);
  if (jpeg == null) return null;
  final dir = Directory(
    p.join((await getApplicationSupportDirectory()).path, 'photos'),
  );
  await dir.create(recursive: true);
  final file = File(
    p.join(dir.path, '$recipeId-${DateTime.now().millisecondsSinceEpoch}.jpg'),
  );
  await file.writeAsBytes(jpeg);
  return file.path;
}

/// Text and links shared into Wasfati from other apps (IMP-1, S4).
abstract interface class ShareInbox {
  /// What the app was opened with, if it was opened by a share.
  Future<String?> initial();

  /// Shares that arrive while the app is running.
  Stream<String> get incoming;

  /// Clears a handled share, so it isn't delivered again (S4 traps).
  Future<void> reset();
}

class NoopShareInbox implements ShareInbox {
  const NoopShareInbox();
  @override
  Future<String?> initial() async => null;
  @override
  Stream<String> get incoming => const Stream.empty();
  @override
  Future<void> reset() async {}
}

/// The real inbox, over `receive_sharing_intent`; built only in `main.dart`.
class DeviceShareInbox implements ShareInbox {
  const DeviceShareInbox();

  static String? _text(List<SharedMediaFile> files) {
    for (final f in files) {
      if ((f.type == SharedMediaType.text || f.type == SharedMediaType.url) &&
          f.path.trim().isNotEmpty) {
        return f.path;
      }
    }
    return null;
  }

  @override
  Future<String?> initial() async =>
      _text(await ReceiveSharingIntent.instance.getInitialMedia());

  @override
  Stream<String> get incoming => ReceiveSharingIntent.instance
      .getMediaStream()
      .map(_text)
      .where((t) => t != null)
      .cast<String>();

  @override
  Future<void> reset() async => ReceiveSharingIntent.instance.reset();
}
