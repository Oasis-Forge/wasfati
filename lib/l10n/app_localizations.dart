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

  /// ORG-1. Library tab.
  ///
  /// In en, this message translates to:
  /// **'All recipes'**
  String get tabAllRecipes;

  /// ORG-1. Library tab.
  ///
  /// In en, this message translates to:
  /// **'Cookbooks'**
  String get tabCookbooks;

  /// ORG-3. Search box hint.
  ///
  /// In en, this message translates to:
  /// **'Search recipes or ingredients'**
  String get searchHint;

  /// Tooltip for clearing the search box.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClear;

  /// ORG-3. Shown under a recipe that matched only by an ingredient.
  ///
  /// In en, this message translates to:
  /// **'Contains: {name}'**
  String containsIngredient(String name);

  /// Search or filters found nothing.
  ///
  /// In en, this message translates to:
  /// **'No recipes match'**
  String get noResults;

  /// ORG-6. Button.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// ORG-5. Sort chip and sheet title.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortBy;

  /// ORG-5.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get sortRecent;

  /// ORG-5. Alphabetical.
  ///
  /// In en, this message translates to:
  /// **'A–Z'**
  String get sortAz;

  /// ORG-5.
  ///
  /// In en, this message translates to:
  /// **'Recently cooked'**
  String get sortRecentlyCooked;

  /// ORG-5.
  ///
  /// In en, this message translates to:
  /// **'Most cooked'**
  String get sortMostCooked;

  /// ORG-6. Filter chip.
  ///
  /// In en, this message translates to:
  /// **'Cookbook'**
  String get filterCookbook;

  /// ORG-6. Filter chip.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get filterTag;

  /// ORG-6. Filter chip.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get filterSource;

  /// ORG-6. Filter chip.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get filterTime;

  /// ORG-6. Filter chip.
  ///
  /// In en, this message translates to:
  /// **'Has photo'**
  String get filterPhoto;

  /// REC-3 source type.
  ///
  /// In en, this message translates to:
  /// **'Written by me'**
  String get sourceWritten;

  /// REC-3 source type.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get sourceWebsite;

  /// REC-3 source type.
  ///
  /// In en, this message translates to:
  /// **'Social media'**
  String get sourceSocial;

  /// REC-3 source type.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get sourcePhoto;

  /// ORG-6 time filter.
  ///
  /// In en, this message translates to:
  /// **'Under 30 min'**
  String get timeUnder30;

  /// ORG-6 time filter.
  ///
  /// In en, this message translates to:
  /// **'30–60 min'**
  String get time30to60;

  /// ORG-6 time filter.
  ///
  /// In en, this message translates to:
  /// **'Over 1 hour'**
  String get timeOver60;

  /// Filter option: no filter.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get any;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get viewGrid;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get viewList;

  /// ORG-1. Button and dialog title.
  ///
  /// In en, this message translates to:
  /// **'New cookbook'**
  String get cookbookNew;

  /// ORG-1. Dialog field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get cookbookName;

  /// ORG-1. Validation.
  ///
  /// In en, this message translates to:
  /// **'1 to 60 characters'**
  String get cookbookNameInvalid;

  /// ORG-1. Menu item.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get cookbookRename;

  /// ORG-1. Menu item.
  ///
  /// In en, this message translates to:
  /// **'Delete cookbook'**
  String get cookbookDelete;

  /// ORG-1. Confirmation text.
  ///
  /// In en, this message translates to:
  /// **'The recipes stay in your library.'**
  String get cookbookDeleteBody;

  /// ORG-1. Recipes in a cookbook.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No recipes} =1{1 recipe} other{{shown} recipes}}'**
  String cookbookRecipes(int count, String shown);

  /// RUN-1. Empty cookbooks tab.
  ///
  /// In en, this message translates to:
  /// **'Group recipes your way: Ramadan, quick dinners, family favourites.'**
  String get cookbooksEmpty;

  /// RUN-1. Empty cookbook.
  ///
  /// In en, this message translates to:
  /// **'No recipes in this cookbook yet. Add them from a recipe\'s edit screen.'**
  String get cookbookEmpty;

  /// ORG-2. Editor field.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get fieldTags;

  /// ORG-2. Editor hint.
  ///
  /// In en, this message translates to:
  /// **'Separate with commas, e.g. spicy, Ramadan'**
  String get fieldTagsHint;

  /// ORG-2. Validation.
  ///
  /// In en, this message translates to:
  /// **'Up to 20 tags, 30 characters each'**
  String get tagsInvalid;

  /// ORG-1. Editor section.
  ///
  /// In en, this message translates to:
  /// **'Cookbooks'**
  String get fieldCookbooks;

  /// Dialog button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Dialog button.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// SCALE-2. Back to ×1.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get scaleReset;

  /// SCALE-2. Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Fewer servings'**
  String get servingsLess;

  /// SCALE-2. Tooltip.
  ///
  /// In en, this message translates to:
  /// **'More servings'**
  String get servingsMore;

  /// SCALE-4. Mark on a line the scaler couldn't change.
  ///
  /// In en, this message translates to:
  /// **'not scaled'**
  String get notScaled;

  /// SCALE-4. Header when some lines couldn't be scaled.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 ingredient wasn\'t scaled} other{{shown} ingredients weren\'t scaled}}'**
  String notScaledCount(int count, String shown);

  /// SCALE-5. Conversion view.
  ///
  /// In en, this message translates to:
  /// **'As written'**
  String get viewAsWritten;

  /// SCALE-5. Conversion view.
  ///
  /// In en, this message translates to:
  /// **'g / ml'**
  String get viewMetric;

  /// SCALE-5. Conversion view.
  ///
  /// In en, this message translates to:
  /// **'Cups'**
  String get viewKitchen;

  /// COOK-1. Button on the recipe page.
  ///
  /// In en, this message translates to:
  /// **'Start cooking'**
  String get startCooking;

  /// COOK-2. Cook mode progress; numbers already in the chosen digit style.
  ///
  /// In en, this message translates to:
  /// **'Step {n} of {total}'**
  String stepOf(String n, String total);

  /// COOK-4. Which step a running timer belongs to.
  ///
  /// In en, this message translates to:
  /// **'Step {n}'**
  String stepN(String n);

  /// COOK-2. Button.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousStep;

  /// COOK-2. Button.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextStep;

  /// COOK-6. Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Close cook mode'**
  String get closeCooking;

  /// COOK-6. Last cook-mode page.
  ///
  /// In en, this message translates to:
  /// **'Enjoy your meal!'**
  String get finishTitle;

  /// COOK-6, REC-9. Button.
  ///
  /// In en, this message translates to:
  /// **'Mark as cooked'**
  String get markCooked;

  /// COOK-6. Confirmation.
  ///
  /// In en, this message translates to:
  /// **'Marked as cooked'**
  String get markedCooked;

  /// COOK-6. Leaves cook mode.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// COOK-4. Tooltip on a timer found in a step.
  ///
  /// In en, this message translates to:
  /// **'Start a {time} timer'**
  String timerStart(String time);

  /// COOK-4. Tooltip and dialog title.
  ///
  /// In en, this message translates to:
  /// **'Stop timer'**
  String get timerStop;

  /// COOK-5. In-app banner and notification body.
  ///
  /// In en, this message translates to:
  /// **'Timer done: step {n}'**
  String timerDone(String n);

  /// COOK-5. Android notification channel name.
  ///
  /// In en, this message translates to:
  /// **'Cooking timers'**
  String get timerChannel;

  /// COOK-5. Shown once after notification permission is refused.
  ///
  /// In en, this message translates to:
  /// **'Background timer alerts are off. Timers still ring while Wasfati is open.'**
  String get alertsOff;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get dismiss;

  /// IMP-2. Screen title and button.
  ///
  /// In en, this message translates to:
  /// **'Import from a link'**
  String get importTitle;

  /// IMP-2. Link field hint.
  ///
  /// In en, this message translates to:
  /// **'Paste a recipe link'**
  String get importHint;

  /// IMP-2. Under the link field.
  ///
  /// In en, this message translates to:
  /// **'Recipes from sites like Fatafeat and Cookpad are read on your phone, free and unlimited.'**
  String get importExplain;

  /// Reads the clipboard only when tapped (IMP-12).
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// IMP-2. Button.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// IMP-4. Progress step.
  ///
  /// In en, this message translates to:
  /// **'Opening the page…'**
  String get importReading;

  /// IMP-4. Progress step.
  ///
  /// In en, this message translates to:
  /// **'Reading the recipe…'**
  String get importUnderstanding;

  /// IMP-2. Error.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a link.'**
  String get importInvalidUrl;

  /// IMP-2. Error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the page. Check the link and your connection.'**
  String get importUnreachable;

  /// IMP-2, IMP-11. The page has no schema.org recipe; AI import comes later.
  ///
  /// In en, this message translates to:
  /// **'Wasfati can\'t find recipe data on this page yet. You can still add it by hand.'**
  String get importNoRecipe;

  /// Opens the editor with the link as the source.
  ///
  /// In en, this message translates to:
  /// **'Add by hand'**
  String get addByHand;

  /// IMP-9. Dialog title.
  ///
  /// In en, this message translates to:
  /// **'Already saved'**
  String get duplicateTitle;

  /// IMP-9. Dialog text.
  ///
  /// In en, this message translates to:
  /// **'You saved a recipe from this page before.'**
  String get duplicateBody;

  /// IMP-9. Dialog button.
  ///
  /// In en, this message translates to:
  /// **'Open the saved one'**
  String get openSaved;

  /// IMP-9. Dialog button.
  ///
  /// In en, this message translates to:
  /// **'Import again'**
  String get importAgain;

  /// IMP-5. Title of the preview (the editor, prefilled).
  ///
  /// In en, this message translates to:
  /// **'Check and save'**
  String get importedRecipe;

  /// The meal plan screen and its navigation destination (PLAN-1)
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get planTitle;

  /// The library destination in the bottom navigation bar
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get tabRecipes;

  /// Returns the plan to the current week (PLAN-1)
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get planThisWeek;

  /// Tooltip on the arrow that moves a week back
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get planPreviousWeek;

  /// Tooltip on the arrow that moves a week forward
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get planNextWeek;

  /// Marks today's day in the plan
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get planToday;

  /// Meal slot (PLAN-1)
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealBreakfast;

  /// Meal slot (PLAN-1)
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealLunch;

  /// Meal slot (PLAN-1)
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealDinner;

  /// Meal slot (PLAN-1)
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get mealSnack;

  /// Tooltip on the + of an empty meal slot (PLAN-3)
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get planAdd;

  /// Opens the recipe picker for a meal (PLAN-3)
  ///
  /// In en, this message translates to:
  /// **'Choose a recipe'**
  String get planAddRecipe;

  /// Plans a meal without a recipe (PLAN-2)
  ///
  /// In en, this message translates to:
  /// **'Write a note'**
  String get planAddNote;

  /// Label of the note field (PLAN-2)
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get planNoteLabel;

  /// Hint in the note field (PLAN-2)
  ///
  /// In en, this message translates to:
  /// **'Eating out, leftovers…'**
  String get planNoteHint;

  /// The note is empty or too long (PLAN-2)
  ///
  /// In en, this message translates to:
  /// **'1–60 characters'**
  String get planNoteInvalid;

  /// Button on a recipe page, and the title of its sheet (PLAN-3)
  ///
  /// In en, this message translates to:
  /// **'Add to plan'**
  String get planAddToPlan;

  /// Snackbar after planning a recipe (PLAN-3)
  ///
  /// In en, this message translates to:
  /// **'Added to the plan'**
  String get planAdded;

  /// Label above the day chips in the add sheet (PLAN-3)
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get planChooseDay;

  /// Label above the meal chips in the add sheet (PLAN-3)
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get planChooseMeal;

  /// The multiplier for a recipe with no servings (PLAN-2, SCALE-2)
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get planAmount;

  /// Moves an entry to another day or meal (PLAN-4)
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get planMove;

  /// Copies an entry to another day or meal (PLAN-4)
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get planCopy;

  /// Takes an entry out of the plan (PLAN-4)
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get planRemove;

  /// Snackbar with Undo after removing an entry (PLAN-4, DEL-2)
  ///
  /// In en, this message translates to:
  /// **'Removed from the plan'**
  String get planRemoved;

  /// Removes every entry of the week shown (PLAN-4)
  ///
  /// In en, this message translates to:
  /// **'Clear week'**
  String get planClearWeek;

  /// Snackbar after clearing a week (PLAN-4)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to clear} =1{1 meal removed} other{{shown} meals removed}}'**
  String planClearedCount(int count, String shown);

  /// The slot already has PlanEntry.maxPerSlot entries (PLAN-2)
  ///
  /// In en, this message translates to:
  /// **'A meal holds up to 10 entries'**
  String get planSlotFull;

  /// Empty plan heading (PLAN-1, RUN-1)
  ///
  /// In en, this message translates to:
  /// **'Plan your week'**
  String get planEmptyTitle;

  /// Empty plan explanation (PLAN-1, RUN-1)
  ///
  /// In en, this message translates to:
  /// **'Add a recipe to any meal, or write a note like “eating out”.'**
  String get planEmptyBody;

  /// On a recipe page, its next planned meal (PLAN-6)
  ///
  /// In en, this message translates to:
  /// **'In the plan: {day}, {meal}'**
  String planNextMeal(String day, String meal);

  /// GRO-5. The groceries tab label and screen title.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get groceriesTitle;

  /// GRO-2, PLAN-5. The recipe page's and the plan's app-bar action that opens the add-to-groceries sheet.
  ///
  /// In en, this message translates to:
  /// **'Add to groceries'**
  String get addToGroceries;

  /// GRO-1. Hint text of the typed-add field on the groceries screen.
  ///
  /// In en, this message translates to:
  /// **'Add an item'**
  String get groceriesAddHint;

  /// RUN-1. Shown with the add field when the list has nothing in it.
  ///
  /// In en, this message translates to:
  /// **'Your grocery list is empty'**
  String get groceriesEmptyTitle;

  /// No description provided for @groceriesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Type an item above, or add one from a recipe\'s page or the week\'s plan.'**
  String get groceriesEmptyBody;

  /// GRO-4. Aisle 1 of 12.
  ///
  /// In en, this message translates to:
  /// **'Vegetables and fruit'**
  String get aisleProduce;

  /// GRO-4. Aisle 2 of 12.
  ///
  /// In en, this message translates to:
  /// **'Meat and poultry'**
  String get aisleMeat;

  /// GRO-4. Aisle 3 of 12.
  ///
  /// In en, this message translates to:
  /// **'Fish and seafood'**
  String get aisleFish;

  /// GRO-4. Aisle 4 of 12.
  ///
  /// In en, this message translates to:
  /// **'Dairy, cheese and eggs'**
  String get aisleDairy;

  /// GRO-4. Aisle 5 of 12.
  ///
  /// In en, this message translates to:
  /// **'Bread and bakery'**
  String get aisleBakery;

  /// GRO-4. Aisle 6 of 12.
  ///
  /// In en, this message translates to:
  /// **'Rice, pasta and grains'**
  String get aisleGrains;

  /// GRO-4. Aisle 7 of 12.
  ///
  /// In en, this message translates to:
  /// **'Spices'**
  String get aisleSpices;

  /// GRO-4. Aisle 8 of 12.
  ///
  /// In en, this message translates to:
  /// **'Oils, sauces and cans'**
  String get aislePantry;

  /// GRO-4. Aisle 9 of 12.
  ///
  /// In en, this message translates to:
  /// **'Baking and sweets'**
  String get aisleBaking;

  /// GRO-4. Aisle 10 of 12.
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get aisleFrozen;

  /// GRO-4. Aisle 11 of 12.
  ///
  /// In en, this message translates to:
  /// **'Drinks'**
  String get aisleDrinks;

  /// GRO-4. Aisle 12 of 12.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get aisleOther;

  /// GRO-5. Heading of the collapsed section a ticked item moves into.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get groceriesDoneSection;

  /// GRO-5. Menu action.
  ///
  /// In en, this message translates to:
  /// **'Clear done'**
  String get groceriesClearDone;

  /// GRO-5. Menu action.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get groceriesClearAll;

  /// DEL-2. Snackbar after Clear done or Clear all.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to clear} =1{1 item cleared} other{{shown} items cleared}}'**
  String groceriesClearedCount(int count, String shown);

  /// GRO-5. View toggle.
  ///
  /// In en, this message translates to:
  /// **'By aisle'**
  String get groceriesByAisle;

  /// GRO-5. View toggle.
  ///
  /// In en, this message translates to:
  /// **'By recipe'**
  String get groceriesByRecipe;

  /// GRO-5. Group heading in the By recipe view for typed-in items.
  ///
  /// In en, this message translates to:
  /// **'Added by you'**
  String get groceriesHandAdded;

  /// No description provided for @groceriesRecipeRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed \"{title}\"\'s ingredients'**
  String groceriesRecipeRemoved(String title);

  /// GRO-4. Title of the sheet opened by a long press on an item.
  ///
  /// In en, this message translates to:
  /// **'Move to aisle'**
  String get groceriesMoveToAisle;

  /// GRO-6. App-bar action tooltip.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get groceriesShareTooltip;

  /// GRO-6. The title line of the shared text.
  ///
  /// In en, this message translates to:
  /// **'Grocery list'**
  String get groceriesShareTitle;

  /// GRO-5. The recipes an item's amounts came from, on a second line.
  ///
  /// In en, this message translates to:
  /// **'From: {names}'**
  String groceriesFrom(String names);

  /// No description provided for @groceriesNameSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get groceriesNameSeparator;

  /// GRO-2. Snackbar after adding a recipe's ticked lines to groceries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 ingredient added} other{{shown} ingredients added}}'**
  String groceriesAddedCount(int count, String shown);

  /// PLAN-5. Marker on an entry already sent to groceries.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get planGroceriesAlreadyAdded;

  /// PLAN-5. Shown in the add-to-groceries sheet when the week has no recipe entries.
  ///
  /// In en, this message translates to:
  /// **'No meals from today in these days'**
  String get planGroceriesEmpty;

  /// PLAN-5. Snackbar after adding the week's ticked entries to groceries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to add} =1{1 meal added to groceries} other{{shown} meals added to groceries}}'**
  String planGroceriesAddedCount(int count, String shown);
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
