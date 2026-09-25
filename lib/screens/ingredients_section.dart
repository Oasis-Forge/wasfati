import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/quantity/convert.dart';
import '../models/quantity/format.dart';
import '../models/quantity/rational.dart';
import '../models/recipe.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../widgets/amount_line.dart';
import '../widgets/digit_box.dart';
import '../widgets/rail_heading.dart';

/// The ingredients with scaling and conversion (SCALE-1–SCALE-6), both free
/// (SCALE-1). Scaling is a view: nothing stored changes (SCALE-3).
class IngredientsSection extends StatelessWidget {
  const IngredientsSection({
    super.key,
    required this.recipe,
    required this.factor,
    required this.onFactor,
  });

  final Recipe recipe;
  final Rational factor;
  final ValueChanged<Rational> onFactor;

  static final multipliers = [
    Rational.half,
    Rational.one,
    Rational(2),
    Rational(3),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final r = recipe;
    final lines = [
      for (final section in r.ingredients)
        for (final line in section.items)
          showLine(line.parsed, factor: factor, view: r.unitView),
    ];
    final scaling = factor != Rational.one;
    final unscaled = scaling ? lines.where((l) => !l.scalable).length : 0;
    final servings = r.servings;
    // Servings for this factor, when they come out whole (SCALE-2).
    final scaledServings = servings == null
        ? null
        : Rational(servings) * factor;
    final wholeServings = scaledServings != null && scaledServings.isWhole
        ? scaledServings.whole
        : null;

    String amount(Rational v) =>
        formatAmount(v, null, digits: s.digits); // ×½, ×1½, ×2
    // "×" has no direction of its own; in right-to-left text it would move
    // past the number ("2×"), so these labels are laid out left to right.
    Widget times(Rational v, {TextStyle? style}) =>
        Text('×${amount(v)}', textDirection: TextDirection.ltr, style: style);

    var i = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (servings != null) ...[
              IconButton.outlined(
                tooltip: l10n.servingsLess,
                icon: const Icon(Icons.remove),
                onPressed: wholeServings != null && wholeServings > 1
                    ? () => onFactor(Rational(wholeServings - 1, servings))
                    : null,
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12,
                  ),
                  // LOOK-5: the ×factor readout steps with the stepper, so
                  // its digits are boxed (the servings sentence has no bare
                  // number to box: the Arabic plural absorbs it).
                  child: wholeServings == null
                      ? DigitBox(
                          '×${amount(factor)}',
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context).textTheme.titleMedium,
                        )
                      : Text(
                          l10n.servings(wholeServings, s.number(wholeServings)),
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
              IconButton.outlined(
                tooltip: l10n.servingsMore,
                icon: const Icon(Icons.add),
                onPressed:
                    wholeServings != null && wholeServings < Recipe.maxServings
                    ? () => onFactor(Rational(wholeServings + 1, servings))
                    : null,
              ),
            ],
            if (scaling) ...[
              const Spacer(),
              TextButton(
                onPressed: () => onFactor(Rational.one),
                child: Text(l10n.scaleReset),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final m in multipliers)
              ChoiceChip(
                label: times(m),
                selected: factor == m,
                showCheckmark: false,
                onSelected: (_) => onFactor(m),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<UnitView>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: UnitView.asWritten,
              label: Text(l10n.viewAsWritten),
            ),
            ButtonSegment(value: UnitView.metric, label: Text(l10n.viewMetric)),
            ButtonSegment(
              value: UnitView.kitchen,
              label: Text(l10n.viewKitchen),
            ),
          ],
          selected: {r.unitView},
          onSelectionChanged: (v) =>
              context.read<RecipesState>().setUnitView(r.id, v.first),
        ),
        if (unscaled > 0)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 8),
            child: Text(
              l10n.notScaledCount(unscaled, s.number(unscaled)),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        for (final section in r.ingredients) ...[
          if (section.name != null) GroupName(section.name!),
          for (final _ in section.items)
            _IngredientRow(lines[i++], digits: s.digits, markUnscaled: scaling),
        ],
      ],
    );
  }
}

/// An ingredient line as shown (QTY-5, QTY-6): the amount in the chosen
/// digits, isolated left-to-right inside Arabic text. A line with no amount
/// shows its original text (QTY-2) and, while scaling, a "not scaled" mark
/// (SCALE-4).
class _IngredientRow extends StatelessWidget {
  const _IngredientRow(
    this.shown, {
    required this.digits,
    required this.markUnscaled,
  });

  final ShownLine shown;
  final DigitStyle digits;
  final bool markUnscaled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final line = shown.line;
    final text = shownLineText(shown, digits);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(top: 9, end: 12),
            child: Icon(Icons.circle, size: 6),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AmountLine(
                  text,
                  source: line.original,
                  style: theme.textTheme.bodyLarge,
                ),
                if (markUnscaled && !shown.scalable)
                  Text(
                    l10n.notScaled,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A named group's heading (REC-4, REC-6). LOOK-6: a shelf label — the
/// rail, not coloured text, carries the emphasis now (design-styles.md
/// "GroupName becomes a shelf label").
class GroupName extends StatelessWidget {
  const GroupName(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 12, bottom: 4),
    child: RailHeading(
      text,
      railHeight: 14,
      style: Theme.of(context).textTheme.titleSmall,
    ),
  );
}
