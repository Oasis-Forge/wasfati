import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/purchases_state.dart';
import '../providers/settings_state.dart';
import '../theme/decor.dart';
import 'home_screen.dart' show openEditor;
import 'import_screen.dart';

/// Which tile the add sheet was closed with, or null if it was dismissed
/// without picking one.
enum AddSheetAction { link, photo, pasteText, byHand }

/// LOOK-11: the add sheet, opened from the navigation pill's centre "+".
/// Four ways in, in this fixed order (LOOK-2: never reordered) — a link
/// (IMP-1), a photo (IMP-10), pasted text (IMP-3) and writing it yourself —
/// each opening exactly the flow that already exists for it, then the
/// AI-import quota (IMP-7) and one line that website imports are free and
/// unlimited (IMP-2). No upsell, no ad (ADS-1).
///
/// The sheet itself only reports which tile was tapped: navigating (a
/// second page push) happens after it has fully closed, with the caller's
/// own long-lived [context] — never the sheet's own, which the framework
/// may already have unmounted by the time a pushed screen's Future
/// resolves (`openEditor` awaits the editor and then checks
/// `context.mounted` before pushing again).
Future<void> showAddSheet(BuildContext context) async {
  final action = await showModalBottomSheet<AddSheetAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => const _AddSheet(),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case AddSheetAction.link:
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ImportScreen(mode: ImportEntryMode.link),
        ),
      );
    case AddSheetAction.photo:
      // IMP-1, IMP-10: the same screen, opened straight to its camera/
      // gallery choice instead of the link form.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ImportScreen(mode: ImportEntryMode.photo),
        ),
      );
    case AddSheetAction.pasteText:
      // IMP-3: the same screen, opened with the multi-line paste box
      // instead of the link field.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ImportScreen(mode: ImportEntryMode.pasteText),
        ),
      );
    case AddSheetAction.byHand:
      await openEditor(context);
  }
}

class _AddSheet extends StatelessWidget {
  const _AddSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    void pick(AddSheetAction action) => Navigator.pop(context, action);

    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.only(
        start: 24,
        end: 24,
        // The theme's `showDragHandle` already reserves its own space above
        // this, so no extra top air is needed here.
        top: 0,
        // `useSafeArea` wraps the sheet in `SafeArea(bottom: false)`, so the
        // sheet has to consume the bottom system inset itself, on top of
        // the keyboard's.
        bottom:
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.viewPaddingOf(context).bottom +
            24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.recipesAdd, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            l10n.addSheetSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          // `IntrinsicHeight` + `CrossAxisAlignment.stretch`: the two tiles
          // in a row take the taller one's own height (LOOK-8), rather than
          // each following its own text.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _AddTile(
                    icon: Icons.link,
                    label: l10n.importTitle,
                    description: l10n.addSheetLinkDesc,
                    onTap: () => pick(AddSheetAction.link),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AddTile(
                    icon: Icons.photo_camera_outlined,
                    label: l10n.addSheetPhoto,
                    description: l10n.addSheetPhotoDesc,
                    onTap: () => pick(AddSheetAction.photo),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _AddTile(
                    icon: Icons.content_paste,
                    label: l10n.addSheetPasteText,
                    description: l10n.addSheetPasteDesc,
                    onTap: () => pick(AddSheetAction.pasteText),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AddTile(
                    icon: Icons.edit_outlined,
                    label: l10n.addByHand,
                    description: l10n.addSheetByHandDesc,
                    onTap: () => pick(AddSheetAction.byHand),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _QuotaCard(),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 144),
      child: Material(
        color: decor.sunk,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              // The icon anchors the top; the label/description anchor the
              // bottom (as in AddSheet.dc.html), with whatever the row's
              // shared height (from `IntrinsicHeight`, above) leaves between
              // them going here rather than under the icon.
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surfaceContainerLowest,
                    boxShadow: decor.liftShadow,
                  ),
                  child: Icon(icon, color: cs.primary, size: 20),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Never a single-line ellipsis (LOOK-8): the tile has
                    // the height for a wrapped label, in both languages at
                    // 1.3x.
                    Text(label, maxLines: 2, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// IMP-7: this month's AI imports left and the reset date — the same state
/// the import screen already uses — and the standing line that website
/// imports are free and unlimited (IMP-2).
class _QuotaCard extends StatelessWidget {
  const _QuotaCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final decor = Decor.of(context);
    final settings = context.watch<SettingsState>();
    final purchases = context.watch<PurchasesState>();
    final quota = purchases.aiImportQuota;
    final left = settings.aiImportsLeft(quota: quota);
    final caption = left > 0
        ? l10n.addSheetQuotaCaption
        : l10n.aiImportsOutLine;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.addSheetQuotaLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 8),
              // LOOK-8: at 1.3x, the label and the count can't both keep
              // their full width — the count shrinks (ellipsis) rather
              // than overflowing the row.
              Flexible(
                child: Text(
                  l10n.addSheetQuotaCount(
                    settings.number(left < 0 ? 0 : left),
                    settings.number(quota),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: quota == 0 ? 0 : left / quota,
              minHeight: 6,
              backgroundColor: decor.sunk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
