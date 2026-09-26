// ADS-1–ADS-9 on screen: one banner slot on exactly the four screens
// Decision 12 names, nowhere else; its reserved height; and Pro or Premium
// taking every banner away. Over the no-op ad network and store.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/widgets/nav_pill.dart';
import 'package:wasfati/models/quantity/arabic_text.dart' show ownIsolate;
import 'package:wasfati/services/ads.dart';
import 'package:wasfati/services/store.dart';
import 'package:wasfati/widgets/ad_slot.dart';

import 'app_test.dart' show purchases, pumpApp, settle, store;

const allowed = AdConsent(canRequestAds: true, privacyOptionsRequired: false);

/// The banner, once it has arrived.
final banner = find.byKey(noopBannerKey);

/// The shell's own tabs, scoped to the NavPill (the recipe and plan
/// pages carry the same icons in their app bars).
Finder navTab(IconData icon) =>
    find.descendant(of: find.byType(NavPill), matching: find.byIcon(icon));

/// A slot's height on screen: 0 when it isn't showing at all.
double slotHeight(WidgetTester tester) =>
    tester.getSize(find.byType(AdSlot)).height;

void main() {
  testWidgets('ADS-9: the banner is on the library, the plan, groceries and '
      'the recipe page, and on no other screen', (tester) async {
    await pumpApp(
      tester,
      withRecipe: true,
      adServiceOverride: NoopAdService(consent: allowed, fills: true),
    );

    // The library.
    expect(banner, findsOneWidget, reason: 'library');
    // ADS-3: outside the scrolling content, above the navigation bar with
    // ADS-9's 8 dp between them.
    expect(
      find.ancestor(of: banner, matching: find.byType(Scrollable)),
      findsNothing,
    );
    // ADS-9/LOOK-8: at least 8dp clear of the raised "+" — not just the
    // pill's own fill, which the "+" rises above.
    expect(
      tester.getRect(banner).bottom + AdSlot.gap,
      lessThanOrEqualTo(tester.getRect(find.byTooltip('أضف وصفة')).top),
    );

    await tester.tap(navTab(Icons.calendar_month_outlined));
    await settle(tester);
    expect(banner, findsOneWidget, reason: 'plan');

    await tester.tap(navTab(Icons.shopping_basket_outlined));
    await settle(tester);
    expect(banner, findsOneWidget, reason: 'groceries');

    await tester.tap(navTab(Icons.menu_book_outlined));
    await settle(tester);

    // The recipe page: its own slot, in its bottom bar.
    await tester.tap(find.text('كبسة لحم'));
    await settle(tester);
    expect(banner, findsOneWidget, reason: 'recipe page');
    expect(
      find.ancestor(of: banner, matching: find.byType(Scrollable)),
      findsNothing,
    );
    // ADS-9, LOOK-13: "ابدأ الطبخ", in the action bar over the banner,
    // keeps 8 dp.
    final start = find.text('ابدأ الطبخ');
    expect(
      tester.getRect(start).bottom,
      lessThanOrEqualTo(tester.getRect(banner).top - AdSlot.gap),
    );

    // Cook mode (COOK-1).
    await tester.tap(start);
    await settle(tester);
    expect(find.text('الخطوة 1 من 2'), findsWidgets);
    expect(banner, findsNothing, reason: 'cook mode');
    expect(find.byType(AdSlot), findsNothing, reason: 'cook mode');
    await tester.tap(find.byIcon(Icons.close).first);
    await settle(tester);

    // The editor.
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await settle(tester);
    expect(find.byType(AdSlot), findsNothing, reason: 'editor');
    expect(banner, findsNothing, reason: 'editor');
    await tester.tap(find.byType(BackButton).first);
    await settle(tester);
    // LOOK-13: the recipe page's own round back button.
    await tester.tap(find.byTooltip('رجوع'));
    await settle(tester);
    expect(banner, findsOneWidget, reason: 'back on the library');

    // Import.
    await tester.tap(find.byTooltip('أضف وصفة'));
    await settle(tester);
    await tester.tap(find.text('استيراد من رابط'));
    await settle(tester);
    expect(find.byType(AdSlot), findsNothing, reason: 'import');
    expect(banner, findsNothing, reason: 'import');
    await tester.tap(find.byType(BackButton).first);
    await settle(tester);

    // Settings, and the purchase screen from its Subscription row.
    await tester.tap(find.byTooltip('الإعدادات'));
    await settle(tester);
    expect(find.byType(AdSlot), findsNothing, reason: 'settings');
    expect(banner, findsNothing, reason: 'settings');
    await tester.scrollUntilVisible(find.text('الاشتراك'), 300);
    // Built in the list's cache isn't on screen yet: bring it in first.
    await tester.ensureVisible(find.text('الاشتراك'));
    await settle(tester);
    await tester.tap(find.text('الاشتراك'));
    await settle(tester);
    expect(find.text('برو وبريميوم'), findsWidgets);
    expect(find.byType(AdSlot), findsNothing, reason: 'purchase screen');
    expect(banner, findsNothing, reason: 'purchase screen');
  });

  testWidgets('ADS-2: the slot reserves the banner\'s full height before an '
      'ad arrives, and paints nothing in it', (tester) async {
    final service = NoopAdService(consent: allowed, height: 56);
    await pumpApp(tester, withRecipe: true, adServiceOverride: service);
    // Asked for, after the space was reserved; no ad has come back.
    expect(service.requests, [360]);
    expect(banner, findsNothing);
    expect(slotHeight(tester), AdSlot.reservedHeight(56));
    expect(AdSlot.reservedHeight(56), 8 + 56 + 8 + AdSlot.targetLine);
    // Nothing painted: no text, no frame, no placeholder.
    expect(
      find.descendant(of: find.byType(AdSlot), matching: find.byType(Text)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AdSlot),
        matching: find.byWidgetPredicate(
          (w) => w is DecoratedBox || w is ColoredBox || w is Material,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('ADS-2: an arriving ad changes nothing around it', (
    tester,
  ) async {
    Future<Rect> navBarWith(bool fills) async {
      await tester.pumpWidget(const SizedBox()); // a fresh app each time
      await pumpApp(
        tester,
        withRecipe: true,
        adServiceOverride: NoopAdService(consent: allowed, fills: fills),
      );
      expect(banner, fills ? findsOneWidget : findsNothing);
      return tester.getRect(find.byType(NavPill));
    }

    final waiting = await navBarWith(false);
    final arrived = await navBarWith(true);
    expect(arrived, waiting);
    expect(slotHeight(tester), AdSlot.reservedHeight(56));
  });

  for (final product in Product.values) {
    testWidgets('PAY-1: ${product.id} takes every banner away', (tester) async {
      final service = NoopAdService(consent: allowed, fills: true);
      await pumpApp(
        tester,
        withRecipe: true,
        adServiceOverride: service,
        storeOverride: NoopPurchaseStore(owned: {product}),
      );
      expect(banner, findsNothing);
      expect(slotHeight(tester), 0);
      await tester.tap(find.text('كبسة لحم'));
      await settle(tester);
      expect(banner, findsNothing);
      expect(slotHeight(tester), 0);
      // Never asked for, and no consent form for an ad-free owner.
      expect(service.requests, isEmpty);
      expect(service.consentAsks, 0);
    });
  }

  testWidgets('PAY-6: buying Pro takes the banner away once the store '
      'confirms it, not while it\'s pending', (tester) async {
    await pumpApp(
      tester,
      withRecipe: true,
      adServiceOverride: NoopAdService(consent: allowed, fills: true),
    );
    expect(banner, findsOneWidget);
    store.emit(Product.pro, PurchaseOutcome.pending);
    await settle(tester);
    expect(banner, findsOneWidget);
    store.emit(Product.pro, PurchaseOutcome.purchased);
    await settle(tester);
    expect(banner, findsNothing);
    expect(slotHeight(tester), 0);
  });

  testWidgets('PAY-1, PAY-11: a subscription that lapsed brings the banner '
      'back when the app returns to the front', (tester) async {
    await pumpApp(
      tester,
      withRecipe: true,
      adServiceOverride: NoopAdService(consent: allowed, fills: true),
      storeOverride: NoopPurchaseStore(owned: {Product.premium}),
    );
    expect(banner, findsNothing);
    expect(purchases.aiImportQuota, 100);

    store.ownedNow = {}; // ended in Google Play
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(banner, findsOneWidget);
    expect(purchases.aiImportQuota, 10);
  });

  testWidgets('PAY-5: the slot\'s one small target opens the purchase '
      'screen, and only when there is something to sell', (tester) async {
    await pumpApp(
      tester,
      withRecipe: true,
      adServiceOverride: NoopAdService(consent: allowed, fills: true),
    );
    // PAY-6: nothing on sale: no target that could only fail.
    expect(find.text('إزالة الإعلانات'), findsNothing);

    await tester.pumpWidget(const SizedBox()); // a fresh app
    await pumpApp(
      tester,
      withRecipe: true,
      adServiceOverride: NoopAdService(consent: allowed, fills: true),
      storeOverride: NoopPurchaseStore(
        offers: const [StoreOffer(product: Product.pro, price: 'AED 14.99')],
      ),
    );
    final target = find.text('إزالة الإعلانات');
    expect(target, findsOneWidget);
    // ADS-9: 8 dp between it and the ad.
    expect(
      tester.getRect(target).bottom,
      lessThanOrEqualTo(tester.getRect(banner).top - AdSlot.gap),
    );
    await tester.tap(target);
    await settle(tester);
    expect(find.text(ownIsolate('AED 14.99')), findsOneWidget);
    expect(find.text('مرة واحدة'), findsOneWidget);
    expect(banner, findsNothing);
  });

  testWidgets('ADS-4: a fresh install asks for no ad and no consent during '
      'setup or the walkthrough; the banner comes once it\'s finished', (
    tester,
  ) async {
    final service = NoopAdService(consent: allowed, fills: true);
    await pumpApp(
      tester,
      firstRunComplete: false,
      adServiceOverride: service,
      // PAY-5: something on sale, so a slot would carry its target too.
      storeOverride: NoopPurchaseStore(
        offers: const [StoreOffer(product: Product.pro, price: 'AED 14.99')],
      ),
    );

    void nothingAsked(String where) {
      expect(service.consentAsks, 0, reason: where);
      expect(service.started, isFalse, reason: where);
      expect(service.requests, isEmpty, reason: where);
      expect(find.byType(AdSlot), findsNothing, reason: where);
      expect(find.text('إزالة الإعلانات'), findsNothing, reason: where);
    }

    // Setup (RUN-3), with the store already answered.
    expect(purchases.checked, isTrue);
    expect(find.text('متابعة'), findsOneWidget);
    nothingAsked('setup');
    await tester.tap(find.text('متابعة'));
    await settle(tester);

    // Every walkthrough page (RUN-4).
    for (var page = 1; page <= 3; page++) {
      nothingAsked('walkthrough page $page');
      await tester.tap(find.text('التالي'));
      await settle(tester);
    }
    nothingAsked('walkthrough page 4');
    await tester.tap(find.text('إلى وصفاتي'));
    await settle(tester);

    // The library: consent asked once, then the banner.
    expect(find.text('شوربة عدس'), findsOneWidget);
    expect(service.consentAsks, 1);
    expect(service.started, isTrue);
    expect(banner, findsOneWidget);
    expect(find.text('إزالة الإعلانات'), findsOneWidget);
  });

  testWidgets(
    'ADS-9/LOOK-8: the raised "+" is fully hit-testable, not just its '
    'lower half',
    (tester) async {
      await pumpApp(
        tester,
        withRecipe: true,
        adServiceOverride: NoopAdService(consent: allowed, fills: true),
      );
      final addRect = tester.getRect(find.byTooltip('أضف وصفة'));
      // A tap right at the "+"'s own top edge still opens the add sheet —
      // the raised ring is inside NavPill's hit-testable box, not overflow
      // painted outside it.
      await tester.tapAt(Offset(addRect.center.dx, addRect.top + 1));
      await settle(tester);
      expect(find.text('أضف وصفة'), findsWidgets);
    },
  );
}
