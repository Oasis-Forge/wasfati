// Sharing a recipe (SHARE-1–SHARE-4). Pure Dart: no Flutter imports, so it
// can be unit-tested without the widget tree, and Flutter's rendering layer
// (services/recipe_pages.dart) depends on this file, never the other way.
//
// Every translated word (headings, "المصدر", the footer line, plurals for
// servings and minutes) comes in as a parameter, filled in by the caller
// from AppLocalizations (LANG-2) — this file never guesses at a language.
import 'quantity/arabic_text.dart';
import 'quantity/convert.dart';
import 'quantity/format.dart';
import 'quantity/rational.dart';
import 'recipe.dart';

/// The app's Play Store page, on the last line of every shared recipe text
/// (SHARE-2) and nowhere else: not on a shared image (SHARE-4) or a shared
/// grocery list (GRO-6).
const wasfatiPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.oasisforge.wasfati';

// A "×2" mark has no direction of its own, so [factorLabel] wraps it the
// same way an amount is, or it reads reversed inside an Arabic line ("2×",
// must-fix, adversarial review).

/// The recipe as text (SHARE-1, SHARE-2): the title; one line with whichever
/// of servings and prep/cook times are set (REC-3, servings following
/// [factor]); the ingredients under [ingredientsHeading], with group
/// headings (REC-4), each line exactly as the recipe page shows it (QTY-5,
/// SCALE-6); the steps, numbered, under [stepsHeading], with group
/// headings; the source link, if any; and a last line naming the app, with
/// its Play link.
///
/// Never included (SHARE-1): notes, the kept original caption, rating,
/// tags, cookbooks or the cooked count — this reads only the fields it
/// needs from [r], so those can never leak in.
String recipeShareText(
  Recipe r, {
  Rational factor = Rational.one,
  UnitView view = UnitView.asWritten,
  DigitStyle digits = DigitStyle.western,
  required String ingredientsHeading,
  required String stepsHeading,
  required String footerLine,
  required String notScaledMark,
  required String Function(String line, String mark) unscaledLineText,
  required String Function(int servings) servingsLabel,
  required String Function(int minutes) prepTimeLabel,
  required String Function(int minutes) cookTimeLabel,
  required String Function(String url) sourceLabel,
}) {
  final sections = <String>[];

  final top = <String>[r.title];
  final facts = _factsLine(
    r,
    factor: factor,
    digits: digits,
    servingsLabel: servingsLabel,
    prepTimeLabel: prepTimeLabel,
    cookTimeLabel: cookTimeLabel,
  );
  if (facts != null) top.add(facts);
  sections.add(top.join('\n'));

  final ingredientLines = _ingredientLines(
    r,
    factor: factor,
    view: view,
    digits: digits,
    notScaledMark: notScaledMark,
    unscaledLineText: unscaledLineText,
  );
  if (ingredientLines.isNotEmpty) {
    sections.add([ingredientsHeading, ...ingredientLines].join('\n'));
  }

  final stepLines = _stepLines(r, digits: digits);
  final source = r.sourceUrl?.trim();
  if (stepLines.isNotEmpty || (source != null && source.isNotEmpty)) {
    final block = <String>[
      if (stepLines.isNotEmpty) ...[stepsHeading, ...stepLines],
      if (source != null && source.isNotEmpty) sourceLabel(source),
    ];
    sections.add(block.join('\n'));
  }

  sections.add('$footerLine\n$wasfatiPlayStoreUrl');

  return sections.join('\n\n');
}

String? _factsLine(
  Recipe r, {
  required Rational factor,
  required DigitStyle digits,
  required String Function(int servings) servingsLabel,
  required String Function(int minutes) prepTimeLabel,
  required String Function(int minutes) cookTimeLabel,
}) {
  final parts = <String>[];
  if (r.servings != null) {
    final scaled = Rational(r.servings!) * factor;
    parts.add(
      scaled.isWhole
          ? servingsLabel(scaled.whole)
          // A factor that doesn't land on a whole serving count shows the
          // multiplier instead, exactly as the ingredients section does
          // (SCALE-2): "×½", never a fractional serving count.
          : factorLabel(factor, digits),
    );
  } else if (factor != Rational.one) {
    // SCALE-6, should-fix (adversarial review): a recipe with no servings
    // still shows the current multiplier — the page's chips already do,
    // via the selected chip's own label — so the share isn't silently ×2
    // with no sign of it.
    parts.add(factorLabel(factor, digits));
  }
  if (r.prepMinutes != null) parts.add(prepTimeLabel(r.prepMinutes!));
  if (r.cookMinutes != null) parts.add(cookTimeLabel(r.cookMinutes!));
  return parts.isEmpty ? null : parts.join(' · ');
}

/// SCALE-4/SCALE-6, should-fix (adversarial review): while [factor] scales
/// the recipe, a line the scaler couldn't touch (to-taste, unreadable) gets
/// the same "not scaled" mark the ingredients section shows under it —
/// [notScaledMark] — through [unscaledLineText], never silently dropped.
List<String> _ingredientLines(
  Recipe r, {
  required Rational factor,
  required UnitView view,
  required DigitStyle digits,
  required String notScaledMark,
  required String Function(String line, String mark) unscaledLineText,
}) {
  final marking = factor != Rational.one;
  final lines = <String>[];
  for (final section in r.ingredients) {
    if (section.items.isEmpty) continue;
    if (section.name != null) lines.add(section.name!);
    for (final item in section.items) {
      final shown = showLine(item.parsed, factor: factor, view: view);
      final text = shownLineText(shown, digits);
      lines.add(
        marking && !shown.scalable
            ? unscaledLineText(text, notScaledMark)
            : text,
      );
    }
  }
  return lines;
}

List<String> _stepLines(Recipe r, {required DigitStyle digits}) {
  final lines = <String>[];
  var n = 0;
  for (final section in r.steps) {
    if (section.items.isEmpty) continue;
    if (section.name != null) lines.add(section.name!);
    for (final step in section.items) {
      n++;
      lines.add('${_stepNumber(n, step.text, digits)}. ${step.text}');
    }
  }
  return lines;
}

/// The step's number, in the recipe's own digit style, never the app
/// setting's for a line in another language (QTY-5, must-fix, adversarial
/// review): unlike the recipe page, where the number sits in its own
/// circle, the shared line has to carry it inline, so it follows the same
/// "always 123 outside Arabic" rule as the rest of the line.
String _stepNumber(int n, String stepText, DigitStyle digits) =>
    digitsFor(stepText, digits) == DigitStyle.arabic
    ? easternDigits('$n')
    : '$n';

// ---------------------------------------------------------------------------
// SHARE-3: the image pages, as a pure layout planner. The renderer
// (services/recipe_pages.dart) turns the plan this produces into PNG bytes;
// nothing here touches a canvas, a font or a file.
// ---------------------------------------------------------------------------

/// 1,080 × 1,350 px pages, below WhatsApp's resize limit (SHARE-3).
const shareImageWidth = 1080.0;
const shareImageHeight = 1350.0;

/// Side and top margin, and the space reserved for the footer band on every
/// page ("وصفاتي" and the page count, SHARE-3).
const shareMargin = 48.0;
const shareFooterHeight = 84.0;

/// Vertical gap between two blocks on the same page.
const shareBlockGap = 16.0;

/// A longer recipe offers text instead (SHARE-3).
const shareMaxPages = 6;

/// Body text is never smaller than this (SHARE-3), whatever a block is
/// shrunk to fit a page.
const shareMinFontSize = 32.0;

const _shareContentWidth = shareImageWidth - 2 * shareMargin;
const _sharePageContentHeight =
    shareImageHeight - shareMargin - shareFooterHeight;

/// What kind of content a [ShareBlock] carries, so the renderer knows how to
/// draw it (the photo aside, or a heading in the primary colour).
enum ShareBlockKind { photo, title, facts, heading, ingredient, step }

/// One piece of page content: never split across two pages (SHARE-3). Each
/// block carries the font size to draw its text at, so an oversized block
/// (a 2,000-character step, REC-6) can be redrawn smaller by the planner
/// without becoming two blocks.
class ShareBlock {
  const ShareBlock._(
    this.kind,
    this.text, {
    required this.fontSize,
    this.directionSource,
    this.forceNewPage = false,
  });

  factory ShareBlock.photo() =>
      const ShareBlock._(ShareBlockKind.photo, '', fontSize: 0);
  factory ShareBlock.title(String text) =>
      ShareBlock._(ShareBlockKind.title, text, fontSize: 44);
  factory ShareBlock.facts(String text) =>
      ShareBlock._(ShareBlockKind.facts, text, fontSize: 34);
  factory ShareBlock.heading(String text, {bool forceNewPage = false}) =>
      ShareBlock._(
        ShareBlockKind.heading,
        text,
        fontSize: 38,
        forceNewPage: forceNewPage,
      );
  // Body text's own size (36) is above the 32 px floor (SHARE-3), so a
  // block that doesn't fit a page still has room to shrink before it hits
  // [shareMinFontSize].
  factory ShareBlock.ingredient(String text, {String? directionSource}) =>
      ShareBlock._(
        ShareBlockKind.ingredient,
        text,
        fontSize: 36,
        directionSource: directionSource,
      );
  factory ShareBlock.step(String text, {String? directionSource}) =>
      ShareBlock._(
        ShareBlockKind.step,
        text,
        fontSize: 36,
        directionSource: directionSource,
      );

  final ShareBlockKind kind;
  final String text;
  final double fontSize;

  /// The text that decides which way this block reads (LANG-5, QTY-5,
  /// must-fix, adversarial review), when [text] itself isn't safe to sniff:
  /// a step's app-numbered line, or an ingredient's formatted, digit-styled
  /// one. Null for a block whose own [text] is never touched by the app's
  /// digit or numbering choices (the title, a heading, the facts line —
  /// the renderer decides that one from the UI language instead, not from
  /// [text] or this).
  final String? directionSource;

  /// SHARE-3: the steps section always starts its own page, never sharing
  /// one with the ingredients (should-fix, adversarial review) — true only
  /// for the top-level "الطريقة" heading, never a group name inside it.
  final bool forceNewPage;

  ShareBlock withFontSize(double size) => ShareBlock._(
    kind,
    text,
    fontSize: size,
    directionSource: directionSource,
    forceNewPage: forceNewPage,
  );

  @override
  String toString() => 'ShareBlock($kind, $fontSize, ${text.length} chars)';
}

/// Measures how tall [block] would render at [width] px, at its own
/// [ShareBlock.fontSize]. The renderer supplies a real `TextPainter`-backed
/// measurement (dart:ui); tests supply a fake one, so the planner itself
/// stays pure Dart.
typedef ShareMeasure = double Function(ShareBlock block, double width);

/// One page's worth of blocks, in order, plus its footer text ("٢/٣",
/// digits per setting, SHARE-3).
class SharePage {
  const SharePage(this.blocks, {required this.footer});
  final List<ShareBlock> blocks;
  final String footer;
}

/// The result of [planSharePages]: either the pages to render, or a flag
/// that the recipe doesn't fit within [shareMaxPages] pages even after
/// shrinking, so the caller should offer text instead (SHARE-3).
class ShareImagePlan {
  const ShareImagePlan.ok(this.pages) : tooLong = false;
  const ShareImagePlan.tooLong() : pages = const [], tooLong = true;
  final List<SharePage> pages;
  final bool tooLong;
}

/// Lays [blocks] out across pages (SHARE-3): a page breaks between blocks,
/// never inside one. A block taller than a whole page's content height (a
/// long step, REC-6) is redrawn smaller, down to [shareMinFontSize], rather
/// than split; if it still doesn't fit, or the recipe needs more than
/// [shareMaxPages] pages, the result flags "too long" instead of a partial
/// plan.
///
/// Two should-fix rules from the adversarial review keep a heading from
/// ever being the last thing shown on a page: a heading (a section heading
/// or a group name, REC-4) is only placed on a page that also has room for
/// the block right after it, and the steps section's own heading always
/// starts a fresh page ([ShareBlock.forceNewPage], matching SHARE-3's
/// "the steps follow on the next pages" literally). Neither rule applies
/// to an otherwise-empty page: a block always lands somewhere.
ShareImagePlan planSharePages(
  List<ShareBlock> blocks,
  ShareMeasure measure, {
  DigitStyle digits = DigitStyle.western,
}) {
  final pages = <List<ShareBlock>>[[]];
  var used = 0.0;

  for (var i = 0; i < blocks.length; i++) {
    var block = blocks[i];
    var height = measure(block, _shareContentWidth);

    if (height > _sharePageContentHeight) {
      var size = block.fontSize;
      while (height > _sharePageContentHeight && size > shareMinFontSize) {
        size -= 2;
        block = block.withFontSize(size);
        height = measure(block, _shareContentWidth);
      }
      if (height > _sharePageContentHeight) {
        return const ShareImagePlan.tooLong();
      }
    }

    final page = pages.last;
    final gap = page.isEmpty ? 0.0 : shareBlockGap;
    var breakBefore = false;

    if (page.isNotEmpty) {
      if (used + gap + height > _sharePageContentHeight) {
        breakBefore = true;
      } else if (block.forceNewPage) {
        breakBefore = true;
      } else if (block.kind == ShareBlockKind.heading &&
          i + 1 < blocks.length) {
        final nextHeight = measure(blocks[i + 1], _shareContentWidth);
        if (used + gap + height + shareBlockGap + nextHeight >
            _sharePageContentHeight) {
          breakBefore = true;
        }
      }
    }

    if (breakBefore) {
      pages.add([block]);
      used = height;
    } else {
      page.add(block);
      used += gap + height;
    }
  }

  if (pages.length > shareMaxPages) return const ShareImagePlan.tooLong();
  return ShareImagePlan.ok([
    for (var i = 0; i < pages.length; i++)
      SharePage(pages[i], footer: pageCounter(i + 1, pages.length, digits)),
  ]);
}

/// The footer page count (SHARE-3), in the user's digits: "2/3" or "٢/٣".
String pageCounter(int page, int total, DigitStyle digits) {
  final raw = '$page/$total';
  return digits == DigitStyle.arabic ? easternDigits(raw) : raw;
}

/// Builds the blocks for [r]'s image pages (SHARE-3), in the order they're
/// drawn: the photo (if [hasPhoto]), the title, the facts line, then the
/// ingredients under [ingredientsHeading] and the steps under
/// [stepsHeading], each with their own group headings (REC-4). Never
/// includes notes, tags, rating, cookbooks or the cooked count (SHARE-1).
/// An unscaled line is marked with [notScaledMark] through
/// [unscaledLineText], exactly as [recipeShareText] marks it (SCALE-6,
/// should-fix, adversarial review).
List<ShareBlock> shareBlocksFor(
  Recipe r, {
  required bool hasPhoto,
  Rational factor = Rational.one,
  UnitView view = UnitView.asWritten,
  DigitStyle digits = DigitStyle.western,
  required String ingredientsHeading,
  required String stepsHeading,
  required String notScaledMark,
  required String Function(String line, String mark) unscaledLineText,
  required String Function(int servings) servingsLabel,
  required String Function(int minutes) prepTimeLabel,
  required String Function(int minutes) cookTimeLabel,
}) {
  final blocks = <ShareBlock>[];
  if (hasPhoto) blocks.add(ShareBlock.photo());
  blocks.add(ShareBlock.title(r.title));

  final facts = _factsLine(
    r,
    factor: factor,
    digits: digits,
    servingsLabel: servingsLabel,
    prepTimeLabel: prepTimeLabel,
    cookTimeLabel: cookTimeLabel,
  );
  if (facts != null) blocks.add(ShareBlock.facts(facts));

  final marking = factor != Rational.one;
  final ingredientLines = _ingredientLines(
    r,
    factor: factor,
    view: view,
    digits: digits,
    notScaledMark: notScaledMark,
    unscaledLineText: unscaledLineText,
  );
  if (ingredientLines.isNotEmpty) {
    blocks.add(ShareBlock.heading(ingredientsHeading));
    for (final section in r.ingredients) {
      if (section.items.isEmpty) continue;
      if (section.name != null) blocks.add(ShareBlock.heading(section.name!));
      for (final item in section.items) {
        final shown = showLine(item.parsed, factor: factor, view: view);
        final text = shownLineText(shown, digits);
        blocks.add(
          ShareBlock.ingredient(
            marking && !shown.scalable
                ? unscaledLineText(text, notScaledMark)
                : text,
            // LANG-5, must-fix (adversarial review): reads by the line as
            // the user wrote it, never by the formatted, digit-styled text
            // this block actually shows (matches ContentText's `source` on
            // the recipe page).
            directionSource: item.parsed.original,
          ),
        );
      }
    }
  }

  final hasSteps = r.steps.any((s) => s.items.isNotEmpty);
  if (hasSteps) {
    // SHARE-3: the steps section always starts its own page (should-fix,
    // adversarial review), never sharing one with the ingredients above.
    blocks.add(ShareBlock.heading(stepsHeading, forceNewPage: true));
    var n = 0;
    for (final section in r.steps) {
      if (section.items.isEmpty) continue;
      if (section.name != null) blocks.add(ShareBlock.heading(section.name!));
      for (final step in section.items) {
        n++;
        blocks.add(
          ShareBlock.step(
            '${_stepNumber(n, step.text, digits)}. ${step.text}',
            // must-fix (adversarial review): reads by the step's own
            // words, not the app-numbered prefix (QTY-5).
            directionSource: step.text,
          ),
        );
      }
    }
  }

  return blocks;
}
