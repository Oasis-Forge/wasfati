// SHARE-1–SHARE-4: recipeShareText (SHARE-2) and the image-page planner
// (SHARE-3), both pure Dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/quantity/convert.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/recipe_share.dart';

import '../helpers.dart';

// Matches format.dart's own isolate characters (QTY-5).
final _lri = String.fromCharCode(0x2066); // left-to-right isolate
final _pdi = String.fromCharCode(0x2069); // pop directional isolate

/// [text] as a person reads it, without the invisible isolates QTY-5 wraps
/// amounts in — the same trick test/widget/app_test.dart's `shown` uses.
String _withoutIsolates(String text) =>
    text.replaceAll(_lri, '').replaceAll(_pdi, '');

String _servingsLabel(int n) => n == 1
    ? 'حصة واحدة'
    : (n == 2 ? 'حصتان' : (n >= 3 && n <= 10 ? '$n حصص' : '$n حصة'));
String _prepTimeLabel(int m) => 'التحضير $m دقيقة';
String _cookTimeLabel(int m) => 'الطبخ $m دقيقة';
String _sourceLabel(String url) => 'المصدر: $url';
const _footerLine = 'من تطبيق وصفاتي';
const _ingredientsHeading = 'المقادير';
const _stepsHeading = 'الطريقة';
const _notScaledMark =
    'لم يُعدَّل'; // matches app_ar.arb's "notScaled" (SCALE-4)
String _unscaledLineText(String line, String mark) => '$line ($mark)';

String _text(
  Recipe r, {
  Rational factor = Rational.one,
  UnitView view = UnitView.asWritten,
  DigitStyle digits = DigitStyle.western,
}) => recipeShareText(
  r,
  factor: factor,
  view: view,
  digits: digits,
  ingredientsHeading: _ingredientsHeading,
  stepsHeading: _stepsHeading,
  footerLine: _footerLine,
  notScaledMark: _notScaledMark,
  unscaledLineText: _unscaledLineText,
  servingsLabel: _servingsLabel,
  prepTimeLabel: _prepTimeLabel,
  cookTimeLabel: _cookTimeLabel,
  sourceLabel: _sourceLabel,
);

void main() {
  group('recipeShareText (SHARE-1, SHARE-2)', () {
    test('the kabsa recipe at ×1', () async {
      final (repo, _, _) = await testRepo();
      final text = _text(kabsa(repo));
      expect(_withoutIsolates(text), '''
كبسة لحم
6 حصص · التحضير 60 دقيقة · الطبخ 120 دقيقة

المقادير
1 كيلو لحم ضأن
3 أكواب ارز بسمتي
ملح حسب الذوق
للدقوس
2 حبتان طماطم

الطريقة
1. يحمر اللحم في الزبدة.
2. يضاف الأرز ويترك 15 دقيقة.
المصدر: https://www.fatafeat.com/recipe/1632

من تطبيق وصفاتي
$wasfatiPlayStoreUrl''');
    });

    test('at ×2: servings and amounts scale (SCALE-2)', () async {
      final (repo, _, _) = await testRepo();
      final text = _withoutIsolates(_text(kabsa(repo), factor: Rational(2)));
      expect(text, contains('12 حصة · التحضير 60 دقيقة · الطبخ 120 دقيقة'));
      expect(text, contains('2 كيلو لحم ضأن'));
      expect(text, contains('6 أكواب ارز بسمتي'));
      expect(text, contains('4 حبات طماطم'));
      expect(text, contains('ملح حسب الذوق')); // to taste: never scaled
    });

    test('in the metric view (SCALE-5, SCALE-6)', () async {
      final (repo, _, _) = await testRepo();
      final text = _withoutIsolates(_text(kabsa(repo), view: UnitView.metric));
      expect(text, contains('1 كيلو لحم ضأن')); // already metric
      expect(text, contains('555 غرامًا ارز بسمتي')); // 3 cups × 185 g/cup
      expect(text, contains('2 حبتان طماطم')); // count unit: unaffected
    });

    test(
      'never shares notes, tags, rating, cookbooks or cooked count (SHARE-1)',
      () async {
        final (repo, _, _) = await testRepo();
        final r = kabsa(repo).copyWith(
          notes: 'ملاحظة سرية',
          tags: ['وسم-غريب'],
          rating: 5,
          cookedCount: 9,
        );
        final text = _text(r);
        expect(text, isNot(contains('ملاحظة سرية')));
        expect(text, isNot(contains('وسم-غريب')));
      },
    );

    test('no servings and no times: no facts line (REC-3)', () {
      final now = DateTime.utc(2026);
      final r = Recipe(
        id: 'r1',
        title: 'وصفة بسيطة',
        ingredients: [
          Section(id: 'g1', items: [IngredientLine.parse('i1', '1 كوب سكر')]),
        ],
        createdAt: now,
        updatedAt: now,
      );
      final text = _text(r);
      // The title's own section is just the title: no second line, so the
      // next thing is the blank-line separator before "المقادير".
      expect(text, startsWith('وصفة بسيطة\n\n$_ingredientsHeading'));
    });

    test('no source: no "المصدر" line', () {
      final now = DateTime.utc(2026);
      final r = Recipe(
        id: 'r1',
        title: 'وصفة',
        steps: [
          const Section(
            id: 's1',
            items: [RecipeStep(id: 'p1', text: 'اخلط.')],
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      expect(_text(r), isNot(contains('المصدر')));
    });

    test(
      'an English recipe keeps 123 even with Arabic digits chosen (QTY-5)',
      () {
        final now = DateTime.utc(2026);
        final r = Recipe(
          id: 'r1',
          title: 'Chicken Kabsa',
          ingredients: [
            Section(
              id: 'g1',
              items: [IngredientLine.parse('i1', '2 cups flour')],
            ),
          ],
          createdAt: now,
          updatedAt: now,
        );
        final text = _withoutIsolates(_text(r, digits: DigitStyle.arabic));
        expect(text, contains('2 cups flour'));
        expect(text, isNot(contains('٢')));
      },
    );

    test(
      'isolates wrap the amount inside an Arabic line (QTY-5, LANG-5)',
      () async {
        final (repo, _, _) = await testRepo();
        final text = _text(kabsa(repo));
        expect(
          text,
          contains(
            '$_lri'
            '1$_pdi كيلو لحم ضأن',
          ),
        );
      },
    );

    test('an English step keeps 123 in its number too (QTY-5, must-fix, '
        'adversarial review)', () {
      final now = DateTime.utc(2026);
      final r = Recipe(
        id: 'r1',
        title: 'Chicken Kabsa',
        steps: [
          const Section(
            id: 's1',
            items: [RecipeStep(id: 'p1', text: 'Heat the oven.')],
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      final text = _text(r, digits: DigitStyle.arabic);
      expect(text, contains('1. Heat the oven.'));
      expect(text, isNot(contains('١')));
    });

    test('the ×factor mark is isolated left-to-right too (QTY-5, should-fix, '
        'adversarial review)', () {
      final now = DateTime.utc(2026);
      final r = Recipe(
        id: 'r1',
        title: 'وصفة',
        servings: 3,
        createdAt: now,
        updatedAt: now,
      );
      // 3 servings × ½ = 1.5: not whole, so the multiplier shows instead
      // (SCALE-2) — and it needs the same isolate an amount gets, or "×½"
      // reads reversed inside the Arabic facts line ("½×").
      final text = _text(r, factor: Rational.half);
      expect(text, contains('$_lri×½$_pdi'));
    });

    test('at ×2, an unscaled line is marked, matching the page (SCALE-4, '
        'SCALE-6, should-fix, adversarial review)', () async {
      final (repo, _, _) = await testRepo();
      final text = _withoutIsolates(_text(kabsa(repo), factor: Rational(2)));
      expect(text, contains('ملح حسب الذوق ($_notScaledMark)'));
    });

    test('no servings but scaled: the factor still shows (SCALE-6, should-fix, '
        'adversarial review)', () {
      final now = DateTime.utc(2026);
      final r = Recipe(
        id: 'r1',
        title: 'وصفة',
        ingredients: [
          Section(id: 'g1', items: [IngredientLine.parse('i1', '1 كوب سكر')]),
        ],
        createdAt: now,
        updatedAt: now,
      );
      final text = _withoutIsolates(_text(r, factor: Rational(2)));
      expect(text, startsWith('وصفة\n×2'));
    });
  });

  group('shareBlocksFor (SHARE-1, SHARE-3)', () {
    test('the photo comes first, headings are separate blocks', () async {
      final (repo, _, _) = await testRepo();
      final r = kabsa(repo).copyWith(photoPath: '/tmp/a.jpg');
      final blocks = shareBlocksFor(
        r,
        hasPhoto: true,
        ingredientsHeading: _ingredientsHeading,
        stepsHeading: _stepsHeading,
        notScaledMark: _notScaledMark,
        unscaledLineText: _unscaledLineText,
        servingsLabel: _servingsLabel,
        prepTimeLabel: _prepTimeLabel,
        cookTimeLabel: _cookTimeLabel,
      );
      expect(blocks.first.kind, ShareBlockKind.photo);
      expect(blocks[1].kind, ShareBlockKind.title);
      expect(
        blocks
            .where((b) => b.kind == ShareBlockKind.heading)
            .map((b) => b.text),
        [_ingredientsHeading, 'للدقوس', _stepsHeading],
      );
      // SHARE-1: never a block for notes, tags, rating or cookedCount.
      expect(blocks.any((b) => b.text.contains('ملاحظة')), isFalse);
    });

    test('no photo: no photo block', () async {
      final (repo, _, _) = await testRepo();
      final blocks = shareBlocksFor(
        kabsa(repo),
        hasPhoto: false,
        ingredientsHeading: _ingredientsHeading,
        stepsHeading: _stepsHeading,
        notScaledMark: _notScaledMark,
        unscaledLineText: _unscaledLineText,
        servingsLabel: _servingsLabel,
        prepTimeLabel: _prepTimeLabel,
        cookTimeLabel: _cookTimeLabel,
      );
      expect(blocks.every((b) => b.kind != ShareBlockKind.photo), isTrue);
      expect(blocks.first.kind, ShareBlockKind.title);
    });

    test('only the steps heading forces a new page (SHARE-3, should-fix, '
        'adversarial review)', () async {
      final (repo, _, _) = await testRepo();
      final r = kabsa(repo).copyWith(photoPath: '/tmp/a.jpg');
      final blocks = shareBlocksFor(
        r,
        hasPhoto: true,
        ingredientsHeading: _ingredientsHeading,
        stepsHeading: _stepsHeading,
        notScaledMark: _notScaledMark,
        unscaledLineText: _unscaledLineText,
        servingsLabel: _servingsLabel,
        prepTimeLabel: _prepTimeLabel,
        cookTimeLabel: _cookTimeLabel,
      );
      final headings = blocks.where((b) => b.kind == ShareBlockKind.heading);
      expect(headings.map((b) => b.text), [
        _ingredientsHeading,
        'للدقوس',
        _stepsHeading,
      ]);
      expect(headings.map((b) => b.forceNewPage), [false, false, true]);
    });

    test('a step reads by its own words, not the app-numbered prefix '
        '(LANG-5, QTY-5, must-fix, adversarial review)', () async {
      final now = DateTime.utc(2026);
      final r = Recipe(
        id: 'r1',
        title: 'Chicken Kabsa',
        steps: [
          const Section(
            id: 's1',
            items: [RecipeStep(id: 'p1', text: 'Heat the oven.')],
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      final blocks = shareBlocksFor(
        r,
        hasPhoto: false,
        digits: DigitStyle.arabic,
        ingredientsHeading: _ingredientsHeading,
        stepsHeading: _stepsHeading,
        notScaledMark: _notScaledMark,
        unscaledLineText: _unscaledLineText,
        servingsLabel: _servingsLabel,
        prepTimeLabel: _prepTimeLabel,
        cookTimeLabel: _cookTimeLabel,
      );
      final step = blocks.firstWhere((b) => b.kind == ShareBlockKind.step);
      expect(step.text, '1. Heat the oven.'); // QTY-5: English keeps 123
      expect(step.directionSource, 'Heat the oven.');
    });

    test('an ingredient reads the original line, not the formatted, '
        'digit-styled one (LANG-5, must-fix, adversarial review)', () async {
      final now = DateTime.utc(2026);
      final r = Recipe(
        id: 'r1',
        title: 'Cookies',
        ingredients: [
          Section(
            id: 'g1',
            items: [IngredientLine.parse('i1', '1 cup Nutella')],
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      final blocks = shareBlocksFor(
        r,
        hasPhoto: false,
        ingredientsHeading: _ingredientsHeading,
        stepsHeading: _stepsHeading,
        notScaledMark: _notScaledMark,
        unscaledLineText: _unscaledLineText,
        servingsLabel: _servingsLabel,
        prepTimeLabel: _prepTimeLabel,
        cookTimeLabel: _cookTimeLabel,
      );
      final ingredient = blocks.firstWhere(
        (b) => b.kind == ShareBlockKind.ingredient,
      );
      expect(ingredient.directionSource, '1 cup Nutella');
    });

    test('the steps section always starts a fresh page (SHARE-3, should-fix, '
        'adversarial review)', () async {
      final (repo, _, _) = await testRepo();
      // Small enough that, without the forced break, the steps heading
      // would fit right after the ingredients on the same page.
      double height(ShareBlock b, double w) => 100;
      final blocks = shareBlocksFor(
        kabsa(repo),
        hasPhoto: false,
        ingredientsHeading: _ingredientsHeading,
        stepsHeading: _stepsHeading,
        notScaledMark: _notScaledMark,
        unscaledLineText: _unscaledLineText,
        servingsLabel: _servingsLabel,
        prepTimeLabel: _prepTimeLabel,
        cookTimeLabel: _cookTimeLabel,
      );
      final plan = planSharePages(blocks, height);
      final stepsPage = plan.pages.firstWhere(
        (p) => p.blocks.any((b) => b.text == _stepsHeading),
      );
      expect(stepsPage.blocks.first.text, _stepsHeading);
    });
  });

  group('pageCounter (SHARE-3)', () {
    test('western and Arabic digits', () {
      expect(pageCounter(2, 3, DigitStyle.western), '2/3');
      expect(pageCounter(2, 3, DigitStyle.arabic), '٢/٣');
    });
  });

  group('planSharePages (SHARE-3)', () {
    const pageContentHeight =
        shareImageHeight - shareMargin - shareFooterHeight;

    double fixedHeight(ShareBlock b, double w) => 40;

    test('a short recipe fits on one page', () {
      final blocks = [
        ShareBlock.title('عنوان'),
        ShareBlock.facts('4 حصص'),
        ShareBlock.heading(_ingredientsHeading),
        ShareBlock.ingredient('سطر 1'),
        ShareBlock.ingredient('سطر 2'),
      ];
      final plan = planSharePages(blocks, fixedHeight);
      expect(plan.tooLong, isFalse);
      expect(plan.pages, hasLength(1));
      expect(plan.pages.single.blocks, hasLength(blocks.length));
    });

    test('ingredients then steps across pages, never split, headings never '
        'orphaned (SHARE-3)', () {
      // Two 400 px blocks fill a page (416 with the gap); a third would
      // overflow it (832 + 16 + 400 > pageContentHeight), so a page
      // never holds more than two — except a heading, which the planner
      // moves off a page rather than leave it alone at the bottom
      // (should-fix, adversarial review): pairing "الطريقة" with 'a'
      // ingredient 'b' would overflow, so it starts page 3 instead.
      double height(ShareBlock b, double w) => 400;
      final blocks = [
        ShareBlock.heading(_ingredientsHeading),
        ShareBlock.ingredient('a'),
        ShareBlock.ingredient('b'),
        ShareBlock.heading(_stepsHeading),
        ShareBlock.step('1. x'),
        ShareBlock.step('2. y'),
      ];
      final plan = planSharePages(blocks, height, digits: DigitStyle.arabic);
      expect(plan.tooLong, isFalse);
      // Every block is placed exactly once, none lost or duplicated.
      expect(plan.pages.expand((p) => p.blocks).map((b) => b.text), [
        for (final b in blocks) b.text,
      ]);
      expect(plan.pages.map((p) => p.blocks.map((b) => b.text).toList()), [
        [_ingredientsHeading, 'a'],
        ['b'],
        [_stepsHeading, '1. x'],
        ['2. y'],
      ]);
      expect(plan.pages[0].footer, '١/٤');
      expect(plan.pages[2].footer, '٣/٤');
      expect(plan.pages[3].footer, '٤/٤');
    });

    test('a heading is never left alone at the bottom of a page (REC-4, '
        'should-fix, adversarial review)', () {
      // A page holds 1218 px. The heading (200 px) fits after 'a' (900
      // px), but pairing it with the group's first line ('طماطم', 900
      // px) would overflow by nearly 800 px, so the heading moves to the
      // next page instead of being stranded alone at the bottom of this
      // one.
      double height(ShareBlock b, double w) =>
          b.kind == ShareBlockKind.heading ? 200 : 900;
      final blocks = [
        ShareBlock.ingredient('a'),
        ShareBlock.heading('للدقوس'),
        ShareBlock.ingredient('طماطم'),
      ];
      final plan = planSharePages(blocks, height);
      expect(plan.pages.map((p) => p.blocks.map((b) => b.text).toList()), [
        ['a'],
        ['للدقوس', 'طماطم'],
      ]);
    });

    test('an otherwise-empty page still takes its heading, even orphaned '
        '(REC-4, should-fix, adversarial review)', () {
      // The heading (1100 px) and the block after it (900 px) can never
      // share a page (they'd need 2,016 px), so pairing them is
      // impossible either way — the heading still opens the (empty)
      // page it lands on, rather than the planner looping forever
      // trying to find it a page with room for both.
      double height(ShareBlock b, double w) =>
          b.kind == ShareBlockKind.heading ? 1100 : 900;
      final blocks = [ShareBlock.heading('فارغ'), ShareBlock.ingredient('a')];
      final plan = planSharePages(blocks, height);
      expect(plan.pages.map((p) => p.blocks.map((b) => b.text).toList()), [
        ['فارغ'],
        ['a'],
      ]);
    });

    test('a 7-page recipe flags "too long" instead (SHARE-3)', () {
      // Each block alone exactly fills a page, so a second on any page
      // always overflows: one block per page, seven pages.
      double height(ShareBlock b, double w) => pageContentHeight;
      final blocks = [for (var i = 0; i < 7; i++) ShareBlock.ingredient('l$i')];
      final plan = planSharePages(blocks, height);
      expect(plan.tooLong, isTrue);
      expect(plan.pages, isEmpty);
    });

    test('an over-tall step is shrunk, never split (SHARE-3, REC-6)', () {
      // At the step's own size (36) it's far taller than a page; two steps
      // down (34) it fits, so the planner should stop shrinking there.
      double height(ShareBlock b, double w) {
        if (b.kind != ShareBlockKind.step) return 40;
        return b.fontSize >= 36
            ? pageContentHeight + 500
            : pageContentHeight - 200;
      }

      final longStep = ShareBlock.step('ن' * 2000); // REC-6's 2,000 chars
      final plan = planSharePages([longStep], height);
      expect(plan.tooLong, isFalse);
      expect(plan.pages, hasLength(1));
      expect(plan.pages.single.blocks.single.fontSize, 34);
      expect(plan.pages.single.blocks.single.text, longStep.text); // not split
    });

    test('a block too tall even at the 32 px floor flags "too long"', () {
      double height(ShareBlock b, double w) => pageContentHeight + 1;
      final plan = planSharePages([ShareBlock.step('x' * 2000)], height);
      expect(plan.tooLong, isTrue);
    });
  });
}
