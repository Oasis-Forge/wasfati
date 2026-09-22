import 'package:flutter/material.dart';

import '../models/settings.dart' show AppStyle;

/// LOOK-5: one family, IBM Plex Sans Arabic (already bundled, weights
/// 400-700), letter-spacing 0 on every token and even leading — Flutter's
/// default `TextLeadingDistribution.proportional` hands ~72% of the extra
/// leading to the ascent and starves the descent band where Arabic bowls
/// live. Two line heights, both derived from the font's own metrics rather
/// than taste (design-styles.md "Typography", both looks: the font's line
/// box is 1.500em and its ink is 1.729em tall at most, so two stacked
/// lines cannot collide at that distance): 1.75 on any token that can wrap
/// to a second line, 1.50 on single-line chrome. Matches the literal
/// string `app.dart`'s own `fontFamily` constant carries.
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

/// حبر / Ink's scale (design-styles.md lines 99-113).
TextTheme inkTextTheme() => TextTheme(
  displaySmall: _style(size: 30, weight: FontWeight.w700, height: 1.75),
  headlineMedium: _style(size: 26, weight: FontWeight.w600, height: 1.75),
  headlineSmall: _style(size: 22, weight: FontWeight.w600, height: 1.75),
  titleLarge: _style(size: 20, weight: FontWeight.w600, height: 1.50),
  titleMedium: _style(size: 17, weight: FontWeight.w600, height: 1.50),
  titleSmall: _style(size: 15, weight: FontWeight.w600, height: 1.75),
  bodyLarge: _style(size: 17, weight: FontWeight.w400, height: 1.75),
  bodyMedium: _style(size: 15, weight: FontWeight.w400, height: 1.75),
  bodySmall: _style(size: 13, weight: FontWeight.w400, height: 1.75),
  labelLarge: _style(size: 15, weight: FontWeight.w600, height: 1.50),
  labelMedium: _style(size: 13, weight: FontWeight.w600, height: 1.50),
  labelSmall: _style(size: 12, weight: FontWeight.w600, height: 1.50),
);

/// زعفران / Saffron's scale (design-styles.md lines 310-323): every label
/// and button token one step larger than Ink's, because this look is read
/// on a counter at arm's length.
TextTheme saffronTextTheme() => TextTheme(
  displaySmall: _style(size: 32, weight: FontWeight.w700, height: 1.75),
  headlineMedium: _style(size: 26, weight: FontWeight.w700, height: 1.75),
  headlineSmall: _style(size: 22, weight: FontWeight.w700, height: 1.75),
  titleLarge: _style(size: 20, weight: FontWeight.w700, height: 1.50),
  titleMedium: _style(size: 18, weight: FontWeight.w600, height: 1.50),
  titleSmall: _style(size: 16, weight: FontWeight.w700, height: 1.75),
  bodyLarge: _style(size: 17, weight: FontWeight.w400, height: 1.75),
  bodyMedium: _style(size: 15, weight: FontWeight.w400, height: 1.75),
  bodySmall: _style(size: 13, weight: FontWeight.w400, height: 1.75),
  labelLarge: _style(size: 16, weight: FontWeight.w600, height: 1.50),
  labelMedium: _style(size: 14, weight: FontWeight.w600, height: 1.50),
  labelSmall: _style(size: 12, weight: FontWeight.w600, height: 1.50),
);

/// The structural [TextTheme] for [style] (no colour — `app_theme.dart`
/// applies the look's `ColorScheme` on top, same as Material's own
/// defaults).
TextTheme wasfatiTextTheme(AppStyle style) =>
    style == AppStyle.ink ? inkTextTheme() : saffronTextTheme();

/// COOK-2: cook mode's step text, 1.6× `bodyLarge` rather than a literal
/// size, so the 1.5× floor COOK-2 asks for holds even if `bodyLarge` ever
/// moves (design-styles.md, both looks). `test/theme/type_test.dart`
/// asserts the ratio directly instead of trusting the multiplier.
TextStyle cookStep(TextTheme textTheme) {
  final bodyLarge = textTheme.bodyLarge!;
  return bodyLarge.copyWith(
    fontSize: bodyLarge.fontSize! * 1.6,
    fontWeight: FontWeight.w500,
    height: 1.75,
  );
}
