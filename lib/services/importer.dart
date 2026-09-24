import 'dart:typed_data';

import '../db/recipe_repository.dart';
import '../models/recipe.dart';
import '../models/recipe_import.dart';
import 'ai_import.dart';
import 'web_import.dart';

/// Thrown by [Importer.fromAi] for any typed server or network failure
/// (SRV-7) — never a raw string; the UI picks its own translated message
/// (LANG-2) from [kind].
class AiImportException implements Exception {
  const AiImportException(this.kind);
  final AiImportErrorKind kind;
  @override
  String toString() => 'AiImportException($kind)';
}

/// Turns a link or shared text into a recipe draft for the preview (IMP-5).
/// Nothing is saved here: the user saves from the preview.
class Importer {
  Importer(
    this._fetcher,
    this._repo, {
    Future<String?> Function(String id, Uint8List bytes)? savePhoto,
    AiImportClient? aiClient,
  }) : _savePhoto = savePhoto ?? saveImportedPhoto,
       _aiClient = aiClient ?? NoopAiImportClient();

  final PageFetcher _fetcher;
  final RecipeRepository _repo;
  final Future<String?> Function(String id, Uint8List bytes) _savePhoto;
  final AiImportClient _aiClient;

  /// The saved recipe with the same source page, if any (IMP-9).
  Future<String?> duplicateOf(String rawUrl) =>
      _repo.findBySourceUrl(normalizeSourceUrl(rawUrl));

  /// Reads a recipe website on the device (IMP-2, IMP-11). Free and
  /// unlimited: it never touches the AI quota or our server.
  Future<Recipe> fromUrl(String rawUrl) async {
    final url = Uri.tryParse(rawUrl.trim());
    if (url == null ||
        !url.hasAuthority ||
        !url.isScheme('http') && !url.isScheme('https')) {
      throw const ImportException(ImportFailure.invalidUrl);
    }
    final page = await _fetcher.page(url);
    final found = parseRecipePage(page, url);
    if (found == null) throw const ImportException(ImportFailure.noRecipe);
    final id = _repo.newId();
    String? photo;
    if (found.imageUrl != null) {
      final bytes = await _fetcher.image(Uri.parse(found.imageUrl!));
      if (bytes != null) photo = await _savePhoto(id, bytes);
    }
    return _draft(
      id,
      found,
      sourceType: SourceType.website,
      sourceUrl: normalizeSourceUrl(rawUrl),
      photo: photo,
    );
  }

  /// The offline fallback draft (IMP-13): a heading-based guess at
  /// ingredients and steps, used for "Add by hand" and whenever AI import
  /// can't be reached (no quota, no network). [fromAi] is the normal path
  /// for pasted or shared text now that AI import exists (IMP-3).
  Recipe fromText(String text) => _draft(
    _repo.newId(),
    draftFromText(text),
    sourceType: SourceType.written,
  );

  /// Sends [url] or [text] (exactly one) to the AI import server (IMP-3,
  /// SRV-1) for [installId] (SRV-4). Only called after [fromUrl] fails
  /// with a failure [needsAiImport] agrees should be retried (IMP-2), or
  /// directly for a social link or pasted text (IMP-3).
  ///
  /// The server never returns amounts: every ingredient line comes back
  /// through this same [_draft] builder and QTY-1 (IMP-6, IMP-15,
  /// Decision 17), exactly like a website or typed line. Calling this
  /// alone never spends the AI quota — only saving the returned draft
  /// does (IMP-7); a cancelled or failed attempt costs nothing.
  ///
  /// Throws [AiImportException] for any server error or network failure
  /// (SRV-7) — the caller reads its `kind` rather than a string.
  Future<Recipe> fromAi({
    required String installId,
    String? url,
    String? text,
  }) async {
    assert(
      (url == null) != (text == null),
      'Importer.fromAi needs exactly one of url or text',
    );
    final result = await _aiClient.import(
      installId: installId,
      url: url,
      text: text,
    );
    switch (result) {
      case AiImportError(:final kind):
        throw AiImportException(kind);
      case AiImportSuccess(:final recipe):
        return _draft(
          _repo.newId(),
          recipe,
          sourceType: url != null ? SourceType.social : SourceType.written,
          sourceUrl: url == null ? null : normalizeSourceUrl(url),
          // IMP-6: the original caption is kept, collapsed, so anything the
          // model missed is still there to recover. Only the text path has
          // it in hand — a link's page text is read on the server, which
          // keeps nothing (SRV-3), so the device never sees it.
          notes: text == null ? null : _collapse(text),
        );
    }
  }

  Recipe _draft(
    String id,
    ImportedRecipe r, {
    required SourceType sourceType,
    String? sourceUrl,
    String? photo,
    String? notes,
  }) {
    final now = _repo.now();
    return Recipe(
      id: id,
      title: r.title.length > Recipe.maxTitle
          ? r.title.substring(0, Recipe.maxTitle)
          : r.title,
      photoPath: photo,
      sourceUrl: sourceUrl,
      sourceType: sourceType,
      notes: notes,
      servings: r.servings,
      prepMinutes: r.prepMinutes,
      cookMinutes: r.cookMinutes,
      ingredients: [
        for (final (name, lines) in r.ingredients)
          Section(
            id: _repo.newId(),
            name: name,
            items: [
              for (final l in lines) IngredientLine.parse(_repo.newId(), l),
            ],
          ),
      ],
      steps: [
        for (final (name, steps) in r.steps)
          Section(
            id: _repo.newId(),
            name: name,
            items: [
              for (final s in steps)
                RecipeStep(
                  id: _repo.newId(),
                  text: s.length > RecipeStep.maxLength
                      ? s.substring(0, RecipeStep.maxLength)
                      : s,
                ),
            ],
          ),
      ],
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// IMP-6's "kept in the recipe's notes, collapsed": runs and line breaks in
/// the original caption become single spaces, so a multi-paragraph caption
/// reads as one block instead of the post's own line breaks.
String _collapse(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');
