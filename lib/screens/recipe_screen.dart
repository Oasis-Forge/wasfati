import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/recipe.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../widgets/content_direction.dart';
import '../models/quantity/rational.dart';
import 'ingredients_section.dart';
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
