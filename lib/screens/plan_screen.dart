import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/grocery.dart';
import '../models/library.dart';
import '../models/plan.dart';
import '../models/quantity/format.dart' show factorLabel;
import '../models/quantity/rational.dart';
import '../models/ramadan.dart';
import '../models/settings.dart';
import '../providers/grocery_state.dart';
import '../providers/plan_state.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../theme/decor.dart';
import '../widgets/content_direction.dart';
import '../widgets/digit_counter.dart';
import '../widgets/empty_state.dart';
import 'home_screen.dart';

/// The meal plan: one week at a time, four meals a day (PLAN-1). Adding,
/// moving and removing never touch the recipe itself (PLAN-3, PLAN-4).
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

/// The meal the add sheet offers first: the one last used (PLAN-3).
MealSlot _lastMeal = MealSlot.lunch;

class _PlanScreenState extends State<PlanScreen> {
  final _todayKey = GlobalKey();
  int? _firstWeekday;

  /// RAM-4: "الأسبوع" or "رمضان" — only meaningful while the toggle shows.
  bool _monthView = false;

  /// The week showing before switching to the Ramadan month, so "الأسبوع"
  /// comes back to it rather than always jumping to today's week (RAM-4).
  DateTime? _weekBeforeMonthView;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsState>().settings;
    final plan = context.read<PlanState>();
    // RAM-1, RAM-2: kept in step with Settings on every change, so entries
    // sort and label correctly (slotsFor) even before a week reloads. The
    // assignment PlanState makes is synchronous, so `plan.ramadanFor(...)`
    // below already sees it (should-fix: also mirrored in app.dart, so
    // Settings reads the right dates even when this screen isn't mounted).
    plan.setRamadanMode(
      settings.ramadanMode,
      shift: settings.ramadanShift,
      shiftYear: settings.ramadanShiftYear,
    );

    final first = _weekStartDay(context, settings);
    final weekChanged = first != _firstWeekday;
    _firstWeekday = first;

    if (_monthView) {
      final ramadanMonth = plan.ramadanFor(plan.today);
      final stillValid =
          settings.ramadanMode &&
          ramadanMonth != null &&
          inRamadanWindow(plan.today, ramadanMonth);
      if (!stillValid) {
        // must-fix: the "رمضان" toggle only exists in this window: it was
        // turned off in Settings, or today has moved past the last day
        // (Eid) or before the window opens. Without this, the screen got
        // stuck showing a month that no longer applies, with no way back
        // to a week short of toggling the mode off and on.
        _monthView = false;
        plan
            .showWeek(_weekBeforeMonthView ?? weekStartFor(plan.today, first))
            .then((_) {
              if (mounted) _scrollToToday();
            });
        return;
      }
      if (dateKey(plan.days.firstOrNull ?? DateTime(0)) !=
              dateKey(ramadanMonth.start) ||
          dateKey(plan.days.lastOrNull ?? DateTime(0)) !=
              dateKey(ramadanMonth.last)) {
        // must-fix: a moon-sighting shift moves the whole month even while
        // its view is open — reload so it doesn't keep showing yesterday's
        // range (a day short, or one day into what's no longer Ramadan).
        plan.showRange(ramadanMonth.start, ramadanMonth.last).then((_) {
          if (mounted) _scrollToToday();
        });
      }
      return;
    }
    if (!weekChanged) return;
    plan.showWeek(weekStartFor(plan.today, first)).then((_) {
      if (mounted) _scrollToToday();
    });
  }

  /// The week's first day: the setting, else the phone's region (PLAN-1).
  int _weekStartDay(BuildContext context, AppSettings settings) => firstWeekday(
    settings.weekStart,
    region: View.of(context).platformDispatcher.locale.countryCode,
    arabic: Localizations.localeOf(context).languageCode == 'ar',
  );

  /// RAM-4: switches between the week and the whole Ramadan month, which
  /// PlanState loads as an arbitrary range.
  Future<void> _setMonthView(bool month, RamadanMonth ramadanMonth) async {
    final plan = context.read<PlanState>();
    setState(() => _monthView = month);
    if (month) {
      _weekBeforeMonthView = plan.weekStart;
      await plan.showRange(ramadanMonth.start, ramadanMonth.last);
      // must-fix: switching to the month used to leave the scroll position
      // wherever it was (usually the top, day 1), so opening it on, say,
      // day 20 gave no way to see today without scrolling by hand.
      if (mounted) _scrollToToday();
    } else {
      await plan.showWeek(
        _weekBeforeMonthView ?? weekStartFor(plan.today, _firstWeekday!),
      );
      if (mounted) _scrollToToday();
    }
  }

  void _scrollToToday() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _todayKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.05,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  Future<void> _clearWeek() async {
    final l10n = AppLocalizations.of(context);
    final settings = context.read<SettingsState>();
    final messenger = ScaffoldMessenger.of(context);
    final plan = context.read<PlanState>();
    final ids = await plan.clearWeek();
    if (ids == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.planClearedCount(ids.length, settings.number(ids.length)),
          ),
          duration: const Duration(seconds: 5),
          action: ids.isEmpty
              ? null
              : SnackBarAction(
                  label: l10n.undo,
                  onPressed: () => plan.restore(ids),
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = context.watch<PlanState>();
    final settings = context.watch<SettingsState>();
    final dates = MaterialLocalizations.of(context);
    final days = plan.days;
    final range = days.isEmpty
        ? ''
        : '${settings.inDigits(dates.formatShortMonthDay(days.first))} – '
              '${settings.inDigits(dates.formatShortMonthDay(days.last))}';

    // RAM-3, RAM-4: both key off the current-or-next Ramadan relative to
    // today, from the calendar PlanState was given (RAM-2).
    final ramadanMonth = plan.ramadanFor(plan.today);
    final card = ramadanCard(
      ramadanMonth,
      plan.today,
      mode: settings.settings.ramadanMode,
      dismissedYear: settings.settings.ramadanCardDismissedYear,
    );
    final showMonthToggle =
        settings.settings.ramadanMode &&
        ramadanMonth != null &&
        inRamadanWindow(plan.today, ramadanMonth);
    // must-fix: the raw _monthView flag can briefly be stale (the toggle
    // just disappeared because today left the window, or the mode just
    // turned off) until didChangeDependencies's post-write catches up —
    // this is what the screen actually renders as "in the month view".
    final monthView = _monthView && showMonthToggle;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.planTitle),
        actions: [
          IconButton(
            tooltip: l10n.planThisWeek,
            icon: const Icon(Icons.today_outlined),
            // must-fix: kept working in the month view too — it used to
            // disappear there, with no other way to jump back to today
            // without scrolling by hand.
            onPressed: monthView
                ? _scrollToToday
                : () {
                    plan
                        .showWeek(weekStartFor(plan.today, _firstWeekday!))
                        .then((_) => _scrollToToday());
                  },
          ),
          IconButton(
            tooltip: l10n.addToGroceries,
            icon: const Icon(Icons.shopping_basket_outlined),
            onPressed: () => openPlanAddToGroceries(context),
          ),
          if (!monthView)
            PopupMenuButton<String>(
              onSelected: (_) => _clearWeek(),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'clear', child: Text(l10n.planClearWeek)),
              ],
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: monthView
              ? Center(
                  child: Text(
                    range,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: l10n.planPreviousWeek,
                      // Mirrors itself in right-to-left (matchTextDirection):
                      // it points to the reading start either way (LANG-5).
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => plan.shiftWeeks(-1),
                    ),
                    Flexible(
                      child: Text(
                        range,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.planNextWeek,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => plan.shiftWeeks(1),
                    ),
                  ],
                ),
        ),
      ),
      body: !plan.loaded
          ? const Center(child: CircularProgressIndicator())
          // must-fix: the card and the "الأسبوع"/"رمضان" toggle used to be
          // the first children of the scrolling list below, so opening on
          // today (never the first day shown, most weeks) scrolled them
          // off-screen at once — RAM-3's card and RAM-4's toggle were
          // invisible on open. They're pinned above the scrolling days
          // now, so nothing can carry them out of view.
          : Column(
              children: [
                if (card != null) _RamadanCard(card: card),
                if (showMonthToggle)
                  _RamadanViewToggle(
                    monthView: _monthView,
                    onChanged: (v) => _setMonthView(v, ramadanMonth),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsetsDirectional.only(bottom: 24),
                    child: Column(
                      children: [
                        if (plan.entries.isEmpty) _EmptyPlan(l10n: l10n),
                        for (final day in days)
                          _DayCard(
                            key: dateKey(day) == dateKey(plan.today)
                                ? _todayKey
                                : null,
                            day: day,
                            isToday: dateKey(day) == dateKey(plan.today),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// RAM-3: the countdown or "كريم" card, with "تفعيل" and "ليس الآن". The
/// mode never turns itself on; only this button does.
class _RamadanCard extends StatelessWidget {
  const _RamadanCard({required this.card});
  final RamadanCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = context.read<SettingsState>();
    final text = card.started
        ? l10n.ramadanCardNow
        : l10n.ramadanCardSoon(card.daysUntil, settings.number(card.daysUntil));
    return Card(
      margin: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => settings.update(
                    settings.settings.copyWith(
                      ramadanCardDismissedYear: card.month.hijriYear,
                    ),
                  ),
                  child: Text(l10n.ramadanCardNotNow),
                ),
                FilledButton(
                  onPressed: () => settings.update(
                    settings.settings.copyWith(ramadanMode: true),
                  ),
                  child: Text(l10n.ramadanCardEnable),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// RAM-4: "الأسبوع" / "رمضان", shown from 7 days before Ramadan through
/// its end while the mode is on.
class _RamadanViewToggle extends StatelessWidget {
  const _RamadanViewToggle({required this.monthView, required this.onChanged});

  final bool monthView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
      child: Center(
        child: SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l10n.planViewWeek)),
            ButtonSegment(value: true, label: Text(l10n.planViewRamadan)),
          ],
          selected: {monthView},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => EmptyState(
    title: l10n.planEmptyTitle,
    body: l10n.planEmptyBody,
    // Sits inside the week's own scrolling Column, above the day cards,
    // which still render below it — never the sole content of the screen.
    scrollable: false,
  );
}

class _DayCard extends StatelessWidget {
  const _DayCard({super.key, required this.day, required this.isToday});

  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = context.watch<SettingsState>();
    final plan = context.watch<PlanState>();
    final label = settings.inDigits(
      MaterialLocalizations.of(context).formatMediumDate(day),
    );
    // RAM-2: only with the mode on, so it can stay on all year without
    // marking days outside any Ramadan.
    final ramadanMonth = plan.ramadanMode ? plan.ramadanMonthOf(day) : null;
    final hijriLabel = !plan.ramadanMode
        ? null
        : plan.isEid(day)
        ? l10n.ramadanEidLabel
        : ramadanMonth == null
        ? null
        : l10n.ramadanDayLabel(settings.number(ramadanMonth.dayOf(day)!));
    // RAM-1: suhoor, iftar, snack on a Ramadan day; the usual four
    // otherwise — either way, plus any slot that already holds an entry.
    final slots = slotsFor(
      day,
      ramadan: plan.ramadanMode,
      month: ramadanMonth,
      withEntries: plan.slotsWithEntries(day),
    );
    final decor = Decor.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
      // LOOK-6: the look's grouped-row fill and card shape, in place of a
      // Card washed with a translucent tint; a Material, so each entry's
      // ink still paints on it. Today keeps its bold date and "اليوم", and
      // gains the look's rail down its reading edge. The Semantics container
      // is the one Card added, so a screen reader still reads each day as
      // one group: its date, "اليوم", its meals, then its add buttons.
      child: Semantics(
        container: true,
        child: Material(
          color: decor.groupedRowFill,
          shape: decor.cardShape,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        4,
                        16,
                        4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : null,
                                  ),
                                ),
                                if (hijriLabel != null)
                                  Text(
                                    hijriLabel,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isToday)
                            Text(
                              l10n.planToday,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final slot in slots) _SlotRow(day: day, slot: slot),
                  ],
                ),
              ),
              if (isToday && decor.railWidth > 0)
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: decor.railWidth,
                  child: ColoredBox(color: decor.railColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.day, required this.slot});

  final DateTime day;
  final MealSlot slot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entries = context.watch<PlanState>().entriesFor(day, slot);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: 10),
              child: Text(
                mealName(l10n, slot),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final e in entries) _EntryTile(entry: e)],
            ),
          ),
          IconButton(
            tooltip: l10n.planAdd,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add),
            onPressed: () => _addToSlot(context, day, slot),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final PlanEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsState>();
    final recipes = context.watch<RecipesState>();
    final LibraryEntry? recipe = entry.isNote
        ? null
        : recipes.recipes.where((r) => r.id == entry.recipeId).firstOrNull;
    final title = entry.isNote ? entry.note! : (recipe?.title ?? '');
    final amount = entry.servings != null
        ? l10n.servings(entry.servings!, settings.number(entry.servings!))
        : entry.multiplier != null && entry.multiplier != Rational.one
        ? factorLabel(entry.multiplier!, settings.digits)
        : null;

    return InkWell(
      onTap: entry.isNote
          ? () => _entryMenu(context, entry)
          : () => openRecipe(context, entry.recipeId!),
      onLongPress: () => _entryMenu(context, entry),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: 8,
          horizontal: 4,
        ),
        child: Row(
          children: [
            Icon(
              entry.isNote ? Icons.sticky_note_2_outlined : Icons.restaurant,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            // The amount sits at the end of the title's line, or drops
            // below it when the two don't fit side by side: never an
            // overflow at 1.3x text on a 360dp phone (LANG-6).
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  ContentText(title),
                  // The ambient direction: "٦ حصص" reads right to left, and
                  // a "×2" carries its own left-to-right isolate (LANG-5).
                  if (amount != null)
                    Text(
                      amount,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The name of a meal slot (PLAN-1); [suhoor] and [iftar] only ever show
/// on a Ramadan day (RAM-1, decision 9).
String mealName(AppLocalizations l10n, MealSlot slot) => switch (slot) {
  MealSlot.breakfast => l10n.mealBreakfast,
  MealSlot.lunch => l10n.mealLunch,
  MealSlot.dinner => l10n.mealDinner,
  MealSlot.snack => l10n.mealSnack,
  MealSlot.suhoor => l10n.mealSuhoor,
  MealSlot.iftar => l10n.mealIftar,
};

/// A slot's "+": a recipe, or a written note (PLAN-2, PLAN-3).
Future<void> _addToSlot(
  BuildContext context,
  DateTime day,
  MealSlot slot,
) async {
  final l10n = AppLocalizations.of(context);
  final plan = context.read<PlanState>();
  final recipes = context.read<RecipesState>();
  final settings = context.read<SettingsState>();
  if (plan.entriesFor(day, slot).length >= PlanEntry.maxPerSlot) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.planSlotFull(settings.number(PlanEntry.maxPerSlot))),
      ),
    );
    return;
  }
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: Text(l10n.planAddRecipe),
            onTap: () => Navigator.pop(ctx, 'recipe'),
          ),
          ListTile(
            leading: const Icon(Icons.sticky_note_2_outlined),
            title: Text(l10n.planAddNote),
            onTap: () => Navigator.pop(ctx, 'note'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  _lastMeal = slot;

  if (choice == 'note') {
    final note = await askPlanNote(context);
    if (note == null) return;
    await plan.add(date: day, slot: slot, note: note);
    return;
  }
  final recipeId = await pickRecipe(context);
  if (recipeId == null) return;
  await plan.add(
    date: day,
    slot: slot,
    recipeId: recipeId,
    servings: await recipes.repository.servingsOf(recipeId),
  );
}

/// Move, copy, change the amount, or remove (PLAN-2, PLAN-4).
Future<void> _entryMenu(BuildContext context, PlanEntry entry) async {
  final l10n = AppLocalizations.of(context);
  final plan = context.read<PlanState>();
  final messenger = ScaffoldMessenger.of(context);
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!entry.isNote)
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(
                entry.servings != null ? l10n.fieldServings : l10n.planAmount,
              ),
              onTap: () => Navigator.pop(ctx, 'amount'),
            ),
          ListTile(
            // This icon doesn't mirror itself (LANG-5).
            leading: Icon(
              Directionality.of(ctx) == TextDirection.rtl
                  ? Icons.drive_file_move_rtl_outlined
                  : Icons.drive_file_move_outline,
            ),
            title: Text(l10n.planMove),
            onTap: () => Navigator.pop(ctx, 'move'),
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: Text(l10n.planCopy),
            onTap: () => Navigator.pop(ctx, 'copy'),
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: Text(l10n.planRemove),
            onTap: () => Navigator.pop(ctx, 'remove'),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case 'amount':
      await _askAmount(context, entry);
    case 'move':
    case 'copy':
      // RAM-4, should-fix: from the "رمضان" month view, offer every day
      // still shown, from today on, not just the usual 7 — otherwise an
      // entry on day 3 could never move or copy to day 20. The entry's
      // own day is always included, even if it's already gone by.
      final monthDays = plan.days.length > 7
          ? ({
              for (final d in plan.days)
                if (!d.isBefore(plan.today)) d,
              dateOnly(entry.date),
            }.toList()..sort())
          : null;
      final where = await _askDayAndMeal(
        context,
        title: action == 'move' ? l10n.planMove : l10n.planCopy,
        day: entry.date,
        slot: entry.slot,
        dayOptions: monthDays,
        // RAM-1: the entry's own slot stays offered and selected while
        // its own day is picked, even if that day would otherwise hide
        // it (an entry sitting in an ordinary slot on a Ramadan day).
        homeSlot: entry.slot,
      );
      if (where != null) {
        await plan.moveTo(entry, where.$1, where.$2, copy: action == 'copy');
      }
    case 'remove':
      if (await plan.remove(entry.id)) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.planRemoved),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: l10n.undo,
                onPressed: () => plan.restore([entry.id]),
              ),
            ),
          );
      }
  }
}

/// Servings for a recipe entry, or the multiplier when it has none
/// (PLAN-2, SCALE-2).
Future<void> _askAmount(BuildContext context, PlanEntry entry) async {
  final l10n = AppLocalizations.of(context);
  final settings = context.read<SettingsState>();
  final plan = context.read<PlanState>();
  if (entry.servings == null) {
    final picked = await showModalBottomSheet<Rational>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (final m in PlanEntry.multipliers)
                ChoiceChip(
                  label: Text(factorLabel(m, settings.digits)),
                  selected: (entry.multiplier ?? Rational.one) == m,
                  onSelected: (_) => Navigator.pop(ctx, m),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) await plan.setAmount(entry, multiplier: picked);
    return;
  }
  var count = entry.servings!;
  final chosen = await showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInner) => AlertDialog(
        title: Text(l10n.fieldServings),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.servingsLess,
              icon: const Icon(Icons.remove),
              onPressed: count > 1 ? () => setInner(() => count--) : null,
            ),
            Text(settings.number(count), style: const TextStyle(fontSize: 20)),
            IconButton(
              tooltip: l10n.servingsMore,
              icon: const Icon(Icons.add),
              onPressed: count < PlanEntry.maxServings
                  ? () => setInner(() => count++)
                  : null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, count),
            child: Text(l10n.save),
          ),
        ],
      ),
    ),
  );
  if (chosen != null) await plan.setAmount(entry, servings: chosen);
}

/// The note text of a written entry (PLAN-2): 1–60 characters.
Future<String?> askPlanNote(BuildContext context, {String initial = ''}) {
  final l10n = AppLocalizations.of(context);
  final settings = context.read<SettingsState>();
  final controller = TextEditingController(text: initial);
  final form = GlobalKey<FormState>();
  void submit(BuildContext ctx) {
    if (form.currentState!.validate()) {
      Navigator.pop(ctx, controller.text.trim());
    }
  }

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.planAddNote),
      content: Form(
        key: form,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          maxLength: PlanEntry.maxNote,
          buildCounter: digitCounter,
          decoration: InputDecoration(
            labelText: l10n.planNoteLabel,
            hintText: l10n.planNoteHint,
          ),
          validator: (v) => (v ?? '').trim().isEmpty
              ? l10n.planNoteInvalid(
                  settings.number(1),
                  settings.number(PlanEntry.maxNote),
                )
              : null,
          onFieldSubmitted: (_) => submit(ctx),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: () => submit(ctx), child: Text(l10n.save)),
      ],
    ),
  );
}

/// The library, searchable (ORG-3), to pick one recipe (PLAN-3).
Future<String?> pickRecipe(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      var text = '';
      return SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setInner) {
            final hits = ctx.read<RecipesState>().query(
              LibraryQuery(text: text),
            );
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.all(12),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.searchHint,
                      ),
                      onChanged: (v) => setInner(() => text = v),
                    ),
                  ),
                  Flexible(
                    child: hits.isEmpty
                        ? Padding(
                            padding: const EdgeInsetsDirectional.all(24),
                            child: Text(l10n.noResults),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: hits.length,
                            itemBuilder: (_, i) => ListTile(
                              title: ContentText(hits[i].entry.title),
                              onTap: () => Navigator.pop(ctx, hits[i].entry.id),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

/// Day and meal chips, for "Add to plan" and for moving an entry (PLAN-3).
/// [dayOptions] overrides the default 7-day-from-today list (RAM-4, so the
/// month view can offer its own days). [homeSlot], for move/copy only,
/// keeps that entry's own slot offered and selected while its own day is
/// picked, even where it wouldn't normally be offered (RAM-1).
Future<(DateTime, MealSlot)?> _askDayAndMeal(
  BuildContext context, {
  required String title,
  required DateTime day,
  required MealSlot slot,
  List<DateTime>? dayOptions,
  MealSlot? homeSlot,
}) {
  final l10n = AppLocalizations.of(context);
  final settings = context.read<SettingsState>();
  final dates = MaterialLocalizations.of(context);
  final plan = context.read<PlanState>();
  final today = plan.today;
  final options =
      dayOptions ??
      [
        for (var i = 0; i < 7; i++)
          DateTime(today.year, today.month, today.day + i),
      ];
  final originalDay = dateOnly(day);
  var pickedDay = originalDay;
  var pickedSlot = slot;

  // The slots a given day really offers (RAM-1): [homeSlot] is only ever
  // forced into that list on its own day, so it doesn't leak into every
  // other day's chips once the day chip changes.
  List<MealSlot> offeredSlots(DateTime d) => slotsFor(
    d,
    ramadan: plan.ramadanMode,
    month: plan.ramadanMonthOf(d),
    withEntries: homeSlot != null && dateKey(d) == dateKey(originalDay)
        ? {...plan.slotsWithEntries(d), homeSlot}
        : plan.slotsWithEntries(d),
  );
  // must-fix: the preselected meal (the add sheet's "last meal used", or
  // an entry's own slot on a different day than it's being moved to)
  // isn't always one the opening day actually offers — map it onto that
  // day's real slots up front, not only once the user touches a day chip.
  final initialOffered = offeredSlots(pickedDay);
  if (!initialOffered.contains(pickedSlot)) {
    pickedSlot = slotOnDay(pickedSlot, initialOffered);
  }

  return showModalBottomSheet<(DateTime, MealSlot)>(
    context: context,
    // The chips wrap over several rows, and grow with the text size
    // (LANG-6), so the sheet scrolls instead of overflowing.
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: StatefulBuilder(
        builder: (ctx, setInner) {
          final slots = offeredSlots(pickedDay);
          return SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(
                  l10n.planChooseDay,
                  style: Theme.of(ctx).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in options)
                      ChoiceChip(
                        label: Text(
                          dateKey(d) == dateKey(today)
                              ? l10n.planToday
                              : settings.inDigits(dates.formatShortMonthDay(d)),
                        ),
                        selected: dateKey(d) == dateKey(pickedDay),
                        onSelected: (_) => setInner(() {
                          pickedDay = d;
                          // RAM-1: repeat the mapping every time the day
                          // changes, so a slot the new day doesn't offer
                          // (suhoor picked, then a non-Ramadan day chosen)
                          // doesn't stay silently selected off-screen.
                          final offered = offeredSlots(pickedDay);
                          if (!offered.contains(pickedSlot)) {
                            pickedSlot = slotOnDay(pickedSlot, offered);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.planChooseMeal,
                  style: Theme.of(ctx).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in slots)
                      ChoiceChip(
                        label: Text(mealName(l10n, m)),
                        selected: m == pickedSlot,
                        onSelected: (_) => setInner(() => pickedSlot = m),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(ctx, (pickedDay, pickedSlot)),
                    child: Text(l10n.save),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// "Add to plan" from a recipe page: a day and a meal, then Save — three
/// taps in all (PLAN-3).
Future<void> openAddToPlan(BuildContext context, String recipeId) async {
  final l10n = AppLocalizations.of(context);
  final plan = context.read<PlanState>();
  final recipes = context.read<RecipesState>();
  final messenger = ScaffoldMessenger.of(context);
  final where = await _askDayAndMeal(
    context,
    title: l10n.planAddToPlan,
    day: plan.today,
    slot: _lastMeal,
  );
  if (where == null) return;
  _lastMeal = where.$2;
  final added = await plan.add(
    date: where.$1,
    slot: where.$2,
    recipeId: recipeId,
    servings: await recipes.repository.servingsOf(recipeId),
  );
  if (added != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.planAdded)));
  }
}

/// One plan entry as a candidate for "أضف إلى المشتريات" (PLAN-5): ticked
/// unless it was already sent, which also shows "أُضيفت".
class _GroceryEntryCandidate {
  _GroceryEntryCandidate(this.entry, this.title)
    : checked = entry.addedToGroceriesAt == null;
  final PlanEntry entry;
  final String title;
  bool checked;
}

/// A candidate's day, meal and servings ("21 Sep 2026 · Lunch · 6 servings"),
/// so the same recipe planned twice in the week doesn't look identical
/// (should-fix, UI review), with "أُضيفت" appended when it was already sent.
String _candidateSubtitle(
  BuildContext ctx,
  AppLocalizations l10n,
  SettingsState settings,
  PlanEntry entry,
) {
  final date = settings.inDigits(
    MaterialLocalizations.of(ctx).formatMediumDate(entry.date),
  );
  final amount = entry.servings != null
      ? l10n.servings(entry.servings!, settings.number(entry.servings!))
      : entry.multiplier != null && entry.multiplier != Rational.one
      ? factorLabel(entry.multiplier!, settings.digits)
      : null;
  return [
    date,
    mealName(l10n, entry.slot),
    ?amount,
    if (entry.addedToGroceriesAt != null) l10n.planGroceriesAlreadyAdded,
  ].join(' · ');
}

/// PLAN-5: "أضف إلى المشتريات" lists the recipe entries of the shown week
/// from today on, each ticked unless already added. Adding scales each
/// entry's lines by its servings over the recipe's, or by its multiplier
/// (PLAN-2, SCALE-2), in the recipe's remembered view (SCALE-5, SCALE-6),
/// merges them into the list (GRO-3) and marks the entries added.
Future<void> openPlanAddToGroceries(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final plan = context.read<PlanState>();
  final recipes = context.read<RecipesState>();
  final groceries = context.read<GroceryState>();
  final settings = context.read<SettingsState>();
  final messenger = ScaffoldMessenger.of(context);

  final candidates = [
    for (final e in plan.entries)
      if (!e.isNote && dateOnly(e.date).compareTo(plan.today) >= 0)
        _GroceryEntryCandidate(
          e,
          recipes.recipes.where((r) => r.id == e.recipeId).firstOrNull?.title ??
              '',
        ),
  ];

  var busy = false;
  final added = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    // A long week (or 12 aisles at 1.3×) used to grow under the status
    // bar, since isScrollControlled strips top padding on its own
    // (should-fix, UI review).
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInner) {
        final anyChecked = candidates.any((c) => c.checked);
        return SingleChildScrollView(
          padding: EdgeInsetsDirectional.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
                child: Text(
                  l10n.addToGroceries,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              if (candidates.isEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.all(24),
                  child: Text(l10n.planGroceriesEmpty),
                )
              else
                for (final c in candidates)
                  CheckboxListTile(
                    value: c.checked,
                    onChanged: (v) => setInner(() => c.checked = v ?? false),
                    title: ContentText(c.title),
                    // Day, meal and servings (should-fix, UI review): the
                    // same recipe on two days looked identical.
                    subtitle: Text(
                      _candidateSubtitle(ctx, l10n, settings, c.entry),
                    ),
                  ),
              Padding(
                padding: const EdgeInsetsDirectional.all(16),
                child: FilledButton(
                  // Disabled while busy or with nothing ticked (should-fix,
                  // UI review): a double tap used to add everything twice.
                  onPressed: candidates.isEmpty || busy || !anyChecked
                      ? null
                      : () async {
                          setInner(() => busy = true);
                          final ids = <String>[];
                          final lines = <IncomingLine>[];
                          for (final c in candidates) {
                            if (!c.checked) continue;
                            final recipe = await recipes.repository.get(
                              c.entry.recipeId!,
                            );
                            if (recipe == null ||
                                (recipe.servings == null &&
                                    c.entry.servings != null)) {
                              continue;
                            }
                            final factor = c.entry.servings != null
                                ? Rational(c.entry.servings!, recipe.servings!)
                                : (c.entry.multiplier ?? Rational.one);
                            lines.addAll(
                              groceryLinesForRecipe(
                                recipe,
                                factor,
                                planEntryId: c.entry.id,
                              ),
                            );
                            ids.add(c.entry.id);
                          }
                          // must-fix, two reviews: groceries.add()'s result
                          // was ignored, so a failed write still marked the
                          // week "أُضيفت" and lost it silently.
                          final ok = lines.isEmpty
                              ? true
                              : await groceries.add(lines);
                          if (ok && ids.isNotEmpty) {
                            await plan.markAddedToGroceries(ids);
                          }
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx, ok ? ids.length : null);
                        },
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.planAdd),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  if (added != null && added > 0 && context.mounted) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.planGroceriesAddedCount(added, settings.number(added)),
          ),
        ),
      );
  }
}
