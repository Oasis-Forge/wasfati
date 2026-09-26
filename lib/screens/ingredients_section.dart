import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/quantity/convert.dart';
import '../models/quantity/format.dart';
import '../models/quantity/rational.dart';
import '../models/recipe.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../theme/decor.dart';
import '../widgets/amount_line.dart';
import '../widgets/content_direction.dart';
import '../widgets/digit_box.dart';
import '../widgets/segmented_pill.dart';
import '../widgets/servings_stepper.dart';
import '../widgets/sufra_card.dart';

/// The recipe page's Ingredients tab (LOOK-13): the scale card — servings
/// or the multiplier, ×½ ×2 ×3, the unit views, "إعادة" and the not-scaled
/// notice (SCALE-1–SCALE-6, both free, SCALE-1) — then the ingredient card.
/// Scaling is a view: nothing stored changes (SCALE-3).
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

  /// SCALE-2's multipliers; ×1 is "إعادة", shown only once scaled.
  static final multipliers = [Rational.half, Rational(2), Rational(3)];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsState>();
    final r = recipe;
    final lines = [
      for (final section in r.ingredients)
        for (final line in section.items)
          showLine(line.parsed, factor: factor, view: r.unitView),
    ];
    final scaling = factor != Rational.one;
    var i = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScaleCard(
          recipe: r,
          factor: factor,
          onFactor: onFactor,
          unscaled: scaling ? lines.where((l) => !l.scalable).length : 0,
        ),
        const SizedBox(height: 20),
        SufraCard(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final section in r.ingredients) ...[
                if (section.name != null) GroupName(section.name!),
                for (final (n, _) in section.items.indexed)
                  _IngredientRow(
                    lines[i++],
                    digits: s.digits,
                    markUnscaled: scaling,
                    divided: n > 0,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// SCALE-2, SCALE-4, SCALE-5 in one card: the servings stepper (or the
/// ×factor alone, for a recipe with no servings) and the multiplier chips,
/// the unit views, "إعادة", and how many lines weren't scaled.
class _ScaleCard extends StatelessWidget {
  const _ScaleCard({
    required this.recipe,
    required this.factor,
    required this.onFactor,
    required this.unscaled,
  });

  final Recipe recipe;
  final Rational factor;
  final ValueChanged<Rational> onFactor;
  final int unscaled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final decor = Decor.of(context);
    final r = recipe;
    final servings = r.servings;
    // Servings for this factor, when they come out whole (SCALE-2).
    final scaled = servings == null ? null : Rational(servings) * factor;
    final whole = scaled != null && scaled.isWhole ? scaled.whole : null;
    // ×½, ×1½, ×2. "×" has no direction of its own; in right-to-left text
    // it would move past the number ("2×"), so these are laid out left to
    // right.
    final times = '×${formatAmount(factor, null, digits: s.digits)}';

    // LOOK-5: the ×factor readout steps with the stepper, so its digits are
    // boxed (the servings sentence has no bare number to box: the Arabic
    // plural absorbs it).
    final Widget amount = servings != null
        ? ServingsStepper(
            label: whole == null
                ? times
                : l10n.servings(whole, s.number(whole)),
            boxDigits: whole == null,
            labelDirection: whole == null ? TextDirection.ltr : null,
            onDecrement: whole != null && whole > 1
                ? () => onFactor(Rational(whole - 1, servings))
                : null,
            onIncrement: whole != null && whole < Recipe.maxServings
                ? () => onFactor(Rational(whole + 1, servings))
                : null,
          )
        : Container(
            // SCALE-2: a recipe with no servings scales by multiplier only,
            // and shows the factor where the stepper would be.
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: decor.sunk,
              borderRadius: BorderRadius.circular(999),
            ),
            // Centred in its 48 dp, but only as wide as the factor: a plain
            // `alignment` would stretch the pill across the Wrap's width and
            // push the chips onto a second row (SCALE-2).
            child: Align(
              widthFactor: 1,
              child: DigitBox(
                times,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.titleSmall,
              ),
            ),
          );

    return SufraCard(
      padding: const EdgeInsetsDirectional.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Recipe.dc.html: the stepper and the chips share one row; the
          // Wrap only breaks it on a narrow phone or a long label. Nothing
          // in this row depends on the factor, so scaling never reflows it
          // and the chip just tapped stays under the finger.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 8,
            children: [
              amount,
              Wrap(
                spacing: 4,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final m in IngredientsSection.multipliers)
                    _FactorChip(
                      label: '×${formatAmount(m, null, digits: s.digits)}',
                      selected: factor == m,
                      onTap: () => onFactor(m),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // LOOK-6: the nested, flat pill — the tabs above are the raised one.
          SegmentedPill<UnitView>(
            raised: false,
            options: {
              UnitView.asWritten: l10n.viewAsWritten,
              UnitView.metric: l10n.viewMetric,
              UnitView.kitchen: l10n.viewKitchen,
            },
            value: r.unitView,
            onChanged: (v) => context.read<RecipesState>().setUnitView(r.id, v),
          ),
          // SCALE-2's "إعادة" back to ×1, under the unit views, only while
          // scaled: at ×1 the card ends at the unit views, with no blank
          // band. It sits below the row above, so showing it never moves
          // the chip just tapped.
          if (factor != Rational.one)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => onFactor(Rational.one),
                child: Text(l10n.scaleReset),
              ),
            ),
          if (unscaled > 0) ...[
            const SizedBox(height: 10),
            // SCALE-4: never silently skips a line — the header says how
            // many weren't scaled.
            Container(
              padding: const EdgeInsetsDirectional.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: cs.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.notScaledCount(unscaled, s.number(unscaled)),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A multiplier chip (SCALE-2): Recipe.dc.html's small caption pill (12/600,
/// 10 dp to its sides) inside a 48 dp-tall, 44 dp-wide tap box — a `sunk`
/// pill with the `outline` edge at rest (LOOK-3: an unselected chip's
/// boundary reaches 3:1) and the accent's soft fill with an accent edge when
/// chosen; the selected state also in semantics, never colour alone.
class _FactorChip extends StatelessWidget {
  const _FactorChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final decor = Decor.of(context);
    return Semantics(
      button: true,
      selected: selected,
      // Its own transparent Material, so the splash, hover and focus
      // highlight paint over the card rather than under it (SufraCard's
      // trap); the pill's fill is an Ink for the same reason.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 44),
            child: Center(
              widthFactor: 1,
              // No `alignment` here: that would stretch the pill across the
              // whole row; the padding alone sizes it.
              child: Ink(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: selected ? cs.primaryContainer : decor.sunk,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: selected ? cs.primary : cs.outline),
                ),
                child: Text(
                  label,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? cs.onPrimaryContainer
                        : cs.onSurfaceVariant,
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

/// An ingredient line as shown (QTY-5, QTY-6, LOOK-4): a small accent
/// diamond, then the amount in the accent at 700 through [AmountLine],
/// isolated left-to-right inside Arabic text. A line with no amount shows
/// its original text (QTY-2) and, while scaling, a "not scaled" mark
/// (SCALE-4). [divided] draws the hairline above every row but a group's
/// first.
class _IngredientRow extends StatelessWidget {
  const _IngredientRow(
    this.shown, {
    required this.digits,
    required this.markUnscaled,
    required this.divided,
  });

  final ShownLine shown;
  final DigitStyle digits;
  final bool markUnscaled;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final decor = Decor.of(context);
    final body = theme.textTheme.bodyLarge!;
    // The diamond sits on the first line's middle, at any text size.
    final lineHeight = MediaQuery.textScalerOf(context)
        .scale(body.fontSize! * body.height!);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: divided
            ? BorderDirectional(
                top: BorderSide(
                  color: decor.rowHairline ?? theme.colorScheme.outlineVariant,
                ),
              )
            : null,
      ),
      // The line and its "not scaled" mark read as one stop.
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(top: lineHeight / 2 - 3),
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 6,
                  height: 6,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AmountLine(
                    shownLineText(shown, digits),
                    source: shown.line.original,
                    style: body,
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
      ),
    );
  }
}

/// A named group's label (REC-4, REC-6): LOOK-13's small caption over its
/// lines, in the recipe's own direction.
class GroupName extends StatelessWidget {
  const GroupName(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 12, bottom: 2),
      child: Semantics(
        header: true,
        child: ContentText(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
