import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/library.dart';
import '../models/quantity/arabic_text.dart' show ltrIsolate;
import '../models/quantity/rational.dart';
import '../models/recipe.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../theme/decor.dart';
import '../widgets/content_direction.dart';
import '../widgets/empty_state.dart';
import '../widgets/recipe_cover.dart';
import '../widgets/recipe_photo.dart';
import '../widgets/round_icon_button.dart';
import '../widgets/sufra_card.dart';
import '../widgets/sufra_search_field.dart';
import 'cook_mode_screen.dart';
import 'home_screen.dart';

/// LOOK-12: the one vertical gap between the library home's own stacked
/// blocks — the header, the backup reminder, the search row, the quick
/// chips, the resume card and the section heading (Main.dc.html: a single
/// 24dp rhythm, not the mixed 4/8/12 values a series of one-off fixes had
/// left behind).
const sectionGap = 24.0;

/// Search, sort, filters and results (ORG-3–ORG-6), the quick-chip row and
/// the "تابع الطبخ" resume card (LOOK-12, COOK-6). With [cookbookId] it
/// shows one cookbook (ORG-1) — its own fixed scope, kept apart from the
/// filters the user picks, so «الكل» and «مسح عوامل التصفية» can never
/// widen past it. Sorting lives one level up (the library home's header,
/// or the cookbook screen's own app-bar button, ORG-5), since it applies
/// to whichever segment or cookbook is showing.
///
/// Renders as one [CustomScrollView] (LOOK-8): the search row, the quick
/// chips, the resume card and the section heading are slivers ahead of the
/// results, so nothing here can overflow at a large text scale — the
/// header simply scrolls with the rest of the page. [leading] lets a
/// caller (the library home) splice its own header slivers (the greeting,
/// the segmented pill, the backup reminder) in front of these, so the
/// *whole* page is one scroll view rather than a fixed header above a
/// second, separately scrolling one.
class LibraryView extends StatefulWidget {
  const LibraryView({super.key, this.cookbookId, this.leading = const []});
  final String? cookbookId;
  final List<Widget> leading;

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  final _search = TextEditingController();
  late LibraryQuery _q = LibraryQuery(cookbookId: widget.cookbookId);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Forces the screen's own cookbook scope back onto every query change
  /// (ORG-1, RUN-1) — no matter what the change itself was (a quick chip,
  /// «الكل», a filter picked in the sheet or its own «مسح عوامل
  /// التصفية»), a cookbook screen can never drift into showing, or
  /// filtering, the whole library.
  void _set(LibraryQuery q) => setState(
    () => _q = widget.cookbookId == null
        ? q
        : q.copyWith(cookbookId: widget.cookbookId),
  );

  /// Whether [q] carries a filter beyond this screen's own fixed cookbook
  /// scope (ORG-1): on the library home ([cookbookId] null) any cookbook
  /// counts, but inside a cookbook screen its own, always-set cookbookId
  /// never does — otherwise an empty cookbook would always read as
  /// "searching" and «الكل» could never show selected.
  bool _hasVisibleFilters(LibraryQuery q) =>
      (widget.cookbookId == null && q.cookbookId != null) ||
      q.tag != null ||
      q.source != null ||
      q.time != null ||
      q.photoOnly;

  Future<void> _openFilterSheet(BuildContext context, LibraryQuery q) async {
    final state = context.read<RecipesState>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        initial: q,
        cookbooks: widget.cookbookId == null
            ? {for (final c in state.cookbooks) c.id: c.name}
            : const {},
        tags: state.tags,
        onApply: _set,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final decor = Decor.of(context);
    final state = context.watch<RecipesState>();
    final settings = context.watch<SettingsState>();
    final s = settings.settings;
    final q = _q.copyWith(sort: s.sort);
    final hits = state.query(q);
    final visibleFilters = _hasVisibleFilters(q);
    final searching = q.text.trim().isNotEmpty || visibleFilters;
    final bookName = widget.cookbookId == null
        ? null
        : state.cookbooks
              .where((c) => c.id == widget.cookbookId)
              .firstOrNull
              ?.name;
    // ORG-6: on the home, a cookbook picked in the filter sheet (not this
    // screen's own fixed scope, which `bookName` already covers) still
    // names itself in the heading; any other sheet-only filter (source,
    // time) or quick chip falls back to a filtered wording instead of the
    // misleading «كل الوصفات».
    final filterBookName = widget.cookbookId == null && q.cookbookId != null
        ? state.cookbooks.where((c) => c.id == q.cookbookId).firstOrNull?.name
        : null;
    final headingTitle =
        bookName ??
        filterBookName ??
        (visibleFilters ? l10n.libraryFilteredHeading : l10n.tabAllRecipes);

    void clear() {
      _search.clear();
      _set(_q.clearFilters().copyWith(text: ''));
    }

    return CustomScrollView(
      slivers: [
        ...widget.leading,
        SliverPadding(
          padding: EdgeInsetsDirectional.fromSTEB(
            decor.gutter,
            sectionGap,
            decor.gutter,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: SufraSearchField(
              controller: _search,
              hintText: l10n.searchHint,
              onChanged: (t) => _set(_q.copyWith(text: t)),
              onClear: clear,
              clearTooltip: l10n.searchClear,
              onFilterTap: () => _openFilterSheet(context, q),
              filterTooltip: l10n.filterAction,
              filterActive: visibleFilters,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsetsDirectional.only(top: sectionGap),
          sliver: SliverToBoxAdapter(
            child: _QuickChipsRow(
              query: q,
              allSelected: !visibleFilters,
              onChanged: _set,
            ),
          ),
        ),
        if (widget.cookbookId == null && state.resume != null)
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(
              decor.gutter,
              sectionGap,
              decor.gutter,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _ContinueCookingCard(resume: state.resume!),
            ),
          ),
        SliverPadding(
          padding: EdgeInsetsDirectional.fromSTEB(
            decor.gutter,
            sectionGap,
            decor.gutter,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: _SectionHeading(
              title: headingTitle,
              count: hits.length,
              grid: s.grid,
              onGrid: (g) => settings.update(s.copyWith(grid: g)),
            ),
          ),
        ),
        if (hits.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _NoResults(
              searching: searching,
              cookbook: widget.cookbookId != null,
              onClear: clear,
            ),
          )
        else if (s.grid)
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(
              decor.gutter,
              4,
              decor.gutter,
              96,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                // LOOK-12: a fixed 0.75 aspect ratio (design spec §1) — the
                // title/meta column sits `PositionedDirectional` over the
                // photo rather than pushing the card taller, so it stays
                // legible (`maxLines`/`overflow`) at a large text scale
                // instead of growing the grid's own row height.
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _RecipeCard(hits[i]),
                childCount: hits.length,
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(
              decor.gutter,
              4,
              decor.gutter,
              96,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 8),
                  child: _RecipeTile(hits[i]),
                ),
                childCount: hits.length,
              ),
            ),
          ),
      ],
    );
  }
}

Map<LibrarySort, String> sortLabels(AppLocalizations l10n) => {
  LibrarySort.recent: l10n.sortRecent,
  LibrarySort.az: l10n.sortAz,
  LibrarySort.recentlyCooked: l10n.sortRecentlyCooked,
  LibrarySort.mostCooked: l10n.sortMostCooked,
};

Map<SourceType, String> sourceLabels(AppLocalizations l10n) => {
  SourceType.written: l10n.sourceWritten,
  SourceType.website: l10n.sourceWebsite,
  SourceType.social: l10n.sourceSocial,
  SourceType.photo: l10n.sourcePhoto,
};

/// REC-3: the grid/list card's source badge — the site's own name for a
/// website, the platform's name for a social import (Decision 8: TikTok,
/// Instagram or YouTube, read from the host, falling back to the generic
/// label when it isn't one of those three), and the fixed label otherwise.
String sourceBadge(AppLocalizations l10n, LibraryEntry r) {
  final host = r.sourceUrl == null
      ? null
      : Uri.tryParse(r.sourceUrl!)?.host.toLowerCase();
  switch (r.sourceType) {
    case SourceType.written:
      return l10n.sourceWritten;
    case SourceType.photo:
      return l10n.sourcePhoto;
    case SourceType.website:
      return (host == null || host.isEmpty)
          ? l10n.sourceWebsite
          : host.replaceFirst('www.', '');
    case SourceType.social:
      if (host == null) return l10n.sourceSocial;
      if (host.contains('tiktok')) return l10n.sourceTiktok;
      if (host.contains('instagram')) return l10n.sourceInstagram;
      if (host.contains('youtube') || host.contains('youtu.be')) {
        return l10n.sourceYoutube;
      }
      return l10n.sourceSocial;
  }
}

/// A source badge's icon (REC-3): a generic mark for the source type, never
/// the exact platform's own logo.
IconData sourceBadgeIcon(SourceType type) => switch (type) {
  SourceType.written => Icons.edit_outlined,
  SourceType.photo => Icons.photo_camera_outlined,
  SourceType.website => Icons.public,
  SourceType.social => Icons.play_circle_outline,
};

/// LOOK-10: the text colour a no-photo card's title/meta take, over its own
/// [RecipeCover] rather than the photo scrim's white.
Color coverToneFor(BuildContext context, String recipeId) {
  final tints = Decor.of(context).coverTints;
  return tints[RecipeCover.tintIndexFor(recipeId, tints.length)].$2;
}

/// ORG-6's filter sheet, opened from the search row's accent circle: every
/// filter applies as soon as it's tapped (never waiting for a "Done"), so a
/// swipe-to-dismiss never loses a choice already made.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.cookbooks,
    required this.tags,
    required this.onApply,
  });

  final LibraryQuery initial;
  final Map<String, String> cookbooks;
  final List<String> tags;
  final ValueChanged<LibraryQuery> onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late LibraryQuery _q = widget.initial;

  void _apply(LibraryQuery q) {
    setState(() => _q = q);
    widget.onApply(q);
  }

  Widget _section(BuildContext context, String title, Widget child) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  Widget _choices<T>(
    AppLocalizations l10n,
    Map<T, String> options,
    T? value,
    ValueChanged<T?> onPicked,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      ChoiceChip(
        label: Text(l10n.any),
        selected: value == null,
        onSelected: (_) => onPicked(null),
      ),
      for (final e in options.entries)
        ChoiceChip(
          label: Text(e.value),
          selected: e.key == value,
          onSelected: (_) => onPicked(e.key),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final digits = context.watch<SettingsState>();
    final sourceNames = sourceLabels(l10n);
    // LANG-5: the range is an expression, so it stays left to right in
    // right-to-left text ("30–60", never "60–30").
    final timeNames = {
      TimeBucket.under30: l10n.timeUnder30(digits.number(30)),
      TimeBucket.from30to60: l10n.time30to60(
        ltrIsolate('${digits.number(30)}–${digits.number(60)}'),
      ),
      TimeBucket.over60: l10n.timeOver60,
    };

    return SafeArea(
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
                  child: Text(
                    l10n.filterAction,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (widget.cookbooks.isNotEmpty)
                  _section(
                    context,
                    l10n.filterCookbook,
                    _choices<String>(
                      l10n,
                      widget.cookbooks,
                      _q.cookbookId,
                      (v) => _apply(_q.copyWith(cookbookId: v)),
                    ),
                  ),
                if (widget.tags.isNotEmpty)
                  _section(
                    context,
                    l10n.filterTag,
                    _choices<String>(
                      l10n,
                      {for (final t in widget.tags) t: t},
                      _q.tag,
                      (v) => _apply(_q.copyWith(tag: v)),
                    ),
                  ),
                _section(
                  context,
                  l10n.filterSource,
                  _choices<SourceType>(
                    l10n,
                    sourceNames,
                    _q.source,
                    (v) => _apply(_q.copyWith(source: v)),
                  ),
                ),
                _section(
                  context,
                  l10n.filterTime,
                  _choices<TimeBucket>(
                    l10n,
                    timeNames,
                    _q.time,
                    (v) => _apply(_q.copyWith(time: v)),
                  ),
                ),
                _section(
                  context,
                  l10n.filterPhotoHeading,
                  FilterChip(
                    label: Text(l10n.filterPhoto),
                    selected: _q.photoOnly,
                    onSelected: (v) => _apply(_q.copyWith(photoOnly: v)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 0),
                  child: OutlinedButton(
                    onPressed: () => _apply(_q.clearFilters()),
                    child: Text(l10n.clearFilters),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// LOOK-12: «الكل» (clears every quick filter), «بصورة»، the under-30-minute
/// time bucket, «مواقع التواصل» and up to four most-used tags — each toggles
/// straight on the shared [LibraryQuery], combining with the filter sheet
/// and search exactly the same way (ORG-6). Unselected chips carry the
/// card fill and the light shadow (design-styles.md's "library quick
/// filters"), rather than the theme's default sunk fill.
class _QuickChipsRow extends StatelessWidget {
  const _QuickChipsRow({
    required this.query,
    required this.allSelected,
    required this.onChanged,
  });

  final LibraryQuery query;
  final bool allSelected;
  final ValueChanged<LibraryQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final digits = context.watch<SettingsState>();
    final state = context.watch<RecipesState>();
    final decor = Decor.of(context);
    final cs = Theme.of(context).colorScheme;
    final q = query;
    final topTags = state.tags.take(4).toList();

    Widget chip(String label, bool selected, VoidCallback onTap) {
      Widget filterChip({bool shrink = false}) => FilterChip(
        label: Text(label),
        selected: selected,
        backgroundColor: selected ? null : cs.surfaceContainerLowest,
        // Only the shadowed (unselected) chip below shrinks: the shadow has
        // to hug the 36dp visible pill, not Material's own 48dp padded tap
        // box (was-fix), while the selected chip keeps its ordinary tap
        // target.
        materialTapTargetSize: shrink ? MaterialTapTargetSize.shrinkWrap : null,
        onSelected: (_) => onTap(),
      );
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: selected
            ? filterChip()
            // A 48dp-tall hit area holding the shrink-wrapped chip, so the
            // row's own height still reads as a consistent 48dp regardless
            // of which chips carry a shadow.
            : SizedBox(
                height: 48,
                child: Center(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: const StadiumBorder(),
                      shadows: decor.liftShadow,
                    ),
                    child: filterChip(shrink: true),
                  ),
                ),
              ),
      );
    }

    // design-styles.md: chips are 36dp visual with a 48dp tap target — a
    // fixed 44dp row (was-fix) capped every chip's hit area under that, and
    // left almost no headroom once text scale passed about 1.3x.
    final height = math.max(
      48.0,
      MediaQuery.textScalerOf(context).scale(21) + 16 + 11,
    );

    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        // The default Clip.hardEdge cut the shadow off in a hard rectangle
        // at the row's own bounds (was-fix); the row spans the full screen
        // width, so nothing here ever bleeds past the screen anyway.
        clipBehavior: Clip.none,
        padding: EdgeInsetsDirectional.symmetric(horizontal: decor.gutter),
        children: [
          chip(l10n.any, allSelected, () => onChanged(q.clearFilters())),
          chip(
            l10n.filterPhoto,
            q.photoOnly,
            () => onChanged(q.copyWith(photoOnly: !q.photoOnly)),
          ),
          chip(
            l10n.timeUnder30(digits.number(30)),
            q.time == TimeBucket.under30,
            () => onChanged(
              q.copyWith(
                time: q.time == TimeBucket.under30 ? null : TimeBucket.under30,
              ),
            ),
          ),
          chip(
            l10n.sourceSocial,
            q.source == SourceType.social,
            () => onChanged(
              q.copyWith(
                source: q.source == SourceType.social
                    ? null
                    : SourceType.social,
              ),
            ),
          ),
          for (final t in topTags)
            chip(
              t,
              q.tag == t,
              () => onChanged(q.copyWith(tag: q.tag == t ? null : t)),
            ),
        ],
      ),
    );
  }
}

/// LOOK-12, COOK-6: shown only while a cook-mode session can still resume.
class _ContinueCookingCard extends StatelessWidget {
  const _ContinueCookingCard({required this.resume});
  final CookResume resume;

  Future<void> _continue(BuildContext context) async {
    final repo = context.read<RecipesState>().repository;
    final recipe = await repo.get(resume.recipeId);
    if (recipe == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CookModeScreen(recipe: recipe, factor: Rational.one),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final progress = resume.totalSteps == 0
        ? 0.0
        : (resume.step + 1) / resume.totalSteps;
    final stepLabel = l10n.stepOf(
      s.number(resume.step + 1),
      s.number(resume.totalSteps),
    );

    return SufraCard(
      padding: const EdgeInsetsDirectional.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox.square(
              dimension: 64,
              child: RecipePhoto(
                recipeId: resume.recipeId,
                title: resume.title,
                photoPath: resume.photoPath,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            // A single semantics node in the reading order the row already
            // draws in (should-fix): otherwise "تابع الطبخ", the title, the
            // step and the progress bar's own (Latin-digit) percentage each
            // read as separate stops.
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.continueCooking,
                    style: text.labelLarge?.copyWith(color: cs.primary),
                  ),
                  ContentText(
                    resume.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall,
                  ),
                  Text(stepLabel, style: text.bodySmall),
                  const SizedBox(height: 6),
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: Icons.play_arrow,
            tooltip: l10n.continueCookingAction,
            size: 48,
            color: cs.onPrimary,
            backgroundColor: cs.primary,
            onPressed: () => _continue(context),
          ),
        ],
      ),
    );
  }
}

/// LOOK-12: the section heading («كل الوصفات» or a cookbook's name), the
/// live count in a sunk pill, and the grid/list toggle (remembered,
/// ORG-5-style — the setting itself lives on [AppSettings.grid]).
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.count,
    required this.grid,
    required this.onGrid,
  });

  final String title;
  final int count;
  final bool grid;
  final ValueChanged<bool> onGrid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final decor = Decor.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: ContentText(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: decor.sunk,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(s.number(count), style: text.labelMedium),
              ),
            ],
          ),
        ),
        // The toggle sits flush at the row's end (was-fix: a loose
        // Flexible beside a Spacer let it float toward the middle,
        // following the title's own length).
        IconButton(
          tooltip: grid ? l10n.viewList : l10n.viewGrid,
          icon: Icon(
            grid ? Icons.view_list : Icons.grid_view,
            color: cs.onSurfaceVariant,
          ),
          onPressed: () => onGrid(!grid),
        ),
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({
    required this.searching,
    required this.cookbook,
    required this.onClear,
  });

  final bool searching;
  final bool cookbook;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      title: searching
          ? l10n.noResults
          : cookbook
          ? l10n.cookbookEmpty
          : l10n.recipesEmptyTitle,
      actions: [
        if (searching)
          OutlinedButton(onPressed: onClear, child: Text(l10n.clearFilters)),
      ],
    );
  }
}

/// LOOK-12: a list row — a 72dp rounded photo or [RecipeCover], the title,
/// the meta line (REC-3: only the fields that exist) and the source badge.
class _RecipeTile extends StatelessWidget {
  const _RecipeTile(this.hit);
  final LibraryHit hit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final r = hit.entry;
    final meta = [
      if (hit.matchedIngredient != null)
        l10n.containsIngredient(hit.matchedIngredient!),
      if (r.totalMinutes != null)
        l10n.minutes(r.totalMinutes!, s.number(r.totalMinutes!)),
      if (r.servings != null) l10n.servings(r.servings!, s.number(r.servings!)),
    ].join(' · ');
    final source = sourceBadge(l10n, r);

    return Semantics(
      button: true,
      label: [
        r.title,
        if (meta.isNotEmpty) meta,
        source,
      ].join(l10n.labelSeparator),
      onTap: () => openRecipe(context, r.id),
      child: ExcludeSemantics(
        child: SufraCard(
          padding: const EdgeInsetsDirectional.all(8),
          onTap: () => openRecipe(context, r.id),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox.square(
                  dimension: 72,
                  child: RecipePhoto(
                    recipeId: r.id,
                    title: r.title,
                    photoPath: r.photoPath,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ContentText(
                      r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      source,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// LOOK-12: a photo-forward grid card — the photo (or [RecipeCover]) fills
/// the card under a bottom scrim reaching at least 78% near-black (LOOK-3),
/// the title in white over it, the meta line (REC-3) and a source badge at
/// the top start. A no-photo card shows its cover's own dark tone instead of
/// white, since there's no photo for a scrim to sit on (LOOK-10).
class _RecipeCard extends StatelessWidget {
  const _RecipeCard(this.hit);
  final LibraryHit hit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final decor = Decor.of(context);
    final radius = decor.photoCardRadius;
    final r = hit.entry;
    final hasPhoto = RecipePhoto.hasPhoto(r.photoPath);
    final meta = [
      if (hit.matchedIngredient != null)
        l10n.containsIngredient(hit.matchedIngredient!),
      if (r.totalMinutes != null)
        l10n.minutes(r.totalMinutes!, s.number(r.totalMinutes!)),
      if (r.servings != null) l10n.servings(r.servings!, s.number(r.servings!)),
    ].join(' · ');
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = hasPhoto ? Colors.white : coverToneFor(context, r.id);
    final source = sourceBadge(l10n, r);
    // LOOK-3: a photo card's badge frost is a fixed light fill in both
    // themes (a photo can be any colour, so the fill never follows the
    // theme) — its ink has to be fixed too, the light theme's own ink,
    // never `onSurface` (which flips to a light colour in dark and stopped
    // reading against the still-light fill). A no-photo card's badge sits
    // on its own [RecipeCover] instead: in dark that cover is the dark card
    // fill, so the badge frosts dark there too, with the cover's own
    // (already light-on-dark) tone as ink — never the fixed light fill a
    // bright tone was never meant to sit on.
    final badgeFill = (hasPhoto || !dark)
        ? Colors.white.withValues(alpha: 0.85)
        : cs.surfaceContainerLowest.withValues(alpha: 0.85);
    final badgeInk = hasPhoto
        ? const Color(0xFF1F1A15)
        : coverToneFor(context, r.id);

    return Semantics(
      button: true,
      label: [
        r.title,
        if (meta.isNotEmpty) meta,
        source,
      ].join(l10n.labelSeparator),
      onTap: () => openRecipe(context, r.id),
      child: ExcludeSemantics(
        child: SufraCard(
          radius: radius,
          padding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPhoto)
                RecipePhoto(
                  recipeId: r.id,
                  title: r.title,
                  photoPath: r.photoPath,
                )
              else
                RecipeCover(recipeId: r.id, title: r.title),
              if (hasPhoto)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        // LOOK-3: reaches the full 78% near-black
                        // (rgba(20,14,10,.78), `Decor.photoScrim`) by 40%
                        // down and holds it to the bottom — not just at the
                        // very last pixel — so a two-line title at a large
                        // text scale (which can start as high as ~60% down)
                        // always sits on the full scrim, never a partial
                        // one.
                        stops: const [0, 0.4, 1],
                        colors: [
                          Colors.transparent,
                          decor.photoScrim,
                          decor.photoScrim,
                        ],
                      ),
                    ),
                  ),
                ),
              PositionedDirectional(
                top: 10,
                start: 10,
                end: 10,
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: badgeFill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            sourceBadgeIcon(r.sourceType),
                            size: 13,
                            color: badgeInk,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              source,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: badgeInk),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: 12,
                start: 12,
                end: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ContentText(
                      r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(color: textColor),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          // LOOK-3: a no-photo card's meta sits on its own
                          // opaque cover tone, not the photo scrim — full
                          // strength there (was-fix: faded to 0.9 dropped
                          // two of the six tints under 4.5:1).
                          color: hasPhoto
                              ? textColor.withValues(alpha: 0.9)
                              : textColor,
                        ),
                      ),
                  ],
                ),
              ),
              // The ripple and the keyboard/switch-access focus highlight
              // (should-fix): as the Stack's own last child, painted above
              // the photo/cover and the scrim, instead of underneath them
              // the way a `Material`/`InkWell` inside `SufraCard` would
              // paint it (SufraCard's own `onTap` isn't used here for
              // exactly that reason).
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => openRecipe(context, r.id),
                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
