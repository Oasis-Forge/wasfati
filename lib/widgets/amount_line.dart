import 'package:flutter/material.dart';

import '../theme/decor.dart';
import 'content_direction.dart';

/// LOOK-4, QTY-6: an ingredient (or grocery) amount is the loudest text in
/// its line. Splits the string `formatLine(isolate: true)`/`shownLineText`
/// already produces at its PDI (U+2069) — the closing mark of the
/// left-to-right isolate `formatLine` wraps around the amount — never
/// re-parsing the text, so the amount and the unit word that agrees with it
/// ("٢ كوبان") always stay one phrase (QTY-6). The isolated span (kept
/// whole, isolate marks and all) is coloured/weighted from
/// [Decor.amountColor]/[Decor.amountWeight] (Ink: primary w600; Saffron:
/// the body colour w600); the rest of the line, including that unit word,
/// stays the base style.
///
/// With no parsed amount (no PDI — [line.min] was null, QTY-2) it falls
/// back to the plain [ContentText], still reading direction from the
/// unformatted original — [source] — so an English line inside an Arabic
/// recipe never flips (LANG-5).
class AmountLine extends StatelessWidget {
  const AmountLine(
    this.text, {
    super.key,
    this.source,
    this.style,
    this.maxLines,
    this.overflow,
  });

  /// `shownLineText`'s output for this line, isolated.
  final String text;

  /// The unformatted line ([ParsedLine.original]) direction is decided
  /// from, exactly like [ContentText.source].
  final String? source;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Pop directional isolate (U+2069): closes the left-to-right isolate
  /// (U+2066, LRI) `formatLine` opens around an amount when
  /// `isolate: true`.
  static final _pdi = String.fromCharCode(0x2069);

  @override
  Widget build(BuildContext context) {
    final cut = text.indexOf(_pdi);
    if (cut == -1) {
      // QTY-2: an unreadable line shows its original text verbatim, and
      // there's nothing to isolate — the plain widget, same direction rule.
      return ContentText(
        text,
        source: source ?? text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    final decor = Decor.of(context);
    final amountEnd = cut + 1; // keep the PDI itself inside the amount span
    final ui = Directionality.of(context);
    return Text.rich(
      TextSpan(
        // Nested spans inherit any style field they don't set of their
        // own, so only colour/weight need naming here — size, family and
        // height still come from `style` (Text.rich merges it with the
        // ambient DefaultTextStyle exactly as a plain Text would).
        children: [
          TextSpan(
            text: text.substring(0, amountEnd),
            style: TextStyle(
              color: decor.amountColor,
              fontWeight: decor.amountWeight,
            ),
          ),
          TextSpan(text: text.substring(amountEnd)),
        ],
      ),
      style: style,
      textDirection: contentDirection(source ?? text),
      textAlign: ui == TextDirection.rtl ? TextAlign.right : TextAlign.left,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
