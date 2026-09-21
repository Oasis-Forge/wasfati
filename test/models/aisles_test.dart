import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/aisles.dart';
import 'package:wasfati/models/quantity/parser.dart';

void main() {
  group('GRO-4: hand-picked names, every aisle', () {
    // Name → expected aisle. Covers every aisle, dialect spellings (Gulf,
    // Levantine, Egyptian), a leading "ال" on one or more words, diacritics,
    // Eastern Arabic digits mixed into the name, English names, and the
    // longest-known-phrase overrides GRO-4 calls out by example.
    const cases = <(String, Aisle)>[
      // produce (خضار وفواكه), with dialect pairs.
      ('بصل', Aisle.produce),
      ('طماطم', Aisle.produce),
      ('بندورة', Aisle.produce), // dialect pair with طماطم
      ('بقدونس', Aisle.produce),
      ('بقدوس', Aisle.produce), // dialect spelling
      ('كزبرة', Aisle.produce),
      ('كسبرة', Aisle.produce), // dialect spelling
      ('ليمون', Aisle.produce),
      ('لومي', Aisle.spices), // dried black lime sits with the spices
      ('فلفل رومي', Aisle.produce),
      ('فلفل حلو', Aisle.produce), // dialect pair, bell pepper
      ('باذنجان', Aisle.produce),
      ('كوسا', Aisle.produce),
      ('كوسة', Aisle.produce), // dialect spelling
      ('onion', Aisle.produce),
      ('garlic', Aisle.produce),
      // meat and poultry (لحوم ودواجن)
      ('لحم ضأن', Aisle.meat),
      ('دجاج', Aisle.meat),
      ('صدر دجاج', Aisle.meat),
      ('chicken breast', Aisle.meat),
      // fish and seafood (أسماك)
      ('سمك سلمون', Aisle.fish),
      ('روبيان', Aisle.fish),
      ('tuna', Aisle.fish),
      // dairy, cheese and eggs (ألبان وأجبان وبيض)
      ('حليب', Aisle.dairy),
      ('جبن حلوم', Aisle.dairy),
      ('لبنة', Aisle.dairy),
      ('لبن', Aisle.dairy),
      ('بيض', Aisle.dairy), // eggs are dairy in GRO-4's aisle order
      ('زبدة', Aisle.dairy),
      // bread and bakery (خبز ومخبوزات)
      ('خبز رقاق', Aisle.bakery),
      ('توست', Aisle.bakery),
      ('baguette', Aisle.bakery),
      // rice, pasta, grains and pulses (أرز ومعكرونة وبقوليات)
      ('basmati rice', Aisle.grains),
      ('برغل', Aisle.grains),
      ('فريكة', Aisle.grains),
      ('عدس', Aisle.grains),
      ('حمص', Aisle.grains),
      ('سميد', Aisle.grains),
      // spices (بهارات)
      ('هال', Aisle.spices),
      ('حبهان', Aisle.spices), // dialect pair
      ('كمون', Aisle.spices),
      ('كركم', Aisle.spices),
      ('بهارات مشكلة', Aisle.spices),
      ('salt', Aisle.spices),
      // oils, sauces and cans (زيوت وصلصات ومعلبات)
      ('طحينة', Aisle.pantry),
      ('سمن', Aisle.pantry),
      ('olive oil', Aisle.pantry),
      // baking and sweets (مستلزمات الحلويات)
      ('دقيق', Aisle.baking),
      ('flour', Aisle.baking),
      ('فانيليا', Aisle.baking),
      // frozen (مجمدات)
      ('آيس كريم', Aisle.frozen),
      ('ice cream', Aisle.frozen),
      ('خضار مجمدة', Aisle.frozen),
      // drinks (مشروبات)
      ('ماء', Aisle.drinks),
      ('عصير برتقال', Aisle.drinks),
      ('water', Aisle.drinks),
      // other (أخرى): not a food name, so no aisle knows it.
      ('منظف أطباق', Aisle.other),
      ('مناديل ورقية', Aisle.other),

      // Longest known phrase wins (GRO-4), overriding the single word it's
      // built on.
      ('صدر دجاج مسحب', Aisle.meat), // "صدر دجاج"/"دجاج", not just a name
      ('معجون طماطم', Aisle.pantry), // not produce like plain طماطم
      ('ماء الورد', Aisle.baking), // not drinks like plain ماء
      ('حليب جوز الهند', Aisle.pantry), // not dairy like plain حليب
      ('دبس رمان', Aisle.pantry), // not produce like plain رمان
      ('فلفل أسود', Aisle.spices), // not produce like plain فلفل
      ('زيت زيتون', Aisle.pantry), // not produce like plain زيتون
      ('زبدة الفول السوداني', Aisle.pantry), // not dairy like plain زبدة
      ('تونة معلبة', Aisle.pantry), // not fish like plain تونة
      // A leading "ال" dropped from one or more words (ORG-4).
      ('الثوم الطازج', Aisle.produce),
      ('البصل الأحمر', Aisle.produce),

      // Diacritics removed before matching (ORG-4).
      ('ثَوْمٌ', Aisle.produce),
      ('دَجَاجٌ', Aisle.meat),

      // Eastern Arabic digits mixed into the name don't stop the rest of
      // it from matching.
      ('٢ بصل', Aisle.produce),
      ('٣ حليب', Aisle.dairy),
    ];

    for (final (name, expected) in cases) {
      test('$name → ${expected.name}', () {
        expect(aisleFor(name), expected, reason: name);
      });
    }
  });

  group('GRO-4, ORG-4: coverage over the S1 and S2 fixtures', () {
    // Every input line from the QTY-7 table (test/models/quantity/
    // parser_test.dart), copied verbatim: S1, Fatafeat/ReciMe web and
    // YouTube Short, Instagram caption, and real lines from Arabic recipe
    // websites (cookpad, sayidaty, atyabtabkha, supermama).
    const s1Lines = <String>[
      '1 كيلو جرام لحم ضأن',
      '2 حبة بصل أبيض',
      '5 ملعقة كبيرة زبدة',
      '1 كوب معجون الطماطم',
      '3 عود قرنفل',
      '8 حبة هال',
      '1/2 ملعقة صغيرة كركم',
      '1/2 حبة برش قشر البرتقال',
      '8 كوب مرقة لحم',
      '5 فص ثوم',
      'ملح حسب الذوق',
      'رشة زعفران',
      '١ بصل حجم كبير',
      '٣ ملاعق كبيرة زيت نباتي',
      '١ ملعقة صغيرة ثوم مهروس',
      '٢ فلفل حار صحيح',
      '١ ك لحم غنم قطع',
      '٣ كوب ارز بسمتي',
      '١ حزمة صغيرة بقدونس مفروم',
      '-خمس ملاعق كبيرة زيت نباتي',
      '-حبة بصل مقطعة',
      '-كوب جزر مقطع ومقشر',
      '-سبع حبات قرنفل',
      '-اثنين حبة بندورة مقطعة',
      '-ملعقة كبيرة ملح',
      '-اربع اكواب ارز بسمتي منقوع ومغسول',
      '-ست اكواب مرق الدجاج.',
      'حزمتين ورقيات سلق',
      'ملعقتين كبيرتين طحينة',
      'كوبين ماء',
      '1 1/2 كوب طحين',
      '١½ كوب سكر',
      '½ كوب حليب',
      'نصف كيلو دجاج',
      'ربع كوب زيت',
      'كوب ونصف رز',
      '٢-٣ فصوص ثوم',
      '2 إلى 3 حبات طماطم',
      '2.5 كغ لحم',
      '٢٫٥ لتر ماء',
      '500 غرام لحم مفروم',
      '250مل حليب',
      '2 م.ك سكر',
      'ملح: 1 ملعقة صغيرة',
      'رز بسمتي 3 أكواب',
      '2 cups rice',
      '1 tbsp olive oil',
      'salt to taste',
      '1/4 كوب كزبرة خضراء',
      'زعفران',
      ' أرز بسمتي أو أمريكاني',
      '2 بصل',
      'كوب و نصف من الماء لكل كوب أرز',
      'معكرونة 500 غراماً',
      'زيت الزيتون 3 ملاعق كبيرة',
      'الثوم فصّان مفروم',
      'الجزر 1 حبة مبشور',
      ' كوبان ونصف دقيق',
      'مقطّعة إلى مكعبات صغيرة  200 غرام زبدة',
      ' ربع ملعقة صغيرة قرفة مطحونة',
      '3 أكواب (450 غرام) دقيق أبيض.',
      '¼ 1 كوب (187.5 غرام) سكر أبيض.',
      '½ كوب (125 مل) زيت نباتي.',
      '¼ 1 (312.5 مل) كوب حليب.',
      'ملعقة كبيرة (10 غرام) بيكنج باودر.',
      'رشة ملح.',
      'ليمون',
      'قطع الدجاج',
      'حبات هال',
    ];

    // Ingredient lines from S2's sample pages (test/models/
    // recipe_import_test.dart): the fatafeat JSON-LD shape (including its
    // grouped sauce sub-lines), the sayidaty, supermama and @graph/Pie
    // shapes, the HTML-entity line (decoded), the microdata (فتوش) sample,
    // and the IMP-13 shared-text drafts.
    const s2Lines = <String>[
      '1 كيلو جرام لحم ضأن',
      '2 حبة بصل',
      '1 طماطم',
      '1 فلفل أخضر',
      '2 فص ثوم',
      '1 كوب عدس',
      '¼ 1 كوب سكر',
      '2 cups flour',
      '1 cup milk & cream',
      '2 حبة طماطم',
      '- 5 ملاعق كبيرة زيت',
      '- حبة بصل',
      '1 cup flour',
      '1 egg',
    ];

    test('at least 95% of the ingredient names land in a named aisle', () {
      final names = [
        for (final line in [...s1Lines, ...s2Lines]) parseIngredient(line).name,
      ].where((n) => n.trim().isNotEmpty).toList();

      final misses = [
        for (final n in names)
          if (aisleFor(n) == Aisle.other) n,
      ];
      final pct = (names.length - misses.length) / names.length * 100;

      expect(
        pct,
        greaterThanOrEqualTo(95),
        reason:
            '${misses.length} of ${names.length} names landed in "أخرى": '
            '${misses.toSet().join(', ')}',
      );
    });
  });
}
