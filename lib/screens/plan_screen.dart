import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
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
import '../widgets/recipe_cover.dart';
import '../widgets/recipe_photo.dart';
import '../widgets/round_icon_button.dart';
import '../widgets/segmented_pill.dart';
import '../widgets/sufra_card.dart';
import '../widgets/sufra_search_field.dart';
import 'home_screen.dart';

/// The meal plan (PLAN-1, amended by Decision 23): a strip of the week's 7
/// days and, under it, the chosen day's meals as a timeline. Adding, moving
/// and removing never touch the recipe itself (PLAN-3, PLAN-4).
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

/// The meal the add sheet offers first: the one last used (PLAN-3).
MealSlot _lastMeal = MealSlot.lunch;

/// The strip's pills are 46dp wide in the mockup; each day's tap target is
/// its whole column of the strip, at least 48dp on a 360dp phone.
const double _pillWidth = 46;

class _PlanScreenState extends State<PlanScreen> with WidgetsBindingObserver {
  int? _firstWeekday;

  /// RAM-4: "الأسبوع" or "رمضان" — only meaningful while the toggle shows.
  bool _monthView = false;

  /// The week showing before switching to the Ramadan month, so "الأسبوع"
  /// comes back to it rather than always jumping to today's week (RAM-4).
  DateTime? _weekBeforeMonthView;

  /// The chosen day (PLAN-1); null means today. It's screen state only:
  /// choosing a day never reloads anything, since the whole week (or the
  /// Ramadan month) is already loaded.
  DateTime? _selected;
  DateTime? _selectedBeforeMonthView;

  /// The chosen day's heading, scrolled to when a day is chosen in the
  /// month view (RAM-4), where the grid pushes it below the fold.
  final _dayHeadingKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
        // stuck showing a month that no longer applies.
        _monthView = false;
        _selected = _selectedBeforeMonthView;
        plan.showWeek(_weekBeforeMonthView ?? weekStartFor(plan.today, first));
        return;
      }
      if (dateKey(plan.days.firstOrNull ?? DateTime(0)) !=
              dateKey(ramadanMonth.start) ||
          dateKey(plan.days.lastOrNull ?? DateTime(0)) !=
              dateKey(ramadanMonth.last)) {
        // must-fix: a moon-sighting shift moves the whole month even while
        // its view is open — reload so it doesn't keep showing yesterday's
        // range (a day short, or one day into what's no longer Ramadan).
        plan.showRange(ramadanMonth.start, ramadanMonth.last);
      }
      return;
    }
    if (!weekChanged) return;
    // The week that holds the chosen day, from the (new) first weekday.
    plan.showWeek(weekStartFor(_selected ?? plan.today, first));
  }

  /// The week's first day: the setting, else the phone's region (PLAN-1) —
  /// from the device's own language list, never the app's chosen language
  /// (`Localizations.localeOf`), which only picks the no-region fallback.
  int _weekStartDay(BuildContext context, AppSettings settings) => firstWeekday(
    settings.weekStart,
    region: deviceRegion(View.of(context).platformDispatcher.locales),
    arabic: Localizations.localeOf(context).languageCode == 'ar',
  );

  /// PLAN-1: the phone's region changed while the app runs. Nothing the
  /// screen depends on changes with it when the app's language is fixed,
  /// so re-read the week start here.
  @override
  void didChangeLocales(List<Locale>? locales) {
    if (!mounted || _monthView) return;
    final first = _weekStartDay(
      context,
      context.read<SettingsState>().settings,
    );
    if (first == _firstWeekday) return;
    _firstWeekday = first;
    final plan = context.read<PlanState>();
    plan.showWeek(weekStartFor(_selected ?? plan.today, first));
  }

  /// The day whose meals show (PLAN-1): the chosen one when it's in the
  /// range shown; else the same weekday, so the arrows keep it even for the
  /// moment before the next week has loaded; else today; else the first.
  DateTime _chosenDay(PlanState plan) {
    final days = plan.days;
    final wanted = dateOnly(_selected ?? plan.today);
    bool isShown(DateTime d) => days.any((x) => dateKey(x) == dateKey(d));
    if (isShown(wanted)) return wanted;
    if (days.length == 7) {
      for (final d in days) {
        if (d.weekday == wanted.weekday) return d;
      }
    }
    if (isShown(plan.today)) return plan.today;
    return days.first;
  }

  void _choose(DateTime day) {
    setState(() => _selected = dateOnly(day));
    // RAM-4: the month's 5 rows of pills put the chosen day's meals below
    // the fold, so choosing one brings its heading up, with its meals under
    // it; otherwise only the pill's fill would change on screen. Only on a
    // choice: entering the month view keeps the grid the user just opened.
    if (!_monthView) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _dayHeadingKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.05,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// The arrows: a week at a time, keeping the chosen weekday (PLAN-1).
  void _shiftWeek(int weeks) {
    final plan = context.read<PlanState>();
    final chosen = _chosenDay(plan);
    setState(
      () => _selected = DateTime(
        chosen.year,
        chosen.month,
        chosen.day + 7 * weeks,
      ),
    );
    plan.shiftWeeks(weeks);
  }

  /// "هذا الأسبوع": back to the current week, with today chosen (PLAN-1).
  void _thisWeek() {
    final plan = context.read<PlanState>();
    setState(() => _selected = null);
    plan.showWeek(weekStartFor(plan.today, _firstWeekday!));
  }

  /// RAM-4: switches between the week and the whole Ramadan month, which
  /// PlanState loads as an arbitrary range.
  Future<void> _setMonthView(bool month, RamadanMonth ramadanMonth) async {
    final plan = context.read<PlanState>();
    if (month == _monthView) return;
    if (month) {
      _weekBeforeMonthView = plan.weekStart;
      _selectedBeforeMonthView = _selected;
      // Today when it's in the month, else day 1 (the window opens 7 days
      // before it).
      setState(() {
        _monthView = true;
        _selected = ramadanMonth.contains(plan.today)
            ? null
            : ramadanMonth.start;
      });
      await plan.showRange(ramadanMonth.start, ramadanMonth.last);
    } else {
      setState(() {
        _monthView = false;
        _selected = _selectedBeforeMonthView;
      });
      await plan.showWeek(
        _weekBeforeMonthView ?? weekStartFor(plan.today, _firstWeekday!),
      );
    }
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
          // DEL-2: Undo for about 5 seconds, then the notice goes away on
          // its own, never lingering over the screen.
          duration: const Duration(seconds: 5),
          persist: false,
          action: ids.isEmpty
              ? null
              : SnackBarAction(
                  label: l10n.undo,
                  onPressed: () => plan.restore(ids),
                ),
        ),
      );
  }

  /// The header's "more": "مسح الأسبوع" (PLAN-4).
  Future<void> _more() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: Text(l10n.planClearWeek),
              onTap: () => Navigator.pop(ctx, 'clear'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'clear' && mounted) await _clearWeek();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = context.watch<PlanState>();
    final settings = context.watch<SettingsState>();
    final text = Theme.of(context).textTheme;
    final gutter = Decor.of(context).gutter;

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
    // turned off) until didChangeDependencies catches up — this is what
    // the screen actually renders as "in the month view".
    final monthView = _monthView && showMonthToggle;

    if (!plan.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final days = plan.days;
    final chosen = _chosenDay(plan);
    final dates = MaterialLocalizations.of(context);
    final range =
        '${settings.inDigits(dates.formatShortMonthDay(days.first))} – '
        '${settings.inDigits(dates.formatShortMonthDay(days.last))}';
    final onCurrentWeek =
        dateKey(days.first) ==
        dateKey(weekStartFor(plan.today, _firstWeekday ?? DateTime.saturday));

    // One scroll view for the whole screen (LOOK-8): at 1.3x text the
    // header, the strip and the day together can outgrow a short phone.
    // Choosing a day or a week only rebuilds it; the loaded data stays on
    // screen, never a spinner (the week's own entries are already loaded).
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.only(top: 12, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.symmetric(horizontal: gutter),
                child: Row(
                  children: [
                    Expanded(
                      // The screen's heading, as AppBar's title was
                      // (should-fix), so a screen reader can jump to it.
                      child: Semantics(
                        header: true,
                        namesRoute: true,
                        child: Text(
                          l10n.planTitle,
                          style: text.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // PLAN-5: the week's (or, RAM-4, the month's) entries.
                    RoundIconButton(
                      icon: Icons.shopping_basket_outlined,
                      tooltip: l10n.addToGroceries,
                      onPressed: () => openPlanAddToGroceries(context),
                    ),
                    if (!monthView) ...[
                      const SizedBox(width: 4),
                      RoundIconButton(
                        icon: Icons.more_horiz,
                        tooltip: l10n.moreActions,
                        onPressed: _more,
                      ),
                    ],
                  ],
                ),
              ),
              if (card != null)
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    gutter,
                    16,
                    gutter,
                    0,
                  ),
                  child: _RamadanCard(card: card),
                ),
              if (showMonthToggle)
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    gutter,
                    16,
                    gutter,
                    0,
                  ),
                  child: SegmentedPill<bool>(
                    options: {
                      false: l10n.planViewWeek,
                      true: l10n.planViewRamadan,
                    },
                    value: monthView,
                    onChanged: (v) => _setMonthView(v, ramadanMonth),
                  ),
                ),
              const SizedBox(height: 12),
              if (monthView)
                Padding(
                  padding: EdgeInsetsDirectional.symmetric(horizontal: gutter),
                  child: Text(
                    range,
                    textAlign: TextAlign.center,
                    style: text.titleSmall,
                  ),
                )
              else
                Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: gutter - 12,
                  ),
                  child: _WeekNav(
                    range: range,
                    onPrevious: () => _shiftWeek(-1),
                    onNext: () => _shiftWeek(1),
                  ),
                ),
              if (!monthView && !onCurrentWeek)
                Center(child: _ThisWeekChip(onTap: _thisWeek)),
              const SizedBox(height: 12),
              Padding(
                // The strip runs 8dp nearer the edges than the gutter, so
                // each of its 7 columns is a 48dp target on a 360dp phone.
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: gutter - 8,
                ),
                child: monthView
                    ? _MonthGrid(days: days, chosen: chosen, onChoose: _choose)
                    : _DayRow(days: days, chosen: chosen, onChoose: _choose),
              ),
              if (plan.entries.isEmpty)
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    gutter,
                    16,
                    gutter,
                    0,
                  ),
                  child: const _EmptyHint(),
                ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(gutter, 28, gutter, 0),
                child: _DayHeading(key: _dayHeadingKey, day: chosen),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(gutter, 16, gutter, 0),
                child: _DayTimeline(day: chosen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The week range between its two arrows (PLAN-1). The arrows mirror
/// themselves in right to left: each points back toward its own side.
class _WeekNav extends StatelessWidget {
  const _WeekNav({
    required this.range,
    required this.onPrevious,
    required this.onNext,
  });

  final String range;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: l10n.planPreviousWeek,
          // Mirrors itself in right-to-left (matchTextDirection): it points
          // to the reading start either way (LANG-5).
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Expanded(
          child: Text(
            range,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        IconButton(
          tooltip: l10n.planNextWeek,
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

/// "هذا الأسبوع", only off the current week: back to today (PLAN-1).
class _ThisWeekChip extends StatelessWidget {
  const _ThisWeekChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final decor = Decor.of(context);
    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            // A 48dp target around a smaller drawn pill.
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Center(
              widthFactor: 1,
              // Ink, not a DecoratedBox: the fill is painted on the
              // Material, under the InkWell's splash and focus highlight
              // rather than over them. LOOK-3: the outline gives the chip
              // its 3:1 edge against the page, as the theme's chips have.
              child: Ink(
                decoration: ShapeDecoration(
                  shape: StadiumBorder(side: BorderSide(color: cs.outline)),
                  color: decor.sunk,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Text(
                    AppLocalizations.of(context).planThisWeek,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A weekday's key for [AppLocalizations.planWeekdayShort].
String _weekdayKey(int weekday) => const {
  DateTime.monday: 'mon',
  DateTime.tuesday: 'tue',
  DateTime.wednesday: 'wed',
  DateTime.thursday: 'thu',
  DateTime.friday: 'fri',
  DateTime.saturday: 'sat',
  DateTime.sunday: 'sun',
}[weekday]!;

/// RAM-2: the Hijri label of [day] ("٥ رمضان", or "عيد الفطر" the day after
/// the last one), only with the mode on, so it can stay on all year
/// without marking days outside any Ramadan.
String? _hijriLabel(
  AppLocalizations l10n,
  PlanState plan,
  SettingsState settings,
  DateTime day,
) {
  if (!plan.ramadanMode) return null;
  if (plan.isEid(day)) return l10n.ramadanEidLabel;
  final month = plan.ramadanMonthOf(day);
  if (month == null) return null;
  return l10n.ramadanDayLabel(settings.number(month.dayOf(day)!));
}

/// The weekday and date, "الخميس، 25 سبتمبر", in the user's digits.
String _longDate(BuildContext context, SettingsState settings, DateTime day) =>
    settings.inDigits(
      DateFormat.MMMMEEEEd(Localizations.localeOf(context).toString())
          .format(day),
    );

int _entryCount(PlanState plan, DateTime day) =>
    plan.entries.where((e) => dateKey(e.date) == dateKey(day)).length;

/// The week strip (PLAN-1): 7 day pills, one per column.
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.days,
    required this.chosen,
    required this.onChoose,
  });

  final List<DateTime> days;
  final DateTime chosen;
  final ValueChanged<DateTime> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = context.watch<PlanState>();
    final settings = context.watch<SettingsState>();
    // A Ramadan day's Hijri line makes every pill in the row taller.
    final tall = days.any((d) => _hijriLabel(l10n, plan, settings, d) != null);
    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: _DayPill(
              day: d,
              chosen: dateKey(d) == dateKey(chosen),
              height: tall ? 88 : 72,
              onTap: () => onChoose(d),
            ),
          ),
      ],
    );
  }
}

/// RAM-4's month: the same pills in rows of 7, then "عيد الفطر" after the
/// last day.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.days,
    required this.chosen,
    required this.onChoose,
  });

  final List<DateTime> days;
  final DateTime chosen;
  final ValueChanged<DateTime> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsState>();
    final cs = Theme.of(context).colorScheme;
    final last = days.last;
    final eid = DateTime(last.year, last.month, last.day + 1);
    final eidDate = settings.inDigits(
      MaterialLocalizations.of(context).formatShortMonthDay(eid),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < days.length; i += 7)
          Padding(
            padding: EdgeInsetsDirectional.only(top: i == 0 ? 0 : 8),
            child: Row(
              children: [
                for (var j = i; j < i + 7; j++)
                  Expanded(
                    child: j < days.length
                        ? _DayPill(
                            day: days[j],
                            chosen: dateKey(days[j]) == dateKey(chosen),
                            height: 88,
                            onTap: () => onChoose(days[j]),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Center(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: cs.primaryContainer,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Text(
                l10n.ramadanEidOn(eidDate),
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: cs.onPrimaryContainer),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One day of the strip (PLAN-1): its short name and date; the chosen day
/// ink-filled, today ringed in the accent even when not chosen, and a dot
/// only on a day with entries — herb on an ordinary pill, and the pill's
/// own text colour on the chosen (ink) one, where the accent and herb fall
/// below 3:1 in dark. A screen reader hears the
/// whole date, "اليوم", its Hijri day and how many meals it has, as one
/// selectable button.
class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.day,
    required this.chosen,
    required this.height,
    required this.onTap,
  });

  final DateTime day;
  final bool chosen;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = context.watch<PlanState>();
    final settings = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final decor = Decor.of(context);
    final isToday = dateKey(day) == dateKey(plan.today);
    final count = _entryCount(plan, day);
    final hijri = _hijriLabel(l10n, plan, settings, day);

    final fill = chosen ? cs.onSurface : cs.surfaceContainerLowest;
    final main = chosen
        ? cs.surfaceContainerLowest
        : isToday
        ? cs.primary
        : cs.onSurface;
    final secondary = chosen
        ? cs.surfaceContainerLowest
        : isToday
        ? cs.primary
        : cs.onSurfaceVariant;
    // PLAN-1: a dot means "has entries", chosen or not.
    final dot = count == 0
        ? Colors.transparent
        : chosen
        ? cs.surfaceContainerLowest
        : cs.secondary;
    final label = [
      _longDate(context, settings, day),
      if (isToday) l10n.planToday,
      ?hijri,
      l10n.planMealCount(count, settings.number(count)),
    ].join(l10n.labelSeparator);

    return Semantics(
      key: ValueKey('plan-day-${dateKey(day)}'),
      button: true,
      selected: chosen,
      label: label,
      // The pill's own texts are summed up in [label]; the tap is kept
      // here, since excluding them drops the InkWell's action too.
      excludeSemantics: true,
      onTap: onTap,
      // The ink sits in its own layer over the pill (should-fix): the
      // pill's opaque fill would cover a splash or focus highlight painted
      // under it, and an Ink fill would clip the pill's shadow to the
      // column. The tap target stays the whole column.
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth - 2 < _pillWidth
                      ? constraints.maxWidth - 2
                      : _pillWidth;
                  return Center(
                    child: Container(
                      width: width,
                      height: height,
                      decoration: ShapeDecoration(
                        color: fill,
                        shape: StadiumBorder(
                          side: isToday && !chosen
                              ? BorderSide(color: cs.primary, width: 1.5)
                              : decor.cardHairline != null && !chosen
                              ? BorderSide(color: decor.cardHairline!)
                              : BorderSide.none,
                        ),
                        shadows: chosen ? const [] : decor.liftShadow,
                      ),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 3,
                        vertical: 6,
                      ),
                      // Scales down rather than clipping at 1.3x text, in a
                      // pill that can be as narrow as 46dp (LOOK-8).
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.planWeekdayShort(_weekdayKey(day.weekday)),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                color: secondary,
                              ),
                            ),
                            Text(
                              settings.number(day.day),
                              style: theme.textTheme.titleSmall?.copyWith(
                                height: 1.5,
                                color: main,
                              ),
                            ),
                            if (hijri != null)
                              Text(
                                hijri,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: chosen
                                      ? cs.surfaceContainerLowest
                                      : cs.primary,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Container(
                              key: const ValueKey('plan-dot'),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dot,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "اليوم · الخميس 25 سبتمبر", or just the date, with the day's meal count
/// and, on a Ramadan day, its Hijri date (RAM-2).
class _DayHeading extends StatelessWidget {
  const _DayHeading({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = context.watch<PlanState>();
    final settings = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final date = _longDate(context, settings, day);
    final heading = dateKey(day) == dateKey(plan.today)
        ? l10n.planDayHeadingToday(date)
        : date;
    final count = _entryCount(plan, day);
    final hijri = _hijriLabel(l10n, plan, settings, day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(heading, style: theme.textTheme.headlineSmall),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 4),
              child: Text(
                l10n.planMealCount(count, settings.number(count)),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        if (hijri != null)
          Text(
            hijri,
            style: theme.textTheme.labelLarge?.copyWith(color: cs.primary),
          ),
      ],
    );
  }
}

/// The chosen day's meals (PLAN-1, RAM-1) down a vertical line, with a
/// node per meal: the accent when it holds entries, a ring when empty.
class _DayTimeline extends StatelessWidget {
  const _DayTimeline({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanState>();
    // RAM-1: suhoor, iftar, snack on a Ramadan day; the usual four
    // otherwise — either way, plus any slot that already holds an entry.
    final slots = slotsFor(
      day,
      ramadan: plan.ramadanMode,
      month: plan.ramadanMode ? plan.ramadanMonthOf(day) : null,
      withEntries: plan.slotsWithEntries(day),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, slot) in slots.indexed)
          _SlotBlock(day: day, slot: slot, last: i == slots.length - 1),
      ],
    );
  }
}

class _SlotBlock extends StatelessWidget {
  const _SlotBlock({required this.day, required this.slot, required this.last});

  final DateTime day;
  final MealSlot slot;
  final bool last;

  // Plan.dc.html: the rail is inset inside the gutter — the node at 24dp,
  // under the title rather than flush with it, and the meal's content at
  // 48dp.
  static const double _node = 12;
  static const double _nodeStart = 24;
  static const double _indent = 48;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entries = context.watch<PlanState>().entriesFor(day, slot);
    final nameStyle = theme.textTheme.labelLarge!.copyWith(
      color: cs.onSurfaceVariant,
    );
    // The node sits centred on the meal's name line, whatever the text size.
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(nameStyle.fontSize!) *
        (nameStyle.height ?? 1.5);
    final nodeTop = (lineHeight - _node) / 2;
    final filled = entries.isNotEmpty;
    return Stack(
      children: [
        if (!last)
          PositionedDirectional(
            start: _nodeStart + _node / 2 - 1,
            top: nodeTop + _node / 2,
            bottom: 0,
            width: 2,
            child: ColoredBox(color: cs.outlineVariant),
          ),
        PositionedDirectional(
          start: _nodeStart,
          top: nodeTop,
          child: ExcludeSemantics(
            child: Container(
              width: _node,
              height: _node,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? cs.primary : cs.surface,
                border: filled
                    ? null
                    : Border.all(color: cs.outline, width: 1.5),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: _indent,
            bottom: last ? 0 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(mealName(l10n, slot), style: nameStyle),
              const SizedBox(height: 6),
              for (final e in entries)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 8),
                  child: _EntryCard(entry: e),
                ),
              if (entries.isEmpty)
                _DashedAdd(onTap: () => _addToSlot(context, day, slot))
              else
                // PLAN-2: up to 10 per meal; a full one says so on tap.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => _addToSlot(context, day, slot),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.planAdd),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// An empty meal: a dashed card, "+ إضافة", opening PLAN-3's picker.
class _DashedAdd extends StatelessWidget {
  const _DashedAdd({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const radius = 20.0;
    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          child: CustomPaint(
            painter: _DashedBorderPainter(color: cs.outline, radius: radius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18, color: cs.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        l10n.planAdd,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 1.5dp dashed rounded rectangle (LOOK-6: drawn, never a bitmap).
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 1.5;
    const dash = 5.0;
    const gap = 4.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// A planned recipe (its photo or drawn cover, its title, its servings or
/// multiplier, and a more button) or a note (a pencil). A tap opens the
/// recipe, or the note itself to change its text (PLAN-2); a long press
/// opens PLAN-4's menu.
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final PlanEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsState>();
    final recipes = context.watch<RecipesState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final decor = Decor.of(context);
    final LibraryEntry? recipe = entry.isNote
        ? null
        : recipes.recipes.where((r) => r.id == entry.recipeId).firstOrNull;
    final title = entry.isNote ? entry.note! : (recipe?.title ?? '');
    final amount = entry.servings != null
        ? l10n.servings(entry.servings!, settings.number(entry.servings!))
        : entry.multiplier != null && entry.multiplier != Rational.one
        ? factorLabel(entry.multiplier!, settings.digits)
        : null;

    // A button, not an image (should-fix): a photo's own image semantics
    // would otherwise merge into the card's tap. Not excluding, so the more
    // button stays its own node.
    return Semantics(
      button: true,
      child: SufraCard(
        radius: 20,
        padding: entry.isNote
            ? const EdgeInsetsDirectional.fromSTEB(14, 12, 4, 12)
            : const EdgeInsetsDirectional.fromSTEB(10, 10, 4, 10),
        onTap: entry.isNote
            ? () => _editNote(context, entry)
            : () => openRecipe(context, entry.recipeId!),
        onLongPress: () => _entryMenu(context, entry),
        child: Row(
          children: [
            if (entry.isNote)
              Icon(Icons.edit_outlined, size: 20, color: cs.onSurfaceVariant)
            else
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox.square(
                    dimension: 56,
                    child: recipe == null
                        ? RecipeCover(recipeId: entry.recipeId!, title: title)
                        : RecipePhoto(
                            recipeId: recipe.id,
                            title: recipe.title,
                            photoPath: recipe.photoPath,
                          ),
                  ),
                ),
              ),
            SizedBox(width: entry.isNote ? 10 : 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContentText(
                    title,
                    style: theme.textTheme.titleSmall,
                    maxLines: entry.isNote ? null : 2,
                    overflow: entry.isNote ? null : TextOverflow.ellipsis,
                  ),
                  if (amount != null) ...[
                    const SizedBox(height: 4),
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: const StadiumBorder(),
                        color: decor.sunk,
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        // The ambient direction: "٦ حصص" reads right to left,
                        // and a "×2" carries its own left-to-right isolate
                        // (LANG-5).
                        child: Text(
                          amount,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // PLAN-4: a note's move, copy and remove sit behind the same
            // visible button as a recipe's; tapping a note edits it.
            IconButton(
              tooltip: l10n.moreActions,
              icon: const Icon(Icons.more_horiz),
              color: cs.onSurfaceVariant,
              onPressed: () => _entryMenu(context, entry),
            ),
          ],
        ),
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
    final cs = theme.colorScheme;
    final settings = context.read<SettingsState>();
    final text = card.started
        ? l10n.ramadanCardNow
        : l10n.ramadanCardSoon(card.daysUntil, settings.number(card.daysUntil));
    return SufraCard(
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.nightlight_outlined,
                    size: 20,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
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
    );
  }
}

/// RUN-1: an empty week explains itself; its first action is right below,
/// on every meal ("+ إضافة").
class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SufraCard(
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.planEmptyTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            l10n.planEmptyBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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

/// The picker's answer for "اكتب ملاحظة"; any other answer is a recipe ID.
const _noteChoice = '\u0000note';

/// A slot's add: a recipe, or a written note (PLAN-2, PLAN-3). A full slot
/// says so instead (PLAN-2).
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.planSlotFull(settings.number(PlanEntry.maxPerSlot)),
          ),
        ),
      );
    return;
  }
  final choice = await _pickForSlot(context, mealName(l10n, slot));
  if (choice == null || !context.mounted) return;
  _lastMeal = slot;

  if (choice == _noteChoice) {
    final note = await askPlanNote(context);
    if (note == null) return;
    await plan.add(date: day, slot: slot, note: note);
    return;
  }
  await plan.add(
    date: day,
    slot: slot,
    recipeId: choice,
    servings: await recipes.repository.servingsOf(choice),
  );
}

/// PLAN-3's picker: "اكتب ملاحظة", then the library with its search
/// (ORG-3), in one sheet.
Future<String?> _pickForSlot(BuildContext context, String title) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SlotPicker(title: title),
    );

/// The sheet's own state, so the search survives the sheet rebuilding as
/// the keyboard opens.
class _SlotPicker extends StatefulWidget {
  const _SlotPicker({required this.title});
  final String title;

  @override
  State<_SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<_SlotPicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hits = context.read<RecipesState>().query(
      LibraryQuery(text: _search.text),
    );
    return Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      // A fixed share of the screen, so the list under the search field has
      // room to scroll and the sheet never jumps in height as a search
      // narrows it.
      child: FractionallySizedBox(
        heightFactor: 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4),
              child: Text(widget.title, style: theme.textTheme.titleMedium),
            ),
            ListTile(
              contentPadding: const EdgeInsetsDirectional.symmetric(
                horizontal: 20,
              ),
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.planAddNote),
              onTap: () => Navigator.pop(context, _noteChoice),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
              child: Text(
                l10n.planAddRecipe,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // LOOK-6: the library's search pill, without its filter.
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
              child: SufraSearchField(
                controller: _search,
                hintText: l10n.searchHint,
                onChanged: (_) => setState(() {}),
                onClear: () => setState(_search.clear),
                clearTooltip: l10n.searchClear,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: hits.isEmpty
                  ? Padding(
                      padding: const EdgeInsetsDirectional.all(24),
                      child: Text(l10n.noResults, textAlign: TextAlign.center),
                    )
                  : ListView.builder(
                      padding: const EdgeInsetsDirectional.only(bottom: 16),
                      itemCount: hits.length,
                      itemBuilder: (_, i) {
                        final r = hits[i].entry;
                        return ListTile(
                          contentPadding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 20,
                          ),
                          // LOOK-10: the photo, else the drawn cover; the
                          // title already names the row.
                          leading: ExcludeSemantics(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox.square(
                                dimension: 40,
                                child: RecipePhoto(
                                  recipeId: r.id,
                                  title: r.title,
                                  photoPath: r.photoPath,
                                ),
                              ),
                            ),
                          ),
                          title: ContentText(r.title),
                          onTap: () => Navigator.pop(context, r.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
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
              // DEL-2: Undo for about 5 seconds, then gone on its own.
              duration: const Duration(seconds: 5),
              persist: false,
              action: SnackBarAction(
                label: l10n.undo,
                onPressed: () => plan.restore([entry.id]),
              ),
            ),
          );
      }
  }
}

/// A tapped note (PLAN-2): the note dialog, titled as an edit and filled
/// with its text, saved back over it. Cancelling, or saving it unchanged,
/// writes nothing.
Future<void> _editNote(BuildContext context, PlanEntry entry) async {
  final plan = context.read<PlanState>();
  final note = await askPlanNote(
    context,
    initial: entry.note ?? '',
    title: AppLocalizations.of(context).planEditNote,
  );
  if (note == null || note == entry.note) return;
  await plan.setNote(entry, note);
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

/// The note text of a written entry (PLAN-2): 1–60 characters. [title]
/// defaults to adding a note; editing one passes its own.
Future<String?> askPlanNote(
  BuildContext context, {
  String initial = '',
  String? title,
}) => showDialog<String>(
  context: context,
  builder: (ctx) => _NoteDialog(
    initial: initial,
    title: title ?? AppLocalizations.of(context).planAddNote,
  ),
);

/// [askPlanNote]'s dialog. A widget of its own so its text controller is
/// disposed with it, after the closing transition, not at the pop.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.initial, required this.title});

  final String initial;
  final String title;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.read<SettingsState>();
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _controller,
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
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
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
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInner) {
        final theme = Theme.of(ctx);
        final caption = theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
        final slots = offeredSlots(pickedDay);
        return SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              Text(l10n.planChooseDay, style: caption),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
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
              const SizedBox(height: 16),
              Text(l10n.planChooseMeal, style: caption),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in slots)
                    ChoiceChip(
                      label: Text(mealName(l10n, m)),
                      selected: m == pickedSlot,
                      onSelected: (_) => setInner(() => pickedSlot = m),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, (pickedDay, pickedSlot)),
                child: Text(l10n.save),
              ),
            ],
          ),
        );
      },
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
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4),
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
                padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
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
