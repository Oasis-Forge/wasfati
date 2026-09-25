import 'dart:async';

import 'package:flutter/foundation.dart';

/// PAY-8: the store's products. The IDs are permanent after the first
/// upload, like the app ID.
enum Product {
  /// One-time: removes ads (PAY-1).
  pro('pro'),

  /// A subscription with two base plans (PAY-8): removes ads and raises the
  /// AI imports to 100 a month (PAY-7).
  premium('premium');

  const Product(this.id);

  final String id;

  static Product? fromId(String id) =>
      values.where((p) => p.id == id).firstOrNull;
}

/// PAY-8: Premium's two auto-renewing base plans. No trial and no
/// introductory offer (PAY-9, Decision 11).
enum PremiumPlan {
  monthly('monthly'),
  yearly('yearly');

  const PremiumPlan(this.id);

  final String id;

  static PremiumPlan? fromId(String id) =>
      values.where((p) => p.id == id).firstOrNull;
}

/// One thing the store sells, at the store's own price (PAY-2).
@immutable
class StoreOffer {
  const StoreOffer({
    required this.product,
    this.plan,
    required this.price,
    this.handle,
  });

  final Product product;

  /// Premium's base plan; null for Pro.
  final PremiumPlan? plan;

  /// The price exactly as the store formats it, in the buyer's currency.
  /// Never hard-coded, never converted (PAY-2).
  final String price;

  /// The store SDK's own product object, opaque outside the store adapter.
  final Object? handle;
}

/// How a purchase the store reported ended, or where it stands (PAY-6).
enum PurchaseOutcome {
  /// Waiting on a slow payment method: nothing changes until it's paid.
  pending,

  /// Paid and confirmed by the store.
  purchased,

  /// The store reported an error. Nothing was bought.
  failed,

  /// The user closed the store's sheet.
  cancelled,
}

/// One update from the store's purchase stream.
@immutable
class PurchaseUpdate {
  const PurchaseUpdate({
    required this.product,
    required this.outcome,
    required this.finish,
  });

  final Product product;
  final PurchaseOutcome outcome;

  /// PAY-6: tells the store the app is done with this purchase. Called for
  /// every update whatever its outcome; the adapter decides what, if
  /// anything, the store needs for it (acknowledging a paid one).
  final Future<void> Function() finish;
}

/// The app store (PAY-1–PAY-11), behind an interface like every device
/// service: `main.dart` builds the real one (`PlayPurchaseStore`), and
/// tests get [NoopPurchaseStore]. Nothing here ever touches the network in
/// a test.
abstract interface class PurchaseStore {
  /// Results of purchases started with [buy], and ones that finish later
  /// (a pending payment that clears).
  Stream<List<PurchaseUpdate>> get updates;

  /// PAY-2: what the store sells, at its prices. Empty when it has nothing
  /// configured, or can't sell on this device (PAY-6); null when it
  /// couldn't be asked right now.
  Future<List<StoreOffer>?> offers();

  /// PAY-1: what this store account owns right now, so a refund, a lapsed
  /// subscription or a family-shared purchase shows up without a reinstall.
  /// A pending purchase isn't owned (PAY-6). Null when the store couldn't
  /// be asked; empty when there's no store on the device to own anything.
  Future<Set<Product>?> owned();

  /// Opens the store's own purchase sheet. False if it couldn't open; the
  /// result arrives on [updates] otherwise.
  Future<bool> buy(StoreOffer offer);

  /// PAY-11: the store's own page for the Premium subscription, where it's
  /// changed or cancelled. False if it couldn't open.
  Future<bool> openSubscriptionPage();
}

/// The default in tests: no store at all. Sells [offerList] (nothing by
/// default), owns [ownedNow], and lets a test drive the purchase stream
/// with [emit]. Records what was bought, finished and opened.
class NoopPurchaseStore implements PurchaseStore {
  NoopPurchaseStore({
    Set<Product> owned = const {},
    List<StoreOffer> offers = const [],
  }) : ownedNow = {...owned},
       offerList = [...offers];

  /// What [owned] answers; null stands in for a store that can't be asked.
  Set<Product>? ownedNow;

  /// What [offers] answers; null stands in for a store that can't be asked.
  List<StoreOffer>? offerList;

  /// Whether [buy] and [openSubscriptionPage] manage to open anything.
  bool opens = true;

  final _updates = StreamController<List<PurchaseUpdate>>.broadcast();
  final bought = <StoreOffer>[];
  final finished = <(Product, PurchaseOutcome)>[];
  int ownedQueries = 0;
  int subscriptionPagesOpened = 0;

  /// Sends one purchase update, as the store would.
  void emit(Product product, PurchaseOutcome outcome) => _updates.add([
    PurchaseUpdate(
      product: product,
      outcome: outcome,
      finish: () async => finished.add((product, outcome)),
    ),
  ]);

  @override
  Stream<List<PurchaseUpdate>> get updates => _updates.stream;

  @override
  Future<List<StoreOffer>?> offers() async =>
      offerList == null ? null : [...offerList!];

  @override
  Future<Set<Product>?> owned() async {
    ownedQueries++;
    return ownedNow == null ? null : {...ownedNow!};
  }

  @override
  Future<bool> buy(StoreOffer offer) async {
    bought.add(offer);
    return opens;
  }

  @override
  Future<bool> openSubscriptionPage() async {
    subscriptionPagesOpened++;
    return opens;
  }
}
