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
  String recipesCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown recipes',
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

  @override
  String minutes(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String servings(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown servings',
      one: '1 serving',
    );
    return '$_temp0';
  }

  @override
  String get prepTime => 'Prep';

  @override
  String get cookTime => 'Cook';

  @override
  String get ingredients => 'Ingredients';

  @override
  String get steps => 'Steps';

  @override
  String get notes => 'Notes';

  @override
  String sourceFrom(String site) {
    return 'From $site';
  }

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get shareTooltip => 'Share';

  @override
  String get shareAsText => 'As text';

  @override
  String get shareAsImages => 'As images';

  @override
  String get shareHeadingIngredients => 'Ingredients';

  @override
  String get shareHeadingSteps => 'Method';

  @override
  String shareSource(String url) {
    return 'Source: $url';
  }

  @override
  String get shareFooterLine => 'From the Wasfati app';

  @override
  String get shareRendering => 'Creating images…';

  @override
  String get shareTooLong =>
      'This recipe is too long to share as images. Share it as text instead.';

  @override
  String get shareFailed => 'Couldn\'t create the images. Try again.';

  @override
  String shareUnscaledLine(String line, String mark) {
    return '$line ($mark)';
  }

  @override
  String get save => 'Save';

  @override
  String get newRecipe => 'New recipe';

  @override
  String get editRecipe => 'Edit recipe';

  @override
  String get fieldTitle => 'Title';

  @override
  String get fieldTitleRequired => 'Give the recipe a name';

  @override
  String get fieldServings => 'Servings';

  @override
  String get fieldServingsInvalid => '1 to 100';

  @override
  String get fieldPrep => 'Prep (min)';

  @override
  String get fieldCook => 'Cook (min)';

  @override
  String get fieldIngredientsHint =>
      'One ingredient per line, e.g. 2 cups rice\nA line ending with : starts a group, e.g. For the sauce:';

  @override
  String get fieldStepsHint => 'One step per line';

  @override
  String get fieldNumberInvalid => 'Numbers only';

  @override
  String get stepTooLong => 'A step is longer than 2,000 characters';

  @override
  String get photoAdd => 'Add photo';

  @override
  String get photoRemove => 'Remove photo';

  @override
  String get discardTitle => 'Discard changes?';

  @override
  String get discard => 'Discard';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get recipeMissing => 'This recipe is no longer here.';

  @override
  String get settings => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get settingsDigits => 'Numbers';

  @override
  String get settingsUnits => 'Units';

  @override
  String get unitsMetric => 'Metric (g, ml)';

  @override
  String get unitsKitchen => 'Cups and spoons';

  @override
  String get settingsWeekStart => 'Week starts on';

  @override
  String get weekStartAuto => 'By region';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get monday => 'Monday';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsLook => 'Look';

  @override
  String get lookInk => 'Ink';

  @override
  String get lookSaffron => 'Saffron';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get tabAllRecipes => 'All recipes';

  @override
  String get tabCookbooks => 'Cookbooks';

  @override
  String get searchHint => 'Search recipes or ingredients';

  @override
  String get searchClear => 'Clear search';

  @override
  String containsIngredient(String name) {
    return 'Contains: $name';
  }

  @override
  String get noResults => 'No recipes match';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get sortBy => 'Sort';

  @override
  String get sortRecent => 'Recently added';

  @override
  String get sortAz => 'A–Z';

  @override
  String get sortRecentlyCooked => 'Recently cooked';

  @override
  String get sortMostCooked => 'Most cooked';

  @override
  String get filterCookbook => 'Cookbook';

  @override
  String get filterTag => 'Tag';

  @override
  String get filterSource => 'Source';

  @override
  String get filterTime => 'Time';

  @override
  String get filterPhoto => 'Has photo';

  @override
  String get sourceWritten => 'Written by me';

  @override
  String get sourceWebsite => 'Website';

  @override
  String get sourceSocial => 'Social media';

  @override
  String get sourcePhoto => 'Photo';

  @override
  String get timeUnder30 => 'Under 30 min';

  @override
  String get time30to60 => '30–60 min';

  @override
  String get timeOver60 => 'Over 1 hour';

  @override
  String get any => 'Any';

  @override
  String get viewGrid => 'Grid view';

  @override
  String get viewList => 'List view';

  @override
  String get cookbookNew => 'New cookbook';

  @override
  String get cookbookName => 'Name';

  @override
  String get cookbookNameInvalid => '1 to 60 characters';

  @override
  String get cookbookRename => 'Rename';

  @override
  String get cookbookDelete => 'Delete cookbook';

  @override
  String get cookbookDeleteBody => 'The recipes stay in your library.';

  @override
  String cookbookRecipes(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown recipes',
      one: '1 recipe',
      zero: 'No recipes',
    );
    return '$_temp0';
  }

  @override
  String get cookbooksEmpty =>
      'Group recipes your way: Ramadan, quick dinners, family favourites.';

  @override
  String get cookbookEmpty =>
      'No recipes in this cookbook yet. Add them from a recipe\'s edit screen.';

  @override
  String get fieldTags => 'Tags';

  @override
  String get fieldTagsHint => 'Separate with commas, e.g. spicy, Ramadan';

  @override
  String get tagsInvalid => 'Up to 20 tags, 30 characters each';

  @override
  String get fieldCookbooks => 'Cookbooks';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get scaleReset => 'Reset';

  @override
  String get servingsLess => 'Fewer servings';

  @override
  String get servingsMore => 'More servings';

  @override
  String get notScaled => 'not scaled';

  @override
  String notScaledCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown ingredients weren\'t scaled',
      one: '1 ingredient wasn\'t scaled',
    );
    return '$_temp0';
  }

  @override
  String get viewAsWritten => 'As written';

  @override
  String get viewMetric => 'g / ml';

  @override
  String get viewKitchen => 'Cups';

  @override
  String get startCooking => 'Start cooking';

  @override
  String stepOf(String n, String total) {
    return 'Step $n of $total';
  }

  @override
  String stepN(String n) {
    return 'Step $n';
  }

  @override
  String get previousStep => 'Previous';

  @override
  String get nextStep => 'Next';

  @override
  String get closeCooking => 'Close cook mode';

  @override
  String get finishTitle => 'Enjoy your meal!';

  @override
  String get markCooked => 'Mark as cooked';

  @override
  String get markedCooked => 'Marked as cooked';

  @override
  String get done => 'Done';

  @override
  String timerStart(String time) {
    return 'Start a $time timer';
  }

  @override
  String get timerStop => 'Stop timer';

  @override
  String timerDone(String n) {
    return 'Timer done: step $n';
  }

  @override
  String get timerChannel => 'Cooking timers';

  @override
  String get alertsOff =>
      'Background timer alerts are off. Timers still ring while Wasfati is open.';

  @override
  String get dismiss => 'OK';

  @override
  String get importTitle => 'Import from a link';

  @override
  String get importHint => 'Paste a recipe link';

  @override
  String get importExplain =>
      'Recipes from sites like Fatafeat and Cookpad are read on your phone, free and unlimited.';

  @override
  String get paste => 'Paste';

  @override
  String get importAction => 'Import';

  @override
  String get importReading => 'Opening the page…';

  @override
  String get importUnderstanding => 'Reading the recipe…';

  @override
  String get importInvalidUrl => 'That doesn\'t look like a link.';

  @override
  String get importUnreachable =>
      'Couldn\'t open the page. Check the link and your connection.';

  @override
  String get importNoRecipe =>
      'Wasfati can\'t find recipe data on this page yet. You can still add it by hand.';

  @override
  String get addByHand => 'Add by hand';

  @override
  String get duplicateTitle => 'Already saved';

  @override
  String get duplicateBody => 'You saved a recipe from this page before.';

  @override
  String get openSaved => 'Open the saved one';

  @override
  String get importAgain => 'Import again';

  @override
  String get importedRecipe => 'Check and save';

  @override
  String get reportMistake => 'Report a mistake';

  @override
  String get reportMistakeExplainLink =>
      'Your mail app opens with just the source link and your note. You send it.';

  @override
  String get reportMistakeExplainNoLink =>
      'Your mail app opens with just your note. You send it.';

  @override
  String get reportMistakeNoteHint => 'What\'s wrong? (optional)';

  @override
  String get reportMistakeSend => 'Send';

  @override
  String get reportMistakeSubject => 'Wasfati: a mistake in an imported recipe';

  @override
  String reportMistakeNoMailApp(String email) {
    return 'No mail app on this device. Write to us at $email';
  }

  @override
  String aiImportsLeftLine(String shown, String quota) {
    return '$shown of $quota AI imports left this month · resets on the 1st';
  }

  @override
  String get aiImportsOutLine =>
      'No AI imports left this month · resets on the 1st. Website imports still work, free.';

  @override
  String aiImportCostLine(String shown, String quota) {
    return 'Uses one AI import · $shown of $quota left';
  }

  @override
  String get aiImportSending => 'Importing with AI…';

  @override
  String get aiImportKeepWaitingLine => 'This is taking longer than usual.';

  @override
  String get aiImportKeepWaitingAction => 'Keep waiting';

  @override
  String get aiImportErrorBadRequest =>
      'Something went wrong with this request. Try again.';

  @override
  String get aiImportErrorInvalidToken =>
      'Couldn\'t verify this device. Try again later.';

  @override
  String get aiImportErrorUnreachable => 'Couldn\'t read this link\'s content.';

  @override
  String get aiImportErrorPrivatePost =>
      'This account or post is private, so its content can\'t be read.';

  @override
  String get aiImportErrorNotARecipe =>
      'No recipe was found in this content. You can add it by hand.';

  @override
  String get aiImportErrorLimitReached =>
      'No AI imports left this month. Website imports still work, free.';

  @override
  String get aiImportErrorBusy =>
      'AI import is busy right now. Try again later.';

  @override
  String get aiImportErrorMisconfigured =>
      'AI import isn\'t available right now. Try again later.';

  @override
  String get aiImportErrorUnknown =>
      'Something unexpected happened. Try again.';

  @override
  String get aiImportErrorNetwork =>
      'Couldn\'t connect. Check your internet and try again.';

  @override
  String get aiImportErrorTooLarge =>
      'These photos are too large to send. Try fewer photos.';

  @override
  String get aiImportErrorUnreadablePhoto =>
      'Couldn\'t open this photo. Try another one.';

  @override
  String get aiImportPasteHint => 'Paste the recipe\'s text or caption here';

  @override
  String importPhotoExplain(String max) {
    return 'Or from a photo: a cookbook page or a handwritten recipe, up to $max photos.';
  }

  @override
  String get importPhotoCamera => 'Take a photo';

  @override
  String get importPhotoGallery => 'Choose photos';

  @override
  String get importPhotoAddPage => 'Add a page';

  @override
  String importPhotoCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String importPhotoFirstOnly(String max) {
    return 'Only the first $max photos are used.';
  }

  @override
  String get aiImportScreenshotAction => 'Or a screenshot';

  @override
  String get translateRecipe => 'Translate to English';

  @override
  String get translateConfirm => 'Translate';

  @override
  String get translateSending => 'Translating…';

  @override
  String get translateKeptOriginal =>
      'Some lines kept their original text so their numbers stay right.';

  @override
  String get translateErrorIncomplete =>
      'The translation came back incomplete, and nothing was counted. Try again.';

  @override
  String get translateErrorTooLarge =>
      'This recipe is too long to translate in one go.';

  @override
  String translatedFromLine(String title) {
    return 'Translated from: $title';
  }

  @override
  String translationLine(String title) {
    return 'Translation: $title';
  }

  @override
  String get tryAgain => 'Try again';

  @override
  String get planTitle => 'Plan';

  @override
  String get tabRecipes => 'Recipes';

  @override
  String get planThisWeek => 'This week';

  @override
  String get planViewWeek => 'Week';

  @override
  String get planViewRamadan => 'Ramadan';

  @override
  String get planPreviousWeek => 'Previous week';

  @override
  String get planNextWeek => 'Next week';

  @override
  String get planToday => 'Today';

  @override
  String get mealBreakfast => 'Breakfast';

  @override
  String get mealLunch => 'Lunch';

  @override
  String get mealDinner => 'Dinner';

  @override
  String get mealSnack => 'Snack';

  @override
  String get mealSuhoor => 'Suhoor';

  @override
  String get mealIftar => 'Iftar';

  @override
  String get planAdd => 'Add';

  @override
  String get planAddRecipe => 'Choose a recipe';

  @override
  String get planAddNote => 'Write a note';

  @override
  String get planNoteLabel => 'Note';

  @override
  String get planNoteHint => 'Eating out, leftovers…';

  @override
  String get planNoteInvalid => '1–60 characters';

  @override
  String get planAddToPlan => 'Add to plan';

  @override
  String get planAdded => 'Added to the plan';

  @override
  String get planChooseDay => 'Day';

  @override
  String get planChooseMeal => 'Meal';

  @override
  String get planAmount => 'Amount';

  @override
  String get planMove => 'Move';

  @override
  String get planCopy => 'Copy';

  @override
  String get planRemove => 'Remove';

  @override
  String get planRemoved => 'Removed from the plan';

  @override
  String get planClearWeek => 'Clear week';

  @override
  String planClearedCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown meals removed',
      one: '1 meal removed',
      zero: 'Nothing to clear',
    );
    return '$_temp0';
  }

  @override
  String get planSlotFull => 'A meal holds up to 10 entries';

  @override
  String get planEmptyTitle => 'Plan your week';

  @override
  String get planEmptyBody =>
      'Add a recipe to any meal, or write a note like “eating out”.';

  @override
  String planNextMeal(String day, String meal) {
    return 'In the plan: $day, $meal';
  }

  @override
  String get groceriesTitle => 'Groceries';

  @override
  String get addToGroceries => 'Add to groceries';

  @override
  String get groceriesAddHint => 'Add an item';

  @override
  String get groceriesEmptyTitle => 'Your grocery list is empty';

  @override
  String get groceriesEmptyBody =>
      'Type an item above, or add one from a recipe\'s page or the week\'s plan.';

  @override
  String get aisleProduce => 'Vegetables and fruit';

  @override
  String get aisleMeat => 'Meat and poultry';

  @override
  String get aisleFish => 'Fish and seafood';

  @override
  String get aisleDairy => 'Dairy, cheese and eggs';

  @override
  String get aisleBakery => 'Bread and bakery';

  @override
  String get aisleGrains => 'Rice, pasta and grains';

  @override
  String get aisleSpices => 'Spices';

  @override
  String get aislePantry => 'Oils, sauces and cans';

  @override
  String get aisleBaking => 'Baking and sweets';

  @override
  String get aisleFrozen => 'Frozen';

  @override
  String get aisleDrinks => 'Drinks';

  @override
  String get aisleOther => 'Other';

  @override
  String get groceriesDoneSection => 'Done';

  @override
  String get groceriesClearDone => 'Clear done';

  @override
  String get groceriesClearAll => 'Clear all';

  @override
  String groceriesClearedCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown items cleared',
      one: '1 item cleared',
      zero: 'Nothing to clear',
    );
    return '$_temp0';
  }

  @override
  String get groceriesByAisle => 'By aisle';

  @override
  String get groceriesByRecipe => 'By recipe';

  @override
  String get groceriesHandAdded => 'Added by you';

  @override
  String groceriesRecipeRemoved(String title) {
    return 'Removed \"$title\"\'s ingredients';
  }

  @override
  String get groceriesMoveToAisle => 'Move to aisle';

  @override
  String get groceriesShareTooltip => 'Share';

  @override
  String get groceriesShareTitle => 'Grocery list';

  @override
  String groceriesFrom(String names) {
    return 'From: $names';
  }

  @override
  String get groceriesNameSeparator => ', ';

  @override
  String groceriesAddedCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown ingredients added',
      one: '1 ingredient added',
    );
    return '$_temp0';
  }

  @override
  String get planGroceriesAlreadyAdded => 'Added';

  @override
  String get planGroceriesEmpty => 'No meals from today in these days';

  @override
  String planGroceriesAddedCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown meals added to groceries',
      one: '1 meal added to groceries',
      zero: 'Nothing to add',
    );
    return '$_temp0';
  }

  @override
  String ramadanCardSoon(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ramadan starts in $shown days. Switch the plan to suhoor and iftar?',
      one: 'Ramadan starts in 1 day. Switch the plan to suhoor and iftar?',
    );
    return '$_temp0';
  }

  @override
  String get ramadanCardNow =>
      'Ramadan kareem. Switch the plan to suhoor and iftar?';

  @override
  String get ramadanCardEnable => 'Enable';

  @override
  String get ramadanCardNotNow => 'Not now';

  @override
  String ramadanDayLabel(String day) {
    return '$day Ramadan';
  }

  @override
  String get ramadanEidLabel => 'Eid al-Fitr';

  @override
  String get settingsRamadanSection => 'Ramadan';

  @override
  String get settingsBackupSection => 'Backup';

  @override
  String get backupSaveAction => 'Save a backup';

  @override
  String get backupSaveDone => 'Backup saved';

  @override
  String get backupSaveFailed => 'Couldn\'t save the backup.';

  @override
  String get backupShareFailed => 'Couldn\'t share the backup.';

  @override
  String get backupShareAction => 'Share the backup';

  @override
  String get backupRestoreAction => 'Restore';

  @override
  String get backupErrorCantOpen => 'Couldn\'t open that file.';

  @override
  String get backupExportAction => 'Export as text';

  @override
  String get backupReminderSwitch => 'Backup reminder';

  @override
  String get backupAutoSection => 'Automatic backups';

  @override
  String get backupAutoEmpty => 'No automatic backups yet';

  @override
  String backupAutoBackupDate(String date, String time) {
    return 'Backup from $date, $time';
  }

  @override
  String get backupPreviewTitle => 'What this file holds';

  @override
  String backupPreviewRecipes(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown recipes',
      one: '1 recipe',
      zero: 'No recipes',
    );
    return '$_temp0';
  }

  @override
  String backupPreviewCookbooks(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown cookbooks',
      one: '1 cookbook',
      zero: 'No cookbooks',
    );
    return '$_temp0';
  }

  @override
  String backupPreviewWeeks(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown plan weeks',
      one: '1 plan week',
      zero: 'No plan weeks',
    );
    return '$_temp0';
  }

  @override
  String backupPreviewGroceryItems(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown grocery items',
      one: '1 grocery item',
      zero: 'No grocery items',
    );
    return '$_temp0';
  }

  @override
  String get backupMergeAction => 'Merge';

  @override
  String get backupReplaceAction => 'Replace';

  @override
  String get backupReplaceConfirmTitle => 'Replace everything?';

  @override
  String backupReplaceConfirmBody(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This deletes the $shown recipes on this phone, plus the plan and grocery list, and replaces them with the file\'s.',
      one: 'This deletes the recipe on this phone, plus the plan and grocery list, and replaces them with the file\'s.',
      zero: 'This replaces the plan and grocery list on this phone with the file\'s.',
    );
    return '$_temp0 An automatic copy of what\'s here now is saved first.';
  }

  @override
  String get backupReplaceConfirmFinalTitle => 'Are you sure?';

  @override
  String get backupReplaceConfirmFinalBody =>
      'This can\'t be undone from here, except by restoring the automatic copy just saved.';

  @override
  String get backupResultTitle => 'Restore complete';

  @override
  String backupResultSummary(String added, String updated, String unchanged) {
    return 'Added $added · Updated $updated · Unchanged $unchanged';
  }

  @override
  String get backupErrorNotWasfati => 'This isn\'t a Wasfati backup file.';

  @override
  String get backupErrorDamaged => 'This file is damaged.';

  @override
  String get backupErrorNewerSchema =>
      'This backup is from a newer version of the app. Update the app first.';

  @override
  String get backupErrorGeneric => 'The restore failed.';

  @override
  String get backupExportPickTitle => 'Export recipes';

  @override
  String get backupExportAll => 'All recipes';

  @override
  String get backupExportDone => 'Export saved';

  @override
  String get backupExportFailed => 'Couldn\'t save the export.';

  @override
  String get backupReminderNever => 'You haven\'t saved a backup yet';

  @override
  String backupReminderDaysAgo(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last backup was $shown days ago',
      one: 'Last backup was 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get backupReminderNowAction => 'Back up now';

  @override
  String get backupReminderLaterAction => 'Later';

  @override
  String get ramadanModeLabel => 'Ramadan mode';

  @override
  String ramadanStartLabel(String date) {
    return 'Ramadan starts: $date';
  }

  @override
  String get ramadanShiftEarlier => 'One day earlier';

  @override
  String get ramadanShiftLater => 'One day later';
}
