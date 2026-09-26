import 'package:flutter/material.dart';

import '../theme/decor.dart';

/// LOOK-14's step rail: one segment per step — done ones in the accent at
/// 45%, the current one solid and taller, the rest `sunk` — or, past
/// [maxSegments] steps, one progress bar. Cook mode's step counter says the
/// same in words, so the rail itself is silent. Shared by cook mode and the
/// walkthrough's cook page (RUN-4), so the page shows exactly what cook
/// mode draws.
class StepRail extends StatelessWidget {
  const StepRail({super.key, required this.current, required this.total});

  /// Past this many steps the segments would be too thin to read.
  static const maxSegments = 14;

  /// The current step, from 0.
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sunk = Decor.of(context).sunk;
    if (total == 0) return const SizedBox.shrink();
    if (total > maxSegments) {
      return ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              key: const Key('rail-progress'),
              value: (current + 1).clamp(0, total) / total,
              backgroundColor: sunk,
              color: cs.primary,
            ),
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Center(
                  child: Container(
                    key: Key('rail-$i'),
                    height: i == current ? 6 : 4,
                    decoration: BoxDecoration(
                      color: i < current
                          ? cs.primary.withValues(alpha: 0.45)
                          : i == current
                          ? cs.primary
                          : sunk,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
