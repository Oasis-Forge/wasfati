import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/cookbook.dart';
import '../models/library.dart';
import '../models/quantity/arabic_text.dart';
import '../models/quantity/convert.dart' show UnitView;
import '../models/recipe.dart';
import '../models/recipe_text.dart';
import '../models/recipe_translation.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../services/mail.dart';
import '../services/photo_store.dart';
import '../theme/decor.dart';
import '../widgets/content_direction.dart';
import '../widgets/digit_counter.dart';
import '../widgets/sufra_card.dart';
import 'translate_flow.dart';

/// Adds or edits a recipe (REC-3–REC-8). Ingredients and steps are one line
/// each; a line ending with ":" starts a group (REC-4, REC-6). Pops the saved
/// recipe's ID. No ads here (principle 4).
class RecipeEditorScreen extends StatefulWidget {
  const RecipeEditorScreen({
    super.key,
    this.recipe,
    this.initialCookbookId,
    this.imported = false,
    this.usedAiImport = false,
    this.translation = false,
  });
  final Recipe? recipe;

  /// A new recipe started from a cookbook goes into it (ORG-1).
  final String? initialCookbookId;

  /// [recipe] is an unsaved import: this is its preview (IMP-5). Leaving
  /// asks first, and a discarded import's downloaded photo is deleted.
  final bool imported;

  /// [recipe] came from `Importer.fromAi` (IMP-3): saving it is what spends
  /// the AI quota (IMP-7) — never a cancelled preview, and never a website
  /// or by-hand import, which cost nothing.
  final bool usedAiImport;

  /// [recipe] is a translated copy (IMP-14): it offers no second
  /// translation.
  final bool translation;

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final String _id;
  late final TextEditingController _title, _servings, _prep, _cook;
  late final TextEditingController _ingredients, _steps, _notes, _tags;
  late Set<String> _cookbooks;
  String? _photo;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _id = r?.id ?? context.read<RecipesState>().repository.newId();
    // The user's digits (QTY-5, LANG-3); the fields read both styles back.
    final settings = context.read<SettingsState>();
    String n(int? v) => v == null ? '' : settings.number(v);
    _title = TextEditingController(text: r?.title ?? '');
    _servings = TextEditingController(text: n(r?.servings));
    _prep = TextEditingController(text: n(r?.prepMinutes));
    _cook = TextEditingController(text: n(r?.cookMinutes));
    _ingredients = TextEditingController(
      text: r == null ? '' : ingredientsToText(r.ingredients),
    );
    _steps = TextEditingController(text: r == null ? '' : stepsToText(r.steps));
    _notes = TextEditingController(text: r?.notes ?? '');
    final tags = r?.tags ?? const <String>[];
    _tags = TextEditingController(text: tags.join(tagSeparator(tags)));
    _cookbooks = {
      ...?r?.cookbookIds,
      if (r == null && widget.initialCookbookId != null)
        widget.initialCookbookId!,
    };
    _photo = r?.photoPath;
    for (final c in _controllers) {
      c.addListener(_markDirty);
    }
    _dirty = widget.imported;
  }

  List<TextEditingController> get _controllers => [
    _title,
    _servings,
    _prep,
    _cook,
    _ingredients,
    _steps,
    _notes,
    _tags,
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

  /// The recipe exactly as the form now shows it.
  Recipe _fromForm() {
    final state = context.read<RecipesState>();
    final repo = state.repository;
    final before = widget.recipe;
    final now = repo.now();
    final notes = _notes.text.trim();
    return Recipe(
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
      cookbookIds: [
        for (final c in state.cookbooks)
          if (_cookbooks.contains(c.id)) c.id,
      ],
      tags: parseTags(_tags.text),
      // SCALE-5: the remembered view survives an edit; IMP-14: so does a
      // translated copy's link to its original.
      unitView: before?.unitView ?? UnitView.asWritten,
      translatedFrom: before?.translatedFrom,
      createdAt: before?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _save() async {
    // A second tap before the first save's own async work settles must be
    // a no-op: the button's disabled look (below) only takes effect once
    // Flutter rebuilds, which a same-frame double tap can outrun
    // (should-fix, review) — this guard is checked on entry, not the UI.
    if (_saving) return;
    if (!_form.currentState!.validate()) return;
    final state = context.read<RecipesState>();
    final before = widget.recipe;
    final recipe = _fromForm();
    setState(() => _saving = true);
    final saved = await state.save(recipe);
    if (!mounted) return;
    if (saved == null) {
      setState(() => _saving = false);
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
    if (!mounted) return;
    // IMP-7: only the save path spends the quota, and only for an AI
    // import — never a cancelled preview, and never website or by-hand.
    // _saving stays true (the Save button disabled) through this whole
    // tail: a double-tap before the upsert settles must never record the
    // AI quota twice for the one recipe it saves (should-fix, review).
    if (widget.usedAiImport) {
      await context.read<SettingsState>().recordAiImportSaved();
    }
    if (mounted) Navigator.of(context).pop(saved.id);
  }

  /// IMP-14, IMP-16: translates the preview as it now reads. Inside an AI
  /// import's preview it's part of that import and costs nothing more;
  /// otherwise the cost line shows first. When the translated copy is
  /// saved, it's saved instead of this import: this draft is discarded,
  /// with its photo, and closes onto the copy.
  Future<void> _translate() async {
    if (!_form.currentState!.validate()) return;
    final photos = context.read<PhotoStore>();
    final saved = await translateAndPreview(
      context,
      _fromForm(),
      free: widget.usedAiImport,
      linkToOriginal: false,
    );
    if (saved == null || !mounted) return;
    for (final path in {widget.recipe?.photoPath, _photo}.nonNulls) {
      await photos.delete(path);
    }
    if (mounted) Navigator.of(context).pop(saved);
  }

  /// IMP-8, Decision 19: an optional note, then the user's own mail app
  /// with a draft to [supportEmail] holding only the import's source link
  /// (none for a photo or pasted text) and that note. The recipe, its
  /// photos and any caption never go in it, nothing goes through our
  /// server, and the user reads the draft and sends it themselves.
  Future<void> _reportMistake() async {
    final l10n = AppLocalizations.of(context);
    final mail = context.read<MailComposer>();
    final messenger = ScaffoldMessenger.of(context);
    final link = widget.recipe?.sourceUrl;
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReportMistakeDialog(hasLink: link != null),
    );
    if (note == null) return; // cancelled: nothing opens
    final opened = await mail.compose(
      to: supportEmail,
      subject: l10n.reportMistakeSubject,
      body: mistakeReportBody(sourceUrl: link, note: note),
    );
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.reportMistakeNoMailApp(supportEmail))),
      );
    }
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
    final settings = context.watch<SettingsState>();
    final gutter = Decor.of(context).gutter;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          final photo = widget.recipe?.photoPath;
          if (widget.imported && photo != null) {
            await context.read<PhotoStore>().delete(photo);
          }
          if (!context.mounted) return;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.imported
                ? l10n.importedRecipe
                : widget.recipe == null
                ? l10n.newRecipe
                : l10n.editRecipe,
          ),
          actions: [
            Padding(
              // should-fix, LOOK-6: the theme's FilledButton is sized for
              // a screen's one main action at the bottom (56dp) — inside
              // a 64dp toolbar that reads as an oversized blob at the
              // screen edge rather than an app-bar action.
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 44),
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 20,
                  ),
                ),
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
        body: Form(
          key: _form,
          // LOOK-6/Decision 23: the same fields, in the same order, grouped
          // into SufraCard sections instead of one flat field-by-field
          // list — restyled, never re-laid-out (no field moves, gains a
          // validator or drops one).
          child: ListView(
            padding: EdgeInsetsDirectional.fromSTEB(gutter, 8, gutter, 32),
            children: [
              SufraCard(
                padding: const EdgeInsetsDirectional.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _title,
                      maxLength: Recipe.maxTitle,
                      buildCounter: digitCounter,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: l10n.fieldTitle),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? l10n.fieldTitleRequired
                          : null,
                    ),
                    _PhotoRow(
                      path: _photo,
                      onPick: _pickPhoto,
                      onRemove: () => setState(() {
                        _photo = null;
                        _dirty = true;
                      }),
                    ),
                    // IMP-14: an import written mostly in another language.
                    if (widget.imported &&
                        !widget.translation &&
                        widget.recipe != null &&
                        offersTranslation(
                          widget.recipe!,
                          arabicApp:
                              Localizations.localeOf(context).languageCode ==
                              'ar',
                        ))
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: _saving ? null : _translate,
                          icon: const Icon(Icons.translate),
                          label: Text(l10n.translateRecipe),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SufraCard(
                // should-fix, LANG-6: the card's usual 16dp horizontal
                // padding, on both sides of every gap between three equal
                // fields, left too little width for their own floating
                // labels at a large text scale (some clipped even at
                // 1.0x) — a narrower horizontal inset for this one row
                // gives each field back the width the card's padding was
                // taking from it.
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _NumberField(
                        controller: _servings,
                        label: l10n.fieldServings,
                        validator: (n) =>
                            n != null && (n < 1 || n > Recipe.maxServings)
                            ? l10n.fieldServingsInvalid(
                                settings.number(1),
                                settings.number(Recipe.maxServings),
                              )
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
              ),
              const SizedBox(height: 16),
              SufraCard(
                padding: const EdgeInsetsDirectional.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _ingredients,
                      minLines: 5,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        labelText: l10n.ingredients,
                        // The example is an ingredient line: an English one
                        // keeps 123 whatever the setting, an Arabic one
                        // follows it (QTY-5).
                        hintText: l10n.fieldIngredientsHint(
                          l10n.localeName == 'ar' ? settings.number(2) : '2',
                        ),
                        hintMaxLines: 3,
                        alignLabelWithHint: true,
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
                      ),
                      validator: (v) =>
                          (v ?? '')
                              .split('\n')
                              .any(
                                (l) => l.trim().length > RecipeStep.maxLength,
                              )
                          ? l10n.stepTooLong(
                              settings.number(RecipeStep.maxLength),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SufraCard(
                padding: const EdgeInsetsDirectional.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _tags,
                      decoration: InputDecoration(
                        labelText: l10n.fieldTags,
                        hintText: l10n.fieldTagsHint,
                      ),
                      validator: (v) {
                        final tags = parseTags(v ?? '');
                        return tags.length > Tag.maxPerRecipe ||
                                tags.any((t) => t.length > Tag.maxName)
                            ? l10n.tagsInvalid(
                                settings.number(Tag.maxPerRecipe),
                                settings.number(Tag.maxName),
                              )
                            : null;
                      },
                    ),
                    _TagSuggestions(controller: _tags),
                    _CookbookPicker(
                      selected: _cookbooks,
                      onChanged: (id, on) => setState(() {
                        on ? _cookbooks.add(id) : _cookbooks.remove(id);
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SufraCard(
                padding: const EdgeInsetsDirectional.all(16),
                child: TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: null,
                  decoration: InputDecoration(
                    labelText: l10n.notes,
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              // IMP-5, IMP-8: a quiet action, last in the preview.
              if (widget.imported) ...[
                const SizedBox(height: 24),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _reportMistake,
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(l10n.reportMistake),
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

/// IMP-8: says exactly what the mail will hold, takes an optional note, and
/// pops that note on Send (null on Cancel).
class _ReportMistakeDialog extends StatefulWidget {
  const _ReportMistakeDialog({required this.hasLink});

  /// Whether the import has a source link to include (a photo or pasted
  /// text has none).
  final bool hasLink;

  @override
  State<_ReportMistakeDialog> createState() => _ReportMistakeDialogState();
}

class _ReportMistakeDialogState extends State<_ReportMistakeDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.reportMistake),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.hasLink
                  ? l10n.reportMistakeExplainLink
                  : l10n.reportMistakeExplainNoLink,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(hintText: l10n.reportMistakeNoteHint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _note.text),
          child: Text(l10n.reportMistakeSend),
        ),
      ],
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
      // should-fix, LANG-6: three equal fields in a row leave each label
      // little width, and an Arabic label ("التحضير (دقيقة)") or "Prep
      // (min)"/"Cook (min)" at a large text scale can need more of it than
      // there is — a `Text` label (rather than `labelText`) can wrap to a
      // second line instead of the floating label silently ellipsizing.
      decoration: InputDecoration(label: Text(label, maxLines: 2)),
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
            child: ClipPath(
              // LOOK-6: the same shape as a library thumbnail (Decor).
              clipper: ShapeBorderClipper(
                shape: Decor.of(context).thumbnailShape,
                textDirection: Directionality.of(context),
              ),
              child: Image.file(
                File(path!),
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                // BAK-9: no photo file (Android's own device backup carries
                // the database but not photos) shows nothing, never a
                // broken image.
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 64,
                  height: 64,
                  child: Icon(Icons.restaurant_outlined),
                ),
              ),
            ),
          ),
        // Wraps under itself on a phone: next to a photo, both buttons don't
        // fit on one 360 dp line (an imported photo, IMP-10).
        Expanded(
          child: Wrap(
            children: [
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
          ),
        ),
      ],
    );
  }
}

/// Tags already in use, one tap to add (ORG-2).
class _TagSuggestions extends StatelessWidget {
  const _TagSuggestions({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final all = context.watch<RecipesState>().tags;
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        final have = parseTags(value.text).map(normalizeArabic).toSet();
        final left = all
            .where((t) => !have.contains(normalizeArabic(t)))
            .take(8)
            .toList();
        if (left.isEmpty) return const SizedBox(height: 8);
        return Padding(
          padding: const EdgeInsetsDirectional.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final t in left)
                ActionChip(
                  label: ContentText(t),
                  onPressed: () {
                    final text = value.text.trim();
                    controller.text = text.isEmpty
                        ? t
                        : '$text${tagSeparator([text, t])}$t';
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Which cookbooks the recipe is in, any number (ORG-1).
class _CookbookPicker extends StatelessWidget {
  const _CookbookPicker({required this.selected, required this.onChanged});
  final Set<String> selected;
  final void Function(String id, bool on) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final List<Cookbook> books = context.watch<RecipesState>().cookbooks;
    if (books.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.fieldCookbooks,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in books)
                FilterChip(
                  label: ContentText(c.name),
                  selected: selected.contains(c.id),
                  onSelected: (on) => onChanged(c.id, on),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
