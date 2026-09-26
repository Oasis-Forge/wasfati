import 'dart:async';
import 'dart:math' as math;

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
import '../theme/decor.dart';
import '../widgets/content_direction.dart';
import '../widgets/empty_state.dart';
import '../widgets/recipe_photo.dart';
import '../widgets/round_icon_button.dart';
import '../widgets/segmented_pill.dart';
import '../widgets/sufra_card.dart';

// First-strong and pop directional isolates, so a name reads in its own
// direction inside the app's "من:" line (should-fix, UI review) without
// forcing a fixed direction, the way [_amountFormatter]'s [formatLine]
// isolates a number (QTY-5, LANG-5).
final _fsi = String.fromCharCode(0x2068);
final _pdi = String.fromCharCode(0x2069);

/// The formatter every amount on this screen goes through (QTY-5, QTY-6).
typedef _AmountFormat = String Function(Rational, String?, String);

/// The grocery list (GRO-1–GRO-7): a progress card, a typed-add field, the
/// list itself by aisle or by recipe, and Share.
class GroceriesScreen extends StatefulWidget {
  const GroceriesScreen({super.key});

  @override
  State<GroceriesScreen> createState() => _GroceriesScreenState();
}

class _GroceriesScreenState extends State<GroceriesScreen> {
  /// design-styles.md Motion #4: a ticked item stays in its aisle, ticked,
  /// for a moment before it moves into "تم" (GRO-5).
  static const _moveDelay = Duration(milliseconds: 600);

  /// Items just ticked that still show in their aisle until [_moveDelay]
  /// has passed. Empty under reduce motion: they move at once.
  final _lingering = <String>{};
  final _timers = <String, Timer>{};

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> _setDone(GroceryItem item, bool done) async {
    final groceries = context.read<GroceryState>();
    _timers.remove(item.id)?.cancel();
    if (done && !MediaQuery.disableAnimationsOf(context)) {
      setState(() => _lingering.add(item.id));
      _timers[item.id] = Timer(_moveDelay, () {
        _timers.remove(item.id);
        if (mounted) setState(() => _lingering.remove(item.id));
      });
    } else {
      setState(() => _lingering.remove(item.id));
    }
    await groceries.setDone(item.id, done);
  }

  Future<void> _share(_AmountFormat format) async {
    final l10n = AppLocalizations.of(context);
    final text = groceryShareText(
      context.read<GroceryState>().items,
      title: l10n.groceriesShareTitle,
      aisleLabel: (a) => aisleLabel(l10n, a),
      formatAmount: format,
    );
    if (text.isEmpty) return;
    await context.read<Sharer>().shareText(text);
  }

  Future<void> _clear({required bool onlyDone}) async {
    final l10n = AppLocalizations.of(context);
    final settings = context.read<SettingsState>();
    final groceries = context.read<GroceryState>();
    final messenger = ScaffoldMessenger.of(context);
    final ids = onlyDone
        ? await groceries.clearDone()
        : await groceries.clearAll();
    if (ids == null || !mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.groceriesClearedCount(ids.length, settings.number(ids.length)),
          ),
          // DEL-2: Undo for about 5 seconds, then the notice goes away on
          // its own, never lingering over the list.
          duration: const Duration(seconds: 5),
          persist: false,
          action: ids.isEmpty
              ? null
              : SnackBarAction(
                  label: l10n.undo,
                  onPressed: () => groceries.restore(ids),
                ),
        ),
      );
  }

  /// "More": "مسح ما تم شراؤه" and "مسح الكل", each with Undo (GRO-5).
  Future<void> _more() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_remove),
              title: Text(l10n.groceriesClearDone),
              onTap: () => Navigator.pop(ctx, 'done'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: Text(l10n.groceriesClearAll),
              onTap: () => Navigator.pop(ctx, 'all'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _clear(onlyDone: choice == 'done');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groceries = context.watch<GroceryState>();
    final settings = context.watch<SettingsState>();
    final recipes = context.watch<RecipesState>();
    final format = _amountFormatter(settings.digits);
    final gutter = Decor.of(context).gutter;
    final items = groceries.items;
    final byAisle = settings.settings.groceryView == GroceryView.byAisle;
    final doneItems = [
      for (final i in groceries.done)
        if (!_lingering.contains(i.id)) i,
    ];

    // One scroll view for the whole screen (LOOK-8), non-lazy so every
    // aisle is built: a list is at most a few dozen rows.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(gutter, 12, gutter, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    // The screen's heading, as AppBar's title was
                    // (should-fix), so a screen reader can jump to it.
                    child: Semantics(
                      header: true,
                      namesRoute: true,
                      child: Text(
                        l10n.groceriesTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // GRO-6: an empty list (or one all bought) can't be shared.
                  RoundIconButton(
                    icon: Icons.share_outlined,
                    tooltip: l10n.groceriesShareTooltip,
                    onPressed: groceries.toBuy.isNotEmpty
                        ? () => _share(format)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  RoundIconButton(
                    icon: Icons.more_horiz,
                    tooltip: l10n.moreActions,
                    onPressed: _more,
                  ),
                ],
              ),
              if (groceries.loaded && items.isNotEmpty) ...[
                const SizedBox(height: 20),
                _ProgressCard(
                  done: groceries.done.length,
                  total: items.length,
                  names: _allRecipeNames(items, recipes),
                ),
              ],
              const SizedBox(height: 20),
              const _AddField(),
              if (!groceries.loaded)
                const Padding(
                  padding: EdgeInsetsDirectional.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                const Padding(
                  padding: EdgeInsetsDirectional.only(top: 24),
                  child: _EmptyGroceries(),
                )
              else ...[
                const SizedBox(height: 16),
                SegmentedPill<GroceryView>(
                  options: {
                    GroceryView.byAisle: l10n.groceriesByAisle,
                    GroceryView.byRecipe: l10n.groceriesByRecipe,
                  },
                  value: settings.settings.groceryView,
                  // Remembered in AppSettings, not just in memory (GRO-5,
                  // should-fix), so it survives a restart and is in backups
                  // (BAK-6).
                  onChanged: (v) => settings.update(
                    settings.settings.copyWith(groceryView: v),
                  ),
                ),
                if (byAisle)
                  ..._aisleCards(items, format, recipes)
                else
                  ..._recipeCards(context, groceries, recipes, format),
                if (doneItems.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _DoneSection(
                    items: doneItems,
                    format: format,
                    onToggle: _setDone,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// GRO-5's default view: aisles in GRO-4's order, items by name. A ticked
  /// item stays in place for a moment ([_lingering]), then leaves for "تم".
  List<Widget> _aisleCards(
    List<GroceryItem> items,
    _AmountFormat format,
    RecipesState recipes,
  ) {
    final shown = <Aisle, List<GroceryItem>>{};
    final all = <Aisle, int>{};
    final bought = <Aisle, int>{};
    for (final i in items) {
      all[i.aisle] = (all[i.aisle] ?? 0) + 1;
      if (i.isDone) bought[i.aisle] = (bought[i.aisle] ?? 0) + 1;
      if (!i.isDone || _lingering.contains(i.id)) {
        (shown[i.aisle] ??= []).add(i);
      }
    }
    return [
      for (final aisle in Aisle.values)
        if ((shown[aisle] ?? const []).isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 14),
            child: _AisleCard(
              aisle: aisle,
              items: shown[aisle]!,
              done: bought[aisle] ?? 0,
              total: all[aisle] ?? 0,
              format: format,
              recipes: recipes,
              onToggle: _setDone,
            ),
          ),
    ];
  }

  /// GRO-5's "By recipe" view: amounts grouped under each recipe, with
  /// hand-added ones (and, GRO-7, amounts whose recipe is gone: should-fix,
  /// two reviews — they used to vanish from this view while still on the
  /// list) under "أضفتها بنفسك".
  List<Widget> _recipeCards(
    BuildContext context,
    GroceryState groceries,
    RecipesState recipes,
    _AmountFormat format,
  ) {
    final l10n = AppLocalizations.of(context);
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
            (recipe: r, entries: byGroup[id]!),
    ]..sort((a, b) => a.recipe.title.compareTo(b.recipe.title));
    final handAdded = byGroup[null] ?? const [];

    return [
      for (final g in recipeGroups)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 14),
          child: _RecipeGroup(
            title: g.recipe.title,
            recipeId: g.recipe.id,
            photoPath: g.recipe.photoPath,
            entries: g.entries,
            format: format,
          ),
        ),
      if (handAdded.isNotEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 14),
          child: _RecipeGroup(
            title: l10n.groceriesHandAdded,
            recipeId: null,
            entries: handAdded,
            format: format,
          ),
        ),
    ];
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

/// GRO-5: each of GRO-4's 12 aisles has its own icon on its card's tile.
IconData aisleIcon(Aisle aisle) => switch (aisle) {
  Aisle.produce => Icons.eco_outlined,
  Aisle.meat => Icons.kebab_dining_outlined,
  Aisle.fish => Icons.set_meal_outlined,
  Aisle.dairy => Icons.egg_outlined,
  Aisle.bakery => Icons.bakery_dining_outlined,
  Aisle.grains => Icons.rice_bowl_outlined,
  Aisle.spices => Icons.local_fire_department_outlined,
  Aisle.pantry => Icons.inventory_2_outlined,
  Aisle.baking => Icons.cake_outlined,
  Aisle.frozen => Icons.ac_unit,
  Aisle.drinks => Icons.local_drink_outlined,
  Aisle.other => Icons.shopping_bag_outlined,
};

/// An aisle tile's (fill, icon colour): herb for produce and the accent for
/// meat, as in the mockup, then the drawn covers' six tints (LOOK-10), so
/// the tints stay within the palette LOOK-3's contrast test measures. In
/// dark, a tint's tone sits on the sunk fill instead of its light pastel.
(Color, Color) _aisleTint(BuildContext context, Aisle aisle) {
  final cs = Theme.of(context).colorScheme;
  final decor = Decor.of(context);
  final light = Theme.of(context).brightness == Brightness.light;
  (Color, Color) cover(int i) {
    final (fill, tone) = decor.coverTints[i % decor.coverTints.length];
    return light ? (fill, tone) : (decor.sunk, tone);
  }

  return switch (aisle) {
    Aisle.produce => (cs.secondaryContainer, cs.secondary),
    Aisle.meat => (cs.primaryContainer, cs.primary),
    Aisle.fish => cover(4), // denim
    Aisle.dairy => cover(2), // honey
    Aisle.bakery => cover(1), // clay
    Aisle.grains => cover(0), // sage
    Aisle.spices => cover(3), // dusty rose
    Aisle.pantry => cover(5), // plum
    Aisle.baking => cover(1), // clay
    Aisle.frozen => cover(4), // denim
    Aisle.drinks => cover(0), // sage
    Aisle.other => (decor.sunk, cs.onSurfaceVariant),
  };
}

/// One (amount, unit) pair as text (QTY-5, QTY-6), for [name]: its own
/// language picks Arabic or English unit agreement — not the app's, so an
/// English item never reads "٢ كوب" in the Arabic app (should-fix, three
/// reviews) — reusing [formatLine]'s rounding and agreement logic with an
/// empty name so only the amount and unit show. Isolates only the number
/// (QTY-5), never the unit with it, so the unit stays on the reading side
/// the number's own direction puts it on (must-fix, two reviews).
_AmountFormat _amountFormatter(DigitStyle digits) {
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

/// Every recipe the list came from, each once, for the progress card.
List<String> _allRecipeNames(List<GroceryItem> items, RecipesState recipes) {
  final names = <String>[];
  for (final i in items) {
    for (final n in _recipeNames(i, recipes)) {
      if (!names.contains(n)) names.add(n);
    }
  }
  return names;
}

/// "من: …" with each recipe name isolated so it reads in its own direction
/// inside the app's (should-fix, UI review).
String _fromText(AppLocalizations l10n, List<String> names) =>
    l10n.groceriesFrom(
      names.map((n) => '$_fsi$n$_pdi').join(l10n.groceriesNameSeparator),
    );

/// The progress card's caption and "من:" line in light: the card colour at
/// this alpha over the ink fill (measured in test/theme/contrast_test.dart,
/// LOOK-3).
const double progressCaptionAlpha = 0.78;

/// GRO-5's progress: "8 من 23 تم شراؤها", a ring, and the recipes the list
/// came from. Ink on the light page, the sunk colour in dark — the one card
/// that inverts the ladder on purpose (design-styles.md, Groceries).
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.done,
    required this.total,
    required this.names,
  });

  final int done;
  final int total;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final decor = Decor.of(context);
    final light = theme.brightness == Brightness.light;
    final fill = light ? cs.onSurface : decor.sunk;
    final fg = light ? cs.surfaceContainerLowest : cs.onSurface;
    final fg2 = light
        ? cs.surfaceContainerLowest.withValues(alpha: progressCaptionAlpha)
        : cs.onSurfaceVariant;
    // The card's own foreground at low alpha, as the mockup's track: in
    // dark, outlineVariant on sunk all but vanished (about 1.1:1).
    final track = fg.withValues(alpha: 0.2);
    return MergeSemantics(
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(24),
          border: decor.cardHairline != null
              ? Border.all(color: decor.cardHairline!)
              : null,
        ),
        padding: const EdgeInsetsDirectional.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.groceriesDoneOf(
                          settings.number(done),
                          settings.number(total),
                        ),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 28,
                          color: fg,
                        ),
                      ),
                      Text(
                        l10n.groceriesBought,
                        style: theme.textTheme.bodyMedium?.copyWith(color: fg2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: 64,
                    child: CustomPaint(
                      painter: _RingPainter(
                        value: total == 0 ? 0 : done / total,
                        track: track,
                        arc: cs.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (names.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _fromText(l10n, names),
                style: theme.textTheme.labelSmall?.copyWith(color: fg2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A 64dp progress ring: a track and the bought share as an accent arc,
/// from the top (drawn, LOOK-6).
class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.track, required this.arc});

  final double value;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value.clamp(0, 1),
        false,
        paint..color = arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.track != track || old.arc != arc;
}

/// RUN-1: says how the list fills, since typing isn't the only way in
/// (should-fix, UI review: the old empty state didn't explain itself). Its
/// first action is the add field right above it.
class _EmptyGroceries extends StatelessWidget {
  const _EmptyGroceries();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      title: l10n.groceriesEmptyTitle,
      body: l10n.groceriesEmptyBody,
      scrollable: false,
    );
  }
}

/// "أضف غرضًا" (GRO-1): a white pill with a round accent "+"; typed text is
/// parsed like a recipe line.
class _AddField extends StatefulWidget {
  const _AddField();

  @override
  State<_AddField> createState() => _AddFieldState();
}

class _AddFieldState extends State<_AddField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
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
    final cs = Theme.of(context).colorScheme;
    final decor = Decor.of(context);
    // LOOK-3: the outline gives the field its 3:1 edge against the page in
    // both brightnesses, as the search field's; 2dp of the accent while
    // focused, as the theme's focused fields.
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: _focus.hasFocus
              ? BorderSide(color: cs.primary, width: 2)
              : BorderSide(color: cs.outline),
        ),
        color: cs.surfaceContainerLowest,
        shadows: decor.liftShadow,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 2, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  decoration: InputDecoration(
                    hintText: l10n.groceriesAddHint,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsetsDirectional.symmetric(
                      vertical: 12,
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
              ),
              RoundIconButton(
                icon: Icons.add,
                tooltip: l10n.groceriesAddHint,
                size: 40,
                backgroundColor: cs.primary,
                color: cs.onPrimary,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An aisle tile: a 36dp rounded square with the aisle's icon and tint.
class _AisleTile extends StatelessWidget {
  const _AisleTile(this.aisle);
  final Aisle aisle;

  @override
  Widget build(BuildContext context) {
    final (fill, tone) = _aisleTint(context, aisle);
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(aisleIcon(aisle), size: 20, color: tone),
      ),
    );
  }
}

/// One aisle (GRO-4, GRO-5): its tile, its name, "3 من 5" bought in it,
/// then its rows. A row leaving for "تم" slides the card shut around it,
/// at once under reduce motion.
class _AisleCard extends StatelessWidget {
  const _AisleCard({
    required this.aisle,
    required this.items,
    required this.done,
    required this.total,
    required this.format,
    required this.recipes,
    required this.onToggle,
  });

  final Aisle aisle;
  final List<GroceryItem> items;
  final int done;
  final int total;
  final _AmountFormat format;
  final RecipesState recipes;
  final void Function(GroceryItem, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) Divider(height: 1, indent: 12, color: cs.outlineVariant),
          _ItemRow(
            item,
            format: format,
            names: _recipeNames(item, recipes),
            onToggle: onToggle,
          ),
        ],
      ],
    );
    // The rows start 4dp in, so each row's 48dp checkbox target centres its
    // 24dp circle 28dp from the card's edge: the circle itself at the
    // card's 16dp padding (Groceries.dc.html). The heading keeps the 16dp.
    return SufraCard(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 12),
              _AisleTile(aisle),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    aisleLabel(l10n, aisle),
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.groceriesDoneOf(
                  settings.number(done),
                  settings.number(total),
                ),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // No AnimatedSize under reduce motion: the row just goes.
          if (reduceMotion)
            rows
          else
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: AlignmentDirectional.topCenter,
              child: rows,
            ),
        ],
      ),
    );
  }
}

/// The collapsed "تم" section at the end (GRO-5): unticking an item there
/// moves it straight back to its aisle.
class _DoneSection extends StatelessWidget {
  const _DoneSection({
    required this.items,
    required this.format,
    required this.onToggle,
  });

  final List<GroceryItem> items;
  final _AmountFormat format;
  final void Function(GroceryItem, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsState>();
    final recipes = context.watch<RecipesState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SufraCard(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
        // As in an aisle card: the checkbox circle at 16dp (see there).
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(4, 0, 12, 4),
        leading: Icon(Icons.check_circle_outline, color: cs.secondary),
        title: Row(
          children: [
            Text(l10n.groceriesDoneSection, style: theme.textTheme.titleMedium),
            const SizedBox(width: 8),
            Text(
              settings.number(items.length),
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 12, color: cs.outlineVariant),
            _ItemRow(
              item,
              format: format,
              names: _recipeNames(item, recipes),
              onToggle: onToggle,
            ),
          ],
        ],
      ),
    );
  }
}

/// One item: a round checkbox, its name with the recipes it came from on a
/// second line (GRO-5), and its merged amount in the accent at 700 (LOOK-4)
/// — the amount phrase exactly as the list has always formatted it (QTY-5,
/// QTY-6), read in the item's own direction, never forced left to right.
/// A long press moves it to another aisle (GRO-4).
class _ItemRow extends StatelessWidget {
  const _ItemRow(
    this.item, {
    required this.format,
    required this.names,
    required this.onToggle,
  });

  final GroceryItem item;
  final _AmountFormat format;
  final List<String> names;
  final void Function(GroceryItem, bool) onToggle;

  static const double _checkScale = 24 / 18;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final decor = Decor.of(context);
    final done = item.isDone;
    final amount = groceryAmountText(
      item.amounts,
      name: item.name,
      formatAmount: format,
    ).trim();
    final strike = done ? TextDecoration.lineThrough : null;
    final checkSide = CheckboxTheme.of(context).side;
    return MergeSemantics(
      child: InkWell(
        key: ValueKey('grocery-${item.id}'),
        onLongPress: () => _moveToAisle(context, item),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              // design-styles.md, Groceries: a 24dp circle. Material's
              // Checkbox always paints 18dp, so it's scaled up, with its
              // ring thinned to match so it still draws at 1.5dp; the 48dp
              // target keeps its layout size.
              Transform.scale(
                scale: _checkScale,
                child: Checkbox(
                  value: done,
                  side: checkSide?.copyWith(
                    width: checkSide.width / _checkScale,
                  ),
                  onChanged: (v) => onToggle(item, v ?? false),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // No maxLines/overflow here (should-fix, UI review):
                      // the item's name is what the shopper needs, and an
                      // ellipsis used to be able to hide it.
                      ContentText(
                        item.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: done ? cs.onSurfaceVariant : null,
                          decoration: strike,
                        ),
                      ),
                      if (names.isNotEmpty) _FromLine(names),
                    ],
                  ),
                ),
              ),
              if (amount.isNotEmpty) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    amount,
                    textDirection: contentDirection(item.name),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: decor.amountWeight,
                      color: done ? cs.onSurfaceVariant : decor.amountColor,
                      decoration: strike,
                    ),
                  ),
                ),
              ],
            ],
          ),
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
    return Text(
      _fromText(l10n, names),
      style: Theme.of(context).textTheme.bodyMedium
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
    useSafeArea: true,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
            child: Text(
              l10n.groceriesMoveToAisle,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          for (final a in Aisle.values)
            ListTile(
              contentPadding: const EdgeInsetsDirectional.symmetric(
                horizontal: 20,
              ),
              leading: _AisleTile(a),
              title: Text(aisleLabel(l10n, a)),
              selected: a == item.aisle,
              trailing: a == item.aisle ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, a),
            ),
        ],
      ),
    ),
  );
  if (chosen != null && chosen != item.aisle && context.mounted) {
    await context.read<GroceryState>().moveToAisle(item.id, chosen);
  }
}

/// A recipe's card in the By-recipe view (GRO-5): its photo or cover, its
/// title and "إزالة", then its own amounts. Hand-added items get the same
/// card under "أضفتها بنفسك", with no "إزالة".
class _RecipeGroup extends StatelessWidget {
  const _RecipeGroup({
    required this.title,
    required this.recipeId,
    required this.entries,
    required this.format,
    this.photoPath,
  });

  final String title;
  final String? recipeId;
  final String? photoPath;
  final List<(GroceryItem, List<GroceryAmount>)> entries;
  final _AmountFormat format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final decor = Decor.of(context);
    final id = recipeId;
    return SufraCard(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(
                    dimension: 36,
                    child: id != null
                        ? RecipePhoto(
                            recipeId: id,
                            title: title,
                            photoPath: photoPath,
                          )
                        : ColoredBox(
                            color: decor.sunk,
                            child: Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: ContentText(
                    title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (id != null)
                TextButton(
                  onPressed: () => _removeRecipe(context, title, id),
                  child: Text(l10n.planRemove),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (final (i, (item, amounts)) in entries.indexed) ...[
            if (i > 0) Divider(height: 1, color: cs.outlineVariant),
            _AmountRow(
              key: ValueKey('grocery-${item.id}'),
              name: item.name,
              amount: groceryAmountText(
                amounts,
                name: item.name,
                formatAmount: format,
              ).trim(),
            ),
          ],
        ],
      ),
    );
  }
}

/// A row of the By-recipe view: the name, and this recipe's own amount of
/// it (LOOK-4), in the item's own direction.
class _AmountRow extends StatelessWidget {
  const _AmountRow({super.key, required this.name, required this.amount});

  final String name;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = Decor.of(context);
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: ContentText(name, style: theme.textTheme.bodyLarge),
              ),
              if (amount.isNotEmpty) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    amount,
                    textDirection: contentDirection(name),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: decor.amountWeight,
                      color: decor.amountColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
        // DEL-2: about 5 seconds, then gone on its own.
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () =>
              groceries.restoreRecipe(removed.amountIds, removed.itemIds),
        ),
      ),
    );
}
