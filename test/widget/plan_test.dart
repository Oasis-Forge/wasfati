import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsProperties;
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/plan.dart';
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/providers/settings_state.dart';
import 'package:wasfati/widgets/nav_pill.dart';
import 'package:wasfati/widgets/sufra_card.dart';

import '../helpers.dart' show kabsa;
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

Future<void> _goToPlan(WidgetTester tester) async {
  await tester.tap(
    find.descendant(of: find.byType(NavPill), matching: find.text('الخطة')),
  );
  await settle(tester);
}

/// The FakeClock's today, Saturday 19 September 2026, is the first day of
/// a Saturday week (PLAN-1), pinned so the strip doesn't follow the test
/// machine's region.
Future<void> _saturdayWeeks(WidgetTester tester, SettingsState settings) =>
    tester.runAsync(
      () => settings.update(
        settings.settings.copyWith(weekStart: WeekStart.saturday),
      ),
    );

/// One day of the week strip, by its date.
Finder _day(DateTime d) => find.byKey(ValueKey('plan-day-${dateKey(d)}'));

SemanticsProperties _dayProps(WidgetTester tester, DateTime d) =>
    tester.widget<Semantics>(_day(d)).properties;

/// The strip pill's own drawn fill and border, and its dot's colour.
ShapeDecoration _pill(WidgetTester tester, DateTime d) =>
    tester
            .widget<Container>(
              find
                  .descendant(of: _day(d), matching: find.byType(Container))
                  .first,
            )
            .decoration!
        as ShapeDecoration;

Color? _dot(WidgetTester tester, DateTime d) =>
    (tester
                .widget<Container>(
                  find.descendant(
                    of: _day(d),
                    matching: find.byKey(const ValueKey('plan-dot')),
                  ),
                )
                .decoration!
            as BoxDecoration)
        .color;

final _today = DateTime(2026, 9, 19);
final _monday = DateTime(2026, 9, 21);

void main() {
  testWidgets('PLAN-3, PLAN-6: a recipe is planned in three taps, and its '
      'page says so', (tester) async {
    await pumpApp(tester, withRecipe: true);

    // The plan is the app's second place, once there's a recipe (PLAN-1).
    expect(find.byType(NavPill), findsOneWidget);

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

    // And the plan opens on today, showing it under its meal with its
    // servings (PLAN-1).
    await tester.binding.handlePopRoute(); // pageBack can't see the icon
    await settle(tester);
    await _goToPlan(tester);
    expect(shown('كبسة لحم'), findsWidgets);
    expect(shown('6 حصص'), findsOneWidget);
  });

  testWidgets('PLAN-1: the strip marks today, the chosen day and the days '
      'with entries; choosing a day shows its meals and count, without '
      'reloading', (tester) async {
    final (recipes, settings) = await pumpApp(tester, withRecipe: true);
    await _saturdayWeeks(tester, settings);
    final id = recipes.recipes.single.id;
    await tester.runAsync(() async {
      await plan.add(
        date: _today,
        slot: MealSlot.lunch,
        recipeId: id,
        servings: 6,
      );
      await plan.add(date: _today, slot: MealSlot.breakfast, note: 'فول');
      await plan.add(date: _today, slot: MealSlot.dinner, note: 'مطعم');
      await plan.add(date: _monday, slot: MealSlot.dinner, note: 'بقايا');
    });
    await _goToPlan(tester);
    final cs = Theme.of(tester.element(_day(_today))).colorScheme;

    // Opens on today, chosen: ink-filled, and since it has entries, its dot
    // in the pill's own card-coloured text, which reads on ink (PLAN-1).
    expect(_dayProps(tester, _today).selected, isTrue);
    expect(_dayProps(tester, _today).label, contains('اليوم'));
    expect(_dayProps(tester, _today).label, contains('3 وجبات'));
    expect(_pill(tester, _today).color, cs.onSurface);
    expect(_dot(tester, _today), cs.surfaceContainerLowest);
    // A day with entries carries the herb dot; an empty one none.
    expect(_dayProps(tester, _monday).selected, isFalse);
    expect(_dayProps(tester, _monday).label, contains('وجبة واحدة'));
    expect(_dot(tester, _monday), cs.secondary);
    expect(_dot(tester, DateTime(2026, 9, 20)), Colors.transparent);

    // Today's heading, its meal count, and only today's four meals.
    expect(shown('اليوم · '), findsOneWidget);
    expect(find.text('3 وجبات'), findsOneWidget);
    for (final meal in ['فطور', 'غداء', 'عشاء', 'وجبة خفيفة']) {
      expect(find.text(meal), findsOneWidget);
    }
    expect(find.text('فول'), findsOneWidget);
    expect(find.text('مطعم'), findsOneWidget);
    expect(find.text('6 حصص'), findsOneWidget);
    expect(find.text('بقايا'), findsNothing); // Monday's, not shown

    // Monday: its own meals, its own count; today still marked (ringed
    // in the accent, "اليوم" read) though no longer chosen.
    await tester.tap(_day(_monday));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('بقايا'), findsOneWidget);
    expect(find.text('فول'), findsNothing);
    expect(find.text('وجبة واحدة'), findsOneWidget);
    expect(shown('اليوم · '), findsNothing);
    expect(_dayProps(tester, _monday).selected, isTrue);
    expect(_pill(tester, _monday).color, cs.onSurface);
    expect(_dot(tester, _monday), cs.surfaceContainerLowest);
    expect(_dot(tester, _today), cs.secondary); // has entries, not chosen
    expect(_dayProps(tester, _today).selected, isFalse);
    expect(_dayProps(tester, _today).label, contains('اليوم'));
    expect(
      (_pill(tester, _today).shape as StadiumBorder).side.color,
      cs.primary,
    );

    // An empty day reads "لا وجبات" and offers an add on every meal; chosen,
    // it's ink-filled but carries no dot, since it has no entries.
    await tester.tap(_day(DateTime(2026, 9, 22)));
    await tester.pump();
    expect(_dayProps(tester, DateTime(2026, 9, 22)).selected, isTrue);
    expect(_pill(tester, DateTime(2026, 9, 22)).color, cs.onSurface);
    expect(_dot(tester, DateTime(2026, 9, 22)), Colors.transparent);
    // Monday, no longer chosen, is back to its herb dot.
    expect(_dot(tester, _monday), cs.secondary);
    expect(find.text('لا وجبات'), findsOneWidget);
    expect(find.text('إضافة'), findsNWidgets(4));
  });

  testWidgets('PLAN-1: the arrows move a week and keep the chosen weekday; '
      '"هذا الأسبوع" shows off this week and comes back to today', (
    tester,
  ) async {
    final (_, settings) = await pumpApp(tester, withRecipe: true);
    await _saturdayWeeks(tester, settings);
    await _goToPlan(tester);
    final thisWeek = plan.weekStart;
    expect(find.text('هذا الأسبوع'), findsNothing); // already on it

    await tester.tap(_day(_monday));
    await tester.pump();
    await tester.tap(find.byTooltip('الأسبوع التالي'));
    await settle(tester);
    expect(plan.weekStart.difference(thisWeek).inDays, 7);
    expect(_dayProps(tester, DateTime(2026, 9, 28)).selected, isTrue);
    expect(find.text('هذا الأسبوع'), findsOneWidget);

    await tester.tap(find.byTooltip('الأسبوع السابق'));
    await settle(tester);
    await tester.tap(find.byTooltip('الأسبوع السابق'));
    await settle(tester);
    expect(dateKey(plan.weekStart), '2026-09-12');
    expect(_dayProps(tester, DateTime(2026, 9, 14)).selected, isTrue);

    await tester.tap(find.text('هذا الأسبوع'));
    await settle(tester);
    expect(dateKey(plan.weekStart), dateKey(thisWeek));
    expect(_dayProps(tester, _today).selected, isTrue);
    expect(find.text('هذا الأسبوع'), findsNothing);
  });

  testWidgets('PLAN-1: "by region" follows the phone\'s region, not the '
      'app\'s language: an Arabic app on a UK phone starts on Monday', (
    tester,
  ) async {
    // The phone's first language names no region; its UK English does.
    tester.platformDispatcher.localesTestValue = const [
      Locale('ar'),
      Locale('en', 'GB'),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await pumpApp(tester, withRecipe: true);
    await _goToPlan(tester);
    expect(plan.weekStart.weekday, DateTime.monday);
    expect(dateKey(plan.weekStart), '2026-09-14');
    // Monday leads the strip: its pill sits at the start (the right, in
    // Arabic) of Sunday's.
    expect(
      tester.getCenter(_day(DateTime(2026, 9, 14))).dx,
      greaterThan(tester.getCenter(_day(DateTime(2026, 9, 20))).dx),
    );
  });

  testWidgets('PLAN-1: an English app on a Saudi phone starts on Sunday, '
      'and follows a region change while it runs', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ar', 'SA')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await pumpApp(tester, withRecipe: true, language: LanguagePref.en);
    await tester.tap(
      find.descendant(of: find.byType(NavPill), matching: find.text('Plan')),
    );
    await settle(tester);
    expect(plan.weekStart.weekday, DateTime.sunday);
    expect(dateKey(plan.weekStart), '2026-09-13');

    // The phone's region changes to the UK while the app runs.
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
    await settle(tester);
    expect(plan.weekStart.weekday, DateTime.monday);
  });

  testWidgets('PLAN-3: an empty meal\'s "+ إضافة" opens the picker: a note, '
      'or the library with its search', (tester) async {
    await pumpApp(tester, withRecipe: true);
    await _goToPlan(tester);

    await tester.tap(find.text('إضافة').first); // breakfast, empty
    await settle(tester);
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('اكتب ملاحظة')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('كبسة لحم')),
      findsOneWidget,
    );
    await tester.enterText(
      find.descendant(of: sheet, matching: find.byType(TextField)),
      'شوربة',
    );
    await tester.pump();
    expect(find.text('لا توجد وصفات مطابقة'), findsOneWidget);
    await tester.enterText(
      find.descendant(of: sheet, matching: find.byType(TextField)),
      'كبسة',
    );
    await tester.pump();
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('كبسة لحم')),
    );
    await settle(tester);

    final added = plan.entriesFor(plan.today, MealSlot.breakfast).single;
    expect(added.recipeId, isNotNull);
    expect(added.servings, 6); // PLAN-2: the recipe's own
    expect(find.text('كبسة لحم'), findsWidgets);
    expect(find.text('6 حصص'), findsOneWidget);
    expect(find.text('وجبة واحدة'), findsOneWidget);
  });

  testWidgets('PLAN-2, PLAN-4: a note is removed and brought back, and the '
      'Undo notice then goes away on its own (DEL-2)', (tester) async {
    await pumpApp(tester, withRecipe: true);
    await _goToPlan(tester);

    await tester.tap(find.text('إضافة').first);
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

    // Removed again, and left: the notice times out, never lingering over
    // the screen, the banner or the navigation pill.
    await tester.longPress(find.text('مطعم'));
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, 'إزالة'));
    await brief(tester);
    final snack = find.byType(SnackBar);
    expect(snack, findsOneWidget);
    expect(
      tester.getRect(snack).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(NavPill)).top),
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('تراجع'), findsNothing);
    expect(plan.entries, isEmpty);
  });

  testWidgets('PLAN-4: a note shows its own "المزيد" button, which opens '
      'move, copy and remove; remove comes with Undo (DEL-2)', (tester) async {
    await pumpApp(tester, withRecipe: true);
    await tester.runAsync(
      () => plan.add(date: plan.today, slot: MealSlot.dinner, note: 'مطعم'),
    );
    await _goToPlan(tester);

    // The header's button and the note's: nothing hides behind a long press.
    final more = find.descendant(
      of: find.ancestor(
        of: find.text('مطعم'),
        matching: find.byType(SufraCard),
      ),
      matching: find.byTooltip('المزيد'),
    );
    expect(more, findsOneWidget);
    await tester.tap(more);
    await settle(tester);
    for (final action in ['نقل', 'نسخ', 'إزالة']) {
      expect(find.widgetWithText(ListTile, action), findsOneWidget);
    }
    // Not the edit dialog: the button opens the menu, the card's tap edits.
    expect(find.byType(TextFormField), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'إزالة'));
    await brief(tester);
    expect(shown('أُزيلت من الخطة'), findsOneWidget);
    expect(plan.entries, isEmpty);
    expect(find.text('مطعم'), findsNothing);

    await tester.tap(find.text('تراجع'));
    await settle(tester);
    expect(plan.entries.single.note, 'مطعم');
    expect(find.text('مطعم'), findsOneWidget);
  });

  testWidgets('PLAN-2: tapping a note opens it filled in, to change its '
      'text; an empty one is refused; a long press still opens PLAN-4 '
      'menu', (tester) async {
    await pumpApp(tester, withRecipe: true);
    await tester.runAsync(
      () => plan.add(date: _today, slot: MealSlot.dinner, note: 'مطعم'),
    );
    await _goToPlan(tester);

    await tester.tap(find.text('مطعم'));
    await settle(tester);
    // Titled as an edit, not as writing a new note.
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('عدّل الملاحظة'),
      ),
      findsOneWidget,
    );
    expect(find.text('اكتب ملاحظة'), findsNothing);
    final field = find.byType(TextFormField);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'مطعم',
    );

    // Emptied, it isn't saved (PLAN-2: 1-60 characters).
    await tester.enterText(field, '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await settle(tester);
    expect(find.text('من 1 إلى 60 حرفًا'), findsOneWidget);
    expect(plan.entries.single.note, 'مطعم');

    await tester.enterText(field, 'بقايا الأمس');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await brief(tester);
    await settle(tester);
    expect(plan.entries.single.note, 'بقايا الأمس');
    expect(plan.entries.single.slot, MealSlot.dinner);
    expect(find.text('بقايا الأمس'), findsOneWidget);
    expect(find.text('مطعم'), findsNothing);

    await tester.longPress(find.text('بقايا الأمس'));
    await settle(tester);
    expect(find.widgetWithText(ListTile, 'نقل'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'إزالة'), findsOneWidget);
  });

  testWidgets('PLAN-4: the long-press menu copies and moves a recipe entry', (
    tester,
  ) async {
    final (recipes, _) = await pumpApp(tester, withRecipe: true);
    await tester.runAsync(
      () => plan.add(
        date: plan.today,
        slot: MealSlot.lunch,
        recipeId: recipes.recipes.single.id,
        servings: 6,
      ),
    );
    await _goToPlan(tester);

    // Copy to dinner, the same day.
    await tester.longPress(find.text('كبسة لحم'));
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, 'نسخ'));
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'عشاء'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await settle(tester);
    expect(plan.entriesFor(plan.today, MealSlot.lunch), hasLength(1));
    expect(plan.entriesFor(plan.today, MealSlot.dinner), hasLength(1));
    expect(find.text('كبسة لحم'), findsNWidgets(2));
    expect(find.text('وجبتان'), findsOneWidget);

    // Move the dinner one to breakfast, through its more button.
    await tester.tap(find.byTooltip('المزيد').last);
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, 'نقل'));
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'فطور'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await settle(tester);
    expect(plan.entriesFor(plan.today, MealSlot.dinner), isEmpty);
    expect(plan.entriesFor(plan.today, MealSlot.breakfast), hasLength(1));
    expect(plan.entries, hasLength(2));
  });

  testWidgets('PLAN-4: the header\'s "المزيد" clears the week, with Undo '
      'above the navigation pill (DEL-2); the title is a heading', (
    tester,
  ) async {
    final (recipes, _) = await pumpApp(tester, withRecipe: true);
    await tester.runAsync(() async {
      await plan.add(
        date: plan.today,
        slot: MealSlot.lunch,
        recipeId: recipes.recipes.single.id,
        servings: 6,
      );
      await plan.add(date: plan.today, slot: MealSlot.dinner, note: 'مطعم');
    });
    await _goToPlan(tester);

    // The screen's title is still a heading, as AppBar's was.
    final handle = tester.ensureSemantics();
    final heading = find.ancestor(
      of: find.text('الخطة'),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.header ?? false),
      ),
    );
    expect(
      tester.getSemantics(heading),
      isSemantics(label: 'الخطة', isHeader: true),
    );
    handle.dispose();

    // The header's "المزيد", not the planned recipe's or the note's own.
    expect(find.byTooltip('المزيد'), findsNWidgets(3));
    await tester.tap(find.byTooltip('المزيد').first);
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, 'مسح الأسبوع'));
    await brief(tester);
    expect(plan.entries, isEmpty);
    expect(find.text('أُزيلت وجبتان'), findsOneWidget);
    expect(find.text('تراجع'), findsOneWidget);
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(NavPill)).top),
    );
    expect(find.text('إضافة'), findsNWidgets(4)); // every meal empty
    expect(find.text('مطعم'), findsNothing);

    await tester.tap(find.text('تراجع'));
    await settle(tester);
    expect(plan.entries, hasLength(2));
    expect(find.text('كبسة لحم'), findsOneWidget);
    expect(find.text('مطعم'), findsOneWidget);
  });

  testWidgets('a planned recipe with a photo is read as a button, not an '
      'image, and its more button stays its own', (tester) async {
    final (recipes, _) = await pumpApp(tester);
    final dir = Directory.systemTemp.createTempSync('wasfati_plan_test');
    final photo = File('${dir.path}/kabsa.png')..writeAsBytesSync(_onePxPng);
    await tester.runAsync(() async {
      await recipes.save(
        kabsa(recipes.repository).copyWith(photoPath: photo.path),
      );
      await plan.add(
        date: plan.today,
        slot: MealSlot.lunch,
        recipeId: recipes.recipes.single.id,
        servings: 6,
      );
    });
    await settle(tester);
    await _goToPlan(tester);
    expect(find.byType(Image), findsWidgets); // the photo, not a cover

    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.text('كبسة لحم')),
      isSemantics(
        label: 'كبسة لحم\n6 حصص',
        isButton: true,
        isImage: false,
        hasTapAction: true,
        hasLongPressAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byTooltip('المزيد').last),
      isSemantics(isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });
}

/// A one-pixel, valid PNG, so `Image.file` decodes it.
final _onePxPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);
