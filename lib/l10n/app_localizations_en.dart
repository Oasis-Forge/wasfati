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
}
