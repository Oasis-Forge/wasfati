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

  /// RUN-3. The setup page's heading, on the first launch.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Wasfati'**
  String get setupTitle;

  /// RUN-3. Under the setup page's heading.
  ///
  /// In en, this message translates to:
  /// **'Two quick choices. You can change both later in Settings.'**
  String get setupBody;

  /// RUN-3. Setup page button; opens the walkthrough.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get setupContinue;

  /// RUN-4. On every walkthrough page; ends the walkthrough.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get walkthroughSkip;

  /// RUN-4. Moves to the next walkthrough page.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get walkthroughNext;

  /// RUN-4. The last walkthrough page's button; opens the library.
  ///
  /// In en, this message translates to:
  /// **'Go to my recipes'**
  String get walkthroughStart;

  /// RUN-4. Screen-reader label of the walkthrough's page dots.
  ///
  /// In en, this message translates to:
  /// **'Page {n} of {total}'**
  String walkthroughPageOf(String n, String total);

  /// RUN-4. Walkthrough page 1 heading: importing.
  ///
  /// In en, this message translates to:
  /// **'Save recipes from any post'**
  String get walkthroughImportTitle;

  /// RUN-4. Walkthrough page 1 text.
  ///
  /// In en, this message translates to:
  /// **'Share a post from TikTok, Instagram or YouTube, a recipe site or a photo. Wasfati turns it into a clean recipe you check before saving.'**
  String get walkthroughImportBody;

  /// RUN-4. Walkthrough page 2 heading: scaling.
  ///
  /// In en, this message translates to:
  /// **'Amounts that scale, in proper Arabic'**
  String get walkthroughScaleTitle;

  /// RUN-4. Walkthrough page 2 text.
  ///
  /// In en, this message translates to:
  /// **'Change the servings and every amount follows: fractions stay readable, and Arabic units agree with the number.'**
  String get walkthroughScaleBody;

  /// RUN-4. Walkthrough page 3 heading: cook mode.
  ///
  /// In en, this message translates to:
  /// **'Cook one step at a time'**
  String get walkthroughCookTitle;

  /// RUN-4. Walkthrough page 3 text.
  ///
  /// In en, this message translates to:
  /// **'Big text, one step per page, timers straight from the step, and the screen stays on.'**
  String get walkthroughCookBody;

  /// RUN-4. Walkthrough page 4 heading: plan and groceries.
  ///
  /// In en, this message translates to:
  /// **'Plan the week, shop from one list'**
  String get walkthroughPlanTitle;

  /// RUN-4. Walkthrough page 4 text.
  ///
  /// In en, this message translates to:
  /// **'Put recipes on your days, then add them to one grocery list, sorted by aisle and ready to share.'**
  String get walkthroughPlanBody;

  /// RUN-4. The made-up recipe the walkthrough's drawings show.
  ///
  /// In en, this message translates to:
  /// **'Chicken kabsa'**
  String get walkthroughDemoRecipe;

  /// RUN-4. A demo ingredient line; the app parses and doubles it, so keep an amount and a unit.
  ///
  /// In en, this message translates to:
  /// **'1½ cups rice'**
  String get walkthroughDemoLine1;

  /// RUN-4. A demo ingredient line; the app parses and doubles it, so keep an amount and a unit.
  ///
  /// In en, this message translates to:
  /// **'2 tbsp olive oil'**
  String get walkthroughDemoLine2;

  /// RUN-4. A demo grocery item, shown ticked off.
  ///
  /// In en, this message translates to:
  /// **'1 onion'**
  String get walkthroughDemoLine3;

  /// RUN-4. A demo cook-mode step; keep the time, the app reads a timer from it.
  ///
  /// In en, this message translates to:
  /// **'Cover and simmer for 25 minutes.'**
  String get walkthroughDemoStep;

  /// RUN-4. Settings row that replays the first-run walkthrough.
  ///
  /// In en, this message translates to:
  /// **'Show the walkthrough again'**
  String get settingsReplayWalkthrough;

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

  /// SHARE-1. Recipe page app-bar action, opening the share sheet.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareTooltip;

  /// SHARE-1. Share-sheet option: plain text.
  ///
  /// In en, this message translates to:
  /// **'As text'**
  String get shareAsText;

  /// SHARE-1. Share-sheet option: portrait picture pages.
  ///
  /// In en, this message translates to:
  /// **'As images'**
  String get shareAsImages;

  /// SHARE-2. Ingredients heading in the shared recipe text and images, distinct from the on-screen heading ("ingredients").
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get shareHeadingIngredients;

  /// SHARE-2. Steps heading in the shared recipe text and images, distinct from the on-screen heading ("steps").
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get shareHeadingSteps;

  /// SHARE-2. The shared recipe's source line, when it has one.
  ///
  /// In en, this message translates to:
  /// **'Source: {url}'**
  String shareSource(String url);

  /// SHARE-2. The last line of a shared recipe text, right before the Play Store link.
  ///
  /// In en, this message translates to:
  /// **'From the Wasfati app'**
  String get shareFooterLine;

  /// SHARE-1. Progress label while the share-as-images pages render.
  ///
  /// In en, this message translates to:
  /// **'Creating images…'**
  String get shareRendering;

  /// SHARE-3. Shown when a recipe would need more than 6 image pages.
  ///
  /// In en, this message translates to:
  /// **'This recipe is too long to share as images. Share it as text instead.'**
  String get shareTooLong;

  /// SHARE-3. Shown when share-as-images fails unexpectedly (not the too-long case).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the images. Try again.'**
  String get shareFailed;

  /// SHARE-1, SCALE-6. Marks a shared line (text or image) the scaler couldn't change, matching the recipe page's own "not scaled" mark.
  ///
  /// In en, this message translates to:
  /// **'{line} ({mark})'**
  String shareUnscaledLine(String line, String mark);

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

  /// LOOK-1: the Settings row title for picking a look (Ink/Saffron), placed next to the theme (light/dark) row.
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get settingsLook;

  /// LOOK-1: the Ink look's option label in the Look row.
  ///
  /// In en, this message translates to:
  /// **'Ink'**
  String get lookInk;

  /// LOOK-1: the Saffron look's option label in the Look row.
  ///
  /// In en, this message translates to:
  /// **'Saffron'**
  String get lookSaffron;

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

  /// IMP-8: a quiet action in the import preview (IMP-5).
  ///
  /// In en, this message translates to:
  /// **'Report a mistake'**
  String get reportMistake;

  /// IMP-8, Decision 19: what a report holds, for an import with a source link.
  ///
  /// In en, this message translates to:
  /// **'Your mail app opens with just the source link and your note. You send it.'**
  String get reportMistakeExplainLink;

  /// IMP-8, Decision 19: what a report holds, for an import with no link (a photo or pasted text).
  ///
  /// In en, this message translates to:
  /// **'Your mail app opens with just your note. You send it.'**
  String get reportMistakeExplainNoLink;

  /// IMP-8: the optional note field in the report dialog.
  ///
  /// In en, this message translates to:
  /// **'What\'s wrong? (optional)'**
  String get reportMistakeNoteHint;

  /// IMP-8: opens the user's mail app with the report draft.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get reportMistakeSend;

  /// IMP-8, Decision 19: the subject line of the report mail draft.
  ///
  /// In en, this message translates to:
  /// **'Wasfati: a mistake in an imported recipe'**
  String get reportMistakeSubject;

  /// IMP-8: no app could open the report draft. {email} is the support address.
  ///
  /// In en, this message translates to:
  /// **'No mail app on this device. Write to us at {email}'**
  String reportMistakeNoMailApp(String email);

  /// IMP-7: the always-visible quota counter, with the reset date.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {quota} AI imports left this month · resets on the 1st'**
  String aiImportsLeftLine(String shown, String quota);

  /// IMP-7: shown instead of aiImportsLeftLine once the quota runs out.
  ///
  /// In en, this message translates to:
  /// **'No AI imports left this month · resets on the 1st. Website imports still work, free.'**
  String get aiImportsOutLine;

  /// PAY-5, IMP-7: the one line under the quota once the free AI imports run out. Opens the purchase screen.
  ///
  /// In en, this message translates to:
  /// **'More AI imports with Premium'**
  String get aiImportsPremiumLine;

  /// IMP-3: shown before an import is sent to the AI server, next to the progress indicator.
  ///
  /// In en, this message translates to:
  /// **'Uses one AI import · {shown} of {quota} left'**
  String aiImportCostLine(String shown, String quota);

  /// IMP-4: the progress message while Importer.fromAi is in flight.
  ///
  /// In en, this message translates to:
  /// **'Importing with AI…'**
  String get aiImportSending;

  /// IMP-4: shown once the 45-second keep-waiting prompt appears during an AI import.
  ///
  /// In en, this message translates to:
  /// **'This is taking longer than usual.'**
  String get aiImportKeepWaitingLine;

  /// IMP-4: the button that dismisses the keep-waiting prompt without cancelling the import.
  ///
  /// In en, this message translates to:
  /// **'Keep waiting'**
  String get aiImportKeepWaitingAction;

  /// SRV-7 400 bad_request.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong with this request. Try again.'**
  String get aiImportErrorBadRequest;

  /// SRV-7 403 invalid_integrity_token.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t verify this device. Try again later.'**
  String get aiImportErrorInvalidToken;

  /// SRV-7 422 unreachable; also the reason line above IMP-12's paste fallback.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this link\'s content.'**
  String get aiImportErrorUnreachable;

  /// SRV-7 422 private_post: a platform the server can't read at all (Instagram always, Decision 8); also the reason line above IMP-12's paste fallback.
  ///
  /// In en, this message translates to:
  /// **'This account or post is private, so its content can\'t be read.'**
  String get aiImportErrorPrivatePost;

  /// SRV-7 422 not_a_recipe.
  ///
  /// In en, this message translates to:
  /// **'No recipe was found in this content. You can add it by hand.'**
  String get aiImportErrorNotARecipe;

  /// SRV-7 429 limit_reached (IMP-7): the server's own confirmation that the quota is out.
  ///
  /// In en, this message translates to:
  /// **'No AI imports left this month. Website imports still work, free.'**
  String get aiImportErrorLimitReached;

  /// SRV-7 503 busy (SRV-6's spending cap or load).
  ///
  /// In en, this message translates to:
  /// **'AI import is busy right now. Try again later.'**
  String get aiImportErrorBusy;

  /// SRV-7 503 misconfigured.
  ///
  /// In en, this message translates to:
  /// **'AI import isn\'t available right now. Try again later.'**
  String get aiImportErrorMisconfigured;

  /// An error code this build doesn't recognize yet.
  ///
  /// In en, this message translates to:
  /// **'Something unexpected happened. Try again.'**
  String get aiImportErrorUnknown;

  /// The request never reached the server, or its answer couldn't be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect. Check your internet and try again.'**
  String get aiImportErrorNetwork;

  /// SRV-7: the server answered 413 too_large to a photo import.
  ///
  /// In en, this message translates to:
  /// **'These photos are too large to send. Try fewer photos.'**
  String get aiImportErrorTooLarge;

  /// IMP-10: the device couldn't read a picked photo to resize it, so nothing was sent.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this photo. Try another one.'**
  String get aiImportErrorUnreadablePhoto;

  /// IMP-12: the text box in the paste-caption fallback.
  ///
  /// In en, this message translates to:
  /// **'Paste the recipe\'s text or caption here'**
  String get aiImportPasteHint;

  /// IMP-1, IMP-10: above the photo import buttons on the import screen. {max} is the most photos one import can send (4), already in the chosen digit style.
  ///
  /// In en, this message translates to:
  /// **'Or from a photo: a cookbook page or a handwritten recipe, up to {max} photos.'**
  String importPhotoExplain(String max);

  /// IMP-1: opens the system camera for a photo import.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get importPhotoCamera;

  /// IMP-1: opens the system photo picker for a photo import (up to 4).
  ///
  /// In en, this message translates to:
  /// **'Choose photos'**
  String get importPhotoGallery;

  /// IMP-1: takes another camera photo for the same recipe, before sending.
  ///
  /// In en, this message translates to:
  /// **'Add a page'**
  String get importPhotoAddPage;

  /// IMP-1: how many photos are about to be sent, next to their thumbnails.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{shown} photos}}'**
  String importPhotoCount(int count, String shown);

  /// IMP-1: the system picker returned more photos than one import can send.
  ///
  /// In en, this message translates to:
  /// **'Only the first {max} photos are used.'**
  String importPhotoFirstOnly(String max);

  /// IMP-12: in the fallback for a post whose caption can't be read, opens the photo picker for a screenshot of the post.
  ///
  /// In en, this message translates to:
  /// **'Or a screenshot'**
  String get aiImportScreenshotAction;

  /// IMP-14: the button on a recipe, or an import preview, written mostly in another language. It always names the app's own language.
  ///
  /// In en, this message translates to:
  /// **'Translate to English'**
  String get translateRecipe;

  /// IMP-16: the confirm button under the cost line, before a recipe's words are sent for translation.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translateConfirm;

  /// IMP-14: shown while the translation is on its way back.
  ///
  /// In en, this message translates to:
  /// **'Translating…'**
  String get translateSending;

  /// IMP-15: the translation changed a number or a timer in some lines or steps, so those kept their original text.
  ///
  /// In en, this message translates to:
  /// **'Some lines kept their original text so their numbers stay right.'**
  String get translateKeptOriginal;

  /// IMP-15, SRV-7: an ID sent for translation didn't come back exactly once, so nothing changed and no AI import was used.
  ///
  /// In en, this message translates to:
  /// **'The translation came back incomplete, and nothing was counted. Try again.'**
  String get translateErrorIncomplete;

  /// SRV-11: the recipe has more than 300 pieces of text or 20,000 characters.
  ///
  /// In en, this message translates to:
  /// **'This recipe is too long to translate in one go.'**
  String get translateErrorTooLarge;

  /// IMP-14: on a translated copy, a link to the recipe it was translated from.
  ///
  /// In en, this message translates to:
  /// **'Translated from: {title}'**
  String translatedFromLine(String title);

  /// IMP-14: on a recipe that was translated, a link to its translated copy.
  ///
  /// In en, this message translates to:
  /// **'Translation: {title}'**
  String translationLine(String title);

  /// A button that sends the same request again, costing nothing (SRV-7).
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

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

  /// RAM-4. The plan's week/Ramadan view toggle: the week side.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get planViewWeek;

  /// RAM-4. The plan's week/Ramadan view toggle: the whole-month side.
  ///
  /// In en, this message translates to:
  /// **'Ramadan'**
  String get planViewRamadan;

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

  /// RAM-1. Meal slot name: the pre-dawn meal in Ramadan.
  ///
  /// In en, this message translates to:
  /// **'Suhoor'**
  String get mealSuhoor;

  /// RAM-1. Meal slot name: the sunset meal in Ramadan.
  ///
  /// In en, this message translates to:
  /// **'Iftar'**
  String get mealIftar;

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

  /// RAM-3. The plan's card, 7 days before Ramadan through the day before it starts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Ramadan starts in 1 day. Switch the plan to suhoor and iftar?} other{Ramadan starts in {shown} days. Switch the plan to suhoor and iftar?}}'**
  String ramadanCardSoon(int count, String shown);

  /// RAM-3. The plan's card, once Ramadan has started.
  ///
  /// In en, this message translates to:
  /// **'Ramadan kareem. Switch the plan to suhoor and iftar?'**
  String get ramadanCardNow;

  /// RAM-3. The card's button that turns Ramadan mode on.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get ramadanCardEnable;

  /// RAM-3. The card's button that hides it until the next Ramadan.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get ramadanCardNotNow;

  /// RAM-2. A Ramadan day's Hijri date, shown beside the usual one.
  ///
  /// In en, this message translates to:
  /// **'{day} Ramadan'**
  String ramadanDayLabel(String day);

  /// RAM-2. Shown on the day after Ramadan's last one.
  ///
  /// In en, this message translates to:
  /// **'Eid al-Fitr'**
  String get ramadanEidLabel;

  /// RAM-1. Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'Ramadan'**
  String get settingsRamadanSection;

  /// No description provided for @settingsBackupSection.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackupSection;

  /// No description provided for @backupSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save a backup'**
  String get backupSaveAction;

  /// No description provided for @backupSaveDone.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupSaveDone;

  /// BAK-6. Shown when saving a backup fails (the save dialog itself, or building the file).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the backup.'**
  String get backupSaveFailed;

  /// BAK-6. Shown when sharing a backup fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share the backup.'**
  String get backupShareFailed;

  /// No description provided for @backupShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share the backup'**
  String get backupShareAction;

  /// No description provided for @backupRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestoreAction;

  /// BAK-7. Shown when the system's file picker itself fails to hand back the picked file (distinct from the user cancelling, and from backupErrorDamaged for a file that opens but isn't a usable backup).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open that file.'**
  String get backupErrorCantOpen;

  /// No description provided for @backupExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export as text'**
  String get backupExportAction;

  /// No description provided for @backupReminderSwitch.
  ///
  /// In en, this message translates to:
  /// **'Backup reminder'**
  String get backupReminderSwitch;

  /// No description provided for @backupAutoSection.
  ///
  /// In en, this message translates to:
  /// **'Automatic backups'**
  String get backupAutoSection;

  /// No description provided for @backupAutoEmpty.
  ///
  /// In en, this message translates to:
  /// **'No automatic backups yet'**
  String get backupAutoEmpty;

  /// BAK-2, BAK-7. One automatic backup's label in Settings, next to its restore action. Includes the time, since a restore makes a new one at once and same-day rows would otherwise read identically.
  ///
  /// In en, this message translates to:
  /// **'Backup from {date}, {time}'**
  String backupAutoBackupDate(String date, String time);

  /// BAK-7. Heading of the sheet shown before a restore, above the counts and Merge/Replace.
  ///
  /// In en, this message translates to:
  /// **'What this file holds'**
  String get backupPreviewTitle;

  /// BAK-7. Recipe count in the restore preview sheet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No recipes} =1{1 recipe} other{{shown} recipes}}'**
  String backupPreviewRecipes(int count, String shown);

  /// BAK-7. Cookbook count in the restore preview sheet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No cookbooks} =1{1 cookbook} other{{shown} cookbooks}}'**
  String backupPreviewCookbooks(int count, String shown);

  /// BAK-7. Distinct plan weeks in the restore preview sheet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No plan weeks} =1{1 plan week} other{{shown} plan weeks}}'**
  String backupPreviewWeeks(int count, String shown);

  /// BAK-7. Grocery item count in the restore preview sheet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No grocery items} =1{1 grocery item} other{{shown} grocery items}}'**
  String backupPreviewGroceryItems(int count, String shown);

  /// No description provided for @backupMergeAction.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get backupMergeAction;

  /// No description provided for @backupReplaceAction.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get backupReplaceAction;

  /// No description provided for @backupReplaceConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace everything?'**
  String get backupReplaceConfirmTitle;

  /// BAK-7. Body of the first Replace-confirmation dialog: what will be lost, with this phone's own live recipe count (must-fix, platform review — this used to be a fixed string with no numbers).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{This replaces the plan and grocery list on this phone with the file\'s.} =1{This deletes the recipe on this phone, plus the plan and grocery list, and replaces them with the file\'s.} other{This deletes the {shown} recipes on this phone, plus the plan and grocery list, and replaces them with the file\'s.}} An automatic copy of what\'s here now is saved first.'**
  String backupReplaceConfirmBody(int count, String shown);

  /// BAK-7. Title of the second, final Replace-confirmation dialog (must-fix, platform review: Replace used to be confirmed only once).
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get backupReplaceConfirmFinalTitle;

  /// BAK-7. Body of the second, final Replace-confirmation dialog, whose button is styled as destructive.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone from here, except by restoring the automatic copy just saved.'**
  String get backupReplaceConfirmFinalBody;

  /// No description provided for @backupResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore complete'**
  String get backupResultTitle;

  /// BAK-3. Counts after a restore, already in the user's digit style. Recipes, cookbooks, plan entries and grocery items only (DEL-1, should-fix: this used to sum every table, including sections/lines/steps/links, so restoring one recipe could read as "added 14").
  ///
  /// In en, this message translates to:
  /// **'Added {added} · Updated {updated} · Unchanged {unchanged}'**
  String backupResultSummary(String added, String updated, String unchanged);

  /// No description provided for @backupErrorNotWasfati.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a Wasfati backup file.'**
  String get backupErrorNotWasfati;

  /// No description provided for @backupErrorDamaged.
  ///
  /// In en, this message translates to:
  /// **'This file is damaged.'**
  String get backupErrorDamaged;

  /// No description provided for @backupErrorNewerSchema.
  ///
  /// In en, this message translates to:
  /// **'This backup is from a newer version of the app. Update the app first.'**
  String get backupErrorNewerSchema;

  /// No description provided for @backupErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'The restore failed.'**
  String get backupErrorGeneric;

  /// No description provided for @backupExportPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Export recipes'**
  String get backupExportPickTitle;

  /// No description provided for @backupExportAll.
  ///
  /// In en, this message translates to:
  /// **'All recipes'**
  String get backupExportAll;

  /// No description provided for @backupExportDone.
  ///
  /// In en, this message translates to:
  /// **'Export saved'**
  String get backupExportDone;

  /// BAK-10. Shown when saving the exported text fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the export.'**
  String get backupExportFailed;

  /// BAK-8. The library's reminder card when no backup was ever made.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t saved a backup yet'**
  String get backupReminderNever;

  /// BAK-8. The library's reminder card, days since the last backup.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Last backup was 1 day ago} other{Last backup was {shown} days ago}}'**
  String backupReminderDaysAgo(int count, String shown);

  /// No description provided for @backupReminderNowAction.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupReminderNowAction;

  /// No description provided for @backupReminderLaterAction.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get backupReminderLaterAction;

  /// RAM-1. Settings switch that turns Ramadan mode on or off.
  ///
  /// In en, this message translates to:
  /// **'Ramadan mode'**
  String get ramadanModeLabel;

  /// RAM-2. Settings row showing the current or next Ramadan's first day.
  ///
  /// In en, this message translates to:
  /// **'Ramadan starts: {date}'**
  String ramadanStartLabel(String date);

  /// RAM-2. Tooltip: moves Ramadan's first day a day earlier, for the local moon sighting.
  ///
  /// In en, this message translates to:
  /// **'One day earlier'**
  String get ramadanShiftEarlier;

  /// RAM-2. Tooltip: moves Ramadan's first day a day later, for the local moon sighting.
  ///
  /// In en, this message translates to:
  /// **'One day later'**
  String get ramadanShiftLater;

  /// PAY-5: the one small target on the ad slot, above the banner. Opens the purchase screen.
  ///
  /// In en, this message translates to:
  /// **'Remove ads'**
  String get adSlotRemoveAds;

  /// PAY-10: the purchase screen's title; also the Settings subscription row's value when both are owned.
  ///
  /// In en, this message translates to:
  /// **'Pro and Premium'**
  String get purchaseTitle;

  /// PAY-10: tooltip of the purchase screen's close button, there from the first frame.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get purchaseClose;

  /// PAY-4, PAY-10: the purchase screen's first line.
  ///
  /// In en, this message translates to:
  /// **'Everything in Wasfati stays free. Pro removes the ads. Premium removes them too, and gives you more AI imports.'**
  String get purchaseLead;

  /// PAY-1: the one-time product's name.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get purchasePro;

  /// PAY-1: the subscription's name.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get purchasePremium;

  /// No description provided for @purchaseProKind.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase'**
  String get purchaseProKind;

  /// No description provided for @purchasePremiumKind.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get purchasePremiumKind;

  /// PAY-7: what Pro and Premium include.
  ///
  /// In en, this message translates to:
  /// **'No ads'**
  String get purchaseNoAds;

  /// PAY-7: AI imports a month with Pro (10) or Premium (100).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 AI import a month} other{{shown} AI imports a month}}'**
  String purchaseAiImports(int count, String shown);

  /// PAY-7, SRV-4: Premium's 100 AI imports are fair use.
  ///
  /// In en, this message translates to:
  /// **'Fair use'**
  String get purchaseFairUse;

  /// PAY-7, PAY-10: shown on a product this store account already owns.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get purchaseOwned;

  /// PAY-2, PAY-10: Pro's buy button; price is the store's own formatted price.
  ///
  /// In en, this message translates to:
  /// **'{price} once'**
  String purchasePriceOnce(String price);

  /// PAY-2, PAY-8: Premium's monthly plan button; price is the store's own formatted price.
  ///
  /// In en, this message translates to:
  /// **'{price} a month'**
  String purchasePriceMonthly(String price);

  /// PAY-2, PAY-8: Premium's yearly plan button; price is the store's own formatted price.
  ///
  /// In en, this message translates to:
  /// **'{price} a year'**
  String purchasePriceYearly(String price);

  /// PAY-3: a product the store doesn't sell yet: no price, no button.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get purchaseComingSoon;

  /// PAY-6: the store has no product configured, or can't sell on this device.
  ///
  /// In en, this message translates to:
  /// **'Nothing is for sale yet.'**
  String get purchaseNothingYet;

  /// PAY-1, PAY-10: next to the prices. In Arabic, avoid المشتريات: it names the grocery list.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get purchaseRestore;

  /// No description provided for @purchaseRestored.
  ///
  /// In en, this message translates to:
  /// **'Your purchases are restored.'**
  String get purchaseRestored;

  /// No description provided for @purchaseNothingToRestore.
  ///
  /// In en, this message translates to:
  /// **'This Google account has no Wasfati purchases.'**
  String get purchaseNothingToRestore;

  /// No description provided for @purchaseStoreUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Google Play. Try again later.'**
  String get purchaseStoreUnreachable;

  /// PAY-6: a purchase the store reports as pending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Google Play to confirm the payment. Nothing changes until it does.'**
  String get purchasePending;

  /// PAY-6: the store reported an error for the last purchase.
  ///
  /// In en, this message translates to:
  /// **'The purchase didn\'t go through.'**
  String get purchaseFailed;

  /// PAY-10, PAY-11: that Premium renews until cancelled, and where to cancel.
  ///
  /// In en, this message translates to:
  /// **'Premium renews automatically until you cancel it. Cancel any time: Settings › Manage or cancel opens it in Google Play.'**
  String get purchasePremiumRenews;

  /// PAY-11: opens Google Play's page for the subscription.
  ///
  /// In en, this message translates to:
  /// **'Manage or cancel'**
  String get purchaseManage;

  /// No description provided for @purchaseManageFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open Google Play.'**
  String get purchaseManageFailed;

  /// PAY-11, ADS-5: the Settings section heading. In Arabic, avoid المشتريات: it names the grocery list.
  ///
  /// In en, this message translates to:
  /// **'Ads and subscription'**
  String get settingsPayingSection;

  /// PAY-5, PAY-11: the Settings row; its value is the plan. Opens the purchase screen.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get settingsSubscription;

  /// PAY-11: the Settings subscription row's value when nothing is owned.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get tierFree;

  /// ADS-5: opens the ad network's own consent form, where the law asks for one.
  ///
  /// In en, this message translates to:
  /// **'Ad privacy choices'**
  String get settingsAdPrivacy;
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
