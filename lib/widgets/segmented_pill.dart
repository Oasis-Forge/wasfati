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

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
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
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    );
  }
}
