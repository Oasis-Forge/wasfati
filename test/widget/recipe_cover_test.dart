// LOOK-10: RecipeCover had no test at all, and nothing pinned
// `tintIndexFor`'s output — a stable hash a refactor (a switch to
// `hashCode`, or another FNV prime) could silently change, recolouring
// every user's covers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/theme/app_theme.dart';
import 'package:wasfati/theme/colors.dart';
import 'package:wasfati/models/settings.dart' show AppStyle;
import 'package:wasfati/widgets/recipe_cover.dart';

void main() {
  group('RecipeCover.tintIndexFor (FNV-1a, pinned against the canonical '
      'test vectors)', () {
    test("'' -> 1 of 6", () {
      expect(RecipeCover.tintIndexFor('', 6), 1);
    });
    test("'a' -> 4 of 6", () {
      expect(RecipeCover.tintIndexFor('a', 6), 4);
    });
    test("'foobar' -> 4 of 6", () {
      expect(RecipeCover.tintIndexFor('foobar', 6), 4);
    });
    test('a UUID-shaped id is stable too', () {
      expect(
        RecipeCover.tintIndexFor('3fa85f64-5717-4562-b3fc-2c963f66afa6', 6),
        4,
      );
    });
    test('the same id always lands on the same tint', () {
      final a = RecipeCover.tintIndexFor('كبسة لحم', 6);
      final b = RecipeCover.tintIndexFor('كبسة لحم', 6);
      expect(a, b);
    });
  });

  group('RecipeCover (widget)', () {
    Widget pump(Widget child) => MaterialApp(
      theme: wasfatiTheme(AppStyle.saffron, Brightness.light),
      home: Scaffold(body: SizedBox(width: 120, height: 120, child: child)),
    );

    testWidgets('shows the title\'s first letter', (tester) async {
      await tester.pumpWidget(
        pump(const RecipeCover(recipeId: 'r1', title: 'كبسة لحم')),
      );
      expect(find.text('ك'), findsOneWidget);
    });

    testWidgets(
      'draws the letter in the tint\'s own dark tone, never a fixed colour',
      (tester) async {
        await tester.pumpWidget(
          pump(const RecipeCover(recipeId: 'r1', title: 'كبسة لحم')),
        );
        final tints = sufraCoverTints(Brightness.light);
        final tint = tints[RecipeCover.tintIndexFor('r1', tints.length)];
        final letter = tester.widget<Text>(find.text('ك'));
        expect(letter.style!.color, tint.$2);
      },
    );

    testWidgets(
      'in dark, the fill is the dark card colour, never the light pastel '
      'tint (LOOK-10)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: wasfatiTheme(AppStyle.saffron, Brightness.dark),
            home: const Scaffold(
              body: SizedBox(
                width: 120,
                height: 120,
                child: RecipeCover(recipeId: 'r1', title: 'كبسة لحم'),
              ),
            ),
          ),
        );
        final coloredBox = tester.widget<ColoredBox>(find.byType(ColoredBox));
        expect(coloredBox.color, sufraNeutrals(Brightness.dark).card);
      },
    );

    testWidgets('shows "؟" for a blank title', (tester) async {
      await tester.pumpWidget(
        pump(const RecipeCover(recipeId: 'r2', title: '   ')),
      );
      expect(find.text('؟'), findsOneWidget);
    });

    testWidgets('the same recipeId shows the same letter/tint across '
        'rebuilds (LOOK-10: stable per recipe)', (tester) async {
      await tester.pumpWidget(
        pump(const RecipeCover(recipeId: 'same-id', title: 'أ')),
      );
      final firstColor = tester
          .widget<ColoredBox>(find.byType(ColoredBox))
          .color;
      await tester.pumpWidget(
        pump(const RecipeCover(recipeId: 'same-id', title: 'أ')),
      );
      final secondColor = tester
          .widget<ColoredBox>(find.byType(ColoredBox))
          .color;
      expect(firstColor, secondColor);
    });
  });
}
