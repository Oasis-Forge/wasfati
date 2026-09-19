// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'وصفاتي';

  @override
  String get recipesEmptyTitle => 'لا توجد وصفات بعد';

  @override
  String get recipesEmptyBody =>
      'شارك وصفة من تيك توك أو إنستغرام أو يوتيوب، أو أضف وصفتك.';

  @override
  String get recipesAdd => 'أضف وصفة';

  @override
  String recipesCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown وصفة',
      many: '$shown وصفة',
      few: '$shown وصفات',
      two: 'وصفتان',
      one: 'وصفة واحدة',
      zero: 'لا توجد وصفات',
    );
    return '$_temp0';
  }

  @override
  String get errorSaveFailed => 'تعذّر الحفظ. لم تضِع تعديلاتك، حاول مرة أخرى.';

  @override
  String get deletedSnack => 'حُذفت الوصفة';

  @override
  String get undo => 'تراجع';

  @override
  String minutes(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown دقيقة',
      many: '$shown دقيقة',
      few: '$shown دقائق',
      two: 'دقيقتان',
      one: 'دقيقة',
    );
    return '$_temp0';
  }

  @override
  String servings(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown حصة',
      many: '$shown حصة',
      few: '$shown حصص',
      two: 'حصتان',
      one: 'حصة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get prepTime => 'التحضير';

  @override
  String get cookTime => 'الطبخ';

  @override
  String get ingredients => 'المكونات';

  @override
  String get steps => 'طريقة التحضير';

  @override
  String get notes => 'ملاحظات';

  @override
  String sourceFrom(String site) {
    return 'من $site';
  }

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String get save => 'حفظ';

  @override
  String get newRecipe => 'وصفة جديدة';

  @override
  String get editRecipe => 'تعديل الوصفة';

  @override
  String get fieldTitle => 'اسم الوصفة';

  @override
  String get fieldTitleRequired => 'اكتب اسم الوصفة';

  @override
  String get fieldServings => 'عدد الحصص';

  @override
  String get fieldServingsInvalid => 'من 1 إلى 100';

  @override
  String get fieldPrep => 'التحضير (دقيقة)';

  @override
  String get fieldCook => 'الطبخ (دقيقة)';

  @override
  String get fieldIngredientsHint =>
      'مكوّن في كل سطر، مثل: ٢ كوب أرز\nالسطر الذي ينتهي بنقطتين يبدأ مجموعة، مثل: للصلصة:';

  @override
  String get fieldStepsHint => 'خطوة في كل سطر';

  @override
  String get fieldNumberInvalid => 'أرقام فقط';

  @override
  String get stepTooLong => 'إحدى الخطوات أطول من ٢٠٠٠ حرف';

  @override
  String get photoAdd => 'أضف صورة';

  @override
  String get photoRemove => 'احذف الصورة';

  @override
  String get discardTitle => 'تجاهل التعديلات؟';

  @override
  String get discard => 'تجاهل';

  @override
  String get keepEditing => 'متابعة التعديل';

  @override
  String get recipeMissing => 'لم تعد هذه الوصفة موجودة.';

  @override
  String get settings => 'الإعدادات';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get languageSystem => 'لغة الجهاز';

  @override
  String get settingsDigits => 'الأرقام';

  @override
  String get settingsUnits => 'الوحدات';

  @override
  String get unitsMetric => 'مترية (غرام، مل)';

  @override
  String get unitsKitchen => 'أكواب وملاعق';

  @override
  String get settingsWeekStart => 'بداية الأسبوع';

  @override
  String get weekStartAuto => 'حسب المنطقة';

  @override
  String get saturday => 'السبت';

  @override
  String get sunday => 'الأحد';

  @override
  String get monday => 'الاثنين';

  @override
  String get settingsTheme => 'المظهر';

  @override
  String get themeSystem => 'حسب الجهاز';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';
}
