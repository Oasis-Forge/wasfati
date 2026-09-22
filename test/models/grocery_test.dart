import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/aisles.dart';
import 'package:wasfati/models/grocery.dart';
import 'package:wasfati/models/quantity/arabic_text.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/quantity/parser.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/recipe.dart';

final _now = DateTime.utc(2026, 9, 19, 10);
final _lri = String.fromCharCode(0x2066);
final _pdi = String.fromCharCode(0x2069);

/// An amount as a recipe line would parse to (GRO-2, GRO-3): only [min],
/// [max] and [unitId] matter to [totalOf].
GroceryAmount _amt(String line, {String? recipeId}) {
  final p = parseIngredient(line);
  return GroceryAmount(
    id: 'a',
    itemId: 'i',
    min: p.min,
    max: p.max,
    unitId: p.unitId,
    recipeId: recipeId,
    createdAt: _now,
    updatedAt: _now,
  );
}

GroceryItem _item(
  String name, {
  List<GroceryAmount> amounts = const [],
  Aisle aisle = Aisle.produce,
  bool done = false,
}) => GroceryItem(
  id: name,
  name: name,
  normName: groceryKey(name),
  aisle: aisle,
  doneAt: done ? _now : null,
  amounts: amounts,
  createdAt: _now,
  updatedAt: _now,
);

/// [groceryAmountText]/[groceryShareText]'s real formatter, matching
/// `groceries_screen.dart`'s `_amountFormatter`: the name's own language
/// picks Arabic or English agreement (QTY-5, should-fix: three reviews),
/// and only the number is isolated (QTY-5, must-fix: two reviews).
String _realFormat(Rational v, String? unitId, String name) => formatLine(
  ParsedLine(original: '', min: v, unitId: unitId, name: ''),
  arabic: hasArabic(name),
  digits: digitsFor(name, DigitStyle.western),
  isolate: true,
);

void main() {
  group('groceryKey (GRO-3)', () {
    test('normalizes and drops a leading ال from every word', () {
      expect(groceryKey('الطماطم'), groceryKey('طماطم'));
      expect(groceryKey('البصل الأحمر'), groceryKey('بصل احمر'));
    });

    test('collapses spaces', () {
      expect(groceryKey('  بصل   أحمر  '), 'بصل احمر');
    });

    test("names in different languages don't share a key", () {
      expect(groceryKey('Onion'), isNot(groceryKey('بصل')));
    });
  });

  group('isWaterOrIce (GRO-2)', () {
    test('matches a bare water or ice name, in either language', () {
      for (final name in ['ماء', 'مياه', 'water', 'ثلج', 'ice']) {
        expect(isWaterOrIce(name), isTrue, reason: name);
      }
    });

    test('matches water or ice followed by a state word', () {
      for (final name in ['ماء بارد', 'ماء مغلي', 'ice cold', 'water hot']) {
        expect(isWaterOrIce(name), isTrue, reason: name);
      }
    });

    test('matches "مكعبات ثلج" / "ice cubes"', () {
      expect(isWaterOrIce('مكعبات ثلج'), isTrue);
      expect(isWaterOrIce('ice cubes'), isTrue);
    });

    test("doesn't match an ordinary ingredient", () {
      expect(isWaterOrIce('طماطم'), isFalse);
      expect(isWaterOrIce('حليب'), isFalse);
    });

    test("doesn't match a name that merely contains water or ice (must-fix, "
        'adversary and UI reviews: these used to be silently dropped)', () {
      for (final name in [
        'ماء الورد', // rose water: baking aisle
        'ماء الزهر', // orange blossom water
        'ماء جوز الهند', // coconut water
        'rose water',
        'orange blossom water',
        'coconut water',
        'ice cream', // frozen aisle
        'water chestnuts',
      ]) {
        expect(isWaterOrIce(name), isFalse, reason: name);
      }
    });

    test('whether plain "مياه معدنية" (mineral water) counts is a product '
        'call: aisles.dart already lists it as a purchasable drink, so it '
        "isn't treated as water to drop", () {
      expect(isWaterOrIce('مياه معدنية'), isFalse);
      expect(aisleFor('مياه معدنية'), Aisle.drinks);
    });
  });

  group('totalOf (GRO-3)', () {
    test('the same unit adds up: 1 كوب + 2 كوب = 3 أكواب', () {
      expect(totalOf([_amt('1 كوب أرز'), _amt('2 كوب أرز')]), [
        (Rational(3), 'cup'),
      ]);
    });

    test('mass in different units steps up: 1 كغ + 500 غ = 1.5 كغ', () {
      expect(totalOf([_amt('1 كيلو لحم'), _amt('500 غرام لحم')]), [
        (Rational(3, 2), 'kg'),
      ]);
    });

    test(
      'a single small unit steps up past 1,000 too, not only a mix '
      '(must-fix, adversary review: 900 g + 200 g used to stay "1100 g")',
      () {
        expect(totalOf([_amt('900 غرام لحم'), _amt('200 غرام لحم')]), [
          (Rational(11, 10), 'kg'), // 1.1 kg
        ]);
        expect(totalOf([_amt('600 مل حليب'), _amt('500 مل حليب')]), [
          (Rational(11, 10), 'l'), // 1.1 l
        ]);
      },
    );

    test('oz, lb and fl oz merge into the mass/volume family like any other '
        'unit (should-fix, adversary review): 1 lb + 500 g beef', () {
      expect(totalOf([_amt('1 lb beef'), _amt('500 g beef')]), [
        (Rational(955), 'g'), // 453.59237 + 500, rounded to the nearest 5
      ]);
    });

    test(
      'a bare count and a حبة count are the same: 2 بصل + حبة بصل = 3 بصل',
      () {
        expect(totalOf([_amt('2 بصل'), _amt('حبة بصل')]), [
          (Rational(3), null),
        ]);
      },
    );

    test('a range contributes its upper end: 2–3 + 1 = 4', () {
      expect(totalOf([_amt('2-3 بصل'), _amt('1 بصل')]), [(Rational(4), null)]);
    });

    test('anything else stays its own part, and a count part next to another '
        'is labelled "piece" so it never reads as a bare number added to the '
        'other part (should-fix, adversary review): طماطم: 2 حبة + علبة', () {
      expect(totalOf([_amt('2 حبة طماطم'), _amt('علبة طماطم')]), [
        (Rational(2), 'piece'),
        (Rational.one, 'can'),
      ]);
    });

    test('a count-only item stays a bare number, no "piece" label', () {
      expect(totalOf([_amt('2 بصل'), _amt('1 بصل')]), [(Rational(3), null)]);
    });

    test("the parts' order doesn't depend on which amount arrived first "
        '(should-fix, adversary review): mass, then volume, then count, '
        'then other units', () {
      final forward = totalOf([
        _amt('علبة طماطم'), // count/can
        _amt('2 طماطم'), // count/bare
        _amt('500 غرام طماطم'), // mass
      ]);
      final backward = totalOf([
        _amt('500 غرام طماطم'),
        _amt('2 طماطم'),
        _amt('علبة طماطم'),
      ]);
      expect(forward, backward);
      expect(forward, [
        (Rational(500), 'g'),
        (Rational(2), 'piece'),
        (Rational.one, 'can'),
      ]);
    });

    test('volume in different units merges and steps up: cups + ml → ml', () {
      expect(totalOf([_amt('1 كوب حليب'), _amt('100 مل حليب')]), [
        (Rational(340), 'ml'),
      ]);
    });

    test('tbsp and tsp merge into ml, not each other', () {
      expect(totalOf([_amt('2 ملعقة كبيرة زيت'), _amt('1 ملعقة صغيرة زيت')]), [
        (Rational(35), 'ml'),
      ]);
    });

    test('a spoon of unknown size is kept apart from cups (SCALE-5)', () {
      expect(totalOf([_amt('1 كوب زيت'), _amt('1 ملعقة زيت')]), [
        (Rational.one, 'cup'),
        (Rational.one, 'spoon'),
      ]);
    });

    test('a to-taste amount adds nothing', () {
      final withToTaste = totalOf([_amt('ملح حسب الذوق'), _amt('2 كيلو ملح')]);
      expect(withToTaste, [(Rational(2), 'kg')]);
    });

    test('to-taste only: nothing to show, but still listed (QTY-2)', () {
      expect(totalOf([_amt('ملح حسب الذوق')]), [(null, null)]);
    });

    test('no amounts at all: nothing to show', () {
      expect(totalOf(const []), <(Rational?, String?)>[]);
    });

    test('rounds once, at the end, not per amount (SCALE-3)', () {
      // Three thirds of a cup, unrounded, sum to exactly 1 cup. Rounding
      // each 1/3 to the nearest 1/8 first (SCALE-3's cup step) before
      // summing would give 9/8, not 1 — the bug this guards against.
      final parts = totalOf([
        _amt('1/3 كوب دقيق'),
        _amt('1/3 كوب دقيق'),
        _amt('1/3 كوب دقيق'),
      ]);
      expect(parts, [(Rational.one, 'cup')]);
    });
  });

  group('groceryAmountText (GRO-5, GRO-6)', () {
    String format(Rational v, String? unitId, String name) =>
        '${v.isWhole ? v.whole : v.toDouble()}${unitId == null ? '' : ' $unitId'}';

    test('one part: just that part, formatted', () {
      expect(
        groceryAmountText(
          [_amt('2 كيلو طماطم')],
          name: 'طماطم',
          formatAmount: format,
        ),
        '2 kg',
      );
    });

    test('several parts join with " + "; a count part next to another is '
        'labelled (GRO-3, should-fix)', () {
      expect(
        groceryAmountText(
          [_amt('2 حبة طماطم'), _amt('علبة طماطم')],
          name: 'طماطم',
          formatAmount: format,
        ),
        '2 piece + 1 can',
      );
    });

    test('to-taste only: empty, nothing to show (QTY-2)', () {
      expect(
        groceryAmountText(
          [_amt('ملح حسب الذوق')],
          name: 'ملح',
          formatAmount: format,
        ),
        '',
      );
    });

    test('isolates only the number, never the unit with it, so an Arabic '
        'reader sees the unit on the right side of the number (must-fix, two '
        'reviews: the whole amount used to be isolated together)', () {
      expect(
        groceryAmountText(
          [_amt('2 كيلو طماطم')],
          name: 'طماطم',
          formatAmount: _realFormat,
        ),
        '${_lri}2$_pdi كيلو',
      );
    });

    test('an English item name keeps 123 and English unit words, whatever '
        "the app's own digit setting (should-fix, three reviews)", () {
      expect(
        groceryAmountText(
          [_amt('2 كوب flour')],
          name: 'flour',
          formatAmount: _realFormat,
        ),
        '${_lri}2$_pdi cups',
      );
    });
  });

  group('groceryShareText (GRO-6)', () {
    String label(Aisle a) => switch (a) {
      Aisle.produce => 'خضار وفواكه',
      Aisle.meat => 'لحوم ودواجن',
      _ => a.name,
    };
    String format(Rational v, String? unitId, String name) =>
        '${v.isWhole ? v.whole : v.toDouble()}${unitId == null ? '' : ' $unitId'}';

    test('title, aisle headings, one line per item not done', () {
      final items = [
        _item('طماطم', amounts: [_amt('2 حبة طماطم'), _amt('علبة طماطم')]),
        _item('ملح', amounts: [_amt('ملح حسب الذوق')]),
        _item('لحم ضأن', aisle: Aisle.meat, amounts: [_amt('1 كيلو لحم')]),
        _item(
          'دجاج',
          aisle: Aisle.meat,
          amounts: [_amt('1 كيلو دجاج')],
          done: true, // GRO-6: only items not done
        ),
      ];
      final text = groceryShareText(
        items,
        title: 'قائمة التسوق',
        aisleLabel: label,
        formatAmount: format,
      );
      expect(
        text,
        'قائمة التسوق\n\n'
        'خضار وفواكه\n'
        '• '
        '2 piece + 1 can'
        ' طماطم\n'
        '• ملح\n\n'
        'لحوم ودواجن\n'
        '• '
        '1 kg'
        ' لحم ضأن',
      );
      expect(text, isNot(contains('دجاج'))); // the done item is left out
      expect(text, isNot(contains('http'))); // no link (GRO-6)
      expect(text, isNot(contains('وصفاتي'))); // no app name (GRO-6)
    });

    test('with the real Arabic formatter, only the number is isolated, so a '
        'shared line reads the right way (must-fix, two reviews)', () {
      final items = [
        _item('طماطم', amounts: [_amt('2 كيلو طماطم')]),
      ];
      final text = groceryShareText(
        items,
        title: 'قائمة التسوق',
        aisleLabel: label,
        formatAmount: _realFormat,
      );
      expect(text, 'قائمة التسوق\n\nخضار وفواكه\n• ${_lri}2$_pdi كيلو طماطم');
    });

    test("an empty list can't be shared", () {
      expect(
        groceryShareText(
          const [],
          title: 't',
          aisleLabel: label,
          formatAmount: format,
        ),
        '',
      );
      final allDone = [_item('طماطم', done: true)];
      expect(
        groceryShareText(
          allDone,
          title: 't',
          aisleLabel: label,
          formatAmount: format,
        ),
        '',
      );
    });
  });

  group('groceryLinesForRecipe (PLAN-5, GRO-3)', () {
    Recipe recipeWith(List<String> lines) => Recipe(
      id: 'r1',
      title: 'ر',
      servings: 6,
      ingredients: [
        Section(
          id: 's1',
          items: [
            for (final (i, l) in lines.indexed) IngredientLine.parse('i$i', l),
          ],
        ),
      ],
      createdAt: _now,
      updatedAt: _now,
    );

    test('scales each line by factor and drops water/ice (GRO-2)', () {
      final r = recipeWith(['1 كيلو لحم', 'ماء حسب الحاجة', '2 حبة بصل']);
      final lines = groceryLinesForRecipe(r, Rational(2), planEntryId: 'p1');
      expect(lines.map((l) => l.name), ['لحم', 'بصل']);
      expect(lines.first.min, Rational(2));
      expect(lines.every((l) => l.recipeId == 'r1'), isTrue);
      expect(lines.every((l) => l.planEntryId == 'p1'), isTrue);
    });

    test('carries the exact scaled amount, not the rounded display value '
        '(must-fix, two reviews: double rounding)', () {
      // 1/3 cup × 1/6 = 1/18 exactly; the display line would round to a
      // displayable eighth, which a later merge must not be built from.
      final r = recipeWith(['1/3 كوب دقيق']);
      final lines = groceryLinesForRecipe(r, Rational(1, 6));
      expect(lines.single.min, Rational(1, 18));
    });
  });

  group('GroceryItem and GroceryAmount maps', () {
    test('round-trip through toMap/fromMap', () {
      final amount = GroceryAmount(
        id: 'a1',
        itemId: 'i1',
        min: Rational(1, 2),
        max: Rational(3, 4),
        unitId: 'cup',
        recipeId: 'r1',
        planEntryId: 'p1',
        createdAt: _now,
        updatedAt: _now,
      );
      expect(GroceryAmount.fromMap(amount.toMap()).toMap(), amount.toMap());

      final item = GroceryItem(
        id: 'i1',
        name: 'طماطم',
        normName: groceryKey('طماطم'),
        aisle: Aisle.produce,
        doneAt: _now,
        handAdded: true,
        createdAt: _now,
        updatedAt: _now,
      );
      expect(GroceryItem.fromMap(item.toMap()).toMap(), item.toMap());
    });

    test('an unknown stored aisle falls back to أخرى', () {
      final item = GroceryItem.fromMap({
        'id': 'i1',
        'name': 'x',
        'norm_name': 'x',
        'aisle': 'not_a_real_aisle',
        'hand_added': 0,
        'created_at': _now.millisecondsSinceEpoch,
        'updated_at': _now.millisecondsSinceEpoch,
      });
      expect(item.aisle, Aisle.other);
    });
  });
}
