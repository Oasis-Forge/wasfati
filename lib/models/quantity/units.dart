import 'arabic_text.dart';
import 'rational.dart';

/// How a unit behaves when scaled and shown (SCALE-3, QTY-5).
enum UnitKind { mass, volume, spoon, count, informal }

/// A unit from the fixed table (QTY-3). [forms] are what the parser accepts;
/// a form in [dualForms] also means "two" on its own (QTY-8).
class Unit {
  const Unit({
    required this.id,
    required this.kind,
    required this.forms,
    this.dualForms = const [],
    this.metricFactor,
    required this.ar,
    required this.en,
  });

  final String id;
  final UnitKind kind;
  final List<String> forms;
  final List<String> dualForms;

  /// Grams per unit (mass) or millilitres per unit (volume, spoon); SCALE-5.
  final Rational? metricFactor;

  /// Arabic display forms: singular, dual, plural (3–10), accusative (11+).
  final ArabicForms ar;

  /// English display forms: singular and plural.
  final (String, String) en;
}

class ArabicForms {
  const ArabicForms(this.one, this.two, this.few, this.many);
  final String one;
  final String two;
  final String few;
  final String many;
}

/// The unit table (QTY-3). Longer forms are tried first, so "كيلو جرام" is
/// one unit and never "كيلو" + "جرام".
const units = <Unit>[
  Unit(
    id: 'kg',
    kind: UnitKind.mass,
    forms: [
      'كيلو جرام',
      'كيلوجرام',
      'كيلو غرام',
      'كيلوغرام',
      'كيلو',
      'كيلوات',
      'كجم',
      'كغ',
      'ك',
      'kg',
      'kgs',
      'kilogram',
      'kilograms',
      'kilo',
      'kilos',
    ],
    dualForms: ['كيلوين'],
    metricFactor: Rational.thousand,
    ar: ArabicForms('كيلو', 'كيلو', 'كيلو', 'كيلو'),
    en: ('kg', 'kg'),
  ),
  Unit(
    id: 'g',
    kind: UnitKind.mass,
    forms: [
      'جرام',
      'جرامات',
      'غرام',
      'غرامات',
      'جم',
      'غ',
      'g',
      'gr',
      'gram',
      'grams',
    ],
    metricFactor: Rational.one,
    ar: ArabicForms('غرام', 'غرامان', 'غرامات', 'غرامًا'),
    en: ('g', 'g'),
  ),
  Unit(
    id: 'l',
    kind: UnitKind.volume,
    forms: [
      'لتر',
      'لترات',
      'ليتر',
      'ل',
      'l',
      'liter',
      'liters',
      'litre',
      'litres',
    ],
    dualForms: ['لترين', 'لتران'],
    metricFactor: Rational.thousand,
    ar: ArabicForms('لتر', 'لتران', 'لترات', 'لترًا'),
    en: ('l', 'l'),
  ),
  Unit(
    id: 'ml',
    kind: UnitKind.volume,
    forms: ['مل', 'مليلتر', 'ملي', 'ml', 'milliliter', 'milliliters'],
    metricFactor: Rational.one,
    ar: ArabicForms('مل', 'مل', 'مل', 'مل'),
    en: ('ml', 'ml'),
  ),
  Unit(
    id: 'tbsp',
    kind: UnitKind.spoon,
    forms: [
      'ملعقه كبيره',
      'ملاعق كبيره',
      'معلقه كبيره',
      'معالق كبيره',
      'م.ك',
      'م ك',
      'tbsp',
      'tablespoon',
      'tablespoons',
      'tbs',
    ],
    dualForms: [
      'ملعقتين كبيرتين',
      'ملعقتان كبيرتان',
      'معلقتين كبار',
      'ملعقتين كبار',
    ],
    metricFactor: Rational.tbspMl,
    ar: ArabicForms(
      'ملعقة كبيرة',
      'ملعقتان كبيرتان',
      'ملاعق كبيرة',
      'ملعقة كبيرة',
    ),
    en: ('tbsp', 'tbsp'),
  ),
  Unit(
    id: 'tsp',
    kind: UnitKind.spoon,
    forms: [
      'ملعقه صغيره',
      'ملاعق صغيره',
      'معلقه صغيره',
      'معالق صغيره',
      'م.ص',
      'م ص',
      'tsp',
      'teaspoon',
      'teaspoons',
    ],
    dualForms: [
      'ملعقتين صغيرتين',
      'ملعقتان صغيرتان',
      'معلقتين صغار',
      'ملعقتين صغار',
    ],
    metricFactor: Rational.tspMl,
    ar: ArabicForms(
      'ملعقة صغيرة',
      'ملعقتان صغيرتان',
      'ملاعق صغيرة',
      'ملعقة صغيرة',
    ),
    en: ('tsp', 'tsp'),
  ),
  // A spoon with no size given ("ملعقة", "ملعقة متوسطة"): kept, never converted.
  Unit(
    id: 'spoon',
    kind: UnitKind.spoon,
    forms: ['ملعقه متوسطه', 'ملعق متوسطه', 'ملعقه', 'ملاعق', 'معلقه', 'معالق'],
    dualForms: ['ملعقتين', 'ملعقتان', 'معلقتين'],
    ar: ArabicForms('ملعقة', 'ملعقتان', 'ملاعق', 'ملعقة'),
    en: ('spoon', 'spoons'),
  ),
  Unit(
    id: 'cup',
    kind: UnitKind.volume,
    forms: ['كوب', 'اكواب', 'كاسه', 'كاس', 'كاسات', 'cup', 'cups'],
    dualForms: ['كوبين', 'كوبان', 'كاستين'],
    metricFactor: Rational.cupMl,
    ar: ArabicForms('كوب', 'كوبان', 'أكواب', 'كوبًا'),
    en: ('cup', 'cups'),
  ),
  // QTY-3's oz, lb and fl oz: English recipes only, so no Arabic forms
  // (matches QTY-3's table, no dictionary entry needed for ORG-4).
  Unit(
    id: 'oz',
    kind: UnitKind.mass,
    forms: ['oz', 'ounce', 'ounces'],
    metricFactor: Rational.ounceGrams,
    ar: ArabicForms('أونصة', 'أونصتان', 'أونصات', 'أونصة'),
    en: ('oz', 'oz'),
  ),
  Unit(
    id: 'lb',
    kind: UnitKind.mass,
    forms: ['lb', 'lbs', 'pound', 'pounds'],
    metricFactor: Rational.poundGrams,
    ar: ArabicForms('رطل', 'رطلان', 'أرطال', 'رطلًا'),
    en: ('lb', 'lb'),
  ),
  Unit(
    id: 'floz',
    kind: UnitKind.volume,
    forms: ['fl oz', 'floz', 'fluid ounce', 'fluid ounces'],
    metricFactor: Rational.flOunceMl,
    ar: ArabicForms(
      'أونصة سائلة',
      'أونصتان سائلتان',
      'أونصات سائلة',
      'أونصة سائلة',
    ),
    en: ('fl oz', 'fl oz'),
  ),
  Unit(
    id: 'piece',
    kind: UnitKind.count,
    forms: ['حبه', 'حبات', 'حب', 'piece', 'pieces', 'pc', 'pcs'],
    dualForms: ['حبتين', 'حبتان'],
    ar: ArabicForms('حبة', 'حبتان', 'حبات', 'حبة'),
    en: ('piece', 'pieces'),
  ),
  Unit(
    id: 'clove',
    kind: UnitKind.count,
    forms: ['فص', 'فصوص', 'clove', 'cloves'],
    dualForms: ['فصين', 'فصان'],
    ar: ArabicForms('فص', 'فصان', 'فصوص', 'فصًا'),
    en: ('clove', 'cloves'),
  ),
  Unit(
    id: 'stick',
    kind: UnitKind.count,
    forms: ['عود', 'اعواد', 'عيدان', 'stick', 'sticks'],
    dualForms: ['عودين', 'عودان'],
    ar: ArabicForms('عود', 'عودان', 'أعواد', 'عودًا'),
    en: ('stick', 'sticks'),
  ),
  Unit(
    id: 'slice',
    kind: UnitKind.count,
    forms: ['شريحه', 'شرائح', 'slice', 'slices'],
    dualForms: ['شريحتين', 'شريحتان'],
    ar: ArabicForms('شريحة', 'شريحتان', 'شرائح', 'شريحة'),
    en: ('slice', 'slices'),
  ),
  Unit(
    id: 'leaf',
    kind: UnitKind.count,
    forms: ['ورقه', 'اوراق', 'leaf', 'leaves'],
    dualForms: ['ورقتين', 'ورقتان'],
    ar: ArabicForms('ورقة', 'ورقتان', 'أوراق', 'ورقة'),
    en: ('leaf', 'leaves'),
  ),
  Unit(
    id: 'bunch',
    kind: UnitKind.count,
    forms: ['حزمه', 'حزم', 'ربطه', 'ربطات', 'bunch', 'bunches'],
    dualForms: ['حزمتين', 'حزمتان', 'ربطتين'],
    ar: ArabicForms('حزمة', 'حزمتان', 'حزم', 'حزمة'),
    en: ('bunch', 'bunches'),
  ),
  Unit(
    id: 'can',
    kind: UnitKind.count,
    forms: ['علبه', 'علب', 'can', 'cans', 'tin', 'tins'],
    dualForms: ['علبتين', 'علبتان'],
    ar: ArabicForms('علبة', 'علبتان', 'علب', 'علبة'),
    en: ('can', 'cans'),
  ),
  Unit(
    id: 'bag',
    kind: UnitKind.count,
    forms: ['كيس', 'اكياس', 'bag', 'bags'],
    dualForms: ['كيسين', 'كيسان'],
    ar: ArabicForms('كيس', 'كيسان', 'أكياس', 'كيسًا'),
    en: ('bag', 'bags'),
  ),
  Unit(
    id: 'head',
    kind: UnitKind.count,
    forms: ['راس', 'رؤوس', 'روس', 'head', 'heads'],
    dualForms: ['راسين'],
    ar: ArabicForms('رأس', 'رأسان', 'رؤوس', 'رأسًا'),
    en: ('head', 'heads'),
  ),
  Unit(
    id: 'chunk',
    kind: UnitKind.count,
    forms: ['قطعه', 'قطع'],
    dualForms: ['قطعتين', 'قطعتان'],
    ar: ArabicForms('قطعة', 'قطعتان', 'قطع', 'قطعة'),
    en: ('piece', 'pieces'),
  ),
  Unit(
    id: 'pinch',
    kind: UnitKind.informal,
    forms: ['رشه', 'رشات', 'pinch', 'pinches'],
    dualForms: ['رشتين'],
    ar: ArabicForms('رشة', 'رشتان', 'رشات', 'رشة'),
    en: ('pinch', 'pinches'),
  ),
  Unit(
    id: 'handful',
    kind: UnitKind.informal,
    forms: ['قبضه', 'حفنه', 'handful', 'handfuls'],
    dualForms: ['قبضتين', 'حفنتين'],
    ar: ArabicForms('حفنة', 'حفنتان', 'حفنات', 'حفنة'),
    en: ('handful', 'handfuls'),
  ),
];

/// Every accepted form, normalized, longest first, with its unit, whether it
/// is a dual form, and whether it is singular: only a singular form with no
/// number means "one" (QTY-8), so "قطع الدجاج" is not one piece.
final List<(String form, Unit unit, bool dual, bool singular)> unitForms = () {
  final all = <(String, Unit, bool, bool)>[];
  for (final u in units) {
    final singulars = {
      normalizeArabic(u.ar.one),
      normalizeArabic(u.forms.first),
      u.en.$1,
    };
    for (final f in u.forms) {
      final n = normalizeArabic(f);
      all.add((n, u, false, singulars.contains(n)));
    }
    for (final f in u.dualForms) {
      all.add((normalizeArabic(f), u, true, false));
    }
    // The display forms too (QTY-6), so a shown line parses back (QTY-4).
    all.add((normalizeArabic(u.ar.one), u, false, true));
    for (final f in [u.ar.few, u.ar.many]) {
      final n = normalizeArabic(f);
      all.add((n, u, false, singulars.contains(n)));
    }
    if (u.ar.two != u.ar.one) {
      all.add((normalizeArabic(u.ar.two), u, true, false));
    }
  }
  all.sort((a, b) => b.$1.length.compareTo(a.$1.length));
  return all;
}();

Unit unitById(String id) => units.firstWhere((u) => u.id == id);
