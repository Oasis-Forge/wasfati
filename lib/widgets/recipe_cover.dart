import 'dart:convert' show utf8;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/decor.dart';

/// LOOK-10: a recipe with no photo gets a drawn cover instead of a grey
/// placeholder — a khatam star pattern tiled in the tint's dark tone at
/// about 18% over the light tone, with the title's first letter large and
/// centred in the dark tone. The tint is picked from a stable hash of
/// [recipeId] ([tintIndexFor], never `Object.hashCode`, which the platform
/// gives no cross-run/cross-device guarantee for), so the same recipe shows
/// the same tint on every screen and every device. Scales from a 56dp
/// thumbnail to a 390dp header: the star tile is a fixed size and the
/// letter is sized from the box itself.
class RecipeCover extends StatelessWidget {
  const RecipeCover({
    super.key,
    required this.recipeId,
    required this.title,
    this.borderRadius,
  });

  final String recipeId;
  final String title;
  final BorderRadiusGeometry? borderRadius;

  /// A stable (FNV-1a, 32-bit) hash of [recipeId] into one of [tintCount]
  /// tints — the same value on every platform and every run, unlike
  /// `Object.hashCode`/`String.hashCode`, which the language spec never
  /// promises to be stable across isolates, processes or Dart versions.
  static int tintIndexFor(String recipeId, int tintCount) {
    var hash = 0x811C9DC5;
    for (final byte in utf8.encode(recipeId)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash % tintCount;
  }

  /// Any letter, in any script; the tatweel (ـ), a letter to Unicode, is
  /// only a stretch and never counts.
  static final _letter = RegExp(r'\p{L}', unicode: true);
  static const _tatweel = 0x0640;

  /// A combining mark: tashkeel, and any other script's accents.
  static final _mark = RegExp(r'\p{M}', unicode: true);
  static const _al = 'ال';

  /// LOOK-10: the letter drawn on the cover — the title's first letter,
  /// past any leading quote, digit, tashkeel or tatweel, and past a
  /// leading «ال», so «الكبسة» shows «ك», not a bare «ا». A title with no
  /// letter after «ال» keeps its «ا»; one with no letter at all shows its
  /// first character, and a blank one "؟".
  static String letterFor(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return '؟';
    bool isLetter(int rune) =>
        rune != _tatweel && _letter.hasMatch(String.fromCharCode(rune));
    // The title from its first letter on, without tashkeel or tatweel.
    final runes = trimmed.runes.toList();
    final first = runes.indexWhere(isLetter);
    if (first < 0) return trimmed.characters.first;
    final rest = [
      for (final rune in runes.skip(first))
        if (rune != _tatweel && !_mark.hasMatch(String.fromCharCode(rune)))
          rune,
    ];
    final word = String.fromCharCodes(rest);
    if (word.startsWith(_al)) {
      final after = rest.skip(_al.length).where(isLetter);
      if (after.isNotEmpty) return String.fromCharCode(after.first);
    }
    return String.fromCharCode(rest.first);
  }

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    final tints = decor.coverTints;
    final (light, dark) = tints[tintIndexFor(recipeId, tints.length)];
    final letter = letterFor(title);

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: ColoredBox(
        color: light,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.biggest.shortestSide.isFinite
                ? constraints.biggest.shortestSide
                : 120.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _StarTilePainter(
                    color: dark.withValues(alpha: 0.18),
                  ),
                ),
                // The letter is decoration, the same as the star tile
                // behind it — never a screen reader's first word for a
                // recipe card or row (should-fix: it was reading before
                // the title, the source and even the card's own button
                // role).
                ExcludeSemantics(
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontWeight: FontWeight.w700,
                        color: dark,
                        fontSize: (side * 0.4).clamp(14, 72),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// LOOK-10: an eight-point khatam star, tiled about 28dp per star (design
/// spec §1), clipped to its own box (`CustomPaint` never clips a painter on
/// its own).
class _StarTilePainter extends CustomPainter {
  const _StarTilePainter({required this.color});

  final Color color;

  /// About 28dp per star (design spec §1).
  static const cell = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.2;
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;
    for (var row = -1; row < rows; row++) {
      for (var col = -1; col < cols; col++) {
        final center = Offset((col + 0.5) * cell, (row + 0.5) * cell);
        canvas.drawPath(_star(center, cell * 0.42), paint);
      }
    }
    canvas.restore();
  }

  Path _star(Offset center, double radius) {
    final points = [
      for (var k = 0; k < 8; k++)
        center + Offset.fromDirection(k * math.pi / 4 - math.pi / 2, radius),
    ];
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var step = 1; step <= 8; step++) {
      final p = points[(step * 3) % 8];
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _StarTilePainter oldDelegate) =>
      color != oldDelegate.color;
}
