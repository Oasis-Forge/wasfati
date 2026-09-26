import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/theme/type.dart';

/// LOOK-5/COOK-2: the type scale's structural rules, checked directly on
/// the [TextTheme]s rather than trusted from the design doc — every token
/// that can wrap to a second line clears 1.75 line height, every token
/// (wrapping or not) clears 1.50, letter-spacing is 0 everywhere, and
/// `cookStep` is derived from `bodyLarge` so COOK-2's 1.5x floor holds
/// even if `bodyLarge` ever moves.
void main() {
  // Tokens that can wrap to a second line (design-styles.md "Typography",
  // both looks): the headline/title-small/body group.
  const wrapping = <String, TextStyle? Function(TextTheme)>{
    'displaySmall': _displaySmall,
    'headlineMedium': _headlineMedium,
    'headlineSmall': _headlineSmall,
    'titleSmall': _titleSmall,
    'bodyLarge': _bodyLarge,
    'bodyMedium': _bodyMedium,
    'bodySmall': _bodySmall,
  };

  // Single-line chrome: never wraps, so only the 1.50 floor applies.
  const singleLine = <String, TextStyle? Function(TextTheme)>{
    'titleLarge': _titleLarge,
    'titleMedium': _titleMedium,
    'labelLarge': _labelLarge,
    'labelMedium': _labelMedium,
    'labelSmall': _labelSmall,
  };

  final allTokens = {...wrapping, ...singleLine};

  group('Sufra text theme (LOOK-5)', () {
    final textTheme = sufraTextTheme();

    for (final MapEntry(key: token, value: get) in wrapping.entries) {
      test('$token height >= 1.75 (can wrap to a second line)', () {
        final style = get(textTheme);
        expect(style, isNotNull, reason: '$token is missing');
        expect(style!.height, greaterThanOrEqualTo(1.75));
      });
    }

    for (final MapEntry(key: token, value: get) in allTokens.entries) {
      test('$token height >= 1.50 (the font\'s own line box)', () {
        final style = get(textTheme);
        expect(style!.height, greaterThanOrEqualTo(1.50));
      });

      test('$token letterSpacing is 0', () {
        final style = get(textTheme);
        expect(style!.letterSpacing, 0);
      });

      test('$token uses even leading distribution', () {
        final style = get(textTheme);
        expect(style!.leadingDistribution, TextLeadingDistribution.even);
      });
    }

    test('cookStep.fontSize >= bodyLarge.fontSize * 1.5 (COOK-2)', () {
      final step = cookStep(textTheme);
      final bodyLarge = textTheme.bodyLarge!;
      expect(step.fontSize, greaterThanOrEqualTo(bodyLarge.fontSize! * 1.5));
    });

    test('cookStep wraps to a second line at >= 1.75', () {
      expect(cookStep(textTheme).height, greaterThanOrEqualTo(1.75));
    });

    test('cookStep letterSpacing is 0', () {
      expect(cookStep(textTheme).letterSpacing, 0);
    });
  });

  test('cookStep tracks bodyLarge: doubling it doubles the derived size '
      '(COOK-2\'s floor holds even if bodyLarge ever moves)', () {
    final base = sufraTextTheme();
    final doubled = base.copyWith(
      bodyLarge: base.bodyLarge!.copyWith(
        fontSize: base.bodyLarge!.fontSize! * 2,
      ),
    );
    expect(cookStep(doubled).fontSize, cookStep(base).fontSize! * 2);
  });
}

TextStyle? _displaySmall(TextTheme t) => t.displaySmall;
TextStyle? _headlineMedium(TextTheme t) => t.headlineMedium;
TextStyle? _headlineSmall(TextTheme t) => t.headlineSmall;
TextStyle? _titleLarge(TextTheme t) => t.titleLarge;
TextStyle? _titleMedium(TextTheme t) => t.titleMedium;
TextStyle? _titleSmall(TextTheme t) => t.titleSmall;
TextStyle? _bodyLarge(TextTheme t) => t.bodyLarge;
TextStyle? _bodyMedium(TextTheme t) => t.bodyMedium;
TextStyle? _bodySmall(TextTheme t) => t.bodySmall;
TextStyle? _labelLarge(TextTheme t) => t.labelLarge;
TextStyle? _labelMedium(TextTheme t) => t.labelMedium;
TextStyle? _labelSmall(TextTheme t) => t.labelSmall;
