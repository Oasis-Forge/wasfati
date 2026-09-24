import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/recipe_text.dart';
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/models/quantity/format.dart';

import '../helpers.dart';

void main() {
  group('ingredients text (REC-4, REC-5)', () {
    test('a line ending with ":" starts a named group', () {
      final ids = CountingIds();
      final s = ingredientsFromText(
        '1 كيلو جرام لحم\n٣ كوب ارز\n\nللدقوس:\n2 حبة طماطم\nملح: 1 ملعقة صغيرة',
        const [],
        ids.call,
      );
      expect(s.map((g) => g.name), [null, 'للدقوس']);
      expect(s[0].items.map((l) => l.original), [
        '1 كيلو جرام لحم',
        '٣ كوب ارز',
      ]);
      expect(s[0].items[1].min, Rational(3)); // parsed on the way in
      // "ملح: 1 ملعقة صغيرة" has text after the colon: an ingredient.
      expect(s[1].items.map((l) => l.name), ['طماطم', 'ملح']);
    });

    test('unchanged lines keep their IDs; changed lines get new ones', () {
      final ids = CountingIds();
      final first = ingredientsFromText(
        '1 كوب رز\n2 حبة بصل',
        const [],
        ids.call,
      );
      final again = ingredientsFromText('1 كوب رز\n3 حبة بصل', first, ids.call);
      expect(again.first.id, first.first.id);
      expect(again.first.items[0].id, first.first.items[0].id);
      expect(again.first.items[1].id, isNot(first.first.items[1].id));
    });

    test('an unchanged line keeps what was read from it; an edited one is '
        'read again (REC-5, IMP-15: a translated copy\'s amounts)', () {
      final ids = CountingIds();
      // A translated copy's line: its amount and unit are the original's,
      // beside words the parser would read differently.
      final kept = IngredientLine(
        id: 'line-1',
        original: '2 كوبان أرز بسمتي',
        min: Rational(2),
        unitId: 'cup',
        name: 'أرز بسمتي',
      );
      final odd = IngredientLine(
        id: 'line-2',
        original: 'a handful of rice',
        min: Rational(3),
        unitId: 'tbsp',
        name: 'rice',
      );
      final before = [
        Section(id: 's1', items: [kept, odd]),
      ];
      final again = ingredientsFromText(
        '2 كوبان أرز بسمتي\na handful of rice\n1 كوب ماء',
        before,
        ids.call,
      );
      final lines = again.single.items;
      expect(lines[0], same(kept));
      expect(lines[1].min, Rational(3)); // not re-read from its words
      expect(lines[1].unitId, 'tbsp');
      expect(lines[2].min, Rational(1)); // new text: parsed
      expect(lines[2].unitId, 'cup');

      final edited = ingredientsFromText(
        '2 كوبان أرز بسمتي\na handful of brown rice',
        before,
        ids.call,
      ).single.items;
      expect(edited[1].id, isNot('line-2'));
      expect(edited[1].min, isNull); // edited: read again, no amount
    });

    test('text → sections → text is stable', () {
      const text = '1 كوب رز\n\nللصلصة:\n2 حبة طماطم';
      final s = ingredientsFromText(text, const [], CountingIds().call);
      expect(ingredientsToText(s), text);
    });

    test('an empty named group is dropped', () {
      final s = ingredientsFromText('للصلصة:\n', const [], CountingIds().call);
      expect(s, isEmpty);
    });
  });

  group('steps text (REC-6)', () {
    test('numbering and bullets are removed, one step per line', () {
      final s = stepsFromText(
        '1. يحمر اللحم\n٢- يضاف الأرز\n• يقدم ساخنًا',
        const [],
        CountingIds().call,
      );
      expect(s.single.items.map((x) => x.text), [
        'يحمر اللحم',
        'يضاف الأرز',
        'يقدم ساخنًا',
      ]);
    });
  });

  group('settings', () {
    test('round-trip, and unknown values fall back to defaults', () {
      const s = AppSettings(
        language: LanguagePref.ar,
        digits: DigitStyle.arabic,
        weekStart: WeekStart.saturday,
      );
      expect(AppSettings.fromJson(s.toJson()), s);
      expect(
        AppSettings.fromJson('{"digits":"roman","theme":"dark"}'),
        const AppSettings(theme: ThemePref.dark),
      );
      expect(
        AppSettings.fromJson(null).digits,
        DigitStyle.western,
      ); // Decision 5
    });
  });
}
