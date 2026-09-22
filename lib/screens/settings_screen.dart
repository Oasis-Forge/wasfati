import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/quantity/format.dart';
import '../models/ramadan.dart';
import '../models/recipe.dart';
import '../models/settings.dart';
import '../providers/grocery_state.dart';
import '../providers/plan_state.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../services/backup.dart';
import '../services/backup_files.dart' show BackupFiles, BackupFilesError;
import '../services/recipe_pages.dart' show ShareStorage;
import '../services/sharer.dart';
import '../widgets/content_direction.dart';

/// Settings (roadmap 2a): language (LANG-1), digit style (QTY-5), units
/// (SCALE-5), week start and theme. Changes apply at once.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SettingsState>();
    final plan = context.watch<PlanState>();
    final s = state.settings;
    void set(AppSettings next) => state.update(next);
    // RAM-2: null until the calendar (ramadanTable) has this year's dates.
    // ramadanMonthForShiftRowAt, not ramadanFor: this row's own year must
    // stay put while its shift is being edited, even right at the
    // boundary where that shift makes "today" Eid (should-fix).
    final ramadanMonth = plan.ramadanMonthForShiftRowAt(plan.today);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsetsDirectional.only(bottom: 32),
        children: [
          _Choice<LanguagePref>(
            title: l10n.settingsLanguage,
            value: s.language,
            options: {
              LanguagePref.system: l10n.languageSystem,
              LanguagePref.ar: 'العربية', // each language in its own name
              LanguagePref.en: 'English',
            },
            onChanged: (v) => set(s.copyWith(language: v)),
          ),
          _Choice<DigitStyle>(
            title: l10n.settingsDigits,
            value: s.digits,
            options: const {
              DigitStyle.western: '123',
              DigitStyle.arabic: '١٢٣',
            },
            onChanged: (v) => set(s.copyWith(digits: v)),
          ),
          _Choice<UnitSystem>(
            title: l10n.settingsUnits,
            value: s.units,
            options: {
              UnitSystem.metric: l10n.unitsMetric,
              UnitSystem.kitchen: l10n.unitsKitchen,
            },
            onChanged: (v) => set(s.copyWith(units: v)),
          ),
          _Choice<WeekStart>(
            title: l10n.settingsWeekStart,
            value: s.weekStart,
            options: {
              WeekStart.auto: l10n.weekStartAuto,
              WeekStart.saturday: l10n.saturday,
              WeekStart.sunday: l10n.sunday,
              WeekStart.monday: l10n.monday,
            },
            onChanged: (v) => set(s.copyWith(weekStart: v)),
          ),
          _Choice<ThemePref>(
            title: l10n.settingsTheme,
            value: s.theme,
            options: {
              ThemePref.system: l10n.themeSystem,
              ThemePref.light: l10n.themeLight,
              ThemePref.dark: l10n.themeDark,
            },
            onChanged: (v) => set(s.copyWith(theme: v)),
          ),
          _RamadanSection(settings: s, month: ramadanMonth, onChanged: set),
          const _BackupSection(),
        ],
      ),
    );
  }
}

/// RAM-1's switch, and RAM-2's shift row once a Ramadan is current or
/// upcoming (null until the built-in calendar has this year's dates).
/// RAM-5: no prayer or iftar times here, and nothing that needs a
/// permission the release build doesn't already declare (RUN-2).
class _RamadanSection extends StatelessWidget {
  const _RamadanSection({
    required this.settings,
    required this.month,
    required this.onChanged,
  });

  final AppSettings settings;
  final RamadanMonth? month;
  final ValueChanged<AppSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SettingsState>();
    final scheme = Theme.of(context).colorScheme;
    final month = this.month;
    final shift = month == null ? 0 : settings.ramadanShiftFor(month.hijriYear);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 4),
          child: Text(
            l10n.settingsRamadanSection,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: scheme.primary),
          ),
        ),
        SwitchListTile(
          title: Text(l10n.ramadanModeLabel),
          value: settings.ramadanMode,
          onChanged: (v) => onChanged(settings.copyWith(ramadanMode: v)),
        ),
        if (month != null)
          ListTile(
            title: Text(
              l10n.ramadanStartLabel(
                state.inDigits(
                  MaterialLocalizations.of(context)
                      .formatMediumDate(month.start),
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l10n.ramadanShiftEarlier,
                  icon: const Icon(Icons.remove),
                  onPressed: shift > -1
                      ? () => onChanged(
                          settings.copyWith(
                            ramadanShift: shift - 1,
                            ramadanShiftYear: month.hijriYear,
                          ),
                        )
                      : null,
                ),
                IconButton(
                  tooltip: l10n.ramadanShiftLater,
                  icon: const Icon(Icons.add),
                  onPressed: shift < 1
                      ? () => onChanged(
                          settings.copyWith(
                            ramadanShift: shift + 1,
                            ramadanShiftYear: month.hijriYear,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// BAK-1–BAK-10: save, share, restore and export, the reminder switch
/// (BAK-8), and the latest automatic backups (BAK-2, BAK-7). Its own
/// [StatefulWidget] because it holds UI-only state (the async list of
/// automatic backups, and whether an action is in flight) that nothing
/// else on the screen needs.
class _BackupSection extends StatefulWidget {
  const _BackupSection();

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  List<AutoBackup>? _autoBackups;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reloadAutoBackups();
  }

  Future<void> _reloadAutoBackups() async {
    final list = await context.read<BackupService>().automaticBackups();
    if (mounted) setState(() => _autoBackups = list);
  }

  /// Runs one backup action at a time, so a second tap can't overlap it.
  Future<void> _guarded(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _guarded(() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await saveBackupNow(context);
    if (!saved || !mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.backupSaveDone)));
  });

  /// BAK-6: shares the same zip [saveBackupNow] would save, written first
  /// to the app's share cache (services/recipe_pages.dart's [ShareStorage],
  /// the same folder SHARE-4's images use and that's cleared at every
  /// start), then handed to the share sheet. Sharing is the other way a
  /// backup can leave the phone (principle 2), so it counts as "the last
  /// backup" too, same as Save (should-fix, platform review: this used to
  /// never update it, so BAK-8 kept reminding someone who only ever shares).
  Future<void> _share() => _guarded(() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final backup = context.read<BackupService>();
    final storage = context.read<ShareStorage>();
    final sharer = context.read<Sharer>();
    final settingsState = context.read<SettingsState>();
    try {
      final bytes = await backup.createBackup();
      final dir = await storage.pagesDir();
      await dir.create(recursive: true);
      final now = backup.now();
      final file = File(p.join(dir.path, backupFileName(now)));
      await file.writeAsBytes(bytes);
      await sharer.shareFiles([file.path]);
      await settingsState.update(
        settingsState.settings.copyWith(lastBackupAt: now),
      );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.backupShareFailed)));
    }
  });

  Future<void> _restore() => _guarded(() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final files = context.read<BackupFiles>();
    List<int>? bytes;
    try {
      bytes = await files.openFile();
    } on BackupFilesError {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.backupErrorCantOpen)));
      return;
    }
    if (bytes == null || !mounted) return;
    await _handleRestore(bytes);
  });

  Future<void> _restoreAuto(AutoBackup auto) => _guarded(() async {
    final bytes = await File(auto.path).readAsBytes();
    if (!mounted) return;
    await _handleRestore(bytes);
  });

  /// BAK-4, BAK-7: shows what the file holds, then Merge or Replace
  /// (confirmed twice), or the translated reason it can't be restored at
  /// all — never changing anything before the user picks a mode.
  Future<void> _handleRestore(List<int> bytes) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final BackupPreview preview;
    try {
      preview = await context.read<BackupService>().inspect(bytes);
    } on BackupError catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_errorText(l10n, e))));
      return;
    } catch (_) {
      // must-fix, several reviews: inspect() now turns every damaged-file
      // shape into a BackupError itself, but this stays as a last resort so
      // a restore never fails silently, matching BAK-7's "changes nothing
      // and says so" for a file this screen didn't expect.
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.backupErrorGeneric)));
      return;
    }
    if (!mounted) return;
    final mode = await _pickMode(preview);
    if (mode == null || !mounted) return;
    if (mode == RestoreMode.replace) {
      final confirmed = await _confirmReplace();
      if (!confirmed || !mounted) return;
    }
    await _finishRestore(bytes, mode);
  }

  /// BAK-7's preview sheet: what the file holds, then Merge (the default)
  /// or Replace. Null if the user dismissed it without choosing. Each count
  /// is its own line, and a zero count other than recipes is left out
  /// entirely (should-fix, platform review): LANG-2 rules out a
  /// pieced-together string, which `' · '.join(...)` was, and "بلا كتب
  /// طبخ · بلا أسابيع في الخطة · بلا عناصر في المشتريات" for an otherwise
  /// simple one-recipe file was noise, not information.
  Future<RestoreMode?> _pickMode(BackupPreview preview) {
    final l10n = AppLocalizations.of(context);
    final settings = context.read<SettingsState>();
    final lines = [
      l10n.backupPreviewRecipes(
        preview.recipeCount,
        settings.number(preview.recipeCount),
      ),
      if (preview.cookbookCount > 0)
        l10n.backupPreviewCookbooks(
          preview.cookbookCount,
          settings.number(preview.cookbookCount),
        ),
      if (preview.planWeeks > 0)
        l10n.backupPreviewWeeks(
          preview.planWeeks,
          settings.number(preview.planWeeks),
        ),
      if (preview.groceryItemCount > 0)
        l10n.backupPreviewGroceryItems(
          preview.groceryItemCount,
          settings.number(preview.groceryItemCount),
        ),
    ];
    return showModalBottomSheet<RestoreMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.backupPreviewTitle,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final line in lines) Text(line),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, RestoreMode.merge),
                child: Text(l10n.backupMergeAction),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, RestoreMode.replace),
                child: Text(l10n.backupReplaceAction),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// BAK-7: Replace is confirmed twice (must-fix, platform review): the
  /// counts sheet's own "استبدال" is a choice between Merge and Replace,
  /// not a confirmation, so this shows what will actually be lost — with
  /// this phone's own recipe count, not just the file's — and then asks
  /// once more with a destructively styled button, before anything is
  /// touched.
  Future<bool> _confirmReplace() async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final count = context.read<RecipesState>().recipes.length;
    final settingsState = context.read<SettingsState>();
    final firstOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupReplaceConfirmTitle),
        content: Text(
          l10n.backupReplaceConfirmBody(count, settingsState.number(count)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.backupReplaceAction),
          ),
        ],
      ),
    );
    if (firstOk != true || !mounted) return false;
    final finalOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupReplaceConfirmFinalTitle),
        content: Text(l10n.backupReplaceConfirmFinalBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.backupReplaceAction),
          ),
        ],
      ),
    );
    return finalOk ?? false;
  }

  Future<void> _finishRestore(List<int> bytes, RestoreMode mode) async {
    final l10n = AppLocalizations.of(context);
    final backup = context.read<BackupService>();
    final settingsState = context.read<SettingsState>();
    final recipes = context.read<RecipesState>();
    final plan = context.read<PlanState>();
    final groceries = context.read<GroceryState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await backup.restore(bytes, mode: mode);
      // Every screen that reads this data reloads (CLAUDE.md), not just
      // the recipe list: the plan, groceries and settings can all have
      // changed underneath them.
      await recipes.load();
      await plan.showWeek(plan.weekStart);
      await groceries.load();
      await settingsState.load();
      // should-fix, platform review: an automatic backup lives only in this
      // phone's own storage (BAK-9 excludes it from Android's device
      // backup), so restoring — merge or replace — is never itself a copy
      // that has left the phone. Only Save and Share (principle 2) count as
      // "the last backup" for BAK-8's reminder.
      await _reloadAutoBackups();
      if (!mounted) return;
      final counted = result.userFacing;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.backupResultTitle),
          content: Text(
            l10n.backupResultSummary(
              settingsState.number(counted.added),
              settingsState.number(counted.updated),
              settingsState.number(counted.unchanged),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.done),
            ),
          ],
        ),
      );
    } on BackupError catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_errorText(l10n, e))));
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.backupErrorGeneric)));
    }
  }

  /// BAK-10: all recipes, or one cookbook's, as text, through the same
  /// save dialog as the backup zip.
  Future<void> _export() => _guarded(() async {
    final l10n = AppLocalizations.of(context);
    final recipesState = context.read<RecipesState>();
    final settingsState = context.read<SettingsState>();
    final backup = context.read<BackupService>();
    final files = context.read<BackupFiles>();
    final messenger = ScaffoldMessenger.of(context);

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: Text(
                l10n.backupExportPickTitle,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              title: Text(l10n.backupExportAll),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final c in recipesState.cookbooks)
              ListTile(
                title: ContentText(c.name),
                onTap: () => Navigator.pop(ctx, c.id),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final entries = choice.isEmpty
        ? recipesState.recipes
        : recipesState.recipes
              .where((e) => e.cookbookIds.contains(choice))
              .toList();
    final repo = recipesState.repository;
    final full = <Recipe>[];
    for (final e in entries) {
      final r = await repo.get(e.id);
      if (r != null) full.add(r);
    }
    if (!mounted) return;

    String servingsLabel(int n) => l10n.servings(n, settingsState.number(n));
    String prepTimeLabel(int m) =>
        '${l10n.prepTime} ${l10n.minutes(m, settingsState.number(m))}';
    String cookTimeLabel(int m) =>
        '${l10n.cookTime} ${l10n.minutes(m, settingsState.number(m))}';
    String unscaledLineText(String line, String mark) =>
        l10n.shareUnscaledLine(line, mark);

    final text = backup.exportText(
      full,
      digits: settingsState.digits,
      ingredientsHeading: l10n.shareHeadingIngredients,
      stepsHeading: l10n.shareHeadingSteps,
      footerLine: l10n.shareFooterLine,
      notScaledMark: l10n.notScaled,
      unscaledLineText: unscaledLineText,
      servingsLabel: servingsLabel,
      prepTimeLabel: prepTimeLabel,
      cookTimeLabel: cookTimeLabel,
      sourceLabel: l10n.shareSource,
    );
    final name = _exportFileName(backup.now());
    try {
      final saved = await files.saveBytes(
        name,
        utf8.encode(text),
        'text/plain',
      );
      if (!saved || !mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.backupExportDone)));
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.backupExportFailed)));
    }
  });

  /// BAK-4, BAK-7: a translated reason, never the engine's own words —
  /// [BackupErrorKind.notAZip] and [BackupErrorKind.notWasfati] read the
  /// same to the user ("not a Wasfati backup"); only [damagedJson] and
  /// [newerSchema] need their own message.
  String _errorText(AppLocalizations l10n, BackupError e) => switch (e.kind) {
    BackupErrorKind.notAZip ||
    BackupErrorKind.notWasfati => l10n.backupErrorNotWasfati,
    BackupErrorKind.damagedJson => l10n.backupErrorDamaged,
    BackupErrorKind.newerSchema => l10n.backupErrorNewerSchema,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<SettingsState>();
    final s = state.settings;
    final autoBackups = _autoBackups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 4),
          child: Text(
            l10n.settingsBackupSection,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: scheme.primary),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.save_outlined),
          title: Text(l10n.backupSaveAction),
          enabled: !_busy,
          onTap: () => _save(),
        ),
        ListTile(
          leading: const Icon(Icons.ios_share_outlined),
          title: Text(l10n.backupShareAction),
          enabled: !_busy,
          onTap: () => _share(),
        ),
        ListTile(
          leading: const Icon(Icons.restore_outlined),
          title: Text(l10n.backupRestoreAction),
          enabled: !_busy,
          onTap: () => _restore(),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(l10n.backupExportAction),
          enabled: !_busy,
          onTap: () => _export(),
        ),
        SwitchListTile(
          title: Text(l10n.backupReminderSwitch),
          value: !s.backupReminderOff,
          onChanged: (v) => state.update(s.copyWith(backupReminderOff: !v)),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
          child: Text(
            l10n.backupAutoSection,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: scheme.primary),
          ),
        ),
        if (autoBackups == null)
          const Padding(
            padding: EdgeInsetsDirectional.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (autoBackups.isEmpty)
          ListTile(title: Text(l10n.backupAutoEmpty))
        else
          for (final auto in autoBackups)
            ListTile(
              // should-fix, platform review: a restore makes a new one at
              // once, so same-day rows used to read identically ("نسخة
              // السبت، ١٩ سبتمبر" twice); the time tells them apart.
              title: Text(
                l10n.backupAutoBackupDate(
                  state.inDigits(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(auto.createdAt.toLocal()),
                  ),
                  state.inDigits(
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay.fromDateTime(auto.createdAt.toLocal()),
                    ),
                  ),
                ),
              ),
              trailing: TextButton(
                onPressed: _busy ? null : () => _restoreAuto(auto),
                child: Text(l10n.backupRestoreAction),
              ),
            ),
      ],
    );
  }
}

/// `wasfati-export-YYYY-MM-DD.txt` (BAK-10): [createdAt]'s local calendar
/// date (DATE-1), the same as [backupFileName] uses for the zip
/// (should-fix, platform review: this used to stamp the UTC date instead).
String _exportFileName(DateTime createdAt) {
  final local = createdAt.toLocal();
  return 'wasfati-export-'
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}.txt';
}

/// BAK-6, BAK-8: saves a backup through the system's save dialog and
/// records [AppSettings.lastBackupAt] on success. Shared by this screen's
/// own button and the library's reminder card ("احفظ الآن", BAK-8), so both
/// behave identically. True if the user actually saved it; false both when
/// they cancelled and when saving failed outright (must-fix, platform
/// review: a thrown [BackupFilesError] or any other I/O failure used to
/// escape uncaught here, showing nothing and — for the reminder card —
/// leaving its buttons disabled for good).
Future<bool> saveBackupNow(BuildContext context) async {
  final backup = context.read<BackupService>();
  final files = context.read<BackupFiles>();
  final settingsState = context.read<SettingsState>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    final bytes = await backup.createBackup();
    final now = backup.now();
    final saved = await files.saveBytes(
      backupFileName(now),
      bytes,
      backupMimeType,
    );
    if (saved) {
      await settingsState.update(
        settingsState.settings.copyWith(lastBackupAt: now),
      );
    }
    return saved;
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.backupSaveFailed)));
    return false;
  }
}

/// A heading and one row per option, the chosen one ticked.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: scheme.primary),
          ),
        ),
        for (final e in options.entries)
          ListTile(
            title: Text(e.value),
            trailing: e.key == value
                ? Icon(Icons.check, color: scheme.primary)
                : null,
            selected: e.key == value,
            onTap: () => onChanged(e.key),
          ),
      ],
    );
  }
}
