import 'package:flutter/material.dart';

/// Text whose digits tick or step in place — the running timer, the step
/// numeral, the ×factor readout (LOOK-5) — and never resize its layout when
/// the digit style switches between Western and Arabic-Indic (QTY-5): the
/// bundled font has no `tnum` feature (neither digit set is tabular), so
/// each digit is centred in a box `fontSize × 0.63` wide — the widest
/// Arabic-Indic glyph's advance (design-styles.md "Typography", both looks)
/// — by blank space laid either side of it. Everything else (words, a
/// colon, "×", a space) keeps its natural width.
///
/// The digits stay real text, so it reads exactly like a [Text] of [text]
/// (LOOK-2): a screen reader hears the same label, `find.text` matches the
/// whole string, and the bidi algorithm orders the numbers. The blank
/// space is silent: it is laid out, never read or matched.
///
/// Each number (its digits and the colon, point, comma or slash between
/// them) is isolated and laid out strictly left to right, so the space
/// inside it can't reverse "١٢:٠٥" or the "12" in "الخطوة 12 من 20" in
/// right-to-left text.
/// A sentence takes the ambient direction; a bare "×2" passes
/// [TextDirection.ltr] so the "×" stays before its number.
class DigitBox extends StatelessWidget {
  const DigitBox(this.text, {super.key, this.style, this.textDirection});

  final String text;
  final TextStyle? style;
  final TextDirection? textDirection;

  /// A box's width, in font sizes.
  static const boxWidth = 0.63;

  /// Western 0-9 and Arabic-Indic ٠-٩ (QTY-5's two digit sets).
  static final _digit = RegExp(r'[0-9٠-٩]');

  /// A number: a run of digits, and any colon, point, comma, Arabic
  /// decimal or thousands mark, or slash between two of them.
  static final _number = RegExp(r'[0-9٠-٩]+(?:[:.,٫٬/][0-9٠-٩]+)*');

  // A number opens with LRI (the isolate formatLine uses too, QTY-5), so
  // the text around it orders it as one unit, then LRO, so everything
  // inside runs left to right: without it, the blank space between two
  // Arabic-Indic digits would resolve right to left and swap them ("١٢"
  // read as "٢١"). Closed with PDF and PDI. Silent: they shape the layout
  // but aren't part of what the text says.
  static final _open = TextSpan(
    text: String.fromCharCodes(const [0x2066, 0x202D]),
    semanticsLabel: '',
  );
  static final _close = TextSpan(
    text: String.fromCharCodes(const [0x202C, 0x2069]),
    semanticsLabel: '',
  );

  /// Each digit's own advance, per style and text scale: at most ten
  /// digits per style, and a screen uses a handful of styles.
  static final _advances = <(TextStyle, TextScaler, String), double>{};

  static double _advance(TextStyle style, TextScaler scaler, String digit) {
    if (_advances.length > 256) _advances.clear();
    return _advances.putIfAbsent((style, scaler, digit), () {
      final painter = TextPainter(
        text: TextSpan(text: digit, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    });
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final size = base.fontSize ?? kDefaultFontSize;
    // Measured at the size the text is drawn at (LANG-6), since a glyph's
    // advance doesn't grow exactly in step with it; the space itself is
    // an inline widget, which the paragraph scales back up by [scale].
    final scaled = scaler.scale(size);
    final scale = size == 0 ? 1.0 : scaled / size;
    final box = scaled * boxWidth;
    final spans = <InlineSpan>[];
    var space = 0.0; // blank space not laid down yet
    void flush() {
      if (space > 0) spans.add(_Space(space));
      space = 0;
    }

    var at = 0;
    for (final number in _number.allMatches(text)) {
      if (number.start > at) {
        spans.add(TextSpan(text: text.substring(at, number.start)));
      }
      spans.add(_open);
      for (final ch in number[0]!.split('')) {
        final pad = _digit.hasMatch(ch)
            ? ((box - _advance(base, scaler, ch)) / 2).clamp(0.0, box) / scale
            : 0.0;
        space += pad;
        flush();
        spans.add(TextSpan(text: ch));
        space += pad;
      }
      flush();
      spans.add(_close);
      at = number.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(
      TextSpan(children: spans),
      style: style,
      textDirection: textDirection,
    );
  }
}

/// Blank space beside a digit. Laid out like any inline widget (and scaled
/// with the text, LANG-6), but it reads as nothing: no plain text, no
/// semantics, so the [DigitBox] reads exactly like a plain [Text].
class _Space extends WidgetSpan {
  _Space(double width)
    : super(
        alignment: PlaceholderAlignment.middle,
        child: SizedBox(width: width, height: 0),
      );

  @override
  void computeToPlainText(
    StringBuffer buffer, {
    bool includeSemanticsLabels = true,
    bool includePlaceholders = true,
  }) {
    // Layout text (no semantics labels) keeps the placeholder character,
    // so offsets still match what the engine laid out; readable text, like
    // a TextSpan whose semanticsLabel is empty, has nothing here.
    if (!includeSemanticsLabels) {
      super.computeToPlainText(
        buffer,
        includeSemanticsLabels: includeSemanticsLabels,
        includePlaceholders: includePlaceholders,
      );
    }
  }

  @override
  void computeSemanticsInformation(
    List<InlineSpanSemanticsInformation> collector,
  ) {}
}
