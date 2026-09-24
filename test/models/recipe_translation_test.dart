// Translate a recipe (IMP-14, IMP-15, SRV-11): when it's offered, what is
// sent, and the copy rebuilt from what comes back.
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/durations.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/recipe_text.dart';
import 'package:wasfati/models/recipe_translation.dart';

import '../helpers.dart';

final _now = DateTime.utc(2026, 9, 24, 12);

Recipe _recipe({
  String title = 'Chicken kabsa',
  List<(String?, List<String>)> ingredients = const [],
  List<(String?, List<String>)> steps = const [],
  CountingIds? ids,
}) {
  final id = ids ?? CountingIds(prefix: 'o');
  return Recipe(
    id: 'original',
    title: title,
    sourceUrl: 'https://example.com/kabsa',
    sourceType: SourceType.website,
    servings: 4,
    prepMinutes: 20,
    cookMinutes: 90,
    notes: 'From my aunt.',
    rating: 5,
    cookedCount: 7,
    lastCookedAt: _now,
    cookbookIds: const ['book-1'],
    tags: const ['rice'],
    ingredients: [
      for (final (name, lines) in ingredients)
        Section(
          id: id(),
          name: name,
          items: [for (final l in lines) IngredientLine.parse(id(), l)],
        ),
    ],
    steps: [
      for (final (name, texts) in steps)
        Section(
          id: id(),
          name: name,
          items: [for (final t in texts) RecipeStep(id: id(), text: t)],
        ),
    ],
    createdAt: _now,
    updatedAt: _now,
  );
}

/// An English kabsa, in two groups, with durations in its steps (COOK-4).
Recipe _english() => _recipe(
  ingredients: [
    (
      null,
      [
        '2 cups basmati rice',
        '1 1/2 tsp salt',
        '2-3 tomatoes',
        '2 cups water (480 ml)',
        'salt to taste',
      ],
    ),
    ('For the sauce', ['1 cup yogurt']),
  ],
  steps: [
    (
      null,
      [
        'Soak the rice for 30 minutes.',
        'Cook for 1 hour and 20 minutes.',
        'Serve hot.',
      ],
    ),
  ],
);

/// A fake server (SRV-11) that translates from [dict], and answers every
/// ID sent exactly once unless told otherwise.
List<TranslationItem> _answer(
  List<TranslationItem> sent,
  Map<String, String> dict,
) => [for (final i in sent) (id: i.id, text: dict[i.text] ?? 'ترجمة')];

const _honest = {
  'Chicken kabsa': 'كبسة دجاج',
  'basmati rice': 'أرز بسمتي',
  'salt': 'ملح',
  'tomatoes': 'طماطم',
  'water': 'ماء',
  '480 ml': '480 مل',
  'salt to taste': 'ملح حسب الذوق',
  'For the sauce': 'للصلصة',
  'yogurt': 'زبادي',
  'Soak the rice for 30 minutes.': 'انقعي الأرز لمدة 30 دقيقة.',
  'Cook for 1 hour and 20 minutes.': 'اطبخيه لمدة 1 ساعة و20 دقيقة.',
  'Serve hot.': 'يقدم ساخنًا.',
};

/// Every line's amount, range and unit, in order.
List<(Rational?, Rational?, String?)> _amounts(Recipe r) => [
  for (final s in r.ingredients)
    for (final l in s.items) (l.min, l.max, l.unitId),
];

List<List<Duration>> _timers(Recipe r) => [
  for (final s in r.steps)
    for (final step in s.items) findDurations(step.text),
];

TranslatedRecipe? _apply(Recipe r, List<TranslationItem> returned) =>
    applyTranslation(
      r,
      returned,
      toArabic: true,
      id: 'copy',
      newId: CountingIds(prefix: 'c').call,
      now: _now,
      translatedFrom: r.id,
    );

void main() {
  group('IMP-14: when "ترجم إلى العربية" is offered', () {
    test('an English recipe in an Arabic app is offered; an Arabic one is '
        'not', () {
      expect(offersTranslation(_english(), arabicApp: true), isTrue);
      final arabic = _recipe(
        title: 'كبسة دجاج',
        ingredients: [
          (null, ['2 كوب أرز', '1 حبة بصل']),
        ],
        steps: [
          (null, ['يغسل الأرز.']),
        ],
      );
      expect(offersTranslation(arabic, arabicApp: true), isFalse);
    });

    test('an English app offers "Translate to English" for an Arabic '
        'recipe, and not for an English one', () {
      final arabic = _recipe(
        title: 'كبسة دجاج',
        ingredients: [
          (null, ['2 كوب أرز']),
        ],
      );
      expect(offersTranslation(arabic, arabicApp: false), isTrue);
      expect(offersTranslation(_english(), arabicApp: false), isFalse);
    });

    test('"mostly" means fewer than half of the title, ingredient names and '
        'steps: exactly half in the app\'s script is not offered', () {
      // Arabic title, 1 Arabic line, 2 English lines: 2 of 4 in Arabic.
      final half = _recipe(
        title: 'كبسة',
        ingredients: [
          (null, ['2 كوب أرز', '1 cup yogurt', '2 tomatoes']),
        ],
      );
      expect(offersTranslation(half, arabicApp: true), isFalse);
      // One more English step: 2 of 5.
      final mostlyEnglish = _recipe(
        title: 'كبسة',
        ingredients: [
          (null, ['2 كوب أرز', '1 cup yogurt', '2 tomatoes']),
        ],
        steps: [
          (null, ['Cook the rice.']),
        ],
      );
      expect(offersTranslation(mostlyEnglish, arabicApp: true), isTrue);
    });

    test('text with no letters counts for neither side, and a French recipe '
        'in an English app is already in its script', () {
      final digitsOnly = _recipe(
        title: '1234',
        ingredients: [
          (null, ['250']),
        ],
      );
      expect(offersTranslation(digitsOnly, arabicApp: true), isFalse);
      final french = _recipe(
        title: 'Crème brûlée',
        steps: [
          (null, ['Chauffer la crème.']),
        ],
      );
      expect(offersTranslation(french, arabicApp: false), isFalse);
      expect(offersTranslation(french, arabicApp: true), isTrue);
    });

    test('a word in the other script inside a sentence doesn\'t flip it', () {
      final r = _recipe(
        title: 'Rice with طحينة',
        steps: [
          (null, ['Mix the طحينة with water and lemon juice.']),
        ],
      );
      expect(offersTranslation(r, arabicApp: true), isTrue);
    });
  });

  group('IMP-15: only words are sent, keyed by ID', () {
    test('the title, group names, each read line\'s name and note, an '
        'unread line whole, and each step — never an amount or a unit', () {
      final items = translationItems(_english());
      final texts = [for (final i in items) i.text];
      expect(texts, [
        'Chicken kabsa',
        'basmati rice',
        'salt',
        'tomatoes',
        'water',
        '480 ml', // the bracketed note (QTY-8), as the parser read it
        'salt to taste', // no amount read: sent whole
        'For the sauce',
        'yogurt',
        'Soak the rice for 30 minutes.',
        'Cook for 1 hour and 20 minutes.',
        'Serve hot.',
      ]);
      expect(texts.any((t) => t.contains('cup')), isFalse);
      expect(texts.any((t) => t.contains('tsp')), isFalse);
      expect(items.map((i) => i.id).toSet(), hasLength(items.length));
    });

    test('SRV-11: 300 items and 20,000 characters are the most one request '
        'carries', () {
      List<TranslationItem> of(int n, int size) => [
        for (var i = 0; i < n; i++) (id: 's$i', text: 'x' * size),
      ];
      expect(fitsTranslateLimits(of(300, 10)), isTrue);
      expect(fitsTranslateLimits(of(301, 10)), isFalse);
      expect(fitsTranslateLimits(of(200, 100)), isTrue); // exactly 20,000
      expect(fitsTranslateLimits(of(200, 101)), isFalse);
    });
  });

  group('IMP-15: numbers are compared, whatever the digits', () {
    test(
      'Eastern digits, glyph fractions and word order all compare equal',
      () {
        expect(sameNumbers('Soak for 30 minutes', 'انقعي ٣٠ دقيقة'), isTrue);
        expect(sameNumbers('1½ cups', '1 1/2 كوب'), isTrue);
        expect(
          sameNumbers('bake at 180 for 20', 'اخبزي 20 دقيقة على 180'),
          isTrue,
        );
      },
    );

    test('a changed, added or dropped number does not', () {
      expect(sameNumbers('30 minutes', '45 دقيقة'), isFalse);
      expect(sameNumbers('180°C', '350°F'), isFalse);
      expect(sameNumbers('Serve hot.', 'قدميه لـ 4 أشخاص'), isFalse);
      expect(sameNumbers('Serve 4', 'قدميه'), isFalse);
    });

    test('timers must match too (COOK-4): the same number with another unit '
        'is a different timer', () {
      expect(sameTimers('Cook for 1 hour', 'اطبخيه لمدة ساعة'), isTrue);
      expect(sameTimers('Cook for 20 minutes', 'اطبخيه 20 ثانية'), isFalse);
      expect(sameTimers('Cook for 20 minutes', 'اطبخيه حتى ينضج'), isFalse);
    });
  });

  group('IMP-14, IMP-15: the translated copy', () {
    test('an honest translation: Arabic words, every amount, range and unit '
        'the original\'s own, and the same timers', () {
      final original = _english();
      final out = _apply(
        original,
        _answer(translationItems(original), _honest),
      )!;
      final copy = out.recipe;
      expect(out.keptOriginal, 0);
      expect(copy.title, 'كبسة دجاج');
      expect(copy.ingredients[1].name, 'للصلصة');
      final lines = [for (final s in copy.ingredients) ...s.items];
      expect(
        [for (final l in lines) l.name],
        ['أرز بسمتي', 'ملح', 'طماطم', 'ماء', 'ملح', 'زبادي'],
      );
      expect(lines[3].note, '480 مل');
      expect(lines[4].note, 'حسب الذوق'); // read again from the new words
      expect(_amounts(copy), _amounts(original));
      expect(_timers(copy), _timers(original));
      // The editor's text for each line, in Arabic with the line's own amount.
      expect(lines[0].original, '2 كوبان أرز بسمتي'); // QTY-6's dual
      expect(lines[1].original, '1½ ملعقة صغيرة ملح');
      expect(lines[2].original, '2–3 طماطم');
      expect(lines[3].original, '2 كوبان ماء، 480 مل');
      expect(lines[4].original, 'ملح حسب الذوق');
    });

    test('a fake server that changes numbers: those lines and steps keep '
        'their original text, and the copy\'s amounts, units and timers never '
        'change', () {
      final original = _english();
      final lying = {
        ..._honest,
        '480 ml': '500 مل', // a changed note
        'Soak the rice for 30 minutes.': 'انقعي الأرز لمدة 45 دقيقة.',
        'Cook for 1 hour and 20 minutes.': 'اطبخيه حتى ينضج.', // timer gone
        'salt to taste': 'ملعقة ملح 1', // a number that was never there
        'Chicken kabsa': 'كبسة دجاج لـ 6', // the title too
      };
      final out = _apply(original, _answer(translationItems(original), lying))!;
      final copy = out.recipe;
      expect(out.keptOriginal, 5);
      expect(copy.title, 'Chicken kabsa');
      final lines = [for (final s in copy.ingredients) ...s.items];
      expect(lines[3].original, '2 cups water (480 ml)');
      expect(lines[3].name, 'water');
      expect(lines[4].original, 'salt to taste');
      expect(lines[0].name, 'أرز بسمتي'); // honest lines still translated
      final steps = [for (final s in copy.steps) ...s.items];
      expect(steps.map((s) => s.text), [
        'Soak the rice for 30 minutes.',
        'Cook for 1 hour and 20 minutes.',
        'يقدم ساخنًا.',
      ]);
      expect(_amounts(copy), _amounts(original));
      expect(_timers(copy), _timers(original));
    });

    test('a fake server that slips in a line break or a trailing colon: those '
        'items keep their original text, and saving through the editor '
        '(REC-4) gives back the same lines, groups, steps and amounts', () {
      final original = _english();
      final lying = {
        ..._honest,
        // A second line with an amount in words (QTY-1), hidden in a name.
        'basmati rice': 'أرز بسمتي\nنصف كوب سكر',
        'For the sauce': 'للصلصة\rملعقتان ملح', // and in a group name
        'water': 'ماء ثلاث ملاعق زيت',
        'yogurt': 'زبادي:', // "1 كوب زبادي:" would be a group name
        '480 ml': '480 مل:', // so would a note at the end of the line
        'Serve hot.': 'يقدم ساخنًا:', // and a step
        'Chicken kabsa': 'كبسة\nدجاج',
      };
      final out = _apply(original, _answer(translationItems(original), lying))!;
      final copy = out.recipe;
      // The title, the group, and the rice, water and yogurt lines (water's
      // name and note are one line) and the step.
      expect(out.keptOriginal, 6);
      expect(copy.title, 'Chicken kabsa');
      expect(copy.ingredients[1].name, 'For the sauce');
      final lines = [for (final s in copy.ingredients) ...s.items];
      expect(lines.map((l) => l.original), [
        '2 cups basmati rice',
        '1½ ملعقة صغيرة ملح', // honest lines still translated
        '2–3 طماطم',
        '2 cups water (480 ml)',
        'ملح حسب الذوق',
        '1 cup yogurt',
      ]);
      expect([for (final s in copy.steps) ...s.items].last.text, 'Serve hot.');

      // What the editor does on Save: the copy's text boxes, read back.
      final ids = CountingIds(prefix: 'e');
      final saved = ingredientsFromText(
        ingredientsToText(copy.ingredients),
        copy.ingredients,
        ids.call,
      );
      final savedLines = [for (final s in saved) ...s.items];
      expect(savedLines, hasLength(6));
      expect(saved.map((s) => s.name), [null, 'For the sauce']);
      expect(savedLines.map((l) => l.original), lines.map((l) => l.original));
      expect([
        for (final l in savedLines) (l.min, l.max, l.unitId),
      ], _amounts(original));
      expect(
        savedLines.any((l) => l.original.contains('سكر')),
        isFalse, // no line the model made up
      );
      final savedSteps = stepsFromText(
        stepsToText(copy.steps),
        copy.steps,
        ids.call,
      );
      expect(
        [for (final s in savedSteps) ...s.items].map((s) => s.text),
        [for (final s in copy.steps) ...s.items].map((s) => s.text),
      );
      expect(savedSteps.single.name, isNull);
    });

    test('a note that only becomes a group name once it is on the line keeps '
        'its original text: the copy is checked against the editor\'s own '
        'reading (REC-4)', () {
      // The sent note itself ends with a colon, so the colon alone doesn't
      // give it away; the translated line "2 كوبان طحين، منخول:" would.
      final original = _recipe(
        ingredients: [
          (null, ['2 cups flour (sifted:)']),
        ],
      );
      expect(original.ingredients.single.items.single.note, 'sifted:');
      final out = _apply(
        original,
        _answer(translationItems(original), {
          'flour': 'طحين',
          'sifted:': 'منخول:',
        }),
      )!;
      expect(out.keptOriginal, 1);
      final line = out.recipe.ingredients.single.items.single;
      expect(line.original, '2 cups flour (sifted:)');
      expect(_amounts(out.recipe), _amounts(original));
    });

    test('QTY-1, QTY-8: a line the parser couldn\'t read that comes back with '
        'an amount in words, a dual form or a new unit keeps its original '
        'text; a plain translation of it is still used', () {
      Recipe unread(String line) => _recipe(
        ingredients: [
          (null, [line]),
        ],
      );
      TranslatedRecipe translate(Recipe r, String to, {bool toArabic = true}) =>
          applyTranslation(
            r,
            [
              for (final i in translationItems(r))
                (id: i.id, text: i.id == 't' ? i.text : to),
            ],
            toArabic: toArabic,
            id: 'copy',
            newId: CountingIds(prefix: 'c').call,
            now: _now,
          )!;

      for (final lie in [
        'ملعقتان ملح', // "two spoons of salt": a dual form
        'نصف ملعقة ملح', // "half a spoon": a number word
        'ملح ثلاث ملاعق', // an amount after the name
        'رشة ملح', // "a pinch": a unit the line never had
      ]) {
        final out = translate(unread('salt to taste'), lie);
        final line = out.recipe.ingredients.single.items.single;
        expect(out.keptOriginal, 1, reason: lie);
        expect(line.original, 'salt to taste', reason: lie);
        expect((line.min, line.unitId), (null, null), reason: lie);
      }

      // No amount, and the same unit (or none read): used as before.
      final honest = translate(unread('salt to taste'), 'ملح حسب الذوق');
      expect(honest.keptOriginal, 0);
      expect(
        honest.recipe.ingredients.single.items.single.original,
        'ملح حسب الذوق',
      );
      final pinch = unread('رشة زعفران');
      expect(pinch.ingredients.single.items.single.unitId, isNotNull);
      final english = translate(pinch, 'a pinch of saffron', toArabic: false);
      expect(english.keptOriginal, 0);
      final line = english.recipe.ingredients.single.items.single;
      expect(line.original, 'a pinch of saffron');
      expect(
        (line.min, line.unitId),
        (null, pinch.ingredients.single.items.single.unitId),
      );
    });

    test(
      'every ID must come back exactly once, or nothing changes (SRV-7)',
      () {
        final original = _english();
        final good = _answer(translationItems(original), _honest);
        expect(_apply(original, good.sublist(1)), isNull); // one missing
        expect(_apply(original, [...good, good.first]), isNull); // duplicated
        expect(
          _apply(original, [...good, (id: 'x99', text: 'زيادة')]),
          isNull, // never sent
        );
      },
    );

    test('a new recipe: new IDs throughout, cooked count 0, no rating, and '
        'everything else IMP-14 keeps', () {
      final original = _english();
      final copy = _apply(
        original,
        _answer(translationItems(original), _honest),
      )!.recipe;
      final originalIds = {
        original.id,
        for (final s in [...original.ingredients, ...original.steps]) s.id,
        for (final s in original.ingredients) ...s.items.map((l) => l.id),
        for (final s in original.steps) ...s.items.map((l) => l.id),
      };
      final copyIds = {
        copy.id,
        for (final s in [...copy.ingredients, ...copy.steps]) s.id,
        for (final s in copy.ingredients) ...s.items.map((l) => l.id),
        for (final s in copy.steps) ...s.items.map((l) => l.id),
      };
      expect(copyIds.intersection(originalIds), isEmpty);
      expect(copy.id, 'copy');
      expect(copy.translatedFrom, 'original');
      expect(copy.sourceUrl, original.sourceUrl);
      expect(copy.sourceType, SourceType.website);
      expect(copy.servings, 4);
      expect(copy.prepMinutes, 20);
      expect(copy.cookMinutes, 90);
      expect(copy.cookbookIds, ['book-1']);
      expect(copy.tags, ['rice']);
      expect(copy.notes, 'From my aunt.');
      expect(copy.cookedCount, 0);
      expect(copy.lastCookedAt, isNull);
      expect(copy.rating, isNull);
      expect(copy.photoPath, isNull); // the caller copies the file
      expect(copy.validate(), isNull);
    });

    test('into English: the unit names are English, so the page shows them '
        'in English (QTY-5)', () {
      final arabic = _recipe(
        title: 'كبسة',
        ingredients: [
          (null, ['3 أكواب أرز', '٢ فص ثوم']),
        ],
      );
      final out = applyTranslation(
        arabic,
        _answer(translationItems(arabic), {
          'كبسة': 'Kabsa',
          'أرز': 'rice',
          'ثوم': 'garlic',
        }),
        toArabic: false,
        id: 'copy',
        newId: CountingIds(prefix: 'c').call,
        now: _now,
      )!;
      final lines = out.recipe.ingredients.single.items;
      expect(lines.map((l) => l.original), ['3 cups rice', '2 cloves garlic']);
      expect(_amounts(out.recipe), _amounts(arabic));
      expect(out.recipe.translatedFrom, isNull);
    });
  });
}
