import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/quantity/format.dart';
import '../models/ramadan.dart';
import '../models/recipe.dart';
import '../models/settings.dart';
import '../providers/ads_state.dart';
import '../providers/backup_state.dart';
import '../providers/grocery_state.dart';
import '../providers/plan_state.dart';
import '../providers/purchases_state.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../services/backup.dart';
import '../services/backup_files.dart' show BackupFilesError;
import '../services/links.dart';
import '../services/mail.dart';
import '../theme/colors.dart' show sufraAccent;
import '../theme/decor.dart';
import '../widgets/content_direction.dart';
import '../widgets/segmented_pill.dart';
import '../widgets/sufra_card.dart';
import 'purchase_screen.dart';
import 'walkthrough_screen.dart';

/// The published privacy policy (docs/RELEASING.md): one bilingual page.
const privacyPolicyUrl = 'https://oasis-forge.github.io/wasfati/privacy-policy';

/// Settings (roadmap 2a; Sufra, Decision 23): the Pro card, then grouped
/// cards of rows — look and language (LOOK-1, LANG-1, QTY-5), cooking and
/// the plan (SCALE-5, PLAN-1, RAM-1–RAM-3), your data (BAK-1–BAK-10), ads
/// and the subscription (PAY-5, PAY-11, ADS-5), and about (RUN-4, the
/// privacy policy, contact, the version). Each choice row opens a sheet
/// with its options, the current one ticked; every change applies at once,
/// without a restart (LANG-1). A tab of its own, so it never carries a
/// banner (ADS-9).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SettingsState>();
    final plan = context.watch<PlanState>();
    final theme = Theme.of(context);
    final decor = Decor.of(context);
    final s = state.settings;
    void set(AppSettings next) => state.update(next);
    // RAM-2: null until the calendar (ramadanTable) has this year's dates.
    // ramadanMonthForShiftRowAt, not ramadanFor: this row's own year must
    // stay put while its shift is being edited, even right at the
    // boundary where that shift makes "today" Eid (should-fix).
    final ramadanMonth = plan.ramadanMonthForShiftRowAt(plan.today);
    // Pushed as a route from somewhere else, it gets a way back; as the
    // navigation pill's own tab it needs none (LOOK-7).
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    final lookNames = {
      AppStyle.saffron: l10n.lookSaffron,
      AppStyle.ink: l10n.lookInk,
    };
    final themeNames = {
      ThemePref.system: l10n.themeSystem,
      ThemePref.light: l10n.themeLight,
      ThemePref.dark: l10n.themeDark,
    };
    final languageNames = {
      LanguagePref.system: l10n.languageSystem,
      LanguagePref.ar: 'العربية', // each language in its own name
      LanguagePref.en: 'English',
    };
    final unitNames = {
      UnitSystem.metric: l10n.unitsMetric,
      UnitSystem.kitchen: l10n.unitsKitchen,
    };
    final weekStartNames = {
      WeekStart.auto: l10n.weekStartAuto,
      WeekStart.saturday: l10n.saturday,
      WeekStart.sunday: l10n.sunday,
      WeekStart.monday: l10n.monday,
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsetsDirectional.fromSTEB(
            decor.gutter,
            canPop ? 4 : 16,
            decor.gutter,
            32,
          ),
          children: [
            Row(
              children: [
                if (canPop) const BackButton(),
                Expanded(
                  child: Semantics(
                    header: true,
                    // Pushed as a route of its own, its title names it.
                    namesRoute: canPop,
                    child: Text(
                      l10n.settings,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _ProCard(),
            _Section(
              title: l10n.settingsGroupLook,
              children: [
                // LOOK-1: independent of المظهر (light/dark) below, and
                // applied at once, since `set` rebuilds the app's theme
                // through the same Consumer as every other row here.
                _Row(
                  icon: Icons.contrast,
                  label: l10n.settingsLook,
                  value: lookNames[s.style],
                  valueLeading: _AccentDot(color: theme.colorScheme.primary),
                  onTap: () => _choose<AppStyle>(
                    context,
                    title: l10n.settingsLook,
                    value: s.style,
                    options: lookNames,
                    leading: (style) => _AccentDot(
                      size: 28,
                      color: sufraAccent(style, theme.brightness).accent,
                    ),
                    onChosen: (v) => set(s.copyWith(style: v)),
                  ),
                ),
                _Row(
                  icon: Icons.light_mode_outlined,
                  label: l10n.settingsTheme,
                  value: themeNames[s.theme],
                  onTap: () => _choose<ThemePref>(
                    context,
                    title: l10n.settingsTheme,
                    value: s.theme,
                    options: themeNames,
                    onChosen: (v) => set(s.copyWith(theme: v)),
                  ),
                ),
                _Row(
                  icon: Icons.language,
                  label: l10n.settingsLanguage,
                  value: languageNames[s.language],
                  onTap: () => _choose<LanguagePref>(
                    context,
                    title: l10n.settingsLanguage,
                    value: s.language,
                    options: languageNames,
                    onChosen: (v) => set(s.copyWith(language: v)),
                  ),
                ),
                // QTY-5, Decision 5: a toggle, not a picker — inline.
                _Row(
                  icon: Icons.onetwothree,
                  label: l10n.settingsDigits,
                  mergeSemantics: false,
                  trailing: SegmentedPill<DigitStyle>(
                    dense: true,
                    options: const {
                      DigitStyle.western: '123',
                      DigitStyle.arabic: '١٢٣',
                    },
                    value: s.digits,
                    onChanged: (v) => set(s.copyWith(digits: v)),
                  ),
                ),
              ],
            ),
            _Section(
              title: l10n.settingsGroupCooking,
              children: [
                _Row(
                  icon: Icons.tune,
                  label: l10n.settingsUnits,
                  value: unitNames[s.units],
                  onTap: () => _choose<UnitSystem>(
                    context,
                    title: l10n.settingsUnits,
                    value: s.units,
                    options: unitNames,
                    onChosen: (v) => set(s.copyWith(units: v)),
                  ),
                ),
                // PLAN-1: the day the plan's week starts on.
                _Row(
                  icon: Icons.calendar_today_outlined,
                  label: l10n.settingsWeekStart,
                  value: weekStartNames[s.weekStart],
                  onTap: () => _choose<WeekStart>(
                    context,
                    title: l10n.settingsWeekStart,
                    value: s.weekStart,
                    options: weekStartNames,
                    onChosen: (v) => set(s.copyWith(weekStart: v)),
                  ),
                ),
                // RAM-1, RAM-3: the mode never turns itself on; this switch
                // is where it's turned on and off.
                _Row(
                  icon: Icons.dark_mode_outlined,
                  label: l10n.ramadanModeLabel,
                  onTap: () => set(s.copyWith(ramadanMode: !s.ramadanMode)),
                  trailing: Switch(
                    value: s.ramadanMode,
                    onChanged: (v) => set(s.copyWith(ramadanMode: v)),
                  ),
                ),
                // RAM-2: the shift shows whether the mode is on or off. It
                // also moves RAM-3's countdown and the Eid label, which
                // show while the mode is off, so its control never hides.
                if (ramadanMonth != null)
                  _RamadanShiftRow(
                    settings: s,
                    month: ramadanMonth,
                    onChanged: set,
                  ),
              ],
            ),
            const _BackupSection(),
            const _PayingSection(),
            const _AboutSection(),
          ],
        ),
      ),
    );
  }
}

/// RAM-2: this year's first day, one day earlier or later for the local
/// moon sighting. RAM-5: no prayer or iftar times here, and nothing that
/// needs a permission the release build doesn't already declare (RUN-2).
class _RamadanShiftRow extends StatelessWidget {
  const _RamadanShiftRow({
    required this.settings,
    required this.month,
    required this.onChanged,
  });

  final AppSettings settings;
  final RamadanMonth month;
  final ValueChanged<AppSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final shift = settings.ramadanShiftFor(month.hijriYear);
    AppSettings shifted(int by) => settings.copyWith(
      ramadanShift: shift + by,
      ramadanShiftYear: month.hijriYear,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _Row.minHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(_Row.textStart, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.ramadanStartLabel(
                  state.inDigits(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(month.start),
                  ),
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.ramadanShiftEarlier,
              icon: const Icon(Icons.remove),
              onPressed: shift > -1 ? () => onChanged(shifted(-1)) : null,
            ),
            IconButton(
              tooltip: l10n.ramadanShiftLater,
              icon: const Icon(Icons.add),
              onPressed: shift < 1 ? () => onChanged(shifted(1)) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// BAK-1–BAK-10: save, share, restore and export, the reminder switch
/// (BAK-8), and the latest automatic backups (BAK-2, BAK-7). The flow
/// itself — busy, the last result, the last error, and every call into the
/// backup engine and its save/open dialogs — lives in [BackupState] (CLAUDE.md:
/// screens stay presentational); this widget keeps only the UI: the
/// buttons, the two-step "استبدال" confirmation (BAK-7), the progress
/// indicator, and picking a message for whatever [BackupState] reports.
/// Still its own [StatefulWidget], only so [initState] can trigger the
/// automatic-backups list load the moment this section is first built,
/// exactly as it always has.
class _BackupSection extends StatefulWidget {
  const _BackupSection();

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  @override
  void initState() {
    super.initState();
    context.read<BackupState>().loadAutoBackups();
  }

  Future<void> _save() => context.read<BackupState>().guarded(() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await saveBackupNow(context);
    if (!saved || !mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.backupSaveDone)));
  });

  /// BAK-6: shares the same zip [saveBackupNow] would save (BackupState.
  /// share, over SHARE-4's own cache folder), then hands it to the share
  /// sheet. Sharing is the other way a backup can leave the phone
  /// (principle 2), so it counts as "the last backup" too, same as Save
  /// (should-fix, platform review: this used to never update it, so BAK-8
  /// kept reminding someone who only ever shares).
  Future<void> _share() => context.read<BackupState>().guarded(() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<BackupState>().share();
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.backupShareFailed)));
    }
  });

  Future<void> _restore() => context.read<BackupState>().guarded(() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    List<int>? bytes;
    try {
      bytes = await context.read<BackupState>().openFile();
    } on BackupFilesError {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.backupErrorCantOpen)));
      return;
    }
    if (bytes == null || !mounted) return;
    await _handleRestore(bytes);
  });

  Future<void> _restoreAuto(AutoBackup auto) =>
      context.read<BackupState>().guarded(() async {
        final bytes = await context.read<BackupState>().readAutoBackup(auto);
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
      preview = await context.read<BackupState>().inspect(bytes);
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
    final settingsState = context.read<SettingsState>();
    final recipes = context.read<RecipesState>();
    final plan = context.read<PlanState>();
    final groceries = context.read<GroceryState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      // should-fix, platform review: an automatic backup lives only in this
      // phone's own storage (BAK-9 excludes it from Android's device
      // backup), so restoring — merge or replace — is never itself a copy
      // that has left the phone. Only Save and Share (principle 2) count as
      // "the last backup" for BAK-8's reminder — finishRestore reloads
      // BackupState's own [autoBackups] list, not [lastBackupAt].
      final result = await context.read<BackupState>().finishRestore(
        bytes,
        mode: mode,
      );
      // Every screen that reads this data reloads (CLAUDE.md), not just
      // the recipe list: the plan, groceries and settings can all have
      // changed underneath them.
      await recipes.load();
      await plan.showWeek(plan.weekStart);
      await groceries.load();
      await settingsState.load();
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
  Future<void> _export() => context.read<BackupState>().guarded(() async {
    final l10n = AppLocalizations.of(context);
    final recipesState = context.read<RecipesState>();
    final settingsState = context.read<SettingsState>();
    final backupState = context.read<BackupState>();
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
        l10n.prepTime(l10n.minutes(m, settingsState.number(m)));
    String cookTimeLabel(int m) =>
        l10n.cookTime(l10n.minutes(m, settingsState.number(m)));
    String unscaledLineText(String line, String mark) =>
        l10n.shareUnscaledLine(line, mark);

    final text = backupState.exportText(
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
    final name = _exportFileName(backupState.now());
    try {
      final saved = await backupState.exportBytes(
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
    final state = context.watch<SettingsState>();
    final s = state.settings;
    final backupState = context.watch<BackupState>();
    final busy = backupState.busy;
    final autoBackups = backupState.autoBackups;
    final localizations = MaterialLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: l10n.settingsGroupData,
          busy: busy,
          children: [
            _Row(
              icon: Icons.save_outlined,
              label: l10n.backupSaveAction,
              enabled: !busy,
              onTap: () => _save(),
            ),
            _Row(
              icon: Icons.ios_share_outlined,
              label: l10n.backupShareAction,
              enabled: !busy,
              onTap: () => _share(),
            ),
            _Row(
              icon: Icons.restore_outlined,
              label: l10n.backupRestoreAction,
              enabled: !busy,
              onTap: () => _restore(),
            ),
            _Row(
              icon: Icons.description_outlined,
              label: l10n.backupExportAction,
              enabled: !busy,
              onTap: () => _export(),
            ),
            // BAK-8: off for good here; "لاحقًا" on the card only snoozes.
            _Row(
              icon: Icons.notifications_none_outlined,
              label: l10n.backupReminderSwitch,
              onTap: () => state.update(
                s.copyWith(backupReminderOff: !s.backupReminderOff),
              ),
              trailing: Switch(
                value: !s.backupReminderOff,
                onChanged: (v) =>
                    state.update(s.copyWith(backupReminderOff: !v)),
              ),
            ),
          ],
        ),
        // BAK-2, BAK-7: the copies made before every restore.
        _Section(
          title: l10n.backupAutoSection,
          children: [
            if (autoBackups == null)
              const Padding(
                padding: EdgeInsetsDirectional.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (autoBackups.isEmpty)
              _Row(icon: Icons.history, label: l10n.backupAutoEmpty)
            else
              for (final auto in autoBackups)
                _Row(
                  icon: Icons.history,
                  // should-fix, platform review: a restore makes a new one
                  // at once, so same-day rows used to read identically
                  // ("نسخة السبت، ١٩ سبتمبر" twice); the time tells them
                  // apart.
                  label: l10n.backupAutoBackupDate(
                    state.inDigits(
                      localizations.formatMediumDate(auto.createdAt.toLocal()),
                    ),
                    state.inDigits(
                      localizations.formatTimeOfDay(
                        TimeOfDay.fromDateTime(auto.createdAt.toLocal()),
                      ),
                    ),
                  ),
                  mergeSemantics: false,
                  trailing: TextButton(
                    onPressed: busy ? null : () => _restoreAuto(auto),
                    child: Text(l10n.backupRestoreAction),
                  ),
                ),
          ],
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

/// BAK-6, BAK-8: saves a backup through [BackupState.save] and shows the
/// failure message itself. Shared by this screen's own button and the
/// library's reminder card ("احفظ الآن", BAK-8), so both behave identically.
/// True if the user actually saved it; false both when they cancelled and
/// when saving failed outright (must-fix, platform review: a thrown
/// [BackupFilesError] or any other I/O failure used to escape uncaught
/// here, showing nothing and — for the reminder card — leaving its buttons
/// disabled for good).
Future<bool> saveBackupNow(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    return await context.read<BackupState>().save();
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.backupSaveFailed)));
    return false;
  }
}

/// PAY-5, PAY-10: the Pro card at the top — what Pro and Premium give, in
/// one line, opening the purchase screen. No price, no badge, no countdown;
/// once something is owned it says what, instead of selling.
class _ProCard extends StatelessWidget {
  const _ProCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final purchases = context.watch<PurchasesState>();
    final settings = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const quota = PurchasesState.premiumAiImportsPerMonth;
    final count = settings.number(quota);
    final body = switch (purchases.tier) {
      Tier.free => l10n.settingsProCardBody(count),
      Tier.pro => l10n.settingsProCardOwnsPro,
      Tier.premium => l10n.settingsProCardOwnsPremium(quota, count),
      Tier.proAndPremium => l10n.settingsProCardOwnsBoth(quota, count),
    };
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: SufraCard(
          radius: 24,
          onTap: () => openPurchaseScreen(context),
          padding: const EdgeInsetsDirectional.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.purchaseTitle, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// PAY-5, PAY-11: the "Subscription" row with the plan it's on, opening
/// the purchase screen; "Manage or cancel" while Premium is owned, which
/// opens Google Play's page for it (two taps from Settings: this row, then
/// Play's own cancel); "Restore purchases" (PAY-1); and ADS-5's row to
/// change the ad consent, where the law asks.
class _PayingSection extends StatelessWidget {
  const _PayingSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final purchases = context.watch<PurchasesState>();
    final ads = context.watch<AdsState>();
    final plan = switch (purchases.tier) {
      Tier.free => l10n.tierFree,
      Tier.pro => l10n.purchasePro,
      Tier.premium => l10n.purchasePremium,
      Tier.proAndPremium => l10n.purchaseTitle,
    };
    return _Section(
      title: l10n.settingsPayingSection,
      children: [
        _Row(
          icon: Icons.workspace_premium_outlined,
          label: l10n.settingsSubscription,
          value: plan,
          onTap: () => openPurchaseScreen(context),
        ),
        if (purchases.ownsPremium)
          _Row(
            icon: Icons.open_in_new,
            label: l10n.purchaseManage,
            onTap: () => manageSubscription(context),
          ),
        _Row(
          icon: Icons.restore,
          label: l10n.purchaseRestore,
          onTap: () => restorePurchases(context),
        ),
        if (ads.showPrivacyChoices)
          _Row(
            icon: Icons.privacy_tip_outlined,
            label: l10n.settingsAdPrivacy,
            onTap: ads.changeConsent,
          ),
      ],
    );
  }
}

/// RUN-4's replay, the privacy policy, the one support address
/// (CLAUDE.md: never a personal one) and the app's version.
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  Future<void> _openPolicy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final opened = await context.read<LinkOpener>().open(
      Uri.parse(privacyPolicyUrl),
    );
    if (opened) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.linkOpenFailed)));
  }

  /// A draft the user reads and sends themselves (Decision 19); with no
  /// mail app, the address to write to instead.
  Future<void> _contact(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final opened = await context.read<MailComposer>().compose(
      to: supportEmail,
      subject: l10n.appTitle,
      body: '',
    );
    if (opened) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.reportMistakeNoMailApp(supportEmail))),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final version = context.read<BackupService>().appVersion;
    return _Section(
      title: l10n.settingsGroupAbout,
      children: [
        // RUN-4: the walkthrough can be replayed; it just closes at the
        // end, and changes nothing.
        _Row(
          icon: Icons.auto_stories_outlined,
          label: l10n.settingsReplayWalkthrough,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const WalkthroughScreen()),
          ),
        ),
        _Row(
          icon: Icons.shield_outlined,
          label: l10n.settingsPrivacyPolicy,
          onTap: () => _openPolicy(context),
        ),
        _Row(
          icon: Icons.mail_outline,
          label: l10n.settingsContact,
          subtitle: supportEmail,
          onTap: () => _contact(context),
        ),
        _Row(
          icon: Icons.info_outline,
          label: l10n.settingsVersion,
          value: version,
          valueIsLtr: true,
        ),
      ],
    );
  }
}

/// A small caption heading over one card of rows, the rows split by
/// hairlines that start where their text does (design-styles.md,
/// "Settings").
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.busy = false,
  });

  final String title;
  final List<Widget> children;

  /// True while this card's work runs (a backup, BAK-6): a thin progress
  /// line under the heading, beside the rows' own disabled look.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = Decor.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 2,
            child: busy
                ? LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(999),
                  )
                : null,
          ),
          SufraCard(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, row) in children.indexed) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: _Row.textStart,
                        endIndent: 16,
                        color:
                            decor.rowHairline ??
                            theme.colorScheme.outlineVariant,
                      ),
                    row,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One Settings row, at least 60dp: a 36dp tinted rounded-square icon tile,
/// the label (and an optional line under it), the current value, and a
/// chevron when it opens something — or [trailing] instead (a switch, the
/// digits pill). Label and value are read together as one button.
///
/// The label takes the row's free width; the value and chevron hug the end
/// edge (08-settings.png), so every chevron in a card lines up, and a value
/// wraps only once it passes [valueMaxShare] of the row (LOOK-8 at 1.3x).
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.subtitle,
    this.value,
    this.valueLeading,
    this.valueIsLtr = false,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.mergeSemantics = true,
  });

  static const minHeight = 60.0;

  /// Where a row's text starts: 16 padding + the 36dp tile + a 12dp gap.
  static const textStart = 64.0;

  /// The most of the row's inner width a value may take before it wraps.
  static const valueMaxShare = 0.45;

  final IconData icon;
  final String label;
  final String? subtitle;
  final String? value;
  final Widget? valueLeading;
  final bool valueIsLtr;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// False while the row can't be used (the backup rows during a backup,
  /// BAK-6): drawn in LOOK-3's disabled colour, its chevron kept in place,
  /// and read as a disabled button.
  final bool enabled;

  /// False when [trailing] holds controls of its own (the digits pill, a
  /// restore button) that a screen reader must reach one by one.
  final bool mergeSemantics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final decor = Decor.of(context);
    final value = this.value;
    final subtitle = this.subtitle;
    // LOOK-3: the theme's disabled colour, already composited to 3:1.
    final muted = enabled ? null : theme.disabledColor;
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: muted ?? cs.onSurfaceVariant,
    );
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minHeight),
      child: Padding(
        // 6dp above and below: a 48dp control (a switch, the digits pill)
        // makes exactly the 60dp every other row has.
        padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 12, 6),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: enabled ? cs.primaryContainer : decor.sunk,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: muted ?? cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(color: muted),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: secondary,
                        textDirection: TextDirection.ltr,
                      ),
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * valueMaxShare,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (valueLeading != null) ...[
                        valueLeading!,
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          value,
                          style: secondary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          textDirection: valueIsLtr ? TextDirection.ltr : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: muted ?? cs.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
    if (onTap != null || trailing == null) {
      row = InkWell(onTap: enabled ? onTap : null, child: row);
    }
    if (!mergeSemantics) return row;
    final isButton = onTap != null && trailing == null;
    return MergeSemantics(
      child: Semantics(
        button: isButton,
        enabled: isButton ? enabled : null,
        child: row,
      ),
    );
  }
}

/// LOOK-1: an accent colour's swatch — beside الطراز's value, and larger
/// beside each option in its sheet.
class _AccentDot extends StatelessWidget {
  const _AccentDot({required this.color, this.size = 14});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// A choice row's sheet: its options, the current one ticked. Choosing
/// one closes the sheet and applies it at once (LANG-1, LOOK-1).
Future<void> _choose<T>(
  BuildContext context, {
  required String title,
  required T value,
  required Map<T, String> options,
  required ValueChanged<T> onChosen,
  Widget Function(T option)? leading,
}) async {
  final chosen = await showModalBottomSheet<T>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 8),
                child: Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.headlineSmall),
                ),
              ),
              for (final e in options.entries)
                ListTile(
                  minTileHeight: 56,
                  leading: leading?.call(e.key),
                  title: Text(e.value),
                  selected: e.key == value,
                  trailing: e.key == value
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, e.key),
                ),
            ],
          ),
        ),
      );
    },
  );
  if (chosen != null && chosen != value) onChosen(chosen);
}
