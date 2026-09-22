// The recipe image pages (SHARE-3, SHARE-4): dart:ui drawing only, no
// image or PDF package. Plans come from models/recipe_share.dart (pure
// Dart); this file turns a plan into PNG bytes and writes them to disk.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app.dart' show fontFamily;
import '../models/quantity/convert.dart';
import '../models/quantity/format.dart';
import '../models/quantity/rational.dart';
import '../models/recipe.dart';
import '../models/recipe_share.dart';
import '../models/settings.dart' show AppStyle;
import '../theme/colors.dart' show wasfatiColorScheme;
import '../widgets/content_direction.dart';

const _contentWidth = shareImageWidth - 2 * shareMargin;

/// Where the rendered pages go (SHARE-4): behind an interface so tests use
/// a throwaway directory instead of the device cache.
abstract interface class ShareStorage {
  /// The folder pages are written into. It doesn't have to exist yet.
  Future<Directory> pagesDir();

  /// Other folders a past share may have left behind, cleared alongside
  /// [pagesDir] at startup (SHARE-4, should-fix, adversarial review): on
  /// the device, `share_plus`'s own copy of every shared file, which it
  /// only clears at the *next* share, so it would otherwise outlive this
  /// run. Empty when there's nothing else to clear.
  Future<List<Directory>> leftoverDirs();
}

/// The real storage: a `share` folder in the app's cache, cleared at every
/// start by [clearShareCache]. No permission is needed for it (RUN-2).
class DeviceShareStorage implements ShareStorage {
  const DeviceShareStorage();

  @override
  Future<Directory> pagesDir() async {
    final tmp = await getTemporaryDirectory();
    return Directory(p.join(tmp.path, 'share'));
  }

  @override
  Future<List<Directory>> leftoverDirs() async {
    final tmp = await getTemporaryDirectory();
    // share_plus (Share.kt: prepareShareIntent → copyToShareCacheFolder)
    // copies every shared file here and clears it only at the NEXT share,
    // so a shared recipe's images would otherwise outlive this run.
    return [Directory(p.join(tmp.path, 'share_plus'))];
  }
}

/// The default in tests: a directory the test owns, so it can find and
/// clean up its own files without touching the real cache.
class FakeShareStorage implements ShareStorage {
  FakeShareStorage(this.dir, {this.leftovers = const []});
  final Directory dir;
  final List<Directory> leftovers;

  @override
  Future<Directory> pagesDir() async => dir;

  @override
  Future<List<Directory>> leftoverDirs() async => leftovers;
}

/// Deletes every image left over from a previous run (SHARE-4): called once
/// at app start (`main.dart`), so shared pictures never outlive the run
/// that made them. A missing folder is not an error.
Future<void> clearShareCache(ShareStorage storage) async {
  final dirs = [await storage.pagesDir(), ...await storage.leftoverDirs()];
  for (final dir in dirs) {
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// Renders [r]'s share images (SHARE-3): what's drawn is what the recipe
/// page shows — [factor], [view] and [digits] — never notes, tags, rating,
/// cookbooks or the cooked count (SHARE-1). [uiDirection] is the app's own
/// reading edge (`Directionality.of(context)`), which every block aligns
/// to (LANG-5, must-fix, adversarial review) whatever direction its own
/// text reads in. [style] is the chosen look's light palette (LOOK-1,
/// SHARE-3, Decision 16) — the caller's own `settings.style`, read once
/// before rendering and threaded through, never read from settings inside
/// this renderer. An unscaled line carries [notScaledMark], through
/// [unscaledLineText] (SCALE-6, should-fix). Returns the pages' file paths
/// in order, or null when the recipe needs more than [shareMaxPages] pages
/// even after shrinking an oversized block, so the caller should offer
/// text instead.
Future<List<String>?> renderSharePages(
  Recipe r, {
  required Rational factor,
  required UnitView view,
  required DigitStyle digits,
  required TextDirection uiDirection,
  required AppStyle style,
  required String ingredientsHeading,
  required String stepsHeading,
  required String notScaledMark,
  required String Function(String line, String mark) unscaledLineText,
  required String Function(int servings) servingsLabel,
  required String Function(int minutes) prepTimeLabel,
  required String Function(int minutes) cookTimeLabel,
  required String brand,
  required ShareStorage storage,
}) async {
  // must-fix (adversarial review): a missing or corrupt photo (BAK-9: a
  // restore carries the database but not photo files) must not crash the
  // share — it just drops the photo, the same way the recipe page's own
  // Image.file(errorBuilder:) does.
  final requestsPhoto = r.photoPath != null && r.photoPath!.trim().isNotEmpty;
  final photo = requestsPhoto ? await _decodePhoto(r.photoPath!) : null;
  final hasPhoto = photo != null;

  final blocks = shareBlocksFor(
    r,
    hasPhoto: hasPhoto,
    factor: factor,
    view: view,
    digits: digits,
    ingredientsHeading: ingredientsHeading,
    stepsHeading: stepsHeading,
    notScaledMark: notScaledMark,
    unscaledLineText: unscaledLineText,
    servingsLabel: servingsLabel,
    prepTimeLabel: prepTimeLabel,
    cookTimeLabel: cookTimeLabel,
  );
  final plan = planSharePages(blocks, measureShareBlock, digits: digits);
  if (plan.tooLong) {
    photo?.dispose();
    return null;
  }

  // LOOK-1/SHARE-3: the chosen look's own light palette, never a fixed
  // seed — pages always use the light theme regardless of the device's
  // own brightness.
  final colors = wasfatiColorScheme(style, Brightness.light);

  try {
    final dir = await storage.pagesDir();
    await dir.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final paths = <String>[];
    for (var i = 0; i < plan.pages.length; i++) {
      final bytes = await _renderPage(
        plan.pages[i],
        colors: colors,
        brand: brand,
        uiDirection: uiDirection,
        photo: i == 0 ? photo : null,
      );
      final path = p.join(dir.path, 'recipe-$stamp-${i + 1}.png');
      await File(path).writeAsBytes(bytes, flush: true);
      paths.add(path);
    }
    return paths;
  } finally {
    photo?.dispose(); // should-fix, adversarial review: native memory
  }
}

/// Decodes the recipe's photo, or null on any failure (a missing file after
/// a restore, BAK-9, or one that isn't a valid image) — never lets a bad
/// photo crash the share (must-fix, adversarial review).
Future<ui.Image?> _decodePhoto(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  } on Exception {
    return null;
  }
}

/// How tall [block] renders at [width] px (SHARE-3): a real text layout at
/// the block's own font size, or the photo band's fixed 4:3 height. Used
/// both to plan the pages and, unchanged, to draw them, so a block is never
/// taller on the page than the planner accounted for. Direction and
/// alignment never change a paragraph's wrapped height at a fixed width,
/// so which way it reads doesn't matter here — only for painting.
double measureShareBlock(ShareBlock block, double width) {
  if (block.kind == ShareBlockKind.photo) return width * 3 / 4;
  final painter = _layOutBlock(
    block.text,
    _styleFor(block.kind, block.fontSize),
    width,
    direction: shareBlockDirection(block, TextDirection.ltr),
    align: TextAlign.left,
  );
  final height = painter.height;
  painter.dispose();
  return height;
}

/// The direction a block's own text reads in (LANG-5, QTY-5, must-fix,
/// adversarial review). The app's own words — the facts line — always
/// follow [uiDirection], never their own digits: an Eastern-digit facts
/// line in the English UI ("Serves ٦ · Prep ١٥ min") must still read left
/// to right, which sniffing the text itself can't tell (Eastern digits sit
/// in the Arabic Unicode block). Everything else is the recipe's own words
/// — a title or heading by its own text, an ingredient or a step by
/// [ShareBlock.directionSource] (the line as written, or the step's own
/// words without the app-added number), never by [ShareBlock.text], which
/// may carry app-chosen digits or numbering of its own.
TextDirection shareBlockDirection(
  ShareBlock block,
  TextDirection uiDirection,
) => block.kind == ShareBlockKind.facts
    ? uiDirection
    : contentDirection(block.directionSource ?? block.text);

/// Body content, laid out at a fixed [width] and aligned to [align] — the
/// app's own reading edge, like [ContentText] on the recipe page — so a
/// short line lands at that edge instead of shrinking to its own width and
/// sitting wherever [Offset] puts it (SHARE-3/LANG-5, must-fix,
/// adversarial review: every short Arabic line used to hug the left
/// margin, since `layout(maxWidth:)` alone reports the text's own width,
/// leaving `TextAlign` nothing to align within).
TextPainter _layOutBlock(
  String text,
  TextStyle style,
  double width, {
  required TextDirection direction,
  required TextAlign align,
}) => TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: direction,
  textAlign: align,
)..layout(minWidth: width, maxWidth: width);

/// A short, natural-width label (the footer's brand and page counter): laid
/// out only as wide as its own text, so the caller places it at either edge
/// by hand (SHARE-3's footer, which already does this correctly).
TextPainter _layOutNatural(
  String text,
  TextStyle style, {
  required TextDirection direction,
}) => TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: direction,
)..layout();

TextStyle _styleFor(ShareBlockKind kind, double fontSize, [Color? color]) =>
    TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: 1.3,
      color: color,
      fontWeight: switch (kind) {
        ShareBlockKind.title => FontWeight.w700,
        ShareBlockKind.heading => FontWeight.w600,
        ShareBlockKind.facts => FontWeight.w500,
        ShareBlockKind.ingredient || ShareBlockKind.step => FontWeight.w400,
        ShareBlockKind.photo => FontWeight.w400,
      },
    );

Color _colorFor(ShareBlockKind kind, ColorScheme colors) => switch (kind) {
  ShareBlockKind.heading => colors.primary,
  ShareBlockKind.facts => colors.onSurfaceVariant,
  _ => colors.onSurface,
};

Future<Uint8List> _renderPage(
  SharePage page, {
  required ColorScheme colors,
  required String brand,
  required TextDirection uiDirection,
  ui.Image? photo,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    const Rect.fromLTWH(0, 0, shareImageWidth, shareImageHeight),
  );
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, shareImageWidth, shareImageHeight),
    Paint()..color = colors.surface,
  );

  final align = uiDirection == TextDirection.rtl
      ? TextAlign.right
      : TextAlign.left;
  var y = shareMargin;
  for (final block in page.blocks) {
    if (block.kind == ShareBlockKind.photo) {
      final h = measureShareBlock(block, _contentWidth);
      if (photo != null) {
        _drawCover(
          canvas,
          photo,
          Rect.fromLTWH(shareMargin, y, _contentWidth, h),
        );
      }
      y += h + shareBlockGap;
      continue;
    }
    final painter = _layOutBlock(
      block.text,
      _styleFor(block.kind, block.fontSize, _colorFor(block.kind, colors)),
      _contentWidth,
      direction: shareBlockDirection(block, uiDirection),
      align: align,
    );
    painter.paint(canvas, Offset(shareMargin, y));
    y += painter.height + shareBlockGap;
    painter.dispose(); // should-fix, adversarial review: native memory
  }

  _drawFooter(canvas, brand: brand, counter: page.footer, colors: colors);

  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(
      shareImageWidth.round(),
      shareImageHeight.round(),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

/// Draws [image] cropped to fill [dest] (`BoxFit.cover`), matching the
/// recipe page's own photo (recipe_screen.dart).
void _drawCover(Canvas canvas, ui.Image image, Rect dest) {
  final srcAspect = image.width / image.height;
  final dstAspect = dest.width / dest.height;
  Rect src;
  if (srcAspect > dstAspect) {
    final w = image.height * dstAspect;
    src = Rect.fromLTWH((image.width - w) / 2, 0, w, image.height.toDouble());
  } else {
    final h = image.width / dstAspect;
    src = Rect.fromLTWH(0, (image.height - h) / 2, image.width.toDouble(), h);
  }
  canvas.drawImageRect(image, src, dest, Paint());
}

/// The footer band on every page (SHARE-3): the brand name at its own
/// reading edge (LANG-5), the page count at the other, always left to
/// right — a "2/3" is a page number, not text (LANG-5's "numbers … stay
/// left to right"). Just the brand and the count: no ad, QR code or
/// tracking link (ADS-9).
void _drawFooter(
  Canvas canvas, {
  required String brand,
  required String counter,
  required ColorScheme colors,
}) {
  final top = shareImageHeight - shareFooterHeight;
  canvas.drawRect(
    Rect.fromLTWH(0, top, shareImageWidth, shareFooterHeight),
    Paint()..color = colors.primary,
  );

  // should-fix, adversarial review: never below the 32 px floor (SHARE-3)
  // that every other block on the page already respects.
  final brandPainter = _layOutNatural(
    brand,
    _styleFor(ShareBlockKind.heading, shareMinFontSize, colors.onPrimary),
    direction: contentDirection(brand),
  );
  final counterPainter = _layOutNatural(
    counter,
    _styleFor(ShareBlockKind.facts, shareMinFontSize, colors.onPrimary),
    direction: TextDirection.ltr,
  );

  final brandY = top + (shareFooterHeight - brandPainter.height) / 2;
  final counterY = top + (shareFooterHeight - counterPainter.height) / 2;
  final rtl = contentDirection(brand) == TextDirection.rtl;
  brandPainter.paint(
    canvas,
    Offset(
      rtl ? shareImageWidth - shareMargin - brandPainter.width : shareMargin,
      brandY,
    ),
  );
  counterPainter.paint(
    canvas,
    Offset(
      rtl ? shareMargin : shareImageWidth - shareMargin - counterPainter.width,
      counterY,
    ),
  );
  brandPainter.dispose();
  counterPainter.dispose();
}
