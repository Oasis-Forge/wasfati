// LOOK-5, QTY-5: DigitBox gives every digit the same width, so a ticking
// clock, a step numeral or a ×factor never resizes when the digit style
// switches, while reading exactly like a plain Text of the same string
// (LOOK-2): the same text for find.text, the same semantics label, the
// numbers in the same order.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/settings.dart' show AppStyle;
import 'package:wasfati/theme/app_theme.dart';
import 'package:wasfati/widgets/digit_box.dart';

const _size = 20.0;
const _style = TextStyle(fontSize: _size);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  TextDirection textDirection = TextDirection.rtl,
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: wasfatiTheme(AppStyle.ink, Brightness.light),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: textDirection,
        child: Scaffold(
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
          ),
        ),
      ),
    ),
  ),
);

double _width(WidgetTester tester, Finder finder) =>
    tester.getSize(finder).width;

void main() {
  // The app's own font, not the test font (whose every glyph is 1em
  // square): the proportional Arabic-Indic digits are the whole point.
  setUpAll(() async {
    final loader = FontLoader('IBMPlexSansArabic');
    for (final weight in ['Regular', 'SemiBold']) {
      final bytes = File('assets/fonts/IBMPlexSansArabic-$weight.ttf')
          .readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  testWidgets('each digit takes the same width in either digit style, '
      'where plain text does not (QTY-5)', (tester) async {
    await _pump(
      tester,
      const Column(
        children: [
          Text('12:05', key: Key('plain western'), style: _style),
          Text('١٢:٠٥', key: Key('plain arabic'), style: _style),
          DigitBox('12:05', key: Key('western'), style: _style),
          DigitBox('١٢:٠٥', key: Key('arabic'), style: _style),
          DigitBox('١', key: Key('narrowest'), style: _style),
          DigitBox('٣', key: Key('widest'), style: _style),
        ],
      ),
      textDirection: TextDirection.ltr,
    );

    // The problem: the same clock is narrower in Arabic-Indic digits.
    expect(
      _width(tester, find.byKey(const Key('plain arabic'))),
      isNot(
        moreOrLessEquals(
          _width(tester, find.byKey(const Key('plain western'))),
        ),
      ),
    );
    // Boxed, it isn't.
    expect(
      _width(tester, find.byKey(const Key('arabic'))),
      moreOrLessEquals(_width(tester, find.byKey(const Key('western')))),
    );
    for (final key in ['narrowest', 'widest']) {
      expect(
        _width(tester, find.byKey(Key(key))),
        moreOrLessEquals(_size * DigitBox.boxWidth, epsilon: 0.01),
        reason: key,
      );
    }
  });

  testWidgets('reads as its whole text: find.text and the screen reader '
      'get the string, nothing of the spacing', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const DigitBox('الخطوة ١٢ من ٢٠', style: _style));

    expect(find.text('الخطوة ١٢ من ٢٠'), findsOneWidget);
    expect(find.bySemanticsLabel('الخطوة ١٢ من ٢٠'), findsOneWidget);
    handle.dispose();
  });

  for (final (name, text) in [
    ('Western', 'الخطوة 12 من 34'),
    ('Arabic-Indic', 'الخطوة ١٢ من ٣٤'),
  ]) {
    testWidgets('$name numbers keep left-to-right order inside '
        'right-to-left text, and the sentence keeps its own', (tester) async {
      await _pump(tester, DigitBox(text, style: _style));

      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(DigitBox),
          matching: find.byType(RichText),
        ),
      );
      // Where each digit is drawn, by the index it has in the laid-out
      // text (which also holds the silent spacing and direction marks).
      final laidOut = paragraph.text.toPlainText(includeSemanticsLabels: false);
      final left = <String, double>{};
      for (var i = 0; i < laidOut.length; i++) {
        if (RegExp(r'[0-9٠-٩]').hasMatch(laidOut[i])) {
          left[laidOut[i]] = paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: i, extentOffset: i + 1),
              )
              .single
              .left;
        }
      }
      final [one, two, three, four] = text
          .split('')
          .where((c) => RegExp(r'[0-9٠-٩]').hasMatch(c))
          .toList();
      expect(left[one]!, lessThan(left[two]!), reason: '12, not 21');
      expect(left[three]!, lessThan(left[four]!), reason: '34, not 43');
      // Right to left: the first number sits to the right of the second.
      expect(left[one]!, greaterThan(left[four]!));
    });
  }

  testWidgets('at 1.3x text (LANG-6) the boxes grow with the text', (
    tester,
  ) async {
    await _pump(
      tester,
      const Column(
        children: [
          DigitBox('١', key: Key('narrowest'), style: _style),
          DigitBox('12:05', key: Key('western'), style: _style),
          DigitBox('١٢:٠٥', key: Key('arabic'), style: _style),
        ],
      ),
      textScale: 1.3,
    );

    expect(
      _width(tester, find.byKey(const Key('narrowest'))),
      moreOrLessEquals(_size * DigitBox.boxWidth * 1.3, epsilon: 0.01),
    );
    expect(
      _width(tester, find.byKey(const Key('arabic'))),
      moreOrLessEquals(_width(tester, find.byKey(const Key('western')))),
    );
  });

  testWidgets('a bare ×factor laid out left to right keeps "×" before its '
      'number inside right-to-left text', (tester) async {
    await _pump(
      tester,
      const DigitBox('×2', textDirection: TextDirection.ltr, style: _style),
    );

    expect(
      tester.widget<Text>(find.text('×2')).textDirection,
      TextDirection.ltr,
    );
  });
}
