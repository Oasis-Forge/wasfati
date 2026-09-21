import 'package:share_plus/share_plus.dart';

/// Sends text or files through the platform share sheet, WhatsApp first
/// (GRO-6, SHARE-1–SHARE-4).
abstract interface class Sharer {
  Future<void> shareText(String text, {String? subject});
  Future<void> shareFiles(List<String> paths, {String? text});
}

/// The default in tests: shares nothing, records what it was asked to.
class NoopSharer implements Sharer {
  final texts = <String>[];
  final subjects = <String?>[];
  final filePaths = <List<String>>[];

  @override
  Future<void> shareText(String text, {String? subject}) async {
    texts.add(text);
    subjects.add(subject);
  }

  @override
  Future<void> shareFiles(List<String> paths, {String? text}) async {
    filePaths.add(paths);
    texts.add(text ?? '');
  }
}

/// The real sharer, over the `share_plus` package; built only in
/// `main.dart`. Adds no Android permission (RUN-2): `share_plus` only
/// declares a file provider, never a `<uses-permission>`.
class DeviceSharer implements Sharer {
  const DeviceSharer();

  @override
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  @override
  Future<void> shareFiles(List<String> paths, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(files: [for (final p in paths) XFile(p)], text: text),
    );
  }
}
