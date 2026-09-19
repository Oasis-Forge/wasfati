import 'package:flutter/widgets.dart';

import '../models/quantity/arabic_text.dart';

/// The direction of recipe text comes from the text itself, not from the
/// app's language: an English line in the Arabic app reads left to right,
/// and an Arabic line in the English app right to left (LANG-5, QTY-5).
TextDirection contentDirection(String text) =>
    hasArabic(text) ? TextDirection.rtl : TextDirection.ltr;

/// Recipe text (titles, ingredient lines, steps, notes): read in its own
/// direction, but lined up with the app's reading edge, so every line starts
/// next to its bullet or number whatever language it is in.
class ContentText extends StatelessWidget {
  const ContentText(
    this.text, {
    super.key,
    this.source,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;

  /// The text that decides the direction, when [text] is a formatted
  /// version of it (an ingredient line with isolated amounts).
  final String? source;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final ui = Directionality.of(context);
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textDirection: contentDirection(source ?? text),
      textAlign: ui == TextDirection.rtl ? TextAlign.right : TextAlign.left,
    );
  }
}
