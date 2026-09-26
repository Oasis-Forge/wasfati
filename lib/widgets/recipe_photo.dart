import 'dart:io';

import 'package:flutter/material.dart';

import 'recipe_cover.dart';

/// A recipe's stored photo, decoded no larger than the box it's shown in
/// (`cacheWidth`, so a library card never holds a full 1600px photo in
/// memory — should-fix), or its [RecipeCover] when there's none. One shared
/// widget instead of the same `existsSync`/`Image.file`/`errorBuilder` block
/// copied at every call site (should-fix): the list row, the grid card, the
/// "تابع الطبخ" card and a cookbook's collage cell all use this.
class RecipePhoto extends StatelessWidget {
  const RecipePhoto({
    super.key,
    required this.recipeId,
    required this.title,
    required this.photoPath,
    this.fit = BoxFit.cover,
  });

  final String recipeId;
  final String title;
  final String? photoPath;
  final BoxFit fit;

  /// True when [photoPath] is set and the file is still on disk (BAK-9: an
  /// import or a restore can leave a path with no file behind it).
  ///
  /// Memoized per path (should-fix): every library card would otherwise
  /// call `File.existsSync` — a blocking syscall — on the UI thread on
  /// every rebuild, including every search keystroke. A path is only ever
  /// reused for the same photo (the photo store names each file fresh), so
  /// caching it here never shows a stale answer for a *different* photo.
  static final _existsCache = <String, bool>{};
  static bool hasPhoto(String? photoPath) {
    if (photoPath == null) return false;
    return _existsCache.putIfAbsent(
      photoPath,
      () => File(photoPath).existsSync(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    if (path == null || !hasPhoto(path)) {
      return RecipeCover(recipeId: recipeId, title: title);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
        final width = constraints.biggest.width;
        final cacheWidth = width.isFinite ? (width * dpr).round() : null;
        return Image.file(
          File(path),
          fit: fit,
          cacheWidth: cacheWidth,
          errorBuilder: (_, _, _) =>
              RecipeCover(recipeId: recipeId, title: title),
        );
      },
    );
  }
}
