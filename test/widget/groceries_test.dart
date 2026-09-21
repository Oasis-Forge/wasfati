import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/grocery.dart';
import 'package:wasfati/models/plan.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/settings.dart';

import '../helpers.dart' show kabsa;
import 'app_test.dart' show groceries, plan, pumpApp, settle, sharer, shown;

/// A tab in the bottom navigation, by its icon (language-agnostic).
Finder _navTab(IconData icon) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.byIcon(icon),
);

// Left-to-right and pop directional isolates (QTY-5), built from their code
// points so they don't change how this file's own source reads.
final _lri = String.fromCharCode(0x2066);
final _pdi = String.fromCharCode(0x2069);

void main() {
  testWidgets('GRO-2: add a recipe to groceries merges into an aisle heading, '
      'adding it twice doubles the amount (GRO-3)', (tester) async {
    await pumpApp(tester, withRecipe: true);
    await tester.tap(shown('كبسة لحم'));
    await settle(tester);

    await tester.tap(find.byTooltip('أضف إلى المشتريات'));
    await settle(tester);
    // "ملح حسب الذوق" is to-taste and starts unticked (QTY-2), so only
    // the other 3 lines are added.
    await tester.tap(find.text('إضافة'));
    await settle(tester);
    expect(find.text('أُضيفت 3 مكوّنات'), findsOneWidget);

    // Adding the same recipe again merges into the same items (GRO-3).
    await tester.tap(find.byTooltip('أضف إلى المشتريات'));
    await settle(tester);
    await tester.tap(find.text('إضافة'));
    await settle(tester);
    expect(find.text('أُضيفت 3 مكوّنات'), findsWidgets);

    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(_navTab(Icons.shopping_basket_outlined));
    await settle(tester);

    expect(shown('لحوم ودواجن'), findsOneWidget); // GRO-4 aisle heading
    expect(shown('2 كيلو لحم ضأن'), findsOneWidget); // 1 kg + 1 kg, merged
    expect(shown('1 كيلو لحم ضأن'), findsNothing); // not left un-merged
    expect(shown('أرز ومعكرونة وبقوليات'), findsOneWidget);
    expect(shown('6 أكواب ارز بسمتي'), findsOneWidget); // 3 + 3 cups
    expect(shown('خضار وفواكه'), findsOneWidget);
    // A merged count drops its unit word, just a number (GRO-3): 2 + 2.
    expect(shown('4 طماطم'), findsOneWidget);
    expect(shown('كبسة لحم'), findsWidgets); // named on the second line
  });

  testWidgets(
    'GRO-2, SCALE-6: the current scale and view carry into the grocery '
    'list, not just ×1 (should-fix, UI review: the old test never touched '
    'the scale)',
    (tester) async {
      await pumpApp(tester, withRecipe: true);
      await tester.tap(shown('كبسة لحم'));
      await settle(tester);
      await tester.tap(find.text('×2'));
      await settle(tester);

      await tester.tap(find.byTooltip('أضف إلى المشتريات'));
      await settle(tester);
      await tester.tap(find.text('إضافة'));
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.tap(_navTab(Icons.shopping_basket_outlined));
      await settle(tester);
      expect(shown('2 كيلو لحم ضأن'), findsOneWidget); // 1 kg × 2
      expect(shown('6 أكواب ارز بسمتي'), findsOneWidget); // 3 cups × 2
    },
  );

  testWidgets(
    'GRO-5: ticking an item moves it under "تم"; Clear done removes it, '
    'Undo brings it back (DEL-2)',
    (tester) async {
      await pumpApp(tester, withRecipe: true);
      await tester.runAsync(() async {
        await groceries.add([
          IncomingLine(name: 'بصل', min: Rational(2), unitId: 'piece'),
        ]);
      });
      await settle(tester);
      await tester.tap(_navTab(Icons.shopping_basket_outlined));
      await settle(tester);

      expect(find.text('تم'), findsNothing); // nothing done yet
      await tester.tap(find.byType(Checkbox).first);
      await settle(tester);
      expect(find.text('تم'), findsOneWidget); // the collapsed section

      await tester.tap(find.byIcon(Icons.more_vert));
      await settle(tester);
      await tester.tap(find.text('مسح ما تم شراؤه'));
      await settle(tester);
      expect(find.textContaining('مُسح'), findsOneWidget);
      expect(find.text('تم'), findsNothing); // the only item is gone
      expect(shown('بصل'), findsNothing);

      await tester.tap(find.text('تراجع'));
      await settle(tester);
      expect(find.text('تم'), findsOneWidget); // back, still done (DEL-2)
      await tester.tap(find.text('تم'));
      await settle(tester);
      expect(shown('بصل'), findsOneWidget);
    },
  );

  testWidgets(
    'GRO-6: Share sends the exact title, heading and amount line, ticking '
    'an item drops it, and Share is disabled on an empty list (should-fix, '
    'UI review: the old test could not catch a missing amount, reversed '
    'isolates or a done item leaking in)',
    (tester) async {
      await pumpApp(tester, withRecipe: true);
      await tester.runAsync(() async {
        await groceries.add([
          IncomingLine(name: 'طماطم', min: Rational(2), unitId: 'piece'),
        ]);
      });
      await settle(tester);
      await tester.tap(_navTab(Icons.shopping_basket_outlined));
      await settle(tester);

      await tester.tap(find.byTooltip('مشاركة'));
      await settle(tester);
      expect(
        sharer.texts.last,
        'قائمة المشتريات\n\nخضار وفواكه\n• $_lri'
        '2$_pdi طماطم',
      );

      await tester.tap(find.byType(Checkbox).first);
      await settle(tester);
      final shareButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.share_outlined),
      );
      expect(shareButton.onPressed, isNull); // nothing left to buy
    },
  );

  testWidgets(
    'PLAN-5: adding the week marks entries added; adding again starts '
    'unticked',
    (tester) async {
      final (recipes, _) = await pumpApp(tester, withRecipe: true);
      final recipeId = recipes.recipes.single.id;
      await tester.runAsync(() async {
        await plan.add(
          date: plan.today,
          slot: MealSlot.lunch,
          recipeId: recipeId,
          servings: 6,
        );
      });
      await settle(tester);

      await tester.tap(_navTab(Icons.calendar_month_outlined));
      await settle(tester);
      await tester.tap(find.byTooltip('أضف إلى المشتريات'));
      await settle(tester);
      expect(
        find.descendant(
          of: find.byType(CheckboxListTile),
          matching: find.text('كبسة لحم'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('إضافة'));
      await settle(tester);
      expect(find.text('أُضيفت وجبة واحدة إلى المشتريات'), findsOneWidget);
      expect(plan.entries.single.addedToGroceriesAt, isNotNull);

      // The same week again: the entry starts unticked and its subtitle
      // (day, meal, servings, should-fix, UI review) says "أُضيفت" too.
      await tester.tap(find.byTooltip('أضف إلى المشتريات'));
      await settle(tester);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data ?? '').contains('غداء') && // meal name
              (w.data ?? '').contains('أُضيفت'),
        ),
        findsOneWidget,
      );
      final tile = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile).first,
      );
      expect(tile.value, isFalse);
    },
  );

  testWidgets(
    'PLAN-5: scales by the entry\'s servings over the recipe\'s, in the '
    "recipe's remembered view, before merging (should-fix, UI review: the "
    'old test only ever used ×1)',
    (tester) async {
      final (recipes, _) = await pumpApp(tester, withRecipe: true);
      final recipeId = recipes.recipes.single.id;
      await tester.runAsync(() async {
        await plan.add(
          date: plan.today,
          slot: MealSlot.lunch,
          recipeId: recipeId,
          servings: 12, // double kabsa's 6 (SCALE-2)
        );
      });
      await settle(tester);

      await tester.tap(_navTab(Icons.calendar_month_outlined));
      await settle(tester);
      await tester.tap(find.byTooltip('أضف إلى المشتريات'));
      await settle(tester);
      await tester.tap(find.text('إضافة'));
      await settle(tester);

      await tester.tap(_navTab(Icons.shopping_basket_outlined));
      await settle(tester);
      expect(shown('2 كيلو لحم ضأن'), findsOneWidget); // 1 kg × 2
      expect(shown('6 أكواب ارز بسمتي'), findsOneWidget); // 3 cups × 2
    },
  );

  testWidgets(
    'GRO-1: a typed line is parsed into its aisle with the right amount',
    (tester) async {
      await pumpApp(tester, withRecipe: true);
      await tester.tap(_navTab(Icons.shopping_basket_outlined));
      await settle(tester);

      await tester.enterText(find.byType(TextField), '2 كيلو طماطم');
      await tester.tap(find.byTooltip('أضف غرضًا'));
      await settle(tester);

      expect(shown('خضار وفواكه'), findsOneWidget);
      expect(shown('2 كيلو طماطم'), findsOneWidget);
    },
  );

  testWidgets(
    'GRO-5: "Remove" in the By-recipe view takes out only that recipe\'s '
    'amounts, with an Undo snackbar (must-fix, two reviews: it had none)',
    (tester) async {
      final (recipes, _) = await pumpApp(tester, withRecipe: true);
      final recipeId = recipes.recipes.single.id;
      await tester.runAsync(() async {
        await groceries.add([
          IncomingLine(
            name: 'طماطم',
            min: Rational(2),
            unitId: 'piece',
            recipeId: recipeId,
          ),
        ]);
      });
      await settle(tester);
      await tester.tap(_navTab(Icons.shopping_basket_outlined));
      await settle(tester);
      await tester.tap(find.text('حسب الوصفة'));
      await settle(tester);
      expect(find.text('كبسة لحم'), findsOneWidget); // the recipe's group
      expect(shown('2 طماطم'), findsOneWidget);

      await tester.tap(find.text('إزالة'));
      await settle(tester);
      expect(find.textContaining('كبسة لحم'), findsWidgets); // the snackbar
      expect(find.text('تراجع'), findsOneWidget);
      expect(shown('2 طماطم'), findsNothing); // its only amount is gone

      await tester.tap(find.text('تراجع'));
      await settle(tester);
      expect(shown('2 طماطم'), findsOneWidget); // back (DEL-2)
    },
  );

  testWidgets('GRO-7: deleting a recipe leaves its amounts on the list, under '
      '"أضفتها بنفسك" in the By-recipe view (must-fix, two reviews: they used '
      'to vanish from this view while still on the list)', (tester) async {
    final (recipes, _) = await pumpApp(tester, withRecipe: true);
    final recipeId = recipes.recipes.single.id;
    await tester.runAsync(() async {
      await groceries.add([
        IncomingLine(
          name: 'طماطم',
          min: Rational(2),
          unitId: 'piece',
          recipeId: recipeId,
        ),
      ]);
      // A second recipe, so the library (and its nav bar, RUN-1) isn't
      // empty once "كبسة لحم" is deleted.
      await recipes.save(kabsa(recipes.repository, title: 'أخرى'));
    });
    await settle(tester);

    await tester.tap(shown('كبسة لحم'));
    await settle(tester);
    await tester.tap(find.byTooltip('حذف'));
    await settle(tester); // deleting already pops back to the list

    await tester.tap(_navTab(Icons.shopping_basket_outlined));
    await settle(tester);
    await tester.tap(find.text('حسب الوصفة'));
    await settle(tester);
    expect(find.text('كبسة لحم'), findsNothing); // no longer named
    expect(find.text('أضفتها بنفسك'), findsOneWidget); // fallback group
    expect(shown('2 طماطم'), findsOneWidget); // still on the list
  });

  for (final lang in [LanguagePref.ar, LanguagePref.en]) {
    testWidgets('${lang.name} groceries at 1.3× text: no overflow (LANG-6)', (
      tester,
    ) async {
      final (recipes, _) = await pumpApp(
        tester,
        language: lang,
        textScale: 1.3,
        withRecipe: true,
      );
      final recipeId = recipes.recipes.single.id;
      await tester.runAsync(() async {
        await groceries.add([
          IncomingLine(
            name: 'طماطم',
            min: Rational(2),
            unitId: 'piece',
            recipeId: recipeId,
          ),
          IncomingLine(
            name: 'طماطم',
            min: Rational.one,
            unitId: 'can',
            recipeId: recipeId,
          ),
          IncomingLine(
            name: 'لحم ضأن مقطع للكباب والمشاوي بمقادير كبيرة جدًا',
            min: Rational.one,
            unitId: 'kg',
            recipeId: recipeId,
          ),
        ]);
        await groceries.addByHand('ملعقة كبيرة سكر بني ناعم للتزيين');
      });
      await settle(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(_navTab(Icons.shopping_basket_outlined));
      await settle(tester);
      expect(tester.takeException(), isNull);

      // Meat comes after produce in GRO-4's order: index 1.
      await tester.tap(find.byType(Checkbox).at(1));
      await settle(tester);
      expect(tester.takeException(), isNull);

      // Long press still-visible produce item: the move-to-aisle sheet,
      // with all 12 aisle names, at 1.3× text.
      await tester.longPress(shown('طماطم').first);
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
