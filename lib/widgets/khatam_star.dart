import 'dart:math' as math;

import 'package:flutter/material.dart';

/// LOOK-6/LOOK-10, Decision 23: سُفرة's one drawn motif, the eight-point
/// khatam star — never a bitmap. Cook mode's finish screen draws it large
/// with a soft fill; an empty state (`EmptyState`) draws it as a quiet
/// outline in its accent disc. Decoration only: it has no semantics.
class KhatamStar extends StatelessWidget {
  const KhatamStar({
    super.key,
    required this.size,
    required this.stroke,
    this.fill = Colors.transparent,
    this.strokeWidth = 3,
  });

  final double size;
  final Color fill;
  final Color stroke;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: StarPainter(
            fill: fill,
            stroke: stroke,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    ),
  );
}

/// The eight-point star: sixteen points alternating between an outer and
/// an inner radius, filled, outlined, with a ring at its heart.
class StarPainter extends CustomPainter {
  const StarPainter({
    required this.fill,
    required this.stroke,
    this.strokeWidth = 3,
  });

  final Color fill;
  final Color stroke;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - strokeWidth / 2 - 0.5;
    final inner = outer * 0.72;
    final path = Path();
    for (var k = 0; k < 16; k++) {
      final r = k.isEven ? outer : inner;
      final p = center + Offset.fromDirection(k * math.pi / 8 - math.pi / 2, r);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    if (fill.a > 0) canvas.drawPath(path, Paint()..color = fill);
    final line = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);
    canvas.drawCircle(center, inner * 0.45, line);
  }

  @override
  bool shouldRepaint(StarPainter old) =>
      old.fill != fill ||
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth;
}
