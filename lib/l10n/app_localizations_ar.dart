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
  String get shareTooltip => 'مشاركة';

  @override
  String get shareAsText => 'كنص';

  @override
  String get shareAsImages => 'كصورة';

  @override
  String get shareHeadingIngredients => 'المقادير';

  @override
  String get shareHeadingSteps => 'الطريقة';

  @override
  String shareSource(String url) {
    return 'المصدر: $url';
  }

  @override
  String get shareFooterLine => 'من تطبيق وصفاتي';

  @override
  String get shareRendering => 'جارٍ إنشاء الصور…';

  @override
  String get shareTooLong =>
      'هذه الوصفة طويلة جدًا لتُشارك كصور. شاركها كنص بدلاً من ذلك.';

  @override
  String get shareFailed => 'تعذّر إنشاء الصور. حاول مرة أخرى.';

  @override
  String shareUnscaledLine(String line, String mark) {
    return '$line ($mark)';
  }

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
  String get settingsLook => 'الطراز';

  @override
  String get lookInk => 'حبر';

  @override
  String get lookSaffron => 'زعفران';

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

  @override
  String get planTitle => 'الخطة';

  @override
  String get tabRecipes => 'الوصفات';

  @override
  String get planThisWeek => 'هذا الأسبوع';

  @override
  String get planViewWeek => 'الأسبوع';

  @override
  String get planViewRamadan => 'رمضان';

  @override
  String get planPreviousWeek => 'الأسبوع السابق';

  @override
  String get planNextWeek => 'الأسبوع التالي';

  @override
  String get planToday => 'اليوم';

  @override
  String get mealBreakfast => 'فطور';

  @override
  String get mealLunch => 'غداء';

  @override
  String get mealDinner => 'عشاء';

  @override
  String get mealSnack => 'وجبة خفيفة';

  @override
  String get mealSuhoor => 'السحور';

  @override
  String get mealIftar => 'الإفطار';

  @override
  String get planAdd => 'إضافة';

  @override
  String get planAddRecipe => 'اختر وصفة';

  @override
  String get planAddNote => 'اكتب ملاحظة';

  @override
  String get planNoteLabel => 'ملاحظة';

  @override
  String get planNoteHint => 'مطعم، بقايا الأمس…';

  @override
  String get planNoteInvalid => 'من ١ إلى ٦٠ حرفًا';

  @override
  String get planAddToPlan => 'أضف إلى الخطة';

  @override
  String get planAdded => 'أُضيفت إلى الخطة';

  @override
  String get planChooseDay => 'اختر اليوم';

  @override
  String get planChooseMeal => 'اختر الوجبة';

  @override
  String get planAmount => 'المقدار';

  @override
  String get planMove => 'نقل';

  @override
  String get planCopy => 'نسخ';

  @override
  String get planRemove => 'إزالة';

  @override
  String get planRemoved => 'أُزيلت من الخطة';

  @override
  String get planClearWeek => 'مسح الأسبوع';

  @override
  String planClearedCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُزيلت $shown وجبة',
      many: 'أُزيلت $shown وجبة',
      few: 'أُزيلت $shown وجبات',
      two: 'أُزيلت وجبتان',
      one: 'أُزيلت وجبة واحدة',
      zero: 'لا شيء لمسحه',
    );
    return '$_temp0';
  }

  @override
  String get planSlotFull => 'الوجبة تتسع حتى ١٠ عناصر';

  @override
  String get planEmptyTitle => 'خطط أسبوعك';

  @override
  String get planEmptyBody =>
      'أضف وصفة إلى أي وجبة، أو اكتب ملاحظة مثل «مطعم».';

  @override
  String planNextMeal(String day, String meal) {
    return 'في الخطة: $day، $meal';
  }

  @override
  String get groceriesTitle => 'المشتريات';

  @override
  String get addToGroceries => 'أضف إلى المشتريات';

  @override
  String get groceriesAddHint => 'أضف غرضًا';

  @override
  String get groceriesEmptyTitle => 'قائمة المشتريات فارغة';

  @override
  String get groceriesEmptyBody =>
      'اكتب غرضًا بالأعلى، أو أضفه من صفحة وصفة أو من خطة الأسبوع.';

  @override
  String get aisleProduce => 'خضار وفواكه';

  @override
  String get aisleMeat => 'لحوم ودواجن';

  @override
  String get aisleFish => 'أسماك';

  @override
  String get aisleDairy => 'ألبان وأجبان وبيض';

  @override
  String get aisleBakery => 'خبز ومخبوزات';

  @override
  String get aisleGrains => 'أرز ومعكرونة وبقوليات';

  @override
  String get aisleSpices => 'بهارات';

  @override
  String get aislePantry => 'زيوت وصلصات ومعلبات';

  @override
  String get aisleBaking => 'مستلزمات الحلويات';

  @override
  String get aisleFrozen => 'مجمدات';

  @override
  String get aisleDrinks => 'مشروبات';

  @override
  String get aisleOther => 'أخرى';

  @override
  String get groceriesDoneSection => 'تم';

  @override
  String get groceriesClearDone => 'مسح ما تم شراؤه';

  @override
  String get groceriesClearAll => 'مسح الكل';

  @override
  String groceriesClearedCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مُسح $shown عنصر',
      many: 'مُسح $shown عنصرًا',
      few: 'مُسحت $shown عناصر',
      two: 'مُسح عنصران',
      one: 'مُسح عنصر واحد',
      zero: 'لا شيء لمسحه',
    );
    return '$_temp0';
  }

  @override
  String get groceriesByAisle => 'حسب الممر';

  @override
  String get groceriesByRecipe => 'حسب الوصفة';

  @override
  String get groceriesHandAdded => 'أضفتها بنفسك';

  @override
  String groceriesRecipeRemoved(String title) {
    return 'أُزيلت مكوّنات «$title»';
  }

  @override
  String get groceriesMoveToAisle => 'نقل إلى ممر آخر';

  @override
  String get groceriesShareTooltip => 'مشاركة';

  @override
  String get groceriesShareTitle => 'قائمة المشتريات';

  @override
  String groceriesFrom(String names) {
    return 'من: $names';
  }

  @override
  String get groceriesNameSeparator => '، ';

  @override
  String groceriesAddedCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُضيف $shown مكوّن',
      many: 'أُضيف $shown مكوّنًا',
      few: 'أُضيفت $shown مكوّنات',
      two: 'أُضيف مكوّنان',
      one: 'أُضيف مكوّن واحد',
    );
    return '$_temp0';
  }

  @override
  String get planGroceriesAlreadyAdded => 'أُضيفت';

  @override
  String get planGroceriesEmpty => 'لا وجبات من اليوم في هذه الأيام';

  @override
  String planGroceriesAddedCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُضيفت $shown وجبة إلى المشتريات',
      many: 'أُضيفت $shown وجبة إلى المشتريات',
      few: 'أُضيفت $shown وجبات إلى المشتريات',
      two: 'أُضيفت وجبتان إلى المشتريات',
      one: 'أُضيفت وجبة واحدة إلى المشتريات',
      zero: 'لا شيء لإضافته',
    );
    return '$_temp0';
  }

  @override
  String ramadanCardSoon(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'رمضان بعد $shown يوم. نحوّل الخطة إلى سحور وإفطار؟',
      many: 'رمضان بعد $shown يومًا. نحوّل الخطة إلى سحور وإفطار؟',
      few: 'رمضان بعد $shown أيام. نحوّل الخطة إلى سحور وإفطار؟',
      two: 'رمضان بعد يومين. نحوّل الخطة إلى سحور وإفطار؟',
      one: 'رمضان بعد يوم واحد. نحوّل الخطة إلى سحور وإفطار؟',
    );
    return '$_temp0';
  }

  @override
  String get ramadanCardNow => 'رمضان كريم. نحوّل الخطة إلى سحور وإفطار؟';

  @override
  String get ramadanCardEnable => 'تفعيل';

  @override
  String get ramadanCardNotNow => 'ليس الآن';

  @override
  String ramadanDayLabel(String day) {
    return '$day رمضان';
  }

  @override
  String get ramadanEidLabel => 'عيد الفطر';

  @override
  String get settingsRamadanSection => 'رمضان';

  @override
  String get settingsBackupSection => 'النسخ الاحتياطي';

  @override
  String get backupSaveAction => 'احفظ نسخة احتياطية';

  @override
  String get backupSaveDone => 'تم حفظ النسخة الاحتياطية';

  @override
  String get backupSaveFailed => 'تعذّر حفظ النسخة الاحتياطية.';

  @override
  String get backupShareFailed => 'تعذّر مشاركة النسخة الاحتياطية.';

  @override
  String get backupShareAction => 'مشاركة النسخة';

  @override
  String get backupRestoreAction => 'استعادة';

  @override
  String get backupErrorCantOpen => 'تعذّر فتح هذا الملف.';

  @override
  String get backupExportAction => 'تصدير كنص';

  @override
  String get backupReminderSwitch => 'التذكير بالنسخ الاحتياطي';

  @override
  String get backupAutoSection => 'النسخ التلقائية';

  @override
  String get backupAutoEmpty => 'لا نسخ تلقائية بعد';

  @override
  String backupAutoBackupDate(String date, String time) {
    return 'نسخة $date، $time';
  }

  @override
  String get backupPreviewTitle => 'محتوى الملف';

  @override
  String backupPreviewRecipes(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown وصفة',
      many: '$shown وصفة',
      few: '$shown وصفات',
      two: 'وصفتان',
      one: 'وصفة واحدة',
      zero: 'بلا وصفات',
    );
    return '$_temp0';
  }

  @override
  String backupPreviewCookbooks(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown كتاب طبخ',
      many: '$shown كتاب طبخ',
      few: '$shown كتب طبخ',
      two: 'كتابا طبخ',
      one: 'كتاب طبخ واحد',
      zero: 'بلا كتب طبخ',
    );
    return '$_temp0';
  }

  @override
  String backupPreviewWeeks(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown أسبوع في الخطة',
      many: '$shown أسبوعًا في الخطة',
      few: '$shown أسابيع في الخطة',
      two: 'أسبوعان في الخطة',
      one: 'أسبوع واحد في الخطة',
      zero: 'بلا أسابيع في الخطة',
    );
    return '$_temp0';
  }

  @override
  String backupPreviewGroceryItems(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown عنصر في المشتريات',
      many: '$shown عنصرًا في المشتريات',
      few: '$shown عناصر في المشتريات',
      two: 'عنصران في المشتريات',
      one: 'عنصر واحد في المشتريات',
      zero: 'بلا عناصر في المشتريات',
    );
    return '$_temp0';
  }

  @override
  String get backupMergeAction => 'دمج';

  @override
  String get backupReplaceAction => 'استبدال';

  @override
  String get backupReplaceConfirmTitle => 'استبدال كل البيانات؟';

  @override
  String backupReplaceConfirmBody(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'سيحذف هذا وصفة هذا الجهاز الـ$shown، مع خطة الوجبات وقائمة المشتريات، ويضع مكانها ما في الملف.',
      many:
          'سيحذف هذا وصفة هذا الجهاز الـ$shown، مع خطة الوجبات وقائمة المشتريات، ويضع مكانها ما في الملف.',
      few:
          'سيحذف هذا وصفات هذا الجهاز الـ$shown، مع خطة الوجبات وقائمة المشتريات، ويضع مكانها ما في الملف.',
      two: 'سيحذف هذا الوصفتين الموجودتين في هذا الجهاز، مع خطة الوجبات وقائمة المشتريات، ويضع مكانهما ما في الملف.',
      one: 'سيحذف هذا الوصفة الموجودة في هذا الجهاز، مع خطة الوجبات وقائمة المشتريات، ويضع مكانها ما في الملف.',
      zero: 'سيستبدل هذا خطة الوجبات وقائمة المشتريات في هذا الجهاز بما في الملف.',
    );
    return '$_temp0 تُحفظ نسخة تلقائية مما هنا الآن أولًا.';
  }

  @override
  String get backupReplaceConfirmFinalTitle => 'هل أنت متأكد؟';

  @override
  String get backupReplaceConfirmFinalBody =>
      'لا يمكن التراجع عن هذا من هنا، إلا باستعادة النسخة التلقائية التي حُفظت للتو.';

  @override
  String get backupResultTitle => 'اكتملت الاستعادة';

  @override
  String backupResultSummary(String added, String updated, String unchanged) {
    return 'أُضيف $added · حُدّث $updated · بلا تغيير $unchanged';
  }

  @override
  String get backupErrorNotWasfati => 'هذا ليس ملف نسخة احتياطية من وصفاتي.';

  @override
  String get backupErrorDamaged => 'هذا الملف تالف.';

  @override
  String get backupErrorNewerSchema =>
      'هذه النسخة الاحتياطية من إصدار أحدث من التطبيق. حدّث التطبيق أولًا.';

  @override
  String get backupErrorGeneric => 'تعذّرت الاستعادة.';

  @override
  String get backupExportPickTitle => 'تصدير الوصفات';

  @override
  String get backupExportAll => 'كل الوصفات';

  @override
  String get backupExportDone => 'تم حفظ ملف التصدير';

  @override
  String get backupExportFailed => 'تعذّر حفظ ملف التصدير.';

  @override
  String get backupReminderNever => 'لم تحفظ نسخة احتياطية بعد';

  @override
  String backupReminderDaysAgo(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'آخر نسخة احتياطية قبل $shown يوم',
      many: 'آخر نسخة احتياطية قبل $shown يومًا',
      few: 'آخر نسخة احتياطية قبل $shown أيام',
      two: 'آخر نسخة احتياطية قبل يومين',
      one: 'آخر نسخة احتياطية قبل يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get backupReminderNowAction => 'احفظ الآن';

  @override
  String get backupReminderLaterAction => 'لاحقًا';

  @override
  String get ramadanModeLabel => 'وضع رمضان';

  @override
  String ramadanStartLabel(String date) {
    return 'بداية رمضان: $date';
  }

  @override
  String get ramadanShiftEarlier => 'يوم أبكر';

  @override
  String get ramadanShiftLater => 'يوم لاحق';
}
