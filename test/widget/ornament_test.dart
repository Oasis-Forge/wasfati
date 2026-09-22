// LOOK-6, must-fix (platform review): CustomPaint never clips its painter,
// so LatticePainter (Saffron's empty-state ornament) used to paint 40dp
// past every edge of the box it was given — straight over EmptyState's own
// heading beneath it. Rendered directly here (not through Ornament/
// CustomPaint), the same way the review's own probe found the bleed, so the
// guarantee holds even for a future caller that skips the widget.
// dart:ui drawing needs a real (non-fake-timer) async zone — tester.runAsync
// — like test/services/recipe_pages_test.dart.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/widgets/ornament.dart';

void main() {
  testWidgets('LatticePainter paints nothing outside its own box', (
    tester,
  ) async {
    const boxSize = 120.0;
    const canvasSize = 300;
    // More than the 40dp cell size on every side, so bleed of up to one
    // whole cell would still land inside the canvas and get counted.
    const inset = (canvasSize - boxSize) / 2;

    late int paintedOutside;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, canvasSize.toDouble(), canvasSize.toDouble()),
      );
      // The box sits centred in the larger, unclipped canvas — exactly the
      // review's own probe: paint at 120x120, look for ink outside it.
      canvas.translate(inset, inset);
      const LatticePainter(color: Color(0xFF000000))
          .paint(canvas, const Size(boxSize, boxSize));
      final picture = recorder.endRecording();
      final image = await picture.toImage(canvasSize, canvasSize);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List();

      paintedOutside = 0;
      for (var y = 0; y < canvasSize; y++) {
        for (var x = 0; x < canvasSize; x++) {
          final localX = x - inset;
          final localY = y - inset;
          final insideBox =
              localX >= 0 &&
              localX < boxSize &&
              localY >= 0 &&
              localY < boxSize;
          if (insideBox) continue;
          final alpha = bytes[(y * canvasSize + x) * 4 + 3];
          if (alpha > 0) paintedOutside++;
        }
      }
    });

    expect(
      paintedOutside,
      0,
      reason:
          'CustomPaint never clips its painter, so LatticePainter must '
          'clip itself to stay inside the box it was given',
    );
  });
}
