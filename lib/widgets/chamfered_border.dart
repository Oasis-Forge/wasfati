import 'dart:math' as math;

import 'package:flutter/material.dart';

/// LOOK-6's Saffron signature: an [OutlinedBorder] (not a plain
/// `ShapeBorder` — `ButtonStyle.shape`, `ChipThemeData.shape` and
/// `CardThemeData.shape` all require one) that cuts the top-start corner at
/// 45° and rounds the other three. Ink never uses this; Saffron applies it
/// through [Decor] fields a screen reads, never a branch on `AppStyle`
/// (LOOK-2).
///
/// The cut's length is `shorterSide * 0.293` — the true regular-octagon
/// ratio (`1 / (2 + √2)`), so the motif is one shape at every size — clamped
/// to 6-18dp (design-styles.md "Shape and spacing"). Which top corner is cut
/// comes from the `textDirection` [paint]/[getOuterPath] are actually
/// called with, never a captured `Directionality`, so the cut lands on the
/// reading-edge corner even inside a sheet or dialog whose direction isn't
/// the ambient one (design-styles.md "The chamfer").
@immutable
class ChamferedBorder extends OutlinedBorder {
  const ChamferedBorder({super.side, this.borderRadius = 12});

  /// The rounding on the three corners that aren't chamfered.
  final double borderRadius;

  static const _minCut = 6.0;
  static const _maxCut = 18.0;
  static const _octagonRatio = 0.292893218813; // 1 / (2 + sqrt(2))

  double _cutFor(Rect rect) =>
      (math.min(rect.width, rect.height) * _octagonRatio).clamp(
        _minCut,
        _maxCut,
      );

  @override
  ChamferedBorder copyWith({BorderSide? side, double? borderRadius}) =>
      ChamferedBorder(
        side: side ?? this.side,
        borderRadius: borderRadius ?? this.borderRadius,
      );

  @override
  ShapeBorder scale(double t) =>
      ChamferedBorder(side: side.scale(t), borderRadius: borderRadius * t);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  /// The boundary path: the top-right corner chamfered in Arabic (the
  /// reading edge starts on the right), the top-left in English, both
  /// traced clockwise so [Path.close] itself draws the diagonal cut.
  Path _pathFor(Rect rect, TextDirection? textDirection) {
    if (rect.isEmpty) return Path();
    final cut = _cutFor(rect);
    final r = borderRadius.clamp(0.0, rect.shortestSide / 2);
    final path = Path();
    if (textDirection == TextDirection.rtl) {
      path
        ..moveTo(rect.left + r, rect.top)
        ..lineTo(rect.right - cut, rect.top)
        ..lineTo(rect.right, rect.top + cut)
        ..lineTo(rect.right, rect.bottom - r)
        ..arcToPoint(
          Offset(rect.right - r, rect.bottom),
          radius: Radius.circular(r),
        )
        ..lineTo(rect.left + r, rect.bottom)
        ..arcToPoint(
          Offset(rect.left, rect.bottom - r),
          radius: Radius.circular(r),
        )
        ..lineTo(rect.left, rect.top + r)
        ..arcToPoint(
          Offset(rect.left + r, rect.top),
          radius: Radius.circular(r),
        )
        ..close();
    } else {
      path
        ..moveTo(rect.left + cut, rect.top)
        ..lineTo(rect.right - r, rect.top)
        ..arcToPoint(
          Offset(rect.right, rect.top + r),
          radius: Radius.circular(r),
        )
        ..lineTo(rect.right, rect.bottom - r)
        ..arcToPoint(
          Offset(rect.right - r, rect.bottom),
          radius: Radius.circular(r),
        )
        ..lineTo(rect.left + r, rect.bottom)
        ..arcToPoint(
          Offset(rect.left, rect.bottom - r),
          radius: Radius.circular(r),
        )
        ..lineTo(rect.left, rect.top + cut)
        ..close();
    }
    return path;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _pathFor(rect.deflate(side.width), textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _pathFor(rect, textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    switch (side.style) {
      case BorderStyle.none:
        return;
      case BorderStyle.solid:
        canvas.drawPath(
          _pathFor(rect.deflate(side.width / 2), textDirection),
          side.toPaint(),
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ChamferedBorder &&
      other.side == side &&
      other.borderRadius == borderRadius;

  @override
  int get hashCode => Object.hash(side, borderRadius);
}
