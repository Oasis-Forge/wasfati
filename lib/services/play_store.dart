import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'store.dart';

/// The real store: Google Play Billing through `in_app_purchase`. Built
/// only in `main.dart`, and only on Android; tests use
/// [NoopPurchaseStore].
///
/// Nothing here trusts the app's own record of a purchase: what's owned is
/// asked of Play every time (PAY-1). Premium isn't checked on our import
/// server yet — that needs a Play Console service account (Decision 22).
class PlayPurchaseStore implements PurchaseStore {
  PlayPurchaseStore({InAppPurchase? iap})
    : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  /// PAY-11: a few lines of platform glue in `MainActivity.kt`, like the
  /// mail draft (Decision 19): an `ACTION_VIEW` intent for Play's own
  /// subscription page. No permission and no package.
  static const _channel = MethodChannel('com.oasisforge.wasfati/store');

  @override
  Stream<List<PurchaseUpdate>> get updates =>
      _iap.purchaseStream.asyncMap((purchases) async {
        final updates = <PurchaseUpdate>[];
        for (final p in purchases) {
          final product = Product.fromId(p.productID);
          if (product == null) {
            // Not ours to grant, but still ours to finish (PAY-6).
            await _finish(p);
            continue;
          }
          updates.add(
            PurchaseUpdate(
              product: product,
              outcome: switch (p.status) {
                PurchaseStatus.pending => PurchaseOutcome.pending,
                PurchaseStatus.purchased ||
                PurchaseStatus.restored => PurchaseOutcome.purchased,
                PurchaseStatus.error => PurchaseOutcome.failed,
                PurchaseStatus.canceled => PurchaseOutcome.cancelled,
              },
              finish: () => _finish(p),
            ),
          );
        }
        return updates;
      });

  /// PAY-6: acknowledges a paid purchase (Play refunds one left
  /// unacknowledged for three days). A pending one can't be acknowledged
  /// yet; it comes back through [updates] or [owned] once it's paid.
  Future<void> _finish(PurchaseDetails p) async {
    if (!p.pendingCompletePurchase || p.status == PurchaseStatus.pending) {
      return;
    }
    try {
      await _iap.completePurchase(p);
    } on Exception {
      // Retried at the next launch: [owned] finishes any it finds.
    }
  }

  @override
  Future<List<StoreOffer>?> offers() async {
    try {
      if (!await _iap.isAvailable()) return const [];
      final response = await _iap.queryProductDetails({
        for (final p in Product.values) p.id,
      });
      if (response.error != null && response.productDetails.isEmpty) {
        return null;
      }
      final offers = <StoreOffer>[];
      for (final details in response.productDetails) {
        final product = Product.fromId(details.id);
        if (product == null) continue;
        if (product == Product.pro) {
          offers.add(
            StoreOffer(product: product, price: details.price, handle: details),
          );
          continue;
        }
        if (details is! GooglePlayProductDetails) continue;
        final index = details.subscriptionIndex;
        final plans = details.productDetails.subscriptionOfferDetails;
        if (index == null || plans == null || index >= plans.length) continue;
        final offer = plans[index];
        // PAY-9, PAY-10: only the base plans themselves — never a trial, an
        // introductory price or any other discounted offer (offerId set).
        if (offer.offerId != null) continue;
        final plan = PremiumPlan.fromId(offer.basePlanId);
        if (plan == null) continue;
        offers.add(
          StoreOffer(
            product: product,
            plan: plan,
            price: details.price,
            handle: details,
          ),
        );
      }
      return offers;
    } on Exception {
      return null;
    }
  }

  @override
  Future<Set<Product>?> owned() async {
    try {
      // No store on the device: nothing can have been bought through it.
      if (!await _iap.isAvailable()) return const {};
      final response = await _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .queryPastPurchases();
      if (response.error != null) return null;
      final owned = <Product>{};
      for (final p in response.pastPurchases) {
        // PAY-6: a pending payment isn't owned yet.
        if (p.status != PurchaseStatus.purchased) continue;
        final product = Product.fromId(p.productID);
        if (product != null) owned.add(product);
        // PAY-6: one the app never got to finish (it closed mid-purchase).
        await _finish(p);
      }
      return owned;
    } on Exception {
      return null;
    }
  }

  @override
  Future<bool> buy(StoreOffer offer) async {
    final details = offer.handle;
    if (details is! ProductDetails) return false;
    try {
      // Play Billing buys a subscription through the same call; the base
      // plan comes from the offer's token inside [details].
      return await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> openSubscriptionPage() async {
    try {
      final opened = await _channel.invokeMethod<bool>('openSubscription', {
        'sku': Product.premium.id,
      });
      return opened ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
