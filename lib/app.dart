import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'models/settings.dart' show appLanguage;
import 'providers/grocery_state.dart';
import 'providers/plan_state.dart';
import 'providers/recipes_state.dart';
import 'providers/settings_state.dart';
import 'screens/home_screen.dart';
import 'providers/timers_state.dart';
import 'services/backup.dart';
import 'services/backup_files.dart';
import 'services/cook_services.dart';
import 'services/importer.dart';
import 'services/photo_store.dart';
import 'services/recipe_pages.dart' show ShareStorage;
import 'services/sharer.dart';
import 'services/web_import.dart';
import 'widgets/share_router.dart';

// Also the fixed light scheme for the share images (SHARE-3,
// services/recipe_pages.dart), so a shared picture always matches the app's
// own colours whatever the device's theme.
const seedColor = Color(0xFFB5542B); // saffron / terracotta
const fontFamily = 'IBMPlexSansArabic';

/// The app shell. State and services are built by the caller (the entry
/// point, or a test with fakes), never here.
class WasfatiApp extends StatelessWidget {
  const WasfatiApp({
    super.key,
    required this.recipes,
    required this.plan,
    required this.groceries,
    required this.settings,
    this.photos = const NoopPhotoStore(),
    required this.timers,
    this.screenAwake = const NoopScreenAwake(),
    required this.importer,
    this.shareInbox = const NoopShareInbox(),
    required this.sharer,
    required this.shareStorage,
    required this.backup,
    required this.backupFiles,
  });

  final RecipesState recipes;
  final PlanState plan;
  final GroceryState groceries;
  final SettingsState settings;
  final PhotoStore photos;
  final TimersState timers;
  final ScreenAwake screenAwake;
  final Importer importer;
  final ShareInbox shareInbox;

  /// The backup engine (BAK-1–BAK-10), over this same app's database. No
  /// default: a real one always needs the app's actual database and photos
  /// folder, so a screen or test that forgot to pass one should fail loudly
  /// rather than silently back up nothing.
  final BackupService backup;

  /// The system's save and open dialogs for backups and exports (BAK-6,
  /// BAK-7, BAK-10). No default, for the same reason as [sharer]: the test
  /// fake records calls, so a test that forgot one should fail loudly.
  final BackupFiles backupFiles;

  /// Sends text or files through the platform share sheet (GRO-6,
  /// SHARE-1–SHARE-4). No default: the caller (`main.dart`, or a test)
  /// always builds it, since the real one is stateless but the test fake
  /// records calls and can't be a compile-time constant.
  final Sharer sharer;

  /// Where the share-as-images pages are rendered to (SHARE-3, SHARE-4). No
  /// default, for the same reason as [sharer]: a test that forgot to pass a
  /// fake should fail loudly, never quietly write into the real cache.
  final ShareStorage shareStorage;

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: recipes),
        ChangeNotifierProvider.value(value: plan),
        ChangeNotifierProvider.value(value: groceries),
        ChangeNotifierProvider.value(value: settings),
        Provider<PhotoStore>.value(value: photos),
        ChangeNotifierProvider.value(value: timers),
        Provider<ScreenAwake>.value(value: screenAwake),
        Provider<Importer>.value(value: importer),
        Provider<ShareInbox>.value(value: shareInbox),
        Provider<Sharer>.value(value: sharer),
        Provider<ShareStorage>.value(value: shareStorage),
        Provider<BackupService>.value(value: backup),
        Provider<BackupFiles>.value(value: backupFiles),
      ],
      child: _RamadanSync(
        settings: settings,
        plan: plan,
        child: Consumer<SettingsState>(
          builder: (context, s, _) => MaterialApp(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            // LANG-1, RUN-6 (should-fix, review): resolved by the same
            // appLanguage main.dart uses for the sample recipe, so the two
            // never disagree on what language the app actually starts in.
            // A concrete `locale:` (never null), not
            // localeListResolutionCallback, so a language change in
            // Settings still applies at once: WidgetsApp only re-resolves
            // through the callback path when supportedLocales itself
            // changes, but re-resolves a non-null `locale` on every build.
            locale: appLanguage(
              s.settings.language,
              WidgetsBinding.instance.platformDispatcher.locales,
            ),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: s.themeMode,
            theme: _theme(Brightness.light),
            darkTheme: _theme(Brightness.dark),
            navigatorKey: navigatorKey,
            builder: (context, child) =>
                ShareRouter(navigator: navigatorKey, child: child!),
            home: const HomeScreen(),
          ),
        ),
      ),
    );
  }

  static ThemeData _theme(Brightness b) => ThemeData(
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: b),
  );
}

/// Keeps [PlanState] in step with Settings' Ramadan fields regardless of
/// which screen is on screen (should-fix, RAM-1/RAM-2): this used to
/// happen only from `PlanScreen.didChangeDependencies`, so Settings (and
/// anything else reading `plan.ramadanMode`/`ramadanFor`) saw stale
/// Ramadan dates whenever the plan tab wasn't mounted — which HomeScreen
/// never mounts at all while the library is empty.
class _RamadanSync extends StatefulWidget {
  const _RamadanSync({
    required this.settings,
    required this.plan,
    required this.child,
  });

  final SettingsState settings;
  final PlanState plan;
  final Widget child;

  @override
  State<_RamadanSync> createState() => _RamadanSyncState();
}

class _RamadanSyncState extends State<_RamadanSync> {
  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_sync);
    _sync();
  }

  void _sync() {
    final s = widget.settings.settings;
    widget.plan.setRamadanMode(
      s.ramadanMode,
      shift: s.ramadanShift,
      shiftYear: s.ramadanShiftYear,
    );
  }

  @override
  void dispose() {
    widget.settings.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
