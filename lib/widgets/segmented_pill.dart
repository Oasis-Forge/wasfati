import 'package:flutter/material.dart';

import '../theme/decor.dart';

/// LOOK-6: a segmented control drawn as a sunk pill track with a
/// card-coloured, lifted thumb on the selected option — "كل الوصفات |
/// كتب الطبخ", the ingredients/steps tabs, unit views. The track itself is
/// 48dp tall (design spec §1); each option's tap target fills that full
/// height, with its selected state carried in semantics (never colour
/// alone, LOOK-3) — never just 40dp inside a 4dp track inset.
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.height = 48,
    this.raised = true,
    this.dense = false,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// The track's own height — at least 48dp (the widget's contract).
  final double height;

  /// True for a standalone control (a lifted, card-coloured thumb); false
  /// for one nested in a card, where a flat `accentSoft`/`primaryContainer`
  /// fill stands in for the thumb instead of another shadow on top of the
  /// card's own (design spec §1 "Components").
  final bool raised;

  /// An inline mini pill for a row's end (Settings' الأرقام, 08-settings
  /// .png): a 28dp `sunk` track with a 2dp inset, 24dp segments with
  /// labelSmall (12/600) labels, as wide as its labels. The tap target
  /// stays 48dp tall: the track is centred in each option's 48dp cell,
  /// the way a 36dp chip sits on a 48dp target (design-styles.md,
  /// "Heights"). [height] is ignored.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    if (dense) {
      return SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              right: 0,
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: decor.sunk,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in options.entries)
                  _DenseOption(
                    selected: e.key == value,
                    label: e.value,
                    raised: raised,
                    onTap: () => onChanged(e.key),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: decor.sunk,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in options.entries)
            Expanded(
              child: _SegmentedOption(
                selected: e.key == value,
                label: e.value,
                raised: raised,
                onTap: () => onChanged(e.key),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentedOption extends StatelessWidget {
  const _SegmentedOption({
    required this.selected,
    required this.label,
    required this.raised,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final bool raised;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final thumbColor = raised ? cs.surfaceContainerLowest : cs.primaryContainer;
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        // Transparent and unclipped: the tap target is the full option
        // cell (>= 48dp, the track's own height), never just the smaller
        // inset thumb underneath it.
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // The 4dp gap around the thumb lives here, inside the option,
            // so it never shrinks the track or the tap target.
            padding: const EdgeInsets.all(4),
            child: DecoratedBox(
              // The lift shadow is painted on this box directly — nothing
              // clips it away — so it isn't lost and doesn't paint back
              // over (and grey) the thumb fill.
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: selected ? thumbColor : Colors.transparent,
                shadows: selected && raised ? decor.liftShadow : const [],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  // LOOK-7's rule: a long label (English "As written" at
                  // 1.3x in a nested pill) shrinks to fit rather than clip.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected
                            ? (raised ? cs.onSurface : cs.onPrimaryContainer)
                            : cs.onSurfaceVariant,
                      ),
                    ),
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

/// One [SegmentedPill.dense] option: a 48dp-tall cell (at least 48dp
/// wide) holding a 24dp segment, the thumb drawn on the segment only.
class _DenseOption extends StatelessWidget {
  const _DenseOption({
    required this.selected,
    required this.label,
    required this.raised,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final bool raised;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final thumbColor = raised ? cs.surfaceContainerLowest : cs.primaryContainer;
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          // The moving thumb is the feedback; a 48dp ripple would spill
          // past the 28dp track. Keyboard focus still shows.
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? cs.onSurface.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Center(
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    color: selected ? thumbColor : Colors.transparent,
                    shadows: selected && raised ? decor.liftShadow : const [],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 24,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: selected
                                ? (raised
                                      ? cs.onSurface
                                      : cs.onPrimaryContainer)
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
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
