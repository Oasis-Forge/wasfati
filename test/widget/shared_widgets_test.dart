// The redesign's new shared widgets (RoundIconButton, ServingsStepper,
// SegmentedPill): no call site in this PR, but no test either — the gap
// that let the SegmentedPill/tap-target defects this PR fixes go unnoticed.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/l10n/app_localizations.dart';
import 'package:wasfati/models/settings.dart' show AppStyle;
import 'package:wasfati/theme/app_theme.dart';
import 'package:wasfati/theme/decor.dart';
import 'package:wasfati/widgets/empty_state.dart';
import 'package:wasfati/widgets/ornament.dart';
import 'package:wasfati/widgets/round_icon_button.dart';
import 'package:wasfati/widgets/segmented_pill.dart';
import 'package:wasfati/widgets/servings_stepper.dart';

Widget _themed(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: wasfatiTheme(AppStyle.saffron, brightness),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('RoundIconButton', () {
    testWidgets('carries a tooltip for accessibility', (tester) async {
      await tester.pumpWidget(
        _themed(
          RoundIconButton(icon: Icons.share, tooltip: 'شارك', onPressed: () {}),
        ),
      );
      expect(find.byTooltip('شارك'), findsOneWidget);
    });

    testWidgets('is read as a button, enabled or not, as IconButton is', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoundIconButton(
                icon: Icons.share,
                tooltip: 'شارك',
                onPressed: () {},
              ),
              const RoundIconButton(
                icon: Icons.edit,
                tooltip: 'تعديل',
                onPressed: null,
              ),
            ],
          ),
        ),
      );
      final on = tester.getSemantics(find.byTooltip('شارك'));
      expect(on.flagsCollection.isButton, isTrue);
      expect(on.flagsCollection.isEnabled, Tristate.isTrue);
      final off = tester.getSemantics(find.byTooltip('تعديل'));
      expect(off.flagsCollection.isButton, isTrue);
      expect(off.flagsCollection.isEnabled, Tristate.isFalse);
    });

    testWidgets('its tap target is never under 48dp, even at the default '
        '44dp visual size', (tester) async {
      await tester.pumpWidget(
        _themed(
          RoundIconButton(icon: Icons.share, tooltip: 'شارك', onPressed: () {}),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('a tap on the button fires onPressed', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        _themed(
          RoundIconButton(
            icon: Icons.share,
            tooltip: 'شارك',
            onPressed: () => pressed = true,
          ),
        ),
      );
      await tester.tap(find.byTooltip('شارك'));
      expect(pressed, isTrue);
    });

    testWidgets(
      'light paints Decor.liftShadow with no border; dark paints no shadow '
      'with a Decor.cardHairline border instead (LOOK-6)',
      (tester) async {
        Future<BoxDecoration> pumpAndRead(Brightness brightness) async {
          await tester.pumpWidget(
            _themed(
              RoundIconButton(
                icon: Icons.share,
                tooltip: 'شارك',
                onPressed: () {},
              ),
              brightness: brightness,
            ),
          );
          // `MaterialApp` animates a `ThemeData` change (`AnimatedTheme`):
          // let it finish before reading anything theme-derived, or a
          // repump within the same test still reads the *previous*
          // brightness's values.
          await tester.pumpAndSettle();
          final container = tester.widget<Container>(
            find.descendant(
              of: find.byType(RoundIconButton),
              matching: find.byType(Container),
            ),
          );
          return container.decoration! as BoxDecoration;
        }

        final light = await pumpAndRead(Brightness.light);
        final lightContext = tester.element(find.byType(RoundIconButton));
        final lightDecor = Decor.of(lightContext);
        expect(light.boxShadow, lightDecor.liftShadow);
        expect(light.boxShadow, isNotEmpty);
        expect(light.border, isNull);

        final dark = await pumpAndRead(Brightness.dark);
        final darkContext = tester.element(find.byType(RoundIconButton));
        final darkDecor = Decor.of(darkContext);
        expect(darkDecor.cardHairline, isNotNull);
        expect(dark.boxShadow, isEmpty);
        expect(dark.border, Border.all(color: darkDecor.cardHairline!));
      },
    );
  });

  group('ServingsStepper', () {
    testWidgets('both +/- steps meet the 48dp Android tap-target guideline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          ServingsStepper(
            label: '٤ حصص',
            onDecrement: () {},
            onIncrement: () {},
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('each step is a button; at a bound it is read as disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          ServingsStepper(
            label: '١ حصة',
            onDecrement: null,
            onIncrement: () {},
          ),
        ),
      );
      final less = tester.getSemantics(find.byTooltip('Fewer servings'));
      expect(less.flagsCollection.isButton, isTrue);
      expect(less.flagsCollection.isEnabled, Tristate.isFalse);
      final more = tester.getSemantics(find.byTooltip('More servings'));
      expect(more.flagsCollection.isButton, isTrue);
      expect(more.flagsCollection.isEnabled, Tristate.isTrue);
    });

    testWidgets('+ and - call their own callback', (tester) async {
      var decremented = false, incremented = false;
      await tester.pumpWidget(
        _themed(
          ServingsStepper(
            label: '٤ حصص',
            onDecrement: () => decremented = true,
            onIncrement: () => incremented = true,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.remove));
      await tester.tap(find.byIcon(Icons.add));
      expect(decremented, isTrue);
      expect(incremented, isTrue);
    });
  });

  group('SegmentedPill', () {
    testWidgets('every option meets the 48dp tap-target guideline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          SegmentedPill<int>(
            options: const {0: 'كل الوصفات', 1: 'كتب الطبخ'},
            value: 0,
            onChanged: (_) {},
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('the selected option carries selected/button semantics '
        '(never colour alone)', (tester) async {
      await tester.pumpWidget(
        _themed(
          SegmentedPill<int>(
            options: const {0: 'كل الوصفات', 1: 'كتب الطبخ'},
            value: 0,
            onChanged: (_) {},
          ),
        ),
      );
      final selected = tester.getSemantics(find.text('كل الوصفات'));
      expect(selected.flagsCollection.isSelected, Tristate.isTrue);
      final unselected = tester.getSemantics(find.text('كتب الطبخ'));
      expect(unselected.flagsCollection.isSelected, Tristate.isFalse);
    });

    testWidgets('tapping an option calls onChanged with its value', (
      tester,
    ) async {
      int? picked;
      await tester.pumpWidget(
        _themed(
          SegmentedPill<int>(
            options: const {0: 'كل الوصفات', 1: 'كتب الطبخ'},
            value: 0,
            onChanged: (v) => picked = v,
          ),
        ),
      );
      await tester.tap(find.text('كتب الطبخ'));
      expect(picked, 1);
    });
  });

  group('SegmentedPill.dense', () {
    testWidgets('a 28dp track that hugs its labels, each option still a '
        '48dp tap target that picks it', (tester) async {
      var picked = 0;
      await tester.pumpWidget(
        _themed(
          StatefulBuilder(
            builder: (context, setState) => SegmentedPill<int>(
              dense: true,
              options: const {0: '123', 1: '١٢٣'},
              value: picked,
              onChanged: (v) => setState(() => picked = v),
            ),
          ),
        ),
      );
      final pill = find.byType(SegmentedPill<int>);
      expect(tester.getSize(pill).height, 48);
      expect(tester.getSize(pill).width, lessThan(128));
      expect(
        find.descendant(
          of: pill,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.constraints?.maxHeight == 28,
          ),
        ),
        findsOneWidget,
      );
      // 12/600 labels (labelSmall).
      final label = tester.widget<Text>(find.text('١٢٣'));
      expect(label.style?.fontSize, 12);
      expect(label.style?.fontWeight, FontWeight.w600);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.tap(find.text('١٢٣'));
      await tester.pump();
      expect(picked, 1);
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text('١٢٣')),
        isSemantics(isSelected: true, isButton: true),
      );
      handle.dispose();
    });
  });

  group('EmptyState', () {
    testWidgets('draws the caller\'s icon on the disc, its title as a '
        'heading, and its body', (tester) async {
      await tester.pumpWidget(
        _themed(
          const EmptyState(
            title: 'لا وصفات بعد',
            body: 'أضف أول وصفة.',
            icon: Icons.menu_book_outlined,
          ),
        ),
      );
      final disc = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      );
      expect(tester.getSize(disc), const Size(112, 112));
      expect(
        find.descendant(
          of: disc,
          matching: find.byIcon(Icons.menu_book_outlined),
        ),
        findsOneWidget,
      );
      expect(find.text('أضف أول وصفة.'), findsOneWidget);
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text('لا وصفات بعد')),
        isSemantics(label: 'لا وصفات بعد', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('with no icon, the disc holds the ornament alone', (
      tester,
    ) async {
      await tester.pumpWidget(_themed(const EmptyState(title: 'فارغة')));
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Ornament), findsOneWidget);
    });
  });
}
