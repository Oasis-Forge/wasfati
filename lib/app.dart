import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'providers/recipes_state.dart';
import 'screens/home_screen.dart';

/// The app shell. State and services are built by the caller (the entry
/// point, or a test with fakes), never here.
class WasfatiApp extends StatelessWidget {
  const WasfatiApp({super.key, required this.recipes, this.locale});

  final RecipesState recipes;

  /// Forces a language (tests, and later Settings, LANG-1); null follows the
  /// device and falls back to English.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: recipes,
      child: MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB5542B)),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFB5542B),
            brightness: Brightness.dark,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
