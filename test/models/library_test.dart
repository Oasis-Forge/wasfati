import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/library.dart';
import 'package:wasfati/models/recipe.dart';

LibraryEntry e(
  String id,
  String title, {
  List<String> ingredients = const [],
  List<String> tags = const [],
  String? notes,
  int minutes = 0,
  int cooked = 0,
  DateTime? lastCooked,
  int day = 1,
  String? photo,
  SourceType source = SourceType.written,
  Set<String> books = const {},
}) => LibraryEntry(
  id: id,
  title: title,
  ingredientNames: ingredients,
  tags: tags,
  notes: notes,
  totalMinutes: minutes == 0 ? null : minutes,
  cookedCount: cooked,
  lastCookedAt: lastCooked,
  createdAt: DateTime.utc(2026, 9, day),
  photoPath: photo,
  sourceType: source,
  cookbookIds: books,
);

List<String> ids(List<LibraryHit> hits) => [for (final h in hits) h.entry.id];

void main() {
  final all = [
    e('kabsa', 'كبسة لحم', ingredients: ['لحم ضأن', 'أرز', 'كزبرة'], day: 1),
    e(
      'salad',
      'سلطة فتوش',
      ingredients: ['خبز', 'بندورة'],
      tags: ['سريع'],
      day: 3,
    ),
    e('soup', 'شوربة عدس', ingredients: ['عدس'], notes: 'مع الكزبرة', day: 2),
    e('pie', 'Apple pie', ingredients: ['apples', 'flour'], day: 4),
  ];

  group('ORG-3 search', () {
    test(
      'title first, then tags, ingredients, notes; ingredient hit named',
      () {
        final hits = runLibraryQuery(all, const LibraryQuery(text: 'كزبرة'));
        expect(ids(hits), ['kabsa', 'soup']); // ingredient, then notes
        expect(hits.first.matchedIngredient, 'كزبرة');
        expect(hits.last.matchedIngredient, isNull);
      },
    );

    test('ORG-4: hamza, taa marbuta and diacritics are ignored', () {
      expect(ids(runLibraryQuery(all, const LibraryQuery(text: 'ارز'))), [
        'kabsa',
      ]);
      expect(ids(runLibraryQuery(all, const LibraryQuery(text: 'كبسه'))), [
        'kabsa',
      ]);
      expect(ids(runLibraryQuery(all, const LibraryQuery(text: 'شُوربة'))), [
        'soup',
      ]);
    });

    test('a title match ranks above an ingredient match', () {
      final list = [
        ...all,
        e('rice', 'رز بالعدس', day: 0), // older than every other entry
      ];
      final hits = runLibraryQuery(list, const LibraryQuery(text: 'رز'));
      // "رز بالعدس" is a title match, so it beats the newer kabsa, whose
      // ingredient "أرز" matches after normalization (ORG-3, ORG-4).
      expect(ids(hits), ['rice', 'kabsa']);
      expect(hits.last.matchedIngredient, 'أرز');
    });

    test('Latin text is case-insensitive', () {
      expect(ids(runLibraryQuery(all, const LibraryQuery(text: 'APPLE'))), [
        'pie',
      ]);
    });
  });

  group('LANG-4 search in every language', () {
    final list = [
      e('idam', 'إدام بامية', day: 1),
      e('ice', 'آيس كريم بالفستق', day: 2),
      e('halwa', 'حلوى الجبن', ingredients: ['جبنة عكاوي'], day: 3),
      e('maqluba', 'مَقْلُوبَة بالباذنجان', day: 4),
      e('creme', 'Crème brûlée', ingredients: ['jalapeño'], day: 5),
      e('kofte', 'İçli köfte', notes: 'Işık usulü', day: 6),
      e('cake', 'كيك ٣ طبقات', tags: ['Rapide'], day: 7),
    ];
    List<String> find(String text) =>
        ids(runLibraryQuery(list, LibraryQuery(text: text)));

    test('hamza forms of alef: a bare alef finds إ and آ, and back', () {
      expect(find('ادام'), ['idam']);
      expect(find('ايس'), ['ice']);
      expect(find('أدام'), ['idam']);
    });

    test('alef maqsura and yaa, taa marbuta and haa, in title and '
        'ingredient', () {
      expect(find('حلوي'), ['halwa']);
      expect(find('جبنه'), ['halwa']); // the ingredient "جبنة"
      expect(find('مقلوبه'), ['maqluba']); // and its tashkeel ignored
    });

    test("a Persian keyboard's ک and ی still find كيك", () {
      expect(find('کیک'), ['cake']);
    });

    test('Latin accents and case, and the Turkish i, are ignored', () {
      expect(find('CREME BRULEE'), ['creme']);
      expect(find('jalapeno'), ['creme']); // an ingredient
      expect(find('icli kofte'), ['kofte']);
      expect(find('ICLI'), ['kofte']);
      expect(find('isik'), ['kofte']); // the notes
      expect(find('rapide'), ['cake']); // a tag
    });

    test('digits in either style', () {
      expect(find('3 طبقات'), ['cake']);
    });
  });

  group('ORG-5 sort', () {
    test('recently added by default', () {
      expect(ids(runLibraryQuery(all, const LibraryQuery())), [
        'pie',
        'salad',
        'soup',
        'kabsa',
      ]);
    });
    test('A–Z: Latin, then Arabic in alphabet order', () {
      expect(
        ids(runLibraryQuery(all, const LibraryQuery(sort: LibrarySort.az))),
        ['pie', 'salad', 'soup', 'kabsa'], // س ش ك
      );
    });
    test('most cooked, then recently cooked with never-cooked last', () {
      final list = [
        e('a', 'أ', cooked: 1, lastCooked: DateTime.utc(2026, 9, 10)),
        e('b', 'ب', cooked: 5, lastCooked: DateTime.utc(2026, 9, 5)),
        e('c', 'ت'),
      ];
      expect(
        ids(
          runLibraryQuery(
            list,
            const LibraryQuery(sort: LibrarySort.mostCooked),
          ),
        ),
        ['b', 'a', 'c'],
      );
      expect(
        ids(
          runLibraryQuery(
            list,
            const LibraryQuery(sort: LibrarySort.recentlyCooked),
          ),
        ),
        ['a', 'b', 'c'],
      );
    });
  });

  group('ORG-6 filters', () {
    final list = [
      e('q', 'سريع', minutes: 20, photo: '/p.jpg', books: {'b1'}),
      e('m', 'متوسط', minutes: 45, source: SourceType.website),
      e('l', 'طويل', minutes: 120, tags: ['رمضان']),
      e('n', 'بلا وقت'),
    ];
    List<String> run(LibraryQuery q) => ids(runLibraryQuery(list, q));

    test('time buckets leave out recipes with no time', () {
      expect(run(const LibraryQuery(time: TimeBucket.under30)), ['q']);
      expect(run(const LibraryQuery(time: TimeBucket.from30to60)), ['m']);
      expect(run(const LibraryQuery(time: TimeBucket.over60)), ['l']);
    });
    test('cookbook, tag, source and photo combine with search', () {
      expect(run(const LibraryQuery(cookbookId: 'b1')), ['q']);
      expect(run(const LibraryQuery(tag: 'رمضان')), ['l']);
      expect(run(const LibraryQuery(source: SourceType.website)), ['m']);
      expect(run(const LibraryQuery(photoOnly: true)), ['q']);
      expect(run(const LibraryQuery(photoOnly: true, text: 'طويل')), isEmpty);
    });
  });

  test('ORG-2 tags box: commas of both kinds, duplicates dropped', () {
    expect(parseTags('حار، رمضان, سريع ،  حار ,,'), ['حار', 'رمضان', 'سريع']);
  });

  test('ORG-2: the editor joins Arabic tags with "، " and English ones with '
      '", " (LANG-2)', () {
    expect(['حار', 'رمضان'].join(tagSeparator(['حار', 'رمضان'])), 'حار، رمضان');
    expect(
      ['quick', 'easy'].join(tagSeparator(['quick', 'easy'])),
      'quick, easy',
    );
    expect(tagSeparator(['quick', 'حار']), '، ');
  });
}
