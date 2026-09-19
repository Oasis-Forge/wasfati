import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'db/db_helper.dart';
import 'db/recipe_repository.dart';
import 'providers/recipes_state.dart';
import 'providers/settings_state.dart';
import 'providers/timers_state.dart';
import 'services/cook_services.dart';
import 'services/photo_store.dart';

/// The only place real services are built; tests use fakes (CLAUDE.md).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await DBHelper.open(
    databaseFactory,
    p.join(await getDatabasesPath(), 'wasfati.db'),
  );
  final repo = RecipeRepository(db);
  final photos = DevicePhotoStore();
  // DEL-2: purge the trash on app start, and the purged photos (REC-8).
  for (final path in await repo.purgeTrash()) {
    await photos.delete(path);
  }
  await repo.installId(); // SRV-4: created once, on first launch
  final settings = SettingsState(db);
  await settings.load();
  final recipes = RecipesState(repo);
  await recipes.load();
  final alerts = DeviceTimerAlerts();
  await alerts.init();
  final timers = TimersState(
    alerts,
    inForeground: () =>
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
  );
  runApp(
    WasfatiApp(
      recipes: recipes,
      settings: settings,
      photos: photos,
      timers: timers,
      screenAwake: const DeviceScreenAwake(),
    ),
  );
}
