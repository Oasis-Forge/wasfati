import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/library.dart';
import '../models/plan.dart';
import '../models/quantity/rational.dart';
import '../providers/plan_state.dart';
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../widgets/content_direction.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final first = _weekStartDay(context);
    if (first == _firstWeekday) return;
    _firstWeekday = first;
    final plan = context.read<PlanState>();
    plan.showWeek(weekStartFor(plan.today, first)).then((_) {
      if (mounted) _scrollToToday();
    });
  }

  /// The week's first day: the setting, else the phone's region (PLAN-1).
  int _weekStartDay(BuildContext context) => firstWeekday(
    context.watch<SettingsState>().settings.weekStart,
    region: View.of(context).platformDispatcher.locale.countryCode,
    arabic: Localizations.localeOf(context).languageCode == 'ar',
  );

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
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final days = plan.days;
    final range =
        '${settings.inDigits(dates.formatShortMonthDay(days.first))} – '
        '${settings.inDigits(dates.formatShortMonthDay(days.last))}';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.planTitle),
        actions: [
          IconButton(
            tooltip: l10n.planThisWeek,
            icon: const Icon(Icons.today_outlined),
            onPressed: () {
              plan
                  .showWeek(weekStartFor(plan.today, _firstWeekday!))
                  .then((_) => _scrollToToday());
            },
          ),
          PopupMenuButton<String>(
            onSelected: (_) => _clearWeek(),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'clear', child: Text(l10n.planClearWeek)),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: l10n.planPreviousWeek,
                icon: Icon(rtl ? Icons.chevron_right : Icons.chevron_left),
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
                icon: Icon(rtl ? Icons.chevron_left : Icons.chevron_right),
                onPressed: () => plan.shiftWeeks(1),
              ),
            ],
          ),
        ),
      ),
      body: !plan.loaded
          ? const Center(child: CircularProgressIndicator())
          // Seven cards, built together rather than lazily, so "today" can
          // be scrolled to even when it's the last day of the week (PLAN-1).
          : SingleChildScrollView(
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
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 8),
      child: Column(
        children: [
          Text(
            l10n.planEmptyTitle,
            style: text.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.planEmptyBody,
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
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
    final label = settings.inDigits(
      MaterialLocalizations.of(context).formatMediumDate(day),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
      child: Card(
        elevation: 0,
        color: isToday
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: isToday ? FontWeight.bold : null,
                        ),
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
              for (final slot in MealSlot.values)
                _SlotRow(day: day, slot: slot),
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
        ? '×${entry.multiplier}'
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
            Expanded(child: ContentText(title)),
            if (amount != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Text(
                  amount,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The name of a meal slot (PLAN-1).
String mealName(AppLocalizations l10n, MealSlot slot) => switch (slot) {
  MealSlot.breakfast => l10n.mealBreakfast,
  MealSlot.lunch => l10n.mealLunch,
  MealSlot.dinner => l10n.mealDinner,
  MealSlot.snack => l10n.mealSnack,
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
  if (plan.entriesFor(day, slot).length >= PlanEntry.maxPerSlot) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.planSlotFull)));
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
            leading: const Icon(Icons.drive_file_move_outline),
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
      final where = await _askDayAndMeal(
        context,
        title: action == 'move' ? l10n.planMove : l10n.planCopy,
        day: entry.date,
        slot: entry.slot,
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
                  label: Text('×$m', textDirection: TextDirection.ltr),
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
          decoration: InputDecoration(
            labelText: l10n.planNoteLabel,
            hintText: l10n.planNoteHint,
          ),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? l10n.planNoteInvalid : null,
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
                        border: const OutlineInputBorder(),
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
Future<(DateTime, MealSlot)?> _askDayAndMeal(
  BuildContext context, {
  required String title,
  required DateTime day,
  required MealSlot slot,
}) {
  final l10n = AppLocalizations.of(context);
  final settings = context.read<SettingsState>();
  final dates = MaterialLocalizations.of(context);
  final today = context.read<PlanState>().today;
  final options = [
    for (var i = 0; i < 7; i++)
      DateTime(today.year, today.month, today.day + i),
  ];
  var pickedDay = dateOnly(day);
  var pickedSlot = slot;

  return showModalBottomSheet<(DateTime, MealSlot)>(
    context: context,
    // The chips wrap over several rows, and grow with the text size
    // (LANG-6), so the sheet scrolls instead of overflowing.
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: StatefulBuilder(
        builder: (ctx, setInner) => SingleChildScrollView(
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
                      onSelected: (_) => setInner(() => pickedDay = d),
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
                  for (final m in MealSlot.values)
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
                  onPressed: () => Navigator.pop(ctx, (pickedDay, pickedSlot)),
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
        ),
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
