import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// App name in the app bar and launcher.
  ///
  /// In en, this message translates to:
  /// **'Wasfati'**
  String get appTitle;

  /// RUN-1. Empty recipe list heading.
  ///
  /// In en, this message translates to:
  /// **'No recipes yet'**
  String get recipesEmptyTitle;

  /// RUN-1. Empty recipe list explanation.
  ///
  /// In en, this message translates to:
  /// **'Share a recipe from TikTok, Instagram or YouTube, or add your own.'**
  String get recipesEmptyBody;

  /// RUN-1. The one clear first action on the empty list.
  ///
  /// In en, this message translates to:
  /// **'Add a recipe'**
  String get recipesAdd;

  /// Number of saved recipes. {shown} is {count} in the chosen digit style (QTY-5).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No recipes} =1{1 recipe} other{{shown} recipes}}'**
  String recipesCount(int count, String shown);

  /// Reliable writes: shown when a database write fails and state was rolled back.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Your changes weren\'t lost; try again.'**
  String get errorSaveFailed;

  /// DEL-2. Snackbar after deleting a recipe.
  ///
  /// In en, this message translates to:
  /// **'Recipe deleted'**
  String get deletedSnack;

  /// DEL-2. Snackbar action.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// A duration in minutes on the recipe page.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min} other{{shown} min}}'**
  String minutes(int count, String shown);

  /// REC-7. Number of servings on the recipe page.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 serving} other{{shown} servings}}'**
  String servings(int count, String shown);

  /// Label before the prep time.
  ///
  /// In en, this message translates to:
  /// **'Prep'**
  String get prepTime;

  /// Label before the cook time.
  ///
  /// In en, this message translates to:
  /// **'Cook'**
  String get cookTime;

  /// Recipe page and editor heading.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredients;

  /// Recipe page and editor heading.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// Recipe page and editor heading.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Where an imported recipe came from; {site} is a domain.
  ///
  /// In en, this message translates to:
  /// **'From {site}'**
  String sourceFrom(String site);

  /// Button: edit the recipe.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Button: move the recipe to the trash (DEL-1).
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Editor button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Editor title when adding.
  ///
  /// In en, this message translates to:
  /// **'New recipe'**
  String get newRecipe;

  /// Editor title when editing.
  ///
  /// In en, this message translates to:
  /// **'Edit recipe'**
  String get editRecipe;

  /// REC-3. Editor field.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// REC-3. Error when the title is empty.
  ///
  /// In en, this message translates to:
  /// **'Give the recipe a name'**
  String get fieldTitleRequired;

  /// REC-7. Editor field.
  ///
  /// In en, this message translates to:
  /// **'Servings'**
  String get fieldServings;

  /// REC-7. Error for servings out of range.
  ///
  /// In en, this message translates to:
  /// **'1 to 100'**
  String get fieldServingsInvalid;

  /// Editor field, minutes.
  ///
  /// In en, this message translates to:
  /// **'Prep (min)'**
  String get fieldPrep;

  /// Editor field, minutes.
  ///
  /// In en, this message translates to:
  /// **'Cook (min)'**
  String get fieldCook;

  /// REC-4, REC-5. Editor hint for the ingredients box.
  ///
  /// In en, this message translates to:
  /// **'One ingredient per line, e.g. 2 cups rice\nA line ending with : starts a group, e.g. For the sauce:'**
  String get fieldIngredientsHint;

  /// REC-6. Editor hint for the steps box.
  ///
  /// In en, this message translates to:
  /// **'One step per line'**
  String get fieldStepsHint;

  /// Error for a non-numeric minutes field.
  ///
  /// In en, this message translates to:
  /// **'Numbers only'**
  String get fieldNumberInvalid;

  /// REC-6. Error when a step is too long.
  ///
  /// In en, this message translates to:
  /// **'A step is longer than 2,000 characters'**
  String get stepTooLong;

  /// REC-8. Editor button.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get photoAdd;

  /// REC-8. Editor button.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get photoRemove;

  /// Dialog when leaving the editor with unsaved changes.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardTitle;

  /// Dialog button.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// Dialog button.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// Shown when a recipe was deleted elsewhere.
  ///
  /// In en, this message translates to:
  /// **'This recipe is no longer here.'**
  String get recipeMissing;

  /// Settings screen title and button.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// LANG-1.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// LANG-1.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// QTY-5, Decision 5. Digit style setting.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get settingsDigits;

  /// SCALE-5. Unit system setting.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get settingsUnits;

  /// SCALE-5.
  ///
  /// In en, this message translates to:
  /// **'Metric (g, ml)'**
  String get unitsMetric;

  /// SCALE-5.
  ///
  /// In en, this message translates to:
  /// **'Cups and spoons'**
  String get unitsKitchen;

  /// Meal plan week start.
  ///
  /// In en, this message translates to:
  /// **'Week starts on'**
  String get settingsWeekStart;

  /// Week start follows the region (Saturday in the Gulf).
  ///
  /// In en, this message translates to:
  /// **'By region'**
  String get weekStartAuto;

  /// Weekday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// Weekday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// Weekday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// Theme setting.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// Theme follows the device.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Light theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
