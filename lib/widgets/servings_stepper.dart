import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/decor.dart';
import 'digit_box.dart';

/// LOOK-6/design spec §1: a pill holding a 40dp round "−", the current
/// value, and a 40dp round "+" — the recipe page's servings stepper. Built
/// here for PR1; wired up on the recipe page in PR3. Tooltips come from the
/// existing `servingsLess`/`servingsMore` strings.
class ServingsStepper extends StatelessWidget {
  const ServingsStepper({
    super.key,
    required this.label,
    required this.onDecrement,
    required this.onIncrement,
    this.boxDigits = false,
    this.labelDirection,
  });

  /// The caller's own formatted value ("4 حصص") — this widget invents no
  /// string of its own.
  final String label;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  /// LOOK-5: a readout whose digits step in place (the recipe page's
  /// ×factor, once the servings aren't whole) is drawn through [DigitBox].
  final bool boxDigits;

  /// The label's own direction: left to right for a bare ×factor, so the
  /// "×" stays before its number; null follows the ambient direction.
  final TextDirection? labelDirection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final decor = Decor.of(context);
    final theme = Theme.of(context);
    return Container(
      // No padding of its own: each `_Step` is already a 48dp tap box
      // holding its 40dp circle centred (4dp of sunk track on every side of
      // it), so adding padding here on top would grow the track past 48dp.
      decoration: BoxDecoration(
        color: decor.sunk,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Step(
            icon: Icons.remove,
            tooltip: l10n.servingsLess,
            onPressed: onDecrement,
          ),
          // Flexible: in a narrow card at 1.3x text the label gives way
          // (LOOK-8) rather than push the "+" past the edge.
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: boxDigits
                  ? DigitBox(
                      label,
                      style: theme.textTheme.titleSmall,
                      textDirection: labelDirection,
                    )
                  : Text(
                      label,
                      style: theme.textTheme.titleSmall,
                      textDirection: labelDirection,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
          _Step(
            icon: Icons.add,
            tooltip: l10n.servingsMore,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.tooltip, this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// The drawn circle's size; the tap target below is never smaller than
  /// Android's 48dp minimum, so it extends past the circle rather than
  /// matching it.
  static const _visualSize = 40.0;
  static const _tapSize = 48.0;

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    final cs = Theme.of(context).colorScheme;
    // The button role and its enabled state, as on RoundIconButton: at a
    // bound the step is read as disabled.
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      child: SizedBox.square(
        dimension: _tapSize,
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
                  width: _visualSize,
                  height: _visualSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surfaceContainerLowest,
                    boxShadow: decor.liftShadow,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: onPressed == null
                        ? Theme.of(context).disabledColor
                        : cs.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
