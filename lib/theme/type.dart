import 'package:flutter/material.dart';

/// LOOK-5, Decision 23: سُفرة / Sufra's one type scale, one family — IBM
/// Plex Sans Arabic (already bundled, weights 400-700) — for both accents:
/// the redesign drops the two looks' separate scales along with everything
/// else Decision 14 fixed a layout to. Letter-spacing is 0 on every token
/// and leading is even (Flutter's default `TextLeadingDistribution.
/// proportional` hands ~72% of the extra leading to the ascent and starves
/// the descent band where Arabic bowls live). Two line heights, both from
/// the font's own metrics rather than taste (its line box is 1.500em and
/// its ink is at most 1.729em tall, so two stacked lines never collide at
/// that distance, LOOK-5): 1.75 on any token that can wrap to a second
/// line, 1.50 on single-line chrome — this overrides the design spec's own
/// literal per-token line-heights (1.45/1.6/1.4), which predate LOOK-5's
/// rule. Matches the literal string `app.dart`'s own `fontFamily` constant
/// carries.
const _fontFamily = 'IBMPlexSansArabic';

TextStyle _style({
  required double size,
  required FontWeight weight,
  required double height,
}) => TextStyle(
  fontFamily: _fontFamily,
  fontSize: size,
  fontWeight: weight,
  height: height,
  letterSpacing: 0, // LOOK-5: positive tracking pulls a joined script apart
  leadingDistribution: TextLeadingDistribution.even,
);

/// The design spec's §1 "Type" table, mapped onto Flutter's twelve-slot
/// [TextTheme]: display→displaySmall/displayMedium/displayLarge, titleL→
/// titleLarge/headlineMedium (a screen title, an AppBar title), title→
/// titleMedium/headlineSmall (a section heading), titleS→titleSmall (a card
/// or list item title), body→bodyLarge, bodyS→bodyMedium/bodySmall (a
/// subtitle or meta line), label→labelLarge (a button, a chip), caption→
/// labelMedium/labelSmall (a badge, a navigation-pill label, a counter).
TextTheme sufraTextTheme() => TextTheme(
  displayLarge: _style(size: 30, weight: FontWeight.w700, height: 1.75),
  displayMedium: _style(size: 30, weight: FontWeight.w700, height: 1.75),
  displaySmall: _style(size: 30, weight: FontWeight.w700, height: 1.75),
  headlineLarge: _style(size: 26, weight: FontWeight.w700, height: 1.75),
  headlineMedium: _style(size: 26, weight: FontWeight.w700, height: 1.75),
  headlineSmall: _style(size: 19, weight: FontWeight.w700, height: 1.75),
  titleLarge: _style(size: 26, weight: FontWeight.w700, height: 1.50),
  titleMedium: _style(size: 19, weight: FontWeight.w700, height: 1.50),
  titleSmall: _style(size: 16, weight: FontWeight.w600, height: 1.75),
  bodyLarge: _style(size: 16, weight: FontWeight.w400, height: 1.75),
  bodyMedium: _style(size: 14, weight: FontWeight.w400, height: 1.75),
  bodySmall: _style(size: 13, weight: FontWeight.w400, height: 1.75),
  labelLarge: _style(size: 14, weight: FontWeight.w600, height: 1.50),
  labelMedium: _style(size: 13, weight: FontWeight.w600, height: 1.50),
  labelSmall: _style(size: 12, weight: FontWeight.w600, height: 1.50),
);

/// COOK-2: cook mode's step text, 1.6875x `bodyLarge` (16 -> 27, the
/// design spec's and Cook.dc.html's own value) rather than a literal size, so the 1.5x floor COOK-2 asks for holds even if `bodyLarge` ever
/// moves. `test/theme/type_test.dart` asserts the ratio directly instead of
/// trusting the multiplier.
TextStyle cookStep(TextTheme textTheme) {
  final bodyLarge = textTheme.bodyLarge!;
  return bodyLarge.copyWith(
    fontSize: bodyLarge.fontSize! * 1.6875,
    fontWeight: FontWeight.w500,
    height: 1.75,
  );
}
