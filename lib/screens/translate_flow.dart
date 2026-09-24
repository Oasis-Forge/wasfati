import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/recipe.dart';
import '../models/recipe_translation.dart';
import '../providers/purchases_state.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../services/ai_import.dart';
import '../services/importer.dart';
import '../services/photo_store.dart';
import 'recipe_editor_screen.dart';

/// IMP-14–IMP-16: "ترجم إلى العربية" / "Translate to English", from a
/// recipe's page or an import preview. Shows IMP-3's cost line first
/// (unless [free]: translating inside an AI import's own preview is part of
/// that import), sends only the words (`Importer.translate`), then opens
/// the translated copy as a preview. Nothing is saved, and no AI import
/// counted, until Save there (IMP-7, IMP-16); a cancelled, failed or
/// incomplete translation costs nothing, and the last two offer "Try
/// again" (SRV-7). [linkToOriginal] links the copy to [recipe] (a saved
/// recipe). Returns the saved copy's ID, or null.
Future<String?> translateAndPreview(
  BuildContext context,
  Recipe recipe, {
  required bool free,
  required bool linkToOriginal,
}) async {
  final l10n = AppLocalizations.of(context);
  final settings = context.read<SettingsState>();
  final importer = context.read<Importer>();
  final repo = context.read<RecipesState>().repository;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final photos = context.read<PhotoStore>();
  final toArabic = Localizations.localeOf(context).languageCode == 'ar';

  // SRV-11: a recipe past the server's limits can't be sent at all, so it
  // says so before asking the user to spend anything.
  if (!fitsTranslateLimits(translationItems(recipe))) {
    await _offerRetry(context, AiImportErrorKind.tooLarge);
    return null;
  }

  if (!free) {
    // PAY-7: Premium's 100 a month, the free 10 otherwise.
    final quota = context.read<PurchasesState>().aiImportQuota;
    final left = settings.aiImportsLeft(quota: quota);
    if (left <= 0) {
      // IMP-7: out of AI imports — said plainly, nothing sent.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.aiImportsOutLine)));
      return null;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translateRecipe),
        content: Text(
          l10n.aiImportCostLine(settings.number(left), settings.number(quota)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.translateConfirm),
          ),
        ],
      ),
    );
    if (go != true) return null;
  }

  final installId = await repo.installId();
  while (true) {
    if (!context.mounted) return null;
    final attempt = await _sendWithProgress(
      context,
      () => importer.translate(
        installId: installId,
        recipe: recipe,
        toArabic: toArabic,
        linkToOriginal: linkToOriginal,
      ),
    );
    if (!context.mounted) {
      // The page is gone: a translation that did come back leaves no
      // photo file behind (REC-8).
      final photo = switch (attempt) {
        _Translated(:final result) => result.recipe.photoPath,
        _ => null,
      };
      if (photo != null) await photos.delete(photo);
      return null;
    }
    switch (attempt) {
      case _Cancelled():
        return null;
      case _Failed(:final kind):
        if (!await _offerRetry(context, kind)) return null;
      case _Translated(:final result):
        if (result.keptOriginal > 0) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.translateKeptOriginal)));
        }
        return navigator.push<String>(
          MaterialPageRoute(
            builder: (_) => RecipeEditorScreen(
              recipe: result.recipe,
              imported: true,
              // IMP-16: saving the copy is the one AI import it costs —
              // for an AI import's preview, that same import.
              usedAiImport: true,
              translation: true,
            ),
          ),
        );
    }
  }
}

sealed class _Attempt {
  const _Attempt();
}

class _Cancelled extends _Attempt {
  const _Cancelled();
}

class _Failed extends _Attempt {
  const _Failed(this.kind);
  final AiImportErrorKind kind;
}

class _Translated extends _Attempt {
  const _Translated(this.result);
  final TranslatedRecipe result;
}

/// Runs [send] behind a progress dialog with Cancel (IMP-4). A cancelled
/// translation's answer is dropped, with the photo it copied.
Future<_Attempt> _sendWithProgress(
  BuildContext context,
  Future<TranslatedRecipe> Function() send,
) async {
  final l10n = AppLocalizations.of(context);
  final photos = context.read<PhotoStore>();
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  var closed = false;
  var cancelled = false;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(l10n.translateSending)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (closed) return;
                closed = true;
                cancelled = true;
                Navigator.of(ctx).pop();
              },
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    ),
  );

  _Attempt attempt;
  try {
    attempt = _Translated(await send());
  } on AiImportException catch (e) {
    attempt = _Failed(e.kind);
  } catch (_) {
    attempt = const _Failed(AiImportErrorKind.unknown);
  }
  if (!closed) {
    closed = true;
    rootNavigator.pop();
  }
  if (!cancelled) return attempt;
  if (attempt case _Translated(:final result)) {
    final photo = result.recipe.photoPath;
    if (photo != null) await photos.delete(photo);
  }
  return const _Cancelled();
}

/// The failure's own translated message (SRV-7, LANG-2); true when the
/// user chose "Try again", offered only where trying again can help.
Future<bool> _offerRetry(BuildContext context, AiImportErrorKind kind) async {
  final l10n = AppLocalizations.of(context);
  final message = translateErrorMessage(l10n, kind);
  final retry = switch (kind) {
    AiImportErrorKind.badTranslation ||
    AiImportErrorKind.network ||
    AiImportErrorKind.badRequest ||
    AiImportErrorKind.unknown => true,
    _ => false,
  };
  final again = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(retry ? l10n.cancel : l10n.dismiss),
        ),
        if (retry)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.tryAgain),
          ),
      ],
    ),
  );
  return again ?? false;
}

/// SRV-7, SRV-11: what a failed translation says. `too_large` and an
/// incomplete answer have their own messages; the rest read as an import's.
String translateErrorMessage(AppLocalizations l10n, AiImportErrorKind kind) =>
    switch (kind) {
      AiImportErrorKind.tooLarge => l10n.translateErrorTooLarge,
      AiImportErrorKind.badTranslation => l10n.translateErrorIncomplete,
      AiImportErrorKind.limitReached => l10n.aiImportErrorLimitReached,
      AiImportErrorKind.busy => l10n.aiImportErrorBusy,
      AiImportErrorKind.misconfigured => l10n.aiImportErrorMisconfigured,
      AiImportErrorKind.invalidToken => l10n.aiImportErrorInvalidToken,
      AiImportErrorKind.badRequest => l10n.aiImportErrorBadRequest,
      AiImportErrorKind.network => l10n.aiImportErrorNetwork,
      AiImportErrorKind.unreachable ||
      AiImportErrorKind.privatePost ||
      AiImportErrorKind.notARecipe ||
      AiImportErrorKind.unreadablePhoto ||
      AiImportErrorKind.unknown => l10n.aiImportErrorUnknown,
    };
