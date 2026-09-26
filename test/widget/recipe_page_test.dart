// LOOK-13 (the recipe page) and LOOK-14 (cook mode) on screen: the fact
// tiles, the two tabs, the action bar and its banner, the source link; the
// step rail, the timer cards and bands, the bottom controls in both
// directions, and the ingredients sheet.
import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show DebugSemanticsDumpOrder, SemanticsNode;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/quantity/convert.dart' show UnitView;
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/providers/recipes_state.dart';
import 'package:wasfati/services/ads.dart';
import 'package:wasfati/theme/decor.dart';
import 'package:wasfati/widgets/ad_slot.dart';
import 'package:wasfati/widgets/amount_line.dart';
import 'package:wasfati/widgets/digit_box.dart';
import 'package:wasfati/widgets/segmented_pill.dart';
import 'package:wasfati/widgets/sufra_card.dart';

import 'app_test.dart'
    show
        alerts,
        links,
        openStepsTab,
        pumpApp,
        reveal,
        settle,
        shown,
        tapOnPage,
        timers;

/// Saves [build]'s recipe and opens its page.
Future<Recipe> _open(
  WidgetTester tester,
  RecipesState recipes,
  Recipe Function(RecipesState) build,
) async {
  final r = build(recipes);
  await tester.runAsync(() => recipes.save(r));
  await settle(tester);
  await tester.tap(shown(r.title).first);
  await settle(tester);
  return r;
}

Recipe _plain(
  RecipesState recipes, {
  String title = 'شوربة',
  int? prep,
  int? cook,
  int? servings,
  List<String> steps = const [],
  List<String> lines = const ['2 كوب عدس'],
  String? notes,
}) {
  final repo = recipes.repository;
  final now = repo.now();
  return Recipe(
    id: repo.newId(),
    title: title,
    prepMinutes: prep,
    cookMinutes: cook,
    servings: servings,
    notes: notes,
    ingredients: [
      if (lines.isNotEmpty)
        Section(
          id: repo.newId(),
          items: [for (final l in lines) IngredientLine.parse(repo.newId(), l)],
        ),
    ],
    steps: [
      if (steps.isNotEmpty)
        Section(
          id: repo.newId(),
          items: [for (final s in steps) RecipeStep(id: repo.newId(), text: s)],
        ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

/// The kabsa's page (helpers.dart), opened from the library.
Future<void> _openKabsa(WidgetTester tester) async {
  await tester.tap(find.text('كبسة لحم'));
  await settle(tester);
}

Future<void> _startCooking(WidgetTester tester) async {
  // The action bar's primary pill, in either language.
  await tester.tap(find.byIcon(Icons.play_arrow_rounded));
  await settle(tester);
}

/// A banner network that can't size a banner (GoogleAdService.bannerSize's
/// null): banners are on, but the slot stays empty.
class _NoSizeAds extends NoopAdService {
  _NoSizeAds()
    : super(
        consent: const AdConsent(
          canRequestAds: true,
          privacyOptionsRequired: false,
        ),
        fills: true,
      );

  @override
  Future<BannerDims?> bannerSize(int width) async => null;
}

/// The step text's duration pill (LOOK-13): the sunk box holding [phrase].
Finder _pill(String phrase) => find.ancestor(
  of: find.text(phrase),
  matching: find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).borderRadius ==
            BorderRadius.circular(999),
  ),
);

void main() {
  group('LOOK-13: the recipe page', () {
    testWidgets('REC-3: the fact tiles show prep, cook and servings, and '
        'only the ones the recipe has', (tester) async {
      final (recipes, _) = await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      // The kabsa has all three: a caption over each value.
      expect(find.text('التحضير'), findsOneWidget);
      expect(find.text('60 دقيقة'), findsOneWidget);
      expect(find.text('الطبخ'), findsOneWidget);
      expect(find.text('120 دقيقة'), findsOneWidget);
      expect(find.text('الحصص'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);

      // Only a cook time: one tile, never a "0" or an empty one.
      await _open(tester, recipes, (r) => _plain(r, cook: 25));
      expect(find.text('الطبخ'), findsOneWidget);
      expect(find.text('25 دقيقة'), findsOneWidget);
      expect(find.text('التحضير'), findsNothing);
      expect(find.text('الحصص'), findsNothing);
      await tester.binding.handlePopRoute();
      await settle(tester);

      // None: no tiles at all.
      await _open(tester, recipes, (r) => _plain(r, title: 'سلطة'));
      expect(find.text('التحضير'), findsNothing);
      expect(find.text('الطبخ'), findsNothing);
      expect(find.text('الحصص'), findsNothing);
    });

    testWidgets('opens on Ingredients, with the scale controls in it; the '
        'Steps tab swaps them for the steps', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);

      // Ingredients: the stepper, the multipliers, the unit views, the lines.
      expect(find.text('6 حصص'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
      expect(find.text('كما كُتبت'), findsOneWidget);
      expect(shown('1 كيلو لحم ضأن'), findsOneWidget);
      expect(find.text('للدقوس'), findsOneWidget); // REC-4's group label
      expect(find.text('يحمر اللحم في الزبدة.'), findsNothing);

      await openStepsTab(tester);
      expect(find.text('يحمر اللحم في الزبدة.'), findsOneWidget);
      // The whole step: its text, then its duration once, in its pill.
      final step = shown('يضاف الأرز ويترك');
      expect(step, findsOneWidget);
      expect(
        find.descendant(of: step, matching: find.text('15 دقيقة')),
        findsOneWidget,
      );
      expect(find.text('1'), findsOneWidget); // the steps' own numbers
      expect(find.text('2'), findsOneWidget);
      // The scale controls live in Ingredients only.
      expect(find.text('×2'), findsNothing);
      expect(find.text('كما كُتبت'), findsNothing);
      expect(shown('1 كيلو لحم ضأن'), findsNothing);

      await openStepsTab(tester, label: 'المكونات');
      expect(find.text('×2'), findsOneWidget);
      expect(find.text('يحمر اللحم في الزبدة.'), findsNothing);
    });

    testWidgets('a duration in a step is a sunk pill with a timer icon, '
        'but is not a button: timers run in cook mode', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      await openStepsTab(tester);
      final step = shown('يضاف الأرز ويترك');
      expect(step, findsOneWidget);
      final phrase = find.descendant(of: step, matching: find.text('15 دقيقة'));
      expect(phrase, findsOneWidget);
      final context = tester.element(phrase);
      final cs = Theme.of(context).colorScheme;
      expect(tester.widget<Text>(phrase).style?.color, cs.primary);
      final pill = _pill('15 دقيقة');
      expect(pill, findsOneWidget);
      expect(
        (tester.widget<Container>(pill).decoration! as BoxDecoration).color,
        Decor.of(context).sunk,
      );
      expect(
        find.descendant(of: pill, matching: find.byIcon(Icons.timer_outlined)),
        findsOneWidget,
      );
      // The text around it: "." follows the pill.
      final plain = tester.widget<Text>(step).textSpan!.toPlainText();
      expect(plain.endsWith('.'), isTrue);
      expect(find.byTooltip('ابدأ مؤقت 15:00'), findsNothing);
      expect(find.text('ابدأ مؤقت 15:00'), findsNothing);
    });

    testWidgets('the notes follow the steps, in the Steps tab', (tester) async {
      final (recipes, _) = await pumpApp(tester);
      await _open(
        tester,
        recipes,
        (r) => _plain(
          r,
          steps: ['اغسلي العدس.', 'اطبخيه على نار هادئة.'],
          notes: 'يُقدّم مع الليمون.',
        ),
      );
      expect(find.text('يُقدّم مع الليمون.'), findsNothing);

      await openStepsTab(tester);
      final notes = find.text('يُقدّم مع الليمون.');
      await reveal(tester, notes);
      expect(notes, findsOneWidget);
      expect(find.text('ملاحظات'), findsOneWidget);
      expect(
        tester.getTopLeft(notes).dy,
        greaterThan(tester.getTopLeft(find.text('اطبخيه على نار هادئة.')).dy),
      );
    });

    testWidgets('COOK-1: "ابدأ الطبخ" only with at least one step; plan '
        'and groceries stay', (tester) async {
      final (recipes, _) = await pumpApp(tester);
      await _open(tester, recipes, (r) => _plain(r));
      expect(find.text('ابدأ الطبخ'), findsNothing);
      expect(find.byTooltip('أضف إلى الخطة'), findsOneWidget);
      expect(find.byTooltip('أضف إلى المشتريات'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);

      await _open(
        tester,
        recipes,
        (r) => _plain(r, title: 'عدس', steps: ['اطبخيه.']),
      );
      expect(find.text('ابدأ الطبخ'), findsOneWidget);
    });

    testWidgets('PLAN-3, GRO-2: the action bar\'s round buttons open their '
        'sheets', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);

      await tester.tap(find.byTooltip('أضف إلى الخطة'));
      await settle(tester);
      expect(find.widgetWithText(ChoiceChip, 'عشاء'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'حفظ'), findsOneWidget);
      await tester.tapAt(const Offset(180, 40)); // the sheet's barrier
      await settle(tester);

      await tester.tap(find.byTooltip('أضف إلى المشتريات'));
      await settle(tester);
      expect(find.text('إضافة'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(4));
    });

    testWidgets('ADS-9: the banner sits under the action bar, 8 dp clear of '
        'it, outside the scrolling page', (tester) async {
      await pumpApp(
        tester,
        withRecipe: true,
        adServiceOverride: NoopAdService(
          consent: const AdConsent(
            canRequestAds: true,
            privacyOptionsRequired: false,
          ),
          fills: true,
        ),
      );
      await _openKabsa(tester);
      final banner = find.byKey(noopBannerKey);
      expect(banner, findsOneWidget);
      expect(
        find.ancestor(of: banner, matching: find.byType(Scrollable)),
        findsNothing,
      );
      final bar = [
        find.text('ابدأ الطبخ'),
        find.byTooltip('أضف إلى الخطة'),
        find.byTooltip('أضف إلى المشتريات'),
      ];
      for (final f in bar) {
        expect(
          tester.getRect(f).bottom + AdSlot.gap,
          lessThanOrEqualTo(tester.getRect(banner).top),
        );
      }
      // LOOK-8: exactly the slot's 8 dp between the bar's buttons and the
      // ad, with nothing between them.
      expect(
        tester.getRect(find.byTooltip('أضف إلى الخطة')).bottom + AdSlot.gap,
        moreOrLessEquals(tester.getRect(banner).top),
      );
      // Scrolled to the end, the page's last line still clears the bar.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await settle(tester);
      final last = shown('طماطم');
      expect(
        tester.getRect(last).bottom,
        lessThanOrEqualTo(tester.getRect(find.byTooltip('أضف إلى الخطة')).top),
      );
    });

    testWidgets('the source chip opens the recipe\'s own link, and says so '
        'when nothing can', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      await tester.tap(find.text('من fatafeat.com'));
      await settle(tester);
      expect(links.opened, [Uri.parse('https://www.fatafeat.com/recipe/1632')]);
      expect(find.text('تعذّر فتح الرابط.'), findsNothing);

      links.opens = false;
      await tester.tap(find.text('من fatafeat.com'));
      await settle(tester);
      expect(find.text('تعذّر فتح الرابط.'), findsOneWidget);
    });

    testWidgets('a recipe with no photo opens under its drawn cover, with the '
        'round buttons over it (LOOK-10)', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      for (final tooltip in ['رجوع', 'مشاركة', 'تعديل', 'المزيد']) {
        expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
      }
      await tester.tap(find.byTooltip('المزيد'));
      await settle(tester);
      expect(find.text('حذف'), findsOneWidget);
      await tester.tapAt(const Offset(180, 40));
      await settle(tester);
      await tester.tap(find.byTooltip('رجوع'));
      await settle(tester);
      expect(find.text('ابدأ الطبخ'), findsNothing); // back on the library
    });
  });

  group('LOOK-14: cook mode', () {
    testWidgets('the rail marks the current step, the ones done, and the ones '
        'to come', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      await _startCooking(tester);
      final cs = Theme.of(tester.element(find.text('التالي'))).colorScheme;
      Color colour(int i) =>
          (tester.widget<Container>(find.byKey(Key('rail-$i'))).decoration!
                  as BoxDecoration)
              .color!;
      double height(int i) => tester.getSize(find.byKey(Key('rail-$i'))).height;

      expect(find.text('الخطوة 1 من 2'), findsOneWidget);
      expect(height(0), 6);
      expect(colour(0), cs.primary);
      expect(height(1), 4);
      expect(colour(1), isNot(cs.primary));

      await tester.tap(find.text('التالي'));
      await settle(tester);
      expect(find.text('الخطوة 2 من 2'), findsOneWidget);
      expect(height(0), 4);
      expect(colour(0), cs.primary.withValues(alpha: 0.45)); // done
      expect(height(1), 6);
      expect(colour(1), cs.primary);
    });

    testWidgets('a step\'s timer card starts its timer; the band counts '
        'down and stops it (COOK-4)', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      await _startCooking(tester);
      await tester.tap(find.text('التالي'));
      await settle(tester);

      // The card: the duration, left to right, and its start pill.
      final ring = find.text('15:00');
      expect(ring, findsOneWidget);
      expect(tester.widget<Text>(ring).textDirection, TextDirection.ltr);
      // The ring's arc is only its starting mark.
      final painter = find
          .ancestor(
            of: find.byKey(const Key('timer-card-clock')),
            matching: find.byType(CustomPaint),
          )
          .first;
      expect(
        tester.renderObject(painter),
        paints
          ..arc(sweepAngle: 2 * math.pi)
          ..arc(sweepAngle: 0.08),
      );
      await tester.tap(find.text('ابدأ مؤقت 15:00'));
      await settle(tester);
      expect(timers.running.single.total, const Duration(minutes: 15));
      // Started once: the start pill is gone, and the card counts the
      // timer down with a stop pill in its place.
      expect(find.text('ابدأ مؤقت 15:00'), findsNothing);
      final cardClock = find.descendant(
        of: find.byKey(const Key('timer-card-clock')),
        matching: find.byType(DigitBox),
      );
      final band = find.byKey(
        ValueKey('timer-band-${timers.running.single.id}'),
      );
      final countdown = find.descendant(
        of: band,
        matching: find.byType(DigitBox),
      );
      expect(find.text('الخطوة 2'), findsOneWidget);
      String clockOf(Finder f) {
        final w = tester.widget<Text>(
          find.descendant(of: f, matching: find.byType(Text)).first,
        );
        return (w.data ?? w.textSpan!.toPlainText()).replaceAll(
          RegExp('[\u2066-\u2069\u202A-\u202E]'),
          '',
        );
      }

      // The card and the band show the same live countdown.
      expect(clockOf(cardClock), matches(RegExp(r'^1[45]:\d\d$')));
      expect(clockOf(cardClock), clockOf(countdown));
      // The ring's arc is the time left: nearly the whole ring.
      expect(
        tester.renderObject(painter),
        paints
          ..arc(sweepAngle: 2 * math.pi)
          ..something((method, args) {
            if (method != #drawArc) return false;
            final sweep = args[2] as double;
            return sweep > 6 && sweep <= 2 * math.pi;
          }),
      );

      final before = clockOf(countdown);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.runAsync(timers.tick);
      await tester.pump();
      expect(clockOf(countdown), isNot(before));
      expect(clockOf(cardClock), clockOf(countdown));

      // The card's own stop pill stops it, and the card is back to its
      // start state.
      final cardStop = find.ancestor(
        of: find.text('إيقاف المؤقت'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );
      expect(cardStop, findsOneWidget);
      expect(
        find.descendant(
          of: cardStop,
          matching: find.byIcon(Icons.stop_rounded),
        ),
        findsOneWidget,
      );
      await tester.tap(cardStop);
      await settle(tester);
      expect(timers.running, isEmpty);
      expect(band, findsNothing);
      expect(find.text('ابدأ مؤقت 15:00'), findsOneWidget);
      expect(clockOf(cardClock), '15:00');

      // Started again, the band's own button stops it too.
      await tester.tap(find.text('ابدأ مؤقت 15:00'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('timer-band-${timers.running.single.id}')),
          matching: find.byTooltip('إيقاف المؤقت'),
        ),
      );
      await settle(tester);
      expect(timers.running, isEmpty);
      expect(find.text('ابدأ مؤقت 15:00'), findsOneWidget);
    });

    testWidgets('a step\'s timer card goes back to its start state when its '
        'timer ends (COOK-4, COOK-5)', (tester) async {
      final (recipes, _) = await pumpApp(tester);
      await _open(tester, recipes, (r) => _plain(r, steps: ['Rest 1 sec.']));
      await _startCooking(tester);
      await tester.tap(find.text('ابدأ مؤقت 00:01'));
      await settle(tester);
      expect(find.text('ابدأ مؤقت 00:01'), findsNothing);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.runAsync(timers.tick);
      await settle(tester);
      expect(timers.running, isEmpty);
      expect(find.text('انتهى المؤقت: الخطوة 1'), findsOneWidget);
      expect(find.text('ابدأ مؤقت 00:01'), findsOneWidget);
      expect(find.text('إيقاف المؤقت'), findsNothing);
    });

    testWidgets('COOK-5: the "alerts are off" notice never covers the '
        'bottom controls', (tester) async {
      await pumpApp(tester, withRecipe: true);
      alerts.allowed = false;
      await _openKabsa(tester);
      await _startCooking(tester);
      await tester.tap(find.text('التالي'));
      await settle(tester);
      await tester.tap(find.text('ابدأ مؤقت 15:00'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final notice = find.byType(SnackBar);
      expect(notice, findsOneWidget);
      expect(
        find.descendant(of: notice, matching: find.textContaining('متوقفة')),
        findsOneWidget,
      );
      final next = find.ancestor(
        of: find.text('التالي'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );
      final previous = find.ancestor(
        of: find.text('السابق'),
        matching: find.byWidgetPredicate((w) => w is OutlinedButton),
      );
      for (final control in [next, previous, find.byTooltip('المكونات').last]) {
        expect(
          tester.getRect(notice).overlaps(tester.getRect(control)),
          isFalse,
        );
      }
      // "Next" takes the tap while the notice shows.
      final hit = tester.hitTestOnBinding(tester.getCenter(next));
      final target = tester.renderObject(next);
      expect(hit.path.any((e) => identical(e.target, target)), isTrue);
      await tester.tap(next);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(notice, findsOneWidget);
      expect(find.text('تم طبخها'), findsOneWidget);
    });

    testWidgets('LOOK-8: at 1.3x text, a long "1:30:00" fits inside the '
        'timer card\'s ring', (tester) async {
      final (recipes, _) = await pumpApp(tester, textScale: 1.3);
      await _open(
        tester,
        recipes,
        (r) => _plain(r, steps: ['يطهى على نار هادئة ساعة ونصف.']),
      );
      await _startCooking(tester);
      final clock = find.descendant(
        of: find.byKey(const Key('timer-card-clock')),
        matching: find.byType(DigitBox),
      );
      expect(shown('1:30:00'), findsWidgets);
      final ring = tester.getRect(
        find
            .ancestor(
              of: find.byKey(const Key('timer-card-clock')),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      // The ring's inner edge: its radius less the 10 dp stroke.
      final inner = ring.width / 2 - 10;
      final text = tester.getRect(clock);
      for (final corner in [
        text.topLeft,
        text.topRight,
        text.bottomLeft,
        text.bottomRight,
      ]) {
        expect((corner - ring.center).distance, lessThan(inner));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('every running timer has its band, the newest first, each '
        'with its step, its countdown and a stop button; a finished one is a '
        'band with its dismiss button (COOK-4, COOK-5)', (tester) async {
      final (recipes, _) = await pumpApp(tester, withRecipe: true);
      final r = recipes.recipes.single;
      Future<void> start(int step, Duration d) => tester.runAsync(
        () => timers.start(
          recipeId: r.id,
          recipeTitle: r.title,
          step: step,
          duration: d,
          notificationTitle: r.title,
          notificationBody: 'x',
          channelName: 'x',
        ),
      );
      await start(1, const Duration(minutes: 5));
      await start(2, const Duration(minutes: 10));
      await start(3, const Duration(minutes: 20));
      await _openKabsa(tester);
      await _startCooking(tester);

      Finder band(int step) => find.byKey(
        ValueKey(
          'timer-band-${timers.running.firstWhere((t) => t.step == step).id}',
        ),
      );
      // COOK-4: in the header, between the step rail and the step.
      expect(
        tester.getRect(band(3)).top,
        greaterThan(tester.getRect(find.byKey(const Key('rail-0'))).bottom),
      );
      expect(
        tester.getRect(band(3)).bottom,
        lessThanOrEqualTo(tester.getTopLeft(find.text('الخطوة 1 من 2')).dy),
      );
      // The newest (just started) is first, with its step and countdown.
      expect(
        tester.getRect(band(3)).top,
        lessThan(tester.getRect(band(2)).top),
      );
      expect(
        find.descendant(of: band(3), matching: find.text('الخطوة 3')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: band(3),
          matching: find.textContaining(RegExp(r'^(20:00|19:\d\d)$')),
        ),
        findsOneWidget,
      );

      // The oldest is a band too: scrolled to, it shows its step and
      // countdown, and its own button stops it.
      final oldest = band(1);
      await tester.dragUntilVisible(
        oldest,
        find.byKey(const Key('timer-bands')),
        const Offset(0, -40),
      );
      await tester.pump();
      expect(
        find.descendant(of: oldest, matching: find.text('الخطوة 1')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: oldest,
          matching: find.textContaining(RegExp(r'^(05:00|04:\d\d)$')),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: oldest, matching: find.byTooltip('إيقاف المؤقت')),
      );
      await settle(tester);
      expect(timers.running.map((t) => t.step), [2, 3]);
      expect(find.text('الخطوة 1'), findsNothing);

      // The step's text shows its duration as plain accent text: no icon,
      // no pill (Cook.dc.html).
      await tester.tap(find.text('التالي'));
      await settle(tester);
      final stepText = shown('يضاف الأرز ويترك 15 دقيقة.');
      expect(stepText, findsOneWidget);
      expect(
        find.descendant(
          of: stepText,
          matching: find.byIcon(Icons.timer_outlined),
        ),
        findsNothing,
      );

      await start(4, const Duration(milliseconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.runAsync(timers.tick);
      await settle(tester);
      expect(find.text('انتهى المؤقت: الخطوة 4'), findsOneWidget);
      await tester.tap(find.text('حسنًا'));
      await settle(tester);
      expect(find.text('انتهى المؤقت: الخطوة 4'), findsNothing);
    });

    testWidgets('past 14 steps the rail is one progress bar', (tester) async {
      final (recipes, _) = await pumpApp(tester);
      await _open(
        tester,
        recipes,
        (r) => _plain(r, steps: [for (var i = 1; i <= 15; i++) 'خطوة $i.']),
      );
      await _startCooking(tester);
      final bar = find.byKey(const Key('rail-progress'));
      expect(bar, findsOneWidget);
      expect(find.byKey(const Key('rail-0')), findsNothing);
      double value() => tester.widget<LinearProgressIndicator>(bar).value!;
      expect(value(), closeTo(1 / 15, 1e-9));
      await tester.tap(find.text('التالي'));
      await settle(tester);
      expect(value(), closeTo(2 / 15, 1e-9));
    });

    for (final language in [LanguagePref.ar, LanguagePref.en]) {
      testWidgets('${language.name}: "next" is the widest control, on the '
          'reading end, pointing onward; "previous" goes back (COOK-2)', (
        tester,
      ) async {
        await pumpApp(tester, language: language, withRecipe: true);
        await _openKabsa(tester);
        await _startCooking(tester);
        final ar = language == LanguagePref.ar;
        final next = find.text(ar ? 'التالي' : 'Next');
        final previous = find.text(ar ? 'السابق' : 'Previous');
        Rect button(Finder label) => tester.getRect(
          find
              .ancestor(
                of: label,
                matching: find.byWidgetPredicate(
                  (w) => w is FilledButton || w is OutlinedButton,
                ),
              )
              .first,
        );
        // Right to left, "next" is on the left; left to right, the right.
        expect(
          button(next).center.dx < button(previous).center.dx,
          ar ? isTrue : isFalse,
        );
        expect(button(next).width, greaterThan(button(previous).width));
        // The chevron mirrors with the language, so it points onward.
        final chevron = find.descendant(
          of: find.ancestor(
            of: next,
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          ),
          matching: find.byIcon(Icons.chevron_right),
        );
        expect(chevron, findsOneWidget);
        expect(tester.widget<Icon>(chevron).icon!.matchTextDirection, isTrue);
        expect(
          Directionality.of(tester.element(chevron)),
          ar ? TextDirection.rtl : TextDirection.ltr,
        );

        final stepOf = ar ? 'الخطوة %s من 2' : 'Step %s of 2';
        await tester.tap(next);
        await settle(tester);
        expect(find.text(stepOf.replaceFirst('%s', '2')), findsOneWidget);
        await tester.tap(previous);
        await settle(tester);
        expect(find.text(stepOf.replaceFirst('%s', '1')), findsOneWidget);
      });
    }

    testWidgets('the ingredients sheet: the ×factor in its header, and a '
        'line ticked off stays ticked', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      await tapOnPage(tester, find.text('×2'));
      await _startCooking(tester);
      expect(find.text('×2'), findsOneWidget); // the top row's pill

      await tester.tap(find.byTooltip('المكونات').last); // the bottom bar's
      await settle(tester);
      expect(find.text('×2'), findsNWidgets(2)); // and the sheet's header
      final line = find.ancestor(
        of: shown('2 كيلو لحم ضأن'),
        matching: find.byType(CheckboxListTile),
      );
      expect(tester.getSize(line).height, greaterThanOrEqualTo(56));
      await tester.tap(line);
      await settle(tester);
      expect(tester.widget<CheckboxListTile>(line).value, isTrue);
      final amount = tester.widget<AmountLine>(
        find.ancestor(
          of: shown('2 كيلو لحم ضأن'),
          matching: find.byType(AmountLine),
        ),
      );
      expect(amount.style?.decoration, TextDecoration.lineThrough);

      // Closed and opened again, it's still ticked.
      await tester.tapAt(const Offset(180, 20));
      await settle(tester);
      await tester.tap(find.byTooltip('المكونات').first);
      await settle(tester);
      expect(tester.widget<CheckboxListTile>(line).value, isTrue);
    });

    testWidgets('COOK-6: the last page draws its star and offers "تم طبخها" '
        'and "تم"', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      await _startCooking(tester);
      await tester.tap(find.text('التالي'));
      await settle(tester);
      await tester.tap(find.text('التالي'));
      await settle(tester);
      expect(find.text('تم طبخها'), findsOneWidget);
      expect(find.text('تم'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsNothing); // drawn, not an icon
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == 'StarPainter',
        ),
        findsOneWidget,
      );
    });
  });

  group('the recipe page\'s edges and semantics', () {
    testWidgets('ADS-3: with banners on but no size for the slot, the action '
        'bar still clears the system bar', (tester) async {
      await pumpApp(
        tester,
        withRecipe: true,
        adServiceOverride: _NoSizeAds(),
        systemInsets: const EdgeInsets.only(bottom: 48),
      );
      await _openKabsa(tester);
      expect(find.byKey(noopBannerKey), findsNothing);
      final screen =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      for (final f in [
        find.text('ابدأ الطبخ'),
        find.byTooltip('أضف إلى الخطة'),
        find.byTooltip('أضف إلى المشتريات'),
      ]) {
        expect(tester.getRect(f).bottom, lessThanOrEqualTo(screen - 48));
      }
      // LOOK-8: an empty slot takes no space; the bar keeps only its own
      // 12 dp margin over the system bar.
      expect(
        tester.getRect(find.byTooltip('أضف إلى الخطة')).bottom,
        moreOrLessEquals(screen - 48 - 12),
      );
    });

    testWidgets('screen readers reach the floating buttons first, then the '
        'title as a heading that names the page', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);

      final back = tester.getSemantics(find.byTooltip('رجوع'));
      expect(back.flagsCollection.isButton, isTrue);
      expect(back.flagsCollection.isEnabled, Tristate.isTrue);

      final title = tester.getSemantics(find.text('كبسة لحم').last);
      expect(title.flagsCollection.isHeader, isTrue);
      expect(title.flagsCollection.namesRoute, isTrue);

      // Traversal order: every node, in the order a screen reader visits
      // (sort keys applied), from the root.
      final order = <SemanticsNode>[];
      void walk(SemanticsNode n) {
        order.add(n);
        n
            .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
            .forEach(walk);
      }

      var root = back;
      while (root.parent != null) {
        root = root.parent!;
      }
      walk(root);
      int at(SemanticsNode n) => order.indexOf(n);
      for (final tooltip in ['رجوع', 'مشاركة', 'تعديل', 'المزيد']) {
        expect(
          at(tester.getSemantics(find.byTooltip(tooltip))),
          lessThan(at(title)),
          reason: tooltip,
        );
      }
      handle.dispose();
    });

    testWidgets('a step\'s number and text, and a line and its "not scaled" '
        'mark, are each one stop', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      await tapOnPage(tester, find.text('×2'));
      // The kabsa's to-taste salt isn't scaled.
      final mark = find.text('لم يُعدَّل');
      expect(mark, findsWidgets);
      final markNode = tester.getSemantics(mark.first);
      expect(markNode.label, contains('ملح'));

      await openStepsTab(tester);
      final step = tester.getSemantics(find.text('يحمر اللحم في الزبدة.'));
      expect(step.label, contains('1'));
      expect(step.label, contains('يحمر اللحم في الزبدة.'));
      handle.dispose();
    });

    testWidgets('the recipe page and cook mode set the status bar\'s icons '
        'for the theme over a drawn cover', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      AnnotatedRegion<SystemUiOverlayStyle> region() => tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byWidgetPredicate(
              (w) => w is AnnotatedRegion<SystemUiOverlayStyle>,
            ),
          )
          .last;
      // Light theme, drawn cover: dark icons.
      expect(region().value.statusBarIconBrightness, Brightness.dark);
      expect(region().value.systemNavigationBarColor, isNull);
      await _startCooking(tester);
      expect(region().value.statusBarIconBrightness, Brightness.dark);
    });

    testWidgets('LOOK-3: the source chip keeps its outline edge; tags are '
        'plain sunk badges with no "#"; the multipliers have an edge and '
        'their own ink', (tester) async {
      final (recipes, _) = await pumpApp(tester, withRecipe: true);
      await tester.runAsync(() async {
        final kabsa = await recipes.repository.get(recipes.recipes.single.id);
        await recipes.save(kabsa!.copyWith(tags: ['رز']));
      });
      await settle(tester);
      await _openKabsa(tester);
      final context = tester.element(find.text('من fatafeat.com'));
      final cs = Theme.of(context).colorScheme;
      final chip = tester.widget<ActionChip>(find.byType(ActionChip));
      // No override: the theme's outline edge, in both brightnesses.
      expect(chip.side, isNull);
      expect(chip.materialTapTargetSize, MaterialTapTargetSize.shrinkWrap);
      // The whole 48 dp box around the pill still opens the link.
      final box = tester.getRect(
        find
            .ancestor(
              of: find.byType(ActionChip),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(box.height, greaterThanOrEqualTo(48));

      expect(find.text('رز'), findsOneWidget);
      expect(find.text('#رز'), findsNothing);
      expect(find.byType(Chip), findsNothing);

      final x2 = find.text('×2');
      final pill = tester.widget<Ink>(
        find.ancestor(of: x2, matching: find.byType(Ink)),
      );
      final border = (pill.decoration! as BoxDecoration).border! as Border;
      expect(border.top.color, cs.outline);
      expect(
        find.ancestor(
          of: x2,
          matching: find.byWidgetPredicate(
            (w) => w is Material && w.type == MaterialType.transparency,
          ),
        ),
        findsWidgets,
      );
    });
  });

  group('PR 3 fixes', () {
    testWidgets('LOOK-13: once the cover has scrolled past, a page-coloured '
        'bar with the title sits behind the round buttons', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      final bar = find.byKey(const Key('recipe-bar'));
      Color? barColour() =>
          (tester.widget<DecoratedBox>(bar).decoration as BoxDecoration).color;
      final cs = Theme.of(tester.element(bar)).colorScheme;
      // Over the cover: only the buttons float, with no bar and no title.
      expect(barColour()!.a, 0);
      expect(find.byKey(const Key('recipe-bar-title')), findsNothing);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await settle(tester);
      expect(barColour(), cs.surface);
      final title = find.byKey(const Key('recipe-bar-title'));
      expect(
        find.descendant(of: title, matching: find.text('كبسة لحم')),
        findsOneWidget,
      );
      final text = tester.widget<Text>(
        find.descendant(of: title, matching: find.byType(Text)),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      // The bar reaches under every button, and every button keeps its
      // tooltip.
      final barRect = tester.getRect(bar);
      for (final tip in ['رجوع', 'مشاركة', 'تعديل', 'المزيد']) {
        final button = tester.getRect(find.byTooltip(tip));
        expect(barRect.top, lessThanOrEqualTo(button.top));
        expect(barRect.bottom, greaterThanOrEqualTo(button.bottom));
      }
      // The title sits between the buttons, never under one.
      final titleRect = tester.getRect(title);
      expect(
        titleRect.overlaps(tester.getRect(find.byTooltip('رجوع'))),
        isFalse,
      );
      expect(
        titleRect.overlaps(tester.getRect(find.byTooltip('المزيد'))),
        isFalse,
      );
    });

    testWidgets('changing the unit view or the scale never reloads the page '
        'or moves its scroll', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      final views = find.byWidgetPredicate((w) => w is SegmentedPill<UnitView>);
      final metric = find.descendant(of: views, matching: find.text('غ / مل'));
      await reveal(tester, metric);
      final scrollable = find.byType(Scrollable).first;
      double offset() =>
          tester.state<ScrollableState>(scrollable).position.pixels;
      final before = offset();
      expect(before, greaterThan(0));

      await tester.tap(find.text('×2'));
      await settle(tester);
      expect(shown('2 كيلو'), findsWidgets);
      expect(offset(), before);

      await tester.tap(metric);
      await settle(tester);
      expect(
        tester.widget<SegmentedPill<UnitView>>(views).value,
        UnitView.metric,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(offset(), before);
    });

    testWidgets('DEL-2: the Undo notice after a delete goes away by itself '
        'after 5 s', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      await tester.tap(find.byTooltip('المزيد'));
      await settle(tester);
      await tester.tap(find.text('حذف'));
      await settle(tester);
      expect(find.text('حُذفت الوصفة'), findsOneWidget);
      expect(find.text('تراجع'), findsOneWidget);
      final notice = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(notice.duration, const Duration(seconds: 5));
      expect(notice.persist, isFalse);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('حُذفت الوصفة'), findsNothing);
      expect(find.text('تراجع'), findsNothing);
    });

    testWidgets('the editor asks before leaving only when a value changed, '
        'never after a tap or a selection', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      final title = find.widgetWithText(TextFormField, 'اسم الوصفة');
      Future<void> openEditor() async {
        await tester.tap(find.byTooltip('تعديل'));
        await settle(tester);
        expect(title, findsOneWidget);
      }

      Future<void> leave() async {
        await tester.binding.handlePopRoute();
        await settle(tester);
      }

      // Tapped into and a word selected: nothing changed, so no question.
      await openEditor();
      await tester.tap(title);
      await tester.pump();
      final field = tester.widget<EditableText>(
        find.descendant(of: title, matching: find.byType(EditableText)),
      );
      field.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 4,
      );
      await tester.pump();
      await leave();
      expect(find.text('تجاهل التعديلات؟'), findsNothing);
      expect(title, findsNothing);

      // A letter changed: it asks.
      await openEditor();
      await tester.enterText(title, 'كبسة لحمة');
      await tester.pump();
      await leave();
      expect(find.text('تجاهل التعديلات؟'), findsOneWidget);

      // Changed back to what it was: it no longer asks.
      await tester.tap(find.text('متابعة التعديل'));
      await settle(tester);
      await tester.enterText(title, 'كبسة لحم');
      await tester.pump();
      await leave();
      expect(find.text('تجاهل التعديلات؟'), findsNothing);
      expect(title, findsNothing);
    });

    for (final language in [LanguagePref.en, LanguagePref.ar]) {
      testWidgets('${language.name}: a cookbook tile reads its name and count '
          'with the language\'s own comma (LANG-6)', (tester) async {
        final handle = tester.ensureSemantics();
        final (recipes, _) = await pumpApp(
          tester,
          language: language,
          withRecipe: true,
        );
        await tester.runAsync(() => recipes.saveCookbook('حلويات'));
        await settle(tester);
        final en = language == LanguagePref.en;
        await tester.tap(find.text(en ? 'Cookbooks' : 'كتب الطبخ'));
        await settle(tester);
        expect(
          find.bySemanticsLabel(RegExp(en ? '^حلويات, ' : '^حلويات، ')),
          findsOneWidget,
        );
        if (en) expect(find.bySemanticsLabel(RegExp('،')), findsNothing);
        handle.dispose();
      });

      testWidgets('${language.name}: a library row reads its parts with the '
          'language\'s own comma (LANG-6)', (tester) async {
        final handle = tester.ensureSemantics();
        final (_, settings) = await pumpApp(
          tester,
          language: language,
          withRecipe: true,
        );
        await tester.runAsync(
          () => settings.update(settings.settings.copyWith(grid: false)),
        );
        await settle(tester);
        final en = language == LanguagePref.en;
        expect(
          find.bySemanticsLabel(RegExp(en ? r'^كبسة لحم, ' : r'^كبسة لحم، ')),
          findsOneWidget,
        );
        if (en) expect(find.bySemanticsLabel(RegExp('،')), findsNothing);
        handle.dispose();
      });
    }
  });

  group('SCALE-2: the scaler card', () {
    /// The card holding the unit views, and the unit views themselves.
    Finder unitViews() =>
        find.byWidgetPredicate((w) => w is SegmentedPill<UnitView>);
    Finder scaleCard() =>
        find.ancestor(of: unitViews(), matching: find.byType(SufraCard)).first;

    testWidgets('with no servings, the ×1 pill is only as wide as its factor '
        'and shares a row with the multipliers', (tester) async {
      final (recipes, _) = await pumpApp(tester);
      await _open(tester, recipes, (r) => _plain(r));
      final pill = find.byWidgetPredicate(
        (w) => w is DigitBox && w.text.startsWith('×'),
      );
      expect(pill, findsOneWidget);
      final readout = tester.getCenter(pill);
      for (final chip in ['×½', '×2', '×3']) {
        expect(
          (tester.getCenter(find.text(chip)).dy - readout.dy).abs(),
          lessThan(2),
          reason: chip,
        );
      }
      // Its sunk pill hugs the factor: far narrower than the card.
      final box = find
          .ancestor(of: pill, matching: find.byType(Container))
          .first;
      expect(
        tester.getSize(box).width,
        lessThan(tester.getSize(scaleCard()).width / 3),
      );
    });

    testWidgets('at ×1 the card ends right after the unit views; «إعادة» '
        'shows only while scaled', (tester) async {
      await pumpApp(tester, withRecipe: true);
      await _openKabsa(tester);
      double gap() =>
          tester.getBottomLeft(scaleCard()).dy -
          tester.getBottomLeft(unitViews()).dy;
      // The card's 12 dp padding, plus a hairline border in some looks.
      expect(gap(), inInclusiveRange(12, 13.5));
      expect(find.text('إعادة'), findsNothing);

      await tester.tap(find.text('×2'));
      await settle(tester);
      expect(find.text('إعادة'), findsOneWidget);
      expect(gap(), greaterThan(40));

      await tester.tap(find.text('إعادة'));
      await settle(tester);
      expect(find.text('إعادة'), findsNothing);
      expect(gap(), inInclusiveRange(12, 13.5));
    });
  });
}
