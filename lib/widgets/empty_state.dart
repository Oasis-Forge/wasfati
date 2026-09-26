import 'package:flutter/material.dart';

import 'ornament.dart';

/// One composition for every empty state (the library, cookbooks, no
/// results, an empty cookbook, an empty plan, an empty grocery list), in
/// Sufra's own terms (design-styles.md, Decision 23): a soft accent disc
/// with the drawn khatam [Ornament] in it, and the caller's [icon] on top
/// when it has one; the caller's heading at `title` (19/700) and body in
/// `ink2`; and the caller's own action(s) — this widget invents or changes
/// no string of its own (RUN-1: one clear first action).
///
/// [scrollable] wraps the composition in its own centred
/// [SingleChildScrollView], so 1.3× text (LANG-6) scrolls instead of
/// overflowing a short screen — the right choice whenever this is the whole
/// body. Pass `false` for a notice that sits inside a scrollable the caller
/// already owns (the meal plan's empty banner above its day cards): a
/// second, nested vertical scrollable there would be given unbounded height
/// by the first and throw at layout.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.body,
    this.icon,
    this.actions = const [],
    this.scrollable = true,
  });

  /// The caller's own heading string.
  final String title;

  /// The caller's own body string, if it has one.
  final String? body;

  /// What the screen holds when it isn't empty (a book for recipes, a
  /// magnifier for a search): drawn in `onAccentSoft` on the disc.
  final IconData? icon;

  /// The caller's own action widget(s) (a button), in order, each given
  /// its usual spacing below the last.
  final List<Widget> actions;

  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Decoration: the heading below says what this is.
        ExcludeSemantics(
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Ornament(
                  size: 84,
                  opacity: icon == null ? 0.5 : 0.18,
                  color: cs.onPrimaryContainer,
                ),
                if (icon != null)
                  Icon(icon, size: 40, color: cs.onPrimaryContainer),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            title,
            style: text.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(
            body!,
            style: text.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
        if (actions.isNotEmpty) const SizedBox(height: 24),
        for (var i = 0; i < actions.length; i++)
          Padding(
            padding: EdgeInsetsDirectional.only(top: i == 0 ? 0 : 8),
            child: actions[i],
          ),
      ],
    );
    if (!scrollable) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 32,
          vertical: 16,
        ),
        child: column,
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 32,
          vertical: 24,
        ),
        child: column,
      ),
    );
  }
}
