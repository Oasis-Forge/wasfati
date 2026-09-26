import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/decor.dart';

/// A timer's ring (COOK-4): a `sunk` track and, in the accent, the starting
/// mark — or, while its timer runs, an arc for the time left ([fraction] of
/// the whole), from the top — around [child]. Shared by cook mode's timer
/// card and the walkthrough's cook page (RUN-4).
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.fraction,
    required this.stroke,
    required this.child,
  });

  /// The time left as a fraction of the whole, 0 to 1; null for a timer
  /// that hasn't started, drawn as the short starting mark.
  final double? fraction;

  /// The stroke, drawn inside the ring's edge.
  final double stroke;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RingPainter(
      track: Decor.of(context).sunk,
      arc: Theme.of(context).colorScheme.primary,
      fraction: fraction,
      stroke: stroke,
    ),
    child: child,
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.track,
    required this.arc,
    required this.fraction,
    required this.stroke,
  });

  final Color track;
  final Color arc;
  final double? fraction;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    final sweep = fraction == null ? 0.08 : 2 * math.pi * fraction!;
    if (sweep > 0) {
      canvas.drawArc(rect, -math.pi / 2, sweep, false, paint..color = arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.track != track ||
      old.arc != arc ||
      old.fraction != fraction ||
      old.stroke != stroke;
}
