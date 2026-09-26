import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/durations.dart';
import '../models/grocery.dart';
import '../models/plan.dart';
import '../models/quantity/convert.dart';
import '../models/quantity/rational.dart';
import '../models/recipe.dart';
import '../models/recipe_share.dart';
import '../models/recipe_translation.dart';
import '../providers/grocery_state.dart';
import '../providers/plan_state.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../services/links.dart';
import '../services/recipe_pages.dart';
import '../services/sharer.dart';
import '../theme/decor.dart';
import '../widgets/ad_slot.dart';
import '../widgets/amount_line.dart';
import '../widgets/content_direction.dart';
import '../widgets/recipe_cover.dart';
import '../widgets/round_icon_button.dart';
import '../widgets/segmented_pill.dart';
import '../widgets/sufra_card.dart';
import 'cook_mode_screen.dart';
import 'home_screen.dart' show openRecipe;
import 'ingredients_section.dart';
import 'plan_screen.dart';
import 'recipe_editor_screen.dart';
import 'translate_flow.dart';

/// One recipe (REC-3–REC-9, LOOK-13): the photo full-bleed (or a drawn
/// cover, LOOK-10) under round floating buttons, the content on a sheet
/// overlapping it, two tabs — Ingredients and Steps — and an action bar at
/// the bottom edge with the banner under it (ADS-9). Empty fields are
/// hidden, never shown as 0. Pops `true` when the recipe was deleted, so
/// the list can offer Undo.
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

  /// LOOK-13: the page opens on Ingredients every time; not stored.
  _Tab _tab = _Tab.ingredients;

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

  /// LOOK-13's "more": every action that has no button of its own — the
  /// translation (IMP-14) when it's offered, and delete (DEL-1).
  Future<void> _more(Recipe r) async {
    final l10n = AppLocalizations.of(context);
    final translate = offersTranslation(
      r,
      arabicApp: Localizations.localeOf(context).languageCode == 'ar',
    );
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (translate)
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(l10n.translateRecipe),
                  onTap: () => Navigator.pop(ctx, 'translate'),
                ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text(l10n.delete, style: TextStyle(color: cs.error)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    switch (choice) {
      case 'translate':
        await _translate(context, r);
      case 'delete':
        await _delete(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<Recipe?>(
      future: _current(context.watch<RecipesState>()),
      builder: (context, snap) {
        final r = snap.data;
        if (snap.connectionState != ConnectionState.done || r == null) {
          return Scaffold(
            appBar: AppBar(),
            body: snap.connectionState != ConnectionState.done
                ? const Center(child: CircularProgressIndicator())
                : Center(child: Text(l10n.recipeMissing)),
          );
        }
        return Scaffold(
          body: _RecipePage(
            r,
            factor: _factor,
            onFactor: (f) => setState(() => _factor = f),
            tab: _tab,
            onTab: (t) => setState(() => _tab = t),
            onEdit: () => _edit(r),
            onMore: () => _more(r),
          ),
          // The Scaffold's bottom bar, so a snackbar floats above it
          // rather than over its buttons. The system bar's inset is added
          // once, around both: whether or not the slot fills (it can stay
          // empty while banners are on, before its size is measured or when
          // it can't be), the bar never sits under the system bar (ADS-3).
          // The page colour sits outside the SafeArea, so the inset strip
          // shows it too.
          bottomNavigationBar: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionBar(r, factor: _factor),
                  // ADS-3, ADS-9: the recipe page's slot, under its action
                  // bar, never in the scrolling content, with the slot's
                  // own 8 dp between them. Cook mode itself has none
                  // (COOK-1).
                  const AdSlot(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _Tab { ingredients, steps }

/// The scrolling page over the photo, with the floating buttons on top.
class _RecipePage extends StatefulWidget {
  const _RecipePage(
    this.r, {
    required this.factor,
    required this.onFactor,
    required this.tab,
    required this.onTab,
    required this.onEdit,
    required this.onMore,
  });

  final Recipe r;
  final Rational factor;
  final ValueChanged<Rational> onFactor;
  final _Tab tab;
  final ValueChanged<_Tab> onTab;
  final VoidCallback onEdit;
  final VoidCallback onMore;

  /// LOOK-13: the photo hero, and LOOK-10's shorter cover header.
  static const photoHeight = 330.0;
  static const coverHeight = 200.0;

  /// How far the content sheet overlaps the photo.
  static const overlap = 30.0;

  @override
  State<_RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<_RecipePage> {
  /// Whether the content sheet has scrolled up under the status bar.
  final _covered = ValueNotifier(false);

  @override
  void dispose() {
    _covered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gutter = Decor.of(context).gutter;
    final top = MediaQuery.paddingOf(context).top;
    final r = widget.r;
    final factor = widget.factor;
    // should-fix, platform review: a missing photo file (BAK-9: a device
    // restore brings back the database but not photos) gets the drawn
    // cover instead of an empty box.
    final photo = r.photoPath != null && File(r.photoPath!).existsSync()
        ? File(r.photoPath!)
        : null;
    final heroHeight = photo != null
        ? _RecipePage.photoHeight
        : _RecipePage.coverHeight;
    const overlap = _RecipePage.overlap;
    final hero = photo != null
        ? Image.file(
            photo,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                RecipeCover(recipeId: r.id, title: r.title),
          )
        : RecipeCover(recipeId: r.id, title: r.title);

    // The status bar's icons: light over a photo (under its scrim), and the
    // theme's own over a drawn cover or once the page covers the bar.
    final themed = theme.brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    SystemUiOverlayStyle statusBar(bool covered) {
      final icons = photo != null && !covered ? Brightness.light : themed;
      // Status-bar fields only: the navigation bar keeps its own style.
      return SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: icons,
        statusBarBrightness: icons == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      );
    }

    return Stack(
      children: [
        // Screen readers reach the floating buttons first, as an app bar's,
        // then the page (the scroll view starts at y = 0, so it would
        // otherwise come first).
        Semantics(
          container: true,
          sortKey: const OrdinalSortKey(2),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.depth == 0) {
                _covered.value = n.metrics.pixels > heroHeight - overlap;
              }
              return false;
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      SizedBox(
                        height: heroHeight + top,
                        width: double.infinity,
                        child: ExcludeSemantics(child: hero),
                      ),
                      // LOOK-3: the status bar's icons over a photo sit on a
                      // short scrim.
                      if (photo != null)
                        PositionedDirectional(
                          top: 0,
                          start: 0,
                          end: 0,
                          height: top + 24,
                          child: const IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x59000000),
                                    Color(0x00000000),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          top: heroHeight + top - overlap,
                        ),
                        child: DecoratedBox(
                          // design-styles.md: the page colour, not a card — the
                          // screen's own body continuing past the photo.
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                          ),
                          // The top padding is _Content's own: the source chip's
                          // tap box reaches into it.
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                              gutter,
                              0,
                              gutter,
                              32,
                            ),
                            child: _Content(
                              r,
                              factor: factor,
                              onFactor: widget.onFactor,
                              tab: widget.tab,
                              onTab: widget.onTab,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // The page colour behind the status bar once the sheet scrolls under
        // it, and the status bar's icon style.
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          height: top,
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: _covered,
              builder: (context, covered, _) =>
                  AnnotatedRegion<SystemUiOverlayStyle>(
                    value: statusBar(covered),
                    child: ColoredBox(
                      color: covered ? cs.surface : Colors.transparent,
                    ),
                  ),
            ),
          ),
        ),
        // LOOK-13: round floating buttons, back at the start, share, edit
        // and more at the end — kept over the page as it scrolls.
        PositionedDirectional(
          top: top + 12,
          start: 16,
          child: Semantics(
            container: true,
            sortKey: const OrdinalSortKey(0),
            child: RoundIconButton(
              icon: Icons.arrow_back,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        PositionedDirectional(
          top: top + 12,
          end: 16,
          child: Semantics(
            container: true,
            sortKey: const OrdinalSortKey(1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RoundIconButton(
                  icon: Icons.share_outlined,
                  tooltip: l10n.shareTooltip,
                  onPressed: () => openShareRecipe(context, r, factor),
                ),
                const SizedBox(width: 4),
                RoundIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: l10n.edit,
                  onPressed: widget.onEdit,
                ),
                const SizedBox(width: 4),
                RoundIconButton(
                  icon: Icons.more_horiz,
                  tooltip: l10n.moreActions,
                  onPressed: widget.onMore,
                ),
              ],
            ),
          ),
        ),
        // The page fading into the action bar under it.
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          height: 24,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [cs.surface.withValues(alpha: 0), cs.surface],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Everything on the sheet: chips, title, facts, the plan band, the
/// translation, the tabs and the chosen tab.
class _Content extends StatelessWidget {
  const _Content(
    this.r, {
    required this.factor,
    required this.onFactor,
    required this.tab,
    required this.onTab,
  });

  final Recipe r;
  final Rational factor;
  final ValueChanged<Rational> onFactor;
  final _Tab tab;
  final ValueChanged<_Tab> onTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final hasIngredients = r.ingredients.any((s) => s.items.isNotEmpty);
    final hasNotes = r.notes != null && r.notes!.trim().isNotEmpty;
    final hasSteps = r.steps.any((s) => s.items.isNotEmpty);
    final hasMethod = hasSteps || hasNotes;
    // Two tabs only when both have something in them; otherwise the one
    // that does shows on its own.
    final shown = hasIngredients && hasMethod
        ? tab
        : hasIngredients
        ? _Tab.ingredients
        : _Tab.steps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Chips(r),
        // The page's heading and the route's name, as an app bar's title
        // would be: announced on opening, and a heading to jump to.
        Semantics(
          header: true,
          namesRoute: true,
          child: ContentText(r.title, style: text.headlineMedium),
        ),
        _Facts(r),
        _NextPlanned(r.id),
        _TranslationLinks(r.id),
        // IMP-14: a recipe written mostly in another language than the
        // app's; the saved copy is a new recipe, and this one never changes.
        if (offersTranslation(
          r,
          arabicApp: Localizations.localeOf(context).languageCode == 'ar',
        ))
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _translate(context, r),
              icon: const Icon(Icons.translate),
              label: Text(l10n.translateRecipe),
            ),
          ),
        if (hasIngredients && hasMethod) ...[
          const SizedBox(height: 20),
          SegmentedPill<_Tab>(
            options: {
              _Tab.ingredients: l10n.ingredients,
              _Tab.steps: l10n.steps,
            },
            value: shown,
            onChanged: onTab,
          ),
        ],
        if (hasIngredients || hasMethod) const SizedBox(height: 16),
        if (hasIngredients && shown == _Tab.ingredients)
          IngredientsSection(recipe: r, factor: factor, onFactor: onFactor),
        if (hasMethod && shown == _Tab.steps) ...[
          if (hasSteps) _StepsCard(r.steps),
          if (hasSteps && hasNotes) const SizedBox(height: 20),
          if (hasNotes) _NotesCard(r.notes!),
        ],
      ],
    );
  }
}

/// The source (opening its link), then the tags and cookbooks.
class _Chips extends StatelessWidget {
  const _Chips(this.r);
  final Recipe r;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final decor = Decor.of(context);
    final url = r.sourceUrl == null ? null : Uri.tryParse(r.sourceUrl!);
    final host = url?.host;
    final books = [
      for (final c in context.watch<RecipesState>().cookbooks)
        if (r.cookbookIds.contains(c.id)) c,
    ];
    final hasSource = host != null && host.isNotEmpty;
    // The sheet's 20 dp above the chips, or above the title without them.
    if (!hasSource && r.tags.isEmpty && books.isEmpty) {
      return const SizedBox(height: 20);
    }
    // The source chip is shrink-wrapped inside a 48 dp tap box (so its
    // shadow hugs the visible pill, not the box); [slack] is the box's
    // room above and below the pill, taken off the padding around the row
    // so the pill itself sits 20 dp under the sheet's edge and 16 dp over
    // the title, as in Recipe.dc.html.
    final pill = MediaQuery.textScalerOf(context).scale(21) + 14;
    final slack = hasSource ? math.max(0.0, (48 - pill) / 2) : 0.0;
    return Padding(
      padding: EdgeInsetsDirectional.only(top: 20 - slack, bottom: 16 - slack),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hasSource)
            // The full 48 dp box opens the link too, not only the pill.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: () => _openSource(context, url!),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: const StadiumBorder(),
                      shadows: decor.liftShadow,
                    ),
                    // LOOK-3: the theme's `outline` edge in both brightnesses,
                    // so the card-white pill keeps a 3:1 boundary on the page.
                    child: ActionChip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: cs.surfaceContainerLowest,
                      avatar: Icon(Icons.public, size: 18, color: cs.onSurface),
                      label: Text(
                        l10n.sourceFrom(host.replaceFirst('www.', '')),
                        style: TextStyle(color: cs.onSurface),
                      ),
                      onPressed: () => _openSource(context, url!),
                    ),
                  ),
                ),
              ),
            ),
          // Tags and cookbooks aren't buttons: Recipe.dc.html's plain sunk
          // badges in ink, with no edge and no "#".
          for (final t in r.tags) _Badge(label: ContentText(t)),
          for (final c in books)
            _Badge(icon: Icons.menu_book_outlined, label: ContentText(c.name)),
        ],
      ),
    );
  }

  Future<void> _openSource(BuildContext context, Uri url) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final opened = await context.read<LinkOpener>().open(url);
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.linkOpenFailed)));
    }
  }
}

/// A tag or cookbook on the recipe page: a `sunk` pill at 14/600 in ink.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.icon});
  final Widget label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 14,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Decor.of(context).sunk,
        borderRadius: BorderRadius.circular(999),
      ),
      child: DefaultTextStyle.merge(
        style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurface),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: cs.onSurface),
              const SizedBox(width: 6),
            ],
            Flexible(child: label),
          ],
        ),
      ),
    );
  }
}

/// REC-3, LOOK-13: prep, cook and servings as up to three tiles — only the
/// ones the recipe has.
class _Facts extends StatelessWidget {
  const _Facts(this.r);
  final Recipe r;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final tiles = [
      if (r.prepMinutes case final m?)
        (Icons.schedule, l10n.factPrep, l10n.minutes(m, s.number(m))),
      if (r.cookMinutes case final m?)
        (
          Icons.local_fire_department_outlined,
          l10n.factCook,
          l10n.minutes(m, s.number(m)),
        ),
      if (r.servings case final n?)
        (Icons.people_outline, l10n.factServings, s.number(n)),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, (icon, caption, value)) in tiles.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _FactTile(icon: icon, caption: caption, value: value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.icon,
    required this.caption,
    required this.value,
  });

  final IconData icon;
  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return MergeSemantics(
      child: SufraCard(
        radius: 18,
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            // One line, shrunk to fit at 1.3x rather than split the number
            // from its unit (QTY-6's spirit).
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// IMP-14, IMP-16: translating a saved recipe costs one AI import, with
/// the cost line first; the copy opens once saved.
Future<void> _translate(BuildContext context, Recipe r) async {
  final saved = await translateAndPreview(
    context,
    r,
    free: false,
    linkToOriginal: true,
  );
  if (saved != null && context.mounted) await openRecipe(context, saved);
}

/// IMP-14: "مترجمة من: <title>" on a translated copy and "الترجمة: <title>"
/// on its original, each opening the other. A link whose other recipe was
/// deleted just isn't there.
class _TranslationLinks extends StatelessWidget {
  const _TranslationLinks(this.recipeId);
  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recipes = context.watch<RecipesState>();
    return FutureBuilder(
      future: recipes.translationLinks(recipeId),
      builder: (context, snap) {
        final links = snap.data;
        if (links == null) return const SizedBox.shrink();
        // LANG-5: the other title may be in another language, so it's
        // isolated from the line around it.
        String isolated(String title) =>
            '${String.fromCharCode(0x2068)}$title${String.fromCharCode(0x2069)}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (links.from case final from?)
              _LinkRow(
                text: l10n.translatedFromLine(isolated(from.title)),
                onTap: () => openRecipe(context, from.id),
              ),
            if (links.translation case final translation?)
              _LinkRow(
                text: l10n.translationLine(isolated(translation.title)),
                onTap: () => openRecipe(context, translation.id),
              ),
          ],
        );
      },
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 8),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.translate, size: 18),
        label: Text(text),
      ),
    ),
  );
}

/// The next meal this recipe is planned for, if any (PLAN-6, LOOK-13): a
/// `herbSoft` band.
class _NextPlanned extends StatelessWidget {
  const _NextPlanned(this.recipeId);
  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final plan = context.watch<PlanState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return FutureBuilder<PlanEntry?>(
      future: plan.nextFor(recipeId),
      builder: (context, snap) {
        final e = snap.data;
        if (e == null) return const SizedBox.shrink();
        final day = s.inDigits(
          MaterialLocalizations.of(context).formatMediumDate(e.date),
        );
        return Padding(
          padding: const EdgeInsetsDirectional.only(top: 16),
          child: Container(
            padding: const EdgeInsetsDirectional.all(12),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: cs.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.planNextMeal(day, mealName(l10n, e.slot)),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// LOOK-13's Steps tab: one card, each step with its number (in the
/// user's digits) in a 32 dp soft-accent square, group labels between
/// (REC-4, REC-6). A duration in a step is marked in the accent with a
/// small timer icon; it's not a button here — timers run in cook mode.
class _StepsCard extends StatelessWidget {
  const _StepsCard(this.sections);
  final List<Section<RecipeStep>> sections;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hairline = Decor.of(context).rowHairline ?? cs.outlineVariant;
    final rows = <Widget>[];
    var n = 0;
    for (final section in sections) {
      if (section.name != null) rows.add(GroupName(section.name!));
      for (final (i, step) in section.items.indexed) {
        n++;
        rows.add(
          Container(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: i > 0
                  ? BorderDirectional(top: BorderSide(color: hairline))
                  : null,
            ),
            // The step's number and its text read as one stop.
            child: MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 4,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      s.number(n),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: StepText(step.text)),
                ],
              ),
            ),
          ),
        );
      }
    }
    return SufraCard(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

/// A step's text in its own direction (LANG-5), each duration in it
/// (COOK-4) in the accent. On the recipe page ([pill]) a duration is
/// RecipeDark.dc.html's small `sunk` pill: a 13 dp timer icon and the
/// phrase at 14/600. Cook mode passes `pill: false` and its own larger
/// [style] (COOK-2), where the duration is plain accent text at 700, as in
/// Cook.dc.html; the timer card under it is the button. [style] defaults
/// to the body style.
class StepText extends StatelessWidget {
  const StepText(this.text, {super.key, this.style, this.pill = true});
  final String text;
  final TextStyle? style;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyLarge!;
    final spans = findDurationSpans(text);
    if (spans.isEmpty) return ContentText(text, style: base);
    final accent = theme.colorScheme.primary;
    final sunk = Decor.of(context).sunk;
    final direction = contentDirection(text);
    final children = <InlineSpan>[];
    var at = 0;
    for (final d in spans) {
      if (d.start > at) {
        children.add(TextSpan(text: text.substring(at, d.start)));
      }
      final phrase = text.substring(d.start, d.end);
      children.add(
        pill
            ? WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                // The span already scales its child with the text; the
                // pill's own text mustn't scale a second time.
                child: MediaQuery.withNoTextScaling(
                  child: Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: sunk,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, size: 13, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          phrase,
                          textDirection: direction,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : TextSpan(
                text: phrase,
                style: TextStyle(color: accent, fontWeight: FontWeight.w700),
              ),
      );
      at = d.end;
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at)));
    final ui = Directionality.of(context);
    return Text.rich(
      TextSpan(children: children),
      style: base,
      textDirection: direction,
      textAlign: ui == TextDirection.rtl ? TextAlign.right : TextAlign.left,
    );
  }
}

/// LOOK-13: the notes follow the steps, in their own card.
class _NotesCard extends StatelessWidget {
  const _NotesCard(this.notes);
  final String notes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return SufraCard(
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.notes, style: text.titleSmall),
          ),
          const SizedBox(height: 8),
          ContentText(notes, style: text.bodyLarge),
        ],
      ),
    );
  }
}

/// LOOK-13's action bar at the bottom edge, outside the scroll: "ابدأ
/// الطبخ" (COOK-1: only with a step), add to plan (PLAN-3) and add to
/// groceries (GRO-2, only with an ingredient).
class _ActionBar extends StatelessWidget {
  const _ActionBar(this.r, {required this.factor});
  final Recipe r;
  final Rational factor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final decor = Decor.of(context);
    final hasSteps = r.steps.any((s) => s.items.isNotEmpty);
    // The system bar's inset is the SafeArea's, around the bar and the slot.
    return ColoredBox(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
        child: Row(
          children: [
            if (hasSteps)
              Expanded(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    shadows: decor.floatShadow,
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CookModeScreen(recipe: r, factor: factor),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      l10n.startCooking,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: 12),
            RoundIconButton(
              size: 56,
              icon: Icons.calendar_month_outlined,
              tooltip: l10n.planAddToPlan,
              onPressed: () => openAddToPlan(context, r.id),
            ),
            if (r.ingredients.any((s) => s.items.isNotEmpty)) ...[
              const SizedBox(width: 12),
              RoundIconButton(
                size: 56,
                icon: Icons.shopping_basket_outlined,
                tooltip: l10n.addToGroceries,
                onPressed: () => openAddToGroceries(context, r, factor),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
                  title: AmountLine(
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
  // LOOK-1/SHARE-3: the chosen look's own light palette, threaded through
  // rather than read inside the renderer.
  final style = settings.settings.style;

  String servingsLabel(int n) => l10n.servings(n, settings.number(n));
  String prepTimeLabel(int m) =>
      l10n.prepTime(l10n.minutes(m, settings.number(m)));
  String cookTimeLabel(int m) =>
      l10n.cookTime(l10n.minutes(m, settings.number(m)));
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
      style: style,
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
