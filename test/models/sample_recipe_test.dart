import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/durations.dart';
import 'package:wasfati/models/quantity/convert.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/sample_recipe.dart';

// Matches format.dart's own isolate characters (QTY-5), the same trick
// test/models/recipe_share_test.dart's `_withoutIsolates` uses.
final _lri = String.fromCharCode(0x2066);
final _pdi = String.fromCharCode(0x2069);
String _withoutIsolates(String text) =>
    text.replaceAll(_lri, '').replaceAll(_pdi, '');

/// [line] exactly as the recipe page shows it (QTY-5, SCALE-6) at [factor],
/// with the isolates stripped so the string compares like a person reads it.
String _shown(IngredientLine line, Rational factor) => _withoutIsolates(
  shownLineText(showLine(line.parsed, factor: factor), DigitStyle.arabic),
);

void main() {
  final now = DateTime.utc(2026, 9, 22, 12);

  group('RUN-6: the built-in sample recipe', () {
    test('Arabic: fixed ids, one group, ten lines, one step group, '
        'four steps, and it validates (REC-2)', () {
      final r = sampleRecipe(arabic: true, now: now);
      expect(r.id, 'sample-ar-lentil-soup');
      expect(r.title, 'شوربة عدس');
      expect(r.servings, 4);
      expect(r.prepMinutes, 10);
      expect(r.cookMinutes, 30);
      expect(r.sourceType, SourceType.written);
      expect(r.photoPath, isNull);
      expect(r.validate(), isNull);
      expect(r.notes, contains('وصفة تجريبية'));

      expect(r.ingredients, hasLength(1));
      expect(r.ingredients.single.id, 'sample-ar-lentil-soup-g1');
      final lines = r.ingredients.single.items;
      expect(lines, hasLength(10));
      expect(lines.map((l) => l.id), [
        for (var i = 1; i <= 10; i++) 'sample-ar-lentil-soup-i$i',
      ]);

      expect(r.steps, hasLength(1));
      expect(r.steps.single.id, 'sample-ar-lentil-soup-sg1');
      final steps = r.steps.single.items;
      expect(steps, hasLength(4));
      expect(steps.map((s) => s.id), [
        for (var i = 1; i <= 4; i++) 'sample-ar-lentil-soup-s$i',
      ]);
    });

    test('English: fixed ids and title, and it validates (REC-2)', () {
      final r = sampleRecipe(arabic: false, now: now);
      expect(r.id, 'sample-en-lentil-soup');
      expect(r.title, 'Red lentil soup');
      expect(r.validate(), isNull);
      expect(r.notes, contains('show you around'));
      expect(r.ingredients.single.id, 'sample-en-lentil-soup-g1');
      expect(r.ingredients.single.items.map((l) => l.id), [
        for (var i = 1; i <= 10; i++) 'sample-en-lentil-soup-i$i',
      ]);
      expect(r.steps.single.id, 'sample-en-lentil-soup-sg1');
      expect(r.steps.single.items.map((s) => s.id), [
        for (var i = 1; i <= 4; i++) 'sample-en-lentil-soup-s$i',
      ]);
    });

    // Every line parses (QTY-1, QTY-8): a word amount ("ربع"/no Arabic word
    // in English, but the fraction glyph does the same job), Eastern Arabic
    // digits ("٢"), and Western digits, side by side with a to-taste line
    // that carries no amount at all.
    void expectAmounts(List<IngredientLine> lines) {
      Rational? min(int i) => lines[i - 1].min;
      String? unit(int i) => lines[i - 1].unitId;

      expect(min(1), Rational.one); // 1 cup lentils
      expect(unit(1), 'cup');
      expect(min(2), Rational.half); // ½ onion
      expect(unit(2), isNull);
      expect(min(3), Rational(2)); // 2 cloves garlic (٢ = Eastern digits)
      expect(unit(3), 'clove');
      expect(min(4), Rational.half); // ½ cup diced carrot
      expect(unit(4), 'cup');
      expect(min(5), Rational(2)); // 2 tbsp olive oil
      expect(unit(5), 'tbsp');
      expect(min(6), Rational.one); // 1 tsp cumin
      expect(unit(6), 'tsp');
      expect(min(7), Rational.quarter); // ¼ tsp turmeric ("ربع" is a word)
      expect(unit(7), 'tsp');
      expect(min(8), Rational(5)); // 5 cups water
      expect(unit(8), 'cup');
      expect(min(9), isNull); // salt to taste: no amount (QTY-2)
      expect(min(10), Rational.half); // ½ lemon, juiced
      expect(unit(10), isNull);
    }

    test('Arabic amounts parse correctly', () {
      expectAmounts(
        sampleRecipe(arabic: true, now: now).ingredients.single.items,
      );
    });

    test('English amounts parse the same way', () {
      expectAmounts(
        sampleRecipe(arabic: false, now: now).ingredients.single.items,
      );
    });

    test('the steps carry timers of 5 and 25 minutes (COOK-4)', () {
      for (final arabic in [true, false]) {
        final steps = sampleRecipe(arabic: arabic, now: now).steps.single.items;
        final found = steps.expand((s) => findDurations(s.text)).toList();
        expect(found, [
          const Duration(minutes: 5),
          const Duration(minutes: 25),
        ], reason: 'arabic: $arabic');
      }
    });

    test('scaling ×2 (SCALE-3) via the existing scaleLine/format helpers: '
        '1 كوب → 2, ٢ فص → ٤', () {
      final lines = sampleRecipe(
        arabic: true,
        now: now,
      ).ingredients.single.items;

      final cup = scaleLine(lines[0].parsed, Rational(2)).line;
      expect(cup.unit?.id, 'cup');
      expect(formatAmount(cup.min!, cup.unit), '2');

      final clove = scaleLine(lines[2].parsed, Rational(2)).line;
      expect(clove.unit?.id, 'clove');
      expect(
        formatAmount(clove.min!, clove.unit, digits: DigitStyle.arabic),
        '٤',
      );

      // The word amount ("ربع") scales too, to a fraction glyph.
      final turmeric = scaleLine(lines[6].parsed, Rational(2)).line;
      expect(formatAmount(turmeric.min!, turmeric.unit), '½');
    });

    // should-fix, review: the test above only checks parsed values, never
    // the line the recipe page actually renders through shownLineText/
    // showLine — which is how a mid-line amount ("juice of ½ lemon") used
    // to come out scrambled ("½ juice of lemon") and how an English count
    // noun used to skip its plural ("2 carrot, diced"). This asserts every
    // line's full displayed text, at ×1 (as written) and ×2, in both
    // languages, so a wording change that reads wrong on screen fails here
    // even when the parsed amount and unit are perfectly fine.
    test('every line as the recipe page shows it, at ×1 and ×2, in both '
        'languages (QTY-5, QTY-6, SCALE-3)', () {
      const arX1 = [
        '١ كوب عدس أحمر',
        '½ بصلة مفرومة',
        '٢ فصان ثوم',
        '½ كوب جزر مقطع',
        '٢ ملعقتان كبيرتان زيت زيتون',
        '١ ملعقة صغيرة كمون',
        '¼ ملعقة صغيرة كركم',
        '٥ أكواب ماء',
        'ملح حسب الذوق',
        '½ ليمونة معصورة',
      ];
      const arX2 = [
        '٢ كوبان عدس أحمر',
        '١ بصلة مفرومة',
        '٤ فصوص ثوم',
        '١ كوب جزر مقطع',
        '٤ ملاعق كبيرة زيت زيتون',
        '٢ ملعقتان صغيرتان كمون',
        '½ ملعقة صغيرة كركم',
        '١٠ أكواب ماء',
        'ملح حسب الذوق',
        '١ ليمونة معصورة',
      ];
      const enX1 = [
        '1 cup red lentils',
        '½ onion, chopped',
        '2 cloves garlic',
        '½ cup diced carrot',
        '2 tbsp olive oil',
        '1 tsp cumin',
        '¼ tsp turmeric',
        '5 cups water',
        'salt to taste',
        '½ lemon, juiced',
      ];
      const enX2 = [
        '2 cups red lentils',
        '1 onion, chopped',
        '4 cloves garlic',
        '1 cup diced carrot',
        '4 tbsp olive oil',
        '2 tsp cumin',
        '½ tsp turmeric',
        '10 cups water',
        'salt to taste',
        '1 lemon, juiced',
      ];

      void check(bool arabic, List<String> x1, List<String> x2) {
        final lines = sampleRecipe(
          arabic: arabic,
          now: now,
        ).ingredients.single.items;
        expect(lines, hasLength(10));
        for (final (i, line) in lines.indexed) {
          expect(
            _shown(line, Rational.one),
            x1[i],
            reason: 'arabic=$arabic line #$i at ×1',
          );
          expect(
            _shown(line, Rational(2)),
            x2[i],
            reason: 'arabic=$arabic line #$i at ×2',
          );
        }
      }

      check(true, arX1, arX2);
      check(false, enX1, enX2);
    });
  });
}
