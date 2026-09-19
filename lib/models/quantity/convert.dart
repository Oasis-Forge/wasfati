import 'arabic_text.dart';
import 'format.dart';
import 'parser.dart';
import 'rational.dart';
import 'units.dart';

/// SCALE-5: how a recipe's amounts are shown. Remembered per recipe.
enum UnitView { asWritten, metric, kitchen }

/// Grams per cup (240 ml) for common ingredients, Arabic and English names
/// (SCALE-5). More specific names come first, so "سكر بني" isn't "سكر".
/// Only these convert between volume and mass; everything else keeps its
/// own kind of unit. Liquids are shown in ml, not grams, in the metric view.
const densityTable = <(List<String> names, int gramsPerCup, bool liquid)>[
  (['سكر بني', 'brown sugar'], 220, false),
  (['سكر بودره', 'سكر ناعم', 'powdered sugar', 'icing sugar'], 120, false),
  (['جوز الهند', 'coconut'], 85, false),
  (
    ['معجون الطماطم', 'معجون طماطم', 'صلصه الطماطم', 'tomato paste'],
    260,
    false,
  ),
  (['جبن مبشور', 'جبنه مبشوره', 'grated cheese'], 100, false),
  (['بيكنج بودر', 'باكينج باودر', 'baking powder'], 220, false),
  (['بيكربونات', 'baking soda'], 220, false),
  (['طحينه', 'tahini'], 240, false),
  (['طحين', 'دقيق', 'flour'], 120, false),
  (['سكر', 'sugar'], 200, false),
  (['ارز', 'رز', 'rice'], 185, false),
  (['زبده', 'butter'], 227, false),
  (['سمن', 'ghee'], 220, false),
  (['زيت', 'oil'], 218, true),
  (['حليب', 'milk'], 245, true),
  (['ماء', 'مي', 'مياه', 'water'], 240, true),
  (['مرق', 'مرقه', 'broth', 'stock'], 240, true),
  (['عسل', 'honey'], 340, false),
  (['دبس', 'molasses'], 330, false),
  (['لبنه', 'labneh'], 250, false),
  (['زبادي', 'لبن', 'yogurt', 'yoghurt'], 245, false),
  (['قشطه', 'كريمه', 'cream'], 240, true),
  (['عدس', 'lentils', 'lentil'], 190, false),
  (['برغل', 'bulgur'], 175, false),
  (['سميد', 'semolina'], 170, false),
  (['شوفان', 'oats'], 90, false),
  (['كاكاو', 'cocoa'], 85, false),
  (['نشا', 'cornstarch', 'corn starch'], 128, false),
  (['بقسماط', 'breadcrumbs'], 110, false),
  (['ملح', 'salt'], 290, false),
  (['مكسرات', 'nuts'], 120, false),
  (['زبيب', 'raisins'], 150, false),
  (['تمر', 'dates'], 150, false),
  (['حمص', 'chickpeas'], 200, false),
];

/// Grams per millilitre for [name], or null when it isn't in the table.
Rational? densityFor(String name) => _entry(name)?.$1;

/// Whether [name] is a liquid in the table (water, milk, broth, oil, cream).
bool isLiquid(String name) => _entry(name)?.$2 ?? false;

(Rational, bool)? _entry(String name) {
  final n = normalizeArabic(name);
  final words = n.split(RegExp(r'\s+'));
  for (final (names, grams, liquid) in densityTable) {
    for (final raw in names) {
      final key = normalizeArabic(raw);
      final hit = key.contains(' ')
          ? n.contains(key)
          : words.any((w) => w == key || w == 'ال$key' || w == '${key}s');
      if (hit) return (Rational(grams, 240), liquid);
    }
  }
  return null;
}

/// A line ready to show: scaled by [factor] and converted to [view], then
/// rounded once, the SCALE-3 way, for the unit it ends up in.
class ShownLine {
  const ShownLine(this.line, {required this.scalable, this.converted = false});
  final ParsedLine line;

  /// False for a to-taste or unreadable line; the screen marks it "not
  /// scaled" when the factor isn't ×1 (SCALE-4).
  final bool scalable;
  final bool converted;
}

ShownLine showLine(
  ParsedLine line, {
  Rational factor = Rational.one,
  UnitView view = UnitView.asWritten,
}) {
  if (line.min == null) return ShownLine(line, scalable: false);
  if (factor == Rational.one && view == UnitView.asWritten) {
    return ShownLine(line, scalable: true);
  }
  var min = line.min! * factor;
  var max = line.max == null ? null : line.max! * factor;
  var unit = line.unit;
  var converted = false;

  final target = _convert(unit, line.name, view);
  if (target != null) {
    final (to, ratio) = target;
    min = min * ratio;
    if (max != null) max = max * ratio;
    unit = to;
    converted = true;
  }
  // Big metric amounts step up: 1500 g → 1.5 kg, 1200 ml → 1.2 l.
  if (unit != null &&
      (unit.id == 'g' || unit.id == 'ml') &&
      min >= Rational(1000)) {
    final up = unitById(unit.id == 'g' ? 'kg' : 'l');
    min = min / Rational(1000);
    if (max != null) max = max / Rational(1000);
    unit = up;
  }
  // Kitchen view: a tiny cup amount reads better in spoons.
  if (view == UnitView.kitchen && unit?.id == 'cup' && min < Rational(1, 4)) {
    final spoons = min * Rational(16); // tbsp per cup
    final tbsp = spoons >= Rational.one;
    unit = unitById(tbsp ? 'tbsp' : 'tsp');
    min = tbsp ? spoons : spoons * Rational(3);
    if (max != null) max = max * Rational(tbsp ? 16 : 48);
    converted = true;
  }

  return ShownLine(
    ParsedLine(
      original: line.original,
      min: roundForUnit(min, unit),
      max: max == null ? null : roundForUnit(max, unit),
      unitId: unit?.id,
      name: line.name,
      note: line.note,
    ),
    scalable: true,
    converted: converted,
  );
}

extension on Rational {
  bool operator >=(Rational o) => compareTo(o) >= 0;
}

/// The unit to convert [from] into for [view], with the amount ratio.
(Unit, Rational)? _convert(Unit? from, String name, UnitView view) {
  if (from == null || view == UnitView.asWritten) return null;
  final ml = from.kind == UnitKind.volume || from.kind == UnitKind.spoon
      ? from
            .metricFactor // ml per unit (null for a spoon of unknown size)
      : null;
  final grams = from.kind == UnitKind.mass ? from.metricFactor : null;
  final density = densityFor(name); // g per ml

  switch (view) {
    case UnitView.metric:
      if (ml == null || from.id == 'ml' || from.id == 'l') return null;
      // Cups and spoons → grams when the density is known, else ml.
      // Liquids stay in ml.
      return density != null && !isLiquid(name)
          ? (unitById('g'), ml * density)
          : (unitById('ml'), ml);
    case UnitView.kitchen:
      if (from.id == 'cup' || from.id == 'tbsp' || from.id == 'tsp') {
        return null; // already kitchen units
      }
      if (ml != null) return (unitById('cup'), ml / Rational.cupMl);
      if (grams != null && density != null) {
        return (unitById('cup'), grams / density / Rational.cupMl);
      }
      return null;
    case UnitView.asWritten:
      return null;
  }
}
