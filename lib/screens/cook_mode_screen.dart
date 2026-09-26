import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/durations.dart';
import '../models/quantity/arabic_text.dart';
import '../models/quantity/convert.dart';
import '../models/quantity/format.dart';
import '../models/quantity/rational.dart';
import '../models/recipe.dart';
import '../providers/recipes_state.dart';
import '../providers/review_prompt_state.dart';
import '../providers/settings_state.dart';
import '../providers/timers_state.dart';
import '../services/cook_services.dart';
import '../theme/decor.dart';
import '../theme/type.dart' show cookStep;
import '../widgets/amount_line.dart';
import '../widgets/content_direction.dart';
import '../widgets/digit_box.dart';
import '../widgets/round_icon_button.dart';
import '../widgets/step_rail.dart';
import '../widgets/sufra_card.dart';
import '../widgets/timer_ring.dart';
import 'ingredients_section.dart' show GroupName;
import 'recipe_screen.dart' show StepText;

/// Cook mode (COOK-1–COOK-6, LOOK-14): free, no ads, one step per page in
/// large text, the screen kept on, timers from the step text, the
/// ingredients one tap away with the recipe page's scale and units
/// (SCALE-6). Follows the light/dark setting like every other screen.
class CookModeScreen extends StatefulWidget {
  const CookModeScreen({super.key, required this.recipe, required this.factor});

  final Recipe recipe;
  final Rational factor;

  /// LOOK-14: up to this many steps the rail has one segment each; a
  /// longer recipe gets a progress bar instead.
  static const maxRailSegments = StepRail.maxSegments;

  /// COOK-4: how tall the running-timer bands grow before they scroll,
  /// about two bands, so the step keeps its room however many run.
  static const maxBandsHeight = 152.0;

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen>
    with WidgetsBindingObserver {
  final _pages = PageController();
  final _checked = <String>{};
  late final List<(String? group, RecipeStep step)> _steps = [
    for (final s in widget.recipe.steps)
      for (final step in s.items) (s.name, step),
  ];
  int _page = 0;
  late final ScreenAwake _awake;

  int get _last => _steps.length; // the "done" page after the last step

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _awake = context.read<ScreenAwake>()..keepOn(true); // COOK-3
    _resume();
  }

  /// Reopening within 12 hours resumes at the same page (COOK-6).
  Future<void> _resume() async {
    final repo = context.read<RecipesState>().repository;
    final page = await repo.cookPage(widget.recipe.id);
    if (page != null && page > 0 && page <= _last && mounted) {
      _pages.jumpToPage(page);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The screen stays on only while cook mode is in front (COOK-3).
    _awake.keepOn(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _awake.keepOn(false);
    _pages.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final target = (_page + delta).clamp(0, _last);
    // Reduce motion: a static swap instead of the slide.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(target);
      return;
    }
    _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _startTimer(int step, Duration d) async {
    final l10n = AppLocalizations.of(context);
    final s = context.read<SettingsState>();
    final timers = context.read<TimersState>();
    final messenger = ScaffoldMessenger.of(context);
    await timers.start(
      recipeId: widget.recipe.id,
      recipeTitle: widget.recipe.title,
      step: step,
      duration: d,
      notificationTitle: widget.recipe.title,
      notificationBody: l10n.timerDone(s.number(step)),
      channelName: l10n.timerChannel,
    );
    if (timers.shouldSayAlertsOff) {
      timers.saidAlertsOff();
      messenger.showSnackBar(SnackBar(content: Text(l10n.alertsOff)));
    }
  }

  Future<void> _markCooked() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<RecipesState>().markCooked(widget.recipe.id);
    if (!mounted) return;
    if (ok) messenger.showSnackBar(SnackBar(content: Text(l10n.markedCooked)));
    _closeFromLastPage();
  }

  /// COOK-6's last page closes cook mode, by "Done" or by "Mark as cooked".
  /// RUN-5: right after it closes — never from the close button part-way
  /// through — the store's review prompt may be asked for.
  void _closeFromLastPage() {
    final review = context.read<ReviewPrompt>();
    Navigator.of(context).pop();
    review.afterCooking();
  }

  /// COOK-2's ingredients sheet: 56 dp rows with round checkboxes, each
  /// line through [AmountLine] (LOOK-4), the ×factor in its header.
  void _showIngredients() {
    final l10n = AppLocalizations.of(context);
    final s = context.read<SettingsState>();
    final r = widget.recipe;
    final gutter = Decor.of(context).gutter;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scroll) => StatefulBuilder(
          builder: (context, setSheet) => ListView(
            controller: scroll,
            padding: const EdgeInsetsDirectional.only(bottom: 16),
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.ingredients,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (widget.factor != Rational.one)
                      _FactorPill(widget.factor, digits: s.digits),
                  ],
                ),
              ),
              for (final section in r.ingredients) ...[
                if (section.name != null)
                  Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: gutter,
                    ),
                    child: GroupName(section.name!),
                  ),
                for (final line in section.items)
                  CheckboxListTile(
                    value: _checked.contains(line.id),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 12,
                    ),
                    onChanged: (v) {
                      setSheet(() {});
                      setState(() {
                        v! ? _checked.add(line.id) : _checked.remove(line.id);
                      });
                    },
                    title: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 32),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AmountLine(
                          _shownText(line, r.unitView, s.digits),
                          source: line.original,
                          style: _checked.contains(line.id)
                              ? const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// A line scaled and converted like the recipe page (SCALE-6).
  String _shownText(IngredientLine line, UnitView view, DigitStyle digits) {
    final shown = showLine(line.parsed, factor: widget.factor, view: view).line;
    if (shown.min == null) return line.original;
    return formatLine(
      shown,
      arabic: hasArabic(line.original),
      digits: digitsFor(line.original, digits),
      isolate: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gutter = Decor.of(context).gutter;
    final dir = Directionality.of(context);
    final hasIngredients = widget.recipe.ingredients.any(
      (s) => s.items.isNotEmpty,
    );
    // Ticks at the reading start: this icon doesn't mirror itself (LANG-5).
    final ingredientsIcon = dir == TextDirection.rtl
        ? Icons.checklist_rtl
        : Icons.checklist;

    // No app bar sets the status bar's icons here: they follow the theme
    // (status-bar fields only; the navigation bar keeps its own style).
    final icons = theme.brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: icons,
        statusBarBrightness: icons == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Scaffold(
        // LOOK-14: three large controls where a wet thumb reaches them.
        // In right-to-left, "التالي" is on the left and points left.
        // "Next" stays the widest; the split is a little less lopsided
        // than the mockup's 1:1.6, which is 390 dp wide, so "Previous"
        // keeps its room on a 360 dp phone, and both labels shrink to
        // fit rather than clip (LOOK-7's rule, LOOK-8). They're the
        // Scaffold's bottom bar, so a notice (COOK-5's "alerts are off",
        // "marked as cooked") floats above them and never covers them.
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(gutter, 12, gutter, 16),
            child: Row(
              children: [
                Expanded(
                  flex: 10,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 8,
                      ),
                    ),
                    onPressed: _page > 0 ? () => _go(-1) : null,
                    icon: const Icon(Icons.chevron_left),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.previousStep, maxLines: 1),
                    ),
                  ),
                ),
                if (hasIngredients) ...[
                  const SizedBox(width: 12),
                  RoundIconButton(
                    size: 56,
                    icon: ingredientsIcon,
                    tooltip: l10n.ingredients,
                    onPressed: _showIngredients,
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  flex: 14,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: const StadiumBorder(),
                      shadows: _page < _last
                          ? Decor.of(context).floatShadow
                          : const [],
                    ),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 8,
                        ),
                      ),
                      onPressed: _page < _last ? () => _go(1) : null,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.chevron_right),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.nextStep, maxLines: 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(gutter, 12, gutter, 0),
                child: Row(
                  children: [
                    RoundIconButton(
                      size: 48,
                      icon: Icons.close,
                      tooltip: l10n.closeCooking,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          // The route's name and heading, as the app bar's
                          // title used to be.
                          Semantics(
                            header: true,
                            namesRoute: true,
                            child: ContentText(
                              widget.recipe.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (widget.factor != Rational.one) ...[
                            const SizedBox(height: 4),
                            _FactorPill(widget.factor, digits: s.digits),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (hasIngredients)
                      RoundIconButton(
                        size: 48,
                        icon: ingredientsIcon,
                        tooltip: l10n.ingredients,
                        onPressed: _showIngredients,
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(gutter, 20, gutter, 0),
                child: StepRail(current: _page, total: _steps.length),
              ),
              // COOK-4: running timers show in the header, outside the pages.
              _TimerBands(recipeId: widget.recipe.id),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    // Tap the edges to move (COOK-2). In right-to-left the
                    // next step is on the left.
                    onTapUp: (d) {
                      final x = d.localPosition.dx / box.maxWidth;
                      final forward = dir == TextDirection.rtl
                          ? x < 0.2
                          : x > 0.8;
                      final back = dir == TextDirection.rtl ? x > 0.8 : x < 0.2;
                      if (forward) _go(1);
                      if (back) _go(-1);
                    },
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: _steps.length + 1,
                      onPageChanged: (p) {
                        setState(() => _page = p);
                        context.read<RecipesState>().setCookPage(
                          widget.recipe.id,
                          p,
                          _steps.length,
                        );
                      },
                      itemBuilder: (context, i) => i == _last
                          ? _DonePage(
                              onCooked: _markCooked,
                              onDone: _closeFromLastPage,
                            )
                          : _StepPage(
                              index: i,
                              total: _steps.length,
                              group: _steps[i].$1,
                              step: _steps[i].$2,
                              recipeId: widget.recipe.id,
                              onTimer: (d) => _startTimer(i + 1, d),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The scale factor as a small soft-accent pill ("×2"), laid out left to
/// right so "×" stays before its number.
class _FactorPill extends StatelessWidget {
  const _FactorPill(this.factor, {required this.digits});
  final Rational factor;
  final DigitStyle digits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '×${formatAmount(factor, null, digits: digits)}',
        textDirection: TextDirection.ltr,
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.index,
    required this.total,
    required this.group,
    required this.step,
    required this.recipeId,
    required this.onTimer,
  });

  final int index;
  final int total;
  final String? group;
  final RecipeStep step;
  final String recipeId;
  final ValueChanged<Duration> onTimer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final gutter = Decor.of(context).gutter;
    final timers = context.watch<TimersState>();
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(gutter, 20, gutter, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LOOK-5: the step numeral steps in place, so its digits are
          // boxed; the sentence itself reads as before.
          DigitBox(
            l10n.stepOf(s.number(index + 1), s.number(total)),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (group != null)
            ContentText(group!, style: theme.textTheme.titleSmall),
          const SizedBox(height: 14),
          // COOK-2: at least 1.5x the body size (`cookStep`), its timers
          // marked in the accent as plain text (Cook.dc.html): the timer
          // card below is the button.
          StepText(step.text, style: cookStep(theme.textTheme), pill: false),
          for (final d in findDurations(step.text)) ...[
            const SizedBox(height: 20),
            _TimerCard(
              duration: d,
              timer: timers.running
                  .where(
                    (t) =>
                        t.recipeId == recipeId &&
                        t.step == index + 1 &&
                        t.total == d,
                  )
                  .lastOrNull,
              now: timers.now(),
              onStart: () => onTimer(d),
              onStop: timers.cancel,
            ),
          ],
        ],
      ),
    );
  }
}

String _clock(SettingsState s, Duration d) {
  final t = clockText(d);
  return s.digits == DigitStyle.arabic ? easternDigits(t) : t;
}

/// COOK-4, LOOK-14: one duration in the step as a large timer — a ring,
/// the time at 40/700 laid out left to right, and "ابدأ مؤقت …" as the
/// primary pill. While that same timer runs, the card counts it down —
/// the ring's arc is the time left — and its pill stops it; when it ends,
/// the card is back to its start state.
class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.duration,
    required this.timer,
    required this.now,
    required this.onStart,
    required this.onStop,
  });

  final Duration duration;

  /// This card's own timer while it runs; null otherwise.
  final CookTimer? timer;
  final DateTime now;
  final VoidCallback onStart;
  final ValueChanged<CookTimer> onStop;

  /// The ring's box, and the stroke drawn inside its edge.
  static const ring = 150.0;
  static const stroke = 10.0;

  /// The clock's box: 106 × 48 keeps its corners about 7 dp inside the
  /// ring's inner edge (radius 65), and the text scales down to fit it at
  /// any text size (LOOK-8), so a long "1:30:00" never touches the ring.
  static const clockWidth = 106.0;
  static const clockHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final t = timer;
    final remaining = t?.remaining(now) ?? duration;
    final left = remaining.isNegative ? Duration.zero : remaining;
    // The same clock as its band's, so the two never disagree.
    final clock = _clock(s, left);
    final total = t?.total.inMilliseconds ?? 0;
    return SufraCard(
      radius: 28,
      padding: const EdgeInsetsDirectional.all(20),
      child: Column(
        children: [
          SizedBox.square(
            dimension: ring,
            child: TimerRing(
              stroke: stroke,
              fraction: t == null || total == 0
                  ? null
                  : (left.inMilliseconds / total).clamp(0.0, 1.0),
              child: Center(
                child: SizedBox(
                  key: const Key('timer-card-clock'),
                  width: clockWidth,
                  height: clockHeight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    // LOOK-5: the countdown ticks every second; boxed digits
                    // keep it from twitching as it does.
                    child: DigitBox(
                      clock,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: t == null
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: onStart,
                    icon: const Icon(Icons.timer_outlined),
                    label: Text(l10n.timerStart(clock)),
                  )
                : Tooltip(
                    message: l10n.timerStop,
                    excludeFromSemantics: true,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      onPressed: () => onStop(t),
                      icon: const Icon(Icons.stop_rounded),
                      label: Text(l10n.timerStop),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Running timers, from any recipe, as bands, and the ones that just ended,
/// each with its dismiss button (COOK-4, COOK-5). Every running timer has
/// its band, with its step, its countdown and its stop button: this
/// recipe's newest first, so the one just started is always in view, then
/// the others'. Past [CookModeScreen.maxBandsHeight] they scroll.
class _TimerBands extends StatelessWidget {
  const _TimerBands({required this.recipeId});
  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final timers = context.watch<TimersState>();
    final now = timers.now();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final decor = Decor.of(context);
    if (timers.running.isEmpty && timers.finished.isEmpty) {
      return const SizedBox.shrink();
    }
    // `running` is in start order: newest first, this recipe's before the
    // others'.
    final newest = timers.running.reversed;
    final running = [
      ...newest.where((t) => t.recipeId == recipeId),
      ...newest.where((t) => t.recipeId != recipeId),
    ];

    Widget band(CookTimer t) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Container(
        key: ValueKey('timer-band-${t.id}'),
        // Cook.dc.html's 68 dp slab: 10 dp around the 48 dp stop target.
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: decor.sunk,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            // The step and its countdown read as one stop; the stop button
            // stays its own.
            Expanded(
              child: MergeSemantics(
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 20, color: cs.secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.stepN(s.number(t.step)),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          // Another recipe's timer names its recipe.
                          if (t.recipeId != recipeId)
                            ContentText(
                              t.recipeTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // LOOK-5: the countdown ticks every second; boxed digits
                    // keep the band from twitching as it does.
                    DigitBox(
                      _clock(s, t.remaining(now)),
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            RoundIconButton(
              size: 40,
              icon: Icons.close,
              tooltip: l10n.timerStop,
              onPressed: () => timers.cancel(t),
            ),
          ],
        ),
      ),
    );

    final gutter = decor.gutter;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(gutter, 16, gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in timers.finished)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8),
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(Icons.alarm_on, color: cs.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.timerDone(s.number(t.step)),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          ContentText(
                            t.recipeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: cs.onErrorContainer,
                      ),
                      onPressed: timers.dismissFinished,
                      child: Text(l10n.dismiss),
                    ),
                  ],
                ),
              ),
            ),
          if (running.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: CookModeScreen.maxBandsHeight,
              ),
              child: _BandList(children: [for (final t in running) band(t)]),
            ),
        ],
      ),
    );
  }
}

/// The running-timer bands, scrolling once they pass their height, with a
/// scrollbar that shows whenever some are out of view.
class _BandList extends StatefulWidget {
  const _BandList({required this.children});
  final List<Widget> children;

  @override
  State<_BandList> createState() => _BandListState();
}

class _BandListState extends State<_BandList> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scroll,
      thumbVisibility: widget.children.length > 2,
      child: ListView(
        key: const Key('timer-bands'),
        controller: _scroll,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: widget.children,
      ),
    );
  }
}

/// COOK-6's last page: a drawn eight-point star, the closing line, then
/// "تم طبخها" (REC-9) and "تم".
class _DonePage extends StatelessWidget {
  const _DonePage({required this.onCooked, required this.onDone});
  final VoidCallback onCooked;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SizedBox.square(
                dimension: 112,
                child: CustomPaint(
                  painter: StarPainter(
                    fill: cs.primaryContainer,
                    stroke: cs.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.finishTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCooked,
              icon: const Icon(Icons.check),
              label: Text(l10n.markCooked),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
              onPressed: onDone,
              child: Text(l10n.done),
            ),
          ],
        ),
      ),
    );
  }
}

/// LOOK-10's eight-point khatam star, drawn large: a soft fill with an
/// accent outline. Decoration, so it has no semantics of its own.
class StarPainter extends CustomPainter {
  const StarPainter({required this.fill, required this.stroke});
  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - 2;
    final inner = outer * 0.72;
    final path = Path();
    for (var k = 0; k < 16; k++) {
      final r = k.isEven ? outer : inner;
      final p = center + Offset.fromDirection(k * math.pi / 8 - math.pi / 2, r);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      center,
      inner * 0.45,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(StarPainter old) =>
      old.fill != fill || old.stroke != stroke;
}
