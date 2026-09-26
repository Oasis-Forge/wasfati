import 'dart:math' as math;

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
import '../widgets/recipe_cover.dart';
import '../widgets/step_rail.dart';
import '../widgets/sufra_card.dart';
import '../widgets/timer_ring.dart';

/// RUN-4: what makes Wasfati different, in four pages — importing a post,
/// amounts that scale in proper Arabic, cook mode, and planning and
/// shopping. Every page has Skip; with reduce motion on, Next jumps instead
/// of sliding. Each page's picture is drawn in Flutter on a large soft
/// accent shape — recipe tiles with drawn covers (LOOK-10), cards and
/// simple painters, never a bitmap (LOOK-6) — in the chosen accent and
/// digits, and the amounts in it go through the real parser and formatter,
/// so what a page claims is exactly what the app does.
///
/// [onDone] runs on Skip and on the last page's button (the first run marks
/// itself complete there). Without one — replayed from Settings — the
/// walkthrough just closes.
class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  static const pageCount = 4;

  /// Each page dot's key, for tests: `dotKey(0)` is the first page's.
  static Key dotKey(int page) => ValueKey('walkthrough-dot-$page');

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
    final theme = Theme.of(context);
    final decor = Decor.of(context);
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
            Expanded(
              child: Stack(
                children: [
                  PageView(
                    controller: _pages,
                    onPageChanged: (p) => setState(() => _page = p),
                    children: [
                      for (final (title, body, drawing) in pages)
                        _Page(title: title, body: body, drawing: drawing),
                    ],
                  ),
                  PositionedDirectional(
                    top: 4,
                    end: 8,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _finish,
                      child: Text(l10n.walkthroughSkip),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                decor.gutter,
                8,
                decor.gutter,
                16,
              ),
              child: Column(
                children: [
                  _Dots(
                    index: _page,
                    count: WalkthroughScreen.pageCount,
                    label: l10n.walkthroughPageOf(
                      s.number(_page + 1),
                      s.number(WalkthroughScreen.pageCount),
                    ),
                  ),
                  const SizedBox(height: 24),
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: const StadiumBorder(),
                      shadows: decor.floatShadow,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _next,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                last
                                    ? l10n.walkthroughStart
                                    : l10n.walkthroughNext,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right, size: 20),
                          ],
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

/// One page: the drawing on its soft accent shape, then the title at 30/700
/// and the body. Scrolls when 1.3x text makes it taller than the screen.
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.body, required this.drawing});

  final String title;
  final String body;
  final Widget drawing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = Decor.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stage = (constraints.maxHeight * 0.56).clamp(200.0, 440.0);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The drawing is decoration: a screen reader reads the
              // page's heading and text instead.
              SizedBox(
                height: stage,
                child: ExcludeSemantics(child: _Stage(child: drawing)),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  decor.gutter,
                  16,
                  decor.gutter,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Names the route for TalkBack, as an AppBar title
                    // would (replayed from Settings it's a route of its own).
                    Semantics(
                      header: true,
                      namesRoute: true,
                      child: Text(
                        title,
                        style: theme.textTheme.displaySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      body,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The drawings' canvas: [_canvas] design units (the mockup's own CSS px),
/// scaled down to fit the page, on the large soft accent shape. A picture,
/// so its text keeps the size it was drawn at, whatever the text scale —
/// the page's title and body carry the words at the reader's size.
const _canvas = Size(390, 420);

class _Stage extends StatelessWidget {
  const _Stage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FittedBox(
      child: SizedBox.fromSize(
        size: _canvas,
        child: MediaQuery.withNoTextScaling(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -15,
                top: 0,
                width: 420,
                height: 420,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    // An organic blob: four elliptical corners, each pair
                    // summing to the side it shares.
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.elliptical(176, 189),
                      topRight: Radius.elliptical(244, 168),
                      bottomRight: Radius.elliptical(265, 252),
                      bottomLeft: Radius.elliptical(155, 231),
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the reader is: a long accent pill for this page, the pages
/// already seen filled in from the reading start (the right, in Arabic),
/// and the rest as outlines' colour. Read aloud as "Page 2 of 4".
class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.count, required this.label});

  final int index;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                key: WalkthroughScreen.dotKey(i),
                duration: duration,
                width: i == index ? 24 : 8,
                height: 8,
                margin: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i <= index ? scheme.primary : scheme.outline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A white card in a drawing: [SufraCard] at 20dp corners, unclipped so a
/// tile's source badge can sit on its edge.
SufraCard _drawnCard({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsetsDirectional.all(16),
}) => SufraCard(radius: 20, clip: false, padding: padding, child: child);

/// The source badges' own colours (Welcome.dc.html): a short-video app's
/// near-black, and a photo-post app's orange-to-purple gradient. Brand-like
/// marks drawn as generic badges, never a logo, so they sit outside the
/// palette tokens and stay the same in both looks and brightnesses.
const _videoBadge = Color(0xFF111111);
const _photoBadge = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
  stops: [0, 0.55, 1],
);

/// A demo line, scaled by [factor] and shown exactly as the recipe page
/// would show it: the user's digits, units that agree (QTY-5, QTY-6).
String _demoLine(String text, DigitStyle digits, {int factor = 1}) {
  final line = IngredientLine.parse('walkthrough', text);
  return shownLineText(showLine(line.parsed, factor: Rational(factor)), digits);
}

/// Where a tile's recipe came from, drawn as a small round badge.
enum _Source { video, photos, web }

/// Page 1: three saved recipes, tilted like cards on a table, each with
/// the badge of where it came from — a video, a photo post, a website.
class _ImportDrawing extends StatelessWidget {
  const _ImportDrawing();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 30,
          top: 164,
          child: _Tile(
            id: 'walkthrough-soup',
            title: l10n.walkthroughTileSoup,
            source: _Source.video,
            degrees: -6,
          ),
        ),
        Positioned(
          left: 210,
          top: 164,
          child: _Tile(
            id: 'walkthrough-kabsa',
            title: l10n.walkthroughDemoRecipe,
            source: _Source.web,
            degrees: -2,
            badgeAtStart: true,
          ),
        ),
        Positioned(
          left: 120,
          top: 104,
          child: _Tile(
            id: 'walkthrough-fattoush',
            title: l10n.walkthroughTileFattoush,
            source: _Source.photos,
            degrees: 3,
          ),
        ),
      ],
    );
  }
}

/// A recipe tile: its drawn cover (LOOK-10), its name, and its source
/// badge on a corner.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.id,
    required this.title,
    required this.source,
    required this.degrees,
    this.badgeAtStart = false,
  });

  final String id;
  final String title;
  final _Source source;
  final double degrees;
  final bool badgeAtStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (
      Color? fill,
      Gradient? gradient,
      Color glyph,
      IconData icon,
    ) = switch (source) {
      _Source.video => (_videoBadge, null, Colors.white, Icons.music_note),
      _Source.photos => (
        null,
        _photoBadge,
        Colors.white,
        Icons.camera_alt_outlined,
      ),
      _Source.web => (
        cs.surfaceContainerLowest,
        null,
        cs.onSurface,
        Icons.public,
      ),
    };
    final badge = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: fill,
        gradient: gradient,
        shape: BoxShape.circle,
        // LOOK-6: the light lift; none in dark.
        boxShadow: Decor.of(context).liftShadow,
      ),
      child: Icon(icon, size: 14, color: glyph),
    );
    return Transform.rotate(
      angle: degrees * math.pi / 180,
      child: SizedBox(
        width: 150,
        child: _drawnCard(
          padding: const EdgeInsetsDirectional.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 134,
                    height: 104,
                    child: RecipeCover(
                      recipeId: id,
                      title: title,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  PositionedDirectional(
                    top: -8,
                    start: badgeAtStart ? -8 : null,
                    end: badgeAtStart ? null : -8,
                    child: badge,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
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
    final faded = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PositionedDirectional(
          start: 45,
          end: 45,
          top: 84,
          child: Transform.rotate(
            angle: -2 * math.pi / 180,
            child: _drawnCard(
              padding: const EdgeInsetsDirectional.all(20),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (final text in [
                    l10n.walkthroughDemoLine1,
                    l10n.walkthroughDemoLine2,
                  ]) ...[
                    ContentText(
                      _demoLine(text, s.digits),
                      source: text,
                      style: faded?.copyWith(
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    AmountLine(
                      _demoLine(text, s.digits, factor: 2),
                      source: text,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Page 3: one step, big, with the timer read from its own text (COOK-4)
/// on a ring, under cook mode's segmented step rail (LOOK-14).
class _CookDrawing extends StatelessWidget {
  const _CookDrawing();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final step = l10n.walkthroughDemoStep;
    final shownStep = digitsFor(step, s.digits) == DigitStyle.arabic
        ? easternDigits(step)
        : step;
    final timers = findDurations(step);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PositionedDirectional(
          start: 45,
          end: 45,
          top: 40,
          child: _drawnCard(
            padding: const EdgeInsetsDirectional.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cook mode's own rail (LOOK-14), on step 3 of 5.
                const StepRail(current: 2, total: 5),
                const SizedBox(height: 12),
                DigitBox(
                  l10n.stepOf(s.number(3), s.number(5)),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 6),
                ContentText(
                  shownStep,
                  source: step,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                for (final d in timers)
                  Center(
                    child: _TimerRing(
                      label: s.digits == DigitStyle.arabic
                          ? easternDigits(clockText(d))
                          : clockText(d),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A timer as cook mode draws it ([TimerRing]), part-way through.
class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: 112,
      child: TimerRing(
        fraction: 0.7,
        stroke: 8,
        child: Center(
          child: Text(
            label,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.titleMedium,
          ),
        ),
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
    final cs = theme.colorScheme;
    Widget heading(IconData icon, String text) => Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text(text, style: theme.textTheme.titleSmall),
      ],
    );
    Widget item(String text, {bool done = false}) => Padding(
      padding: const EdgeInsetsDirectional.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? cs.secondary : null,
              border: done ? null : Border.all(color: cs.outline, width: 1.5),
            ),
            child: done
                ? Icon(Icons.check, size: 14, color: cs.onSecondary)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AmountLine(
              _demoLine(text, s.digits),
              source: text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: done
                  ? TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: cs.onSurfaceVariant,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PositionedDirectional(
          start: 36,
          top: 54,
          width: 230,
          child: Transform.rotate(
            angle: -3 * math.pi / 180,
            child: _drawnCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading(Icons.calendar_month_outlined, l10n.planTitle),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox.square(
                        dimension: 44,
                        child: RecipeCover(
                          recipeId: 'walkthrough-kabsa',
                          title: l10n.walkthroughDemoRecipe,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ContentText(
                          l10n.walkthroughDemoRecipe,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        PositionedDirectional(
          end: 30,
          top: 184,
          width: 250,
          child: Transform.rotate(
            angle: 2 * math.pi / 180,
            child: _drawnCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading(Icons.shopping_basket_outlined, l10n.groceriesTitle),
                  const SizedBox(height: 2),
                  item(l10n.walkthroughDemoLine1),
                  item(l10n.walkthroughDemoLine2),
                  item(l10n.walkthroughDemoLine3, done: true),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
