// should-fix, platform review: Decor.copyWith and Decor.lerp (including the
// clearRowHairline flag no caller passes yet) had no test at all, though
// `wasfatiTheme`'s ThemeExtension list means Flutter calls `lerp` on every
// AnimatedTheme/implicit theme transition.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/theme/decor.dart';
import 'package:wasfati/widgets/chamfered_border.dart';

Decor _sample({
  double railWidth = 3,
  Color railColor = const Color(0xFFFF0000),
  ShapeBorder? cardShape,
  Color amountColor = const Color(0xFF0000FF),
  FontWeight amountWeight = FontWeight.w600,
  double ledgeDepth = 0,
  Color ledgeColor = Colors.transparent,
  Color? rowHairline = const Color(0xFF888888),
  Color groupedRowFill = const Color(0xFFFFFFFF),
  EmptyOrnament ornament = EmptyOrnament.khatam,
}) => Decor(
  railWidth: railWidth,
  railColor: railColor,
  cardShape: cardShape ?? const RoundedRectangleBorder(),
  photoShape: const RoundedRectangleBorder(),
  chipShape: const RoundedRectangleBorder(),
  buttonShape: const RoundedRectangleBorder(),
  thumbnailShape: const RoundedRectangleBorder(),
  amountColor: amountColor,
  amountWeight: amountWeight,
  ledgeDepth: ledgeDepth,
  ledgeColor: ledgeColor,
  rowHairline: rowHairline,
  groupedRowFill: groupedRowFill,
  ornament: ornament,
);

void main() {
  group('Decor.copyWith', () {
    test('with no arguments keeps every field', () {
      final base = _sample(railWidth: 3, railColor: const Color(0xFFFF0000));
      final copy = base.copyWith();
      expect(copy.railWidth, base.railWidth);
      expect(copy.railColor, base.railColor);
      expect(copy.rowHairline, base.rowHairline);
      expect(copy.ornament, base.ornament);
      expect(copy.ledgeDepth, base.ledgeDepth);
    });

    test('changes only the given field', () {
      final base = _sample(railWidth: 3, railColor: const Color(0xFFFF0000));
      final copy = base.copyWith(railWidth: 4);
      expect(copy.railWidth, 4);
      expect(copy.railColor, base.railColor); // untouched
    });

    test('a new rowHairline replaces the old one', () {
      final base = _sample(rowHairline: const Color(0xFF888888));
      final copy = base.copyWith(rowHairline: const Color(0xFF000000));
      expect(copy.rowHairline, const Color(0xFF000000));
    });

    test('clearRowHairline sets it to null even though a look always sets '
        'one today', () {
      final base = _sample(rowHairline: const Color(0xFF888888));
      final copy = base.copyWith(clearRowHairline: true);
      expect(copy.rowHairline, isNull);
    });

    test(
      'clearRowHairline wins over a rowHairline passed in the same call',
      () {
        final base = _sample(rowHairline: const Color(0xFF888888));
        final copy = base.copyWith(
          rowHairline: const Color(0xFF000000),
          clearRowHairline: true,
        );
        expect(copy.rowHairline, isNull);
      },
    );
  });

  group('Decor.lerp', () {
    test('t=0 returns this side\'s own values', () {
      final a = _sample(
        railWidth: 2,
        railColor: const Color(0xFFFF0000),
        ledgeDepth: 0,
      );
      final b = _sample(
        railWidth: 4,
        railColor: const Color(0xFF00FF00),
        ledgeDepth: 2,
      );
      final result = a.lerp(b, 0);
      expect(result.railWidth, 2);
      expect(result.railColor, const Color(0xFFFF0000));
      expect(result.ledgeDepth, 0);
    });

    test('t=1 returns the other side\'s values', () {
      final a = _sample(railWidth: 2, ledgeDepth: 0);
      final b = _sample(railWidth: 4, ledgeDepth: 2);
      final result = a.lerp(b, 1);
      expect(result.railWidth, 4);
      expect(result.ledgeDepth, 2);
    });

    test('numeric and colour fields interpolate at the midpoint', () {
      final a = _sample(railWidth: 0, ledgeDepth: 0);
      final b = _sample(railWidth: 10, ledgeDepth: 10);
      final result = a.lerp(b, 0.5);
      expect(result.railWidth, 5);
      expect(result.ledgeDepth, 5);
    });

    test('ornament and amountWeight step at the midpoint, never blend', () {
      final a = _sample(
        ornament: EmptyOrnament.khatam,
        amountWeight: FontWeight.w400,
      );
      final b = _sample(
        ornament: EmptyOrnament.lattice,
        amountWeight: FontWeight.w700,
      );
      expect(a.lerp(b, 0.49).ornament, EmptyOrnament.khatam);
      expect(a.lerp(b, 0.51).ornament, EmptyOrnament.lattice);
      expect(a.lerp(b, 0.49).amountWeight, FontWeight.w400);
      expect(a.lerp(b, 0.51).amountWeight, FontWeight.w700);
    });

    test('two unrelated shape types step at the midpoint instead of '
        'crashing (a rounded rect vs a chamfered border)', () {
      final a = _sample(cardShape: const RoundedRectangleBorder());
      final b = _sample(cardShape: const ChamferedBorder());
      expect(a.lerp(b, 0.49).cardShape, isA<RoundedRectangleBorder>());
      expect(a.lerp(b, 0.51).cardShape, isA<ChamferedBorder>());
    });

    test('lerp against a non-Decor extension returns this unchanged', () {
      final a = _sample();
      const other = _NotDecor();
      expect(a.lerp(other, 0.5), same(a));
    });
  });
}

class _NotDecor extends ThemeExtension<Decor> {
  const _NotDecor();
  @override
  ThemeExtension<Decor> copyWith() => this;
  @override
  ThemeExtension<Decor> lerp(ThemeExtension<Decor>? other, double t) => this;
}
