import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/quantity/format.dart';
import '../models/recipe.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../models/quantity/arabic_text.dart';
import '../widgets/content_direction.dart';
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
  late Future<Recipe?> _recipe = _load();

  Future<Recipe?> _load() =>
      context.read<RecipesState>().repository.get(widget.recipeId);

  Future<void> _edit(Recipe r) async {
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => RecipeEditorScreen(recipe: r)),
    );
    if (saved != null) setState(() => _recipe = _load());
  }

  Future<void> _delete(Recipe r) async {
    final ok = await context.read<RecipesState>().delete(r.id); // DEL-1
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<Recipe?>(
      future: _recipe,
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
              : _RecipeBody(r),
        );
      },
    );
  }
}

class _RecipeBody extends StatelessWidget {
  const _RecipeBody(this.r);
  final Recipe r;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final text = Theme.of(context).textTheme;
    final facts = <String>[
      if (r.prepMinutes != null)
        '${l10n.prepTime} ${l10n.minutes(r.prepMinutes!, s.number(r.prepMinutes!))}',
      if (r.cookMinutes != null)
        '${l10n.cookTime} ${l10n.minutes(r.cookMinutes!, s.number(r.cookMinutes!))}',
      if (r.servings != null) l10n.servings(r.servings!, s.number(r.servings!)),
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
        if (r.ingredients.isNotEmpty) ...[
          _Heading(l10n.ingredients),
          for (final section in r.ingredients) ...[
            if (section.name != null) _GroupName(section.name!),
            for (final line in section.items)
              _IngredientRow(line, digits: s.digits),
          ],
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
      if (section.name != null) rows.add(_GroupName(section.name!));
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

/// An ingredient line as parsed (QTY-5, QTY-6): the amount in the chosen
/// digits, isolated left-to-right inside Arabic text. A line with no amount
/// shows its original text (QTY-2).
class _IngredientRow extends StatelessWidget {
  const _IngredientRow(this.line, {required this.digits});
  final IngredientLine line;
  final DigitStyle digits;

  @override
  Widget build(BuildContext context) {
    final shown = line.min == null
        ? line.original
        : formatLine(
            line.parsed,
            arabic: hasArabic(line.original),
            digits: digits,
            isolate: true,
          );
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(top: 9, end: 12),
            child: Icon(Icons.circle, size: 6),
          ),
          Expanded(
            child: ContentText(
              shown,
              source: line.original,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
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

class _GroupName extends StatelessWidget {
  const _GroupName(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 12, bottom: 4),
    child: ContentText(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
