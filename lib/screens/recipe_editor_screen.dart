import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/quantity/arabic_text.dart';
import '../models/recipe.dart';
import '../models/recipe_text.dart';
import '../providers/recipes_state.dart';
import '../services/photo_store.dart';

/// Adds or edits a recipe (REC-3–REC-8). Ingredients and steps are one line
/// each; a line ending with ":" starts a group (REC-4, REC-6). Pops the saved
/// recipe's ID. No ads here (principle 4).
class RecipeEditorScreen extends StatefulWidget {
  const RecipeEditorScreen({super.key, this.recipe});
  final Recipe? recipe;

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final String _id;
  late final TextEditingController _title, _servings, _prep, _cook;
  late final TextEditingController _ingredients, _steps, _notes;
  String? _photo;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _id = r?.id ?? context.read<RecipesState>().repository.newId();
    String n(int? v) => v == null ? '' : '$v';
    _title = TextEditingController(text: r?.title ?? '');
    _servings = TextEditingController(text: n(r?.servings));
    _prep = TextEditingController(text: n(r?.prepMinutes));
    _cook = TextEditingController(text: n(r?.cookMinutes));
    _ingredients = TextEditingController(
      text: r == null ? '' : ingredientsToText(r.ingredients),
    );
    _steps = TextEditingController(text: r == null ? '' : stepsToText(r.steps));
    _notes = TextEditingController(text: r?.notes ?? '');
    _photo = r?.photoPath;
    for (final c in _controllers) {
      c.addListener(_markDirty);
    }
  }

  List<TextEditingController> get _controllers => [
    _title,
    _servings,
    _prep,
    _cook,
    _ingredients,
    _steps,
    _notes,
  ];

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Reads a whole number in either digit style; null when empty.
  static int? _int(String text) {
    final t = westernDigits(text.trim());
    return t.isEmpty ? null : int.tryParse(t);
  }

  Future<void> _pickPhoto() async {
    final path = await context.read<PhotoStore>().pickFromGallery(_id);
    if (path != null) {
      setState(() {
        _photo = path;
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final state = context.read<RecipesState>();
    final repo = state.repository;
    final before = widget.recipe;
    final now = repo.now();
    final notes = _notes.text.trim();
    final recipe = Recipe(
      id: _id,
      title: _title.text.trim(),
      photoPath: _photo,
      sourceUrl: before?.sourceUrl,
      sourceType: before?.sourceType ?? SourceType.written,
      servings: _int(_servings.text),
      prepMinutes: _int(_prep.text),
      cookMinutes: _int(_cook.text),
      notes: notes.isEmpty ? null : notes,
      rating: before?.rating,
      cookedCount: before?.cookedCount ?? 0,
      lastCookedAt: before?.lastCookedAt,
      ingredients: ingredientsFromText(
        _ingredients.text,
        before?.ingredients ?? const [],
        repo.newId,
      ),
      steps: stepsFromText(_steps.text, before?.steps ?? const [], repo.newId),
      createdAt: before?.createdAt ?? now,
      updatedAt: now,
    );
    setState(() => _saving = true);
    final saved = await state.save(recipe);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorSaveFailed)),
      );
      return;
    }
    // A replaced photo is deleted once the new one is saved (REC-8).
    final old = before?.photoPath;
    if (old != null && old != _photo) {
      await context.read<PhotoStore>().delete(old);
    }
    if (mounted) Navigator.of(context).pop(saved.id);
  }

  Future<bool> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.discardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.keepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.recipe == null ? l10n.newRecipe : l10n.editRecipe),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
            children: [
              TextFormField(
                controller: _title,
                maxLength: Recipe.maxTitle,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.fieldTitle),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.fieldTitleRequired : null,
              ),
              _PhotoRow(
                path: _photo,
                onPick: _pickPhoto,
                onRemove: () => setState(() {
                  _photo = null;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _NumberField(
                      controller: _servings,
                      label: l10n.fieldServings,
                      validator: (n) =>
                          n != null && (n < 1 || n > Recipe.maxServings)
                          ? l10n.fieldServingsInvalid
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NumberField(
                      controller: _prep,
                      label: l10n.fieldPrep,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NumberField(
                      controller: _cook,
                      label: l10n.fieldCook,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ingredients,
                minLines: 5,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: l10n.ingredients,
                  hintText: l10n.fieldIngredientsHint,
                  hintMaxLines: 3,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _steps,
                minLines: 5,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: l10n.steps,
                  hintText: l10n.fieldStepsHint,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '')
                        .split('\n')
                        .any((l) => l.trim().length > RecipeStep.maxLength)
                    ? l10n.stepTooLong
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: null,
                decoration: InputDecoration(
                  labelText: l10n.notes,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(int?)? validator;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final t = westernDigits((v ?? '').trim());
        if (t.isEmpty) return null;
        final n = int.tryParse(t);
        if (n == null || n < 0) return l10n.fieldNumberInvalid;
        return validator?.call(n);
      },
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.path,
    required this.onPick,
    required this.onRemove,
  });

  final String? path;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        if (path != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(path!),
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
              ),
            ),
          ),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(l10n.photoAdd),
        ),
        if (path != null)
          TextButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.photoRemove),
          ),
      ],
    );
  }
}
