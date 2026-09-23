import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/aisles.dart';
import '../models/grocery.dart';
import '../models/quantity/arabic_text.dart';
import '../models/quantity/format.dart';
import '../models/quantity/parser.dart';
import '../models/quantity/rational.dart';
import '../providers/grocery_state.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../services/sharer.dart';
import '../widgets/amount_line.dart';
import '../widgets/content_direction.dart';
import '../widgets/empty_state.dart';
import '../widgets/rail_heading.dart';

// First-strong and pop directional isolates, so a name reads in its own
// direction inside the app's "من:" line (should-fix, UI review) without
// forcing a fixed direction, the way [_amountFormatter]'s [formatLine]
// isolates a number (QTY-5, LANG-5).
final _fsi = String.fromCharCode(0x2068);
final _pdi = String.fromCharCode(0x2069);

/// The grocery list (GRO-1–GRO-7): a typed-add field, the list itself by
/// aisle or by recipe, and Share.
class GroceriesScreen extends StatelessWidget {
  const GroceriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groceries = context.watch<GroceryState>();
    final settings = context.watch<SettingsState>();
    final format = _amountFormatter(settings.digits);
    final canShare = groceries.toBuy.isNotEmpty;

    Future<void> share() async {
      final text = groceryShareText(
        groceries.items,
        title: l10n.groceriesShareTitle,
        aisleLabel: (a) => aisleLabel(l10n, a),
        formatAmount: format,
      );
      if (text.isEmpty) return;
      await context.read<Sharer>().shareText(text);
    }

    Future<void> clear({required bool onlyDone}) async {
      final messenger = ScaffoldMessenger.of(context);
      final ids = onlyDone
          ? await groceries.clearDone()
          : await groceries.clearAll();
      if (ids == null || !context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.groceriesClearedCount(
                ids.length,
                settings.number(ids.length),
              ),
            ),
            duration: const Duration(seconds: 5),
            action: ids.isEmpty
                ? null
                : SnackBarAction(
                    label: l10n.undo,
                    onPressed: () => groceries.restore(ids),
                  ),
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groceriesTitle),
        actions: [
          IconButton(
            tooltip: l10n.groceriesShareTooltip,
            icon: const Icon(Icons.share_outlined),
            onPressed: canShare ? share : null,
          ),
          PopupMenuButton<String>(
            onSelected: (v) => clear(onlyDone: v == 'done'),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'done',
                child: Text(l10n.groceriesClearDone),
              ),
              PopupMenuItem(value: 'all', child: Text(l10n.groceriesClearAll)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const _AddField(),
          if (groceries.items.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: SegmentedButton<GroceryView>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: GroceryView.byAisle,
                    label: Text(l10n.groceriesByAisle),
                  ),
                  ButtonSegment(
                    value: GroceryView.byRecipe,
                    label: Text(l10n.groceriesByRecipe),
                  ),
                ],
                selected: {settings.settings.groceryView},
                // Remembered in AppSettings, not just in memory (GRO-5,
                // should-fix), so it survives a restart and is in backups
                // (BAK-6).
                onSelectionChanged: (v) => settings.update(
                  settings.settings.copyWith(groceryView: v.first),
                ),
              ),
            ),
          Expanded(
            child: !groceries.loaded
                ? const Center(child: CircularProgressIndicator())
                : groceries.items.isEmpty
                ? const _EmptyGroceries()
                : settings.settings.groceryView == GroceryView.byAisle
                ? _AisleList(format: format)
                : _ByRecipeList(format: format),
          ),
        ],
      ),
    );
  }
}

/// GRO-4's translated aisle headings (DATA-1).
String aisleLabel(AppLocalizations l10n, Aisle aisle) => switch (aisle) {
  Aisle.produce => l10n.aisleProduce,
  Aisle.meat => l10n.aisleMeat,
  Aisle.fish => l10n.aisleFish,
  Aisle.dairy => l10n.aisleDairy,
  Aisle.bakery => l10n.aisleBakery,
  Aisle.grains => l10n.aisleGrains,
  Aisle.spices => l10n.aisleSpices,
  Aisle.pantry => l10n.aislePantry,
  Aisle.baking => l10n.aisleBaking,
  Aisle.frozen => l10n.aisleFrozen,
  Aisle.drinks => l10n.aisleDrinks,
  Aisle.other => l10n.aisleOther,
};

/// One (amount, unit) pair as text (QTY-5, QTY-6), for [name]: its own
/// language picks Arabic or English unit agreement — not the app's, so an
/// English item never reads "٢ كوب" in the Arabic app (should-fix, three
/// reviews) — reusing [formatLine]'s rounding and agreement logic with an
/// empty name so only the amount and unit show. Isolates only the number
/// (QTY-5), never the unit with it, so the unit stays on the reading side
/// the number's own direction puts it on (must-fix, two reviews).
String Function(Rational, String?, String) _amountFormatter(DigitStyle digits) {
  return (amount, unitId, name) => formatLine(
    ParsedLine(original: '', min: amount, unitId: unitId, name: ''),
    arabic: hasArabic(name),
    digits: digitsFor(name, digits),
    isolate: true,
  );
}

/// The recipes an item's amounts came from, live ones only, each once
/// (GRO-5, GRO-7: a deleted recipe is simply not named).
List<String> _recipeNames(GroceryItem item, RecipesState recipes) {
  final seen = <String>{};
  final names = <String>[];
  for (final a in item.amounts) {
    final id = a.recipeId;
    if (id == null || !seen.add(id)) continue;
    final r = recipes.recipes.where((r) => r.id == id).firstOrNull;
    if (r != null) names.add(r.title);
  }
  return names;
}

/// RUN-1: says how the list fills, since typing isn't the only way in
/// (should-fix, UI review: the old empty state didn't explain itself).
class _EmptyGroceries extends StatelessWidget {
  const _EmptyGroceries();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      title: l10n.groceriesEmptyTitle,
      body: l10n.groceriesEmptyBody,
    );
  }
}

/// "أضف غرضًا" (GRO-1): typed text is parsed like a recipe line.
class _AddField extends StatefulWidget {
  const _AddField();

  @override
  State<_AddField> createState() => _AddFieldState();
}

class _AddFieldState extends State<_AddField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await context.read<GroceryState>().addByHand(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: l10n.groceriesAddHint,
                isDense: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ),
          IconButton(
            tooltip: l10n.groceriesAddHint,
            icon: const Icon(Icons.add),
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _AisleHeading extends StatelessWidget {
  const _AisleHeading(this.text);
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

/// GRO-5's default view: aisles in GRO-4 order, items by name, a collapsed
/// "تم" section at the end.
class _AisleList extends StatelessWidget {
  const _AisleList({required this.format});
  final String Function(Rational, String?, String) format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groceries = context.watch<GroceryState>();
    final recipes = context.watch<RecipesState>();
    final byAisle = <Aisle, List<GroceryItem>>{};
    for (final i in groceries.toBuy) {
      (byAisle[i.aisle] ??= []).add(i);
    }
    final done = groceries.done;

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
      children: [
        for (final aisle in Aisle.values)
          if ((byAisle[aisle] ?? const []).isNotEmpty) ...[
            _AisleHeading(aisleLabel(l10n, aisle)),
            for (final item in byAisle[aisle]!)
              _ItemRow(
                item,
                format: format,
                names: _recipeNames(item, recipes),
              ),
          ],
        if (done.isNotEmpty)
          ExpansionTile(
            title: Text(l10n.groceriesDoneSection),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            children: [
              for (final item in done)
                _ItemRow(
                  item,
                  format: format,
                  names: _recipeNames(item, recipes),
                ),
            ],
          ),
      ],
    );
  }
}

/// One item: a checkbox, its merged amount and name, and the recipes it
/// came from on a second line (GRO-5). A long press moves it to another
/// aisle (GRO-4).
class _ItemRow extends StatelessWidget {
  const _ItemRow(this.item, {required this.format, required this.names});
  final GroceryItem item;
  final String Function(Rational, String?, String) format;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final amount = groceryAmountText(
      item.amounts,
      name: item.name,
      formatAmount: format,
    );
    final text = amount.isEmpty ? item.name : '$amount ${item.name}';
    return InkWell(
      onLongPress: () => _moveToAisle(context, item),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: item.isDone,
              onChanged: (v) =>
                  context.read<GroceryState>().setDone(item.id, v ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // No maxLines/overflow here (should-fix, UI review): the
                    // item's name, not the amount, is what the shopper
                    // needs, and an ellipsis used to be able to hide it.
                    AmountLine(
                      text,
                      source: item.name,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (names.isNotEmpty) _FromLine(names),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "من: …" (GRO-5): app text, so it stays in the app's own direction, with
/// each recipe name isolated so it reads in its own (should-fix, UI
/// review: the whole line used to flip direction with the first name).
class _FromLine extends StatelessWidget {
  const _FromLine(this.names);
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final joined = names
        .map((n) => '$_fsi$n$_pdi')
        .join(l10n.groceriesNameSeparator);
    return Text(
      l10n.groceriesFrom(joined),
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// GRO-4: moves an item to another aisle, remembered for its name.
Future<void> _moveToAisle(BuildContext context, GroceryItem item) async {
  final l10n = AppLocalizations.of(context);
  final chosen = await showModalBottomSheet<Aisle>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
              child: Text(
                l10n.groceriesMoveToAisle,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final a in Aisle.values)
              ListTile(
                title: Text(aisleLabel(l10n, a)),
                selected: a == item.aisle,
                onTap: () => Navigator.pop(ctx, a),
              ),
          ],
        ),
      ),
    ),
  );
  if (chosen != null && chosen != item.aisle && context.mounted) {
    await context.read<GroceryState>().moveToAisle(item.id, chosen);
  }
}

/// GRO-5's "By recipe" view: amounts grouped under each recipe, with
/// hand-added ones (and, GRO-7, amounts whose recipe is gone: should-fix,
/// two reviews — they used to vanish from this view while still on the
/// list) under "أضفتها بنفسك". A collapsed "تم" section matches the By-aisle
/// view (should-fix, UI review), so a fully-ticked list isn't just blank.
class _ByRecipeList extends StatelessWidget {
  const _ByRecipeList({required this.format});
  final String Function(Rational, String?, String) format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groceries = context.watch<GroceryState>();
    final recipes = context.watch<RecipesState>();
    final liveIds = recipes.recipes.map((r) => r.id).toSet();

    // recipeId (null for hand-added, or gone) -> (item, its own amounts).
    final byGroup = <String?, List<(GroceryItem, List<GroceryAmount>)>>{};
    for (final item in groceries.toBuy) {
      final byId = <String?, List<GroceryAmount>>{};
      for (final a in item.amounts) {
        final id = a.recipeId != null && liveIds.contains(a.recipeId)
            ? a.recipeId
            : null;
        (byId[id] ??= []).add(a);
      }
      for (final entry in byId.entries) {
        (byGroup[entry.key] ??= []).add((item, entry.value));
      }
    }

    final recipeGroups = [
      for (final id in byGroup.keys)
        if (id != null)
          if (recipes.recipes.where((r) => r.id == id).firstOrNull
              case final r?)
            (title: r.title, id: id, entries: byGroup[id]!),
    ]..sort((a, b) => a.title.compareTo(b.title));
    final handAdded = byGroup[null] ?? const [];
    final done = groceries.done;

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
      children: [
        for (final g in recipeGroups)
          _RecipeGroup(
            title: g.title,
            recipeId: g.id,
            entries: g.entries,
            format: format,
          ),
        if (handAdded.isNotEmpty)
          _RecipeGroup(
            title: l10n.groceriesHandAdded,
            recipeId: null,
            entries: handAdded,
            format: format,
          ),
        if (done.isNotEmpty)
          ExpansionTile(
            title: Text(l10n.groceriesDoneSection),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            children: [
              for (final item in done)
                _ItemRow(
                  item,
                  format: format,
                  names: _recipeNames(item, recipes),
                ),
            ],
          ),
      ],
    );
  }
}

class _RecipeGroup extends StatelessWidget {
  const _RecipeGroup({
    required this.title,
    required this.recipeId,
    required this.entries,
    required this.format,
  });

  final String title;
  final String? recipeId;
  final List<(GroceryItem, List<GroceryAmount>)> entries;
  final String Function(Rational, String?, String) format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ContentText(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (recipeId != null)
                TextButton(
                  onPressed: () => _removeRecipe(context, title, recipeId!),
                  child: Text(l10n.planRemove),
                ),
            ],
          ),
          for (final (item, amounts) in entries)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 8,
                top: 4,
                bottom: 4,
              ),
              child: AmountLine(
                (() {
                  final amt = groceryAmountText(
                    amounts,
                    name: item.name,
                    formatAmount: format,
                  );
                  return amt.isEmpty ? item.name : '$amt ${item.name}';
                })(),
                source: item.name,
              ),
            ),
        ],
      ),
    );
  }
}

/// "Remove" on a recipe (GRO-5): soft-deletes only its own amounts, with an
/// Undo snackbar (DEL-2, must-fix, two reviews: it had none, so one mis-tap
/// silently lost a whole recipe's shopping).
Future<void> _removeRecipe(
  BuildContext context,
  String title,
  String recipeId,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final groceries = context.read<GroceryState>();
  final removed = await groceries.removeRecipe(recipeId);
  if (removed == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.groceriesRecipeRemoved(title)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () =>
              groceries.restoreRecipe(removed.amountIds, removed.itemIds),
        ),
      ),
    );
}
