import 'quantity/arabic_text.dart';
import 'recipe.dart';

/// ORG-5: the library order. The choice is remembered in Settings.
enum LibrarySort { recent, az, recentlyCooked, mostCooked }

/// ORG-6: total-time filter.
enum TimeBucket { under30, from30to60, over60 }

/// One recipe as the library sees it: enough to search, sort and filter
/// without loading every recipe in full (ORG-3–ORG-6).
class LibraryEntry {
  LibraryEntry({
    required this.id,
    required this.title,
    this.photoPath,
    required this.sourceType,
    this.sourceUrl,
    this.totalMinutes,
    this.servings,
    this.cookedCount = 0,
    this.lastCookedAt,
    required this.createdAt,
    this.ingredientNames = const [],
    this.tags = const [],
    this.notes,
    this.cookbookIds = const {},
  }) : _title = searchKey(title),
       _ingredients = [for (final n in ingredientNames) searchKey(n)],
       _tags = [for (final t in tags) searchKey(t)],
       _notes = searchKey(notes ?? '');

  final String id;
  final String title;
  final String? photoPath;
  final SourceType sourceType;

  /// A website or social import's source link (REC-3): the library card's
  /// source badge reads a website's host from it, unset otherwise.
  final String? sourceUrl;
  final int? totalMinutes;

  /// REC-7: the library card's meta line shows it beside the total time
  /// when it's set (REC-3).
  final int? servings;
  final int cookedCount;
  final DateTime? lastCookedAt;
  final DateTime createdAt;
  final List<String> ingredientNames;
  final List<String> tags;
  final String? notes;
  final Set<String> cookbookIds;

  final String _title;
  final List<String> _ingredients;
  final List<String> _tags;
  final String _notes;

  /// The A–Z key: the search key, so أ/ا, ة/ه and é/e sort together
  /// (ORG-4, ORG-5, LANG-4).
  String get sortKey => _title;
}

/// What the library is asked for. Everything combines (ORG-6).
class LibraryQuery {
  const LibraryQuery({
    this.text = '',
    this.sort = LibrarySort.recent,
    this.cookbookId,
    this.tag,
    this.source,
    this.time,
    this.photoOnly = false,
  });

  final String text;
  final LibrarySort sort;
  final String? cookbookId;
  final String? tag;
  final SourceType? source;
  final TimeBucket? time;
  final bool photoOnly;

  bool get hasFilters =>
      cookbookId != null ||
      tag != null ||
      source != null ||
      time != null ||
      photoOnly;

  LibraryQuery copyWith({
    String? text,
    LibrarySort? sort,
    Object? cookbookId = _keep,
    Object? tag = _keep,
    Object? source = _keep,
    Object? time = _keep,
    bool? photoOnly,
  }) => LibraryQuery(
    text: text ?? this.text,
    sort: sort ?? this.sort,
    cookbookId: cookbookId == _keep ? this.cookbookId : cookbookId as String?,
    tag: tag == _keep ? this.tag : tag as String?,
    source: source == _keep ? this.source : source as SourceType?,
    time: time == _keep ? this.time : time as TimeBucket?,
    photoOnly: photoOnly ?? this.photoOnly,
  );

  LibraryQuery clearFilters() => LibraryQuery(text: text, sort: sort);
}

const Object _keep = Object();

/// LOOK-12, COOK-6: the library's "تابع الطبخ" card — a resumable cook-mode
/// session's recipe, its step (0-based, matching `stepOf`'s 1-based "الخطوة
/// N من Y") and the recipe's total step count.
class CookResume {
  const CookResume({
    required this.recipeId,
    required this.title,
    this.photoPath,
    required this.step,
    required this.totalSteps,
  });

  final String recipeId;
  final String title;
  final String? photoPath;
  final int step;
  final int totalSteps;
}

/// A search hit: [matchedIngredient] is set when only an ingredient matched,
/// so the list can say "contains: coriander" (ORG-3).
class LibraryHit {
  const LibraryHit(this.entry, {this.matchedIngredient, this.rank = 0});
  final LibraryEntry entry;
  final String? matchedIngredient;
  final int rank;
}

/// Runs [q] over [entries] (ORG-3–ORG-6). Deleted recipes are never in
/// [entries] (ORG-7). With search text, title matches come first, then tags,
/// then ingredients, then notes (ORG-3); within a rank, the chosen sort.
List<LibraryHit> runLibraryQuery(List<LibraryEntry> entries, LibraryQuery q) {
  final needle = searchKey(q.text.trim());
  final hits = <LibraryHit>[];
  for (final e in entries) {
    if (q.cookbookId != null && !e.cookbookIds.contains(q.cookbookId)) {
      continue;
    }
    if (q.tag != null && !e._tags.contains(searchKey(q.tag!))) {
      continue;
    }
    if (q.source != null && e.sourceType != q.source) continue;
    if (q.photoOnly && e.photoPath == null) continue;
    if (q.time != null && !_inBucket(e.totalMinutes, q.time!)) continue;

    if (needle.isEmpty) {
      hits.add(LibraryHit(e));
      continue;
    }
    if (e._title.contains(needle)) {
      hits.add(LibraryHit(e, rank: e._title.startsWith(needle) ? 0 : 1));
    } else if (e._tags.any((t) => t.contains(needle))) {
      hits.add(LibraryHit(e, rank: 2));
    } else {
      final i = e._ingredients.indexWhere((n) => n.contains(needle));
      if (i >= 0) {
        hits.add(
          LibraryHit(e, rank: 3, matchedIngredient: e.ingredientNames[i]),
        );
      } else if (e._notes.contains(needle)) {
        hits.add(LibraryHit(e, rank: 4));
      }
    }
  }
  final order = _comparator(q.sort);
  hits.sort((a, b) {
    final r = a.rank.compareTo(b.rank);
    return r != 0 ? r : order(a.entry, b.entry);
  });
  return hits;
}

bool _inBucket(int? minutes, TimeBucket b) {
  if (minutes == null) return false;
  return switch (b) {
    TimeBucket.under30 => minutes < 30,
    TimeBucket.from30to60 => minutes >= 30 && minutes <= 60,
    TimeBucket.over60 => minutes > 60,
  };
}

int Function(LibraryEntry, LibraryEntry) _comparator(LibrarySort sort) {
  int newest(LibraryEntry a, LibraryEntry b) =>
      b.createdAt.compareTo(a.createdAt);
  return switch (sort) {
    LibrarySort.recent => newest,
    // Unicode order of normalized Arabic letters is the alphabet order
    // (ا ب ت ث … ن ه و ي), and Latin sorts before Arabic.
    LibrarySort.az => (a, b) {
      final c = a.sortKey.compareTo(b.sortKey);
      return c != 0 ? c : newest(a, b);
    },
    LibrarySort.recentlyCooked => (a, b) {
      final x = a.lastCookedAt, y = b.lastCookedAt;
      if (x == null && y == null) return newest(a, b);
      if (x == null) return 1; // never cooked goes last
      if (y == null) return -1;
      final c = y.compareTo(x);
      return c != 0 ? c : newest(a, b);
    },
    LibrarySort.mostCooked => (a, b) {
      final c = b.cookedCount.compareTo(a.cookedCount);
      return c != 0 ? c : newest(a, b);
    },
  };
}

/// The comma between tags in the editor's box (ORG-2): Arabic "، " when any
/// of [tags] is Arabic, ", " otherwise, so an English list never reads
/// "quick، easy". [parseTags] splits on both.
String tagSeparator(Iterable<String> tags) => tags.any(hasArabic) ? '، ' : ', ';

/// Splits a tags box ("حار، رمضان, سريع") into clean, distinct tags (ORG-2).
List<String> parseTags(String text) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in text.split(RegExp('[,،\n]'))) {
    final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) continue;
    if (seen.add(normalizeArabic(t))) out.add(t);
  }
  return out;
}
