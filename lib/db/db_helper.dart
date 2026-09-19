import 'package:sqflite/sqflite.dart';

/// One schema step. Steps run in order on create and on upgrade; a merged
/// step is never edited, only a new one appended (CLAUDE.md conventions).
typedef SchemaStep = Future<void> Function(DatabaseExecutor db);

/// Opens the app database and runs the schema steps.
class DBHelper {
  DBHelper._();

  /// The ordered steps; the schema version is their count.
  static final List<SchemaStep> steps = [_v1Recipes];

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
