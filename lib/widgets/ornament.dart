import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/decor.dart';

/// LOOK-6's drawn empty-state ornament — never a bitmap. Ink draws
/// [KhatamPainter] (an eight-point star), Saffron [LatticePainter] (a girih
/// grid); [Ornament] itself picks between them from [Decor.ornament], so a
/// screen never branches on the look (LOOK-2).
class Ornament extends StatelessWidget {
  const Ornament({super.key, this.size = 120, this.opacity = 0.08, this.color});

  final double size;

  /// design-styles.md: 8% behind an empty state (both looks' khatam), kept
  /// as the default for the lattice too so neither ornament competes with
  /// the heading and body text in front of it.
  final double opacity;

  /// Defaults to `onSurface`, tinted by [opacity] — legible on any surface
  /// step in the ladder without a colour of its own.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    final tint = (color ?? Theme.of(context).colorScheme.onSurface).withValues(
      alpha: opacity,
    );
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: decor.ornament == EmptyOrnament.khatam
              ? KhatamPainter(color: tint)
              : LatticePainter(color: tint),
        ),
      ),
    );
  }
}

/// Ink's mark (design-styles.md "The khatam"): an {8/3} octagram — eight
/// points equally spaced on a circle, joined every third one so the path
/// closes after visiting all eight (`gcd(8, 3) == 1`) — stroked once, no
/// extra chords drawn between adjacent points, so it's the star's silhouette
/// and nothing more.
class KhatamPainter extends CustomPainter {
  const KhatamPainter({required this.color, this.strokeWidth = 1});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
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
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = strokeWidth,
    );
  }

  // A fixed drawing with no external state: repainting never helps.
  @override
  bool shouldRepaint(covariant KhatamPainter oldDelegate) => false;
}

/// Saffron's mark (design-styles.md "The chamfer" family, the lattice): a
/// girih grid of octagons — each corner cut at the same 0.293 ratio as
/// [ChamferedBorder] — with a small connecting square at every four-octagon
/// corner, tiled across the whole area.
class LatticePainter extends CustomPainter {
  const LatticePainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.cell = 40,
  });

  final Color color;
  final double strokeWidth;

  /// The octagon grid's cell size in dp.
  final double cell;

  static const _octagonRatio = 0.292893218813; // 1 / (2 + sqrt(2))

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final trim = cell * _octagonRatio;
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;

    // must-fix, platform review: the tile grid starts a full cell before
    // (0,0) and runs a full cell past (width,height) so the pattern looks
    // continuous right up to every edge — but `CustomPaint` never clips its
    // painter, so without this the lattice used to paint up to `cell` (40dp)
    // outside its own box on every side, over whatever sits below it
    // (`EmptyState`'s heading, LOOK-6). Clipping to the painter's own size
    // here, rather than only wrapping the `CustomPaint` in a `ClipRect`,
    // keeps the guarantee even for a test (or a future caller) that renders
    // this painter directly instead of through `Ornament`.
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    for (var row = -1; row < rows; row++) {
      for (var col = -1; col < cols; col++) {
        canvas.drawPath(
          _octagon(Rect.fromLTWH(col * cell, row * cell, cell, cell), trim),
          paint,
        );
      }
    }
    // The small square tile at every four-octagon corner.
    final cross = cell * 0.22;
    for (var row = 0; row <= rows; row++) {
      for (var col = 0; col <= cols; col++) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(col * cell, row * cell),
            width: cross,
            height: cross,
          ),
          paint,
        );
      }
    }
    canvas.restore();
  }

  Path _octagon(Rect rect, double trim) => Path()
    ..moveTo(rect.left + trim, rect.top)
    ..lineTo(rect.right - trim, rect.top)
    ..lineTo(rect.right, rect.top + trim)
    ..lineTo(rect.right, rect.bottom - trim)
    ..lineTo(rect.right - trim, rect.bottom)
    ..lineTo(rect.left + trim, rect.bottom)
    ..lineTo(rect.left, rect.bottom - trim)
    ..lineTo(rect.left, rect.top + trim)
    ..close();

  // A fixed drawing with no external state: repainting never helps.
  @override
  bool shouldRepaint(covariant LatticePainter oldDelegate) => false;
}
