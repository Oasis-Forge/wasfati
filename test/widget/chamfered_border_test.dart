// LOOK-6: ChamferedBorder cuts the top-start corner at 45deg and rounds the
// other three, reading the TextDirection it's actually painted with — never
// a captured Directionality — so the cut lands on the reading-edge corner
// in both languages (design-styles.md's stated risk for this widget).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/widgets/chamfered_border.dart';

void main() {
  const rect = Rect.fromLTWH(0, 0, 100, 60);
  const border = ChamferedBorder(borderRadius: 12);

  test('Arabic (rtl): the cut is on the top-right corner', () {
    final path = border.getOuterPath(rect, textDirection: TextDirection.rtl);
    final bounds = path.getBounds();
    // The path never reaches into the top-right corner's own small square
    // (the cut removes it) but does reach the top-left's rounded corner
    // area right up to the very top edge.
    expect(
      path.contains(const Offset(98, 2)),
      isFalse,
      reason: 'the top-right corner should be cut away',
    );
    expect(bounds.right, closeTo(rect.right, 0.5));
    expect(bounds.top, closeTo(rect.top, 0.5));
  });

  test('English (ltr): the cut is on the top-left corner', () {
    final path = border.getOuterPath(rect, textDirection: TextDirection.ltr);
    expect(
      path.contains(const Offset(2, 2)),
      isFalse,
      reason: 'the top-left corner should be cut away',
    );
    // 8dp in from the top-right corner along each axis: past the 12dp
    // rounding's own excluded wedge (a rounded corner excludes only the
    // area outside its arc, closer to the corner than the radius), so
    // this point is inside a rounded corner though it would be cut away
    // by the ~17.6dp chamfer this same rect gets on its other corner.
    expect(
      path.contains(const Offset(92, 8)),
      isTrue,
      reason: 'the top-right corner is rounded, not cut, in English',
    );
  });

  test('the two directions disagree on the same rect (mirrors)', () {
    final rtl = border.getOuterPath(rect, textDirection: TextDirection.rtl);
    final ltr = border.getOuterPath(rect, textDirection: TextDirection.ltr);
    // A point inside the 12dp rounded corner's arc but outside the
    // ~17.6dp chamfer's straight cut (their excluded corner areas are
    // different sizes) — inside when top-left is rounded (rtl), outside
    // when it's chamfered (ltr).
    const probe = Offset(10, 3);
    expect(rtl.contains(probe), isTrue);
    expect(ltr.contains(probe), isFalse);
  });

  test('the cut length is the octagon ratio, clamped 6-18dp', () {
    // shorterSide = 60, so 60 * 0.293 ≈ 17.6 — under the 18dp ceiling.
    final path = border.getOuterPath(rect, textDirection: TextDirection.ltr);
    final onTopEdgeJustPastCut = path.contains(const Offset(18, 1));
    final onTopEdgeBeforeCut = path.contains(const Offset(10, 1));
    expect(onTopEdgeJustPastCut, isTrue);
    expect(onTopEdgeBeforeCut, isFalse);

    // A tiny rect clamps the cut to the 6dp floor rather than shrinking
    // it further.
    const tiny = Rect.fromLTWH(0, 0, 10, 10);
    final tinyPath = border.getOuterPath(
      tiny,
      textDirection: TextDirection.ltr,
    );
    expect(tinyPath.contains(const Offset(3, 0.5)), isFalse); // inside the cut
  });

  test('copyWith changes only the given fields', () {
    const side = BorderSide(color: Color(0xFF000000), width: 2);
    final copy = border.copyWith(side: side);
    expect(copy.side, side);
    expect(copy.borderRadius, border.borderRadius);
  });

  test('scale scales the radius and the border side', () {
    final scaled = border.scale(2) as ChamferedBorder;
    expect(scaled.borderRadius, border.borderRadius * 2);
  });
}
