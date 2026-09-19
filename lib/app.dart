import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'providers/recipes_state.dart';
import 'providers/settings_state.dart';
import 'screens/home_screen.dart';
import 'services/photo_store.dart';

const _seed = Color(0xFFB5542B); // saffron / terracotta
const fontFamily = 'IBMPlexSansArabic';

/// The app shell. State and services are built by the caller (the entry
/// point, or a test with fakes), never here.
class WasfatiApp extends StatelessWidget {
  const WasfatiApp({
    super.key,
    required this.recipes,
    required this.settings,
    this.photos = const NoopPhotoStore(),
  });

  final RecipesState recipes;
  final SettingsState settings;
  final PhotoStore photos;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: recipes),
        ChangeNotifierProvider.value(value: settings),
        Provider<PhotoStore>.value(value: photos),
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
