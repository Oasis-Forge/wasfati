import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/cookbook.dart';
import '../models/library.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../services/backup.dart';
import '../theme/decor.dart';
import '../widgets/ad_slot.dart';
import '../widgets/content_direction.dart';
import '../widgets/digit_counter.dart';
import '../widgets/empty_state.dart';
import '../widgets/nav_pill.dart';
import '../widgets/recipe_photo.dart';
import '../widgets/round_icon_button.dart';
import '../widgets/segmented_pill.dart';
import '../widgets/sufra_card.dart';
import 'add_sheet.dart';
import 'groceries_screen.dart';
import 'library_view.dart';
import 'plan_screen.dart';
import 'recipe_editor_screen.dart';
import 'recipe_screen.dart';
import 'settings_screen.dart';

/// LOOK-7: the app's four places on the navigation pill — الوصفات، الخطة،
/// المشتريات، الإعدادات — with a raised centre "+" that opens the add sheet
/// (LOOK-11). The pill always shows, even with an empty library (Settings
/// lives in it now): an empty library keeps its one clear first action
/// (RUN-1), which opens the add sheet.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.clock});

  /// Forwarded to [LibraryHome]'s greeting (LOOK-12); null means the real
  /// wall clock.
  final DateTime Function()? clock;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const _settingsTabIndex = 3;

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      // Back used to return to the library from a pushed Settings route;
      // now Settings is just another tab, so without this Back would close
      // the app instead (standard bottom-navigation behaviour is Back to
      // the start destination).
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(
              index: _index,
              children: [
                LibraryHome(clock: widget.clock),
                const PlanScreen(),
                const GroceriesScreen(),
                const SettingsScreen(),
              ],
            ),
            // LOOK-7/LOOK-8: the last item on every tab (Settings included)
            // fades into the page colour under a 40dp gradient rather than
            // cutting off hard under the pill. Purely decorative — it must
            // never intercept the scroll or a tap meant for the content
            // beneath it.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 40,
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
        ),
        // ADS-3, ADS-9: the library, the plan and groceries share one slot,
        // in the bottom bar above the pill, outside every tab's scrolling
        // content; Settings never carries one.
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_index != _settingsTabIndex) const AdSlot(),
            NavPill(
              tabs: [
                NavPillTab(
                  icon: Icons.menu_book_outlined,
                  label: l10n.tabRecipes,
                ),
                NavPillTab(
                  icon: Icons.calendar_month_outlined,
                  label: l10n.planTitle,
                ),
                NavPillTab(
                  icon: Icons.shopping_basket_outlined,
                  label: l10n.groceriesTitle,
                ),
                NavPillTab(icon: Icons.settings_outlined, label: l10n.settings),
              ],
              currentIndex: _index,
              onTabSelected: (i) => setState(() => _index = i),
              onAddPressed: () => showAddSheet(context),
              addTooltip: l10n.recipesAdd,
            ),
          ],
        ),
      ),
    );
  }
}

enum _LibrarySegment { all, cookbooks }

/// The library: "All recipes" and "Cookbooks" (ORG-1), under a time-of-day
/// greeting and the library's own question (LOOK-12). An empty library
/// explains itself with one action (RUN-1) and keeps the old app-bar title
/// instead — there's nothing to greet yet.
class LibraryHome extends StatefulWidget {
  const LibraryHome({super.key, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  /// LOOK-12's greeting reads the wall clock (morning before 12:00, evening
  /// from then on) — injectable so a test can fix the time of day, unlike
  /// [BackupService]'s UTC-stamped "when a backup was last saved".
  final DateTime Function() clock;

  @override
  State<LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends State<LibraryHome> {
  _LibrarySegment _segment = _LibrarySegment.all;

  /// LOOK-12's greeting, the 30/700 question and, only on the "all recipes"
  /// segment, the sort button (ORG-5: sorting means nothing on the
  /// cookbooks grid, which has its own order), then the segmented pill —
  /// as one block so it can be spliced as a single leading sliver into
  /// whichever [CustomScrollView] the segment builds (LOOK-8: the whole
  /// page is one scroll view, so nothing here can overflow at a large
  /// text scale).
  Widget _header(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final gutter = Decor.of(context).gutter;
    final greeting = widget.clock().hour < 12
        ? l10n.greetingMorning
        : l10n.greetingEvening;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(gutter, sectionGap, gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: text.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.libraryQuestion,
                      style: text.displayLarge,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              if (_segment == _LibrarySegment.all) ...[
                const SizedBox(width: 12),
                RoundIconButton(
                  icon: Icons.sort,
                  tooltip: l10n.sortBy,
                  onPressed: () => openSortSheet(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SegmentedPill<_LibrarySegment>(
            options: {
              _LibrarySegment.all: l10n.tabAllRecipes,
              _LibrarySegment.cookbooks: l10n.tabCookbooks,
            },
            value: _segment,
            onChanged: (v) => setState(() => _segment = v),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<RecipesState>();
    final empty = state.loaded && state.recipes.isEmpty;

    return Scaffold(
      // LOOK-7: the library's own import/settings actions and its extended
      // FAB are gone — their jobs move to the navigation pill's centre "+"
      // (the add sheet, LOOK-11) and its Settings tab. The app's own name
      // only shows in the empty state (RUN-1); a populated library greets
      // instead (LOOK-12).
      appBar: empty ? AppBar(title: Text(l10n.appTitle)) : null,
      body: !state.loaded
          ? const Center(child: CircularProgressIndicator())
          : empty
          ? _Empty(l10n: l10n)
          : SafeArea(
              bottom: false,
              child: _segment == _LibrarySegment.all
                  ? LibraryView(
                      leading: [
                        SliverToBoxAdapter(child: _header(context)),
                        const SliverToBoxAdapter(child: _BackupReminderCard()),
                      ],
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _header(context)),
                        const SliverToBoxAdapter(child: _BackupReminderCard()),
                        ..._cookbooksSlivers(context),
                      ],
                    ),
            ),
    );
  }
}

/// ORG-5, shared with [CookbookScreen]'s own app-bar button: every sort
/// order in one sheet.
Future<void> openSortSheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final settings = context.read<SettingsState>();
  final labels = sortLabels(l10n);
  final chosen = await showModalBottomSheet<LibrarySort>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
            child: Text(
              l10n.sortBy,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          for (final e in labels.entries)
            ListTile(
              title: Text(e.value),
              // should-fix: a screen reader could see every option was a
              // "check-able" row (`hasSelectedState`) but never which one
              // was actually selected — the check mark alone carries no
              // semantics.
              selected: e.key == settings.settings.sort,
              trailing: e.key == settings.settings.sort
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(ctx, e.key),
            ),
        ],
      ),
    ),
  );
  if (chosen != null) {
    unawaited(settings.update(settings.settings.copyWith(sort: chosen)));
  }
}

/// BAK-8: "آخر نسخة احتياطية قبل ٤٥ يومًا" (or "لم تحفظ نسخة احتياطية بعد")
/// with "احفظ الآن" and "لاحقًا" (snoozes 30 days), above the library's
/// tabs. Renders nothing when there's nothing to remind about — with fewer
/// than 10 recipes, a recent-enough backup, a live snooze, or the Settings
/// switch off ([shouldRemindBackup]) — so it never blocks anything. Never
/// shown in cook mode, the editor or the import preview: those screens
/// never build it at all.
class _BackupReminderCard extends StatefulWidget {
  const _BackupReminderCard();

  @override
  State<_BackupReminderCard> createState() => _BackupReminderCardState();
}

class _BackupReminderCardState extends State<_BackupReminderCard> {
  bool _busy = false;

  Future<void> _saveNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final saved = await saveBackupNow(context);
      if (!saved || !mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.backupSaveDone)));
    } finally {
      // must-fix, platform review: a `finally` here, not a check right
      // after the await, so a failed save (saveBackupNow now shows its own
      // message and returns false rather than throwing) still re-enables
      // both buttons instead of leaving the card stuck disabled.
      if (mounted) setState(() => _busy = false);
    }
  }

  void _later() {
    final settings = context.read<SettingsState>();
    final now = context.read<BackupService>().now();
    settings.update(
      settings.settings.copyWith(
        backupReminderSnoozedUntil: now.add(const Duration(days: 30)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsState = context.watch<SettingsState>();
    final recipes = context.watch<RecipesState>();
    final backup = context.watch<BackupService>();
    final now = backup.now();
    if (!shouldRemindBackup(
      recipes.recipes.length,
      now,
      settingsState.settings,
    )) {
      return const SizedBox.shrink();
    }
    final last = settingsState.settings.lastBackupAt;
    final days = last == null ? 0 : now.difference(last).inDays;
    final line = last == null
        ? l10n.backupReminderNever
        : l10n.backupReminderDaysAgo(days, settingsState.number(days));
    final gutter = Decor.of(context).gutter;

    // should-fix, LOOK-6: a plain Material `Card` has no shadow in this
    // theme (`CardThemeData.shadowColor` is transparent) and a 12dp inset
    // that didn't line up with the header's own gutter above it. The
    // vertical inset is `sectionGap`, the one gap the library home's own
    // stacked blocks now share.
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(gutter, sectionGap, gutter, 0),
      child: SufraCard(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line),
            const SizedBox(height: 8),
            // must-fix, platform review: a plain end-aligned Row overflowed
            // at 1.3× text size (LANG-6) — 13px in Arabic, 51px in English
            // — because two full-width buttons plus their gap no longer fit
            // a 360dp phone. OverflowBar wraps to a second line instead.
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 4,
              children: [
                TextButton(
                  onPressed: _busy ? null : _later,
                  child: Text(l10n.backupReminderLaterAction),
                ),
                FilledButton(
                  onPressed: _busy ? null : _saveNow,
                  child: Text(l10n.backupReminderNowAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the editor for a new recipe, then the saved recipe's page.
Future<void> openEditor(BuildContext context, {String? cookbookId}) async {
  final id = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => RecipeEditorScreen(initialCookbookId: cookbookId),
    ),
  );
  if (id != null && context.mounted) await openRecipe(context, id);
}

/// Opens a recipe's page; if it comes back deleted, offers Undo (DEL-2).
Future<void> openRecipe(BuildContext context, String id) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final recipes = context.read<RecipesState>();
  final deleted = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => RecipeScreen(recipeId: id)));
  if (deleted ?? false) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.deletedSnack),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => recipes.restore(id),
          ),
        ),
      );
  }
}

/// Asks for a cookbook name (ORG-1: 1–60 characters); null if cancelled.
Future<String?> askCookbookName(
  BuildContext context, {
  String initial = '',
  required String title,
  required String action,
}) {
  final l10n = AppLocalizations.of(context);
  final settings = context.read<SettingsState>();
  final controller = TextEditingController(text: initial);
  final form = GlobalKey<FormState>();
  void submit(BuildContext ctx) {
    if (form.currentState!.validate()) {
      Navigator.pop(ctx, controller.text.trim());
    }
  }

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: form,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          maxLength: Cookbook.maxName,
          buildCounter: digitCounter,
          decoration: InputDecoration(labelText: l10n.cookbookName),
          validator: (v) => (v ?? '').trim().isEmpty
              ? l10n.cookbookNameInvalid(
                  settings.number(1),
                  settings.number(Cookbook.maxName),
                )
              : null,
          onFieldSubmitted: (_) => submit(ctx),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: () => submit(ctx), child: Text(action)),
      ],
    ),
  );
}

/// The cookbooks grid, as slivers (LOOK-8) so [_LibraryHomeState] can
/// splice it after its own header slivers into one [CustomScrollView] —
/// otherwise a non-scrolling header (the greeting, the pill, the backup
/// reminder) stacked above this segment's own content could overflow at a
/// large text scale exactly the way the "all recipes" segment did.
List<Widget> _cookbooksSlivers(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final state = context.watch<RecipesState>();
  final s = context.watch<SettingsState>();
  final gutter = Decor.of(context).gutter;
  Future<void> create() async {
    final name = await askCookbookName(
      context,
      title: l10n.cookbookNew,
      action: l10n.create,
    );
    if (name != null) await state.saveCookbook(name);
  }

  if (state.cookbooks.isEmpty) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          title: l10n.cookbooksEmpty,
          actions: [
            OutlinedButton.icon(
              onPressed: create,
              icon: const Icon(Icons.add),
              label: Text(l10n.cookbookNew),
            ),
          ],
        ),
      ),
    ];
  }

  return [
    SliverPadding(
      // The top gap matches the same `sectionGap` after the header/backup
      // reminder above it; the cookbooks grid has no search row or quick
      // chips of its own to share a delegate with the recipe grid's.
      padding: EdgeInsetsDirectional.fromSTEB(gutter, sectionGap, gutter, 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate((context, i) {
          final c = state.cookbooks[i];
          final count = state.countIn(c.id);
          final covers = state.recipes
              .where((r) => r.cookbookIds.contains(c.id))
              .take(4)
              .toList();
          return _CookbookTile(
            name: c.name,
            subtitle: l10n.cookbookRecipes(count, s.number(count)),
            covers: covers,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CookbookScreen(cookbookId: c.id),
              ),
            ),
          );
        }, childCount: state.cookbooks.length),
      ),
    ),
    SliverPadding(
      padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter, 16),
      sliver: SliverToBoxAdapter(
        child: OutlinedButton.icon(
          onPressed: create,
          icon: const Icon(Icons.add),
          label: Text(l10n.cookbookNew),
        ),
      ),
    ),
  ];
}

/// LOOK-12: a cookbook tile — a 2×2 collage of up to four of its recipes'
/// photos or covers (LOOK-10), the name and the count.
class _CookbookTile extends StatelessWidget {
  const _CookbookTile({
    required this.name,
    required this.subtitle,
    required this.covers,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final List<LibraryEntry> covers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    final radius = decor.photoCardRadius;
    return Semantics(
      button: true,
      label: '$name، $subtitle',
      onTap: onTap,
      child: ExcludeSemantics(
        child: SufraCard(
          radius: radius,
          padding: EdgeInsets.zero,
          // SufraCard's own `onTap` isn't used here (should-fix): the
          // collage below paints an opaque cell over the whole tile, so an
          // `InkWell` under it — where SufraCard's `onTap` puts one — would
          // never show its ripple or its keyboard/switch-access focus
          // highlight. Painted as the Stack's own last child instead,
          // above the collage, the same pattern the recipe grid card uses.
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    // Purely decoration for this tile, whose own semantics
                    // come from the wrapper above.
                    child: ExcludeSemantics(
                      child: covers.isEmpty
                          ? ColoredBox(color: decor.sunk)
                          : _Collage(covers: covers, sunk: decor.sunk),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ContentText(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onTap,
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

/// The cookbook tile's 2×2 collage (should-fix): four fixed cells in a
/// [Column] of two [Row]s, rather than a `GridView.count`, which built a
/// whole scrollable viewport under every tile just to draw four static
/// cells.
class _Collage extends StatelessWidget {
  const _Collage({required this.covers, required this.sunk});
  final List<LibraryEntry> covers;
  final Color sunk;

  Widget _cell(int i) => i < covers.length
      ? RecipePhoto(
          recipeId: covers[i].id,
          title: covers[i].title,
          photoPath: covers[i].photoPath,
        )
      : ColoredBox(color: sunk);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _cell(0)),
            const SizedBox(width: 1),
            Expanded(child: _cell(1)),
          ],
        ),
      ),
      const SizedBox(height: 1),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _cell(2)),
            const SizedBox(width: 1),
            Expanded(child: _cell(3)),
          ],
        ),
      ),
    ],
  );
}

/// One cookbook's recipes, with rename and delete (ORG-1).
class CookbookScreen extends StatelessWidget {
  const CookbookScreen({super.key, required this.cookbookId});
  final String cookbookId;

  Future<void> _menu(BuildContext context, String action) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<RecipesState>();
    final book = state.cookbooks.firstWhere((c) => c.id == cookbookId);
    if (action == 'rename') {
      final name = await askCookbookName(
        context,
        initial: book.name,
        title: l10n.cookbookRename,
        action: l10n.save,
      );
      if (name != null) await state.saveCookbook(name, id: book.id);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cookbookDelete),
        content: Text(l10n.cookbookDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if ((ok ?? false) && context.mounted) {
      Navigator.of(context).pop();
      await state.deleteCookbook(book.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<RecipesState>();
    final book = state.cookbooks.where((c) => c.id == cookbookId).firstOrNull;
    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.recipeMissing)),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: ContentText(book.name),
        actions: [
          // ORG-5: sorting was lost inside a cookbook when the old
          // filter bar's own sort chip moved to the library home's
          // header — this screen never had that header, so it could
          // never sort at all without backing out first.
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: RoundIconButton(
              icon: Icons.sort,
              tooltip: l10n.sortBy,
              onPressed: () => openSortSheet(context),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _menu(context, v),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(l10n.cookbookRename)),
              PopupMenuItem(value: 'delete', child: Text(l10n.cookbookDelete)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openEditor(context, cookbookId: cookbookId),
        icon: const Icon(Icons.add),
        label: Text(l10n.recipesAdd),
      ),
      // ADS-9: a pushed screen (LOOK-7 gives it no navigation pill) still
      // carries its own banner, "aboveSystemBar" like the recipe page's.
      bottomNavigationBar: const AdSlot(aboveSystemBar: true),
      body: LibraryView(cookbookId: cookbookId),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => EmptyState(
    title: l10n.recipesEmptyTitle,
    body: l10n.recipesEmptyBody,
    // RUN-1, LOOK-7: one clear first action, the same "أضف وصفة" the
    // pill's centre "+" carries — it opens the same add sheet (LOOK-11).
    actions: [
      FilledButton.icon(
        onPressed: () => showAddSheet(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.recipesAdd),
      ),
    ],
  );
}
