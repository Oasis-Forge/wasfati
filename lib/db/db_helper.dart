import 'package:sqflite/sqflite.dart';

/// One schema step. Steps run in order on create and on upgrade; a merged
/// step is never edited, only a new one appended (CLAUDE.md conventions).
typedef SchemaStep = Future<void> Function(DatabaseExecutor db);

/// Opens the app database and runs the schema steps.
class DBHelper {
  DBHelper._();

  /// The ordered steps; the schema version is their count.
  static final List<SchemaStep> steps = [
    _v1Recipes,
    _v2UnitView,
    _v3PlanEntries,
    _v4Groceries,
    _v5SampleOffered,
    _v6TranslatedFrom,
  ];

  static int get version => steps.length;

  /// Opens [path] with [factory] (sqflite on the device, the ffi factory in
  /// tests). [upTo] limits the steps, so tests can build an older schema.
  static Future<Database> open(
    DatabaseFactory factory,
    String path, {
    int? upTo,
    bool singleInstance = true,
  }) {
    final target = upTo ?? version;
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: target,
        singleInstance: singleInstance,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, v) => _run(db, 0, v),
        onUpgrade: (db, from, to) => _run(db, from, to),
      ),
    );
  }

  static Future<void> _run(Database db, int from, int to) async {
    for (var i = from; i < to; i++) {
      await steps[i](db);
    }
  }
}

/// Every table carries a UUID id, created_at, updated_at and deleted_at
/// (REC-1, REC-2, DEL-1). Times are UTC milliseconds.
const _record = '''
  id TEXT PRIMARY KEY NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER''';

/// Step 1: recipes, sections, ingredient lines, steps, cookbooks, tags, and
/// the key/value meta table that holds the install ID (SRV-4, REC-11).
Future<void> _v1Recipes(DatabaseExecutor db) async {
  await db.execute('''
CREATE TABLE recipes (
$_record,
  title TEXT NOT NULL,
  photo_path TEXT,
  source_url TEXT,
  source_type TEXT NOT NULL DEFAULT 'written',
  prep_minutes INTEGER,
  cook_minutes INTEGER,
  servings INTEGER,
  notes TEXT,
  rating INTEGER,
  cooked_count INTEGER NOT NULL DEFAULT 0,
  last_cooked_at INTEGER
)''');
  // A named or unnamed group of ingredients or steps (REC-4, REC-6).
  await db.execute('''
CREATE TABLE sections (
$_record,
  recipe_id TEXT NOT NULL REFERENCES recipes(id),
  kind TEXT NOT NULL CHECK (kind IN ('ingredients', 'steps')),
  position INTEGER NOT NULL,
  name TEXT
)''');
  // Amounts are exact fractions (QTY-4); original_text is kept verbatim (REC-5).
  await db.execute('''
CREATE TABLE ingredient_lines (
$_record,
  recipe_id TEXT NOT NULL REFERENCES recipes(id),
  section_id TEXT NOT NULL REFERENCES sections(id),
  position INTEGER NOT NULL,
  original_text TEXT NOT NULL,
  min_num INTEGER,
  min_den INTEGER,
  max_num INTEGER,
  max_den INTEGER,
  unit_id TEXT,
  name TEXT NOT NULL,
  note TEXT
)''');
  await db.execute('''
CREATE TABLE steps (
$_record,
  recipe_id TEXT NOT NULL REFERENCES recipes(id),
  section_id TEXT NOT NULL REFERENCES sections(id),
  position INTEGER NOT NULL,
  text TEXT NOT NULL
)''');
  await db.execute('''
CREATE TABLE cookbooks (
$_record,
  name TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0
)''');
  await db.execute('''
CREATE TABLE cookbook_recipes (
$_record,
  cookbook_id TEXT NOT NULL REFERENCES cookbooks(id),
  recipe_id TEXT NOT NULL REFERENCES recipes(id)
)''');
  await db.execute('''
CREATE TABLE tags (
$_record,
  name TEXT NOT NULL
)''');
  await db.execute('''
CREATE TABLE recipe_tags (
$_record,
  recipe_id TEXT NOT NULL REFERENCES recipes(id),
  tag_id TEXT NOT NULL REFERENCES tags(id)
)''');
  await db.execute('''
CREATE TABLE meta (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
)''');
  for (final sql in [
    'CREATE INDEX sections_recipe ON sections(recipe_id, kind, position)',
    'CREATE INDEX lines_section ON ingredient_lines(section_id, position)',
    'CREATE INDEX steps_section ON steps(section_id, position)',
    'CREATE INDEX recipes_updated ON recipes(deleted_at, created_at)',
    'CREATE INDEX cookbook_recipes_cb ON cookbook_recipes(cookbook_id)',
    'CREATE INDEX recipe_tags_recipe ON recipe_tags(recipe_id)',
  ]) {
    await db.execute(sql);
  }
}

/// Step 2: the conversion view each recipe remembers (SCALE-5). Null is
/// "as written".
Future<void> _v2UnitView(DatabaseExecutor db) =>
    db.execute('ALTER TABLE recipes ADD COLUMN unit_view TEXT');

/// Step 3: the meal plan (PLAN-1–PLAN-6). One row per planned meal: a
/// recipe or a short note, on one local calendar date (DATE-1), with the
/// servings that meal is for (PLAN-2).
Future<void> _v3PlanEntries(DatabaseExecutor db) async {
  await db.execute('''
CREATE TABLE plan_entries (
$_record,
  date TEXT NOT NULL,
  slot TEXT NOT NULL,
  recipe_id TEXT REFERENCES recipes(id),
  note TEXT,
  servings INTEGER,
  mult_num INTEGER,
  mult_den INTEGER,
  position INTEGER NOT NULL DEFAULT 0,
  added_to_groceries_at INTEGER,
  CHECK ((recipe_id IS NULL) <> (note IS NULL))
)''');
  await db.execute(
    'CREATE INDEX plan_entries_day ON plan_entries(date, slot, position)',
  );
  await db.execute(
    'CREATE INDEX plan_entries_recipe ON plan_entries(recipe_id)',
  );
}

/// Step 4: the grocery list (GRO-1–GRO-7). An item is one row; its amounts
/// are separate rows, so the number shown is computed from them (GRO-3).
/// [aisle_choices] remembers where a name was moved to (GRO-4).
Future<void> _v4Groceries(DatabaseExecutor db) async {
  await db.execute('''
CREATE TABLE grocery_items (
$_record,
  name TEXT NOT NULL,
  norm_name TEXT NOT NULL,
  aisle TEXT NOT NULL,
  done_at INTEGER,
  hand_added INTEGER NOT NULL DEFAULT 0
)''');
  // recipe_id and plan_entry_id carry no foreign key: the list outlives the
  // recipe or plan entry (GRO-7), and a recipe purge must never fail on it.
  await db.execute('''
CREATE TABLE grocery_amounts (
$_record,
  item_id TEXT NOT NULL REFERENCES grocery_items(id),
  num INTEGER,
  den INTEGER,
  max_num INTEGER,
  max_den INTEGER,
  unit_id TEXT,
  recipe_id TEXT,
  plan_entry_id TEXT
)''');
  await db.execute('''
CREATE TABLE aisle_choices (
$_record,
  norm_name TEXT NOT NULL UNIQUE,
  aisle TEXT NOT NULL
)''');
  for (final sql in [
    'CREATE INDEX grocery_items_list ON grocery_items(deleted_at, done_at, aisle)',
    'CREATE INDEX grocery_amounts_item ON grocery_amounts(item_id)',
    'CREATE INDEX grocery_amounts_recipe ON grocery_amounts(recipe_id)',
  ]) {
    await db.execute(sql);
  }
}

/// Step 5: marks a database from before this version as already offered
/// the built-in sample recipe (RUN-6, must-fix, review). A database that
/// already has a recipe row — any row, including one that only ever sat in
/// the trash — or an install ID, is clearly not a fresh install, so the
/// sample must never be added to it later, even once the purge (DEL-2) has
/// removed every one of its rows. On a fresh create, `recipes` and `meta`
/// are both still empty at this point, so this sets nothing, and the
/// sample is still offered normally.
Future<void> _v5SampleOffered(DatabaseExecutor db) async {
  final recipeCount = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM recipes'),
  );
  final hasInstallId = (await db.query(
    'meta',
    where: 'key = ?',
    whereArgs: ['install_id'],
  )).isNotEmpty;
  if ((recipeCount ?? 0) > 0 || hasInstallId) {
    await db.insert('meta', {
      'key': 'sample_offered',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

/// Step 6: a translated copy's link to the recipe it was translated from
/// (IMP-14, Decision 9). No foreign key on purpose: deleting either recipe
/// leaves the other whole, and the trash purge (DEL-2) hard-deletes rows,
/// which a reference would block — a link to a recipe that is gone simply
/// stops showing. The index serves the original's "الترجمة" lookup.
Future<void> _v6TranslatedFrom(DatabaseExecutor db) async {
  await db.execute('ALTER TABLE recipes ADD COLUMN translated_from TEXT');
  await db.execute(
    'CREATE INDEX recipes_translated_from ON recipes(translated_from)',
  );
}
