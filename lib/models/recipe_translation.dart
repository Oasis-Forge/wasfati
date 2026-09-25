/// Translate a recipe (IMP-14–IMP-16, SRV-11, Decision 9): when to offer
/// it, the words that go to the server, and the copy rebuilt from what
/// comes back. Pure Dart, no Flutter or network: `Importer.translate` does
/// the sending.
///
/// Amounts never go through the model (IMP-15). Only words are sent, each
/// keyed by an ID that means something only inside one request: the
/// title, group names, each read line's name and note, a line the parser
/// couldn't read (whole), and each step. Every line is rebuilt with its own
/// amount, range and unit ID, and a returned text whose numbers — or, for a
/// step, whose cook-mode timers (COOK-4) — differ from what was sent is
/// dropped for the original text. So is one the editor wouldn't read back
/// as the same single line (a line break, a trailing colon), and a line
/// the parser couldn't read that comes back with an amount in it.
library;

import 'durations.dart';
import 'quantity/arabic_text.dart';
import 'quantity/format.dart';
import 'quantity/parser.dart';
import 'recipe.dart';
import 'recipe_text.dart';

/// SRV-11: the server refuses more words than this in one request, so a
/// recipe past either limit is never sent (the app says it's too long).
const maxTranslateItems = 300;
const maxTranslateChars = 20000;

/// One piece of a recipe's words, keyed by an ID that is only meaningful
/// within one translate request (SRV-11).
typedef TranslationItem = ({String id, String text});

final _letter = RegExp(r'\p{L}', unicode: true);
final _arabicScript = RegExp(r'\p{Script=Arabic}', unicode: true);
final _latinScript = RegExp(r'\p{Script=Latin}', unicode: true);

/// Whether at least half of [text]'s letters are in the app's script
/// (Arabic letters for Arabic, Latin for English); null when it has no
/// letters at all, so "250" or "½" counts for neither side.
bool? _inAppScript(String text, {required bool arabicApp}) {
  final script = arabicApp ? _arabicScript : _latinScript;
  var letters = 0, inScript = 0;
  for (final m in _letter.allMatches(text)) {
    letters++;
    if (script.hasMatch(m[0]!)) inScript++;
  }
  if (letters == 0) return null;
  return inScript * 2 >= letters;
}

/// IMP-14: "ترجم إلى العربية" (or "Translate to English") shows when fewer
/// than half of the recipe's title, ingredient names and steps are in the
/// app's script. Items with no letters at all don't count either way.
bool offersTranslation(Recipe r, {required bool arabicApp}) {
  final texts = [
    r.title,
    for (final s in r.ingredients)
      for (final l in s.items) l.name,
    for (final s in r.steps)
      for (final step in s.items) step.text,
  ];
  var counted = 0, inScript = 0;
  for (final t in texts) {
    final v = _inAppScript(t, arabicApp: arabicApp);
    if (v == null) continue;
    counted++;
    if (v) inScript++;
  }
  return counted > 0 && inScript * 2 < counted;
}

/// A line the parser read an amount from (REC-5): only its name and note
/// are words to send. Any other line was shown as written, so it's sent
/// whole (IMP-15).
bool _read(IngredientLine l) => l.min != null;

/// IMP-15: what one translate request sends for [r], in recipe order. Empty
/// texts (an unnamed group, a line with no note) aren't sent.
List<TranslationItem> translationItems(Recipe r) {
  final out = <TranslationItem>[];
  void add(String id, String? text) {
    if (text != null && text.trim().isNotEmpty) out.add((id: id, text: text));
  }

  add('t', r.title);
  var g = 0, l = 0, s = 0;
  for (final section in r.ingredients) {
    add('g${g++}', section.name);
    for (final line in section.items) {
      final i = l++;
      if (_read(line)) {
        add('n$i', line.name);
        add('o$i', line.note);
      } else {
        add('l$i', line.original);
      }
    }
  }
  for (final section in r.steps) {
    add('g${g++}', section.name);
    for (final step in section.items) {
      add('s${s++}', step.text);
    }
  }
  return out;
}

/// Whether [items] fit SRV-11's limits for one request.
bool fitsTranslateLimits(List<TranslationItem> items) =>
    items.length <= maxTranslateItems &&
    items.fold<int>(0, (n, i) => n + i.text.length) <= maxTranslateChars;

final _numberToken = RegExp(r'(\d+(?:\.\d+)?)(?:\s*/\s*(\d+))?|([½¼¾⅓⅔⅛⅜⅝⅞])');

const _glyphValue = {
  '½': '1/2',
  '¼': '1/4',
  '¾': '3/4',
  '⅓': '1/3',
  '⅔': '2/3',
  '⅛': '1/8',
  '⅜': '3/8',
  '⅝': '5/8',
  '⅞': '7/8',
};

String _canon(String digits) {
  final n = num.parse(digits);
  return n == n.truncate() ? '${n.truncate()}' : '$n';
}

/// The numbers in [text], in any digit style (QTY-1), sorted: "1½" and
/// "1 1/2" both give ["1", "1/2"], "١٥" gives ["15"]. Order doesn't count,
/// since a translation may move words around; a value that changed, or
/// appeared, or went missing does (IMP-15).
List<String> numbersIn(String text) {
  final out = <String>[
    for (final m in _numberToken.allMatches(westernDigits(text)))
      if (m[3] != null)
        _glyphValue[m[3]]!
      else if (m[2] != null)
        '${_canon(m[1]!)}/${_canon(m[2]!)}'
      else
        _canon(m[1]!),
  ];
  return out..sort();
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// IMP-15: a returned text keeps exactly the numbers that were sent.
bool sameNumbers(String sent, String returned) =>
    _sameList(numbersIn(sent), numbersIn(returned));

/// COOK-4, IMP-15: a returned step starts exactly the timers the original
/// did, so cook mode behaves the same in either language.
bool sameTimers(String sent, String returned) {
  final a = findDurations(sent)..sort();
  final b = findDurations(returned)..sort();
  return _sameList(a, b);
}

/// Any line break a text box could show: a returned text holding one would
/// be more than one line in the editor (IMP-15, REC-4).
final _lineBreak = RegExp('[\n\r\u000B\u000C\u0085  ]');

/// A line ending with a colon is a group name in the editor (REC-4).
bool _endsWithColon(String text) {
  final t = text.trimRight();
  return t.endsWith(':') || t.endsWith('：');
}

/// Whether the editor's own reading (REC-4, REC-5) gives [line] back as
/// itself: one ingredient, not a group name or several lines, so Save
/// keeps its amount, range and unit rather than reading new ones.
bool _survivesEditor(IngredientLine line) {
  final before = [
    Section<IngredientLine>(id: '', items: [line]),
  ];
  final back = ingredientsFromText(ingredientsToText(before), before, () => '');
  return back.length == 1 &&
      back.single.items.length == 1 &&
      identical(back.single.items.single, line);
}

/// An amount line's text in the target language, for the editor (the page
/// itself shows the parsed form, QTY-5): "2 cups flour, sifted" or
/// "2 كوب طحين، منخول". The amount and unit are the line's own.
String _composedLine(IngredientLine l, {required bool arabic}) {
  final main = formatLine(
    ParsedLine(
      original: '',
      min: l.min,
      max: l.max,
      unitId: l.unitId,
      name: l.name,
    ),
    arabic: arabic,
  );
  final note = l.note;
  if (note == null || note.isEmpty) return main;
  return '$main${arabic ? '، ' : ', '}$note';
}

/// The translated copy (IMP-14) and how many of its items kept their
/// original text because the model changed a number or a timer (IMP-15).
typedef TranslatedRecipe = ({Recipe recipe, int keptOriginal});

/// Builds the translated copy of [r] from [returned] (IMP-14, IMP-15), or
/// null when an ID sent is missing, an ID comes back twice, or one comes
/// back that was never sent: then nothing changes, and the caller offers
/// "Try again" without using the quota (SRV-7).
///
/// The copy is a new recipe with new IDs throughout (REC-2) — [id] for
/// itself, [newId] for every group, line and step — so saving it can never
/// touch the original's rows. It keeps the source URL and type, servings,
/// times, cookbooks, tags, notes and unit view; its cooked count starts at
/// 0 and it has no rating. [translatedFrom] is the original's ID when the
/// original is a saved recipe. The photo is the caller's to copy.
TranslatedRecipe? applyTranslation(
  Recipe r,
  List<TranslationItem> returned, {
  required bool toArabic,
  required String id,
  required String Function() newId,
  required DateTime now,
  String? translatedFrom,
}) {
  final sent = {for (final i in translationItems(r)) i.id: i.text};
  final got = <String, String>{};
  for (final i in returned) {
    if (!sent.containsKey(i.id) || got.containsKey(i.id)) return null;
    got[i.id] = i.text;
  }
  if (got.length != sent.length) return null;

  var kept = 0;

  /// The returned text for [key] (one that was sent), trimmed, if it's
  /// safe to use: not empty, within [max], with the same numbers — and for
  /// a step the same timers — as the text sent, on one line, and (outside
  /// the title) not ending with a colon the sent text didn't end with.
  /// Otherwise null, and the item keeps its original text.
  ///
  /// The editor is the only way to save the copy, and it reads its text
  /// boxes one line at a time (REC-4): a line break would split the item
  /// into new lines whose amounts are read from the model's words, and a
  /// trailing colon would turn it into a group name and drop its amount.
  String? take(String key, {int? max, bool step = false}) {
    final original = sent[key]!;
    final t = got[key]!.trim();
    if (t.isEmpty ||
        (max != null && t.length > max) ||
        _lineBreak.hasMatch(t) ||
        (key != 't' && _endsWithColon(t) && !_endsWithColon(original)) ||
        !sameNumbers(original, t) ||
        (step && !sameTimers(original, t))) {
      return null;
    }
    return t;
  }

  var title = r.title;
  if (sent.containsKey('t')) {
    final t = take('t');
    if (t == null) {
      kept++;
    } else {
      title = t.length > Recipe.maxTitle ? t.substring(0, Recipe.maxTitle) : t;
    }
  }

  var g = 0, l = 0, s = 0;
  String? groupName(String? name) {
    final key = 'g${g++}';
    if (!sent.containsKey(key)) return name;
    final t = take(key);
    if (t == null) kept++;
    return t ?? name;
  }

  IngredientLine unchanged(IngredientLine line) => IngredientLine(
    id: newId(),
    original: line.original,
    min: line.min,
    max: line.max,
    unitId: line.unitId,
    name: line.name,
    note: line.note,
  );

  /// IMP-15: a translated line is used only if the editor reads it back as
  /// itself on Save — one line, not a group name — so the copy that's saved
  /// is the one the preview showed, with the line's own amount.
  IngredientLine checked(IngredientLine built, IngredientLine line) {
    if (_survivesEditor(built)) return built;
    kept++;
    return unchanged(line);
  }

  IngredientLine lineOf(IngredientLine line) {
    final i = l++;
    if (_read(line)) {
      final nameKey = 'n$i', noteKey = 'o$i';
      final name = sent.containsKey(nameKey) ? take(nameKey) : line.name;
      final note = sent.containsKey(noteKey) ? take(noteKey) : line.note;
      if (name == null || (line.note != null && note == null)) {
        kept++;
        return unchanged(line);
      }
      // The amount, range and unit are the line's own (IMP-15).
      final rebuilt = IngredientLine(
        id: newId(),
        original: '',
        min: line.min,
        max: line.max,
        unitId: line.unitId,
        name: name,
        note: note,
      );
      return checked(
        IngredientLine(
          id: rebuilt.id,
          original: _composedLine(rebuilt, arabic: toArabic),
          min: rebuilt.min,
          max: rebuilt.max,
          unitId: rebuilt.unitId,
          name: rebuilt.name,
          note: rebuilt.note,
        ),
        line,
      );
    }
    final text = take('l$i');
    final p = parseIngredient(text ?? '');
    // QTY-1, QTY-8: the parser reads amounts from words and dual forms too
    // ("ملعقتان ملح" is 2 spoons), so a returned line it reads an amount
    // from, or a unit other than the original's, was given one by the
    // model: it keeps its original text (IMP-15).
    if (text == null ||
        p.min != null ||
        (p.unitId != null && p.unitId != line.unitId)) {
      kept++;
      return unchanged(line);
    }
    // A line shown as written (REC-5) stays so: the returned text is its
    // new original, and only its name and note are read from it — the
    // amount and unit are still the original line's (none).
    return checked(
      IngredientLine(
        id: newId(),
        original: text,
        min: line.min,
        max: line.max,
        unitId: line.unitId,
        name: p.name,
        note: p.note,
      ),
      line,
    );
  }

  RecipeStep stepOf(RecipeStep step) {
    final key = 's${s++}';
    if (!sent.containsKey(key)) return RecipeStep(id: newId(), text: step.text);
    final t = take(key, max: RecipeStep.maxLength, step: true);
    if (t == null) kept++;
    return RecipeStep(id: newId(), text: t ?? step.text);
  }

  final ingredients = [
    for (final section in r.ingredients)
      Section(
        id: newId(),
        name: groupName(section.name),
        items: [for (final line in section.items) lineOf(line)],
      ),
  ];
  final steps = [
    for (final section in r.steps)
      Section(
        id: newId(),
        name: groupName(section.name),
        items: [for (final step in section.items) stepOf(step)],
      ),
  ];

  return (
    recipe: Recipe(
      id: id,
      title: title,
      sourceUrl: r.sourceUrl,
      sourceType: r.sourceType,
      prepMinutes: r.prepMinutes,
      cookMinutes: r.cookMinutes,
      servings: r.servings,
      notes: r.notes,
      ingredients: ingredients,
      steps: steps,
      cookbookIds: r.cookbookIds,
      tags: r.tags,
      unitView: r.unitView,
      translatedFrom: translatedFrom,
      createdAt: now,
      updatedAt: now,
    ),
    keptOriginal: kept,
  );
}
