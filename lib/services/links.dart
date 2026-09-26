import 'package:flutter/services.dart';

/// Opens a recipe's source link in the phone's browser (LOOK-13: the source
/// chip on the recipe page). Behind an interface like every device service:
/// tests get [NoopLinkOpener], and only `main.dart` builds [DeviceLinkOpener].
abstract interface class LinkOpener {
  /// True when something opened [url]; false when nothing could (no
  /// browser), so the caller can say so.
  Future<bool> open(Uri url);
}

/// The default in tests: opens nothing, records every link it was asked
/// to open, and answers [opens].
class NoopLinkOpener implements LinkOpener {
  NoopLinkOpener({this.opens = true});

  bool opens;
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return opens;
  }
}

/// The real opener; built only in `main.dart`. A few lines of platform glue
/// in `MainActivity.kt` rather than a package, like the mail draft
/// (Decision 19): an `ACTION_VIEW` intent for an http(s) link. No
/// permission (RUN-2) and no `<queries>` entry, since nothing is looked up
/// before the intent starts.
class DeviceLinkOpener implements LinkOpener {
  const DeviceLinkOpener();

  static const _channel = MethodChannel('com.oasisforge.wasfati/links');

  @override
  Future<bool> open(Uri url) async {
    // Only web links: a stored source URL is never a way to start some
    // other app's intent.
    if (url.scheme != 'http' && url.scheme != 'https') return false;
    try {
      final opened = await _channel.invokeMethod<bool>('open', {
        'url': url.toString(),
      });
      return opened ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
