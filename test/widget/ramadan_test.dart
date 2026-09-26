import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/widgets/nav_pill.dart';
import 'package:wasfati/models/plan.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/ramadan.dart';
import 'package:wasfati/models/settings.dart';

import 'app_test.dart' show clock, plan, pumpApp, settle, shown;

/// One day's pill on the plan's week strip or month grid (PLAN-1, RAM-4).
Finder dayPill(DateTime day) =>
    find.byKey(ValueKey('plan-day-${dateKey(day)}'));

/// Whether [day]'s own pill on the strip shows "عيد الفطر" (RAM-2), since
/// a plain text search can't tell which day a match belongs to.
bool eidShownFor(WidgetTester tester, DateTime day) => find
    .descendant(of: dayPill(day), matching: find.text('عيد الفطر'))
    .evaluate()
    .isNotEmpty;

/// Starts 3 days after the FakeClock's "today" (2026-09-19). Not a real
/// table entry: Ramadan mode's tests don't depend on the built-in
/// calendar's actual dates. Its window (RAM-3) covers today regardless of
/// which day the shown week starts on, but the month itself doesn't
/// overlap the week yet — only the countdown card cares about this one.
final ramadanSoon = const RamadanMonth(1448, 2026, 9, 22, 30);

/// Starts on "today" itself, so today is day 1 (RAM-2).
final ramadanNow = const RamadanMonth(1448, 2026, 9, 19, 30);

/// Starts so "today" is day 5, for a short Hijri-label number (RAM-2).
final ramadanDay5 = const RamadanMonth(1448, 2026, 9, 15, 30);

/// Taps the Plan tab by icon, so it works whatever the language.
Future<void> goToPlan(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavPill),
      matching: find.byIcon(Icons.calendar_month_outlined),
    ),
  );
  await settle(tester);
}

Future<void> goToLibrary(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavPill),
      matching: find.byIcon(Icons.menu_book_outlined),
    ),
  );
  await settle(tester);
}

/// Scrolls the day list (not the card or the "رمضان"/"الأسبوع" toggle,
/// which are pinned above it and don't scroll — must-fix) to the top, to
/// reach day 1 after the view has scrolled to today.
Future<void> scrollToTop(WidgetTester tester) async {
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 5000));
  await tester.pump();
}

void main() {
  testWidgets(
    'RAM-3: the card counts down 3 days before, "ليس الآن" hides it',
    (tester) async {
      final (_, settings) = await pumpApp(
        tester,
        withRecipe: true,
        ramadanMonths: [ramadanSoon],
      );
      await goToPlan(tester);
      // must-fix: the card is pinned above the scrolling day list now, so
      // it's hit-testable right away — no need to scroll for it, and a
      // hidden card would fail these on its own (unlike a plain find,
      // which sees off-screen text too).
      expect(
        find
            .text('رمضان بعد 3 أيام. نحوّل الخطة إلى سحور وإفطار؟')
            .hitTestable(),
        findsOneWidget,
      );
      expect(find.text('تفعيل').hitTestable(), findsOneWidget);
      expect(find.text('ليس الآن').hitTestable(), findsOneWidget);

      await tester.tap(find.text('ليس الآن'));
      await settle(tester);
      expect(find.text('تفعيل'), findsNothing);
      expect(find.textContaining('رمضان بعد'), findsNothing);
      // should-fix (missing coverage): "ليس الآن" only dismisses the
      // card for this Ramadan — it must never turn the mode on.
      expect(settings.settings.ramadanMode, isFalse);
    },
  );

  testWidgets(
    'RAM-3, RAM-1: "تفعيل" turns Ramadan mode on and switches the slots',
    (tester) async {
      // Started days ago, so it overlaps whatever week is shown around
      // today, whichever day that week happens to start on (PLAN-1).
      final (_, settings) = await pumpApp(
        tester,
        withRecipe: true,
        ramadanMonths: [ramadanDay5],
      );
      await goToPlan(tester);
      expect(find.text('تفعيل').hitTestable(), findsOneWidget); // must-fix

      await tester.tap(find.text('تفعيل'));
      await settle(tester);
      expect(settings.settings.ramadanMode, isTrue);
      expect(find.text('تفعيل'), findsNothing); // the card is gone
      expect(find.text('السحور'), findsWidgets);
      expect(find.text('الإفطار'), findsWidgets);
    },
  );

  testWidgets(
    'RAM-2, RAM-1: a Hijri label shows, an ordinary entry stays visible, '
    'and the add sheet offers Ramadan slots (decision 7)',
    (tester) async {
      await pumpApp(
        tester,
        withRecipe: true,
        ramadanMode: true,
        digits: DigitStyle.arabic,
        ramadanMonths: [ramadanDay5],
      );
      await goToPlan(tester);
      // Today is day 5 (RAM-2): on its pill, and under the day's heading.
      expect(
        find.descendant(
          of: dayPill(plan.today),
          matching: find.text('٥ رمضان'),
        ),
        findsOneWidget,
      );
      expect(shown('٥ رمضان'), findsNWidgets(2));

      await tester.runAsync(
        () => plan.add(
          date: plan.today,
          slot: MealSlot.lunch,
          note: 'غداء العائلة',
        ),
      );
      await settle(tester);
      // RAM-1: nothing already planned is hidden — the note in lunch, an
      // ordinary slot, still shows on this Ramadan day.
      expect(shown('غداء العائلة'), findsOneWidget);
      expect(find.text('غداء'), findsWidgets); // its slot label, "Lunch"

      await goToLibrary(tester);
      await tester.tap(shown('كبسة لحم'));
      await settle(tester);
      await tester.tap(find.byTooltip('أضف إلى الخطة'));
      await settle(tester);
      expect(find.widgetWithText(ChoiceChip, 'السحور'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'الإفطار'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'وجبة خفيفة'), findsOneWidget);
    },
  );

  testWidgets('RAM-4: the "رمضان" view lists the whole month, day 30 shown', (
    tester,
  ) async {
    await pumpApp(
      tester,
      withRecipe: true,
      ramadanMode: true,
      ramadanMonths: [ramadanNow],
    );
    await goToPlan(tester);
    // must-fix: the toggle is pinned, so it's tappable without scrolling.
    expect(find.text('الأسبوع').hitTestable(), findsOneWidget);
    expect(find.text('رمضان').hitTestable(), findsOneWidget);
    expect(shown('30 رمضان'), findsNothing); // not shown from the week view

    await tester.tap(find.text('رمضان'));
    await settle(tester);
    // must-fix: switching to the month view scrolls to today (day 1 of a
    // 30-day month here), so day 30's card is already built even though
    // it isn't the one in the viewport (the day list is never lazy).
    expect(shown('30 رمضان'), findsOneWidget); // day 30, RamadanMonth(...30)

    await tester.tap(find.text('الأسبوع'));
    await settle(tester);
    expect(shown('30 رمضان'), findsNothing); // back to the 7-day week
  });

  testWidgets('RAM-4: the month view is a grid of its days, with the chosen '
      "day's Ramadan meals under it and عيد الفطر after the last day", (
    tester,
  ) async {
    await pumpApp(
      tester,
      withRecipe: true,
      ramadanMode: true,
      ramadanMonths: [ramadanNow], // today is day 1 of 30
    );
    await tester.runAsync(
      () => plan.add(
        date: DateTime(2026, 10, 8), // day 20
        slot: MealSlot.iftar,
        note: 'عزومة',
      ),
    );
    await goToPlan(tester);
    await tester.tap(find.text('رمضان'));
    await settle(tester);

    // All 30 days as pills, today chosen, and Eid after the last one.
    final pills = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('plan-day-'),
    );
    expect(pills, findsNWidgets(30));
    expect(
      tester.widget<Semantics>(dayPill(plan.today)).properties.selected,
      isTrue,
    );
    expect(find.textContaining('عيد الفطر · '), findsOneWidget);
    // Today's meals are Ramadan's (RAM-1).
    expect(find.text('السحور'), findsOneWidget);
    expect(find.text('الإفطار'), findsOneWidget);
    expect(find.text('وجبة خفيفة'), findsOneWidget);
    expect(find.text('غداء'), findsNothing);
    expect(find.text('عزومة'), findsNothing);

    // Day 20: its own meals under the grid, its Hijri day on its heading.
    // No manual ensureVisible: day 20's pill is already on screen, so the
    // hitTestable check below only passes if choosing it scrolls the app.
    await tester.tap(dayPill(DateTime(2026, 10, 8)));
    await settle(tester);
    // should-fix: choosing a day scrolls its meals into view, rather than
    // leaving them below the grid where nothing seems to happen.
    expect(find.text('عزومة').hitTestable(), findsOneWidget);
    expect(shown('20 رمضان'), findsNWidgets(2)); // its pill and its heading
    expect(find.text('وجبة واحدة'), findsOneWidget);
  });

  testWidgets(
    'RAM-4, must-fix: a moon-sighting shift moves the month while its '
    'view is open',
    (tester) async {
      final (_, settings) = await pumpApp(
        tester,
        withRecipe: true,
        ramadanMode: true,
        ramadanMonths: [ramadanNow], // starts today, 30 days
      );
      await goToPlan(tester);
      await tester.tap(find.text('رمضان'));
      await settle(tester);
      expect(shown('30 رمضان'), findsOneWidget);
      expect(dateKey(plan.days.last), '2026-10-18'); // 19 Sep + 29 days

      // The night-of-sighting "+1" from Settings, applied directly here
      // (Settings' own row is driven by hand in a separate test) — RAM-2.
      // tester.runAsync: a real (non-fake-timer) DB write, called outside
      // any widget event handler, needs to escape the fake-async zone or
      // it never resolves (same reason plan.add is wrapped elsewhere).
      await tester.runAsync(
        () => settings.update(
          settings.settings.copyWith(ramadanShift: 1, ramadanShiftYear: 1448),
        ),
      );
      await settle(tester);

      // Before the fix this stayed on the old range: day 30 disappeared
      // (the month now runs a day later) and the view kept a day that's
      // no longer in Ramadan at all.
      expect(dateKey(plan.days.last), '2026-10-19'); // moved a day later
      expect(shown('30 رمضان'), findsOneWidget); // still shown, on the new day
    },
  );

  testWidgets('RAM-4, must-fix: the month view recovers once today passes Eid, '
      'instead of getting stuck', (tester) async {
    // Last day of Ramadan is "today" itself (19 Sep): the app left open
    // on the month view overnight, into Eid morning.
    final endsToday = const RamadanMonth(1448, 2026, 8, 21, 30);
    await pumpApp(
      tester,
      withRecipe: true,
      ramadanMode: true,
      ramadanMonths: [endsToday],
    );
    await goToPlan(tester);
    await tester.tap(find.text('رمضان'));
    await settle(tester);
    expect(find.text('رمضان').hitTestable(), findsOneWidget); // in the view
    expect(plan.days.length, 30);

    clock.advance(const Duration(days: 1)); // Eid morning
    // Something has to touch PlanState for the screen to notice the
    // clock moved (nothing else does, on a phone left idle) — a no-op
    // week re-show plays that role here.
    await tester.runAsync(() => plan.showWeek(plan.weekStart));
    await settle(tester);

    // Before the fix: the toggle vanished (today is outside the window)
    // but _monthView stayed true, so the screen lost its week arrows and
    // "clear week" too, with no way back but turning the mode off in
    // Settings.
    expect(plan.days.length, 7);
    expect(find.text('رمضان'), findsNothing); // the toggle itself is gone
    expect(find.byTooltip('الأسبوع التالي'), findsOneWidget);
    expect(find.byTooltip('المزيد'), findsOneWidget); // "مسح الأسبوع"
  });

  testWidgets(
    'RAM-1: adding from a recipe page on a Ramadan day never offers or '
    'saves an ordinary slot (must-fix)',
    (tester) async {
      await pumpApp(
        tester,
        withRecipe: true,
        ramadanMode: true,
        ramadanMonths: [ramadanDay5], // today is a Ramadan day
      );
      await tester.tap(find.text('كبسة لحم'));
      await settle(tester);
      await tester.tap(find.byTooltip('أضف إلى الخطة'));
      await settle(tester);

      // Before the fix: a 4th chip, غداء (the default "last meal used"),
      // was offered and already selected, so a plain 2-tap add (button,
      // Save) saved into lunch on a Ramadan day.
      expect(find.widgetWithText(ChoiceChip, 'غداء'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'فطور'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'عشاء'), findsNothing);

      await tester.tap(find.text('حفظ'));
      await settle(tester);
      expect(
        plan.entries.single.slot,
        anyOf(MealSlot.suhoor, MealSlot.iftar, MealSlot.snack),
      );
    },
  );

  testWidgets(
    'RAM-1: a meal picked on a Ramadan day maps onto an ordinary day\'s '
    'own slots, and back again, whenever the day chip changes (must-fix)',
    (tester) async {
      // Ramadan starts in 3 days: today is ordinary, and today+3 is
      // already inside Ramadan — both directions of the mapping are
      // reachable from one sheet.
      final (_, settings) = await pumpApp(
        tester,
        withRecipe: true,
        ramadanMode: true,
        ramadanMonths: [ramadanSoon],
      );
      await tester.tap(find.text('كبسة لحم'));
      await settle(tester);
      await tester.tap(find.byTooltip('أضف إلى الخطة'));
      await settle(tester);

      // Pick a Ramadan day, then iftar, to make it the "last meal used".
      // Found by its own rendered label, not position: a Wrap can put the
      // day chips on more than one row.
      final ctx = tester.element(find.byType(Scaffold).first);
      final day3 = DateTime(2026, 9, 22); // today (19 Sep) + 3 days
      final day3Label = settings.inDigits(
        MaterialLocalizations.of(ctx).formatShortMonthDay(day3),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, day3Label));
      await settle(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'الإفطار'));
      await settle(tester);
      await tester.tap(find.text('حفظ'));
      await settle(tester);

      // Reopens on today (ordinary): iftar isn't one of today's slots, so
      // it must map onto lunch, not stay a hidden selection or fall back
      // to whichever chip happens to be first.
      await tester.tap(find.byTooltip('أضف إلى الخطة'));
      await settle(tester);
      expect(find.widgetWithText(ChoiceChip, 'السحور'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'الإفطار'), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'غداء'))
            .selected,
        isTrue,
      );
    },
  );

  testWidgets(
    'RAM-1, RAM-2: the Settings Ramadan section works even with an empty '
    'library, where PlanScreen is never mounted (should-fix)',
    (tester) async {
      await pumpApp(tester, ramadanMonths: [ramadanDay5]); // empty library
      await tester.tap(find.byTooltip('الإعدادات'));
      await settle(tester);
      // byTooltip finds the Tooltip that IconButton wraps its child in, so
      // the button itself — what's actually laid out on screen to tap —
      // is an ancestor of that, not the match itself.
      Finder buttonFinder(String tooltip) => find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      );
      IconButton buttonFor(String tooltip) =>
          tester.widget<IconButton>(buttonFinder(tooltip));
      final earlier = buttonFinder('يوم أبكر');
      final later = buttonFinder('يوم لاحق');

      // The Ramadan section is the last one, below the fold in a ListView
      // (which, unlike the plan's SingleChildScrollView, only builds what's
      // near the viewport) — scroll to its shift row first, which also
      // brings the switch above it into view. scrollUntilVisible only
      // scrolls until the item is *built* (a ListView's cache extent can
      // build it slightly before it's actually on screen), so follow up
      // with ensureVisible to bring it fully into the viewport for tap.
      await tester.scrollUntilVisible(
        earlier,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(earlier);
      await tester.pump();
      expect(find.text('وضع رمضان'), findsOneWidget);

      Text startLabel() =>
          tester.widget<Text>(find.textContaining('بداية رمضان').first);
      final before = startLabel().data;
      expect(buttonFor('يوم أبكر').onPressed, isNotNull);

      await tester.tap(earlier);
      await settle(tester);
      expect(startLabel().data, isNot(before)); // the row actually moved
      expect(buttonFor('يوم أبكر').onPressed, isNull); // floor

      await tester.tap(later);
      await settle(tester);
      expect(startLabel().data, before); // back to the unshifted date

      await tester.tap(later);
      await settle(tester);
      expect(buttonFor('يوم لاحق').onPressed, isNull); // ceiling
    },
  );

  testWidgets(
    'RAM-2: the eid label shows on the day after Ramadan, and a shift '
    'moves it a day (should-fix, missing coverage)',
    (tester) async {
      // Last day 20 Sep, eid 21 Sep: both inside the shown week once it's
      // pinned to start on Saturday (19-25 Sep) — the platform's own
      // region, which "بحسب المنطقة" would otherwise follow, isn't fixed
      // in a test environment (PLAN-1), and the test only cares about the
      // Ramadan-specific behavior.
      final endsSoon = const RamadanMonth(1448, 2026, 8, 22, 30);
      final (_, settings) = await pumpApp(
        tester,
        withRecipe: true,
        ramadanMode: true,
        ramadanMonths: [endsSoon],
      );
      await tester.runAsync(
        () => settings.update(
          settings.settings.copyWith(weekStart: WeekStart.saturday),
        ),
      );
      await goToPlan(tester);
      expect(eidShownFor(tester, DateTime(2026, 9, 21)), isTrue);
      expect(eidShownFor(tester, DateTime(2026, 9, 22)), isFalse);

      await tester.runAsync(
        () => settings.update(
          settings.settings.copyWith(ramadanShift: 1, ramadanShiftYear: 1448),
        ),
      );
      await settle(tester);
      expect(eidShownFor(tester, DateTime(2026, 9, 21)), isFalse);
      expect(eidShownFor(tester, DateTime(2026, 9, 22)), isTrue);
    },
  );

  testWidgets(
    'RAM-4, PLAN-4: an entry can move beyond the usual 7-day window from '
    'the month view (should-fix)',
    (tester) async {
      final (_, settings) = await pumpApp(
        tester,
        withRecipe: true,
        ramadanMode: true,
        ramadanMonths: [ramadanNow], // today is day 1, 30-day month
      );
      await tester.runAsync(
        () => plan.add(
          date: plan.today,
          slot: MealSlot.iftar,
          note: 'حفل رمضاني',
        ),
      );
      await goToPlan(tester);
      await tester.tap(find.text('رمضان'));
      await settle(tester);

      // Under the month's grid, so scrolled to first.
      await tester.ensureVisible(shown('حفل رمضاني'));
      await tester.pump();
      await tester.longPress(shown('حفل رمضاني'));
      await settle(tester);
      await tester.tap(find.text('نقل'));
      await settle(tester);

      final ctx = tester.element(find.byType(Scaffold).first);
      final day20 = DateTime(2026, 10, 8); // 19 Sep + 19 days
      final label = settings.inDigits(
        MaterialLocalizations.of(ctx).formatShortMonthDay(day20),
      );
      final chip = find.widgetWithText(ChoiceChip, label);
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await settle(tester);
      await tester.tap(find.text('حفظ'));
      await settle(tester);

      expect(dateKey(plan.entries.single.date), dateKey(day20));
    },
  );

  testWidgets('RAM-4, PLAN-5: "Add to groceries" from the month view lists the '
      "month's remaining entries only, not a day already passed "
      '(should-fix, missing coverage)', (tester) async {
    final (recipes, _) = await pumpApp(
      tester,
      withRecipe: true,
      ramadanMode: true,
      ramadanMonths: [ramadanDay5], // today is day 5: day 1 is past
    );
    final recipeId = recipes.recipes.single.id;
    await tester.runAsync(() async {
      await plan.add(
        date: DateTime(2026, 9, 15), // day 1, already gone by
        slot: MealSlot.suhoor,
        recipeId: recipeId,
        servings: 6,
      );
      await plan.add(
        date: DateTime(2026, 10, 4), // day 20
        slot: MealSlot.iftar,
        recipeId: recipeId,
        servings: 6,
      );
    });
    await goToPlan(tester);
    await tester.tap(find.text('رمضان'));
    await settle(tester);
    await tester.tap(find.byTooltip('أضف إلى المشتريات'));
    await settle(tester);

    // Scoped to the sheet's own candidate row: the same title also shows
    // on the day cards behind it (day 1 and day 20 both plan this recipe).
    expect(find.byType(CheckboxListTile), findsOneWidget); // day 20 only
    expect(
      find.descendant(
        of: find.byType(CheckboxListTile),
        matching: find.text('كبسة لحم'),
      ),
      findsOneWidget,
    );
  });

  for (final lang in [LanguagePref.ar, LanguagePref.en]) {
    testWidgets('${lang.name} at 1.3x text: the card, no overflow (LANG-6)', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        textScale: 1.3,
        withRecipe: true,
        ramadanMonths: [ramadanDay5],
      );
      await goToPlan(tester);
      expect(tester.takeException(), isNull);
      await scrollToTop(tester);
      final enable = lang == LanguagePref.ar ? 'تفعيل' : 'Enable';
      await tester.tap(find.text(enable));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '${lang.name} at 1.3x text: the Ramadan month view, no overflow '
      '(LANG-6)',
      (tester) async {
        await pumpApp(
          tester,
          language: lang,
          textScale: 1.3,
          withRecipe: true,
          ramadanMode: true,
          ramadanMonths: [ramadanNow],
        );
        await goToPlan(tester);
        expect(tester.takeException(), isNull);
        await scrollToTop(tester);
        final monthLabel = lang == LanguagePref.ar ? 'رمضان' : 'Ramadan';
        await tester.tap(find.text(monthLabel));
        await settle(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('${lang.name} at 1.3x text: the Settings Ramadan section, no '
        'overflow (LANG-6, should-fix: missing coverage)', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        textScale: 1.3,
        ramadanMonths: [ramadanDay5],
      );
      final settingsTooltip = lang == LanguagePref.ar
          ? 'الإعدادات'
          : 'Settings';
      await tester.tap(find.byTooltip(settingsTooltip));
      await settle(tester);
      expect(tester.takeException(), isNull);
      final earlierTooltip = lang == LanguagePref.ar
          ? 'يوم أبكر'
          : 'One day earlier';
      final earlierButton = find.ancestor(
        of: find.byTooltip(earlierTooltip),
        matching: find.byType(IconButton),
      );
      // Below the fold at 1.3x even more than usual (LANG-6), and further
      // still now that LOOK-1's "الطراز"/"Look" row sits above this
      // section too — ensureVisible scrolls it fully into view rather
      // than stopping as soon as a fixed-delta scroll merely reaches it.
      await tester.scrollUntilVisible(
        earlierButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(earlierButton);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(earlierButton);
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
