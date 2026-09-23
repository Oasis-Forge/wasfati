import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Which drawn ornament an empty state uses (LOOK-6): Ink's eight-point
/// khatam star, or Saffron's octagon-and-cross girih lattice. Both are
/// `CustomPainter`s built later, per screen; this only says which one.
enum EmptyOrnament { khatam, lattice }

/// LOOK-2/LOOK-6: what a `ThemeData` cannot carry, so the two looks stay
/// data rather than a fork of the widget tree. Every field here is read by
/// shared widgets through [Decor.of], never by branching on `AppStyle`
/// directly (see "How two looks live in one app",
/// docs/research/design-styles.md lines 456-464).
@immutable
class Decor extends ThemeExtension<Decor> {
  const Decor({
    required this.railWidth,
    required this.railColor,
    required this.cardShape,
    required this.photoShape,
    required this.chipShape,
    required this.buttonShape,
    required this.thumbnailShape,
    required this.amountColor,
    required this.amountWeight,
    required this.ledgeDepth,
    required this.ledgeColor,
    required this.rowHairline,
    required this.groupedRowFill,
    required this.ornament,
  });

  /// The reading-edge section rail (Ink's signature move): its width in dp
  /// and its colour. 0 means no rail is drawn (Saffron, which marks a
  /// heading a different way).
  final double railWidth;
  final Color railColor;

  /// Shapes for hand-built widgets that don't go through a Material
  /// `Card`/`Chip`/button widget (a photo tile, a custom badge) but must
  /// still agree with those widgets' own themed shape.
  final ShapeBorder cardShape;
  final ShapeBorder photoShape;
  final ShapeBorder chipShape;
  final ShapeBorder buttonShape;

  /// A library/grid recipe thumbnail's own shape (added for this pass,
  /// LOOK-6's chamfer family): a plain rounded rect in Ink; Saffron's
  /// `ChamferedBorder`, since "recipe thumbnails" is one of the five things
  /// design-styles.md names for the chamfer. Read with a
  /// [ShapeBorderClipper] (it needs the ambient `TextDirection` to know
  /// which corner is the reading edge).
  final ShapeBorder thumbnailShape;

  /// LOOK-4: an ingredient amount's colour and weight. Ink sets it in
  /// `primary` at w600; Saffron keeps the body colour at w600. Read by
  /// `AmountLine` (built later) after it splits `formatLine`'s output at
  /// its isolate characters, so the amount and the unit word that agrees
  /// with it stay one phrase (QTY-6).
  final Color amountColor;
  final FontWeight amountWeight;

  /// LOOK-7: the one place either look raises anything. 0 means flat
  /// (Ink, and every non-primary control in Saffron); a `PressableSlab`
  /// widget (built later) reads this to draw exactly one 2dp ledge under
  /// Saffron's three primary actions and collapse it on press.
  final double ledgeDepth;
  final Color ledgeColor;

  /// A row separator's colour inside an already-bounded group (never a
  /// control or container edge — that's `outline`, at least 3:1, LOOK-3).
  /// Null means the look draws no such hairline.
  final Color? rowHairline;

  /// The fill behind a grouped set of rows (a settings group, a day card).
  final Color groupedRowFill;

  /// Which ornament `EmptyState` (built later) paints.
  final EmptyOrnament ornament;

  static Decor of(BuildContext context) =>
      Theme.of(context).extension<Decor>()!;

  @override
  Decor copyWith({
    double? railWidth,
    Color? railColor,
    ShapeBorder? cardShape,
    ShapeBorder? photoShape,
    ShapeBorder? chipShape,
    ShapeBorder? buttonShape,
    ShapeBorder? thumbnailShape,
    Color? amountColor,
    FontWeight? amountWeight,
    double? ledgeDepth,
    Color? ledgeColor,
    Color? rowHairline,
    bool clearRowHairline = false,
    Color? groupedRowFill,
    EmptyOrnament? ornament,
  }) => Decor(
    railWidth: railWidth ?? this.railWidth,
    railColor: railColor ?? this.railColor,
    cardShape: cardShape ?? this.cardShape,
    photoShape: photoShape ?? this.photoShape,
    chipShape: chipShape ?? this.chipShape,
    buttonShape: buttonShape ?? this.buttonShape,
    thumbnailShape: thumbnailShape ?? this.thumbnailShape,
    amountColor: amountColor ?? this.amountColor,
    amountWeight: amountWeight ?? this.amountWeight,
    ledgeDepth: ledgeDepth ?? this.ledgeDepth,
    ledgeColor: ledgeColor ?? this.ledgeColor,
    rowHairline: clearRowHairline ? null : (rowHairline ?? this.rowHairline),
    groupedRowFill: groupedRowFill ?? this.groupedRowFill,
    ornament: ornament ?? this.ornament,
  );

  @override
  Decor lerp(ThemeExtension<Decor>? other, double t) {
    if (other is! Decor) return this;
    return Decor(
      railWidth: lerpDouble(railWidth, other.railWidth, t) ?? railWidth,
      railColor: Color.lerp(railColor, other.railColor, t) ?? railColor,
      // ShapeBorder.lerp can return null for two unrelated shape types (a
      // rounded rect vs a future chamfered border); step at the midpoint
      // rather than crash or silently keep the wrong shape.
      cardShape:
          ShapeBorder.lerp(cardShape, other.cardShape, t) ??
          (t < 0.5 ? cardShape : other.cardShape),
      photoShape:
          ShapeBorder.lerp(photoShape, other.photoShape, t) ??
          (t < 0.5 ? photoShape : other.photoShape),
      chipShape:
          ShapeBorder.lerp(chipShape, other.chipShape, t) ??
          (t < 0.5 ? chipShape : other.chipShape),
      buttonShape:
          ShapeBorder.lerp(buttonShape, other.buttonShape, t) ??
          (t < 0.5 ? buttonShape : other.buttonShape),
      thumbnailShape:
          ShapeBorder.lerp(thumbnailShape, other.thumbnailShape, t) ??
          (t < 0.5 ? thumbnailShape : other.thumbnailShape),
      amountColor: Color.lerp(amountColor, other.amountColor, t) ?? amountColor,
      amountWeight: t < 0.5 ? amountWeight : other.amountWeight,
      ledgeDepth: lerpDouble(ledgeDepth, other.ledgeDepth, t) ?? ledgeDepth,
      ledgeColor: Color.lerp(ledgeColor, other.ledgeColor, t) ?? ledgeColor,
      rowHairline: Color.lerp(rowHairline, other.rowHairline, t),
      groupedRowFill:
          Color.lerp(groupedRowFill, other.groupedRowFill, t) ?? groupedRowFill,
      ornament: t < 0.5 ? ornament : other.ornament,
    );
  }
}
