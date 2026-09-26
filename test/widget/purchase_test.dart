// PAY-1–PAY-11 on screen: the purchase screen, Settings' Subscription
// rows, and Premium's quota on the import screen — over the no-op store,
// never a real one.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/quantity/arabic_text.dart' show ownIsolate;
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/screens/import_screen.dart';
import 'package:wasfati/screens/purchase_screen.dart' as purchase_screen;
import 'package:wasfati/services/ads.dart';
import 'package:wasfati/services/store.dart';

import 'app_test.dart' show adService, pumpApp, settle, shares, shown, store;

const proOffer = StoreOffer(product: Product.pro, price: 'AED 14.99');
const monthly = StoreOffer(
  product: Product.premium,
  plan: PremiumPlan.monthly,
  price: 'AED 9.99',
);
const yearly = StoreOffer(
  product: Product.premium,
  plan: PremiumPlan.yearly,
  price: 'AED 79.99',
);
const allOffers = [proOffer, monthly, yearly];

/// The price lines as drawn: the store's price as the store wrote it, in
/// its own direction isolate (PAY-2, LANG-5).
final proOnce = '${ownIsolate('AED 14.99')} مرة واحدة';
final premiumMonthly = '${ownIsolate('AED 9.99')} شهريًا';
final premiumYearly = '${ownIsolate('AED 79.99')} سنويًا';

/// Opens Settings and scrolls to its Subscription section.
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('الإعدادات'));
  await settle(tester);
  await tester.scrollUntilVisible(find.text('الاشتراك'), 300);
  await settle(tester);
}

/// PAY-5's first place: Settings' Subscription row.
Future<void> openPurchaseScreen(WidgetTester tester) async {
  await openSettings(tester);
  await tester.tap(find.text('الاشتراك'));
  await settle(tester);
}

/// LOOK-7: Settings is a navigation-pill tab now, not a pushed screen, so
/// leaving it taps the recipes tab instead of a system Back.
Future<void> closeSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('الوصفات'));
  await settle(tester);
}

/// Every Text on screen whose style strikes it through.
Finder struckThrough() => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.style?.decoration?.contains(TextDecoration.lineThrough) ?? false),
);

void main() {
  testWidgets('PAY-10: the close button is there from the very first frame', (
    tester,
  ) async {
    await pumpApp(
      tester,
      withRecipe: true,
      storeOverride: NoopPurchaseStore(offers: allOffers),
    );
    await openSettings(tester);
    await tester.tap(find.text('الاشتراك'));
    // The route's very first frame (built offstage for a moment, as every
    // pushed page is, so heroes can measure): the close button is already
    // there, and on the first frame that shows, it's on screen.
    await tester.pump();
    expect(find.byTooltip('إغلاق', skipOffstage: false), findsOneWidget);
    await tester.pump();
    expect(find.byTooltip('إغلاق'), findsOneWidget);
    await settle(tester);
    await tester.tap(find.byTooltip('إغلاق'));
    await settle(tester);
    expect(find.text('برو وبريميوم'), findsNothing);
    expect(find.text('الاشتراك'), findsOneWidget); // back on Settings
  });

  testWidgets('PAY-2, PAY-10: Pro and Premium side by side at the store\'s '
      'own prices, nothing preselected, no crossed-out price', (tester) async {
    await pumpApp(
      tester,
      withRecipe: true,
      storeOverride: NoopPurchaseStore(offers: allOffers),
    );
    await openPurchaseScreen(tester);

    expect(find.text('برو'), findsOneWidget);
    expect(find.text('بريميوم'), findsOneWidget);
    // Side by side: the two names on one line, the same size.
    expect(
      tester.getRect(find.text('برو')).top,
      tester.getRect(find.text('بريميوم')).top,
    );
    expect(
      tester.getRect(find.text('برو')).left,
      greaterThan(tester.getRect(find.text('بريميوم')).right),
    ); // right to left: Pro first
    // PAY-7: what each includes.
    expect(find.text('بلا إعلانات'), findsNWidgets(2));
    expect(find.text('10 استيرادات ذكية شهريًا'), findsOneWidget);
    expect(find.text('100 استيراد ذكي شهريًا'), findsOneWidget);
    // PAY-2: the store's prices, as the store wrote them.
    expect(find.text(proOnce), findsOneWidget);
    expect(find.text(premiumMonthly), findsOneWidget);
    expect(find.text(premiumYearly), findsOneWidget);
    // PAY-10: every plan the same kind of button, none preselected.
    expect(find.byType(OutlinedButton), findsNWidgets(3));
    expect(find.byType(FilledButton), findsNothing);
    expect(struckThrough(), findsNothing);
    // PAY-1: "Restore purchases" by the prices; PAY-11: renews until
    // cancelled, and where to cancel.
    await tester.scrollUntilVisible(find.text('استعادة عمليات الشراء'), 200);
    expect(find.text('استعادة عمليات الشراء'), findsOneWidget);
    expect(shown('يتجدد بريميوم تلقائيًا حتى تلغيه'), findsOneWidget);
    // ADS-9: never an ad here.
    expect(find.byKey(noopBannerKey), findsNothing);

    await tester.ensureVisible(find.text(premiumYearly));
    await tester.tap(find.text(premiumYearly));
    await settle(tester);
    expect(store.bought, [yearly]);
    expect(find.text('تملكه'), findsNothing); // nothing until it's confirmed
  });

  testWidgets('PAY-3, PAY-6: nothing configured in the store is nothing '
      'to sell: no price, no button', (tester) async {
    await pumpApp(tester, withRecipe: true);
    await openPurchaseScreen(tester);
    expect(find.text('لا شيء معروض للشراء بعد.'), findsOneWidget);
    expect(find.text('قريبًا'), findsNWidgets(2));
    expect(find.byType(OutlinedButton), findsNothing);
    expect(shown('AED'), findsNothing);
  });

  testWidgets('PAY-6: a pending purchase waits, a failed one says so', (
    tester,
  ) async {
    await pumpApp(
      tester,
      withRecipe: true,
      storeOverride: NoopPurchaseStore(offers: allOffers),
    );
    await openPurchaseScreen(tester);
    await tester.tap(find.text(proOnce));
    await settle(tester);
    store.emit(Product.pro, PurchaseOutcome.pending);
    await settle(tester);
    expect(shown('بانتظار أن يؤكد Google Play الدفع'), findsOneWidget);
    expect(find.text(proOnce), findsNothing);

    store.emit(Product.pro, PurchaseOutcome.failed);
    await settle(tester);
    await tester.scrollUntilVisible(find.text('لم تكتمل عملية الشراء.'), 200);
    expect(find.text('لم تكتمل عملية الشراء.'), findsOneWidget);
    expect(find.text(proOnce), findsOneWidget);
    expect(store.finished, hasLength(2));

    store.emit(Product.pro, PurchaseOutcome.purchased);
    await settle(tester);
    expect(find.text('لم تكتمل عملية الشراء.'), findsNothing);
    expect(find.text('تملكه'), findsOneWidget);
  });

  testWidgets('PAY-1: restore finds what the account owns, and marks it '
      'Owned', (tester) async {
    await pumpApp(
      tester,
      withRecipe: true,
      storeOverride: NoopPurchaseStore(offers: allOffers),
    );
    await openPurchaseScreen(tester);
    final restore = find.text('استعادة عمليات الشراء');
    await tester.scrollUntilVisible(restore, 200);

    await tester.tap(restore);
    await settle(tester);
    expect(
      find.text('لا عمليات شراء لوصفاتي على حساب Google هذا.'),
      findsOneWidget,
    );

    store.ownedNow = {Product.pro}; // bought on another phone
    await tester.tap(restore);
    await settle(tester);
    expect(find.text('استُعيدت عمليات الشراء.'), findsOneWidget);
    expect(find.text('تملكه'), findsOneWidget);
    expect(find.text(proOnce), findsNothing);
    expect(find.text(premiumMonthly), findsOneWidget); // Premium still sold

    store.ownedNow = null; // Play can't be reached
    await tester.tap(restore);
    await settle(tester);
    expect(
      find.text('تعذّر الوصول إلى Google Play. حاول لاحقًا.'),
      findsOneWidget,
    );
    expect(find.text('تملكه'), findsOneWidget); // nothing lost
  });

  testWidgets('PAY-11: Settings shows the plan, and "Manage or cancel" '
      'opens Google Play\'s subscription page in one tap', (tester) async {
    await pumpApp(tester, withRecipe: true);
    await openSettings(tester);
    expect(find.text('مجاني'), findsOneWidget);
    expect(find.text('إدارة أو إلغاء'), findsNothing);
    await closeSettings(tester);

    await tester.pumpWidget(const SizedBox()); // a fresh app
    await pumpApp(
      tester,
      withRecipe: true,
      storeOverride: NoopPurchaseStore(owned: {Product.premium}),
    );
    await openSettings(tester);
    expect(find.text('بريميوم'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('إدارة أو إلغاء'), 100);
    await tester.tap(find.text('إدارة أو إلغاء'));
    await settle(tester);
    expect(store.subscriptionPagesOpened, 1);

    store.opens = false; // no Play Store to open
    await tester.tap(find.text('إدارة أو إلغاء'));
    await settle(tester);
    expect(find.text('تعذّر فتح Google Play.'), findsOneWidget);
  });

  testWidgets('ADS-5: Settings keeps a row to change the ad consent, where '
      'the law asks for one', (tester) async {
    await pumpApp(
      tester,
      withRecipe: true,
      adServiceOverride: NoopAdService(
        consent: const AdConsent(
          canRequestAds: true,
          privacyOptionsRequired: true,
        ),
      ),
    );
    await openSettings(tester);
    await tester.scrollUntilVisible(
      find.text('خيارات الخصوصية في الإعلانات'),
      100,
    );
    await tester.tap(find.text('خيارات الخصوصية في الإعلانات'));
    await settle(tester);
    expect(adService.consentChanges, 1);
  });

  testWidgets('ADS-5: no consent row where the law doesn\'t ask', (
    tester,
  ) async {
    await pumpApp(
      tester,
      withRecipe: true,
      adServiceOverride: NoopAdService(
        consent: const AdConsent(
          canRequestAds: true,
          privacyOptionsRequired: false,
        ),
      ),
    );
    await openSettings(tester);
    expect(find.text('خيارات الخصوصية في الإعلانات'), findsNothing);
  });

  group('PAY-7: AI imports on the import screen', () {
    testWidgets('Premium gives 100 a month, counting the month\'s imports '
        'so far', (tester) async {
      final (_, settings) = await pumpApp(
        tester,
        withRecipe: true,
        storeOverride: NoopPurchaseStore(owned: {Product.premium}),
      );
      await tester.runAsync(() async {
        for (var i = 0; i < 12; i++) {
          await settings.recordAiImportSaved();
        }
      });
      await tester.tap(find.byTooltip('أضف وصفة'));
      await settle(tester);
      await tester.tap(find.text('استيراد من رابط'));
      await settle(tester);
      // PAY-11: 12 used stays 12 used, of 100 or of 10.
      expect(
        find.text(
          'بقي 88 من 100 استيراد ذكي هذا الشهر · تتجدد في الأول من كل شهر',
        ),
        findsOneWidget,
      );
      expect(find.text('استيرادات ذكية أكثر مع بريميوم'), findsNothing);
    });

    testWidgets('PAY-5: out of free imports, one line offers Premium when '
        'it\'s on sale', (tester) async {
      final (_, settings) = await pumpApp(
        tester,
        withRecipe: true,
        storeOverride: NoopPurchaseStore(offers: allOffers),
      );
      await tester.runAsync(() async {
        for (var i = 0; i < 10; i++) {
          await settings.recordAiImportSaved();
        }
      });
      await tester.tap(find.byTooltip('أضف وصفة'));
      await settle(tester);
      await tester.tap(find.text('استيراد من رابط'));
      await settle(tester);
      expect(shown('نفدت الاستيرادات الذكية هذا الشهر'), findsOneWidget);
      await tester.tap(find.text('استيرادات ذكية أكثر مع بريميوم'));
      await settle(tester);
      expect(find.text(premiumMonthly), findsOneWidget);
    });

    testWidgets('PAY-6: no Premium line when nothing is on sale', (
      tester,
    ) async {
      final (_, settings) = await pumpApp(tester, withRecipe: true);
      await tester.runAsync(() async {
        for (var i = 0; i < 10; i++) {
          await settings.recordAiImportSaved();
        }
      });
      await tester.tap(find.byTooltip('أضف وصفة'));
      await settle(tester);
      await tester.tap(find.text('استيراد من رابط'));
      await settle(tester);
      expect(shown('نفدت الاستيرادات الذكية هذا الشهر'), findsOneWidget);
      expect(find.text('استيرادات ذكية أكثر مع بريميوم'), findsNothing);
    });

    testWidgets('RUN-3: a share during setup opens import with no Premium '
        'line, and nothing opens the purchase screen', (tester) async {
      final (_, settings) = await pumpApp(
        tester,
        firstRunComplete: false,
        storeOverride: NoopPurchaseStore(offers: allOffers),
      );
      await tester.runAsync(() async {
        for (var i = 0; i < 10; i++) {
          await settings.recordAiImportSaved();
        }
      });
      expect(find.text('متابعة'), findsOneWidget); // setup

      shares.add('نص عشوائي بلا وصفة');
      await settle(tester);
      expect(find.byType(ImportScreen), findsOneWidget);
      // The quota line, and the share's own out-of-imports notice.
      expect(shown('نفدت الاستيرادات الذكية هذا الشهر'), findsWidgets);
      expect(find.text('استيرادات ذكية أكثر مع بريميوم'), findsNothing);

      // The one way in refuses too, until the first run is finished.
      // Not awaited first: a pushed screen would wait for its own close.
      final opening = purchase_screen.openPurchaseScreen(
        tester.element(find.byType(ImportScreen)),
      );
      await settle(tester);
      expect(find.byType(purchase_screen.PurchaseScreen), findsNothing);
      expect(find.text(premiumMonthly), findsNothing);
      await opening; // it returned at once, having pushed nothing
    });
  });

  for (final language in [LanguagePref.ar, LanguagePref.en]) {
    testWidgets('LANG-6: the purchase screen and Settings\' section fit a '
        '360dp phone at 1.3x text (${language.name})', (tester) async {
      await pumpApp(
        tester,
        language: language,
        textScale: 1.3,
        withRecipe: true,
        adServiceOverride: NoopAdService(
          consent: const AdConsent(
            canRequestAds: true,
            privacyOptionsRequired: true,
          ),
          fills: true,
        ),
        storeOverride: NoopPurchaseStore(
          owned: {Product.premium},
          offers: allOffers,
        ),
      );
      final ar = language == LanguagePref.ar;
      await tester.tap(find.byTooltip(ar ? 'الإعدادات' : 'Settings'));
      await settle(tester);
      final row = find.text(ar ? 'الاشتراك' : 'Subscription');
      await tester.scrollUntilVisible(row, 300);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'settings');
      await tester.tap(row);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'purchase screen');
      expect(find.text(ar ? 'تملكه' : 'Owned'), findsOneWidget);
    });
  }
}
