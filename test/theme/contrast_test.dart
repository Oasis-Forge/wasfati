import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/settings.dart' show AppStyle;
import 'package:wasfati/theme/app_theme.dart';
import 'package:wasfati/theme/colors.dart';

/// LOOK-3: computes the WCAG 2.1 contrast ratio of every text/surface and
/// boundary/surface pair each of the four themes (Ink/Saffron x
/// light/dark) actually uses, from nothing but their [ColorScheme]s, and
/// fails below the bar:
/// - body text: at least 4.5:1 against every surface it can sit on;
/// - large text (a heading, an amount, a big digit): at least 3:1;
/// - a control or container boundary: at least 3:1 (a fill step alone is
///   never enough — LOOK-3 explicitly rejects that);
/// - disabled text (composited exactly as `app_theme.dart` composites it,
///   never Material's default 38%) and hint text (full `onSurfaceVariant`,
///   never faded): at least 3:1.
///
/// The ratio helper below is written from the WCAG 2.1 formula directly —
/// no package.
void main() {
  const bodyMin = 4.5;
  const largeMin = 3.0;
  const boundaryMin = 3.0;
  const disabledMin = 3.0;

  for (final style in AppStyle.values) {
    for (final brightness in Brightness.values) {
      final cs = wasfatiColorScheme(style, brightness);
      final label = '$style/${brightness.name}';

      group(label, () {
        // The warm/cool surface ladder every card, sheet and group fill
        // is drawn on (design-styles.md's "Contrast" section, both looks).
        final ladder = <String, Color>{
          'surface': cs.surface,
          'surfaceContainerLow': cs.surfaceContainerLow,
          'surfaceContainer': cs.surfaceContainer,
          'surfaceContainerHigh': cs.surfaceContainerHigh,
          'surfaceContainerHighest': cs.surfaceContainerHighest,
        };

        // Ordinary reading text: ingredient lines, list titles, dialog and
        // settings body copy (bodyLarge/bodyMedium/bodySmall, w400-500).
        final bodyTextColors = <String, Color>{
          'onSurface': cs.onSurface,
          'onSurfaceVariant': cs.onSurfaceVariant,
        };
        for (final MapEntry(key: textName, value: text)
            in bodyTextColors.entries) {
          for (final MapEntry(key: surfName, value: surf) in ladder.entries) {
            test('body text $textName on $surfName >= $bodyMin:1', () {
              expect(contrastRatio(text, surf), greaterThanOrEqualTo(bodyMin));
            });
          }
        }

        // A role's own "on" colour against its own container/fill — also
        // read as body-sized text (a chip label, a selected settings row,
        // a SnackBar).
        final onContainerPairs = <String, (Color, Color)>{
          'onPrimary/primary': (cs.onPrimary, cs.primary),
          'onPrimaryContainer/primaryContainer': (
            cs.onPrimaryContainer,
            cs.primaryContainer,
          ),
          'onSecondary/secondary': (cs.onSecondary, cs.secondary),
          'onSecondaryContainer/secondaryContainer': (
            cs.onSecondaryContainer,
            cs.secondaryContainer,
          ),
          'onTertiary/tertiary': (cs.onTertiary, cs.tertiary),
          'onTertiaryContainer/tertiaryContainer': (
            cs.onTertiaryContainer,
            cs.tertiaryContainer,
          ),
          'onError/error': (cs.onError, cs.error),
          'onErrorContainer/errorContainer': (
            cs.onErrorContainer,
            cs.errorContainer,
          ),
          'onInverseSurface/inverseSurface (SnackBar)': (
            cs.onInverseSurface,
            cs.inverseSurface,
          ),
          'onSurface/primaryContainer (a selected settings row)': (
            cs.onSurface,
            cs.primaryContainer,
          ),
        };
        for (final MapEntry(key: name, value: pair)
            in onContainerPairs.entries) {
          test('$name >= $bodyMin:1', () {
            expect(
              contrastRatio(pair.$1, pair.$2),
              greaterThanOrEqualTo(bodyMin),
            );
          });
        }

        // LOOK-4: an amount/heading accent used as larger, heavier text —
        // primary, secondary, tertiary and error all appear this way
        // somewhere (the teal/amber amount, a ticked ingredient, "not
        // scaled", a real failure) — 3:1 is the WCAG floor for large text.
        final largeTextColors = <String, Color>{
          'primary': cs.primary,
          'secondary': cs.secondary,
          'tertiary': cs.tertiary,
          'error': cs.error,
        };
        for (final MapEntry(key: textName, value: text)
            in largeTextColors.entries) {
          for (final MapEntry(key: surfName, value: surf) in ladder.entries) {
            test('large text $textName on $surfName >= $largeMin:1', () {
              expect(contrastRatio(text, surf), greaterThanOrEqualTo(largeMin));
            });
          }
        }
        test(
          'inversePrimary/inverseSurface (SnackBar action) >= $largeMin:1',
          () {
            expect(
              contrastRatio(cs.inversePrimary, cs.inverseSurface),
              greaterThanOrEqualTo(largeMin),
            );
          },
        );

        // LOOK-3: "the boundary of a control or container at least 3:1 (a
        // fill step alone never makes a card a card)" — outline is every
        // card/field/chip edge; primary at 2dp is the focus/selection
        // border.
        for (final MapEntry(key: surfName, value: surf) in ladder.entries) {
          test('outline boundary on $surfName >= $boundaryMin:1', () {
            expect(
              contrastRatio(cs.outline, surf),
              greaterThanOrEqualTo(boundaryMin),
            );
          });
          test('primary as a focus/selection border on $surfName '
              '>= $boundaryMin:1', () {
            expect(
              contrastRatio(cs.primary, surf),
              greaterThanOrEqualTo(boundaryMin),
            );
          });
        }

        // should-fix, platform review: a dialog's own border colour is a
        // container boundary (LOOK-3's 3:1 floor) same as a card or field —
        // reads whatever `app_theme.dart` actually put on `DialogThemeData`
        // instead of assuming it's always `outline`, so a future regression
        // (Ink's dialog once used `outlineVariant`, 1.68:1 here) fails this
        // test directly rather than only failing to be caught by it.
        test('dialog boundary on its own fill >= $boundaryMin:1', () {
          final shape = wasfatiTheme(style, brightness).dialogTheme.shape;
          final side = (shape! as OutlinedBorder).side;
          expect(
            contrastRatio(side.color, cs.surfaceContainerLow),
            greaterThanOrEqualTo(boundaryMin),
          );
        });

        // LOOK-3: disabled text at least 3:1, never Material's default
        // 38% alpha (composited exactly as app_theme.dart composites it:
        // 55% light / 45% dark).
        final disabledAlpha = brightness == Brightness.light ? 0.55 : 0.45;
        final disabledText = Color.alphaBlend(
          cs.onSurface.withValues(alpha: disabledAlpha),
          cs.surface,
        );
        test('disabled text on surface >= $disabledMin:1', () {
          expect(
            contrastRatio(disabledText, cs.surface),
            greaterThanOrEqualTo(disabledMin),
          );
        });
        // Documented only for light (design-styles.md: "not M3's 38%,
        // which composites to 2.38:1 in light and fails") — dark surfaces
        // have enough headroom that 38% isn't guaranteed to fail there
        // too, so this illustrative check doesn't overreach into dark.
        if (brightness == Brightness.light) {
          test("Material's own 38% default would fail (why LOOK-3 exists)", () {
            final materialDefault = Color.alphaBlend(
              cs.onSurface.withValues(alpha: 0.38),
              cs.surface,
            );
            expect(
              contrastRatio(materialDefault, cs.surface),
              lessThan(disabledMin),
            );
          });
        }

        // LOOK-3: hint text at full onSurfaceVariant, never faded — checked
        // against the field fill it actually sits on.
        test('hint text (full onSurfaceVariant) on the field fill '
            '>= $bodyMin:1', () {
          expect(
            contrastRatio(cs.onSurfaceVariant, cs.surfaceContainerLow),
            greaterThanOrEqualTo(bodyMin),
          );
        });
      });
    }
  }

  group('contrastRatio helper', () {
    test('black on white is 21:1 (the WCAG maximum)', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    });

    test('a colour against itself is 1:1', () {
      expect(contrastRatio(Colors.red, Colors.red), closeTo(1, 0.0001));
    });

    test('is symmetric', () {
      expect(
        contrastRatio(Colors.white, Colors.black),
        contrastRatio(Colors.black, Colors.white),
      );
    });
  });
}

/// The WCAG 2.1 contrast ratio between two sRGB colours: (L1 + 0.05) /
/// (L2 + 0.05), lighter over darker, where L is relative luminance.
/// https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a) + 0.05;
  final lb = _relativeLuminance(b) + 0.05;
  return la > lb ? la / lb : lb / la;
}

double _relativeLuminance(Color c) {
  final r = _linearize(c.r);
  final g = _linearize(c.g);
  final b = _linearize(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// sRGB channel (0.0-1.0) to linear-light value, per the WCAG formula.
double _linearize(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
