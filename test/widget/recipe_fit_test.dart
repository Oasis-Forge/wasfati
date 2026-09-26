// LOOK-8 on the recipe page and in cook mode, measured with the app's own
// font (the test font's every glyph is 1em square, so it can't show a
// label that would be cut off): nothing is ellipsized at 1.3x on a 360 dp
// phone, the fact tiles keep a number with its unit, and the multipliers
// share the stepper's row where the mockup puts them.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/widgets/segmented_pill.dart';

import 'app_test.dart' show pumpApp, settle, shown;

/// Whether [label]'s paragraph was cut short (an ellipsis).
bool _clipped(WidgetTester tester, Finder label) =>
    (tester.renderObject(label) as RenderParagraph).didExceedMaxLines;

void main() {
  setUpAll(() async {
    final loader = FontLoader('IBMPlexSansArabic');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final bytes = File('assets/fonts/IBMPlexSansArabic-$weight.ttf')
          .readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  group('cook mode\'s bottom controls (LOOK-14, LOOK-8)', () {
    for (final language in [LanguagePref.ar, LanguagePref.en]) {
      for (final scale in [1.0, 1.3]) {
        for (final theme in [ThemePref.light, ThemePref.dark]) {
          for (final withIngredients in [true, false]) {
            final name =
                '${language.name} ${scale}x ${theme.name}, '
                '${withIngredients ? 'with' : 'without'} ingredients';
            testWidgets('$name: "previous" and "next" are never cut off, and '
                '"next" stays the widest', (tester) async {
              final (recipes, settings) = await pumpApp(
                tester,
                language: language,
                textScale: scale,
              );
              await tester.runAsync(() async {
                await settings.update(settings.settings.copyWith(theme: theme));
                final repo = recipes.repository;
                final now = repo.now();
                await recipes.save(
                  Recipe(
                    id: repo.newId(),
                    title: 'عدس',
                    ingredients: [
                      if (withIngredients)
                        Section(
                          id: repo.newId(),
                          items: [
                            IngredientLine.parse(repo.newId(), '2 كوب عدس'),
                          ],
                        ),
                    ],
                    steps: [
                      Section(
                        id: repo.newId(),
                        items: [
                          RecipeStep(id: repo.newId(), text: 'اغسلي العدس.'),
                          RecipeStep(id: repo.newId(), text: 'اطبخيه.'),
                        ],
                      ),
                    ],
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
              });
              await settle(tester);
              await tester.tap(shown('عدس').first);
              await settle(tester);
              await tester.tap(find.byIcon(Icons.play_arrow_rounded));
              await settle(tester);

              final ar = language == LanguagePref.ar;
              final previous = find.text(ar ? 'السابق' : 'Previous');
              final next = find.text(ar ? 'التالي' : 'Next');
              expect(_clipped(tester, previous), isFalse);
              expect(_clipped(tester, next), isFalse);
              // Shrunk to fit, if at all, never below a readable size.
              expect(tester.getSize(previous).height, greaterThan(14));

              double buttonWidth(Finder label) => tester
                  .getSize(
                    find
                        .ancestor(
                          of: label,
                          matching: find.byWidgetPredicate(
                            (w) => w is FilledButton || w is OutlinedButton,
                          ),
                        )
                        .first,
                  )
                  .width;
              expect(buttonWidth(next), greaterThan(buttonWidth(previous)));
            });
          }
        }
      }
    }
  });

  group('the recipe page at 1.3x on a 360 dp phone (LOOK-8)', () {
    for (final language in [LanguagePref.ar, LanguagePref.en]) {
      testWidgets('${language.name}: the unit views are never cut off, and '
          'each fact stays on one line', (tester) async {
        await pumpApp(
          tester,
          language: language,
          textScale: 1.3,
          withRecipe: true,
        );
        await tester.tap(find.text('كبسة لحم'));
        await settle(tester);

        final ar = language == LanguagePref.ar;
        for (final label
            in ar
                ? ['كما كُتبت', 'غ / مل', 'أكواب']
                : ['As written', 'g / ml', 'Cups']) {
          final f = find.descendant(
            of: find.byWidgetPredicate((w) => w is SegmentedPill),
            matching: find.text(label),
          );
          expect(f, findsOneWidget, reason: label);
          expect(_clipped(tester, f), isFalse, reason: label);
        }

        // One line each: no taller than one line at this size.
        final oneLine = 16 * 1.3 * 1.75 + 1;
        for (final value
            in ar
                ? ['60 دقيقة', '120 دقيقة', '6']
                : ['60 min', '120 min', '6']) {
          final f = find.text(value);
          expect(f, findsOneWidget, reason: value);
          expect(tester.getSize(f).height, lessThan(oneLine), reason: value);
        }
      });
    }
  });

  testWidgets('on a 390 dp phone the multipliers sit on the stepper\'s row '
      '(Recipe.dc.html), and scaling never moves them', (tester) async {
    await pumpApp(tester, withRecipe: true);
    tester.view.physicalSize = const Size(1170, 2532); // 390 x 844
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    final stepper = tester.getCenter(find.text('6 حصص'));
    for (final chip in ['×½', '×2', '×3']) {
      expect(
        (tester.getCenter(find.text(chip)).dy - stepper.dy).abs(),
        lessThan(2),
        reason: chip,
      );
    }
    final pill = tester.getCenter(find.text('كما كُتبت'));
    // At ×1 there is no "إعادة" at all, not even a reserved blank line.
    bool resetShown() => find.text('إعادة').hitTestable().evaluate().isNotEmpty;
    expect(resetShown(), isFalse);

    final x2 = tester.getCenter(find.text('×2'));
    await tester.tap(find.text('×2'));
    await settle(tester);

    // The stepper now reads the scaled servings, in the same place.
    final scaled = tester.getCenter(find.text('12 حصة'));
    expect((scaled.dy - stepper.dy).abs(), lessThan(2));
    // The chip just tapped stays under the finger, still on the row.
    final x2After = tester.getCenter(find.text('×2'));
    expect((x2After.dx - x2.dx).abs(), lessThan(1));
    expect((x2After.dy - x2.dy).abs(), lessThan(1));
    for (final chip in ['×½', '×2', '×3']) {
      expect(
        (tester.getCenter(find.text(chip)).dy - scaled.dy).abs(),
        lessThan(2),
        reason: chip,
      );
    }
    // Nothing below moves either, and "إعادة" is shown.
    expect(
      (tester.getCenter(find.text('كما كُتبت')).dy - pill.dy).abs(),
      lessThan(1),
    );
    expect(resetShown(), isTrue);

    // And back: "إعادة" returns to ×1 without moving the row.
    await tester.tap(find.text('إعادة'));
    await settle(tester);
    expect(find.text('6 حصص'), findsOneWidget);
    expect((tester.getCenter(find.text('×2')).dy - x2.dy).abs(), lessThan(1));
    expect(resetShown(), isFalse);
  });
}
