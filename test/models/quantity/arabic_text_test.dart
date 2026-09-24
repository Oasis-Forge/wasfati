// LANG-3, LANG-4, LANG-5 and QTY-5 over the pure text helpers: the digits
// and decimal mark the user reads, what search treats as the same letter,
// and the isolates that keep an amount or a "×2" in order.
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/quantity/arabic_text.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/quantity/units.dart';

final _lri = String.fromCharCode(0x2066);
final _pdi = String.fromCharCode(0x2069);

void main() {
  group('LANG-3: Arabic digits use the Arabic decimal mark', () {
    test('a decimal between two digits takes ٫', () {
      expect(easternDigits('1.5 كغ'), '١٫٥ كغ');
      expect(easternDigits('AED 14.99'), 'AED ١٤٫٩٩');
    });

    test('a step number\'s point, a clock and a range keep their marks', () {
      expect(easternDigits('1. قطّع البصل.'), '١. قطّع البصل.');
      expect(easternDigits('12:05'), '١٢:٠٥');
      expect(easternDigits('30–60'), '٣٠–٦٠');
    });

    test('kg with decimals reads ١٫٥ in Arabic digits, and reads back', () {
      final shown = formatAmount(
        Rational(3, 2),
        unitById('kg'),
        digits: DigitStyle.arabic,
      );
      expect(shown, '١٫٥');
      expect(westernDigits(shown), '1.5'); // the parser reads it back
    });
  });

  group('LANG-5: a scale factor stays left to right', () {
    test('"×½" and "×٢", each in a left-to-right isolate', () {
      expect(factorLabel(Rational.half, DigitStyle.arabic), '$_lri×½$_pdi');
      expect(factorLabel(Rational(2), DigitStyle.arabic), '$_lri×٢$_pdi');
      expect(factorLabel(Rational(2), DigitStyle.western), '$_lri×2$_pdi');
    });
  });

  group('LANG-4, ORG-4: the search key', () {
    void same(String a, String b) => expect(
      searchKey(a),
      searchKey(b),
      reason: '"$a" and "$b" should match',
    );

    test('every hamza seat of alef is a bare alef: أ إ آ ٱ ا', () {
      for (final form in ['أرز', 'إرز', 'آرز', 'ٱرز']) {
        same(form, 'ارز');
      }
    });

    test('taa marbuta and haa are one letter', () {
      same('كبسة', 'كبسه');
    });

    test('alef maqsura and yaa are one letter', () {
      same('حلوى', 'حلوي');
      same('مشوى', 'مشوي');
    });

    test('hamza on waw and yaa seats, tashkeel, shadda, sukun and tatweel', () {
      same('مؤونة', 'موونه');
      same('شِوَاءٌ', 'شواء');
      same('مُحَمَّصْ', 'محمص');
      same('كـــبسة', 'كبسه');
      same('بطاطا مقلية', 'بطاطا مقليّة');
      same('ماء', 'مآء');
      same('شئ', 'شي');
    });

    test('Quranic and small Arabic marks are ignored', () {
      same('بسم${String.fromCharCode(0x0610)}', 'بسم');
      same('قال${String.fromCharCode(0x06D6)}', 'قال');
    });

    test('a Persian keyboard\'s yeh and kaf match Arabic ي and ك', () {
      same('کیک', 'كيك');
    });

    test('Latin case and accents are ignored', () {
      same('Crème Brûlée', 'creme brulee');
      same('JALAPEÑO', 'jalapeno');
      same('Smørrebrød', 'smorrebrod');
      same('Straße', 'strasse');
      same('Œufs', 'oeufs');
    });

    test('the Turkish dotted and dotless i match i and I', () {
      same('İçli köfte', 'icli kofte');
      same('ıspanak', 'ISPANAK');
      same('Işık', 'isik');
    });

    test('digits match in either style', () {
      same('كيك ٣ طبقات', 'كيك 3 طبقات');
    });

    test('different words stay different (no dictionary, ORG-4)', () {
      expect(searchKey('طماطم'), isNot(searchKey('بندورة')));
      expect(searchKey('cafe'), isNot(searchKey('cake')));
    });
  });
}
