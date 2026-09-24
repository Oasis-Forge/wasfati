// ADS-1–ADS-9 on screen: one banner slot on exactly the four screens
// Decision 12 names, nowhere else; its reserved height; and Pro or Premium
// taking every banner away. Over the no-op ad network and store.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/services/ads.dart';
import 'package:wasfati/services/store.dart';
import 'package:wasfati/widgets/ad_slot.dart';

import 'app_test.dart' show purchases, pumpApp, settle, store;

const allowed = AdConsent(canRequestAds: true, privacyOptionsRequired: false);

/// The banner, once it has arrived.
final banner = find.byKey(noopBannerKey);

/// The shell's own tabs, scoped to the NavigationBar (the recipe and plan
/// pages carry the same icons in their app bars).
Finder navTab(IconData icon) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.byIcon(icon),
);

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
    expect(
      tester.getRect(banner).bottom + AdSlot.gap,
      tester.getRect(find.byType(NavigationBar)).top,
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
    // ADS-9: "ابدأ الطبخ", scrolled as far down as it goes, keeps 8 dp.
    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await settle(tester);
    final start = find.byIcon(Icons.soup_kitchen_outlined);
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
    await tester.tap(find.byType(BackButton).first);
    await settle(tester);
    expect(banner, findsOneWidget, reason: 'back on the library');

    // Import.
    await tester.tap(find.byTooltip('استيراد من رابط'));
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
      return tester.getRect(find.byType(NavigationBar));
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
    expect(find.text('AED 14.99 مرة واحدة'), findsOneWidget);
    expect(banner, findsNothing);
  });
}
