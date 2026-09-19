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
      'مكوّن في كل سطر، مثل: 2 كوب أرز\nالسطر الذي ينتهي بنقطتين يبدأ مجموعة، مثل: للصلصة:';

  @override
  String get fieldStepsHint => 'خطوة في كل سطر';

  @override
  String get fieldNumberInvalid => 'أرقام فقط';

  @override
  String get stepTooLong => 'إحدى الخطوات أطول من 2000 حرف';

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

  @override
  String get tabAllRecipes => 'كل الوصفات';

  @override
  String get tabCookbooks => 'كتب الطبخ';

  @override
  String get searchHint => 'ابحث عن وصفة أو مكوّن';

  @override
  String get searchClear => 'مسح البحث';

  @override
  String containsIngredient(String name) {
    return 'يحتوي: $name';
  }

  @override
  String get noResults => 'لا توجد وصفات مطابقة';

  @override
  String get clearFilters => 'مسح عوامل التصفية';

  @override
  String get sortBy => 'الترتيب';

  @override
  String get sortRecent => 'الأحدث إضافة';

  @override
  String get sortAz => 'أ–ي';

  @override
  String get sortRecentlyCooked => 'طُبخت مؤخرًا';

  @override
  String get sortMostCooked => 'الأكثر طبخًا';

  @override
  String get filterCookbook => 'كتاب الطبخ';

  @override
  String get filterTag => 'الوسم';

  @override
  String get filterSource => 'المصدر';

  @override
  String get filterTime => 'الوقت';

  @override
  String get filterPhoto => 'بصورة';

  @override
  String get sourceWritten => 'كتبتها بنفسي';

  @override
  String get sourceWebsite => 'موقع إلكتروني';

  @override
  String get sourceSocial => 'مواقع التواصل';

  @override
  String get sourcePhoto => 'صورة';

  @override
  String get timeUnder30 => 'أقل من 30 دقيقة';

  @override
  String get time30to60 => '30–60 دقيقة';

  @override
  String get timeOver60 => 'أكثر من ساعة';

  @override
  String get any => 'الكل';

  @override
  String get viewGrid => 'عرض شبكي';

  @override
  String get viewList => 'عرض قائمة';

  @override
  String get cookbookNew => 'كتاب طبخ جديد';

  @override
  String get cookbookName => 'الاسم';

  @override
  String get cookbookNameInvalid => 'من 1 إلى 60 حرفًا';

  @override
  String get cookbookRename => 'إعادة تسمية';

  @override
  String get cookbookDelete => 'حذف كتاب الطبخ';

  @override
  String get cookbookDeleteBody => 'ستبقى الوصفات في مكتبتك.';

  @override
  String cookbookRecipes(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown وصفة',
      many: '$shown وصفة',
      few: '$shown وصفات',
      two: 'وصفتان',
      one: 'وصفة واحدة',
      zero: 'لا وصفات',
    );
    return '$_temp0';
  }

  @override
  String get cookbooksEmpty =>
      'رتّب وصفاتك كما تحب: رمضان، عشاء سريع، أكلات العائلة.';

  @override
  String get cookbookEmpty =>
      'لا وصفات في هذا الكتاب بعد. أضفها من شاشة تعديل الوصفة.';

  @override
  String get fieldTags => 'الوسوم';

  @override
  String get fieldTagsHint => 'افصل بينها بفاصلة، مثل: حار، رمضان';

  @override
  String get tagsInvalid => 'حتى 20 وسمًا، 30 حرفًا لكل وسم';

  @override
  String get fieldCookbooks => 'كتب الطبخ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get create => 'إنشاء';

  @override
  String get scaleReset => 'إعادة';

  @override
  String get servingsLess => 'حصص أقل';

  @override
  String get servingsMore => 'حصص أكثر';

  @override
  String get notScaled => 'لم يُعدَّل';

  @override
  String notScaledCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown مكوّن لم يُعدَّل',
      many: '$shown مكوّنًا لم يُعدَّل',
      few: '$shown مكوّنات لم تُعدَّل',
      two: 'مكوّنان لم يُعدَّلا',
      one: 'مكوّن واحد لم يُعدَّل',
    );
    return '$_temp0';
  }

  @override
  String get viewAsWritten => 'كما كُتبت';

  @override
  String get viewMetric => 'غ / مل';

  @override
  String get viewKitchen => 'أكواب';

  @override
  String get startCooking => 'ابدأ الطبخ';

  @override
  String stepOf(String n, String total) {
    return 'الخطوة $n من $total';
  }

  @override
  String stepN(String n) {
    return 'الخطوة $n';
  }

  @override
  String get previousStep => 'السابق';

  @override
  String get nextStep => 'التالي';

  @override
  String get closeCooking => 'إغلاق وضع الطبخ';

  @override
  String get finishTitle => 'بالهناء والشفاء!';

  @override
  String get markCooked => 'تم طبخها';

  @override
  String get markedCooked => 'سُجّلت كوصفة مطبوخة';

  @override
  String get done => 'تم';

  @override
  String timerStart(String time) {
    return 'ابدأ مؤقت $time';
  }

  @override
  String get timerStop => 'إيقاف المؤقت';

  @override
  String timerDone(String n) {
    return 'انتهى المؤقت: الخطوة $n';
  }

  @override
  String get timerChannel => 'مؤقتات الطبخ';

  @override
  String get alertsOff =>
      'تنبيهات المؤقت في الخلفية متوقفة. يرن المؤقت ما دام التطبيق مفتوحًا.';

  @override
  String get dismiss => 'حسنًا';

  @override
  String get importTitle => 'استيراد من رابط';

  @override
  String get importHint => 'الصق رابط الوصفة';

  @override
  String get importExplain =>
      'تُقرأ وصفات مواقع مثل فتافيت وكوكباد على هاتفك، مجانًا وبلا حدود.';

  @override
  String get paste => 'لصق';

  @override
  String get importAction => 'استيراد';

  @override
  String get importReading => 'جارٍ فتح الصفحة…';

  @override
  String get importUnderstanding => 'جارٍ قراءة الوصفة…';

  @override
  String get importInvalidUrl => 'هذا لا يبدو رابطًا.';

  @override
  String get importUnreachable => 'تعذّر فتح الصفحة. تأكد من الرابط والاتصال.';

  @override
  String get importNoRecipe =>
      'لم يجد التطبيق بيانات وصفة في هذه الصفحة بعد. يمكنك إضافتها بنفسك.';

  @override
  String get addByHand => 'أضفها بنفسك';

  @override
  String get duplicateTitle => 'محفوظة مسبقًا';

  @override
  String get duplicateBody => 'حفظت وصفة من هذه الصفحة من قبل.';

  @override
  String get openSaved => 'افتح المحفوظة';

  @override
  String get importAgain => 'استورد مرة أخرى';

  @override
  String get importedRecipe => 'راجع واحفظ';
}
