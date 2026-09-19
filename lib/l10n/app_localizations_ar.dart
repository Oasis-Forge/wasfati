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
  String recipesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count وصفة',
      many: '$count وصفة',
      few: '$count وصفات',
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
}
