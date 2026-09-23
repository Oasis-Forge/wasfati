// LOOK-9: derives the launcher icon's other layers from the one
// committed brand source, assets/brand/icon-1024.png (a generated image,
// kept verbatim — see docs/RELEASING.md). Writes:
//   - assets/brand/icon-foreground-1024.png — the mark alone, transparent
//     ground, scaled to ~60% of the canvas for Android's adaptive icon;
//   - assets/brand/splash-1024.png — the same, scaled to ~50%;
//   - assets/brand/icon-128.png — the full source downscaled, so the
//     small size can be judged by eye.
//
// Deliberately NOT under test/, so `flutter test` (CI included) never runs
// it. Run it by hand, then commit nothing here — the generated PNGs are
// picked up by flutter_launcher_icons and flutter_native_splash, whose own
// commands are in docs/RELEASING.md:
//
//   flutter test tool/brand/derive_brand_assets.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//
// It's a `flutter test` (not a `dart run` script) only to match the
// project's convention for brand-asset tooling; nothing here needs the
// Flutter framework itself — it's plain raster image processing on
// package:image.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _sourcePath = 'assets/brand/icon-1024.png';
const _outputDir = 'assets/brand';

/// Below this colour distance from the sampled ground, a pixel is fully
/// transparent; above this, fully opaque. Between the two, alpha ramps
/// linearly — a hard cutoff here would leave jagged, aliased edges around
/// the star and the letters.
const double _keyLowDistance = 30;
const double _keyHighDistance = 90;

/// A pixel is "ink" (part of the mark, not the ground) once its alpha
/// clears this — used to measure the mark's own extent, not anti-aliasing
/// fringe.
const int _inkAlphaThreshold = 40;

class _Corners {
  const _Corners(this.r, this.g, this.b);
  final double r, g, b;
}

/// Samples the ground colour from the source image's four corners (a
/// small patch inset from the very edge, in case of encoding noise right
/// at the border) rather than assuming a fixed value — the source is a
/// generated image, not a value this script controls.
_Corners _sampleGroundColor(img.Image image) {
  final points = [
    (2, 2),
    (image.width - 3, 2),
    (2, image.height - 3),
    (image.width - 3, image.height - 3),
  ];
  var r = 0.0, g = 0.0, b = 0.0;
  for (final (x, y) in points) {
    final p = image.getPixel(x, y);
    r += p.r;
    g += p.g;
    b += p.b;
  }
  final n = points.length;
  return _Corners(r / n, g / n, b / n);
}

double _colorDistance(img.Pixel p, _Corners ground) {
  final dr = p.r - ground.r;
  final dg = p.g - ground.g;
  final db = p.b - ground.b;
  return math.sqrt(dr * dr + dg * dg + db * db);
}

/// Keys the ground out of [source]: same size, same RGB, but alpha now
/// ramps from 0 (at/near [ground]) to 255 (the mark's own cream), so the
/// anti-aliased edge between them stays soft instead of jagged.
img.Image _keyOutGround(img.Image source, _Corners ground) {
  final keyed = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final p = source.getPixel(x, y);
      final dist = _colorDistance(p, ground);
      final t =
          ((dist - _keyLowDistance) / (_keyHighDistance - _keyLowDistance))
              .clamp(0.0, 1.0);
      final alpha = (t * 255).round();
      keyed.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), alpha);
    }
  }
  return keyed;
}

class _InkBBox {
  _InkBBox(this.left, this.top, this.right, this.bottom);
  final int left, top, right, bottom;
  int get width => right - left;
  int get height => bottom - top;
}

_InkBBox? _measureInk(img.Image image, {required bool useAlpha}) {
  int? minX, maxX, minY, maxY;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final isInk = useAlpha
          ? p.a >= _inkAlphaThreshold
          : p.a > 200 && (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) > 200;
      if (!isInk) continue;
      minX = (minX == null || x < minX) ? x : minX;
      maxX = (maxX == null || x > maxX) ? x : maxX;
      minY = (minY == null || y < minY) ? y : minY;
      maxY = (maxY == null || y > maxY) ? y : maxY;
    }
  }
  if (minX == null) return null;
  return _InkBBox(minX, minY!, maxX!, maxY!);
}

/// Premultiplies alpha into RGB before a resize and undoes it after —
/// straight (non-premultiplied) alpha resizes blend a transparent
/// pixel's *stored* colour (here, the keyed-out ground's own hue) into
/// nearby edge pixels, leaving a visible fringe. Premultiplying first
/// makes a fully transparent pixel black, so it contributes nothing.
img.Image _premultiply(img.Image image) {
  final out = img.Image.from(image);
  for (var y = 0; y < out.height; y++) {
    for (var x = 0; x < out.width; x++) {
      final p = out.getPixel(x, y);
      final a = p.a / 255.0;
      out.setPixelRgba(
        x,
        y,
        (p.r * a).round(),
        (p.g * a).round(),
        (p.b * a).round(),
        p.a.toInt(),
      );
    }
  }
  return out;
}

img.Image _unpremultiply(img.Image image) {
  final out = img.Image.from(image);
  for (var y = 0; y < out.height; y++) {
    for (var x = 0; x < out.width; x++) {
      final p = out.getPixel(x, y);
      final a = p.a / 255.0;
      if (a <= 0.001) {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
      } else {
        out.setPixelRgba(
          x,
          y,
          (p.r / a).round().clamp(0, 255),
          (p.g / a).round().clamp(0, 255),
          (p.b / a).round().clamp(0, 255),
          p.a.toInt(),
        );
      }
    }
  }
  return out;
}

/// Scales [keyed] (the whole canvas, ground already transparent) so the
/// mark's ink — currently [currentMarkFraction] of the canvas's side —
/// becomes [targetFraction] of it, then centres the result on a fresh
/// transparent canvas the same size as the source.
img.Image _composeAtScale(
  img.Image keyed,
  double currentMarkFraction,
  double targetFraction,
) {
  final scale = targetFraction / currentMarkFraction;
  final side = keyed.width;
  final newSide = (side * scale).round();

  final premultiplied = _premultiply(keyed);
  final resized = img.copyResize(
    premultiplied,
    width: newSide,
    height: newSide,
    interpolation: img.Interpolation.average,
  );
  final resizedStraight = _unpremultiply(resized);

  final canvas = img.Image(width: side, height: side, numChannels: 4);
  final offsetX = (side - newSide) ~/ 2;
  final offsetY = (side - newSide) ~/ 2;
  img.compositeImage(canvas, resizedStraight, dstX: offsetX, dstY: offsetY);
  return canvas;
}

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

Future<File> _writePng(String fileName, img.Image image) async {
  final dir = Directory(_outputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final file = File('$_outputDir/$fileName');
  final bytes = img.encodePng(image);
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

void _assertValidPng(File file, String fileName) {
  expect(file.existsSync(), isTrue, reason: '$fileName was not written');
  final bytes = file.readAsBytesSync();
  expect(bytes, isNotEmpty, reason: '$fileName is empty');
  expect(
    bytes.take(8),
    equals(_pngSignature),
    reason: '$fileName is not a valid PNG',
  );
  expect(
    img.decodePng(bytes),
    isNotNull,
    reason: '$fileName could not be decoded back as a PNG',
  );
}

void _assertTransparentCorners(img.Image image, String fileName) {
  final corners = [
    (2, 2),
    (image.width - 3, 2),
    (2, image.height - 3),
    (image.width - 3, image.height - 3),
  ];
  for (final (x, y) in corners) {
    final a = image.getPixel(x, y).a;
    expect(
      a,
      lessThan(10),
      reason:
          '$fileName: corner ($x,$y) has alpha $a — expected a transparent ground',
    );
  }
}

void _assertInkWiderThanTall(
  img.Image image,
  String fileName, {
  required bool useAlpha,
}) {
  final ink = _measureInk(image, useAlpha: useAlpha);
  expect(ink, isNotNull, reason: '$fileName: no mark ink found');
  expect(
    ink!.width,
    greaterThan(ink.height),
    reason:
        '$fileName: mark ink is ${ink.width}x${ink.height} — expected wider than tall',
  );
}

void main() {
  test('derives the brand assets from assets/brand/icon-1024.png', () async {
    final source = img.decodePng(File(_sourcePath).readAsBytesSync())!;
    final ground = _sampleGroundColor(source);
    // ignore: avoid_print
    print(
      'sampled ground: r=${ground.r.round()} g=${ground.g.round()} b=${ground.b.round()} '
      'hex=#${ground.r.round().toRadixString(16).padLeft(2, '0')}'
      '${ground.g.round().toRadixString(16).padLeft(2, '0')}'
      '${ground.b.round().toRadixString(16).padLeft(2, '0')}',
    );

    final keyed = _keyOutGround(source, ground);
    final markInSource = _measureInk(keyed, useAlpha: true)!;
    final currentMarkFraction =
        math.max(markInSource.width, markInSource.height) / source.width;
    // ignore: avoid_print
    print(
      'mark in source: ${markInSource.width}x${markInSource.height} '
      '(${(currentMarkFraction * 100).toStringAsFixed(1)}% of side)',
    );

    final foreground = _composeAtScale(keyed, currentMarkFraction, 0.60);
    final foregroundFile = await _writePng(
      'icon-foreground-1024.png',
      foreground,
    );
    _assertValidPng(foregroundFile, 'icon-foreground-1024.png');
    _assertTransparentCorners(foreground, 'icon-foreground-1024.png');
    _assertInkWiderThanTall(
      foreground,
      'icon-foreground-1024.png',
      useAlpha: true,
    );
    final foregroundInk = _measureInk(foreground, useAlpha: true)!;
    // ignore: avoid_print
    print(
      'icon-foreground-1024.png mark: ${foregroundInk.width}x${foregroundInk.height} '
      '(${(math.max(foregroundInk.width, foregroundInk.height) / foreground.width * 100).toStringAsFixed(1)}% of side)',
    );

    final splash = _composeAtScale(keyed, currentMarkFraction, 0.50);
    final splashFile = await _writePng('splash-1024.png', splash);
    _assertValidPng(splashFile, 'splash-1024.png');
    _assertTransparentCorners(splash, 'splash-1024.png');
    _assertInkWiderThanTall(splash, 'splash-1024.png', useAlpha: true);
    final splashInk = _measureInk(splash, useAlpha: true)!;
    // ignore: avoid_print
    print(
      'splash-1024.png mark: ${splashInk.width}x${splashInk.height} '
      '(${(math.max(splashInk.width, splashInk.height) / splash.width * 100).toStringAsFixed(1)}% of side)',
    );

    final small = img.copyResize(
      source,
      width: 128,
      height: 128,
      interpolation: img.Interpolation.average,
    );
    final smallFile = await _writePng('icon-128.png', small);
    _assertValidPng(smallFile, 'icon-128.png');
    _assertInkWiderThanTall(small, 'icon-128.png', useAlpha: false);
  });
}
