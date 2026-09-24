import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/library.dart';
import '../models/quantity/arabic_text.dart' show ltrIsolate;
import '../models/recipe.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../theme/decor.dart';
import '../widgets/content_direction.dart';
import '../widgets/empty_state.dart';
import 'home_screen.dart';

/// Search, sort, filters and results (ORG-3–ORG-6). With [cookbookId] it
/// shows one cookbook (ORG-1).
class LibraryView extends StatefulWidget {
  const LibraryView({super.key, this.cookbookId});
  final String? cookbookId;

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

  void _set(LibraryQuery q) => setState(() => _q = q);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<RecipesState>();
    final settings = context.watch<SettingsState>();
    final s = settings.settings;
    final q = _q.copyWith(sort: s.sort);
    final hits = state.query(q);
    final searching = q.text.trim().isNotEmpty || q.hasFilters;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
          child: SearchBar(
            controller: _search,
            hintText: l10n.searchHint,
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            trailing: [
              if (_search.text.isNotEmpty)
                IconButton(
                  tooltip: l10n.searchClear,
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _search.clear();
                    _set(_q.copyWith(text: ''));
                  },
                ),
            ],
            onChanged: (t) => _set(_q.copyWith(text: t)),
          ),
        ),
        _FilterBar(
          query: q,
          showCookbook: widget.cookbookId == null && state.cookbooks.isNotEmpty,
          onChanged: _set,
          onSort: (sort) => settings.update(s.copyWith(sort: sort)),
          grid: s.grid,
          onGrid: (g) => settings.update(s.copyWith(grid: g)),
        ),
        Expanded(
          child: hits.isEmpty
              ? _NoResults(
                  searching: searching,
                  cookbook: widget.cookbookId != null,
                  onClear: () {
                    _search.clear();
                    _set(_q.clearFilters().copyWith(text: ''));
                  },
                )
              : s.grid
              ? GridView.builder(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 96),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: hits.length,
                  itemBuilder: (context, i) => _RecipeCard(hits[i]),
                )
              : ListView.separated(
                  padding: const EdgeInsetsDirectional.only(bottom: 96),
                  itemCount: hits.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _RecipeTile(hits[i]),
                ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.query,
    required this.showCookbook,
    required this.onChanged,
    required this.onSort,
    required this.grid,
    required this.onGrid,
  });

  final LibraryQuery query;
  final bool showCookbook;
  final ValueChanged<LibraryQuery> onChanged;
  final ValueChanged<LibrarySort> onSort;
  final bool grid;
  final ValueChanged<bool> onGrid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.read<RecipesState>();
    final q = query;
    final sortNames = sortLabels(l10n);
    final sourceNames = sourceLabels(l10n);
    final digits = context.watch<SettingsState>();
    // LANG-5: the range is an expression, so it stays left to right in
    // right-to-left text ("30–60", never "60–30").
    final timeNames = {
      TimeBucket.under30: l10n.timeUnder30(digits.number(30)),
      TimeBucket.from30to60: l10n.time30to60(
        ltrIsolate('${digits.number(30)}–${digits.number(60)}'),
      ),
      TimeBucket.over60: l10n.timeOver60,
    };
    final bookName = {for (final c in state.cookbooks) c.id: c.name};

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
              children: [
                _Pick<LibrarySort>(
                  label: sortNames[q.sort]!,
                  icon: Icons.sort,
                  title: l10n.sortBy,
                  value: q.sort,
                  options: sortNames,
                  allowNone: false,
                  onPicked: (v) => onSort(v!),
                ),
                if (showCookbook)
                  _Pick<String>(
                    label: bookName[q.cookbookId] ?? l10n.filterCookbook,
                    title: l10n.filterCookbook,
                    value: q.cookbookId,
                    options: bookName,
                    onPicked: (v) => onChanged(q.copyWith(cookbookId: v)),
                  ),
                if (state.tags.isNotEmpty)
                  _Pick<String>(
                    label: q.tag ?? l10n.filterTag,
                    title: l10n.filterTag,
                    value: q.tag,
                    options: {for (final t in state.tags) t: t},
                    onPicked: (v) => onChanged(q.copyWith(tag: v)),
                  ),
                _Pick<SourceType>(
                  label: q.source == null
                      ? l10n.filterSource
                      : sourceNames[q.source]!,
                  title: l10n.filterSource,
                  value: q.source,
                  options: sourceNames,
                  onPicked: (v) => onChanged(q.copyWith(source: v)),
                ),
                _Pick<TimeBucket>(
                  label: q.time == null ? l10n.filterTime : timeNames[q.time]!,
                  title: l10n.filterTime,
                  value: q.time,
                  options: timeNames,
                  onPicked: (v) => onChanged(q.copyWith(time: v)),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(l10n.filterPhoto),
                    selected: q.photoOnly,
                    onSelected: (v) => onChanged(q.copyWith(photoOnly: v)),
                  ),
                ),
              ],
            ),
          ),
          // Pinned beside the chips, so it never scrolls out of reach.
          IconButton(
            tooltip: grid ? l10n.viewList : l10n.viewGrid,
            icon: Icon(grid ? Icons.view_list : Icons.grid_view),
            onPressed: () => onGrid(!grid),
          ),
        ],
      ),
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

/// A chip that opens a sheet of options; selected when a value is set.
class _Pick<T> extends StatelessWidget {
  const _Pick({
    required this.label,
    required this.title,
    required this.value,
    required this.options,
    required this.onPicked,
    this.icon,
    this.allowNone = true,
  });

  final String label;
  final String title;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T?> onPicked;
  final IconData? icon;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
      child: FilterChip(
        avatar: icon == null ? null : Icon(icon, size: 18),
        label: Text(label),
        selected: allowNone && value != null,
        showCheckmark: false,
        onSelected: (_) async {
          final picked = await showModalBottomSheet<(T?,)>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (allowNone)
                    ListTile(
                      title: Text(l10n.any),
                      trailing: value == null ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(context, (null,)),
                    ),
                  for (final e in options.entries)
                    ListTile(
                      title: ContentText(e.value),
                      trailing: e.key == value ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(context, (e.key,)),
                    ),
                ],
              ),
            ),
          );
          if (picked != null) onPicked(picked.$1);
        },
      ),
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

class _RecipeTile extends StatelessWidget {
  const _RecipeTile(this.hit);
  final LibraryHit hit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final r = hit.entry;
    final minutes = r.totalMinutes;
    final sub = [
      if (hit.matchedIngredient != null)
        l10n.containsIngredient(hit.matchedIngredient!),
      if (minutes != null) l10n.minutes(minutes, s.number(minutes)),
    ];
    return ListTile(
      leading: RecipeThumb(r.photoPath),
      title: ContentText(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: sub.isEmpty ? null : Text(sub.join(' · ')),
      onTap: () => openRecipe(context, r.id),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard(this.hit);
  final LibraryHit hit;

  @override
  Widget build(BuildContext context) {
    final r = hit.entry;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => openRecipe(context, r.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: RecipeThumb(r.photoPath, size: null)),
            Padding(
              padding: const EdgeInsetsDirectional.all(8),
              child: ContentText(
                r.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A recipe photo, or a placeholder; [size] null fills its box. A missing
/// photo file shows the same placeholder as no photo at all, never a broken
/// image (BAK-9: Android's own device backup carries the database but not
/// the photos folder, so a recipe restored that way has no photo file).
class RecipeThumb extends StatelessWidget {
  const RecipeThumb(this.path, {super.key, this.size = 56});
  final String? path;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder() => ColoredBox(
      color: scheme.secondaryContainer,
      child: Icon(
        Icons.restaurant_outlined,
        color: scheme.onSecondaryContainer,
      ),
    );
    final child = path == null
        ? placeholder()
        : Image.file(
            File(path!),
            fit: BoxFit.cover,
            cacheWidth: 480,
            errorBuilder: (_, _, _) => placeholder(),
          );
    if (size == null) return child;
    return ClipPath(
      // LOOK-6: the thumbnail takes its shape from Decor (a plain rounded
      // rect in Ink, Saffron's chamfered corner) instead of a fixed radius.
      clipper: ShapeBorderClipper(
        shape: Decor.of(context).thumbnailShape,
        textDirection: Directionality.of(context),
      ),
      child: SizedBox.square(dimension: size, child: child),
    );
  }
}
