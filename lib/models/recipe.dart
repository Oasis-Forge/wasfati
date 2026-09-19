import 'cookbook.dart';
import 'quantity/convert.dart';
import 'quantity/parser.dart';
import 'quantity/rational.dart';

/// Where a recipe came from (REC-3).
enum SourceType { written, website, social, photo }

/// Lets [copyWith] clear a nullable field: pass `null` to clear it, leave it
/// out to keep it.
const Object _keep = Object();

/// A recipe (REC-3–REC-9). Every record has a UUID and timestamps (REC-1,
/// REC-2); deleting sets [deletedAt] (DEL-1).
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    this.photoPath,
    this.sourceUrl,
    this.sourceType = SourceType.written,
    this.prepMinutes,
    this.cookMinutes,
    this.servings,
    this.notes,
    this.rating,
    this.cookedCount = 0,
    this.lastCookedAt,
    this.ingredients = const [],
    this.steps = const [],
    this.cookbookIds = const [],
    this.tags = const [],
    this.unitView = UnitView.asWritten,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  static const maxTitle = 120; // REC-3
  static const maxServings = 100; // REC-7

  final String id;
  final String title;
  final String? photoPath;
  final String? sourceUrl;
  final SourceType sourceType;
  final int? prepMinutes;
  final int? cookMinutes;
  final int? servings;
  final String? notes;
  final int? rating;
  final int cookedCount;
  final DateTime? lastCookedAt;

  /// Ingredient groups in order; the first may be unnamed (REC-4).
  final List<Section<IngredientLine>> ingredients;

  /// Step groups in order (REC-6).
  final List<Section<RecipeStep>> steps;

  /// The cookbooks this recipe is in, any number (ORG-1).
  final List<String> cookbookIds;

  /// Tag names, up to 20 of 1–30 characters each (ORG-2).
  final List<String> tags;

  /// How amounts are shown, remembered per recipe (SCALE-5).
  final UnitView unitView;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  int? get totalMinutes => prepMinutes == null && cookMinutes == null
      ? null
      : (prepMinutes ?? 0) + (cookMinutes ?? 0);

  /// Checks REC-3, REC-7 and REC-6 limits; returns the first problem or null.
  String? validate() {
    final t = title.trim();
    if (t.isEmpty || t.length > maxTitle) return 'title';
    if (servings != null && (servings! < 1 || servings! > maxServings)) {
      return 'servings';
    }
    if (rating != null && (rating! < 1 || rating! > 5)) return 'rating';
    if (tags.length > Tag.maxPerRecipe) return 'tags';
    for (final t in tags) {
      if (t.trim().isEmpty || t.trim().length > Tag.maxName) return 'tags';
    }
    for (final s in steps) {
      for (final step in s.items) {
        if (step.text.length > RecipeStep.maxLength) return 'step';
      }
    }
    return null;
  }

  Recipe copyWith({
    String? title,
    Object? photoPath = _keep,
    Object? sourceUrl = _keep,
    SourceType? sourceType,
    Object? prepMinutes = _keep,
    Object? cookMinutes = _keep,
    Object? servings = _keep,
    Object? notes = _keep,
    Object? rating = _keep,
    int? cookedCount,
    Object? lastCookedAt = _keep,
    List<Section<IngredientLine>>? ingredients,
    List<Section<RecipeStep>>? steps,
    List<String>? cookbookIds,
    List<String>? tags,
    UnitView? unitView,
    DateTime? updatedAt,
    Object? deletedAt = _keep,
  }) => Recipe(
    id: id,
    title: title ?? this.title,
    photoPath: photoPath == _keep ? this.photoPath : photoPath as String?,
    sourceUrl: sourceUrl == _keep ? this.sourceUrl : sourceUrl as String?,
    sourceType: sourceType ?? this.sourceType,
    prepMinutes: prepMinutes == _keep ? this.prepMinutes : prepMinutes as int?,
    cookMinutes: cookMinutes == _keep ? this.cookMinutes : cookMinutes as int?,
    servings: servings == _keep ? this.servings : servings as int?,
    notes: notes == _keep ? this.notes : notes as String?,
    rating: rating == _keep ? this.rating : rating as int?,
    cookedCount: cookedCount ?? this.cookedCount,
    lastCookedAt: lastCookedAt == _keep
        ? this.lastCookedAt
        : lastCookedAt as DateTime?,
    ingredients: ingredients ?? this.ingredients,
    steps: steps ?? this.steps,
    cookbookIds: cookbookIds ?? this.cookbookIds,
    tags: tags ?? this.tags,
    unitView: unitView ?? this.unitView,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt == _keep ? this.deletedAt : deletedAt as DateTime?,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'photo_path': photoPath,
    'source_url': sourceUrl,
    'source_type': sourceType.name,
    'prep_minutes': prepMinutes,
    'cook_minutes': cookMinutes,
    'servings': servings,
    'notes': notes,
    'rating': rating,
    'cooked_count': cookedCount,
    'last_cooked_at': lastCookedAt?.millisecondsSinceEpoch,
    'unit_view': unitView == UnitView.asWritten ? null : unitView.name,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
  };

  /// Builds the recipe row; sections are attached by the repository.
  factory Recipe.fromMap(
    Map<String, Object?> m, {
    List<Section<IngredientLine>> ingredients = const [],
    List<Section<RecipeStep>> steps = const [],
    List<String> cookbookIds = const [],
    List<String> tags = const [],
  }) => Recipe(
    id: m['id']! as String,
    title: m['title']! as String,
    photoPath: m['photo_path'] as String?,
    sourceUrl: m['source_url'] as String?,
    sourceType: SourceType.values.byName(m['source_type']! as String),
    prepMinutes: m['prep_minutes'] as int?,
    cookMinutes: m['cook_minutes'] as int?,
    servings: m['servings'] as int?,
    notes: m['notes'] as String?,
    rating: m['rating'] as int?,
    cookedCount: m['cooked_count']! as int,
    lastCookedAt: _date(m['last_cooked_at']),
    ingredients: ingredients,
    steps: steps,
    cookbookIds: cookbookIds,
    tags: tags,
    unitView:
        UnitView.values.where((v) => v.name == m['unit_view']).firstOrNull ??
        UnitView.asWritten,
    createdAt: _date(m['created_at'])!,
    updatedAt: _date(m['updated_at'])!,
    deletedAt: _date(m['deleted_at']),
  );
}

DateTime? _date(Object? ms) => ms == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);

/// A named or unnamed group of ingredient lines or steps (REC-4, REC-6).
class Section<T> {
  const Section({required this.id, this.name, this.items = const []});
  final String id;
  final String? name;
  final List<T> items;
}

/// One ingredient line (REC-5): the original text as written or imported,
/// and what the parser read from it (QTY-1). Editing re-parses.
class IngredientLine {
  const IngredientLine({
    required this.id,
    required this.original,
    this.min,
    this.max,
    this.unitId,
    required this.name,
    this.note,
  });

  /// Parses [text] with the quantity parser (QTY-1, QTY-8).
  factory IngredientLine.parse(String id, String text) {
    final p = parseIngredient(text);
    return IngredientLine(
      id: id,
      original: text,
      min: p.min,
      max: p.max,
      unitId: p.unitId,
      name: p.name,
      note: p.note,
    );
  }

  final String id;
  final String original;
  final Rational? min;
  final Rational? max;
  final String? unitId;
  final String name;
  final String? note;

  ParsedLine get parsed => ParsedLine(
    original: original,
    min: min,
    max: max,
    unitId: unitId,
    name: name,
    note: note,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'original_text': original,
    'min_num': min?.numerator,
    'min_den': min?.denominator,
    'max_num': max?.numerator,
    'max_den': max?.denominator,
    'unit_id': unitId,
    'name': name,
    'note': note,
  };

  factory IngredientLine.fromMap(Map<String, Object?> m) => IngredientLine(
    id: m['id']! as String,
    original: m['original_text']! as String,
    min: _rational(m['min_num'], m['min_den']),
    max: _rational(m['max_num'], m['max_den']),
    unitId: m['unit_id'] as String?,
    name: m['name']! as String,
    note: m['note'] as String?,
  );
}

Rational? _rational(Object? n, Object? d) =>
    n == null ? null : Rational(n as int, d! as int);

/// One instruction step (REC-6), at most 2,000 characters.
class RecipeStep {
  const RecipeStep({required this.id, required this.text});
  static const maxLength = 2000;
  final String id;
  final String text;
}
