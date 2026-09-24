import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/cookbook.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../services/backup.dart';
import '../widgets/ad_slot.dart';
import '../widgets/content_direction.dart';
import '../widgets/empty_state.dart';
import '../widgets/pressable_slab.dart';
import 'groceries_screen.dart';
import 'import_screen.dart';
import 'library_view.dart';
import 'plan_screen.dart';
import 'recipe_editor_screen.dart';
import 'recipe_screen.dart';
import 'settings_screen.dart';

/// The app's three places: the library, the meal plan (PLAN-1) and
/// groceries (GRO-5). An empty library keeps the first run to one screen
/// and one action (RUN-1), so the navigation bar appears only once there's
/// a recipe.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<RecipesState>();
    if (!state.loaded || state.recipes.isEmpty) return const LibraryHome();
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [LibraryHome(), PlanScreen(), GroceriesScreen()],
      ),
      // ADS-3, ADS-9: the library, the plan and groceries share one slot,
      // in the bottom bar above the navigation bar, outside every tab's
      // scrolling content. An empty library has neither (RUN-1): its whole
      // screen is the one first action.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdSlot(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: l10n.tabRecipes,
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                selectedIcon: const Icon(Icons.calendar_month),
                label: l10n.planTitle,
              ),
              NavigationDestination(
                icon: const Icon(Icons.shopping_basket_outlined),
                selectedIcon: const Icon(Icons.shopping_basket),
                label: l10n.groceriesTitle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The library: "All recipes" and "Cookbooks" (ORG-1). An empty library
/// explains itself with one action (RUN-1).
class LibraryHome extends StatelessWidget {
  const LibraryHome({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<RecipesState>();
    final empty = state.loaded && state.recipes.isEmpty;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
          actions: [
            IconButton(
              tooltip: l10n.importTitle,
              icon: const Icon(Icons.link),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ImportScreen())),
            ),
            IconButton(
              tooltip: l10n.settings,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
          bottom: empty
              ? null
              : TabBar(
                  tabs: [
                    Tab(text: l10n.tabAllRecipes),
                    Tab(text: l10n.tabCookbooks),
                  ],
                ),
        ),
        floatingActionButton: empty
            ? null
            // LOOK-7: "أضف وصفة" is one of Saffron's three ledge actions; a
            // no-op in Ink (Decor.ledgeDepth 0).
            : PressableSlab(
                child: FloatingActionButton.extended(
                  onPressed: () => openEditor(context),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.recipesAdd),
                ),
              ),
        body: !state.loaded
            ? const Center(child: CircularProgressIndicator())
            : empty
            ? _Empty(l10n: l10n)
            : const Column(
                children: [
                  _BackupReminderCard(),
                  Expanded(
                    child: TabBarView(
                      children: [LibraryView(), _CookbooksTab()],
                    ),
                  ),
                ],
              ),
      ),
    );
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

    return Card(
      margin: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
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
          decoration: InputDecoration(labelText: l10n.cookbookName),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? l10n.cookbookNameInvalid : null,
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

class _CookbooksTab extends StatelessWidget {
  const _CookbooksTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<RecipesState>();
    final s = context.watch<SettingsState>();
    Future<void> create() async {
      final name = await askCookbookName(
        context,
        title: l10n.cookbookNew,
        action: l10n.create,
      );
      if (name != null) await state.saveCookbook(name);
    }

    if (state.cookbooks.isEmpty) {
      return EmptyState(
        title: l10n.cookbooksEmpty,
        actions: [
          OutlinedButton.icon(
            onPressed: create,
            icon: const Icon(Icons.add),
            label: Text(l10n.cookbookNew),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsetsDirectional.only(bottom: 96),
      children: [
        for (final c in state.cookbooks)
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: ContentText(c.name),
            subtitle: Text(
              l10n.cookbookRecipes(
                state.countIn(c.id),
                s.number(state.countIn(c.id)),
              ),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CookbookScreen(cookbookId: c.id),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: OutlinedButton.icon(
            onPressed: create,
            icon: const Icon(Icons.add),
            label: Text(l10n.cookbookNew),
          ),
        ),
      ],
    );
  }
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
    actions: [
      // LOOK-7: "أضف وصفة" is one of Saffron's three ledge actions; a
      // no-op in Ink (Decor.ledgeDepth 0).
      PressableSlab(
        child: FilledButton.icon(
          onPressed: () => openEditor(context),
          icon: const Icon(Icons.add),
          label: Text(l10n.recipesAdd),
        ),
      ),
      OutlinedButton.icon(
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ImportScreen())),
        icon: const Icon(Icons.link),
        label: Text(l10n.importTitle),
      ),
    ],
  );
}
