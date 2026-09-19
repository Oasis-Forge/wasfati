import 'arabic_text.dart';
import 'parser.dart';
import 'rational.dart';
import 'units.dart';

enum DigitStyle { western, arabic }

/// Scales a line by [factor] with the rounding of SCALE-3. A line with no
/// amount comes back unchanged and [ScaledLine.scaled] is false (SCALE-4).
ScaledLine scaleLine(ParsedLine line, Rational factor) {
  if (line.min == null || factor == Rational.one) {
    return ScaledLine(line, scaled: line.min != null);
  }
  final step = _stepFor(line.unit);
  Rational round(Rational v) {
    final s = step(v);
    final r = v.roundTo(s);
    return r == Rational.zero ? s : r; // never scale down to nothing
  }

  return ScaledLine(
    ParsedLine(
      original: line.original,
      min: round(line.min! * factor),
      max: line.max == null ? null : round(line.max! * factor),
      unitId: line.unitId,
      name: line.name,
      note: line.note,
    ),
    scaled: true,
  );
}

class ScaledLine {
  const ScaledLine(this.line, {required this.scaled});
  final ParsedLine line;

  /// False for a to-taste or unreadable line, which the screen marks
  /// "not scaled" when the factor isn't ×1 (SCALE-4).
  final bool scaled;
}

Rational Function(Rational) _stepFor(Unit? unit) {
  final id = unit?.id;
  if (id == 'g' || id == 'ml') {
    return (v) => v > Rational(100) ? Rational(5) : Rational.one;
  }
  if (id == 'kg' || id == 'l') {
    return (_) => Rational(1, 100); // up to 2 decimals
  }
  if (id == 'cup' || unit?.kind == UnitKind.spoon) {
    return (_) => Rational.eighth; // cups and spoons
  }
  return (_) => Rational.half; // حبة، فص… and lines with no unit
}

const _glyphs = {
  (1, 2): '½',
  (1, 4): '¼',
  (3, 4): '¾',
  (1, 3): '⅓',
  (2, 3): '⅔',
  (1, 8): '⅛',
  (3, 8): '⅜',
  (5, 8): '⅝',
  (7, 8): '⅞',
};

/// Shows an amount (QTY-5): fractions as glyphs for kitchen and count units,
/// never 0.5; decimals only for g/ml/kg/l.
String formatAmount(
  Rational v,
  Unit? unit, {
  DigitStyle digits = DigitStyle.western,
}) {
  final metric = unit != null && const {'g', 'ml', 'kg', 'l'}.contains(unit.id);
  String text;
  if (v.isWhole) {
    text = '${v.whole}';
  } else if (metric) {
    text = v.toDouble().toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  } else {
    final whole = v.whole;
    final frac = v + Rational(-whole);
    final glyph = _glyphs[(frac.numerator, frac.denominator)];
    text = glyph == null
        ? v.toDouble().toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')
        : '${whole == 0 ? '' : whole}$glyph';
  }
  return digits == DigitStyle.arabic ? easternDigits(text) : text;
}

/// The Arabic unit name that agrees with the amount (QTY-6): 1 → singular,
/// 2 → dual, 3–10 → plural, 11+ → accusative singular. Fractions take the
/// singular. (In the app this comes from ICU plural messages, LANG-2.)
String arabicUnitName(Unit unit, Rational amount) {
  if (!amount.isWhole) return unit.ar.one;
  final n = amount.whole;
  if (n == 1) return unit.ar.one;
  if (n == 2) return unit.ar.two;
  if (n >= 3 && n <= 10) return unit.ar.few;
  return unit.ar.many;
}

/// A whole line for display, e.g. "1½ كوب أرز". The amount is wrapped in a
/// left-to-right isolate so it reads correctly inside Arabic text (QTY-5).
String formatLine(
  ParsedLine line, {
  bool arabic = true,
  DigitStyle digits = DigitStyle.western,
  bool isolate = false,
}) {
  final parts = <String>[];
  if (line.min != null) {
    var amount = formatAmount(line.min!, line.unit, digits: digits);
    if (line.max != null) {
      amount += '–${formatAmount(line.max!, line.unit, digits: digits)}';
    }
    if (isolate) {
      amount =
          '${String.fromCharCode(0x2066)}$amount${String.fromCharCode(0x2069)}';
    }
    parts.add(amount);
  }
  final unit = line.unit;
  if (unit != null) {
    final ref = line.max ?? line.min;
    parts.add(
      arabic
          ? (ref == null ? unit.ar.one : arabicUnitName(unit, ref))
          : (ref == null || ref <= Rational.one ? unit.en.$1 : unit.en.$2),
    );
  }
  if (line.name.isNotEmpty) parts.add(line.name);
  if (line.note != null) parts.add(line.note!);
  return parts.join(' ');
}

extension on Rational {
  bool operator <=(Rational o) => compareTo(o) <= 0;
}
