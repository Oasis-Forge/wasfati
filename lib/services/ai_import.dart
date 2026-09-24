import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/recipe_import.dart';

/// The import server's base URL (SRV-1, Decision 6). Deployed from the
/// `Oasis-Forge/wasfati-import` repo (Cloudflare Workers) — this app never
/// builds or runs that server, only calls it.
const aiImportServerUrl = 'https://wasfati-import.thepromptkitchen.workers.dev';

/// Why an AI import failed (SRV-7). Each case gets its own translated
/// message (LANG-2) — the UI never shows the server's raw text.
enum AiImportErrorKind {
  /// 400 bad_request: the app sent something the server can't use.
  badRequest,

  /// 403 invalid_integrity_token: the request wasn't trusted (SRV-4).
  invalidToken,

  /// 422 unreachable: the server has no text for that link (SRV-10).
  unreachable,

  /// 422 private_post: a platform the server can't read at all, Instagram
  /// always (Decision 8) or any other SRV-10 case (IMP-12, SRV-7) — the
  /// paste-caption fallback, same as [unreachable].
  privatePost,

  /// 422 not_a_recipe: the source isn't a recipe.
  notARecipe,

  /// 429 limit_reached: no AI imports left this month (IMP-7, SRV-4).
  /// Website import (IMP-2) still works.
  limitReached,

  /// 503 busy: the spending cap or load paused imports for everyone
  /// (SRV-6). Website import (IMP-2) still works.
  busy,

  /// 503 misconfigured: the server itself is broken, not the request.
  misconfigured,

  /// A server error code the app doesn't recognize yet (forward
  /// compatible with a code shipped after this build).
  unknown,

  /// The request never reached the server, or its answer couldn't be
  /// read: no connection, a timeout, or an unexpected response shape.
  network,
}

/// A typed outcome the UI can act on — never an exception with a string in
/// it (SRV-7). Either the parsed structure, ready for the device's own
/// parser, or a typed reason it failed.
sealed class AiImportResult {
  const AiImportResult();
}

/// The server's recipe structure (SRV-1): every ingredient line is still
/// the source's verbatim text. Nothing here has been through QTY-1 yet —
/// the caller (`Importer.fromAi`) does that, exactly like a typed or
/// website line, so amounts, units and notes always come from the device
/// (IMP-6, IMP-15, Decision 17).
class AiImportSuccess extends AiImportResult {
  const AiImportSuccess(
    this.recipe, {
    required this.model,
    required this.promptVersion,
    required this.cached,
  });

  final ImportedRecipe recipe;

  /// The model that produced this result, for debugging (SRV-1).
  final String model;

  /// The prompt version that produced this result, for debugging (SRV-1).
  final String promptVersion;

  /// Whether this was SRV-5's cache: still counts against the quota for
  /// the user (IMP-7), even though it cost us nothing.
  final bool cached;
}

class AiImportError extends AiImportResult {
  const AiImportError(this.kind, {this.message});
  final AiImportErrorKind kind;

  /// The server's own message, kept only for logs — the UI picks its own
  /// translated text from [kind] (SRV-7, LANG-2).
  final String? message;
}

/// The client side of AI import (SRV-1–SRV-11): one request per call. It
/// never retries and never caches on its own (caching is the server's job,
/// SRV-5) and never spends the quota itself — that only happens when the
/// caller later saves what comes back (IMP-7).
abstract interface class AiImportClient {
  /// Sends exactly one of [url] or [text] (IMP-1, IMP-3) for [installId]
  /// (SRV-4, `RecipeRepository.installId()`). Never throws for a server
  /// error or a network failure — both come back as [AiImportError], so
  /// the caller never needs a try/catch to read the result.
  Future<AiImportResult> import({
    required String installId,
    String? url,
    String? text,
  });
}

/// The default in tests: never touches the network. [nextResult] is
/// returned for every call unless [queue] has entries, which are returned
/// in order and removed, one per call. Every request made is recorded in
/// [requests].
class NoopAiImportClient implements AiImportClient {
  AiImportResult nextResult = const AiImportError(AiImportErrorKind.network);
  final queue = <AiImportResult>[];
  final requests = <({String installId, String? url, String? text})>[];

  @override
  Future<AiImportResult> import({
    required String installId,
    String? url,
    String? text,
  }) async {
    requests.add((installId: installId, url: url, text: text));
    return queue.isNotEmpty ? queue.removeAt(0) : nextResult;
  }
}

/// The real client, over `http`; built only in `main.dart`.
class DeviceAiImportClient implements AiImportClient {
  DeviceAiImportClient([http.Client? client])
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Generous next to IMP-4's 45 s "keep waiting" prompt, so a slow but
  /// real answer isn't cut off before the UI even offers to wait.
  static const _timeout = Duration(seconds: 60);

  @override
  Future<AiImportResult> import({
    required String installId,
    String? url,
    String? text,
  }) async {
    assert(
      (url == null) != (text == null),
      'AiImportClient.import needs exactly one of url or text',
    );
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$aiImportServerUrl/v1/import'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'install_id': installId,
              'url': ?url,
              'text': ?text,
            }),
          )
          .timeout(_timeout);
    } catch (_) {
      return const AiImportError(AiImportErrorKind.network);
    }

    Map<String, Object?> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) throw const FormatException('not an object');
      body = decoded.cast<String, Object?>();
    } catch (_) {
      return const AiImportError(AiImportErrorKind.network);
    }

    if (response.statusCode == 200) {
      final recipe = _recipeFromJson(body['recipe']);
      if (recipe == null) return const AiImportError(AiImportErrorKind.network);
      return AiImportSuccess(
        recipe,
        model: body['model'] as String? ?? '',
        promptVersion: body['prompt_version'] as String? ?? '',
        cached: body['cached'] == true,
      );
    }
    return AiImportError(
      _kindFor(body['error'] as String?),
      message: body['message'] as String?,
    );
  }
}

AiImportErrorKind _kindFor(String? code) => switch (code) {
  'bad_request' => AiImportErrorKind.badRequest,
  'invalid_integrity_token' => AiImportErrorKind.invalidToken,
  'unreachable' => AiImportErrorKind.unreachable,
  'private_post' => AiImportErrorKind.privatePost,
  'not_a_recipe' => AiImportErrorKind.notARecipe,
  'limit_reached' => AiImportErrorKind.limitReached,
  'busy' => AiImportErrorKind.busy,
  'misconfigured' => AiImportErrorKind.misconfigured,
  _ => AiImportErrorKind.unknown,
};

/// SRV-1's recipe shape → [ImportedRecipe], the same model the website
/// path builds (`parseRecipePage`). Amounts are never read here: every
/// ingredient line stays the server's verbatim `original_text` (SRV-1),
/// for `Importer`'s existing draft builder to run through QTY-1.
ImportedRecipe? _recipeFromJson(Object? v) {
  if (v is! Map) return null;
  final m = v.cast<String, Object?>();
  final title = (m['title'] as String?)?.trim();
  if (title == null || title.isEmpty) return null;
  return ImportedRecipe(
    title: title,
    servings: (m['servings'] as num?)?.round(),
    prepMinutes: (m['prep_minutes'] as num?)?.round(),
    cookMinutes: (m['cook_minutes'] as num?)?.round(),
    ingredients: _ingredientGroups(m['ingredient_groups']),
    steps: _stepGroups(m['step_groups']),
  );
}

List<(String?, List<String>)> _ingredientGroups(Object? v) {
  if (v is! List) return const [];
  final out = <(String?, List<String>)>[];
  for (final group in v) {
    if (group is! Map) continue;
    final g = group.cast<String, Object?>();
    final lines = g['lines'];
    final texts = <String>[
      if (lines is List)
        for (final line in lines)
          if (line is Map)
            if ((line['original_text'] as String?)?.trim() case final t?
                when t.isNotEmpty)
              t,
    ];
    if (texts.isNotEmpty) out.add((_groupName(g['name']), texts));
  }
  return out;
}

List<(String?, List<String>)> _stepGroups(Object? v) {
  if (v is! List) return const [];
  final out = <(String?, List<String>)>[];
  for (final group in v) {
    if (group is! Map) continue;
    final g = group.cast<String, Object?>();
    final steps = g['steps'];
    final texts = <String>[
      if (steps is List)
        for (final s in steps)
          if (s is String && s.trim().isNotEmpty) s.trim(),
    ];
    if (texts.isNotEmpty) {
      out.add((_groupName(g['name']), _splitLongSteps(texts)));
    }
  }
  return out;
}

/// IMP-6: same 400-character sentence split the page parser applies
/// (`recipe_import.dart`'s own `_splitLong`) — the server's steps go
/// through it too, so a long paragraph from a caption never gets silently
/// truncated by `Importer._draft`'s 2,000-character cap later.
List<String> _splitLongSteps(List<String> steps, {int max = 400}) => [
  for (final s in steps) ...(s.length <= max ? [s] : splitLongStep(s)),
];

String? _groupName(Object? v) {
  final n = (v as String?)?.trim();
  return n == null || n.isEmpty ? null : n;
}
