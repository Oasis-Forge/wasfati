import 'dart:typed_data';

import '../db/recipe_repository.dart';
import '../models/recipe.dart';
import '../models/recipe_import.dart';
import 'web_import.dart';

/// Turns a link or shared text into a recipe draft for the preview (IMP-5).
/// Nothing is saved here: the user saves from the preview.
class Importer {
  Importer(
    this._fetcher,
    this._repo, {
    Future<String?> Function(String id, Uint8List bytes)? savePhoto,
  }) : _savePhoto = savePhoto ?? saveImportedPhoto;

  final PageFetcher _fetcher;
  final RecipeRepository _repo;
  final Future<String?> Function(String id, Uint8List bytes) _savePhoto;

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

  /// Shared or pasted text, before AI import exists, as a draft (IMP-13).
  Recipe fromText(String text) => _draft(
    _repo.newId(),
    draftFromText(text),
    sourceType: SourceType.written,
  );

  Recipe _draft(
    String id,
    ImportedRecipe r, {
    required SourceType sourceType,
    String? sourceUrl,
    String? photo,
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
