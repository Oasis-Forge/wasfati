import 'package:flutter/material.dart';

import 'content_direction.dart';

/// A section/group heading — ingredient/step group names, aisle headings.
/// Decision 23 drops the two looks' own heading rail (LOOK-6's old
/// signature move): سُفرة marks a heading with type alone, so this renders
/// a plain heading in the title style, nothing else. [railHeight] is kept
/// as an accepted, ignored parameter so every existing call site compiles
/// unchanged.
class RailHeading extends StatelessWidget {
  const RailHeading(this.text, {super.key, this.style, this.railHeight = 20});

  final String text;
  final TextStyle? style;

  final double railHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // type.dart's own mapping puts a section heading at titleMedium
    // (19/700) — titleLarge is the 26/700 screen-title size, which would
    // otherwise outrank the page's own title (e.g. a recipe's name).
    return ContentText(text, style: style ?? theme.textTheme.titleMedium);
  }
}
