import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wasfati/db/db_helper.dart';
import 'package:wasfati/db/grocery_repository.dart';
import 'package:wasfati/db/plan_repository.dart';
import 'package:wasfati/db/recipe_repository.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/services/backup.dart';

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

/// Predictable IDs: id-1, id-2, … or, with a [prefix], a-1, a-2, … so two
/// fixtures standing in for two different phones (a backup merge test)
/// never hand out the same id for two different rows (should-fix, platform
/// review: every merge test used to share one `CountingIds`, which hid the
/// id collisions two real installs would produce).
class CountingIds {
  CountingIds({this.prefix = 'id'});
  final String prefix;
  int _n = 0;
  String call() => '$prefix-${++_n}';
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

/// A grocery repository and a recipe repository on one database, sharing
/// the same clock and IDs (GRO-1).
Future<(GroceryRepository, RecipeRepository, FakeClock, CountingIds)>
testGroceryRepo() async {
  final clock = FakeClock();
  final ids = CountingIds();
  final db = await memoryDb();
  return (
    GroceryRepository(db, clock: clock.call, ids: ids.call),
    RecipeRepository(db, clock: clock.call, ids: ids.call),
    clock,
    ids,
  );
}

/// Every repository BAK-1–BAK-10's tests need, on one database, plus the
/// backup service itself over temp `photos/` and `backups/` folders.
/// [dispose] closes the database and deletes both folders.
class BackupFixture {
  BackupFixture._(
    this.db,
    this.recipes,
    this.plans,
    this.groceries,
    this.backup,
    this.clock,
    this.ids,
    this.photosDir,
    this.backupsDir,
  );

  final Database db;
  final RecipeRepository recipes;
  final PlanRepository plans;
  final GroceryRepository groceries;
  final BackupService backup;
  final FakeClock clock;
  final CountingIds ids;
  final Directory photosDir;
  final Directory backupsDir;

  Future<void> dispose() async {
    await db.close();
    if (await photosDir.exists()) await photosDir.delete(recursive: true);
    if (await backupsDir.exists()) await backupsDir.delete(recursive: true);
  }
}

/// A [BackupFixture] on a database at [upTo] steps (default the current
/// schema, DBHelper.version), sharing one clock and one ID source so rows
/// made through different repositories still compare by `updated_at`.
Future<BackupFixture> testBackupFixture({
  int? upTo,
  String appVersion = '0.11.0',
  String idPrefix = 'id',
}) async {
  final clock = FakeClock();
  final ids = CountingIds(prefix: idPrefix);
  final db = await memoryDb(upTo: upTo);
  final root = Directory.systemTemp.createTempSync('wasfati_backup_test_');
  final photosDir = Directory(p.join(root.path, 'photos'))..createSync();
  final backupsDir = Directory(p.join(root.path, 'backups'))..createSync();
  return BackupFixture._(
    db,
    RecipeRepository(db, clock: clock.call, ids: ids.call),
    PlanRepository(db, clock: clock.call, ids: ids.call),
    GroceryRepository(db, clock: clock.call, ids: ids.call),
    BackupService(
      db,
      factory: databaseFactoryFfi,
      photosDir: photosDir,
      backupsDir: backupsDir,
      appVersion: appVersion,
      clock: clock.call,
      ids: ids.call,
    ),
    clock,
    ids,
    photosDir,
    backupsDir,
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
