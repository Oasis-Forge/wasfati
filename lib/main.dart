import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'db/db_helper.dart';
import 'db/grocery_repository.dart';
import 'db/plan_repository.dart';
import 'db/recipe_repository.dart';
import 'providers/grocery_state.dart';
import 'providers/plan_state.dart';
import 'providers/recipes_state.dart';
import 'providers/settings_state.dart';
import 'providers/timers_state.dart';
import 'services/cook_services.dart';
import 'services/importer.dart';
import 'services/sharer.dart';
import 'services/web_import.dart';
import 'services/photo_store.dart';

/// The only place real services are built; tests use fakes (CLAUDE.md).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await DBHelper.open(
    databaseFactory,
    p.join(await getDatabasesPath(), 'wasfati.db'),
  );
  final repo = RecipeRepository(db);
  final planRepo = PlanRepository(db);
  final groceryRepo = GroceryRepository(db);
  final photos = DevicePhotoStore();
  // DEL-2: purge the trash on app start, and the purged photos (REC-8).
  for (final path in await repo.purgeTrash()) {
    await photos.delete(path);
  }
  await planRepo.purgeTrash();
  await groceryRepo.purgeTrash();
  await repo.installId(); // SRV-4: created once, on first launch
  final settings = SettingsState(db);
  await settings.load();
  final recipes = RecipesState(repo);
  await recipes.load();
  final groceries = GroceryState(groceryRepo);
  await groceries.load();
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
      plan: PlanState(planRepo),
      groceries: groceries,
      settings: settings,
      photos: photos,
      timers: timers,
      screenAwake: const DeviceScreenAwake(),
      importer: Importer(DeviceFetcher(), repo),
      shareInbox: const DeviceShareInbox(),
      sharer: const DeviceSharer(),
    ),
  );
}
