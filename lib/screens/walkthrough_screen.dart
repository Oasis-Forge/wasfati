import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/durations.dart';
import '../models/quantity/arabic_text.dart';
import '../models/quantity/convert.dart';
import '../models/quantity/format.dart';
import '../models/quantity/rational.dart';
import '../models/recipe.dart';
import '../providers/settings_state.dart';
import '../theme/decor.dart';
import '../widgets/amount_line.dart';
import '../widgets/content_direction.dart';
import '../widgets/digit_box.dart';
import '../widgets/pressable_slab.dart';
import '../widgets/rail_heading.dart';

/// RUN-4: what makes Wasfati different, in four pages — importing a post,
/// amounts that scale in proper Arabic, cook mode, and planning and
/// shopping. Every page has Skip; with reduce motion on, Next jumps instead
/// of sliding. The drawings are the app's own widgets in the chosen look
/// and digits (LOOK-6: nothing is a bitmap), and the amounts in them go
/// through the real parser and formatter, so what a page claims is exactly
/// what the app does.
///
/// [onDone] runs on Skip and on the last page's button (the first run marks
/// itself complete there). Without one — replayed from Settings — the
/// walkthrough just closes.
class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  static const pageCount = 4;

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish() {
    final done = widget.onDone;
    if (done != null) {
      done();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    if (_page >= WalkthroughScreen.pageCount - 1) return _finish();
    final target = _page + 1;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final last = _page == WalkthroughScreen.pageCount - 1;
    final pages = <(String, String, Widget)>[
      (
        l10n.walkthroughImportTitle,
        l10n.walkthroughImportBody,
        const _ImportDrawing(),
      ),
      (
        l10n.walkthroughScaleTitle,
        l10n.walkthroughScaleBody,
        const _ScaleDrawing(),
      ),
      (
        l10n.walkthroughCookTitle,
        l10n.walkthroughCookBody,
        const _CookDrawing(),
      ),
      (
        l10n.walkthroughPlanTitle,
        l10n.walkthroughPlanBody,
        const _PlanDrawing(),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 0),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(l10n.walkthroughSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  for (final (title, body, drawing) in pages)
                    _Page(title: title, body: body, drawing: drawing),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
              child: Row(
                children: [
                  _Dots(
                    index: _page,
                    count: WalkthroughScreen.pageCount,
                    label: l10n.walkthroughPageOf(
                      s.number(_page + 1),
                      s.number(WalkthroughScreen.pageCount),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: PressableSlab(
                        child: FilledButton(
                          onPressed: _next,
                          child: Text(
                            last ? l10n.walkthroughStart : l10n.walkthroughNext,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.body, required this.drawing});

  final String title;
  final String body;
  final Widget drawing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The drawing is decoration: a screen reader reads the page's
              // heading and text instead.
              ExcludeSemantics(child: drawing),
              const SizedBox(height: 32),
              Text(
                title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the reader is, drawn as dots; read aloud as "Page 2 of 4".
class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.count, required this.label});

  final int index;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: i == index ? 20 : 8,
                height: 8,
                margin: const EdgeInsetsDirectional.only(end: 6),
                decoration: BoxDecoration(
                  color: i == index ? scheme.primary : scheme.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One drawing's card: the look's own grouped fill and card shape.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    return Material(
      color: decor.groupedRowFill,
      shape: decor.cardShape,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: child,
      ),
    );
  }
}

/// A demo line, scaled by [factor] and shown exactly as the recipe page
/// would show it: the user's digits, units that agree (QTY-5, QTY-6).
String _demoLine(String text, DigitStyle digits, {int factor = 1}) {
  final line = IngredientLine.parse('walkthrough', text);
  return shownLineText(showLine(line.parsed, factor: Rational(factor)), digits);
}

/// Page 1: a shared post, a site or a photo becomes a clean recipe.
class _ImportDrawing extends StatelessWidget {
  const _ImportDrawing();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final decor = Decor.of(context);
    Widget source(IconData icon) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
      child: Material(
        color: theme.colorScheme.secondaryContainer,
        shape: decor.chipShape,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(12),
          child: Icon(icon, color: theme.colorScheme.onSecondaryContainer),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            source(Icons.link),
            source(Icons.public),
            source(Icons.photo_camera_outlined),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
          child: Icon(
            Icons.arrow_downward,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        _Frame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RailHeading(
                l10n.walkthroughDemoRecipe,
                style: theme.textTheme.titleMedium,
                railHeight: 16,
              ),
              const SizedBox(height: 8),
              for (final text in [
                l10n.walkthroughDemoLine1,
                l10n.walkthroughDemoLine2,
              ])
                AmountLine(_demoLine(text, s.digits), source: text),
            ],
          ),
        ),
      ],
    );
  }
}

/// Page 2: doubling the servings doubles every amount, and the unit word
/// agrees with the new number ("1½ كوب" → "3 أكواب").
class _ScaleDrawing extends StatelessWidget {
  const _ScaleDrawing();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final faded = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return _Frame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(l10n.servings(2, s.number(2)), style: faded),
              Icon(Icons.arrow_forward, size: 18, color: faded?.color),
              Text(
                l10n.servings(4, s.number(4)),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final text in [
            l10n.walkthroughDemoLine1,
            l10n.walkthroughDemoLine2,
          ]) ...[
            ContentText(
              _demoLine(text, s.digits),
              source: text,
              style: faded?.copyWith(decoration: TextDecoration.lineThrough),
            ),
            AmountLine(_demoLine(text, s.digits, factor: 2), source: text),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Page 3: one step, big, with the timer read from its own text (COOK-4).
class _CookDrawing extends StatelessWidget {
  const _CookDrawing();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final step = l10n.walkthroughDemoStep;
    final shownStep = digitsFor(step, s.digits) == DigitStyle.arabic
        ? easternDigits(step)
        : step;
    final timers = findDurations(step);
    return _Frame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DigitBox(
            l10n.stepOf(s.number(3), s.number(5)),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          ContentText(
            shownStep,
            source: step,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (final d in timers)
            Chip(
              avatar: const Icon(Icons.timer_outlined),
              label: Text(
                s.digits == DigitStyle.arabic
                    ? easternDigits(clockText(d))
                    : clockText(d),
                textDirection: TextDirection.ltr,
              ),
            ),
        ],
      ),
    );
  }
}

/// Page 4: a recipe on the plan, and the one grocery list it feeds.
class _PlanDrawing extends StatelessWidget {
  const _PlanDrawing();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final theme = Theme.of(context);
    Widget item(String text, {bool done = false}) => Padding(
      padding: const EdgeInsetsDirectional.only(top: 4),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_box : Icons.check_box_outline_blank,
            size: 20,
            color: done
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AmountLine(
              _demoLine(text, s.digits),
              source: text,
              style: done
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
          ),
        ],
      ),
    );
    return _Frame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(l10n.planTitle, style: theme.textTheme.titleSmall),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(32, 4, 0, 0),
            child: ContentText(l10n.walkthroughDemoRecipe),
          ),
          const Divider(height: 24),
          Row(
            children: [
              Icon(
                Icons.shopping_basket_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(l10n.groceriesTitle, style: theme.textTheme.titleSmall),
            ],
          ),
          item(l10n.walkthroughDemoLine1),
          item(l10n.walkthroughDemoLine2),
          item(l10n.walkthroughDemoLine3, done: true),
        ],
      ),
    );
  }
}
