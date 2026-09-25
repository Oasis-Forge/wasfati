import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/recipe.dart';
import '../models/recipe_import.dart' show normalizeSourceUrl;
import '../providers/purchases_state.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../services/ai_import.dart';
import '../services/import_photos.dart';
import '../services/importer.dart';
import '../services/photo_store.dart';
import '../services/web_import.dart';
import '../theme/decor.dart';
import 'home_screen.dart';
import 'purchase_screen.dart';
import 'recipe_editor_screen.dart';

/// Import from a link (IMP-2), shared/pasted text (IMP-3) or photos
/// (IMP-1, IMP-10): a link is read on the device first, free and unlimited;
/// when that fails for any reason but an invalid link, or for plain text or
/// photos, it goes to the AI server instead (IMP-1, IMP-3). Shows progress
/// (IMP-4), checks for a duplicate (IMP-9), then opens the preview, where
/// nothing is saved — and no AI quota spent — until the user taps Save
/// (IMP-5, IMP-7).
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, this.initialUrl, this.initialText});

  /// A shared or pasted link: the import starts at once.
  final String? initialUrl;

  /// Shared or pasted text with no link (IMP-1): goes to AI import at once
  /// (IMP-3). `Importer.fromText`'s offline heuristic is only the fallback,
  /// offered as "أضفها بنفسك" if that fails.
  final String? initialText;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

enum _Stage { idle, reading, understanding, aiConfirm, aiSending }

/// IMP-4: past this long in [_Stage.aiSending], the progress block offers
/// "Keep waiting" or "Cancel" instead of just sitting on an indeterminate
/// bar until [DeviceAiImportClient]'s own 60 s timeout.
const _keepWaitingAfter = Duration(seconds: 45);

class _ImportScreenState extends State<ImportScreen> {
  late final _link = TextEditingController(text: widget.initialUrl ?? '');
  final _caption = TextEditingController();
  _Stage _stage = _Stage.idle;
  ImportFailure? _failure;
  AiImportErrorKind? _aiError;
  bool _outOfQuota = false;

  /// IMP-7, PAY-7: AI imports left this month, out of the quota the store's
  /// entitlements give (100 with Premium, 10 otherwise).
  int _aiImportsLeft(SettingsState settings) => settings.aiImportsLeft(
    quota: context.read<PurchasesState>().aiImportQuota,
  );

  /// Set once an AI attempt for a link comes back `unreachable` or
  /// `private_post` (IMP-12): the original link, kept so a pasted caption
  /// still saves with it as the source (IMP-9).
  String? _unreadableLink;

  /// Why the paste-caption fallback is showing (IMP-12) — separate from
  /// [_aiError], which a failed *retry* of the caption itself (e.g. a
  /// dropped connection) goes on to overwrite. Kept so the fallback box
  /// stays on screen, with its own reason line unchanged, through a caption
  /// send that fails for some other reason (should-fix, review).
  AiImportErrorKind? _captionFallbackReason;

  /// The plain text last sent to AI (a share or a paste), kept only so
  /// "أضفها بنفسك" can fall back to the offline heuristic on failure.
  String? _lastText;

  /// IMP-3: text shared in with no user action at all (unlike a typed
  /// link or a pasted caption, where tapping "استيراد" is itself the
  /// decision) waits here for [_Stage.aiConfirm] until the user actually
  /// chooses to spend an AI import.
  String? _pendingAiText;

  /// IMP-1, IMP-10: picked photos waiting at [_Stage.aiConfirm], like
  /// [_pendingAiText], until the user chooses to spend an AI import.
  List<Uint8List>? _pendingPhotos;

  /// [_pendingPhotos] came from the camera, one page at a time, so the
  /// confirm step offers "أضف صفحة" for the next one.
  bool _photosFromCamera = false;

  /// The last AI attempt sent photos: "أضفها بنفسك" then starts a blank
  /// photo-sourced draft, not one tagged with whatever the link field holds.
  bool _lastWasPhotos = false;

  /// IMP-4: shown once [_keepWaitingAfter] passes during [_Stage.aiSending].
  bool _showKeepWaiting = false;
  Timer? _keepWaitingTimer;

  int _run = 0; // a cancelled run's result is ignored (IMP-4)

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _import());
    } else if (widget.initialText != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _confirmAiSend(widget.initialText!),
      );
    }
  }

  @override
  void dispose() {
    _keepWaitingTimer?.cancel();
    _link.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    // Reads the clipboard only when the user taps Paste (IMP-12).
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) _link.text = data!.text!.trim();
  }

  Future<void> _pasteCaption() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) _caption.text = data!.text!.trim();
  }

  /// IMP-12, SRV-10: both the unreachable-link case and any platform the
  /// server flags `private_post` (Instagram always, per Decision 8) land on
  /// the same paste-caption fallback.
  static bool _showsCaptionFallback(AiImportErrorKind kind) =>
      kind == AiImportErrorKind.unreachable ||
      kind == AiImportErrorKind.privatePost;

  Future<void> _import() async {
    final importer = context.read<Importer>();
    final url = _link.text.trim();
    final run = ++_run;
    setState(() {
      _failure = null;
      _aiError = null;
      _outOfQuota = false;
      _unreadableLink = null;
      _captionFallbackReason = null;
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
      if (!mounted || run != _run) return;
      if (!needsAiImport(e.failure)) {
        setState(() {
          _stage = _Stage.idle;
          _failure = e.failure;
        });
        return;
      }
      // IMP-3: no recipe data, or a page the device couldn't fetch at all
      // (many social apps block a plain fetch) both go to AI import next,
      // same as a social link.
      await _sendToAi(url: url);
      return;
    }
    if (!mounted || run != _run) return;
    setState(() => _stage = _Stage.idle);
    await _openPreview(draft, usedAiImport: false);
  }

  /// IMP-3: a share or a plain paste with no link reaches AI import with no
  /// user action at all — unlike a typed link or a pasted caption, where
  /// tapping "استيراد" already is the user's decision. This shows the cost
  /// line first, with a real استيراد/إلغاء choice, before anything is sent.
  void _confirmAiSend(String text) {
    final settings = context.read<SettingsState>();
    if (_aiImportsLeft(settings) <= 0) {
      setState(() {
        _stage = _Stage.idle;
        _outOfQuota = true;
        _lastText = text;
        _lastWasPhotos = false;
      });
      return;
    }
    setState(() {
      _stage = _Stage.aiConfirm;
      _pendingAiText = text;
      _pendingPhotos = null;
    });
  }

  void _cancelAiConfirm() => setState(() {
    _stage = _Stage.idle;
    _pendingAiText = null;
    _pendingPhotos = null;
  });

  /// IMP-1, IMP-10, IMP-12: the system camera or photo picker. Adds to any
  /// photos already waiting (the camera's next page), up to
  /// [maxImportImages], then shows IMP-3's cost line with a real choice
  /// before anything is sent — the same confirm step as a shared text.
  Future<void> _pickPhotos({required bool camera}) async {
    final picker = context.read<ImportPhotoPicker>();
    final have = _pendingPhotos ?? const <Uint8List>[];
    final room = maxImportImages - have.length;
    if (room <= 0) return;
    final picked = camera
        ? await picker.camera()
        : await picker.gallery(max: room);
    if (!mounted || picked.isEmpty) return; // cancelled: nothing changes
    final settings = context.read<SettingsState>();
    if (picked.length > room) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.importPhotoFirstOnly(settings.number(maxImportImages)),
          ),
        ),
      );
    }
    if (_aiImportsLeft(settings) <= 0) {
      setState(() {
        _stage = _Stage.idle;
        _outOfQuota = true;
        _lastText = null;
        _lastWasPhotos = true;
        _pendingPhotos = null;
      });
      return;
    }
    setState(() {
      _stage = _Stage.aiConfirm;
      _failure = null;
      _aiError = null;
      _pendingAiText = null;
      _pendingPhotos = [...have, ...picked.take(room)];
      _photosFromCamera = camera;
    });
  }

  /// IMP-3, SRV-1: sends exactly one of [url], [text] or [images] to the AI
  /// server. The cost line (IMP-3) and progress (IMP-4) show before
  /// anything is sent; a quota already at 0 is told to the user instead of
  /// trying a request the server would only reject (IMP-7).
  Future<void> _sendToAi({
    String? url,
    String? text,
    List<Uint8List>? images,
  }) async {
    final settings = context.read<SettingsState>();
    if (_aiImportsLeft(settings) <= 0) {
      setState(() {
        _stage = _Stage.idle;
        _outOfQuota = true;
        _aiError = null;
        _unreadableLink = null;
        _captionFallbackReason = null;
        _lastText = text;
        _lastWasPhotos = images != null;
        _pendingPhotos = null;
      });
      return;
    }
    final run = ++_run;
    setState(() {
      _stage = _Stage.aiSending;
      _aiError = null;
      _outOfQuota = false;
      _lastText = text;
      _lastWasPhotos = images != null;
      _pendingAiText = null;
      _pendingPhotos = null;
      _showKeepWaiting = false;
    });
    _keepWaitingTimer?.cancel();
    _keepWaitingTimer = Timer(_keepWaitingAfter, () {
      if (mounted && run == _run) setState(() => _showKeepWaiting = true);
    });
    final photoStore = context.read<PhotoStore>();
    final installId = await context.read<RecipesState>().repository.installId();
    if (!mounted || run != _run) return;
    final importer = context.read<Importer>();
    Recipe draft;
    try {
      draft = images != null
          ? await importer.fromPhotos(installId: installId, images: images)
          : await importer.fromAi(installId: installId, url: url, text: text);
    } on AiImportException catch (e) {
      _keepWaitingTimer?.cancel();
      if (!mounted || run != _run) return;
      setState(() {
        _stage = _Stage.idle;
        _aiError = e.kind;
        // IMP-12: only a link attempt sets or clears these — a failed
        // caption send (url is always null there) must never wipe out a
        // link kept from an earlier unreachable/private_post attempt, or
        // the paste box, its reason line and the original source all
        // disappear behind a retry's own, unrelated error (e.g. a dropped
        // connection) (should-fix, review).
        if (url != null) {
          final fallback = _showsCaptionFallback(e.kind);
          _unreadableLink = fallback ? url : null;
          _captionFallbackReason = fallback ? e.kind : null;
        }
      });
      return;
    }
    _keepWaitingTimer?.cancel();
    if (!mounted || run != _run) {
      // A cancelled photo import (IMP-4) leaves no photo file behind.
      final photo = draft.photoPath;
      if (photo != null) await photoStore.delete(photo);
      return;
    }
    setState(() => _stage = _Stage.idle);
    // IMP-12: a pasted caption or a screenshot still saves with the
    // original link as its source, so IMP-9's duplicate check and "open
    // original" keep working.
    if (url == null) {
      final original = _unreadableLink;
      if (original != null) {
        draft = draft.copyWith(
          sourceUrl: normalizeSourceUrl(original),
          sourceType: SourceType.social,
        );
      }
    }
    await _openPreview(draft, usedAiImport: true);
  }

  /// IMP-5: the preview. Saving a fetched or AI draft from it is what
  /// RUN-5 counts as "saved an import"; a [byHand] draft after a failed
  /// import isn't one, whatever source it's tagged with.
  Future<void> _openPreview(
    Recipe draft, {
    required bool usedAiImport,
    bool byHand = false,
  }) async {
    final settings = context.read<SettingsState>();
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RecipeEditorScreen(
          recipe: draft,
          imported: true,
          usedAiImport: usedAiImport,
        ),
      ),
    );
    if (saved != null && !byHand) await settings.recordImportSaved();
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

  void _cancel() {
    _keepWaitingTimer?.cancel();
    setState(() {
      _run++;
      _stage = _Stage.idle;
      _showKeepWaiting = false;
    });
  }

  /// IMP-4: "Keep waiting" — the request itself is untouched, only the
  /// prompt is dismissed, with another [_keepWaitingAfter] before it can
  /// reappear.
  void _keepWaiting() {
    final run = _run;
    _keepWaitingTimer?.cancel();
    _keepWaitingTimer = Timer(_keepWaitingAfter, () {
      if (mounted && run == _run) setState(() => _showKeepWaiting = true);
    });
    setState(() => _showKeepWaiting = false);
  }

  /// A blank draft, tagged with whatever source was being tried, for the
  /// user to fill in themselves (IMP-1's offline heuristic, or a blank
  /// website-tagged draft when there was only a link).
  Future<void> _addByHand() async {
    final importer = context.read<Importer>();
    final text = _lastText;
    final draft = text != null
        ? importer.fromText(text)
        : _lastWasPhotos
        ? importer.fromText('').copyWith(sourceType: SourceType.photo)
        : importer
              .fromText('')
              .copyWith(
                // IMP-9: normalized like every other import path, so a
                // later re-import of the same link (tracking parameters
                // and all) still finds this one as a duplicate.
                sourceUrl: normalizeSourceUrl(_link.text.trim()),
                sourceType: SourceType.website,
              );
    await _openPreview(draft, usedAiImport: false, byHand: true);
  }

  Future<void> _sendCaption() async {
    final text = _caption.text.trim();
    if (text.isEmpty) return;
    await _sendToAi(text: text);
  }

  void _cancelCaption() => setState(() {
    _unreadableLink = null;
    _captionFallbackReason = null;
    _aiError = null;
    _caption.clear();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsState>();
    final busy = _stage != _Stage.idle;
    // IMP-12: stays true — the paste box, its own reason line and the kept
    // link — through a caption retry that fails for a different reason
    // (should-fix, review): that failure is a fresh [_aiError], not this.
    final showingCaptionFallback =
        _captionFallbackReason != null && _unreadableLink != null;

    String? message = switch (_failure) {
      ImportFailure.invalidUrl => l10n.importInvalidUrl,
      ImportFailure.unreachable || ImportFailure.noRecipe || null => null,
    };
    var showAddByHand = false;
    if (_outOfQuota) {
      message = l10n.aiImportsOutLine;
      showAddByHand = true;
    } else if (_aiError != null && _aiError != _captionFallbackReason) {
      message = switch (_aiError!) {
        AiImportErrorKind.badRequest => l10n.aiImportErrorBadRequest,
        AiImportErrorKind.invalidToken => l10n.aiImportErrorInvalidToken,
        AiImportErrorKind.unreachable => l10n.aiImportErrorUnreachable,
        AiImportErrorKind.privatePost => l10n.aiImportErrorPrivatePost,
        AiImportErrorKind.notARecipe => l10n.aiImportErrorNotARecipe,
        AiImportErrorKind.limitReached => l10n.aiImportErrorLimitReached,
        AiImportErrorKind.busy => l10n.aiImportErrorBusy,
        AiImportErrorKind.misconfigured => l10n.aiImportErrorMisconfigured,
        AiImportErrorKind.tooLarge => l10n.aiImportErrorTooLarge,
        AiImportErrorKind.unreadablePhoto => l10n.aiImportErrorUnreadablePhoto,
        // Only a translation answers this (IMP-15); listed for completeness.
        AiImportErrorKind.badTranslation => l10n.translateErrorIncomplete,
        AiImportErrorKind.unknown => l10n.aiImportErrorUnknown,
        AiImportErrorKind.network => l10n.aiImportErrorNetwork,
      };
      showAddByHand = _aiError == AiImportErrorKind.notARecipe;
    }

    // PAY-7: Premium's 100 a month, the free 10 otherwise; the month's
    // count is the same either way (PAY-11).
    final purchases = context.watch<PurchasesState>();
    final quota = purchases.aiImportQuota;
    final left = settings.aiImportsLeft(quota: quota);
    final quotaLine = left > 0
        ? l10n.aiImportsLeftLine(
            quota, // the noun agrees with the quota (LANG-2, QTY-6)
            settings.number(left),
            settings.number(quota),
          )
        : l10n.aiImportsOutLine;

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
          const SizedBox(height: 8),
          // IMP-7, roadmap "counter visible in the header": always shown,
          // reset date included, and it becomes the out-of-quota line once
          // the month's AI imports are used up.
          Text(quotaLine, style: Theme.of(context).textTheme.bodySmall),
          // PAY-5, IMP-7: the one line where the free AI imports run out —
          // only while Premium is on sale and not already owned (PAY-6),
          // and never during the first run (RUN-3): a share can open this
          // screen over setup or the walkthrough.
          if (settings.settings.firstRunComplete &&
              left <= 0 &&
              !purchases.ownsPremium &&
              purchases.sellsPremium)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => openPurchaseScreen(context),
                child: Text(l10n.aiImportsPremiumLine),
              ),
            ),
          const SizedBox(height: 16),
          if (!busy && !showingCaptionFallback)
            FilledButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.download),
              label: Text(l10n.importAction),
            )
          else if (_stage == _Stage.aiConfirm) ...[
            // IMP-3: shown before a share, a plain paste or picked photos
            // are sent to AI import, with a real choice — the cases where
            // nothing else on this screen already counts as the user's
            // decision.
            if (_pendingPhotos case final photos?) ...[
              _PhotoStrip(photos: photos),
              const SizedBox(height: 4),
              Text(
                l10n.importPhotoCount(
                  photos.length,
                  settings.number(photos.length),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              l10n.aiImportCostLine(
                settings.number(left),
                settings.number(quota),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _pendingPhotos != null
                      ? _sendToAi(images: _pendingPhotos)
                      : _sendToAi(text: _pendingAiText),
                  child: Text(l10n.importAction),
                ),
                if (_photosFromCamera &&
                    (_pendingPhotos?.length ?? maxImportImages) <
                        maxImportImages)
                  OutlinedButton.icon(
                    onPressed: () => _pickPhotos(camera: true),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(l10n.importPhotoAddPage),
                  ),
                OutlinedButton(
                  onPressed: _cancelAiConfirm,
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ] else if (_stage != _Stage.idle) ...[
            LinearProgressIndicator(
              value: switch (_stage) {
                _Stage.reading => 0.25,
                _Stage.understanding => 0.5,
                _Stage.aiSending => 0.75,
                _Stage.aiConfirm || _Stage.idle => 1,
              },
            ),
            const SizedBox(height: 8),
            Text(switch (_stage) {
              _Stage.reading => l10n.importReading,
              _Stage.understanding => l10n.importUnderstanding,
              _Stage.aiSending => l10n.aiImportSending,
              _Stage.aiConfirm || _Stage.idle => '',
            }),
            if (_stage == _Stage.aiSending) ...[
              const SizedBox(height: 4),
              // IMP-3: the cost line, shown before the AI request completes.
              Text(
                l10n.aiImportCostLine(
                  settings.number(left),
                  settings.number(quota),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            // IMP-4: past 45 s, a real choice instead of the bar alone.
            if (_stage == _Stage.aiSending && _showKeepWaiting) ...[
              Text(
                l10n.aiImportKeepWaitingLine,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _keepWaiting,
                      child: Text(
                        l10n.aiImportKeepWaitingAction,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancel,
                      child: Text(l10n.cancel),
                    ),
                  ),
                ],
              ),
            ] else
              OutlinedButton(onPressed: _cancel, child: Text(l10n.cancel)),
          ],
          // Out of the way while a screenshot from it is being confirmed or
          // sent, so the screen offers one "استيراد", not two.
          if (showingCaptionFallback &&
              _stage != _Stage.aiConfirm &&
              !(_stage == _Stage.aiSending && _lastWasPhotos)) ...[
            const SizedBox(height: 16),
            Text(
              _captionFallbackReason == AiImportErrorKind.privatePost
                  ? l10n.aiImportErrorPrivatePost
                  : l10n.aiImportErrorUnreachable,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _caption,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: l10n.aiImportPasteHint,
                suffixIcon: IconButton(
                  tooltip: l10n.paste,
                  icon: const Icon(Icons.content_paste),
                  onPressed: _pasteCaption,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _sendCaption,
                  child: Text(l10n.importAction),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _cancelCaption,
                  child: Text(l10n.cancel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // IMP-12: a screenshot of the post goes through the same photo
            // import (IMP-10), and still saves with the post's link.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: busy ? null : () => _pickPhotos(camera: false),
                icon: const Icon(Icons.screenshot_outlined),
                label: Text(l10n.aiImportScreenshotAction),
              ),
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (showAddByHand)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: OutlinedButton(
                  onPressed: _addByHand,
                  child: Text(l10n.addByHand),
                ),
              ),
          ],
          // IMP-1, IMP-10: a cookbook page or a handwritten recipe, through
          // the system camera or photo picker. Last, so a failed attempt's
          // message stays next to the button that caused it.
          if (!busy && !showingCaptionFallback) ...[
            const SizedBox(height: 24),
            Text(
              l10n.importPhotoExplain(settings.number(maxImportImages)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickPhotos(camera: true),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l10n.importPhotoCamera),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickPhotos(camera: false),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l10n.importPhotoGallery),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Thumbnails of the photos about to be sent (IMP-1), so the user sees
/// exactly which pictures leave the device before tapping استيراد.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos});
  final List<Uint8List> photos;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final photo in photos)
          ClipPath(
            // LOOK-6: the same shape as a library thumbnail (Decor).
            clipper: ShapeBorderClipper(
              shape: Decor.of(context).thumbnailShape,
              textDirection: Directionality.of(context),
            ),
            child: Image.memory(
              photo,
              width: 64,
              height: 64,
              cacheWidth: 192,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 64,
                height: 64,
                child: Icon(Icons.image_outlined),
              ),
            ),
          ),
      ],
    );
  }
}
