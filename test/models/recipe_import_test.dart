import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/recipe_import.dart';

/// Pages shaped like the S2 survey found them (our own text, not the
/// sites'): docs/research/technical-constraints.md.
String page(String head) => '<html><head>$head</head><body>…</body></html>';

final url = Uri.parse('https://example.com/recipes/kabsa');

void main() {
  group('IMP-11: finding the recipe data', () {
    test('JSON-LD with HowToStep, one step a long blob (fatafeat shape)', () {
      final blob = List.filled(
        9, // over 400 characters
        'يضاف اللحم ويحمر جيدا ثم يضاف البصل ويقلى لمدة 5 دقائق',
      ).join(' , ');
      final r = parseRecipePage(
        page('''<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Recipe","name":"كبسة باللحم",
 "image":["https://example.com/k.jpg"],"recipeYield":"6","prepTime":"PT1H",
 "cookTime":"PT2H","recipeIngredient":["1 كيلو جرام لحم ضأن","2 حبة بصل",
 "مقادير صلصة الدقوس: 1 طماطم، 1 فلفل أخضر، 2 فص ثوم"],
 "recipeInstructions":[{"@type":"HowToStep","text":"$blob"},
 {"@type":"HowToStep","text":"توضع المكونات في الخلاط"}]}
</script>'''),
        url,
      )!;
      expect(r.title, 'كبسة باللحم');
      expect(r.imageUrl, 'https://example.com/k.jpg');
      expect((r.servings, r.prepMinutes, r.cookMinutes), (6, 60, 120));
      // IMP-6: the sauce line became its own group, one item per line.
      expect(r.ingredients.map((g) => g.$1), [null, 'مقادير صلصة الدقوس']);
      expect(r.ingredients.last.$2, ['1 طماطم', '1 فلفل أخضر', '2 فص ثوم']);
      // IMP-6: the long step was split into readable steps.
      final steps = r.steps.single.$2;
      expect(steps.length, greaterThan(2));
      expect(steps.every((s) => s.length <= 400), isTrue);
      expect(steps.last, 'توضع المكونات في الخلاط');
    });

    test('instructions as one string with line breaks (sayidaty shape)', () {
      final r = parseRecipePage(
        page('''<script type="application/ld+json">
{"@type":"Recipe","name":"شوربة عدس","recipeIngredient":["1 كوب عدس"],
 "recipeInstructions":"اغسلي العدس.\\r\\nاسلقيه 20 دقيقة.\\r\\nاخلطيه."}
</script>'''),
        url,
      )!;
      expect(r.steps.single.$2, [
        'اغسلي العدس.',
        'اسلقيه 20 دقيقة.',
        'اخلطيه.',
      ]);
    });

    test('unquoted type attribute and a list of strings (supermama shape)', () {
      final r = parseRecipePage(
        page('''<script type=application/ld+json>
{"@type":"Recipe","name":"كيكة","recipeIngredient":["¼ 1 كوب سكر"],
 "recipeInstructions":["اخفقي البيض","أضيفي السكر"]}
</script>'''),
        url,
      )!;
      expect(r.ingredients.single.$2, ['¼ 1 كوب سكر']);
      expect(r.steps.single.$2, ['اخفقي البيض', 'أضيفي السكر']);
    });

    test('inside @graph, with a type list and HowToSection groups', () {
      final r = parseRecipePage(
        page('''<script type="application/ld+json">
{"@graph":[{"@type":"WebPage"},{"@type":["Recipe"],"name":"Pie",
 "recipeIngredient":["2 cups flour"],"recipeInstructions":[
 {"@type":"HowToSection","name":"Crust","itemListElement":[
   {"@type":"HowToStep","text":"Mix"},{"@type":"HowToStep","text":"Chill"}]},
 {"@type":"HowToSection","name":"Filling","itemListElement":[
   {"@type":"HowToStep","text":"Slice apples"}]}]}]}
</script>'''),
        url,
      )!;
      expect(r.steps.map((s) => s.$1), ['Crust', 'Filling']);
      expect(r.steps.first.$2, ['Mix', 'Chill']);
    });

    test('HTML entities are decoded', () {
      final r = parseRecipePage(
        page('''<script type="application/ld+json">
{"@type":"Recipe","name":"Mac &amp; cheese","recipeIngredient":["1 cup milk &amp; cream"]}
</script>'''),
        url,
      )!;
      expect(r.title, 'Mac & cheese');
      expect(r.ingredients.single.$2, ['1 cup milk & cream']);
    });

    test('microdata with ingredients works; SEO-only microdata does not', () {
      final good = parseRecipePage(
        '<div itemscope itemtype="https://schema.org/Recipe">'
        '<h1 itemprop="name">فتوش</h1>'
        '<li itemprop="recipeIngredient">2 حبة طماطم</li>'
        '<div itemprop="recipeInstructions">قطعي الخضار</div></div>',
        url,
      )!;
      expect(good.title, 'فتوش');
      expect(good.ingredients.single.$2, ['2 حبة طماطم']);

      // mawdoo3 in S2: Recipe microdata with no ingredients → AI import.
      final seo = parseRecipePage(
        '<article itemscope itemtype="http://schema.org/Recipe">'
        '<h1 itemprop="name">طريقة عمل الكبسة</h1>'
        '<div itemprop="recipeInstructions">نص طويل…</div></article>',
        url,
      );
      expect(seo, isNull);
    });

    test('no recipe data at all → null (the page needs AI import)', () {
      expect(
        parseRecipePage(
          page(
            '<script type="application/ld+json">{"@type":"NewsArticle"}</script>',
          ),
          url,
        ),
        isNull,
      );
      expect(parseRecipePage('<p>broken <script>{not json', url), isNull);
    });
  });

  group('small parsers', () {
    test('ISO durations', () {
      expect(isoMinutes('PT1H30M'), 90);
      expect(isoMinutes('PT45M'), 45);
      expect(isoMinutes('P0DT2H'), 120);
      expect(isoMinutes('PT0M'), isNull);
      expect(isoMinutes('30 minutes'), isNull);
    });
    test('yield', () {
      expect(parseYield('6 servings'), 6);
      expect(parseYield('٦ حصص'), 6);
      expect(parseYield(['6', '6 حصص']), 6);
      expect(parseYield(4), 4);
      expect(parseYield('500'), isNull); // REC-7: 1–100
    });
    test('IMP-9: the same page gets the same URL', () {
      expect(
        normalizeSourceUrl(
          'http://www.Fatafeat.com/recipe/1632/?utm_source=x&fbclid=y#top',
        ),
        'https://fatafeat.com/recipe/1632',
      );
      expect(
        normalizeSourceUrl('https://cookpad.com/sa/r/1?lang=ar'),
        'https://cookpad.com/sa/r/1?lang=ar',
      );
    });
    test('a link inside shared text', () {
      expect(
        findUrl('جربوا هالوصفة https://fatafeat.com/recipe/1632، رائعة'),
        'https://fatafeat.com/recipe/1632',
      );
      expect(findUrl('بدون رابط'), isNull);
    });
  });

  group('IMP-13: shared text becomes a draft', () {
    test('title, then ingredients and steps by their headings', () {
      final d = draftFromText('''🔴 كبسة دجاج
المقادير:
- 5 ملاعق كبيرة زيت
- حبة بصل
طريقة التحضير:
نحمر الدجاج.
نضيف الرز ونتركه 20 دقيقة.
#كبسة #وصفات''');
      expect(d.title, 'كبسة دجاج');
      expect(d.ingredients.single.$2, ['- 5 ملاعق كبيرة زيت', '- حبة بصل']);
      expect(d.steps.single.$2, ['نحمر الدجاج.', 'نضيف الرز ونتركه 20 دقيقة.']);
    });
    test('no headings: everything after the title is an ingredient', () {
      final d = draftFromText('Pancakes\n1 cup flour\n1 egg');
      expect(d.title, 'Pancakes');
      expect(d.ingredients.single.$2, ['1 cup flour', '1 egg']);
      expect(d.steps, isEmpty);
    });
  });
}
