import 'package:flutter/material.dart';

import '../theme/decor.dart';

/// LOOK-6: a 44dp circular icon button — a card fill with the light shadow
/// (`Decor.liftShadow`) in light, a hairline edge in dark — for a floating
/// action over a photo or a page (back, share, edit, more, sort, filter).
/// [tooltip] is required: every icon-only button names itself for
/// accessibility (LOOK-3/LOOK-7's own pattern).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.color,
    this.backgroundColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// 44dp everywhere but cook mode, which asks for 48dp (design spec §1).
  final double size;

  /// Defaults to `onSurface`.
  final Color? color;

  /// Defaults to `surfaceContainerLowest` (`card`).
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    final cs = Theme.of(context).colorScheme;
    // The drawn circle stays [size]; the tap target never drops under 48dp
    // (Android's minimum). When [size] is smaller, the hit area extends
    // beyond the painted circle rather than shrinking to match it.
    final tapSize = size < 48 ? 48.0 : size;
    return SizedBox.square(
      dimension: tapSize,
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Center(
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: backgroundColor ?? cs.surfaceContainerLowest,
                  boxShadow: decor.liftShadow,
                  border: decor.cardHairline != null
                      ? Border.all(color: decor.cardHairline!)
                      : null,
                ),
                child: Icon(
                  icon,
                  size: size * 0.5,
                  color: onPressed == null
                      ? Theme.of(context).disabledColor
                      : (color ?? cs.onSurface),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
