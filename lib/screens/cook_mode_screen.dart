import 'package:flutter/material.dart';
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
import '../theme/type.dart' show cookStep;
import '../widgets/amount_line.dart';
import '../widgets/content_direction.dart';
import '../widgets/digit_box.dart';
import '../widgets/pressable_slab.dart';

/// Cook mode (COOK-1–COOK-6): free, no ads, one step per page in large
/// text, the screen kept on, timers from the step text, the ingredients one
/// pull away with the recipe page's scale and units (SCALE-6).
class CookModeScreen extends StatefulWidget {
  const CookModeScreen({super.key, required this.recipe, required this.factor});

  final Recipe recipe;
  final Rational factor;

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

  void _showIngredients() {
    final l10n = AppLocalizations.of(context);
    final s = context.read<SettingsState>();
    final r = widget.recipe;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scroll) => StatefulBuilder(
          builder: (context, setSheet) => ListView(
            controller: scroll,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                child: Text(
                  l10n.ingredients,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final section in r.ingredients) ...[
                if (section.name != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                    child: ContentText(
                      section.name!,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                for (final line in section.items)
                  CheckboxListTile(
                    value: _checked.contains(line.id),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) {
                      setSheet(() {});
                      setState(() {
                        v! ? _checked.add(line.id) : _checked.remove(line.id);
                      });
                    },
                    title: AmountLine(
                      _shownText(line, r.unitView, s.digits),
                      source: line.original,
                      style: _checked.contains(line.id)
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            )
                          : null,
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
    final dir = Directionality.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.closeCooking,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: ContentText(
          widget.recipe.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.recipe.ingredients.isNotEmpty)
            IconButton(
              tooltip: l10n.ingredients,
              // Ticks at the reading start: this icon doesn't mirror
              // itself (LANG-5).
              icon: Icon(
                dir == TextDirection.rtl
                    ? Icons.checklist_rtl
                    : Icons.checklist,
              ),
              onPressed: _showIngredients,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _TimersBar(),
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
                      context.read<RecipesState>().repository.setCookPage(
                        widget.recipe.id,
                        p,
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
            Padding(
              padding: const EdgeInsetsDirectional.all(12),
              child: Row(
                // Equal Expanded widths, not a Spacer (should-fix, LOOK-8):
                // at 1.3x text a Spacer-separated Row let "السابق"/"التالي"
                // overflow the 360dp floor by a few px; splitting the
                // width between them the way design-styles.md's cook-mode
                // bottom bar asks for fixes it in both looks and both
                // languages, not just at this one text scale.
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _page > 0 ? () => _go(-1) : null,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(
                        l10n.previousStep,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // LOOK-7: the third of Saffron's three ledge actions; a
                  // no-op in Ink (Decor.ledgeDepth 0).
                  Expanded(
                    child: PressableSlab(
                      child: FilledButton.icon(
                        onPressed: _page < _last ? () => _go(1) : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          l10n.nextStep,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
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
    final timers = context.watch<TimersState>();
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 24),
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
          const SizedBox(height: 16),
          // should-fix, platform review: was a bespoke 1.5x/height-1.5
          // inline style instead of `cookStep` (COOK-2, LOOK-6) — besides
          // leaving `cookStep` unreferenced outside its own test, its
          // height:1.5 undercut LOOK-5's own 1.75 floor for text that can
          // wrap to a second line, which a recipe step routinely does.
          ContentText(step.text, style: cookStep(theme.textTheme)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in findDurations(step.text))
                ActionChip(
                  avatar: const Icon(Icons.timer_outlined),
                  tooltip: l10n.timerStart(_clock(s, d)),
                  label: Text(_clock(s, d), textDirection: TextDirection.ltr),
                  onPressed:
                      timers.running.any(
                        (t) =>
                            t.recipeId == recipeId &&
                            t.step == index + 1 &&
                            t.total == d,
                      )
                      ? null
                      : () => onTimer(d),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _clock(SettingsState s, Duration d) {
  final t = clockText(d);
  return s.digits == DigitStyle.arabic ? easternDigits(t) : t;
}

/// Running timers, from any recipe, and the ones that just ended (COOK-4).
class _TimersBar extends StatelessWidget {
  const _TimersBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final timers = context.watch<TimersState>();
    final now = timers.now();
    final theme = Theme.of(context);
    if (timers.running.isEmpty && timers.finished.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in timers.finished)
            Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.alarm_on),
                title: Text(l10n.timerDone(s.number(t.step))),
                subtitle: ContentText(t.recipeTitle),
                trailing: TextButton(
                  onPressed: timers.dismissFinished,
                  child: Text(l10n.dismiss),
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              for (final t in timers.running)
                InputChip(
                  avatar: const Icon(Icons.timer_outlined),
                  // LOOK-5: the countdown ticks every second; boxed
                  // digits keep the chip from twitching as it does.
                  label: DigitBox(
                    '${_clock(s, t.remaining(now))} · ${l10n.stepN(s.number(t.step))}',
                  ),
                  deleteButtonTooltipMessage: l10n.timerStop,
                  onDeleted: () => timers.cancel(t),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonePage extends StatelessWidget {
  const _DonePage({required this.onCooked, required this.onDone});
  final VoidCallback onCooked;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant, size: 64),
            const SizedBox(height: 16),
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
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onDone, child: Text(l10n.done)),
          ],
        ),
      ),
    );
  }
}
