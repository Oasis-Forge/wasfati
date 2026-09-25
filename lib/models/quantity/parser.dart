import 'arabic_text.dart';
import 'rational.dart';
import 'units.dart';

/// One ingredient line after parsing (REC-5). [original] is kept verbatim so
/// every parse can be undone; [min] is null when there is no amount (QTY-2).
class ParsedLine {
  const ParsedLine({
    required this.original,
    this.min,
    this.max,
    this.unitId,
    required this.name,
    this.note,
  });

  final String original;
  final Rational? min;

  /// Upper end of a range ("2–3"); null for a single amount.
  final Rational? max;
  final String? unitId;
  final String name;
  final String? note;

  bool get hasAmount => min != null;

  /// A line with no amount is never scaled (QTY-2, SCALE-4).
  bool get toTaste => min == null;

  Unit? get unit => unitId == null ? null : unitById(unitId!);

  @override
  String toString() =>
      'ParsedLine(${min ?? '-'}${max == null ? '' : '–$max'} '
      '${unitId ?? '-'} | $name${note == null ? '' : ' | $note'})';
}

const _fractionGlyphs = <String, Rational>{
  '½': Rational.half,
  '¼': Rational.quarter,
  '¾': Rational.threeQuarters,
  '⅓': Rational.third,
  '⅔': Rational.twoThirds,
  '⅛': Rational.eighth,
};

/// Number words (QTY-1), matched after [normalizeArabic].
final Map<String, Rational> _numberWords = {
  for (final e in {
    'واحد': 1,
    'واحده': 1,
    'وحده': 1,
    'اثنين': 2,
    'اثنان': 2,
    'اثنتين': 2,
    'اتنين': 2,
    'ثنتين': 2,
    'ثلاث': 3,
    'ثلاثه': 3,
    'تلات': 3,
    'تلاته': 3,
    'اربع': 4,
    'اربعه': 4,
    'خمس': 5,
    'خمسه': 5,
    'ست': 6,
    'سته': 6,
    'سبع': 7,
    'سبعه': 7,
    'ثمان': 8,
    'ثماني': 8,
    'ثمانيه': 8,
    'تمن': 8,
    'تمانيه': 8,
    'تسع': 9,
    'تسعه': 9,
    'عشر': 10,
    'عشره': 10,
  }.entries)
    e.key: Rational(e.value),
  'نصف': Rational.half,
  'نص': Rational.half,
  'ربع': Rational.quarter,
  'ثلث': Rational.third,
};

const _rangeWords = {'الي', 'او', 'to', 'or', '-', '–', '—'};
const _halfSuffixes = {'ونصف', 'ونص'};
const _toTastePhrases = [
  'حسب الذوق',
  'حسب الرغبه',
  'حسب الحاجه',
  'حسب الطلب',
  'للتزيين',
  'اختياري',
  'to taste',
  'as needed',
  'optional',
];

final _decimal = RegExp(r'^\d+(\.\d+)?$');
final _slash = RegExp(r'^(\d+)/(\d+)$');
final _glyphMixed = RegExp(r'^(\d*)([½¼¾⅓⅔⅛])$');
final _dashRange = RegExp(r'^(\d+(?:\.\d+)?)[-–—](\d+(?:\.\d+)?)$');
final _leadingBullet = RegExp(r'^[\s\-–—•·*▪◦●○✓✔️🔸🔹📌]+');

/// Parses one ingredient line (QTY-1, QTY-2, QTY-3, QTY-8). Never guesses:
/// text it can't read stays in [ParsedLine.name].
ParsedLine parseIngredient(String line) {
  final original = line;
  // "3 أكواب (450 غرام) دقيق": the bracketed equivalent becomes a note.
  final brackets = <String>[];
  final cleaned = westernDigits(line.trim())
      .replaceFirst(_leadingBullet, '')
      .replaceAllMapped(RegExp(r'\(([^)]*)\)'), (m) {
        brackets.add(m[1]!.trim());
        return ' ';
      });
  final tokens = cleaned
      .replaceAllMapped(
        RegExp(r'(\d)([^\d\s./½¼¾⅓⅔⅛\-–—])'),
        (m) => '${m[1]} ${m[2]}',
      ) // "2كوب" → "2 كوب"
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  final norm = tokens.map(normalizeArabic).toList();

  // Amount and unit at the start, or else after the name ("ملح 1 ملعقة").
  var hit = _amountAndUnitAt(tokens, norm, 0);
  var nameTokens = <String>[];
  if (hit == null) {
    for (var k = 1; k < tokens.length; k++) {
      final h = _amountAndUnitAt(tokens, norm, k);
      // A bare "0" after the name ("ملح 0") is the same placeholder as one
      // at the start: dropped, leaving the line with no amount (QTY-1).
      if (h != null && (h.min != null || h.placeholder)) {
        hit = h;
        nameTokens = tokens.sublist(0, k);
        break;
      }
    }
  }
  final ParsedLine parsed;
  if (hit == null) {
    parsed = _withNote(original, null, null, null, tokens);
  } else {
    final rest = [...nameTokens, ...tokens.sublist(hit.end)];
    parsed = _withNote(original, hit.min, hit.max, hit.unit?.id, rest);
  }
  if (brackets.isEmpty) return parsed;
  return ParsedLine(
    original: parsed.original,
    min: parsed.min,
    max: parsed.max,
    unitId: parsed.unitId,
    name: parsed.name,
    note: [?parsed.note, ...brackets].join('، '),
  );
}

ParsedLine _withNote(
  String original,
  Rational? min,
  Rational? max,
  String? unitId,
  List<String> nameTokens,
) {
  var name = nameTokens.join(' ').trim();
  String? note;
  final normName = normalizeArabic(name);
  for (final p in _toTastePhrases) {
    final i = normName.indexOf(p);
    if (i >= 0) {
      // Positions line up because normalization only swaps or drops marks,
      // and a name rarely carries marks; fall back to the whole phrase.
      note = p;
      final cut = _cutPhrase(name, p);
      name = cut;
      break;
    }
  }
  name = name.replaceAll(RegExp(r'^[\s:،,\-–]+|[\s:،,\-–.]+$'), '');
  return ParsedLine(
    original: original,
    min: min,
    max: max,
    unitId: unitId,
    name: name,
    note: note,
  );
}

String _cutPhrase(String name, String normalizedPhrase) {
  final words = name.split(' ');
  final phraseWords = normalizedPhrase.split(' ').length;
  for (var i = 0; i + phraseWords <= words.length; i++) {
    final chunk = normalizeArabic(words.sublist(i, i + phraseWords).join(' '));
    if (chunk == normalizedPhrase) {
      return [
        ...words.sublist(0, i),
        ...words.sublist(i + phraseWords),
      ].join(' ');
    }
  }
  return name;
}

class _Hit {
  _Hit(this.min, this.max, this.unit, this.end, {this.placeholder = false});
  final Rational? min;
  final Rational? max;
  final Unit? unit;
  final int end;

  /// The amount was a bare "0": a site's placeholder for "no amount given",
  /// read as no amount rather than the number zero (QTY-1).
  final bool placeholder;
}

/// Reads an amount (optional), then a unit (optional), from token [i].
_Hit? _amountAndUnitAt(List<String> tokens, List<String> norm, int i) {
  var j = i;
  Rational? min;
  Rational? max;

  final first = _number(tokens, norm, j);
  if (first != null) {
    min = first.$1;
    j = first.$2;
    max = first.$3;
    // "2 - 3", "2 الى 3", "2 او 3"
    if (max == null && j + 1 < tokens.length && _rangeWords.contains(norm[j])) {
      final second = _number(tokens, norm, j + 1);
      if (second != null && second.$1 > min) {
        max = second.$1;
        j = second.$2;
      }
    }
  }

  // Some recipe sites print a bare "0" (or "٠") where no amount was given
  // (QTY-1; found measuring the import server, 23 September 2026). Only a
  // zero that is the whole amount counts: "0.5", "10", "٠٫٥", "0 1/2" and
  // a range starting at zero ("0-1") are read as numbers, as before.
  final placeholder =
      first != null && max == null && first.$2 == i + 1 && min == Rational.zero;
  if (placeholder) min = null;

  final u = _unitAt(norm, j);
  Unit? unit;
  if (u != null) {
    unit = u.$1;
    if (min == null && !placeholder) {
      if (u.$3) {
        min = Rational(2); // a dual form means two (QTY-8)
      } else if (unit.kind != UnitKind.informal) {
        if (!u.$4) return null; // a plural with no number: just a name
        min = Rational.one; // "كوب رز" means one cup (QTY-8)
      }
    }
    j = u.$2;
  }
  // A placeholder with no amount: the "0" is dropped, and a unit after it
  // is still the line's unit ("0 رشة ملح" reads as "رشة ملح").
  if (placeholder) return _Hit(null, null, unit, j, placeholder: true);
  if (min == null && unit == null) return null;
  if (min == null && unit != null && unit.kind == UnitKind.informal) {
    return _Hit(null, null, unit, j); // "رشة زعفران" is to taste (QTY-2)
  }
  // Only a single-letter unit right after a number counts ("١ ك"), so a
  // name starting with "ل" or "ك" is never read as a unit.
  if (unit != null && min != null && first == null && norm[i].length == 1) {
    return null;
  }

  // "كوب ونصف", "2 ونص"
  if (min != null && j < norm.length && _halfSuffixes.contains(norm[j])) {
    min = min + Rational.half;
    if (max != null) max = max + Rational.half;
    j++;
  } else if (min != null &&
      j + 1 < norm.length &&
      norm[j] == 'و' &&
      (norm[j + 1] == 'نصف' || norm[j + 1] == 'نص')) {
    min = min + Rational.half;
    j += 2;
  }
  return _Hit(min, max, unit, j);
}

/// A number starting at token [i]: (value, next index, range end if the
/// token itself was a range like "2-3").
(Rational, int, Rational?)? _number(
  List<String> tokens,
  List<String> norm,
  int i,
) {
  if (i >= tokens.length) return null;
  final t = tokens[i];

  final range = _dashRange.firstMatch(t);
  if (range != null) {
    final a = Rational.fromDecimal(range[1]!);
    final b = Rational.fromDecimal(range[2]!);
    if (b > a) return (a, i + 1, b);
  }

  Rational? value;
  final glyph = _glyphMixed.firstMatch(t);
  final slash = _slash.firstMatch(t);
  if (_decimal.hasMatch(t)) {
    value = Rational.fromDecimal(t);
  } else if (slash != null && int.parse(slash[2]!) != 0) {
    value = Rational(int.parse(slash[1]!), int.parse(slash[2]!));
  } else if (glyph != null) {
    final whole = glyph[1]!.isEmpty ? 0 : int.parse(glyph[1]!);
    value = Rational(whole) + _fractionGlyphs[glyph[2]!]!;
  } else if (_numberWords.containsKey(norm[i])) {
    value = _numberWords[norm[i]];
  } else if (_fractionGlyphs.containsKey(t)) {
    value = _fractionGlyphs[t];
  }
  if (value == null) return null;

  // A fraction glyph before the whole number: "¼ 1 كوب" is 1¼ cups.
  if (!value.isWhole &&
      _fractionGlyphs.containsKey(t) &&
      i + 1 < tokens.length &&
      RegExp(r'^\d+$').hasMatch(tokens[i + 1])) {
    return (value + Rational(int.parse(tokens[i + 1])), i + 2, null);
  }

  // Mixed number over two tokens: "1 1/2", "1 ½"
  if (value.isWhole && i + 1 < tokens.length) {
    final next = tokens[i + 1];
    final s = _slash.firstMatch(next);
    if (s != null && int.parse(s[1]!) < int.parse(s[2]!)) {
      return (
        value + Rational(int.parse(s[1]!), int.parse(s[2]!)),
        i + 2,
        null,
      );
    }
    if (_fractionGlyphs.containsKey(next)) {
      return (value + _fractionGlyphs[next]!, i + 2, null);
    }
  }
  return (value, i + 1, null);
}

/// The longest unit form starting at token [i]: (unit, next index, dual).
(Unit, int, bool, bool)? _unitAt(List<String> norm, int i) {
  if (i >= norm.length) return null;
  for (final (form, unit, dual, singular) in unitForms) {
    final words = form.split(' ');
    if (i + words.length > norm.length) continue;
    final chunk = norm.sublist(i, i + words.length).join(' ');
    // Allow a trailing "." or ":" on the last word ("م.ك.", "كوب:").
    if (chunk == form || chunk.replaceAll(RegExp(r'[.:،,]$'), '') == form) {
      return (unit, i + words.length, dual, singular);
    }
  }
  return null;
}
