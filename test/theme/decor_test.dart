// should-fix, platform review: Decor.copyWith and Decor.lerp (including the
// clearRowHairline flag no caller passes yet) had no test at all, though
// `wasfatiTheme`'s ThemeExtension list means Flutter calls `lerp` on every
// AnimatedTheme/implicit theme transition.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/theme/decor.dart';

Decor _sample({
  Color sunk = const Color(0xFFEFE8DF),
  Color? cardHairline,
  List<BoxShadow> liftShadow = const [],
  List<BoxShadow> floatShadow = const [],
  Color navFill = const Color(0xFF1F1A15),
  Color? navBorder,
  Color navInactive = const Color(0xFFA89C8F),
  Color navActive = const Color(0xFFFFFFFF),
  List<(Color light, Color dark)> coverTints = const [
    (Color(0xFFDDE8D5), Color(0xFF3F5A36)),
  ],
  double gutter = 20,
  ShapeBorder? thumbnailShape,
  Color amountColor = const Color(0xFF0000FF),
  FontWeight amountWeight = FontWeight.w600,
  Color? rowHairline = const Color(0xFF888888),
  double photoCardRadius = 24,
  Color photoScrim = const Color(0xC7140E0A),
}) => Decor(
  sunk: sunk,
  cardHairline: cardHairline,
  liftShadow: liftShadow,
  floatShadow: floatShadow,
  navFill: navFill,
  navBorder: navBorder,
  navInactive: navInactive,
  navActive: navActive,
  coverTints: coverTints,
  gutter: gutter,
  thumbnailShape: thumbnailShape ?? const RoundedRectangleBorder(),
  amountColor: amountColor,
  amountWeight: amountWeight,
  rowHairline: rowHairline,
  photoCardRadius: photoCardRadius,
  photoScrim: photoScrim,
);

void main() {
  group('Decor.copyWith', () {
    test('with no arguments keeps every field', () {
      final base = _sample(gutter: 20, amountColor: const Color(0xFF0000FF));
      final copy = base.copyWith();
      expect(copy.gutter, base.gutter);
      expect(copy.amountColor, base.amountColor);
      expect(copy.rowHairline, base.rowHairline);
      expect(copy.photoCardRadius, base.photoCardRadius);
      expect(copy.photoScrim, base.photoScrim);
    });

    test('changes only the given field', () {
      final base = _sample(gutter: 20, amountColor: const Color(0xFF0000FF));
      final copy = base.copyWith(gutter: 16);
      expect(copy.gutter, 16);
      expect(copy.amountColor, base.amountColor); // untouched
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

    // Decision 23/LOOK-7/LOOK-10: the ten fields this redesign adds — none
    // of them had a test at all.
    test('with no arguments keeps every Sufra field too', () {
      final base = _sample(
        sunk: const Color(0xFFEFE8DF),
        cardHairline: const Color(0xFF332D27),
        liftShadow: const [BoxShadow(color: Color(0xFF000000))],
        floatShadow: const [BoxShadow(color: Color(0xFF111111))],
        navFill: const Color(0xFF1F1A15),
        navBorder: const Color(0xFF3A332C),
        navInactive: const Color(0xFFA89C8F),
        navActive: const Color(0xFFFFFFFF),
        coverTints: const [(Color(0xFFDDE8D5), Color(0xFF3F5A36))],
        gutter: 20,
      );
      final copy = base.copyWith();
      expect(copy.sunk, base.sunk);
      expect(copy.cardHairline, base.cardHairline);
      expect(copy.liftShadow, base.liftShadow);
      expect(copy.floatShadow, base.floatShadow);
      expect(copy.navFill, base.navFill);
      expect(copy.navBorder, base.navBorder);
      expect(copy.navInactive, base.navInactive);
      expect(copy.navActive, base.navActive);
      expect(copy.coverTints, base.coverTints);
      expect(copy.gutter, base.gutter);
    });

    test('changes only the given Sufra field, e.g. navFill', () {
      final base = _sample(navFill: const Color(0xFF1F1A15));
      final copy = base.copyWith(navFill: const Color(0xFF2B2621));
      expect(copy.navFill, const Color(0xFF2B2621));
      expect(copy.navInactive, base.navInactive); // untouched
    });

    test('clearCardHairline sets it to null even in dark, where a look '
        'always sets one today', () {
      final base = _sample(cardHairline: const Color(0xFF332D27));
      final copy = base.copyWith(clearCardHairline: true);
      expect(copy.cardHairline, isNull);
    });

    test(
      'clearCardHairline wins over a cardHairline passed in the same call',
      () {
        final base = _sample(cardHairline: const Color(0xFF332D27));
        final copy = base.copyWith(
          cardHairline: const Color(0xFF000000),
          clearCardHairline: true,
        );
        expect(copy.cardHairline, isNull);
      },
    );

    test('clearNavBorder sets it to null even in dark, where it always '
        'carries one today', () {
      final base = _sample(navBorder: const Color(0xFF3A332C));
      final copy = base.copyWith(clearNavBorder: true);
      expect(copy.navBorder, isNull);
    });

    test('clearNavBorder wins over a navBorder passed in the same call', () {
      final base = _sample(navBorder: const Color(0xFF3A332C));
      final copy = base.copyWith(
        navBorder: const Color(0xFF000000),
        clearNavBorder: true,
      );
      expect(copy.navBorder, isNull);
    });
  });

  group('Decor.lerp', () {
    test('t=0 returns this side\'s own values', () {
      final a = _sample(
        photoCardRadius: 20,
        amountColor: const Color(0xFFFF0000),
        gutter: 16,
      );
      final b = _sample(
        photoCardRadius: 24,
        amountColor: const Color(0xFF00FF00),
        gutter: 20,
      );
      final result = a.lerp(b, 0);
      expect(result.photoCardRadius, 20);
      expect(result.amountColor, const Color(0xFFFF0000));
      expect(result.gutter, 16);
    });

    test('t=1 returns the other side\'s values', () {
      final a = _sample(photoCardRadius: 20, gutter: 16);
      final b = _sample(photoCardRadius: 24, gutter: 20);
      final result = a.lerp(b, 1);
      expect(result.photoCardRadius, 24);
      expect(result.gutter, 20);
    });

    test('numeric and colour fields interpolate at the midpoint', () {
      final a = _sample(photoCardRadius: 0, gutter: 0);
      final b = _sample(photoCardRadius: 10, gutter: 10);
      final result = a.lerp(b, 0.5);
      expect(result.photoCardRadius, 5);
      expect(result.gutter, 5);
    });

    test('amountWeight steps at the midpoint, never blends', () {
      final a = _sample(amountWeight: FontWeight.w400);
      final b = _sample(amountWeight: FontWeight.w700);
      expect(a.lerp(b, 0.49).amountWeight, FontWeight.w400);
      expect(a.lerp(b, 0.51).amountWeight, FontWeight.w700);
    });

    test('two unrelated shape types step at the midpoint instead of '
        'crashing (a rounded rect vs a bevelled one)', () {
      final a = _sample(thumbnailShape: const RoundedRectangleBorder());
      final b = _sample(thumbnailShape: const BeveledRectangleBorder());
      expect(a.lerp(b, 0.49).thumbnailShape, isA<RoundedRectangleBorder>());
      expect(a.lerp(b, 0.51).thumbnailShape, isA<BeveledRectangleBorder>());
    });

    test('lerp against a non-Decor extension returns this unchanged', () {
      final a = _sample();
      const other = _NotDecor();
      expect(a.lerp(other, 0.5), same(a));
    });

    test('Sufra colour fields (e.g. navFill, navInactive) interpolate at '
        'the midpoint', () {
      final a = _sample(
        navFill: const Color(0xFF000000),
        navInactive: const Color(0xFF000000),
      );
      final b = _sample(
        navFill: const Color(0xFFFFFFFF),
        navInactive: const Color(0xFFFFFFFF),
      );
      final result = a.lerp(b, 0.5);
      expect(
        (result.navFill.r + result.navFill.g + result.navFill.b) / 3,
        closeTo(0.5, 0.01),
      );
      expect(
        (result.navInactive.r + result.navInactive.g + result.navInactive.b) /
            3,
        closeTo(0.5, 0.01),
      );
    });

    test('gutter interpolates like any other numeric field', () {
      final a = _sample(gutter: 0);
      final b = _sample(gutter: 20);
      expect(a.lerp(b, 0.5).gutter, 10);
    });

    test('navBorder (nullable) reaches the exact colour at t=1, and never '
        'crashes lerping from null (light has none, dark always does)', () {
      final a = _sample(navBorder: null);
      final b = _sample(navBorder: const Color(0xFF3A332C));
      expect(a.lerp(b, 1).navBorder, const Color(0xFF3A332C));
      expect(() => a.lerp(b, 0.5), returnsNormally);
    });

    test('coverTints steps at the midpoint, never blends tint by tint', () {
      const tintsA = [(Color(0xFFDDE8D5), Color(0xFF3F5A36))];
      const tintsB = [(Color(0xFFF3DCCB), Color(0xFF7A4B2E))];
      final a = _sample(coverTints: tintsA);
      final b = _sample(coverTints: tintsB);
      expect(a.lerp(b, 0.49).coverTints, tintsA);
      expect(a.lerp(b, 0.51).coverTints, tintsB);
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
