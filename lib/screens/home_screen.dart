import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/recipe_repository.dart';
import '../l10n/app_localizations.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../widgets/content_direction.dart';
import 'recipe_editor_screen.dart';
import 'recipe_screen.dart';
import 'settings_screen.dart';

/// The recipe library, newest first (ORG-5). Search, sort, grid and
/// cookbooks come with the next PR (ORG-1–ORG-7).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<RecipesState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: state.recipes.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => openEditor(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.recipesAdd),
            ),
      body: !state.loaded
          ? const Center(child: CircularProgressIndicator())
          : state.recipes.isEmpty
          ? _Empty(l10n: l10n)
          : ListView.separated(
              padding: const EdgeInsetsDirectional.only(bottom: 96),
              itemCount: state.recipes.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _RecipeTile(state.recipes[i]),
            ),
    );
  }
}

/// Opens the editor for a new recipe, then the saved recipe's page.
Future<void> openEditor(BuildContext context) async {
  final id = await Navigator.of(
    context,
  ).push<String>(MaterialPageRoute(builder: (_) => const RecipeEditorScreen()));
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

class _RecipeTile extends StatelessWidget {
  const _RecipeTile(this.recipe);
  final RecipeSummary recipe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final minutes = recipe.totalMinutes;
    return ListTile(
      leading: _Thumb(recipe.photoPath),
      title: ContentText(
        recipe.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: minutes == null
          ? null
          : Text(l10n.minutes(minutes, s.number(minutes))),
      onTap: () => openRecipe(context, recipe.id),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb(this.path);
  final String? path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: 56,
        child: path == null
            ? ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  Icons.restaurant_outlined,
                  color: scheme.onSecondaryContainer,
                ),
              )
            : Image.file(
                File(path!),
                fit: BoxFit.cover,
                cacheWidth: 168,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.recipesEmptyTitle,
              style: text.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.recipesEmptyBody,
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => openEditor(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.recipesAdd),
            ),
          ],
        ),
      ),
    );
  }
}
