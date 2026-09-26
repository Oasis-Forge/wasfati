import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// LOOK-1/LOOK-6/LOOK-10, Decision 23: what سُفرة / Sufra's one
/// [ColorScheme] cannot carry — the extra neutral (`sunk`), the six drawn
/// covers, the two shadow recipes (empty in dark), the navigation pill's own
/// palette, and the thumbnail shape screens ask for by role rather than
/// repeating a radius. Read through [Decor.of],
/// never by branching on `AppStyle` (LOOK-2: the accent changes only
/// colour).
@immutable
class Decor extends ThemeExtension<Decor> {
  const Decor({
    required this.sunk,
    required this.cardHairline,
    required this.liftShadow,
    required this.floatShadow,
    required this.navFill,
    required this.navBorder,
    required this.navInactive,
    required this.navActive,
    required this.coverTints,
    required this.gutter,
    required this.thumbnailShape,
    required this.amountColor,
    required this.amountWeight,
    required this.rowHairline,
    required this.photoCardRadius,
    required this.photoScrim,
  });

  /// An inset surface, darker/lighter than [ColorScheme.surface]: the
  /// segmented-control track, the stepper pill, a chip at rest, the banner
  /// placeholder, a plan entry's amount pill and the "هذا الأسبوع" chip.
  final Color sunk;

  /// Dark mode's 1dp card edge, replacing the light shadow (LOOK-6): null
  /// in light, where [liftShadow] carries the same job.
  final Color? cardHairline;

  /// The two shadow recipes design spec §1 names (`--lift`/`--float`):
  /// empty in dark, where a hairline stands in instead.
  final List<BoxShadow> liftShadow;
  final List<BoxShadow> floatShadow;

  /// LOOK-7: the floating navigation pill's own palette — always a dark
  /// chrome regardless of the app's own brightness (light: `ink`; dark:
  /// `sunk`, with [navBorder] standing in for the shadow it loses).
  final Color navFill;
  final Color? navBorder;
  final Color navInactive;
  final Color navActive;

  /// LOOK-10: the six drawn-cover tints (a light fill, its dark tone for
  /// the star pattern and the centred letter), style-independent.
  final List<(Color light, Color dark)> coverTints;

  /// The screen gutter (design spec §1: 20dp).
  final double gutter;

  /// A grid/list thumbnail's shape (24dp), read by role rather than each
  /// screen repeating the radius.
  final ShapeBorder thumbnailShape;

  /// LOOK-4: an ingredient amount's colour and weight — the accent at w700,
  /// for both accents alike.
  final Color amountColor;
  final FontWeight amountWeight;

  /// A row separator's colour inside an already-bounded group (never a
  /// control or container edge — that's `outline`, at least 3:1, LOOK-3).
  final Color? rowHairline;

  /// LOOK-3/LOOK-12: the library's photo-forward grid card and a cookbook
  /// tile's collage share this radius (design spec §1: 24dp) — read here
  /// rather than each screen repeating the literal.
  final double photoCardRadius;

  /// LOOK-3: the photo card's bottom scrim over its title — a gradient to
  /// this near-black at 78% alpha (design spec §1) — shared by the same two
  /// cards.
  final Color photoScrim;

  static Decor of(BuildContext context) =>
      Theme.of(context).extension<Decor>()!;

  @override
  Decor copyWith({
    Color? sunk,
    Color? cardHairline,
    bool clearCardHairline = false,
    List<BoxShadow>? liftShadow,
    List<BoxShadow>? floatShadow,
    Color? navFill,
    Color? navBorder,
    bool clearNavBorder = false,
    Color? navInactive,
    Color? navActive,
    List<(Color light, Color dark)>? coverTints,
    double? gutter,
    ShapeBorder? thumbnailShape,
    Color? amountColor,
    FontWeight? amountWeight,
    Color? rowHairline,
    bool clearRowHairline = false,
    double? photoCardRadius,
    Color? photoScrim,
  }) => Decor(
    sunk: sunk ?? this.sunk,
    cardHairline: clearCardHairline
        ? null
        : (cardHairline ?? this.cardHairline),
    liftShadow: liftShadow ?? this.liftShadow,
    floatShadow: floatShadow ?? this.floatShadow,
    navFill: navFill ?? this.navFill,
    navBorder: clearNavBorder ? null : (navBorder ?? this.navBorder),
    navInactive: navInactive ?? this.navInactive,
    navActive: navActive ?? this.navActive,
    coverTints: coverTints ?? this.coverTints,
    gutter: gutter ?? this.gutter,
    thumbnailShape: thumbnailShape ?? this.thumbnailShape,
    amountColor: amountColor ?? this.amountColor,
    amountWeight: amountWeight ?? this.amountWeight,
    rowHairline: clearRowHairline ? null : (rowHairline ?? this.rowHairline),
    photoCardRadius: photoCardRadius ?? this.photoCardRadius,
    photoScrim: photoScrim ?? this.photoScrim,
  );

  @override
  Decor lerp(ThemeExtension<Decor>? other, double t) {
    if (other is! Decor) return this;
    return Decor(
      sunk: Color.lerp(sunk, other.sunk, t) ?? sunk,
      cardHairline: Color.lerp(cardHairline, other.cardHairline, t),
      // Shadow lists step at the midpoint rather than blend box-shadow by
      // box-shadow, same treatment as the shape field below.
      liftShadow: t < 0.5 ? liftShadow : other.liftShadow,
      floatShadow: t < 0.5 ? floatShadow : other.floatShadow,
      navFill: Color.lerp(navFill, other.navFill, t) ?? navFill,
      navBorder: Color.lerp(navBorder, other.navBorder, t),
      navInactive: Color.lerp(navInactive, other.navInactive, t) ?? navInactive,
      navActive: Color.lerp(navActive, other.navActive, t) ?? navActive,
      coverTints: t < 0.5 ? coverTints : other.coverTints,
      gutter: lerpDouble(gutter, other.gutter, t) ?? gutter,
      // ShapeBorder.lerp can return null for two unrelated shape types;
      // step at the midpoint rather than crash or silently keep the wrong
      // shape.
      thumbnailShape:
          ShapeBorder.lerp(thumbnailShape, other.thumbnailShape, t) ??
          (t < 0.5 ? thumbnailShape : other.thumbnailShape),
      amountColor: Color.lerp(amountColor, other.amountColor, t) ?? amountColor,
      amountWeight: t < 0.5 ? amountWeight : other.amountWeight,
      rowHairline: Color.lerp(rowHairline, other.rowHairline, t),
      photoCardRadius:
          lerpDouble(photoCardRadius, other.photoCardRadius, t) ??
          photoCardRadius,
      photoScrim: Color.lerp(photoScrim, other.photoScrim, t) ?? photoScrim,
    );
  }
}
