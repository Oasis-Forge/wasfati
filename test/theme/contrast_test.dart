// LOOK-3, Decision 23: computes the WCAG 2.1 contrast ratio of every
// text/surface and boundary/surface pair سُفرة / Sufra's design actually
// uses, for both accents (زعفران/Saffron, حبر/Ink) and both brightnesses,
// from nothing but [wasfatiColorScheme] and the [Decor] extension
// [wasfatiTheme] attaches, and fails below the bar:
// - body text (ink, ink2, the accent) at least 4.5:1 against every surface
//   it can sit on (page, card, sunk);
// - onPrimary on primary, onAccentSoft on accentSoft, onHerbSoft on
//   herbSoft: at least 4.5:1 — a role's own "on" colour against its fill;
// - the navigation pill's inactive and active colours on its own fill (a
//   fixed dark chrome, independent of the app's own brightness): 4.5:1;
// - white on the photo-card title scrim (design spec §1: a gradient to at
//   least 78% near-black) at its worst case, over a light photo: 4.5:1;
// - each of the six drawn-cover tints' dark tone on its own light tone (the
//   star pattern, the centred letter — large text): 3:1;
// - a control boundary (`outline`) against card and page: 3:1;
// - disabled text (composited exactly as `app_theme.dart` composites it,
//   never Material's default 38%): 3:1.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/settings.dart' show AppStyle;
import 'package:wasfati/theme/app_theme.dart';
import 'package:wasfati/theme/colors.dart';
import 'package:wasfati/theme/decor.dart';

void main() {
  const bodyMin = 4.5;
  const largeMin = 3.0;
  const boundaryMin = 3.0;
  const disabledMin = 3.0;

  for (final style in AppStyle.values) {
    for (final brightness in Brightness.values) {
      final cs = wasfatiColorScheme(style, brightness);
      final n = sufraNeutrals(brightness);
      final decor = wasfatiTheme(style, brightness).extension<Decor>()!;
      final label = '${style.name}/${brightness.name}';

      group(label, () {
        final surfaces = <String, Color>{
          'page': cs.surface,
          'card': cs.surfaceContainerLowest,
          'sunk': decor.sunk,
        };

        // LOOK-3: ink and ink2, as ordinary body text, on every surface the
        // design sits it on.
        final bodyTextColors = <String, Color>{
          'ink': cs.onSurface,
          'ink2': cs.onSurfaceVariant,
        };
        for (final MapEntry(key: textName, value: text)
            in bodyTextColors.entries) {
          for (final MapEntry(key: surfName, value: surf) in surfaces.entries) {
            test('$textName text on $surfName >= $bodyMin:1', () {
              expect(contrastRatio(text, surf), greaterThanOrEqualTo(bodyMin));
            });
          }
        }

        // LOOK-4: the accent as body text — an amount at weight 700 (16sp,
        // not WCAG large text), a `TextButton` label, a floating field
        // label — on the two surfaces it actually sits on this way (page,
        // card): 4.5:1, the same bar as any other body text. It never sits
        // as body text on `sunk` (only as an icon/dot, checked at
        // $largeMin below), so that pair is intentionally excluded here.
        for (final surfName in ['page', 'card']) {
          test('accent text on $surfName >= $bodyMin:1', () {
            expect(
              contrastRatio(cs.primary, surfaces[surfName]!),
              greaterThanOrEqualTo(bodyMin),
            );
          });
        }
        // LOOK-4: the accent as large text/an icon (an active nav dot,
        // >=18.66sp bold) on every surface, `sunk` included: at least 3:1.
        for (final MapEntry(key: surfName, value: surf) in surfaces.entries) {
          test('accent icon/large text on $surfName >= $largeMin:1', () {
            expect(
              contrastRatio(cs.primary, surf),
              greaterThanOrEqualTo(largeMin),
            );
          });
        }

        // LOOK-4: onPrimary on primary (a filled button, e.g. "ابدأ
        // الطبخ"); onAccentSoft on accentSoft (a soft icon circle, a
        // selected chip); onHerbSoft on herbSoft (the "في الخطة" band).
        final onFillPairs = <String, (Color, Color)>{
          'onPrimary/primary': (cs.onPrimary, cs.primary),
          'onAccentSoft/accentSoft (onPrimaryContainer/primaryContainer)': (
            cs.onPrimaryContainer,
            cs.primaryContainer,
          ),
          'onHerbSoft/herbSoft (onSecondaryContainer/secondaryContainer)': (
            cs.onSecondaryContainer,
            cs.secondaryContainer,
          ),
          // The import screen's failure message (`cs.error` body text) and
          // any `errorContainer` fill — dropped from the rewrite.
          'onError/error': (cs.onError, cs.error),
          'onErrorContainer/errorContainer': (
            cs.onErrorContainer,
            cs.errorContainer,
          ),
          // Every SnackBar and its action (app_theme.dart's snackBarTheme):
          // the content text on `inverseSurface`, and the action label
          // (`inversePrimary`) on the same fill.
          'onInverseSurface/inverseSurface (SnackBar text)': (
            cs.onInverseSurface,
            cs.inverseSurface,
          ),
          'inversePrimary/inverseSurface (SnackBar action)': (
            cs.inversePrimary,
            cs.inverseSurface,
          ),
          // A selected `FilterChip`'s label (chipTheme.labelStyle, resolved
          // selected) and a selected `ChoiceChip`'s (secondaryLabelStyle):
          // both `card` on the chip's `selectedColor` fill (`onSurface`).
          'selected chip label (card/onSurface)': (n.card, cs.onSurface),
        };
        for (final MapEntry(key: name, value: pair) in onFillPairs.entries) {
          test('$name >= $bodyMin:1', () {
            expect(
              contrastRatio(pair.$1, pair.$2),
              greaterThanOrEqualTo(bodyMin),
            );
          });
        }

        // LOOK-7: the navigation pill is a fixed dark chrome (light: `ink`;
        // dark: `sunk`), independent of the app's own brightness — its
        // inactive and active colours must clear the bar against it either
        // way.
        test('nav pill inactive on its fill >= $bodyMin:1', () {
          expect(
            contrastRatio(decor.navInactive, decor.navFill),
            greaterThanOrEqualTo(bodyMin),
          );
        });
        test('nav pill active on its fill >= $bodyMin:1', () {
          expect(
            contrastRatio(decor.navActive, decor.navFill),
            greaterThanOrEqualTo(bodyMin),
          );
        });
        // LOOK-7: the selected-tab dot (`nav_pill.dart`'s own
        // `theme.colorScheme.primary`) painted on the pill's fill — a state
        // indicator, not body text: $largeMin:1.
        test('nav dot (accent) on the pill fill >= $largeMin:1', () {
          expect(
            contrastRatio(cs.primary, decor.navFill),
            greaterThanOrEqualTo(largeMin),
          );
        });

        // LOOK-3: `cs.error` used directly as body text (the import
        // screen's failure message, an ingredient-section error line), not
        // just `onError` on the filled `errorContainer`.
        for (final surfName in ['page', 'card']) {
          test('error text on $surfName >= $bodyMin:1', () {
            expect(
              contrastRatio(cs.error, surfaces[surfName]!),
              greaterThanOrEqualTo(bodyMin),
            );
          });
        }

        // LOOK-3: white on a photo card's title scrim — a gradient to at
        // least 78% near-black (rgba(20,14,10,.78), design spec §1) — at
        // its worst case, composited over a light (white) photo.
        test('white on the photo-card title scrim (worst case) '
            '>= $bodyMin:1', () {
          const nearBlack = Color(0xFF14140A);
          final scrimOverWhite = Color.alphaBlend(
            nearBlack.withValues(alpha: 0.78),
            Colors.white,
          );
          expect(
            contrastRatio(Colors.white, scrimOverWhite),
            greaterThanOrEqualTo(bodyMin),
          );
        });

        // LOOK-3: an outlined control's boundary against the two surfaces
        // it can sit on.
        test('outline boundary on card >= $boundaryMin:1', () {
          expect(
            contrastRatio(cs.outline, cs.surfaceContainerLowest),
            greaterThanOrEqualTo(boundaryMin),
          );
        });
        test('outline boundary on page >= $boundaryMin:1', () {
          expect(
            contrastRatio(cs.outline, cs.surface),
            greaterThanOrEqualTo(boundaryMin),
          );
        });

        // LOOK-3: disabled text at least 3:1, never Material's default 38%
        // alpha (composited exactly as app_theme.dart composites it: 55%
        // light / 45% dark, over `card`, where a disabled control sits).
        final disabledAlpha = brightness == Brightness.light ? 0.55 : 0.45;
        final disabledText = Color.alphaBlend(
          cs.onSurface.withValues(alpha: disabledAlpha),
          cs.surfaceContainerLowest,
        );
        test('disabled text on card >= $disabledMin:1', () {
          expect(
            contrastRatio(disabledText, cs.surfaceContainerLowest),
            greaterThanOrEqualTo(disabledMin),
          );
        });
        if (brightness == Brightness.light) {
          test("Material's own 38% default would fail (why LOOK-3 exists)", () {
            final materialDefault = Color.alphaBlend(
              cs.onSurface.withValues(alpha: 0.38),
              cs.surfaceContainerLowest,
            );
            expect(
              contrastRatio(materialDefault, cs.surfaceContainerLowest),
              lessThan(disabledMin),
            );
          });
        }

        // LOOK-3: hint text at full onSurfaceVariant, never faded, on the
        // field fill it actually sits on (`card`).
        test('hint text (full onSurfaceVariant) on the field fill '
            '>= $bodyMin:1', () {
          expect(
            contrastRatio(cs.onSurfaceVariant, cs.surfaceContainerLowest),
            greaterThanOrEqualTo(bodyMin),
          );
        });

        // LOOK-3: a checked checkbox's glyph (`checkboxTheme.checkColor`,
        // `onSecondary`) on its own fill (`secondary`) — a state indicator,
        // not body text: 3:1 (WCAG 1.4.11).
        test('checkbox glyph (onSecondary/secondary) >= $boundaryMin:1', () {
          expect(
            contrastRatio(cs.onSecondary, cs.secondary),
            greaterThanOrEqualTo(boundaryMin),
          );
        });

        // LOOK-3: the switch's "off" thumb (`switchTheme.thumbColor`,
        // `outline`) on its track (`sunk`) — a state indicator: 3:1.
        test('switch off-thumb (outline) on sunk track >= $boundaryMin:1', () {
          expect(
            contrastRatio(cs.outline, n.sunk),
            greaterThanOrEqualTo(boundaryMin),
          );
        });

        // LOOK-3: a disabled `FilledButton`'s label (`disabledColor` on
        // `disabledBackground`, composited exactly as app_theme.dart
        // composites it) — never Material's default 38%.
        final disabledOnSunk = Color.alphaBlend(
          cs.onSurface.withValues(alpha: disabledAlpha),
          n.sunk,
        );
        test('disabled label on disabled fill (filled button) '
            '>= $disabledMin:1', () {
          expect(
            contrastRatio(disabledOnSunk, n.sunk),
            greaterThanOrEqualTo(disabledMin),
          );
        });
      });
    }
  }

  // LOOK-10: the six drawn-cover tints — style/brightness-independent — a
  // dark tone (the star pattern, the centred letter) on its own light tone,
  // as large text.
  group('LOOK-10: cover tints', () {
    final tints = wasfatiTheme(
      AppStyle.saffron,
      Brightness.light,
    ).extension<Decor>()!.coverTints;

    test('there are six', () {
      expect(tints, hasLength(6));
    });

    for (final (i, tint) in tints.indexed) {
      test('tint $i: the dark tone on its light tone >= $largeMin:1', () {
        expect(contrastRatio(tint.$2, tint.$1), greaterThanOrEqualTo(largeMin));
      });
    }

    test('spread across distinct tints (never all the same colour)', () {
      expect(tints.map((t) => t.$1).toSet(), hasLength(6));
    });
  });

  // LOOK-10: the same six covers in dark — the dark `card` fill with each
  // tint's lighter tone drawn on it — never measured before: only the
  // light theme's `coverTints` was read above.
  group('LOOK-10: cover tints (dark)', () {
    final darkTints = wasfatiTheme(
      AppStyle.saffron,
      Brightness.dark,
    ).extension<Decor>()!.coverTints;

    test('there are six', () {
      expect(darkTints, hasLength(6));
    });

    for (final (i, tint) in darkTints.indexed) {
      test('tint $i: its tone on the dark card fill >= $largeMin:1', () {
        expect(contrastRatio(tint.$2, tint.$1), greaterThanOrEqualTo(largeMin));
      });
    }
  });

  // LOOK-3: not just the computed pair, but the colour Flutter actually
  // paints — a disabled `ListTile` (used across Settings) with the real
  // theme, read back from its rendered `RenderParagraph`.
  for (final style in AppStyle.values) {
    for (final brightness in Brightness.values) {
      testWidgets('a disabled ListTile paints its title at $disabledMin:1 '
          '(${style.name}/${brightness.name})', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: wasfatiTheme(style, brightness),
            home: const Scaffold(
              body: ListTile(enabled: false, title: Text('عنوان')),
            ),
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('عنوان'),
        );
        final painted = paragraph.text.style!.color!;
        final cs = wasfatiColorScheme(style, brightness);
        expect(
          contrastRatio(painted, cs.surfaceContainerLowest),
          greaterThanOrEqualTo(disabledMin),
        );
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
