import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/quantity/parser.dart';
import 'package:wasfati/models/quantity/rational.dart';

/// The QTY-7 table: (line, min, max, unit id, name). Amounts are written as
/// "1/2" or "1.5"; null means no amount (QTY-2). Every new parsing bug found
/// anywhere becomes a row here before it's fixed.
const _table = <(String, String?, String?, String?, String)>[
  // Fatafeat kabsa, imported by ReciMe from the web (competitor analysis).
  ('1 كيلو جرام لحم ضأن', '1', null, 'kg', 'لحم ضأن'),
  ('2 حبة بصل أبيض', '2', null, 'piece', 'بصل أبيض'),
  ('5 ملعقة كبيرة زبدة', '5', null, 'tbsp', 'زبدة'),
  ('1 كوب معجون الطماطم', '1', null, 'cup', 'معجون الطماطم'),
  ('3 عود قرنفل', '3', null, 'stick', 'قرنفل'),
  ('8 حبة هال', '8', null, 'piece', 'هال'),
  ('1/2 ملعقة صغيرة كركم', '1/2', null, 'tsp', 'كركم'),
  ('1/2 حبة برش قشر البرتقال', '1/2', null, 'piece', 'برش قشر البرتقال'),
  ('8 كوب مرقة لحم', '8', null, 'cup', 'مرقة لحم'),
  ('5 فص ثوم', '5', null, 'clove', 'ثوم'),
  ('ملح حسب الذوق', null, null, null, 'ملح'),
  ('رشة زعفران', null, null, 'pinch', 'زعفران'),
  // Fatafeat YouTube Short, imported by ReciMe: Eastern Arabic digits, which
  // ReciMe didn't scale at all.
  ('١ بصل حجم كبير', '1', null, null, 'بصل حجم كبير'),
  ('٣ ملاعق كبيرة زيت نباتي', '3', null, 'tbsp', 'زيت نباتي'),
  ('١ ملعقة صغيرة ثوم مهروس', '1', null, 'tsp', 'ثوم مهروس'),
  ('٢ فلفل حار صحيح', '2', null, null, 'فلفل حار صحيح'),
  ('١ ك لحم غنم قطع', '1', null, 'kg', 'لحم غنم قطع'),
  ('٣ كوب ارز بسمتي', '3', null, 'cup', 'ارز بسمتي'),
  ('١ حزمة صغيرة بقدونس مفروم', '1', null, 'bunch', 'صغيرة بقدونس مفروم'),
  // Instagram caption (S3): number words, no number, Levantine words.
  ('-خمس ملاعق كبيرة زيت نباتي', '5', null, 'tbsp', 'زيت نباتي'),
  ('-حبة بصل مقطعة', '1', null, 'piece', 'بصل مقطعة'),
  ('-كوب جزر مقطع ومقشر', '1', null, 'cup', 'جزر مقطع ومقشر'),
  ('-سبع حبات قرنفل', '7', null, 'piece', 'قرنفل'),
  ('-اثنين حبة بندورة مقطعة', '2', null, 'piece', 'بندورة مقطعة'),
  ('-ملعقة كبيرة ملح', '1', null, 'tbsp', 'ملح'),
  (
    '-اربع اكواب ارز بسمتي منقوع ومغسول',
    '4',
    null,
    'cup',
    'ارز بسمتي منقوع ومغسول',
  ),
  ('-ست اكواب مرق الدجاج.', '6', null, 'cup', 'مرق الدجاج'),
  // TikTok caption (S3): a dual noun means two (QTY-8).
  ('حزمتين ورقيات سلق', '2', null, 'bunch', 'ورقيات سلق'),
  ('ملعقتين كبيرتين طحينة', '2', null, 'tbsp', 'طحينة'),
  ('كوبين ماء', '2', null, 'cup', 'ماء'),
  // Fractions, mixed numbers, ranges, "and a half".
  ('1 1/2 كوب طحين', '3/2', null, 'cup', 'طحين'),
  ('١½ كوب سكر', '3/2', null, 'cup', 'سكر'),
  ('½ كوب حليب', '1/2', null, 'cup', 'حليب'),
  ('نصف كيلو دجاج', '1/2', null, 'kg', 'دجاج'),
  ('ربع كوب زيت', '1/4', null, 'cup', 'زيت'),
  ('كوب ونصف رز', '3/2', null, 'cup', 'رز'),
  ('٢-٣ فصوص ثوم', '2', '3', 'clove', 'ثوم'),
  ('2 إلى 3 حبات طماطم', '2', '3', 'piece', 'طماطم'),
  ('2.5 كغ لحم', '5/2', null, 'kg', 'لحم'),
  ('٢٫٥ لتر ماء', '5/2', null, 'l', 'ماء'),
  ('500 غرام لحم مفروم', '500', null, 'g', 'لحم مفروم'),
  ('250مل حليب', '250', null, 'ml', 'حليب'),
  ('2 م.ك سكر', '2', null, 'tbsp', 'سكر'),
  // Name first, amount after.
  ('ملح: 1 ملعقة صغيرة', '1', null, 'tsp', 'ملح'),
  ('رز بسمتي 3 أكواب', '3', null, 'cup', 'رز بسمتي'),
  // English.
  ('2 cups rice', '2', null, 'cup', 'rice'),
  ('1 tbsp olive oil', '1', null, 'tbsp', 'olive oil'),
  ('salt to taste', null, null, null, 'salt'),
  // QTY-3's oz, lb and fl oz (should-fix, adversary review: merging).
  ('8 oz cheese', '8', null, 'oz', 'cheese'),
  ('1 lb beef', '1', null, 'lb', 'beef'),
  ('4 fl oz milk', '4', null, 'floz', 'milk'),
  // S2: real lines from Arabic recipe websites (cookpad, sayidaty,
  // atyabtabkha, supermama; docs/research/technical-constraints.md).
  ('1/4 كوب كزبرة خضراء', '1/4', null, 'cup', 'كزبرة خضراء'),
  ('زعفران', null, null, null, 'زعفران'),
  (' أرز بسمتي أو أمريكاني', null, null, null, 'أرز بسمتي أو أمريكاني'),
  ('2 بصل', '2', null, null, 'بصل'),
  (
    'كوب و نصف من الماء لكل كوب أرز',
    '3/2',
    null,
    'cup',
    'من الماء لكل كوب أرز',
  ),
  ('معكرونة 500 غراماً', '500', null, 'g', 'معكرونة'),
  ('زيت الزيتون 3 ملاعق كبيرة', '3', null, 'tbsp', 'زيت الزيتون'),
  ('الثوم فصّان مفروم', '2', null, 'clove', 'الثوم مفروم'),
  ('الجزر 1 حبة مبشور', '1', null, 'piece', 'الجزر مبشور'),
  (' كوبان ونصف دقيق', '5/2', null, 'cup', 'دقيق'),
  (
    'مقطّعة إلى مكعبات صغيرة  200 غرام زبدة',
    '200',
    null,
    'g',
    'مقطّعة إلى مكعبات صغيرة زبدة',
  ),
  (' ربع ملعقة صغيرة قرفة مطحونة', '1/4', null, 'tsp', 'قرفة مطحونة'),
  ('3 أكواب (450 غرام) دقيق أبيض.', '3', null, 'cup', 'دقيق أبيض'),
  ('¼ 1 كوب (187.5 غرام) سكر أبيض.', '5/4', null, 'cup', 'سكر أبيض'),
  ('½ كوب (125 مل) زيت نباتي.', '1/2', null, 'cup', 'زيت نباتي'),
  ('¼ 1 (312.5 مل) كوب حليب.', '5/4', null, 'cup', 'حليب'),
  ('ملعقة كبيرة (10 غرام) بيكنج باودر.', '1', null, 'tbsp', 'بيكنج باودر'),
  ('رشة ملح.', null, null, 'pinch', 'ملح'),
  // Names that start with a unit's letter are not units.
  ('ليمون', null, null, null, 'ليمون'),
  ('قطع الدجاج', null, null, null, 'قطع الدجاج'),
  ('حبات هال', null, null, null, 'حبات هال'),
  // A bare "0" is a site's placeholder for "no amount given", not the
  // number zero (Known bug found measuring the import server, 23 September
  // 2026): the line has no amount, and a unit after it is still read.
  ('0 ملح', null, null, null, 'ملح'),
  ('٠ فلفل أسود', null, null, null, 'فلفل أسود'),
  ('0 رشة ملح', null, null, 'pinch', 'ملح'),
  ('0 ملح حسب الرغبة', null, null, null, 'ملح'),
  ('ملح 0', null, null, null, 'ملح'),
  // …but a zero that is only part of the amount still reads as a number.
  ('0.5 كوب حليب', '1/2', null, 'cup', 'حليب'),
  ('10 حبات تمر', '10', null, 'piece', 'تمر'),
  ('٠٫٥ كيلو لحم', '1/2', null, 'kg', 'لحم'),
  ('0 1/2 كوب سكر', '1/2', null, 'cup', 'سكر'),
  ('0-1 ملعقة صغيرة شطة', '0', '1', 'tsp', 'شطة'),
  ('٠ - ١ ملعقة صغيرة شطة', '0', '1', 'tsp', 'شطة'),
];

Rational? _r(String? s) {
  if (s == null) return null;
  if (s.contains('/')) {
    final p = s.split('/');
    return Rational(int.parse(p[0]), int.parse(p[1]));
  }
  return Rational.fromDecimal(s);
}

void main() {
  group('QTY-7 table', () {
    for (final (line, min, max, unit, name) in _table) {
      test(line, () {
        final p = parseIngredient(line);
        expect(p.min, _r(min), reason: 'min of "$line" → $p');
        expect(p.max, _r(max), reason: 'max of "$line" → $p');
        expect(p.unitId, unit, reason: 'unit of "$line" → $p');
        expect(p.name, name, reason: 'name of "$line" → $p');
        expect(p.original, line);
      });
    }
  });

  test('QTY-4: parse → show → parse keeps the same amount and unit', () {
    for (final (line, _, _, _, _) in _table) {
      final a = parseIngredient(line);
      final b = parseIngredient(formatLine(a));
      expect(
        (b.min, b.max, b.unitId),
        (a.min, a.max, a.unitId),
        reason: '"$line" → "${formatLine(a)}"',
      );
    }
  });

  group('QTY-5 display', () {
    test('fractions, never 0.5, for kitchen and count units', () {
      expect(formatLine(parseIngredient('1.5 كوب رز')), '1½ كوب رز');
      expect(formatLine(parseIngredient('0.5 حبة كراث')), '½ حبة كراث');
    });
    test('metric shows decimals', () {
      expect(formatLine(parseIngredient('1.25 كغ لحم')), '1.25 كيلو لحم');
    });
    test('Arabic digits when chosen', () {
      expect(
        formatLine(parseIngredient('1 1/2 كوب رز'), digits: DigitStyle.arabic),
        '١½ كوب رز',
      );
    });
    test('QTY-6 unit agrees with the number', () {
      expect(formatLine(parseIngredient('3 كوب رز')), '3 أكواب رز');
      expect(formatLine(parseIngredient('2 كوب رز')), '2 كوبان رز');
      expect(formatLine(parseIngredient('12 كوب ماء')), '12 كوبًا ماء');
    });
  });

  group('SCALE-3 and SCALE-4', () {
    Rational scale(String line, Rational f) =>
        scaleLine(parseIngredient(line), f).line.min!;

    test('Eastern Arabic digits scale (ReciMe left them unchanged)', () {
      expect(scale('٣ كوب ارز بسمتي', Rational(2)), Rational(6));
      expect(scale('١ بصل حجم كبير', Rational(2)), Rational(2));
    });
    test('count units round to ½, never below ½', () {
      expect(scale('1 حبة كراث', Rational.half), Rational.half);
      expect(scale('1 عود قرفة', Rational(1, 3)), Rational.half);
      expect(scale('3 حبات بيض', Rational(1, 2)), Rational(3, 2));
    });
    test('cups and spoons round to ⅛, grams to whole or 5', () {
      expect(scale('1 كوب حليب', Rational(1, 3)), Rational(3, 8));
      expect(scale('250 غرام لحم', Rational(1, 3)), Rational(83));
      expect(scale('500 غرام لحم', Rational(1, 3)), Rational(165));
      expect(scale('10 غرام ملح', Rational(1, 3)), Rational(3));
    });
    test(
      'oz and fl oz round like grams, not to the nearest ½ (should-fix, '
      'adversary review: a new metric unit fell through to the count step)',
      () {
        // 8.3 oz × 2 = 16.6, rounds to the nearest whole number (17), not
        // the nearest ½ a count unit would use.
        expect(scale('8.3 oz cheese', Rational(2)), Rational(17));
        expect(scale('4.2 fl oz milk', Rational(2)), Rational(8));
      },
    );
    test('ranges scale both ends', () {
      final s = scaleLine(parseIngredient('٢-٣ فصوص ثوم'), Rational(2)).line;
      expect((s.min, s.max), (Rational(4), Rational(6)));
    });
    test('to-taste lines are never scaled and say so', () {
      final s = scaleLine(parseIngredient('ملح حسب الذوق'), Rational(2));
      expect(s.scaled, isFalse);
      expect(s.line.min, isNull);
    });
  });

  group('QTY-1: a bare "0" means no amount given', () {
    test('it is never shown, and never scaled up to "½" (SCALE-4)', () {
      final line = parseIngredient('0 ملح');
      expect(formatLine(line), 'ملح');
      final s = scaleLine(line, Rational(2));
      expect(s.scaled, isFalse);
      expect(formatLine(s.line), 'ملح');
    });
    test('a unit after it is still the unit, with no amount', () {
      final line = parseIngredient('0 كوب سكر');
      expect((line.min, line.max, line.unitId), (null, null, 'cup'));
      expect(line.name, 'سكر');
      expect(line.toTaste, isTrue);
    });
    test('a zero inside a range still scales from zero', () {
      final s = scaleLine(parseIngredient('0-2 ملعقة صغيرة شطة'), Rational(2));
      expect(s.scaled, isTrue);
      expect(s.line.max, Rational(4));
    });
  });
}
