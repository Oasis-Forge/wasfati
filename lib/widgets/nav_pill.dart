import 'package:flutter/material.dart';

import '../theme/decor.dart';

/// One slot in [NavPill]: an icon and a label. The active slot is coloured
/// (`Decor.navActive`) and carries a dot in the accent colour; an inactive
/// one uses `Decor.navInactive` — never colour alone (LOOK-3/LOOK-7).
@immutable
class NavPillTab {
  const NavPillTab({required this.icon, required this.label, this.tooltip});

  final IconData icon;
  final String label;

  /// Defaults to [label].
  final String? tooltip;
}

/// LOOK-7: a floating dark pill at the bottom of the four main screens —
/// الوصفات، الخطة، (the centre +)، المشتريات، الإعدادات — 12dp above the
/// bottom safe area with 16dp side margins. Each slot shrinks its label to
/// fit (never wraps or clips) at 1.3x text on a 360dp phone (LOOK-8). The
/// centre "+" is a raised accent circle with a page-coloured ring, opening
/// the add sheet (LOOK-11). The raise is part of this widget's own layout
/// box — not overflow — so the whole button is tappable and a caller (e.g.
/// [AdSlot]'s 8dp gap) can measure against it directly.
class NavPill extends StatelessWidget {
  const NavPill({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onAddPressed,
    required this.addTooltip,
  });

  final List<NavPillTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;
  final String addTooltip;

  /// The pill fill's own height.
  static const _pillHeight = 68.0;

  /// How far the centre "+" rises above the pill's top edge.
  static const _raise = 10.0;

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    final mid = tabs.length ~/ 2;
    // LOOK-7: 12dp above the bottom *safe area* — Scaffold hands
    // bottomNavigationBar the full MediaQuery padding and expects the bar to
    // consume it itself, as the old Material NavigationBar did.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12 + bottomInset),
      child: SizedBox(
        // The raise is reserved here, in the widget's own box, so the "+"
        // is never painted outside it (which would make its top dead to
        // hit-testing) and never eats into a sibling's gap above it.
        height: _pillHeight + _raise,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: _raise,
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: decor.floatShadow,
                ),
                // The fill is the Material itself (not a separate
                // DecoratedBox) so a tab's InkWell — registered on this same
                // Material — paints its ripple on top of the fill instead of
                // on some ancestor Material underneath it, where the opaque
                // fill would hide it entirely.
                child: Material(
                  color: decor.navFill,
                  shape: StadiumBorder(
                    side: decor.navBorder != null
                        ? BorderSide(color: decor.navBorder!)
                        : BorderSide.none,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < mid; i++) _tab(context, i),
                      const SizedBox(width: 60), // room for the centre +
                      for (var i = mid; i < tabs.length; i++) _tab(context, i),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: _AddButton(tooltip: addTooltip, onPressed: onAddPressed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int i) {
    final decor = Decor.of(context);
    final theme = Theme.of(context);
    final tab = tabs[i];
    final selected = i == currentIndex;
    final color = selected ? decor.navActive : decor.navInactive;
    final label = tab.tooltip ?? tab.label;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () => onTabSelected(i),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tab.icon, size: 20, color: color),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    softWrap: false,
                    style: theme.textTheme.labelSmall?.copyWith(color: color),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: 4,
                  height: 4,
                  child: selected
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // The accent, not `navActive` (white/ink): the
                            // active slot has to show the accent somewhere,
                            // and the mockups draw this dot in it.
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// LOOK-7: the pill's centre "+", raised 10dp above its fill's top edge
/// with a 4dp page-coloured ring, opening the add sheet (LOOK-11).
class _AddButton extends StatelessWidget {
  const _AddButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 60,
      height: 60,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(shape: BoxShape.circle, color: cs.surface),
      child: Material(
        color: cs.primary,
        shape: const CircleBorder(),
        child: IconButton(
          icon: const Icon(Icons.add),
          iconSize: 26,
          color: cs.onPrimary,
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
