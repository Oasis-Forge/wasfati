import 'dart:typed_data';

import '../db/recipe_repository.dart';
import '../models/recipe.dart';
import '../models/recipe_import.dart';
import '../models/recipe_translation.dart';
import 'ai_import.dart';
import 'photo_store.dart';
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
    Future<Uint8List?> Function(Uint8List bytes)? resizeImage,
    PhotoStore? photos,
  }) : _savePhoto = savePhoto ?? saveImportedPhoto,
       _aiClient = aiClient ?? NoopAiImportClient(),
       _resizeImage = resizeImage ?? resizeForImport,
       _photos = photos ?? const NoopPhotoStore();

  final PageFetcher _fetcher;
  final RecipeRepository _repo;
  final Future<String?> Function(String id, Uint8List bytes) _savePhoto;
  final AiImportClient _aiClient;

  /// IMP-10's resize before a photo leaves the device ([resizeForImport]).
  final Future<Uint8List?> Function(Uint8List bytes) _resizeImage;

  /// Copies a translated copy's photo (IMP-14, REC-8).
  final PhotoStore _photos;

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

  /// Sends 1 to [maxImportImages] photos — a cookbook page, a handwritten
  /// recipe, or a screenshot from IMP-12's fallback — to the AI import
  /// server (IMP-1, IMP-10). Each is resized on the device first, to at
  /// most 1600 px at JPEG 80, so nothing larger ever leaves it; the server
  /// discards them after answering (SRV-3) and never caches them (SRV-5).
  ///
  /// The recipe keeps the first photo as its own (REC-8, IMP-10), saved
  /// only once the server has answered with a recipe, so a failed attempt
  /// leaves no file behind. The preview can still remove it.
  ///
  /// Like [fromAi], the lines come back through [_draft] and QTY-1, and
  /// calling this never spends the quota — only saving does (IMP-7).
  /// Throws [AiImportException], `unreadablePhoto` when a picture can't be
  /// read on the device (nothing is sent then).
  Future<Recipe> fromPhotos({
    required String installId,
    required List<Uint8List> images,
  }) async {
    assert(
      images.isNotEmpty && images.length <= maxImportImages,
      'a photo import sends 1 to $maxImportImages images',
    );
    final sent = <Uint8List>[];
    for (final image in images) {
      final jpeg = await _resizeImage(image);
      if (jpeg == null) {
        throw const AiImportException(AiImportErrorKind.unreadablePhoto);
      }
      sent.add(jpeg);
    }
    final result = await _aiClient.import(installId: installId, images: sent);
    switch (result) {
      case AiImportError(:final kind):
        throw AiImportException(kind);
      case AiImportSuccess(:final recipe):
        final id = _repo.newId();
        return _draft(
          id,
          recipe,
          sourceType: SourceType.photo,
          photo: await _savePhoto(id, images.first),
        );
    }
  }

  /// Translates [recipe] into Arabic ([toArabic]) or English for
  /// [installId] (IMP-14, IMP-15, SRV-11), and returns the translated copy
  /// as a draft for the preview; nothing is saved here, and calling this
  /// never spends the quota — only saving the copy does (IMP-16).
  ///
  /// Only [recipe]'s words go out, keyed by ID (`translationItems`); every
  /// line comes back with its own amount, range and unit, and a text whose
  /// numbers or timers changed keeps the original (`applyTranslation`).
  /// The copy is a new recipe with new IDs; [linkToOriginal] records
  /// [recipe] as what it was translated from (a saved recipe — an import
  /// preview has nothing saved to link to). Its photo is a copied file.
  ///
  /// Throws [AiImportException]: `tooLarge` before sending anything when
  /// [recipe] is past SRV-11's limits, `badTranslation` when an ID didn't
  /// come back exactly once (nothing changes then, SRV-7), and any server
  /// or network failure.
  Future<TranslatedRecipe> translate({
    required String installId,
    required Recipe recipe,
    required bool toArabic,
    bool linkToOriginal = false,
  }) async {
    final items = translationItems(recipe);
    if (items.isEmpty) {
      throw const AiImportException(AiImportErrorKind.badRequest);
    }
    if (!fitsTranslateLimits(items)) {
      throw const AiImportException(AiImportErrorKind.tooLarge);
    }
    final result = await _aiClient.translate(
      installId: installId,
      target: toArabic ? 'ar' : 'en',
      items: items,
    );
    switch (result) {
      case AiTranslateError(:final kind):
        throw AiImportException(kind);
      case AiTranslateSuccess(items: final returned):
        final id = _repo.newId();
        final applied = applyTranslation(
          recipe,
          returned,
          toArabic: toArabic,
          id: id,
          newId: _repo.newId,
          now: _repo.now(),
          translatedFrom: linkToOriginal ? recipe.id : null,
        );
        if (applied == null) {
          throw const AiImportException(AiImportErrorKind.badTranslation);
        }
        final photo = recipe.photoPath;
        return (
          recipe: applied.recipe.copyWith(
            photoPath: photo == null ? null : await _photos.copy(photo, id),
          ),
          keptOriginal: applied.keptOriginal,
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
