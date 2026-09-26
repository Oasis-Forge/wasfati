import 'package:flutter/material.dart';

import '../theme/decor.dart';

/// LOOK-6: a white card floating on the linen page — 22dp radius, the light
/// shadow (`Decor.liftShadow`) or, in dark, a 1dp hairline edge
/// (`Decor.cardHairline`) instead. Material's own elevation tint is never
/// used.
class SufraCard extends StatelessWidget {
  const SufraCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.radius = 22,
    this.clip = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Defaults to `surfaceContainerLowest` (`card`).
  final Color? color;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    final cs = Theme.of(context).colorScheme;
    final content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;
    return Container(
      decoration: BoxDecoration(
        color: color ?? cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: decor.liftShadow,
        border: decor.cardHairline != null
            ? Border.all(color: decor.cardHairline!)
            : null,
      ),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: content,
    );
  }
}
