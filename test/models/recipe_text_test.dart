import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/quantity/rational.dart';
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
