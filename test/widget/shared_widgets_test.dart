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
}
