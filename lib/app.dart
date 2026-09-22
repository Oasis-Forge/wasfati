import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'providers/grocery_state.dart';
import 'providers/plan_state.dart';
import 'providers/recipes_state.dart';
import 'providers/settings_state.dart';
import 'screens/home_screen.dart';
import 'providers/timers_state.dart';
import 'services/cook_services.dart';
import 'services/importer.dart';
import 'services/photo_store.dart';
import 'services/sharer.dart';
import 'services/web_import.dart';
import 'widgets/share_router.dart';

const _seed = Color(0xFFB5542B); // saffron / terracotta
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

  /// Sends text or files through the platform share sheet (GRO-6,
  /// SHARE-1–SHARE-4). No default: the caller (`main.dart`, or a test)
  /// always builds it, since the real one is stateless but the test fake
  /// records calls and can't be a compile-time constant.
  final Sharer sharer;

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
      ],
      child: Consumer<SettingsState>(
        builder: (context, s, _) => MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          locale: s.locale, // LANG-1: null follows the device
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
    );
  }

  static ThemeData _theme(Brightness b) => ThemeData(
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: b),
  );
}
