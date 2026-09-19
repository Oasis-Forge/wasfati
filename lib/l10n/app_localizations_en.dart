// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Wasfati';

  @override
  String get recipesEmptyTitle => 'No recipes yet';

  @override
  String get recipesEmptyBody =>
      'Share a recipe from TikTok, Instagram or YouTube, or add your own.';

  @override
  String get recipesAdd => 'Add a recipe';

  @override
  String recipesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
      zero: 'No recipes',
    );
    return '$_temp0';
  }

  @override
  String get errorSaveFailed =>
      'Couldn\'t save. Your changes weren\'t lost; try again.';

  @override
  String get deletedSnack => 'Recipe deleted';

  @override
  String get undo => 'Undo';
}
