import 'package:flutter/material.dart';

import '../theme/decor.dart';
import 'content_direction.dart';

/// LOOK-6's signature rail: a bar standing at the reading edge of every
/// heading the app owns — section headings, ingredient/step group names,
/// aisle headings. One widget for both looks (LOOK-2): the bar's width and
/// colour come from [Decor.railWidth]/[Decor.railColor] (Ink: 3dp; Saffron:
/// 4dp, its own heading treatment per design-styles.md's recipe/settings/
/// plan screens — both a coloured bar at the reading edge, just a different
/// weight), so nothing here branches on the look itself. A plain [Row]
/// already lays out start-to-end from the ambient [Directionality], so the
/// bar mirrors to the right in Arabic and the left in English with no
/// direction-checking code (design-styles.md "The rail").
class RailHeading extends StatelessWidget {
  const RailHeading(this.text, {super.key, this.style, this.railHeight = 20});

  final String text;
  final TextStyle? style;

  /// The bar's height in dp; callers give a smaller heading (a group name)
  /// a shorter bar than a top-level section heading (design-styles.md: 20dp
  /// for a section heading, 14dp for a group name).
  final double railHeight;

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: decor.railWidth,
          height: railHeight,
          decoration: BoxDecoration(
            color: decor.railColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: ContentText(text, style: style ?? theme.textTheme.titleLarge),
        ),
      ],
    );
  }
}
