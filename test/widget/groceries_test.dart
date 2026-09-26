import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/widgets/nav_pill.dart';
import 'package:wasfati/models/aisles.dart';
import 'package:wasfati/models/grocery.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/screens/groceries_screen.dart' show aisleIcon;
import 'package:wasfati/models/plan.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/widgets/round_icon_button.dart';
import 'package:wasfati/widgets/sufra_card.dart';

import '../helpers.dart' show kabsa;
import 'app_test.dart'
    show groceries, plan, pumpApp, settle, sharer, shown, tapOnPage;

/// A tab in the bottom navigation, by its icon (language-agnostic).
Finder _navTab(IconData icon) =>
    find.descendant(of: find.byType(NavPill), matching: find.byIcon(icon));

// Left-to-right and pop directional isolates (QTY-5), built from their code
// points so they don't change how this file's own source reads.
final _lri = String.fromCharCode(0x2066);
final _pdi = String.fromCharCode(0x2069);

/// One grocery row, as the shopper reads it: its [name], and its [amount]
/// exactly (isolates aside, QTY-5) at the other end of the same row
/// (GRO-5, LOOK-4).
Finder _row(String name, String amount) => find.ancestor(
  of: find.byWidgetPredicate(
    (w) =>
        w is Text &&
        (w.data ?? '').replaceAll(_lri, '').replaceAll(_pdi, '') == amount,
  ),
  matching: find.ancestor(
    of: find.text(name),
    matching: find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('grocery-'),
    ),
  ),
);

/// The row of the item called [name].
Finder _item(String name) => find.ancestor(
  of: find.text(name),
  matching: find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('grocery-'),
  ),
);

/// Lets a tick's write finish without moving the clock (Motion #4's 600 ms
/// wait is fake time, the database is real).
Future<void> _write(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
}

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
    expect(_row('لحم ضأن', '2 كيلو'), findsOneWidget); // 1 kg + 1 kg, merged
    expect(_row('لحم ضأن', '1 كيلو'), findsNothing); // not left un-merged
    expect(shown('أرز ومعكرونة وبقوليات'), findsOneWidget);
    expect(_row('ارز بسمتي', '6 أكواب'), findsOneWidget); // 3 + 3 cups
    expect(shown('خضار وفواكه'), findsOneWidget);
    // A merged count drops its unit word, just a number (GRO-3): 2 + 2.
    expect(_row('طماطم', '4'), findsOneWidget);
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
      await tapOnPage(tester, find.text('×2'));

      await tester.tap(find.byTooltip('أضف إلى المشتريات'));
      await settle(tester);
      await tester.tap(find.text('إضافة'));
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.tap(_navTab(Icons.shopping_basket_outlined));
      await settle(tester);
      expect(_row('لحم ضأن', '2 كيلو'), findsOneWidget); // 1 kg × 2
      expect(_row('ارز بسمتي', '6 أكواب'), findsOneWidget); // 3 cups × 2
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

      await tester.tap(find.byTooltip('المزيد'));
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
      final shareButton = tester.widget<RoundIconButton>(
        find.widgetWithIcon(RoundIconButton, Icons.share_outlined),
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
      await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
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
      await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
      await settle(tester);

      await tester.tap(_navTab(Icons.shopping_basket_outlined));
      await settle(tester);
      expect(_row('لحم ضأن', '2 كيلو'), findsOneWidget); // 1 kg × 2
      expect(_row('ارز بسمتي', '6 أكواب'), findsOneWidget); // 3 cups × 2
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
      expect(_row('طماطم', '2 كيلو'), findsOneWidget);
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
        await groceries.addByHand('خبز');
      });
      await settle(tester);
      await tester.tap(_navTab(Icons.shopping_basket_outlined));
      await settle(tester);
      await tester.tap(find.text('حسب الوصفة'));
      await settle(tester);
      expect(find.text('كبسة لحم'), findsOneWidget); // the recipe's card
      // Hand-added items get their own card, with nothing to remove.
      expect(
        find.ancestor(
          of: find.text('خبز'),
          matching: find.ancestor(
            of: find.text('أضفتها بنفسك'),
            matching: find.byType(SufraCard),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('إزالة'), findsOneWidget); // only the recipe's
      expect(_row('طماطم', '2'), findsOneWidget);

      await tester.tap(find.text('إزالة'));
      await settle(tester);
      expect(find.textContaining('كبسة لحم'), findsWidgets); // the snackbar
      expect(find.text('تراجع'), findsOneWidget);
      expect(_row('طماطم', '2'), findsNothing); // its only amount is gone

      await tester.tap(find.text('تراجع'));
      await settle(tester);
      expect(_row('طماطم', '2'), findsOneWidget); // back (DEL-2)
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
    // LOOK-13: delete is under the page's "more" button.
    await tester.tap(find.byTooltip('المزيد'));
    await settle(tester);
    await tester.tap(find.text('حذف'));
    await settle(tester); // deleting already pops back to the list

    await tester.tap(_navTab(Icons.shopping_basket_outlined));
    await settle(tester);
    await tester.tap(find.text('حسب الوصفة'));
    await settle(tester);
    expect(find.text('كبسة لحم'), findsNothing); // no longer named
    expect(find.text('أضفتها بنفسك'), findsOneWidget); // fallback group
    expect(_row('طماطم', '2'), findsOneWidget); // still on the list
  });

  testWidgets('GRO-5: the progress card counts what is bought, in the '
      "user's digits, with the recipes the list came from, and each aisle "
      'counts its own', (tester) async {
    final (recipes, _) = await pumpApp(
      tester,
      withRecipe: true,
      digits: DigitStyle.arabic,
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
          name: 'بصل',
          min: Rational(3),
          unitId: 'piece',
          recipeId: recipeId,
        ),
      ]);
      await groceries.addByHand('خبز');
    });
    await settle(tester);
    await tester.tap(_navTab(Icons.shopping_basket_outlined));
    await settle(tester);

    expect(find.text('٠ من ٣'), findsOneWidget); // the card
    expect(find.text('تم شراؤها'), findsOneWidget);
    // On the card, and under each of the two items it gave.
    expect(shown('من: كبسة لحم'), findsNWidgets(3));
    expect(find.text('٠ من ٢'), findsOneWidget); // vegetables and fruit
    expect(find.text('٠ من ١'), findsOneWidget); // bread

    await tester.tap(
      find.descendant(of: _item('بصل'), matching: find.byType(Checkbox)),
    );
    await settle(tester);
    expect(find.text('١ من ٣'), findsOneWidget);
    expect(find.text('١ من ٢'), findsOneWidget);
  });

  testWidgets('GRO-5: a ticked item stays a moment, then moves into "تم"; '
      'unticking it there brings it straight back', (tester) async {
    await pumpApp(tester, withRecipe: true);
    await tester.runAsync(() async {
      await groceries.add([
        IncomingLine(name: 'بصل', min: Rational(3), unitId: 'piece'),
        IncomingLine(name: 'طماطم', min: Rational(2), unitId: 'piece'),
      ]);
    });
    await settle(tester);
    await tester.tap(_navTab(Icons.shopping_basket_outlined));
    await settle(tester);
    final produce = find.ancestor(
      of: find.text('خضار وفواكه'),
      matching: find.byType(SufraCard),
    );

    await tester.tap(
      find.descendant(of: _item('بصل'), matching: find.byType(Checkbox)),
    );
    await _write(tester);
    // Ticked, still in its aisle for the moment (Motion #4).
    expect(groceries.done.single.name, 'بصل');
    expect(
      find.descendant(of: produce, matching: find.text('بصل')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(of: _item('بصل'), matching: find.byType(Checkbox)),
          )
          .value,
      isTrue,
    );
    expect(find.text('تم'), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('تم'), findsOneWidget);
    expect(find.text('بصل'), findsNothing); // "تم" starts collapsed
    expect(
      find.descendant(of: produce, matching: find.text('طماطم')),
      findsOneWidget,
    );

    await tester.tap(find.text('تم'));
    await settle(tester);
    await tester.tap(
      find.descendant(of: _item('بصل'), matching: find.byType(Checkbox)),
    );
    await _write(tester);
    expect(find.text('تم'), findsNothing); // at once, nothing left done
    expect(
      find.descendant(of: produce, matching: find.text('بصل')),
      findsOneWidget,
    );
  });

  testWidgets('GRO-5: tapping an item by its name ticks it, and the row '
      'reads as one checkbox named for the item', (tester) async {
    await pumpApp(tester, withRecipe: true, disableAnimations: true);
    await tester.runAsync(() async {
      await groceries.add([
        IncomingLine(name: 'بصل', min: Rational(3), unitId: 'piece'),
        IncomingLine(name: 'طماطم', min: Rational(2), unitId: 'piece'),
      ]);
    });
    await settle(tester);
    await tester.tap(_navTab(Icons.shopping_basket_outlined));
    await settle(tester);

    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.text('بصل')),
      isSemantics(
        label: 'بصل\n${_lri}3$_pdi',
        hasCheckedState: true,
        isChecked: false,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasLongPressAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();

    await tester.tap(find.text('بصل')); // the name, not the circle
    await _write(tester);
    expect(groceries.done.single.name, 'بصل');
    expect(find.text('تم'), findsOneWidget);

    await tester.tap(find.text('تم'));
    await settle(tester);
    await tester.tap(find.text('بصل'));
    await _write(tester);
    expect(groceries.done, isEmpty);
  });

  testWidgets('GRO-5, reduce motion: a ticked item moves into "تم" at once', (
    tester,
  ) async {
    await pumpApp(tester, withRecipe: true, disableAnimations: true);
    await tester.runAsync(() async {
      await groceries.add([
        IncomingLine(name: 'بصل', min: Rational(3), unitId: 'piece'),
        IncomingLine(name: 'طماطم', min: Rational(2), unitId: 'piece'),
      ]);
    });
    await settle(tester);
    await tester.tap(_navTab(Icons.shopping_basket_outlined));
    await settle(tester);

    await tester.tap(
      find.descendant(of: _item('بصل'), matching: find.byType(Checkbox)),
    );
    await _write(tester);
    expect(find.text('تم'), findsOneWidget);
    expect(find.text('بصل'), findsNothing);
  });

  testWidgets('GRO-4, GRO-5: every aisle has its own icon, on its card', (
    tester,
  ) async {
    expect(Aisle.values.map(aisleIcon).toSet(), hasLength(12));

    await pumpApp(tester, withRecipe: true);
    await tester.runAsync(() async {
      await groceries.add([
        IncomingLine(name: 'طماطم', min: Rational(2), unitId: 'piece'),
        const IncomingLine(name: 'لحم ضأن', min: Rational.one, unitId: 'kg'),
        const IncomingLine(name: 'خبز', min: Rational.one, unitId: 'piece'),
      ]);
    });
    await settle(tester);
    await tester.tap(_navTab(Icons.shopping_basket_outlined));
    await settle(tester);

    for (final (aisle, heading) in [
      (Aisle.produce, 'خضار وفواكه'),
      (Aisle.meat, 'لحوم ودواجن'),
      (Aisle.bakery, 'خبز ومخبوزات'),
    ]) {
      final card = find.ancestor(
        of: find.text(heading),
        matching: find.byType(SufraCard),
      );
      expect(
        find.descendant(of: card, matching: find.byIcon(aisleIcon(aisle))),
        findsOneWidget,
        reason: heading,
      );
    }
  });

  testWidgets('GRO-5, DEL-2: "مسح الكل" offers Undo above the navigation '
      'pill, and the notice then goes away on its own', (tester) async {
    await pumpApp(tester, withRecipe: true);
    await tester.runAsync(() async {
      await groceries.add([
        IncomingLine(name: 'بصل', min: Rational(3), unitId: 'piece'),
      ]);
    });
    await settle(tester);
    await tester.tap(_navTab(Icons.shopping_basket_outlined));
    await settle(tester);

    await tester.tap(find.byTooltip('المزيد'));
    await settle(tester);
    await tester.tap(find.text('مسح الكل'));
    await _write(tester);
    expect(find.text('تراجع'), findsOneWidget);
    expect(find.text('قائمة المشتريات فارغة'), findsOneWidget);
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(NavPill)).top),
    );

    await tester.pump(const Duration(milliseconds: 500)); // it slides in
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1)); // and out
    expect(find.text('تراجع'), findsNothing);
    expect(groceries.items, isEmpty);
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
      await tester.ensureVisible(find.byType(Checkbox).at(1));
      await tester.pump();
      await tester.tap(find.byType(Checkbox).at(1));
      await settle(tester);
      expect(tester.takeException(), isNull);

      // Long press still-visible produce item: the move-to-aisle sheet,
      // with all 12 aisle names, at 1.3× text.
      await tester.ensureVisible(shown('طماطم').first);
      await tester.pump();
      await tester.longPress(shown('طماطم').first);
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the title is a heading, the add field has its 3:1 outline '
      "(accent while focused), each check is a 24dp circle at the card's "
      "16dp padding, and the progress ring's track shows in dark (LOOK-3)", (
    tester,
  ) async {
    final (_, settings) = await pumpApp(tester, withRecipe: true);
    await tester.runAsync(() => groceries.addByHand('خبز'));
    await settle(tester);
    await tester.tap(_navTab(Icons.shopping_basket_outlined));
    await settle(tester);
    final cs = Theme.of(tester.element(find.text('خبز'))).colorScheme;

    // The screen's title is still a heading, as AppBar's was.
    final handle = tester.ensureSemantics();
    final heading = find.ancestor(
      of: find.text('المشتريات'),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.header ?? false),
      ),
    );
    expect(
      tester.getSemantics(heading),
      isSemantics(label: 'المشتريات', isHeader: true),
    );
    handle.dispose();

    // The add field's pill edge: the outline, then 2dp of the accent.
    StadiumBorder addPill() {
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is DecoratedBox &&
                    w.decoration is ShapeDecoration &&
                    (w.decoration as ShapeDecoration).shape is StadiumBorder,
              ),
            )
            .first,
      );
      return (box.decoration as ShapeDecoration).shape as StadiumBorder;
    }

    expect(addPill().side, BorderSide(color: cs.outline));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(addPill().side, BorderSide(color: cs.primary, width: 2));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    // The check: scaled from Material's 18dp to 24dp with its ring kept at
    // 1.5dp, centred 28dp from the card's edge (right to left), so the
    // circle starts at the card's 16dp padding.
    final check = find.descendant(
      of: _item('خبز'),
      matching: find.byType(Checkbox),
    );
    final scale = tester.widget<Transform>(
      find.ancestor(of: check, matching: find.byType(Transform)).first,
    );
    expect(scale.transform.getMaxScaleOnAxis(), closeTo(24 / 18, 1e-6));
    expect(tester.widget<Checkbox>(check).side!.width, closeTo(1.125, 1e-6));
    final card = find.ancestor(
      of: _item('خبز'),
      matching: find.byType(SufraCard),
    );
    expect(
      tester.getRect(card).right - tester.getCenter(check).dx,
      closeTo(28, 0.01),
    );

    // Dark: the ring's track is the card's foreground at 20%, not the
    // near-invisible outlineVariant on sunk.
    await tester.runAsync(
      () => settings.update(settings.settings.copyWith(theme: ThemePref.dark)),
    );
    await settle(tester);
    final dark = Theme.of(tester.element(find.text('خبز'))).colorScheme;
    expect(dark.brightness, Brightness.dark);
    final dynamic ring = tester
        .widget<CustomPaint>(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter.runtimeType.toString() == '_RingPainter',
          ),
        )
        .painter;
    expect(ring.track, dark.onSurface.withValues(alpha: 0.2));
  });
}
