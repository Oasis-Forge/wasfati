import 'aisles.dart';
import 'quantity/arabic_text.dart';
import 'quantity/convert.dart';
import 'quantity/format.dart';
import 'quantity/rational.dart';
import 'quantity/units.dart';
import 'recipe.dart';

/// GRO-5's "By recipe" toggle. Remembered in [AppSettings] (`settings.dart`)
/// so it survives a restart, and so it's carried in backups (BAK-6).
enum GroceryView { byAisle, byRecipe }

/// Lets [GroceryItem.copyWith] clear a nullable field: pass `null` to clear
/// it, leave it out to keep it.
const Object _keep = Object();

/// One grocery item (GRO-1): a name, an aisle (GRO-4), a done state, and
/// the amounts it was merged from. The number shown is never stored on the
/// item; it's computed from [amounts] by [totalOf] (GRO-3, GRO-5).
class GroceryItem {
  const GroceryItem({
    required this.id,
    required this.name,
    required this.normName,
    required this.aisle,
    this.doneAt,
    this.handAdded = false,
    this.amounts = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;

  /// As first seen; later merges never rename the item.
  final String name;

  /// The [groceryKey] merges match on (GRO-3).
  final String normName;
  final Aisle aisle;

  /// Null means "to buy"; set means it's in the collapsed "تم" section.
  final DateTime? doneAt;

  /// Whether this item ever took a line typed by hand (GRO-5's "أضفتها
  /// بنفسك"), so `removeRecipe` never cleans it up just because its recipe
  /// amounts are gone.
  final bool handAdded;

  final List<GroceryAmount> amounts;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDone => doneAt != null;

  GroceryItem copyWith({
    String? name,
    Aisle? aisle,
    Object? doneAt = _keep,
    bool? handAdded,
    List<GroceryAmount>? amounts,
    DateTime? updatedAt,
    Object? deletedAt = _keep,
  }) => GroceryItem(
    id: id,
    name: name ?? this.name,
    normName: normName,
    aisle: aisle ?? this.aisle,
    doneAt: doneAt == _keep ? this.doneAt : doneAt as DateTime?,
    handAdded: handAdded ?? this.handAdded,
    amounts: amounts ?? this.amounts,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt == _keep ? this.deletedAt : deletedAt as DateTime?,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'norm_name': normName,
    'aisle': aisle.name,
    'done_at': doneAt?.millisecondsSinceEpoch,
    'hand_added': handAdded ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
  };

  /// Builds the item row; [amounts] are attached by the repository.
  factory GroceryItem.fromMap(
    Map<String, Object?> m, {
    List<GroceryAmount> amounts = const [],
  }) => GroceryItem(
    id: m['id']! as String,
    name: m['name']! as String,
    normName: m['norm_name']! as String,
    aisle:
        Aisle.values.where((a) => a.name == m['aisle']).firstOrNull ??
        Aisle.other,
    doneAt: _time(m['done_at']),
    handAdded: (m['hand_added'] as int?) == 1,
    amounts: amounts,
    createdAt: _time(m['created_at'])!,
    updatedAt: _time(m['updated_at'])!,
    deletedAt: _time(m['deleted_at']),
  );
}

/// One amount attached to a [GroceryItem] (GRO-1, GRO-3): what a recipe
/// line or a hand-typed line contributed. [min] and [max] are both null for
/// a to-taste line with no amount (QTY-2); [max] alone is set for a range.
class GroceryAmount {
  const GroceryAmount({
    required this.id,
    required this.itemId,
    this.min,
    this.max,
    this.unitId,
    this.recipeId,
    this.planEntryId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String itemId;
  final Rational? min;

  /// The upper end of a range; null for a single amount.
  final Rational? max;
  final String? unitId;

  /// Where this amount came from (GRO-5's "By recipe"), no foreign key: the
  /// list outlives the recipe or plan entry (GRO-7).
  final String? recipeId;
  final String? planEntryId;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'item_id': itemId,
    'num': min?.numerator,
    'den': min?.denominator,
    'max_num': max?.numerator,
    'max_den': max?.denominator,
    'unit_id': unitId,
    'recipe_id': recipeId,
    'plan_entry_id': planEntryId,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
  };

  factory GroceryAmount.fromMap(Map<String, Object?> m) => GroceryAmount(
    id: m['id']! as String,
    itemId: m['item_id']! as String,
    min: _rational(m['num'], m['den']),
    max: _rational(m['max_num'], m['max_den']),
    unitId: m['unit_id'] as String?,
    recipeId: m['recipe_id'] as String?,
    planEntryId: m['plan_entry_id'] as String?,
    createdAt: _time(m['created_at'])!,
    updatedAt: _time(m['updated_at'])!,
    deletedAt: _time(m['deleted_at']),
  );
}

Rational? _rational(Object? n, Object? d) =>
    n == null ? null : Rational(n as int, d! as int);

DateTime? _time(Object? ms) => ms == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);

/// [name] normalized (ORG-4), split into words with a leading "ال" dropped
/// from each. Shared by [groceryKey] and [isWaterOrIce].
List<String> _normalizedWords(String name) {
  final words = normalizeArabic(name.trim()).split(RegExp(r'\s+'));
  return [
    for (final w in words)
      if (w.isNotEmpty)
        (w.startsWith('ال') && w.length > 2 ? w.substring(2) : w),
  ];
}

/// GRO-3's merge key: normalized (ORG-4), a leading "ال" dropped from each
/// word, spaces collapsed. Names in different languages never share a key
/// (no dictionary, just like ORG-4's search).
String groceryKey(String name) => _normalizedWords(name).join(' ');

/// A line about to enter the grocery list (GRO-2, PLAN-5): already scaled
/// and converted (SCALE-6), built from a recipe's or a plan entry's
/// [showLine] result.
class IncomingLine {
  const IncomingLine({
    required this.name,
    this.min,
    this.max,
    this.unitId,
    this.recipeId,
    this.planEntryId,
  });

  final String name;
  final Rational? min;
  final Rational? max;
  final String? unitId;
  final String? recipeId;
  final String? planEntryId;
}

/// The lines PLAN-5 sends to groceries for one recipe scaled by [factor]
/// (SCALE-6, GRO-3): water and ice dropped (GRO-2), each carrying the exact
/// pre-rounding amount ([ShownLine.exactMin]/[exactMax]) so summing several
/// scaled lines later rounds once, not once per line (should-fix, two
/// reviews: double rounding). Moved out of the screen so the scaling math
/// has a test of its own (should-fix, UI review: "screens stay
/// presentational").
List<IncomingLine> groceryLinesForRecipe(
  Recipe recipe,
  Rational factor, {
  String? planEntryId,
}) {
  final lines = <IncomingLine>[];
  for (final section in recipe.ingredients) {
    for (final line in section.items) {
      if (isWaterOrIce(line.name)) continue;
      final shown = showLine(
        line.parsed,
        factor: factor,
        view: recipe.unitView,
      );
      lines.add(
        IncomingLine(
          name: shown.line.name,
          min: shown.exactMin,
          max: shown.exactMax,
          unitId: shown.line.unitId,
          recipeId: recipe.id,
          planEntryId: planEntryId,
        ),
      );
    }
  }
  return lines;
}

/// Bare names that mean water or ice, so they're never sent to groceries
/// (GRO-2): matched as the *whole* name, never a word buried inside a
/// longer one (should-fix, adversary and UI reviews: "ماء الورد", "ice
/// cream" and "coconut water" are real groceries, not water or ice).
final _waterOrIceWords = {
  'ماء',
  'مي',
  'مياه',
  'ثلج',
  'water',
  'ice',
}.map(normalizeArabic).toSet();

/// A state word that can follow a bare water or ice name and still mean
/// water or ice ("ماء بارد", "ice cold"), never on its own.
final _waterOrIceStates = {
  'بارد',
  'ساخن',
  'دافئ',
  'فاتر',
  'مغلي',
  'مثلج',
  'cold',
  'warm',
  'hot',
  'boiling',
  'lukewarm',
}.map(normalizeArabic).toSet();

/// "مكعبات ثلج" / "ice cubes": the one two-word ice phrase GRO-2 also drops.
final _iceCubes = {normalizeArabic('مكعبات ثلج'), normalizeArabic('ice cubes')};

/// GRO-2: whether [name] is water or ice, and so never listed. Matched on
/// the whole name (normalized, ORG-4, a leading "ال" dropped): a name that
/// merely *contains* a water or ice word — "ماء الورد", "ماء جوز الهند",
/// "rose water", "ice cream", "water chestnuts" — is a real grocery.
bool isWaterOrIce(String name) {
  final words = _normalizedWords(name);
  if (words.length == 1) return _waterOrIceWords.contains(words.single);
  if (words.length == 2) {
    if (_waterOrIceWords.contains(words[0]) &&
        _waterOrIceStates.contains(words[1])) {
      return true;
    }
    if (_iceCubes.contains(words.join(' '))) return true;
  }
  return false;
}

/// A unit's merge family (GRO-3, SCALE-5): mass and volume (including cups
/// and the sized spoons, but never the unknown "spoon", which has no
/// [Unit.metricFactor]) merge across different exact units; anything else
/// stays its own family. Driven by [Unit.kind] and [Unit.metricFactor], not
/// a fixed id list, so a new metric-convertible unit (oz, lb, fl oz, QTY-3)
/// merges in on its own (should-fix, adversary review).
String _familyOf(Unit unit) {
  if (unit.metricFactor == null) return 'unit:${unit.id}';
  return switch (unit.kind) {
    UnitKind.mass => 'mass',
    UnitKind.volume || UnitKind.spoon => 'volume',
    UnitKind.count || UnitKind.informal => 'unit:${unit.id}',
  };
}

/// Fixed display order for [totalOf]'s parts, so a mixed total reads the
/// same whatever order its amounts arrived in (should-fix, adversary
/// review): mass, then volume, then count, then other units in the unit
/// table's own order.
int _familyRank(String family) => switch (family) {
  'mass' => 0,
  'volume' => 1,
  'count' => 2,
  _ => 100 + units.indexWhere((u) => u.id == family.substring(5)),
};

/// The GRO-3 total for one item's amounts, as parts to show ("طماطم: 2 حبة
/// + علبة" is two parts). A part with a null amount means the item is
/// to-taste only, with nothing to show (QTY-2).
///
/// - The same unit adds up in that unit: 1 كوب + 2 كوب = 3 أكواب.
/// - Different units of the same kind (mass, or volume including cups and
///   sized spoons) merge into one metric total, g or ml, stepping up to kg
///   or l from 1,000 (SCALE-5): 1 كغ + 500 غ = 1.5 كغ.
/// - A bare count and a count in "حبة" are the same unit for this purpose:
///   2 بصل + حبة بصل = 3 بصل.
/// - A range contributes its upper end: 2–3 + 1 = 4.
/// - A to-taste amount (no [GroceryAmount.min]) adds nothing.
/// - Anything else (a can and a count, cups and grams) stays its own part;
///   when there's more than one part, a count part is labelled "piece" (a
///   count-only item stays a bare "3 بصل", should-fix, adversary review).
/// - Every part is rounded once, at the end ([roundForUnit], SCALE-3).
List<(Rational?, String?)> totalOf(List<GroceryAmount> amounts) {
  final sums = <String, Rational>{}; // exact bucket key -> running total
  final familyOf = <String, String>{}; // bucket key -> its family
  final families = <String>{}; // every family seen
  var sawAmount = false;
  var sawToTaste = false;

  for (final a in amounts) {
    if (a.min == null) {
      sawToTaste = true;
      continue;
    }
    sawAmount = true;
    final value = a.max ?? a.min!;
    final unit = a.unitId == null ? null : unitById(a.unitId!);
    final bucket = (unit == null || unit.id == 'piece')
        ? 'count'
        : 'unit:${unit.id}';
    if (!sums.containsKey(bucket)) {
      sums[bucket] = Rational.zero;
      final family = bucket == 'count' ? 'count' : _familyOf(unit!);
      familyOf[bucket] = family;
      families.add(family);
    }
    sums[bucket] = sums[bucket]! + value;
  }

  if (!sawAmount) return sawToTaste ? const [(null, null)] : const [];

  final ordered = families.toList()
    ..sort((a, b) => _familyRank(a).compareTo(_familyRank(b)));
  final parts = <(Rational?, String?)>[];
  for (final family in ordered) {
    final keys = [
      for (final e in familyOf.entries)
        if (e.value == family) e.key,
    ];
    switch (family) {
      case 'count':
        // A bare count reads fine alone ("3 بصل"), but ambiguous next to
        // another part ("2 + 1 علبة" looks like 3 cans), so it's labelled.
        final id = ordered.length > 1 ? 'piece' : null;
        parts.add((roundForUnit(sums['count']!, null), id));
      case 'mass':
        parts.add(_merged(sums, keys, smallId: 'g', bigId: 'kg'));
      case 'volume':
        parts.add(_merged(sums, keys, smallId: 'ml', bigId: 'l'));
      default:
        final id = family.substring(5); // 'unit:'
        parts.add((roundForUnit(sums[family]!, unitById(id)), id));
    }
  }
  return parts;
}

/// One mass or volume family's total: kept in its own unit when only one
/// exact unit contributed, else merged into metric and stepped up past
/// 1,000 (SCALE-5). A single small unit (g, ml) steps up on its own too —
/// 900 g + 200 g is 1.1 كغ, not "1100 غرامًا" (must-fix, adversary review).
(Rational?, String?) _merged(
  Map<String, Rational> sums,
  List<String> keys, {
  required String smallId,
  required String bigId,
}) {
  if (keys.length == 1) {
    final id = keys.single.substring(5);
    final sum = sums[keys.single]!;
    if (id == smallId && sum.compareTo(Rational.thousand) >= 0) {
      final big = unitById(bigId);
      return (roundForUnit(sum / Rational.thousand, big), bigId);
    }
    return (roundForUnit(sum, unitById(id)), id);
  }
  var base = Rational.zero;
  for (final key in keys) {
    final id = key.substring(5);
    base = base + sums[key]! * unitById(id).metricFactor!;
  }
  if (base.compareTo(Rational.thousand) >= 0) {
    final big = unitById(bigId);
    return (roundForUnit(base / Rational.thousand, big), bigId);
  }
  final small = unitById(smallId);
  return (roundForUnit(base, small), smallId);
}

/// One item's amount as shown (GRO-5, GRO-6): its [totalOf] parts joined
/// the way a multi-part total reads ("2 حبة + علبة"), each formatted by
/// [formatAmount] (already-localized text, QTY-5's digit style, QTY-6's
/// unit agreement; [name] decides QTY-5's own language and digits, not the
/// app's, should-fix: three reviews). Empty for a to-taste-only item.
String groceryAmountText(
  List<GroceryAmount> amounts, {
  required String name,
  required String Function(Rational amount, String? unitId, String name)
  formatAmount,
}) =>
    totalOf(amounts)
        .where((p) => p.$1 != null)
        .map((p) => formatAmount(p.$1!, p.$2, name))
        .join(' + ');

/// GRO-6's share text: only items not done, a title line, the aisle
/// headings in GRO-4's order, one "• [2] كغ طماطم" line per item (the
/// number wrapped in QTY-5's isolate, not shown here to keep this comment's
/// own direction unambiguous), in the user's digits, so the
/// amount and its item name each read the right way inside the other's
/// direction (must-fix, two reviews: the isolate used to wrap the unit
/// too, forcing it to the wrong side of the number in Arabic). [aisleLabel]
/// and [formatAmount] hand back already-localized, already-isolated text
/// (LANG-2, QTY-5). No link, no app name (ADS-9).
String groceryShareText(
  List<GroceryItem> items, {
  required String title,
  required String Function(Aisle aisle) aisleLabel,
  required String Function(Rational amount, String? unitId, String name)
  formatAmount,
}) {
  final toBuy = items.where((i) => !i.isDone).toList();
  if (toBuy.isEmpty) return '';
  final byAisle = <Aisle, List<GroceryItem>>{};
  for (final item in toBuy) {
    (byAisle[item.aisle] ??= []).add(item);
  }
  final lines = <String>[title];
  for (final aisle in Aisle.values) {
    final inAisle = byAisle[aisle];
    if (inAisle == null || inAisle.isEmpty) continue;
    lines.add('');
    lines.add(aisleLabel(aisle));
    for (final item in inAisle) {
      final amountText = groceryAmountText(
        item.amounts,
        name: item.name,
        formatAmount: formatAmount,
      );
      lines.add(
        amountText.isEmpty ? '• ${item.name}' : '• $amountText ${item.name}',
      );
    }
  }
  return lines.join('\n');
}
