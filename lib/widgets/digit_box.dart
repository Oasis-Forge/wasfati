import 'package:flutter/material.dart';

/// A digit that ticks or steps in place — the running timer, a step
/// numeral, the ×factor readout — never resizes its layout when the digit
/// style switches between Western and Arabic-Indic (QTY-5): the bundled
/// font has no `tnum` feature (neither digit set is tabular), so each digit
/// character gets its own fixed-width [SizedBox] instead, `fontSize × 0.63`
/// — the widest Arabic-Indic glyph's advance (design-styles.md
/// "Typography", both looks). Non-digit characters (a colon, "×", a space)
/// render at their own natural width, unboxed. Always laid out inside an
/// LTR [Directionality], so a mixed string like a clock's "12:05" or a
/// factor's "×2" never reverses.
class DigitBox extends StatelessWidget {
  const DigitBox(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  /// Western 0-9 and Arabic-Indic ٠-٩ (QTY-5's two digit sets).
  static final _digit = RegExp(r'[0-9٠-٩]');

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final boxWidth = (base.fontSize ?? 14) * 0.63;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text.rich(
        TextSpan(
          children: [
            for (final ch in text.split(''))
              _digit.hasMatch(ch)
                  ? WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: SizedBox(
                        width: boxWidth,
                        child: Text(ch, textAlign: TextAlign.center),
                      ),
                    )
                  : TextSpan(text: ch),
          ],
        ),
        style: base,
      ),
    );
  }
}
