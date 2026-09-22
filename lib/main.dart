import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'db/db_helper.dart';
import 'db/grocery_repository.dart';
import 'db/plan_repository.dart';
import 'db/recipe_repository.dart';
import 'models/settings.dart';
import 'providers/grocery_state.dart';
import 'providers/plan_state.dart';
import 'providers/recipes_state.dart';
import 'providers/settings_state.dart';
import 'providers/timers_state.dart';
import 'services/backup.dart';
import 'services/backup_files.dart';
import 'services/cook_services.dart';
import 'services/importer.dart';
import 'services/recipe_pages.dart';
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
  final settings = SettingsState(db);
  await settings.load();
  // RUN-6: offered once, before the trash is ever purged (must-fix,
  // review) — otherwise an upgrade whose only recipes sat in the trash for
  // over 30 days would lose them to the purge below and then read as an
  // empty, never-offered library. Schema step 5 (db_helper.dart) already
  // marks such a database as offered, but the ordering here matters too:
  // a fresh install's purge is always a no-op, so this never delays it.
  // The language matches what the app actually starts in (LANG-1),
  // through the same resolver MaterialApp uses (app.dart).
  final arabic =
      appLanguage(
        settings.settings.language,
        WidgetsBinding.instance.platformDispatcher.locales,
      ).languageCode ==
      'ar';
  await repo.addSampleOnFirstRun(arabic: arabic);
  // DEL-2: purge the trash on app start, and the purged photos (REC-8).
  for (final path in await repo.purgeTrash()) {
    await photos.delete(path);
  }
  await planRepo.purgeTrash();
  await groceryRepo.purgeTrash();
  const shareStorage = DeviceShareStorage();
  try {
    await clearShareCache(shareStorage); // SHARE-4: never outlive this run
  } on Exception {
    // should-fix, adversarial review: best-effort housekeeping — a folder
    // that can't be deleted today is retried at the next start, but must
    // never stop the app from opening at all.
  }
  await repo.installId(); // SRV-4: created once, on first launch
  final supportDir = await getApplicationSupportDirectory();
  final packageInfo = await PackageInfo.fromPlatform();
  final backup = BackupService(
    db,
    factory: databaseFactory,
    photosDir: Directory(p.join(supportDir.path, 'photos')),
    backupsDir: Directory(p.join(supportDir.path, 'backups')),
    appVersion: packageInfo.version,
  );
  const backupFiles = DeviceBackupFiles();
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
      shareStorage: shareStorage,
      backup: backup,
      backupFiles: backupFiles,
    ),
  );
}
