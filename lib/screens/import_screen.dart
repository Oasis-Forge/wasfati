import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/recipe.dart';
import '../services/importer.dart';
import '../services/web_import.dart';
import 'home_screen.dart';
import 'recipe_editor_screen.dart';

/// Import from a link (IMP-2): read on the device, free and unlimited.
/// Shows progress (IMP-4), checks for a duplicate (IMP-9), then opens the
/// preview, where nothing is saved until the user taps Save (IMP-5).
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, this.initialUrl});

  /// A shared link: the import starts at once.
  final String? initialUrl;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

enum _Stage { idle, reading, understanding }

class _ImportScreenState extends State<ImportScreen> {
  late final _link = TextEditingController(text: widget.initialUrl ?? '');
  _Stage _stage = _Stage.idle;
  ImportFailure? _failure;
  int _run = 0; // a cancelled run's result is ignored (IMP-4)

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _import());
    }
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    // Reads the clipboard only when the user taps Paste (IMP-12).
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) _link.text = data!.text!.trim();
  }

  Future<void> _import() async {
    final importer = context.read<Importer>();
    final url = _link.text.trim();
    final run = ++_run;
    setState(() {
      _failure = null;
      _stage = _Stage.reading;
    });

    final dup = await importer.duplicateOf(url);
    if (!mounted || run != _run) return;
    if (dup != null && !await _importAnyway(dup)) return;
    if (!mounted || run != _run) return;

    Recipe draft;
    try {
      setState(() => _stage = _Stage.understanding);
      draft = await importer.fromUrl(url);
    } on ImportException catch (e) {
      if (mounted && run == _run) {
        setState(() {
          _stage = _Stage.idle;
          _failure = e.failure;
        });
      }
      return;
    }
    if (!mounted || run != _run) return;
    setState(() => _stage = _Stage.idle);
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RecipeEditorScreen(recipe: draft, imported: true),
      ),
    );
    if (saved != null && mounted) {
      Navigator.of(context).pop();
      await openRecipe(context, saved);
    }
  }

  /// IMP-9: "Open the saved one / Import again".
  Future<bool> _importAnyway(String savedId) async {
    final l10n = AppLocalizations.of(context);
    final again = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.duplicateTitle),
        content: Text(l10n.duplicateBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.openSaved),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.importAgain),
          ),
        ],
      ),
    );
    if (again ?? false) return true;
    if (!mounted) return false;
    setState(() => _stage = _Stage.idle);
    if (again == false) {
      Navigator.of(context).pop();
      await openRecipe(context, savedId);
    }
    return false;
  }

  void _cancel() => setState(() {
    _run++;
    _stage = _Stage.idle;
  });

  Future<void> _addByHand() async {
    final importer = context.read<Importer>();
    final draft = importer.fromText('');
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RecipeEditorScreen(
          recipe: draft.copyWith(
            sourceUrl: _link.text.trim(),
            sourceType: SourceType.website,
          ),
          imported: true,
        ),
      ),
    );
    if (saved != null && mounted) {
      Navigator.of(context).pop();
      await openRecipe(context, saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = _stage != _Stage.idle;
    final message = switch (_failure) {
      ImportFailure.invalidUrl => l10n.importInvalidUrl,
      ImportFailure.unreachable => l10n.importUnreachable,
      ImportFailure.noRecipe => l10n.importNoRecipe,
      null => null,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          TextField(
            controller: _link,
            enabled: !busy,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr, // links read left to right
            decoration: InputDecoration(
              labelText: l10n.importHint,
              suffixIcon: IconButton(
                tooltip: l10n.paste,
                icon: const Icon(Icons.content_paste),
                onPressed: busy ? null : _paste,
              ),
            ),
            onSubmitted: (_) => busy ? null : _import(),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.importExplain,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (!busy)
            FilledButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.download),
              label: Text(l10n.importAction),
            )
          else ...[
            LinearProgressIndicator(
              value: _stage == _Stage.reading ? 0.33 : 0.66,
            ),
            const SizedBox(height: 8),
            Text(
              _stage == _Stage.reading
                  ? l10n.importReading
                  : l10n.importUnderstanding,
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _cancel, child: Text(l10n.cancel)),
          ],
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (_failure == ImportFailure.noRecipe)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: OutlinedButton(
                  onPressed: _addByHand,
                  child: Text(l10n.addByHand),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
