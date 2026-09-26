import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Kept only so [Decor] still carries a value for old call sites and
/// `test/theme/decor_test.dart`'s copyWith/lerp mechanics; no widget picks
/// between the two paintings by this any more (LOOK-6, Decision 23:
/// `Ornament` always draws the khatam star now).
enum EmptyOrnament { khatam, lattice }

/// LOOK-1/LOOK-6/LOOK-10, Decision 23: what سُفرة / Sufra's one
/// [ColorScheme] cannot carry — the extra neutral (`sunk`), the six drawn
/// covers, the two shadow recipes (empty in dark), the navigation pill's own
/// palette, and the handful of named shapes shared widgets and screens ask
/// for by role rather than repeating a radius. Read through [Decor.of],
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
    required this.photoCardRadius,
    required this.photoScrim,
  });

  /// An inset surface, darker/lighter than [ColorScheme.surface]: the
  /// segmented-control track, the stepper pill, a chip at rest, the banner
  /// placeholder, the plan/settings grouped-row fill.
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

  /// The plan's own "today" highlight bar (unrelated to `RailHeading`,
  /// which no longer draws one, LOOK-6/Decision 23): width in dp and
  /// colour, read directly by `plan_screen.dart`.
  final double railWidth;
  final Color railColor;

  /// Shapes shared widgets and screens read by role rather than repeating a
  /// radius: cards/sheets at 22dp with a hairline side in dark, the recipe
  /// hero photo (full-bleed, square), chips/segmented options as pills, a
  /// primary/secondary button as a pill, and a grid/list thumbnail at 24dp.
  final ShapeBorder cardShape;
  final ShapeBorder photoShape;
  final ShapeBorder chipShape;
  final ShapeBorder buttonShape;
  final ShapeBorder thumbnailShape;

  /// LOOK-4: an ingredient amount's colour and weight — the accent at w700,
  /// for both accents alike.
  final Color amountColor;
  final FontWeight amountWeight;

  /// Decision 23 drops Saffron's one press ledge; kept at 0/transparent so
  /// `PressableSlab` (unchanged) renders every wrapped button flat.
  final double ledgeDepth;
  final Color ledgeColor;

  /// A row separator's colour inside an already-bounded group (never a
  /// control or container edge — that's `outline`, at least 3:1, LOOK-3).
  final Color? rowHairline;

  /// The fill behind a grouped set of rows (a settings group, a day card):
  /// `card`, so a group reads as one white card on the linen page.
  final Color groupedRowFill;

  /// Unused by any widget now (`Ornament` always draws the khatam star);
  /// kept only for `Decor.copyWith`/`Decor.lerp`'s own tests.
  final EmptyOrnament ornament;

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
      // box-shadow, same treatment as the shape fields below.
      liftShadow: t < 0.5 ? liftShadow : other.liftShadow,
      floatShadow: t < 0.5 ? floatShadow : other.floatShadow,
      navFill: Color.lerp(navFill, other.navFill, t) ?? navFill,
      navBorder: Color.lerp(navBorder, other.navBorder, t),
      navInactive: Color.lerp(navInactive, other.navInactive, t) ?? navInactive,
      navActive: Color.lerp(navActive, other.navActive, t) ?? navActive,
      coverTints: t < 0.5 ? coverTints : other.coverTints,
      gutter: lerpDouble(gutter, other.gutter, t) ?? gutter,
      railWidth: lerpDouble(railWidth, other.railWidth, t) ?? railWidth,
      railColor: Color.lerp(railColor, other.railColor, t) ?? railColor,
      // ShapeBorder.lerp can return null for two unrelated shape types;
      // step at the midpoint rather than crash or silently keep the wrong
      // shape.
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
      photoCardRadius:
          lerpDouble(photoCardRadius, other.photoCardRadius, t) ??
          photoCardRadius,
      photoScrim: Color.lerp(photoScrim, other.photoScrim, t) ?? photoScrim,
    );
  }
}
