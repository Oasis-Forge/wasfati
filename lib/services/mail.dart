import 'package:flutter/services.dart';

/// The only email address the app ever shows or writes to (CLAUDE.md):
/// "Report a mistake" (IMP-8) and any other contact link.
const supportEmail = 'oasisforge.support@gmail.com';

/// The body of a "Report a mistake" mail (IMP-8, Decision 19): the import's
/// source link, when it had one, and the user's note, when they wrote one —
/// nothing else, ever. Not the recipe, not a photo, not a caption. A photo
/// or pasted-text import has no link, so its report is just the note.
String mistakeReportBody({String? sourceUrl, String? note}) => [
  if (sourceUrl != null && sourceUrl.trim().isNotEmpty) sourceUrl.trim(),
  if (note != null && note.trim().isNotEmpty) note.trim(),
].join('\n\n');

/// Opens the user's own mail app with a draft they read and send themselves
/// (IMP-8, Decision 19). Nothing goes through our server.
abstract interface class MailComposer {
  /// False when no mail app could open the draft.
  Future<bool> compose({
    required String to,
    required String subject,
    required String body,
  });
}

/// One draft a [MailComposer] fake was asked to open.
typedef MailDraft = ({String to, String subject, String body});

/// The default in tests: opens nothing, records every draft, and answers
/// [opens] (false stands in for a phone with no mail app).
class NoopMailComposer implements MailComposer {
  NoopMailComposer({this.opens = true});

  bool opens;
  final drafts = <MailDraft>[];

  @override
  Future<bool> compose({
    required String to,
    required String subject,
    required String body,
  }) async {
    drafts.add((to: to, subject: subject, body: body));
    return opens;
  }
}

/// The real composer; built only in `main.dart`. A few lines of platform
/// glue in `MainActivity.kt` rather than a package (docs/STACK_NOTES.md):
/// an `ACTION_SENDTO` `mailto:` intent, which only mail apps answer. It
/// needs no Android permission (RUN-2) and no `<queries>` entry, since
/// nothing is looked up before the intent starts.
class DeviceMailComposer implements MailComposer {
  const DeviceMailComposer();

  static const _channel = MethodChannel('com.oasisforge.wasfati/mail');

  @override
  Future<bool> compose({
    required String to,
    required String subject,
    required String body,
  }) async {
    try {
      final opened = await _channel.invokeMethod<bool>('compose', {
        'to': to,
        'subject': subject,
        'body': body,
      });
      return opened ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
