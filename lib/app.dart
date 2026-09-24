import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'models/settings.dart' show appLanguage;
import 'providers/ads_state.dart';
import 'providers/backup_state.dart';
import 'providers/grocery_state.dart';
import 'providers/plan_state.dart';
import 'providers/purchases_state.dart';
import 'providers/recipes_state.dart';
import 'providers/settings_state.dart';
import 'screens/home_screen.dart';
import 'providers/timers_state.dart';
import 'services/backup.dart';
import 'services/backup_files.dart';
import 'services/cook_services.dart';
import 'services/import_photos.dart';
import 'services/importer.dart';
import 'services/mail.dart';
import 'services/photo_store.dart';
import 'services/recipe_pages.dart' show ShareStorage;
import 'services/sharer.dart';
import 'services/web_import.dart';
import 'theme/app_theme.dart';
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
    required this.backupState,
    required this.mail,
    required this.importPhotos,
    required this.purchases,
    required this.ads,
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

  /// The Settings screen's backup, restore and export flow (BAK-1–BAK-10):
  /// busy, the last result, the last error, and the calls into [backup] and
  /// [backupFiles]. No default, like every other state here (CLAUDE.md):
  /// built once by the caller (`main.dart`, or a test's `pumpApp`), never
  /// rebuilt on every frame, so it keeps its state across rebuilds.
  final BackupState backupState;

  /// Opens the user's mail app for "Report a mistake" (IMP-8, Decision 19).
  /// No default, for the same reason as [sharer]: the test fake records
  /// every draft, so a test that forgot one should fail loudly.
  final MailComposer mail;

  /// The camera and photo picker for a photo import (IMP-1, IMP-10,
  /// IMP-12). No default, like [mail]: the test fake is scripted per test.
  final ImportPhotoPicker importPhotos;

  /// Pro and Premium (PAY-1–PAY-11): what the store account owns and what
  /// it sells. No default, like every other state here: built once by the
  /// caller over a real store (`main.dart`) or a fake (a test).
  final PurchasesState purchases;

  /// The banner slots (ADS-1–ADS-9), over the ad network and [purchases].
  /// No default, for the same reason.
  final AdsState ads;

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
        ChangeNotifierProvider.value(value: backupState),
        Provider<MailComposer>.value(value: mail),
        Provider<ImportPhotoPicker>.value(value: importPhotos),
        ChangeNotifierProvider.value(value: purchases),
        ChangeNotifierProvider.value(value: ads),
      ],
      child: _RamadanSync(
        settings: settings,
        plan: plan,
        child: _PayingSync(
          settings: settings,
          purchases: purchases,
          ads: ads,
          // LANG-1: rebuilds the MaterialApp below whenever the PHONE's own
          // locales change while Wasfati is already open (didChangeLocales),
          // so its `locale:` is re-resolved at once instead of only at the
          // next launch. A Settings change already rebuilds it through
          // Consumer<SettingsState>; this covers the other half — the device
          // language changing underneath a running app on "حسب الجهاز".
          child: const _LocaleObserver(),
        ),
      ),
    );
  }
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

/// Keeps the paying state in step with the rest of the app, whichever
/// screen is showing:
///  * ADS-4: no ad — and no consent form — before setup and the walkthrough
///    are finished (RUN-3, RUN-4). Settings says when they are.
///  * PAY-1: the store is asked again what's owned whenever the app comes
///    back to the front, so a subscription cancelled or refunded in Google
///    Play while Wasfati was in the background lands at once.
class _PayingSync extends StatefulWidget {
  const _PayingSync({
    required this.settings,
    required this.purchases,
    required this.ads,
    required this.child,
  });

  final SettingsState settings;
  final PurchasesState purchases;
  final AdsState ads;
  final Widget child;

  @override
  State<_PayingSync> createState() => _PayingSyncState();
}

class _PayingSyncState extends State<_PayingSync> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_sync);
    // Not during this build: AdsState notifies the providers above.
    scheduleMicrotask(_sync);
  }

  void _sync() {
    if (!mounted) return;
    // ADS-4: the first run's own flag goes here —
    // `widget.settings.settings.firstRunComplete` once RUN-3/RUN-4 add it.
    // Until then there is no first run to wait for.
    widget.ads.setSetupFinished(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.purchases.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// LANG-1 (must-fix, review): builds the [MaterialApp], rebuilding it fresh
/// on the platform's own locale change, not just on a Settings change.
/// `locale:` below is resolved fresh on every rebuild (its own comment), but
/// nothing used to *cause* a rebuild when the PHONE's language changed
/// while "حسب الجهاز" (LanguagePref.system) was on and Wasfati stayed open —
/// Flutter only tells [WidgetsBindingObserver.didChangeLocales], it doesn't
/// rebuild anything on its own. `setState` here (with no state to change)
/// is only ever a trigger, exactly like [_RamadanSyncState] triggers off a
/// listener.
///
/// Builds [MaterialApp] itself, rather than taking it as a `child` widget
/// built by the caller once: a `child` field is the SAME widget instance on
/// every `setState`, and Flutter's element diffing skips rebuilding an
/// identical child widget entirely (the usual `AnimatedBuilder`-style
/// optimization) — so `didChangeLocales`'s `setState` would trigger, but
/// never actually reach `MaterialApp` to re-resolve its `locale:` (must-fix,
/// review: caught only by the widget test that changes
/// `tester.platformDispatcher.localesTestValue` after the app is already
/// running, not by anything that stops at the Settings screen's own
/// language change).
class _LocaleObserver extends StatefulWidget {
  const _LocaleObserver();

  @override
  State<_LocaleObserver> createState() => _LocaleObserverState();
}

class _LocaleObserverState extends State<_LocaleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    setState(() {}); // re-resolve appLanguage(...) below, at once
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<SettingsState>(
    builder: (context, s, _) => MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      // LANG-1, RUN-6 (should-fix, review): resolved by the same
      // appLanguage main.dart uses for the sample recipe, so the two never
      // disagree on what language the app actually starts in. A concrete
      // `locale:` (never null), not localeListResolutionCallback, so a
      // language change in Settings still applies at once: WidgetsApp only
      // re-resolves through the callback path when supportedLocales itself
      // changes, but re-resolves a non-null `locale` on every build — which
      // this State's own rebuilds (Settings, or didChangeLocales above)
      // both now reach.
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
      // LOOK-1: the look (Ink/Saffron) is independent of light/dark, and
      // applies at once because Settings changes reach this Consumer.
      theme: wasfatiTheme(s.settings.style, Brightness.light),
      darkTheme: wasfatiTheme(s.settings.style, Brightness.dark),
      navigatorKey: WasfatiApp.navigatorKey,
      builder: (context, child) =>
          ShareRouter(navigator: WasfatiApp.navigatorKey, child: child!),
      home: const HomeScreen(),
    ),
  );
}
