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
  String get setupTitle => 'أهلًا بك في وصفاتي';

  @override
  String get setupBody =>
      'اختياران سريعان، ويمكنك تغييرهما لاحقًا من الإعدادات.';

  @override
  String get setupContinue => 'متابعة';

  @override
  String get walkthroughSkip => 'تخطَّ';

  @override
  String get walkthroughNext => 'التالي';

  @override
  String get walkthroughStart => 'إلى وصفاتي';

  @override
  String walkthroughPageOf(String n, String total) {
    return 'الصفحة $n من $total';
  }

  @override
  String get walkthroughImportTitle => 'احفظ الوصفات من أي منشور';

  @override
  String get walkthroughImportBody =>
      'شارك منشورًا من تيك توك أو إنستغرام أو يوتيوب، أو موقع وصفات، أو صورة، فتحوّله وصفاتي إلى وصفة مرتبة تراجعها قبل الحفظ.';

  @override
  String get walkthroughScaleTitle => 'مقادير تتضاعف بعربية سليمة';

  @override
  String get walkthroughScaleBody =>
      'غيّر عدد الحصص فتتبعه كل المقادير: كسور واضحة، ووحدات تتفق مع العدد.';

  @override
  String get walkthroughCookTitle => 'اطبخ خطوة بخطوة';

  @override
  String get walkthroughCookBody =>
      'خط كبير وخطوة في كل صفحة، ومؤقتات من نص الخطوة نفسها، والشاشة تبقى مضاءة.';

  @override
  String get walkthroughPlanTitle => 'خطّط لأسبوعك وتسوّق من قائمة واحدة';

  @override
  String get walkthroughPlanBody =>
      'ضع الوصفات على أيامك، ثم أضفها إلى قائمة مشتريات واحدة مرتبة حسب الأقسام وجاهزة للمشاركة.';

  @override
  String get walkthroughDemoRecipe => 'كبسة دجاج';

  @override
  String get walkthroughDemoLine1 => '1½ كوب أرز';

  @override
  String get walkthroughDemoLine2 => '2 ملعقة كبيرة زيت زيتون';

  @override
  String get walkthroughDemoLine3 => '1 بصلة';

  @override
  String get walkthroughDemoStep =>
      'يُغطّى ويُترك على نار هادئة لمدة 25 دقيقة.';

  @override
  String get settingsReplayWalkthrough => 'اعرض الجولة التعريفية مجددًا';

  @override
  String get recipesAdd => 'أضف وصفة';

  @override
  String get addSheetSubtitle => 'من أي مكان وجدتها، وبعربية سليمة.';

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
  String prepTime(String time) {
    return 'التحضير $time';
  }

  @override
  String cookTime(String time) {
    return 'الطبخ $time';
  }

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
  String get moreActions => 'المزيد';

  @override
  String get factPrep => 'التحضير';

  @override
  String get factCook => 'الطبخ';

  @override
  String get factServings => 'الحصص';

  @override
  String get linkOpenFailed => 'تعذّر فتح الرابط.';

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
  String fieldServingsInvalid(String min, String max) {
    return 'من $min إلى $max';
  }

  @override
  String get fieldPrep => 'التحضير (دقيقة)';

  @override
  String get fieldCook => 'الطبخ (دقيقة)';

  @override
  String fieldIngredientsHint(String n) {
    return 'مكوّن في كل سطر، مثل: $n كوب أرز\nالسطر الذي ينتهي بنقطتين يبدأ مجموعة، مثل: للصلصة:';
  }

  @override
  String get fieldStepsHint => 'خطوة في كل سطر';

  @override
  String get fieldNumberInvalid => 'أرقام فقط';

  @override
  String stepTooLong(String max) {
    return 'إحدى الخطوات أطول من $max حرف';
  }

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
  String get libraryFilteredHeading => 'نتائج التصفية';

  @override
  String get greetingMorning => 'صباح الخير';

  @override
  String get greetingEvening => 'مساء الخير';

  @override
  String get libraryQuestion => 'ماذا نطبخ اليوم؟';

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
  String get filterPhotoHeading => 'الصورة';

  @override
  String get filterAction => 'تصفية';

  @override
  String get filterActiveHint => 'تصفية نشطة';

  @override
  String get sourceWritten => 'كتبتها بنفسي';

  @override
  String get sourceWebsite => 'موقع إلكتروني';

  @override
  String get sourceSocial => 'مواقع التواصل';

  @override
  String get sourceTiktok => 'تيك توك';

  @override
  String get sourceInstagram => 'إنستغرام';

  @override
  String get sourceYoutube => 'يوتيوب';

  @override
  String get sourcePhoto => 'صورة';

  @override
  String timeUnder30(String n) {
    return 'أقل من $n دقيقة';
  }

  @override
  String time30to60(String range) {
    return '$range دقيقة';
  }

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
  String cookbookNameInvalid(String min, String max) {
    return 'من $min إلى $max حرفًا';
  }

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
  String tagsInvalid(String tags, String chars) {
    return 'حتى $tags وسمًا، $chars حرفًا لكل وسم';
  }

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
  String get continueCooking => 'تابع الطبخ';

  @override
  String get continueCookingAction => 'تابع';

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
  String get addSheetPhoto => 'من صورة';

  @override
  String get addSheetLinkDesc => 'فتافيت، كوكباد، تيك توك…';

  @override
  String get addSheetPhotoDesc => 'كتاب طبخ أو ورقة بخط اليد';

  @override
  String get addSheetPasteText => 'الصق نصًا';

  @override
  String get addSheetPasteDesc => 'وصف منشور أو رسالة';

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
  String get addSheetByHandDesc => 'اكتب وصفتك بطريقتك';

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
  String get reportMistake => 'أبلغ عن خطأ';

  @override
  String get reportMistakeExplainLink =>
      'يُفتح بريدك برسالة فيها رابط المصدر وملاحظتك فقط، وأنت من يرسلها.';

  @override
  String get reportMistakeExplainNoLink =>
      'يُفتح بريدك برسالة فيها ملاحظتك فقط، وأنت من يرسلها.';

  @override
  String get reportMistakeNoteHint => 'ما الخطأ؟ (اختياري)';

  @override
  String get reportMistakeSend => 'إرسال';

  @override
  String get reportMistakeSubject => 'وصفتي: خطأ في وصفة مستوردة';

  @override
  String reportMistakeNoMailApp(String email) {
    return 'لا يوجد تطبيق بريد على هذا الجهاز. راسلنا على $email';
  }

  @override
  String aiImportsLeftLine(int count, String shown, String quota) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'بقي $shown من $quota استيراد ذكي هذا الشهر · تتجدد في الأول من كل شهر',
      many:
          'بقي $shown من $quota استيرادًا ذكيًا هذا الشهر · تتجدد في الأول من كل شهر',
      few:
          'بقي $shown من $quota استيرادات ذكية هذا الشهر · تتجدد في الأول من كل شهر',
      two:
          'بقي $shown من $quota استيرادين ذكيين هذا الشهر · تتجدد في الأول من كل شهر',
      one:
          'بقي $shown من $quota استيراد ذكي هذا الشهر · تتجدد في الأول من كل شهر',
    );
    return '$_temp0';
  }

  @override
  String get aiImportsOutLine =>
      'نفدت الاستيرادات الذكية هذا الشهر · تتجدد في الأول من كل شهر. استيراد صفحات المواقع يبقى مجانيًا وبلا حدود.';

  @override
  String get aiImportsPremiumLine => 'استيرادات ذكية أكثر مع بريميوم';

  @override
  String aiImportCostLine(String shown, String quota) {
    return 'سيُستخدم استيراد ذكي واحد الآن · بقي $shown من $quota';
  }

  @override
  String get aiImportSending => 'جارٍ الاستيراد بالذكاء الاصطناعي…';

  @override
  String get aiImportKeepWaitingLine => 'يستغرق هذا وقتًا أطول من المعتاد.';

  @override
  String get aiImportKeepWaitingAction => 'متابعة الانتظار';

  @override
  String get aiImportErrorBadRequest => 'تعذّر إرسال هذا الطلب. حاول مرة أخرى.';

  @override
  String get aiImportErrorInvalidToken =>
      'تعذّر التحقق من هذا الجهاز. حاول لاحقًا.';

  @override
  String get aiImportErrorUnreachable => 'تعذّر قراءة محتوى هذا الرابط.';

  @override
  String get aiImportErrorPrivatePost =>
      'هذا الحساب أو المنشور خاص، فلا يمكن قراءة محتواه.';

  @override
  String get aiImportErrorNotARecipe =>
      'لم يجد التطبيق وصفة في هذا المحتوى. يمكنك إضافتها بنفسك.';

  @override
  String get aiImportErrorLimitReached =>
      'نفدت الاستيرادات الذكية هذا الشهر. استيراد صفحات المواقع يبقى مجانيًا.';

  @override
  String get aiImportErrorBusy => 'الاستيراد الذكي مشغول الآن. حاول لاحقًا.';

  @override
  String get aiImportErrorMisconfigured =>
      'الاستيراد الذكي غير متاح الآن. حاول لاحقًا.';

  @override
  String get aiImportErrorUnknown => 'حدث خطأ غير متوقع. حاول مرة أخرى.';

  @override
  String get aiImportErrorNetwork =>
      'تعذّر الاتصال. تحقّق من الإنترنت وحاول مرة أخرى.';

  @override
  String get aiImportErrorTooLarge => 'الصور أكبر من أن تُرسل. جرّب صورًا أقل.';

  @override
  String get aiImportErrorUnreadablePhoto =>
      'تعذّر فتح هذه الصورة. جرّب صورة أخرى.';

  @override
  String get aiImportPasteHint => 'الصق نص الوصفة أو الوصف هنا';

  @override
  String importPhotoExplain(String max) {
    return 'أو من صورة: صفحة من كتاب طبخ أو وصفة بخط اليد، حتى $max صور.';
  }

  @override
  String get importPhotoCamera => 'التقط صورة';

  @override
  String get importPhotoGallery => 'اختر من الصور';

  @override
  String get importPhotoAddPage => 'أضف صفحة';

  @override
  String importPhotoCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown صورة',
      many: '$shown صورة',
      few: '$shown صور',
      two: 'صورتان',
      one: 'صورة واحدة',
    );
    return '$_temp0';
  }

  @override
  String importPhotoFirstOnly(String max) {
    return 'تُستخدم أول $max صور فقط.';
  }

  @override
  String get aiImportScreenshotAction => 'أو صورة للشاشة';

  @override
  String get translateRecipe => 'ترجم إلى العربية';

  @override
  String get translateConfirm => 'ترجم';

  @override
  String get translateSending => 'جارٍ الترجمة…';

  @override
  String get translateKeptOriginal =>
      'بقيت بعض الأسطر بنصّها الأصلي كي لا تتغيّر أرقامها.';

  @override
  String get translateErrorIncomplete =>
      'عادت الترجمة ناقصة، ولم يُحتسب أي استيراد. حاول مرة أخرى.';

  @override
  String get translateErrorTooLarge =>
      'هذه الوصفة أطول من أن تُترجم دفعة واحدة.';

  @override
  String translatedFromLine(String title) {
    return 'مترجمة من: $title';
  }

  @override
  String translationLine(String title) {
    return 'الترجمة: $title';
  }

  @override
  String get tryAgain => 'حاول مرة أخرى';

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
  String planNoteInvalid(String min, String max) {
    return 'من $min إلى $max حرفًا';
  }

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
  String planSlotFull(String max) {
    return 'الوجبة تتسع حتى $max عناصر';
  }

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

  @override
  String get adSlotRemoveAds => 'إزالة الإعلانات';

  @override
  String get purchaseTitle => 'برو وبريميوم';

  @override
  String get purchaseClose => 'إغلاق';

  @override
  String get purchaseLead =>
      'كل ما في وصفاتي يبقى مجانيًا. برو يزيل الإعلانات، وبريميوم يزيلها أيضًا ويمنحك استيرادات ذكية أكثر.';

  @override
  String get purchasePro => 'برو';

  @override
  String get purchasePremium => 'بريميوم';

  @override
  String get purchaseProKind => 'شراء لمرة واحدة';

  @override
  String get purchasePremiumKind => 'اشتراك';

  @override
  String get purchaseNoAds => 'بلا إعلانات';

  @override
  String purchaseAiImports(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown استيراد ذكي شهريًا',
      many: '$shown استيرادًا ذكيًا شهريًا',
      few: '$shown استيرادات ذكية شهريًا',
      two: 'استيرادان ذكيان شهريًا',
      one: 'استيراد ذكي واحد شهريًا',
    );
    return '$_temp0';
  }

  @override
  String get purchaseFairUse => 'ضمن الاستخدام العادل';

  @override
  String get purchaseOwned => 'تملكه';

  @override
  String purchasePriceOnce(String price) {
    return '$price مرة واحدة';
  }

  @override
  String purchasePriceMonthly(String price) {
    return '$price شهريًا';
  }

  @override
  String purchasePriceYearly(String price) {
    return '$price سنويًا';
  }

  @override
  String get purchaseComingSoon => 'قريبًا';

  @override
  String get purchaseNothingYet => 'لا شيء معروض للشراء بعد.';

  @override
  String get purchaseRestore => 'استعادة عمليات الشراء';

  @override
  String get purchaseRestored => 'استُعيدت عمليات الشراء.';

  @override
  String get purchaseNothingToRestore =>
      'لا عمليات شراء لوصفاتي على حساب Google هذا.';

  @override
  String get purchaseStoreUnreachable =>
      'تعذّر الوصول إلى Google Play. حاول لاحقًا.';

  @override
  String get purchasePending =>
      'بانتظار أن يؤكد Google Play الدفع. لا يتغير شيء قبل ذلك.';

  @override
  String get purchaseFailed => 'لم تكتمل عملية الشراء.';

  @override
  String get purchasePremiumRenews =>
      'يتجدد بريميوم تلقائيًا حتى تلغيه. ألغِه متى شئت: الإعدادات › إدارة أو إلغاء يفتحه في Google Play.';

  @override
  String get purchaseManage => 'إدارة أو إلغاء';

  @override
  String get purchaseManageFailed => 'تعذّر فتح Google Play.';

  @override
  String get settingsPayingSection => 'الإعلانات والاشتراك';

  @override
  String get settingsSubscription => 'الاشتراك';

  @override
  String get tierFree => 'مجاني';

  @override
  String get settingsAdPrivacy => 'خيارات الخصوصية في الإعلانات';

  @override
  String get addSheetQuotaLabel => 'الاستيراد الذكي';

  @override
  String addSheetQuotaCount(String shown, String quota) {
    return '$shown من $quota متبقية';
  }

  @override
  String get addSheetQuotaCaption =>
      'تتجدد في الأول من كل شهر · استيراد صفحات المواقع يبقى مجانيًا وبلا حدود.';
}
