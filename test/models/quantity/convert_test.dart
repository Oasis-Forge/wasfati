import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/quantity/arabic_text.dart';
import 'package:wasfati/models/quantity/convert.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/quantity/parser.dart';
import 'package:wasfati/models/quantity/rational.dart';

String show(
  String line, {
  Rational? factor,
  UnitView view = UnitView.asWritten,
}) => formatLine(
  showLine(
    parseIngredient(line),
    factor: factor ?? Rational.one,
    view: view,
  ).line,
  arabic: hasArabic(line),
);

void main() {
  group('SCALE-5 density table', () {
    test('specific names first; Arabic article and plurals match', () {
      expect(densityFor('سكر بني'), Rational(220, 240));
      expect(densityFor('السكر'), Rational(200, 240));
      expect(densityFor('طحين أبيض'), Rational(120, 240));
      expect(densityFor('أرز بسمتي'), Rational(185, 240));
      expect(densityFor('lentils'), Rational(190, 240));
      expect(densityFor('بصل'), isNull);
    });
  });

  group('SCALE-5 conversion', () {
    test('metric: cups of a known ingredient become grams', () {
      expect(show('2 كوب طحين', view: UnitView.metric), '240 غرامًا طحين');
      expect(show('1 cup sugar', view: UnitView.metric), '200 g sugar');
    });
    test('metric: liquids and unknown ingredients become ml, exactly', () {
      expect(
        show('1 كوب مرقة دجاج', view: UnitView.metric),
        '240 مل مرقة دجاج',
      );
      expect(show('2 ملعقة كبيرة خل', view: UnitView.metric), '30 مل خل');
      expect(show('1 cup milk', view: UnitView.metric), '240 ml milk');
      expect(isLiquid('زيت زيتون'), isTrue);
      expect(isLiquid('طحين'), isFalse);
    });
    test('kitchen: ml and grams of known ingredients become cups', () {
      expect(show('240 مل حليب', view: UnitView.kitchen), '1 كوب حليب');
      expect(show('500 g flour', view: UnitView.kitchen), '4⅛ cups flour');
      expect(show('500 غرام لحم', view: UnitView.kitchen), '500 غرامًا لحم');
    });
    test('kitchen: a small amount reads in spoons', () {
      expect(show('15 مل زيت', view: UnitView.kitchen), '1 ملعقة كبيرة زيت');
      expect(show('5 ml vanilla', view: UnitView.kitchen), '1 tsp vanilla');
    });
    test('big metric amounts step up to kg and l', () {
      expect(show('6 كوب طحين', view: UnitView.metric), '720 غرامًا طحين');
      expect(show('10 كوب طحين', view: UnitView.metric), '1.2 كيلو طحين');
      expect(show('5 كوب ماء', view: UnitView.metric), '1.2 لتر ماء');
    });
    test('count units never convert', () {
      expect(show('2 حبة بصل', view: UnitView.metric), '2 حبتان بصل');
      expect(show('3 فص ثوم', view: UnitView.kitchen), '3 فصوص ثوم');
    });
  });

  group('SCALE-2, SCALE-3 scaling', () {
    test('scale, then convert, then round once', () {
      // 1½ cups × 2 = 3 cups = 360 g of flour.
      expect(
        show('1 1/2 كوب طحين', factor: Rational(2), view: UnitView.metric),
        '360 غرامًا طحين',
      );
      expect(show('٣ كوب ارز بسمتي', factor: Rational(2)), '6 أكواب ارز بسمتي');
    });
    test('a to-taste line is kept and flagged not scalable (SCALE-4)', () {
      final s = showLine(parseIngredient('ملح حسب الذوق'), factor: Rational(2));
      expect(s.scalable, isFalse);
      expect(s.line.original, 'ملح حسب الذوق');
    });
    test('×1 as written leaves the line exactly as it was', () {
      final p = parseIngredient('1/3 كوب زيت');
      expect(identical(showLine(p).line, p), isTrue);
    });

    test('exactMin/exactMax carry the pre-rounding value, for groceries to sum '
        'before rounding once (GRO-3, should-fix: double rounding)', () {
      // 1/3 cup × 1/2 = 1/6 cup exactly; SCALE-3's ⅛ step rounds the
      // *display* line to ⅛, but the exact value must survive for a
      // grocery merge to add several scaled lines before rounding.
      final s = showLine(
        parseIngredient('1/3 كوب دقيق'),
        factor: Rational(1, 2),
      );
      expect(s.line.min, Rational(1, 8)); // the rounded display value
      expect(s.exactMin, Rational(1, 6)); // the exact value
    });

    test('exactMin equals the display value at ×1, as written', () {
      final s = showLine(parseIngredient('1/3 كوب زيت'));
      expect(s.exactMin, Rational(1, 3));
      expect(s.exactMin, s.line.min);
    });

    test('a to-taste line has no exactMin either', () {
      final s = showLine(parseIngredient('ملح حسب الذوق'), factor: Rational(2));
      expect(s.exactMin, isNull);
    });
  });
}
