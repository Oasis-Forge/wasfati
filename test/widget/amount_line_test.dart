// LOOK-4, QTY-6: AmountLine splits `formatLine`'s isolated output at its
// PDI, colouring only the amount span, without re-parsing — and falls back
// to the plain widget, reading direction from the unformatted original,
// when there's nothing to split (design-styles.md's stated risk for this
// widget).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/quantity/parser.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/settings.dart' show AppStyle;
import 'package:wasfati/theme/app_theme.dart';
import 'package:wasfati/theme/decor.dart';
import 'package:wasfati/widgets/amount_line.dart';

/// Pumps [child] under Ink's light theme (any look/brightness would do —
/// the split logic itself doesn't depend on which one) with the given
/// ambient [textDirection].
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  TextDirection textDirection = TextDirection.rtl,
}) => tester.pumpWidget(
  MaterialApp(
    theme: wasfatiTheme(AppStyle.ink, Brightness.light),
    home: Directionality(
      textDirection: textDirection,
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

Text _richTextOf(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text).first);

void main() {
  testWidgets('no amount (QTY-2): falls back to the plain widget, '
      'unformatted text', (tester) async {
    const original = 'ملح حسب الرغبة'; // no PDI: nothing was parsed
    await _pump(tester, const AmountLine(original, source: original));

    expect(find.text(original), findsOneWidget); // a plain Text, .data set
    expect(
      tester.widget<Text>(find.text(original)).textDirection,
      TextDirection.rtl,
    );
  });

  testWidgets('a range: the whole "min–max" span is coloured as one phrase '
      '(QTY-6)', (tester) async {
    final line = ParsedLine(
      original: '2-3 اكواب دقيق',
      min: Rational(2),
      max: Rational(3),
      unitId: 'cup',
      name: 'دقيق',
    );
    final shown = formatLine(line, arabic: true, isolate: true);
    expect(
      shown.contains(String.fromCharCode(0x2066)) &&
          shown.contains(String.fromCharCode(0x2069)),
      isTrue,
    );

    await _pump(tester, AmountLine(shown, source: line.original));

    final text = _richTextOf(tester);
    expect(text.textSpan!.toPlainText(), shown); // nothing lost or reordered
    final decor = wasfatiTheme(
      AppStyle.ink,
      Brightness.light,
    ).extension<Decor>()!;
    // The first (amount) span carries Decor's emphasis; the rest doesn't.
    final spans = (text.textSpan! as TextSpan).children!;
    expect((spans[0] as TextSpan).style!.color, decor.amountColor);
    expect((spans[1] as TextSpan).style, isNull);
  });

  testWidgets('an English line inside an Arabic recipe reads left to right '
      '(LANG-5)', (tester) async {
    final line = ParsedLine(
      original: '2 cups flour',
      min: Rational(2),
      unitId: 'cup',
      name: 'flour',
    );
    final shown = formatLine(line, arabic: false, isolate: true);

    // The ambient app is Arabic (rtl); the line itself is English.
    await _pump(
      tester,
      AmountLine(shown, source: line.original),
      textDirection: TextDirection.rtl,
    );

    expect(_richTextOf(tester).textDirection, TextDirection.ltr);
  });

  testWidgets('an Arabic line inside an English recipe reads right to left '
      '(LANG-5)', (tester) async {
    final line = ParsedLine(
      original: '٣ أكواب رز',
      min: Rational(3),
      unitId: 'cup',
      name: 'رز',
    );
    final shown = formatLine(line, arabic: true, isolate: true);

    // The ambient app is English (ltr); the line itself is Arabic.
    await _pump(
      tester,
      AmountLine(shown, source: line.original),
      textDirection: TextDirection.ltr,
    );

    expect(_richTextOf(tester).textDirection, TextDirection.rtl);
  });

  testWidgets(
    'Saffron colours the amount in the body colour, not primary (LOOK-4)',
    (tester) async {
      final line = ParsedLine(
        original: '1 كوب أرز',
        min: Rational(1),
        unitId: 'cup',
        name: 'أرز',
      );
      final shown = formatLine(line, arabic: true, isolate: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: wasfatiTheme(AppStyle.saffron, Brightness.light),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(child: AmountLine(shown, source: line.original)),
            ),
          ),
        ),
      );
      final decor = wasfatiTheme(
        AppStyle.saffron,
        Brightness.light,
      ).extension<Decor>()!;
      final spans = (_richTextOf(tester).textSpan! as TextSpan).children!;
      expect((spans[0] as TextSpan).style!.color, decor.amountColor);
      expect(
        decor.amountColor,
        isNot(
          Theme.of(tester.element(find.byType(AmountLine))).colorScheme.primary,
        ),
      );
    },
  );
}
