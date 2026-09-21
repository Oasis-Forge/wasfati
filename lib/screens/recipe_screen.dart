import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/grocery.dart';
import '../models/plan.dart';
import '../models/quantity/convert.dart';
import '../models/recipe.dart';
import '../models/recipe_share.dart';
import '../providers/grocery_state.dart';
import '../providers/plan_state.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../services/recipe_pages.dart';
import '../services/sharer.dart';
import '../widgets/content_direction.dart';
import '../models/quantity/rational.dart';
import 'cook_mode_screen.dart';
import 'ingredients_section.dart';
import 'plan_screen.dart';
import 'recipe_editor_screen.dart';

/// One recipe (REC-3–REC-9). Empty fields are hidden, never shown as 0.
/// Pops `true` when the recipe was deleted, so the list can offer Undo.
class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key, required this.recipeId});
  final String recipeId;

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  Future<Recipe?>? _recipe;
  int _revision = -1;
  bool _closing = false;

  /// The scale factor: a view, not stored (SCALE-3); kept across reloads.
  Rational _factor = Rational.one;

  /// Reloads whenever the library changed (an edit, a cookbook rename, an
  /// undo), so the page never shows stale data.
  Future<Recipe?> _current(RecipesState state) {
    // While closing after a delete, keep what's shown instead of flashing
    // "no longer here".
    if (_recipe == null || (_revision != state.revision && !_closing)) {
      _revision = state.revision;
      _recipe = state.repository.get(widget.recipeId);
    }
    return _recipe!;
  }

  Future<void> _edit(Recipe r) => Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => RecipeEditorScreen(recipe: r)),
  );

  Future<void> _delete(Recipe r) async {
    _closing = true;
    final ok = await context.read<RecipesState>().delete(r.id); // DEL-1
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<Recipe?>(
      future: _current(context.watch<RecipesState>()),
      builder: (context, snap) {
        final r = snap.data;
        return Scaffold(
          appBar: AppBar(
            actions: [
              if (r != null) ...[
                IconButton(
                  tooltip: l10n.planAddToPlan,
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: () => openAddToPlan(context, r.id),
                ),
                if (r.ingredients.any((s) => s.items.isNotEmpty))
                  IconButton(
                    tooltip: l10n.addToGroceries,
                    icon: const Icon(Icons.shopping_basket_outlined),
                    onPressed: () => openAddToGroceries(context, r, _factor),
                  ),
                IconButton(
                  tooltip: l10n.shareTooltip,
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => openShareRecipe(context, r, _factor),
                ),
                IconButton(
                  tooltip: l10n.edit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(r),
                ),
                IconButton(
                  tooltip: l10n.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(r),
                ),
              ],
            ],
          ),
          body: snap.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : r == null
              ? Center(child: Text(l10n.recipeMissing))
              : _RecipeBody(
                  r,
                  factor: _factor,
                  onFactor: (f) => setState(() => _factor = f),
                ),
        );
      },
    );
  }
}

/// The next meal this recipe is planned for, if any (PLAN-6).
class _NextPlanned extends StatelessWidget {
  const _NextPlanned(this.recipeId);
  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final plan = context.watch<PlanState>();
    return FutureBuilder<PlanEntry?>(
      future: plan.nextFor(recipeId),
      builder: (context, snap) {
        final e = snap.data;
        if (e == null) return const SizedBox.shrink();
        final day = s.inDigits(
          MaterialLocalizations.of(context).formatMediumDate(e.date),
        );
        return Padding(
          padding: const EdgeInsetsDirectional.only(top: 4),
          child: Text(
            l10n.planNextMeal(day, mealName(l10n, e.slot)),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        );
      },
    );
  }
}

class _RecipeBody extends StatelessWidget {
  const _RecipeBody(this.r, {required this.factor, required this.onFactor});
  final Recipe r;
  final Rational factor;
  final ValueChanged<Rational> onFactor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final text = Theme.of(context).textTheme;
    // Servings live in the scaling stepper (SCALE-2), not here.
    final facts = <String>[
      if (r.prepMinutes != null)
        '${l10n.prepTime} ${l10n.minutes(r.prepMinutes!, s.number(r.prepMinutes!))}',
      if (r.cookMinutes != null)
        '${l10n.cookTime} ${l10n.minutes(r.cookMinutes!, s.number(r.cookMinutes!))}',
    ];
    final host = r.sourceUrl == null ? null : Uri.tryParse(r.sourceUrl!)?.host;

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 32),
      children: [
        if (r.photoPath != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.file(
                  File(r.photoPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ContentText(r.title, style: text.headlineSmall),
        if (host != null && host.isNotEmpty)
          Text(
            l10n.sourceFrom(host.replaceFirst('www.', '')),
            style: text.bodySmall,
          ),
        _NextPlanned(r.id),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final f in facts) Chip(label: Text(f))],
          ),
        ],
        if (r.tags.isNotEmpty || r.cookbookIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in context.watch<RecipesState>().cookbooks)
                if (r.cookbookIds.contains(c.id))
                  Chip(
                    avatar: const Icon(Icons.menu_book_outlined, size: 18),
                    label: ContentText(c.name),
                  ),
              for (final t in r.tags)
                Chip(label: ContentText('#$t', source: t)),
            ],
          ),
        ],
        if (r.ingredients.isNotEmpty) ...[
          _Heading(l10n.ingredients),
          IngredientsSection(recipe: r, factor: factor, onFactor: onFactor),
        ],
        if (r.steps.isNotEmpty) ...[
          _Heading(l10n.steps),
          // COOK-1: free, and no ads in cook mode.
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CookModeScreen(recipe: r, factor: factor),
              ),
            ),
            icon: const Icon(Icons.soup_kitchen_outlined),
            label: Text(l10n.startCooking),
          ),
          const SizedBox(height: 8),
          ..._stepRows(context, r.steps, s),
        ],
        if (r.notes != null && r.notes!.trim().isNotEmpty) ...[
          _Heading(l10n.notes),
          ContentText(r.notes!, style: text.bodyLarge),
        ],
      ],
    );
  }

  List<Widget> _stepRows(
    BuildContext context,
    List<Section<RecipeStep>> sections,
    SettingsState s,
  ) {
    final rows = <Widget>[];
    var n = 0;
    for (final section in sections) {
      if (section.name != null) rows.add(GroupName(section.name!));
      for (final step in section.items) {
        n++;
        rows.add(
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 14, child: Text(s.number(n))),
                const SizedBox(width: 12),
                Expanded(
                  child: ContentText(
                    step.text,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return rows;
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 24, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}

/// One candidate line for "أضف إلى المشتريات" (GRO-2): the group it's under
/// and its ticked state, starting unticked for a to-taste line (QTY-2).
class _GroceryCandidate {
  _GroceryCandidate(this.group, this.shown) : checked = !shown.line.toTaste;
  final String? group;
  final ShownLine shown;
  bool checked;
}

/// GRO-2: "أضف إلى المشتريات" lists the recipe's lines exactly as the page
/// shows them (the current scale [factor] and the recipe's unit view,
/// SCALE-6), each ticked except to-taste ones; water and ice aren't listed.
Future<void> openAddToGroceries(
  BuildContext context,
  Recipe r,
  Rational factor,
) async {
  final l10n = AppLocalizations.of(context);
  final settings = context.read<SettingsState>();
  final groceries = context.read<GroceryState>();
  final messenger = ScaffoldMessenger.of(context);

  final candidates = [
    for (final section in r.ingredients)
      for (final line in section.items)
        if (!isWaterOrIce(line.name))
          _GroceryCandidate(
            section.name,
            showLine(line.parsed, factor: factor, view: r.unitView),
          ),
  ];

  var busy = false;
  final added = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    // A tall list (or 12 aisles at 1.3×) used to grow under the status bar,
    // since isScrollControlled strips top padding on its own (should-fix,
    // UI review).
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInner) {
        String? lastGroup;
        final anyChecked = candidates.any((c) => c.checked);
        return SingleChildScrollView(
          padding: EdgeInsetsDirectional.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
                child: Text(
                  l10n.addToGroceries,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              for (final c in candidates) ...[
                if (c.group != lastGroup && (lastGroup = c.group) != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                    child: GroupName(c.group!),
                  ),
                CheckboxListTile(
                  value: c.checked,
                  onChanged: (v) => setInner(() => c.checked = v ?? false),
                  title: ContentText(
                    shownLineText(c.shown, settings.digits),
                    source: c.shown.line.original,
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsetsDirectional.all(16),
                child: FilledButton(
                  // Disabled while busy or with nothing ticked, so a double
                  // tap can't add everything twice and a silent no-op sheet
                  // can't close on nothing (should-fix, UI review).
                  onPressed: candidates.isEmpty || busy || !anyChecked
                      ? null
                      : () async {
                          setInner(() => busy = true);
                          final lines = [
                            for (final c in candidates)
                              if (c.checked)
                                IncomingLine(
                                  name: c.shown.line.name,
                                  min: c.shown.exactMin,
                                  max: c.shown.exactMax,
                                  unitId: c.shown.line.unitId,
                                  recipeId: r.id,
                                ),
                          ];
                          final ok = lines.isEmpty
                              ? true
                              : await groceries.add(lines);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx, ok ? lines.length : null);
                        },
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.planAdd),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  if (added != null && added > 0 && context.mounted) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.groceriesAddedCount(added, settings.number(added)),
          ),
        ),
      );
  }
}

/// SHARE-1: "مشاركة" offers "كنص" and "كصورة". Both go through the share
/// sheet only — nothing is uploaded and no web page is made (principle 2,
/// CLAUDE.md). What's shared is exactly what the page shows: [factor] and
/// the recipe's unit view (SCALE-6), in the user's digits (QTY-5).
Future<void> openShareRecipe(
  BuildContext context,
  Recipe r,
  Rational factor,
) async {
  final l10n = AppLocalizations.of(context);
  final settings = context.read<SettingsState>();
  final sharer = context.read<Sharer>();
  final storage = context.read<ShareStorage>();
  final messenger = ScaffoldMessenger.of(context);
  // LANG-5, must-fix (adversarial review): captured before any `await`, so
  // the images align to the app's own reading edge whatever the recipe's
  // own language is.
  final uiDirection = Directionality.of(context);

  String servingsLabel(int n) => l10n.servings(n, settings.number(n));
  String prepTimeLabel(int m) =>
      '${l10n.prepTime} ${l10n.minutes(m, settings.number(m))}';
  String cookTimeLabel(int m) =>
      '${l10n.cookTime} ${l10n.minutes(m, settings.number(m))}';
  String unscaledLineText(String line, String mark) =>
      l10n.shareUnscaledLine(line, mark);

  // Factored out so a longer recipe's "too long" notice can offer this same
  // path as its action (should-fix, adversarial review), instead of just
  // telling the user to reopen the sheet and pick كنص by hand.
  Future<void> shareAsText() async {
    final text = recipeShareText(
      r,
      factor: factor,
      view: r.unitView,
      digits: settings.digits,
      ingredientsHeading: l10n.shareHeadingIngredients,
      stepsHeading: l10n.shareHeadingSteps,
      footerLine: l10n.shareFooterLine,
      notScaledMark: l10n.notScaled,
      unscaledLineText: unscaledLineText,
      servingsLabel: servingsLabel,
      prepTimeLabel: prepTimeLabel,
      cookTimeLabel: cookTimeLabel,
      sourceLabel: l10n.shareSource,
    );
    await sharer.shareText(text, subject: r.title);
  }

  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.short_text),
            title: Text(l10n.shareAsText),
            onTap: () => Navigator.pop(ctx, 'text'),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(l10n.shareAsImages),
            onTap: () => Navigator.pop(ctx, 'images'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  if (choice == 'text') {
    await shareAsText();
    return;
  }

  // Not awaited: it stays open (dismissed below) while the pages render.
  // PopScope(canPop: false) — must-fix, adversarial review — also blocks
  // the system Back button: barrierDismissible only stops a barrier tap,
  // so Back used to close this dialog while rendering carried on, and the
  // unconditional pop below then closed the recipe page instead (or, on a
  // second Back, fired a second share).
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(l10n.shareRendering)),
            ],
          ),
        ),
      ),
    ),
  );

  List<String>? paths;
  var failed = false;
  try {
    paths = await renderSharePages(
      r,
      factor: factor,
      view: r.unitView,
      digits: settings.digits,
      uiDirection: uiDirection,
      ingredientsHeading: l10n.shareHeadingIngredients,
      stepsHeading: l10n.shareHeadingSteps,
      notScaledMark: l10n.notScaled,
      unscaledLineText: unscaledLineText,
      servingsLabel: servingsLabel,
      prepTimeLabel: prepTimeLabel,
      cookTimeLabel: cookTimeLabel,
      brand: l10n.appTitle,
      storage: storage,
    );
  } catch (_) {
    // must-fix (adversarial review): never leave the progress dialog
    // stuck open on an unexpected failure.
    failed = true;
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // close the dialog
    }
  }
  if (!context.mounted) return;

  if (failed) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
    return;
  }

  if (paths == null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.shareTooLong),
          action: SnackBarAction(
            label: l10n.shareAsText,
            onPressed: () => unawaited(shareAsText()),
          ),
        ),
      );
    return;
  }
  await sharer.shareFiles(paths, text: r.title);
}
