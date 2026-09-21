import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/plan.dart';

import 'app_test.dart' show plan, pumpApp, settle, shown;

/// Lets a write finish without running the clock past a snackbar (5 s).
Future<void> brief(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('PLAN-3, PLAN-6: a recipe is planned in three taps, and its '
      'page says so', (tester) async {
    await pumpApp(tester, withRecipe: true);

    // The plan is the app's second place, once there's a recipe (PLAN-1).
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(shown('كبسة لحم'));
    await settle(tester);
    await tester.tap(find.byTooltip('أضف إلى الخطة')); // tap 1
    await settle(tester);
    expect(shown('اليوم'), findsWidgets); // today comes preselected
    await tester.tap(find.widgetWithText(ChoiceChip, 'عشاء')); // tap 2
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ')); // tap 3
    await brief(tester);

    final planned = plan.entriesFor(plan.today, MealSlot.dinner);
    expect(planned.single.recipeId, isNotNull);
    expect(shown('أُضيفت إلى الخطة'), findsOneWidget);
    // PLAN-2: the entry starts at the recipe's own servings.
    expect(planned.single.servings, 6);
    await settle(tester);
    // PLAN-6: the recipe page names its next planned meal.
    expect(shown('في الخطة'), findsOneWidget);

    // And the week shows it under its meal, with the servings (PLAN-1).
    await tester.binding.handlePopRoute(); // pageBack can't see the icon
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('الخطة'),
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('هذا الأسبوع')); // scrolls to today
    await settle(tester);
    expect(shown('كبسة لحم'), findsWidgets);
    expect(shown('6 حصص'), findsOneWidget);
  });

  testWidgets('PLAN-2, PLAN-4: a note is removed and brought back, and the '
      'week moves', (tester) async {
    await pumpApp(tester, withRecipe: true);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('الخطة'),
      ),
    );
    await settle(tester);

    // The four meals of PLAN-1, on the days on screen.
    for (final meal in ['فطور', 'غداء', 'عشاء', 'وجبة خفيفة']) {
      expect(shown(meal), findsWidgets);
    }

    await tester.tap(find.byTooltip('إضافة').hitTestable().first);
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, 'اكتب ملاحظة'));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField), 'مطعم');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await settle(tester);
    expect(find.text('مطعم'), findsOneWidget);
    expect(plan.entries.single.isNote, isTrue);

    await tester.longPress(find.text('مطعم'));
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, 'إزالة'));
    await brief(tester);
    expect(shown('أُزيلت من الخطة'), findsOneWidget);
    expect(plan.entries, isEmpty);

    await tester.tap(find.text('تراجع')); // DEL-2
    await settle(tester);
    expect(plan.entries.single.note, 'مطعم');
    expect(find.text('مطعم'), findsOneWidget);

    // PLAN-1: next week is another week, and "This week" comes back.
    final thisWeek = plan.weekStart;
    await tester.tap(find.byTooltip('الأسبوع التالي'));
    await settle(tester);
    expect(plan.weekStart.difference(thisWeek).inDays, 7);
    expect(find.text('مطعم'), findsNothing);
    await tester.tap(find.byTooltip('هذا الأسبوع'));
    await settle(tester);
    expect(dateKey(plan.weekStart), dateKey(thisWeek));
    expect(find.text('مطعم'), findsOneWidget);
  });
}
