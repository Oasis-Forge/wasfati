import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wasfati/db/db_helper.dart';
import 'package:wasfati/db/plan_repository.dart';
import 'package:wasfati/db/recipe_repository.dart';
import 'package:wasfati/models/recipe.dart';

/// A fresh in-memory database per call (no shared cache between tests).
Future<Database> memoryDb({int? upTo}) {
  sqfliteFfiInit();
  return DBHelper.open(
    databaseFactoryFfi,
    inMemoryDatabasePath,
    upTo: upTo,
    singleInstance: false, // a fresh database for every test
  );
}

/// A clock tests can move, starting 2026-09-19 10:00 UTC.
class FakeClock {
  DateTime now = DateTime.utc(2026, 9, 19, 10);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

/// Predictable IDs: id-1, id-2, …
class CountingIds {
  int _n = 0;
  String call() => 'id-${++_n}';
}

Future<(RecipeRepository, FakeClock, CountingIds)> testRepo() async {
  final clock = FakeClock();
  final ids = CountingIds();
  return (
    RecipeRepository(await memoryDb(), clock: clock.call, ids: ids.call),
    clock,
    ids,
  );
}

/// A plan repository and a recipe repository on one database, sharing the
/// same clock and IDs (PLAN-1).
Future<(PlanRepository, RecipeRepository, FakeClock, CountingIds)>
testPlanRepo() async {
  final clock = FakeClock();
  final ids = CountingIds();
  final db = await memoryDb();
  return (
    PlanRepository(db, clock: clock.call, ids: ids.call),
    RecipeRepository(db, clock: clock.call, ids: ids.call),
    clock,
    ids,
  );
}

/// A kabsa recipe like the ones imported in the competitor research, with
/// a named sauce group (REC-4).
Recipe kabsa(RecipeRepository repo, {String title = 'كبسة لحم'}) {
  final now = repo.now();
  return Recipe(
    id: repo.newId(),
    title: title,
    sourceType: SourceType.website,
    sourceUrl: 'https://www.fatafeat.com/recipe/1632',
    servings: 6,
    prepMinutes: 60,
    cookMinutes: 120,
    ingredients: [
      Section(
        id: repo.newId(),
        items: [
          IngredientLine.parse(repo.newId(), '1 كيلو جرام لحم ضأن'),
          IngredientLine.parse(repo.newId(), '٣ كوب ارز بسمتي'),
          IngredientLine.parse(repo.newId(), 'ملح حسب الذوق'),
        ],
      ),
      Section(
        id: repo.newId(),
        name: 'للدقوس',
        items: [IngredientLine.parse(repo.newId(), '2 حبة طماطم')],
      ),
    ],
    steps: [
      Section(
        id: repo.newId(),
        items: [
          RecipeStep(id: repo.newId(), text: 'يحمر اللحم في الزبدة.'),
          RecipeStep(id: repo.newId(), text: 'يضاف الأرز ويترك 15 دقيقة.'),
        ],
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}
