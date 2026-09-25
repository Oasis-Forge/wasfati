import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/store.dart';
import 'settings_state.dart';

/// What the store account owns, as the Settings row names it (PAY-11).
enum Tier { free, pro, premium, proAndPremium }

/// What "Restore purchases" found (PAY-1).
enum RestoreResult {
  /// The store answered, and this account owns Pro, Premium or both.
  restored,

  /// The store answered: nothing is owned on this account.
  nothingOwned,

  /// The store couldn't be asked; nothing changed.
  unreachable,
}

/// Pro and Premium (PAY-1–PAY-11): what's owned, what's sold at which
/// store price, and purchases in flight. The entitlements live here and
/// only here: [adFree] is what the ad slots read (through `AdsState`), and
/// [aiImportQuota] what the import screens read (PAY-7).
class PurchasesState extends ChangeNotifier {
  PurchasesState(this._store);

  final PurchaseStore _store;
  StreamSubscription<List<PurchaseUpdate>>? _subscription;
  bool _disposed = false;

  /// PAY-7: Premium's AI imports a calendar month (fair use, SRV-4).
  static const premiumAiImportsPerMonth = 100;

  Set<Product> _owned = const {};
  bool _checked = false;
  List<StoreOffer>? _offers;
  bool _offersLoaded = false;
  final _pending = <Product>{};
  Product? _failed;

  /// Counts purchases confirmed through the stream, so a [refresh] that was
  /// already asking the store when one landed doesn't undo it.
  int _confirmed = 0;

  /// Whether the store has told this launch what's owned. Until it has, no
  /// ad is asked for (`AdsState`), so a paying user never sees one because
  /// the store was slow to answer — or couldn't be asked at all.
  bool get checked => _checked;

  bool get ownsPro => _owned.contains(Product.pro);
  bool get ownsPremium => _owned.contains(Product.premium);

  /// PAY-1, PAY-7: Pro or Premium removes every banner.
  bool get adFree => ownsPro || ownsPremium;

  /// PAY-7: 100 AI imports a month with Premium, the free 10 otherwise.
  /// The month's count is the same either way (PAY-11): 12 used stays 12
  /// used, of 100 or of 10.
  int get aiImportQuota => ownsPremium
      ? premiumAiImportsPerMonth
      : SettingsState.freeAiImportsPerMonth;

  Tier get tier => switch ((ownsPro, ownsPremium)) {
    (false, false) => Tier.free,
    (true, false) => Tier.pro,
    (false, true) => Tier.premium,
    (true, true) => Tier.proAndPremium,
  };

  /// Whether the store's catalogue has been asked for yet.
  bool get offersLoaded => _offersLoaded;

  /// PAY-2: the store's offers, Pro first, then Premium monthly and yearly.
  List<StoreOffer> get offers => _offers ?? const [];

  /// PAY-6: nothing configured (or no store) is a real state: nothing to
  /// sell, so no button that could only fail.
  bool get sellsAnything => offers.isNotEmpty;

  StoreOffer? offerFor(Product product, {PremiumPlan? plan}) =>
      offers.where((o) => o.product == product && o.plan == plan).firstOrNull;

  /// Premium can be bought on this device right now (PAY-5's quota line).
  bool get sellsPremium => offers.any((o) => o.product == Product.premium);

  /// PAY-6: bought, and waiting on the store to confirm the payment.
  bool isPending(Product product) => _pending.contains(product);

  /// The product whose last purchase the store reported as failed, until
  /// the next attempt.
  Product? get failed => _failed;

  /// Listens to the store, asks what's owned, then what's sold. Called once
  /// at launch (`main.dart`); [refresh] runs again when the app comes back
  /// to the front.
  Future<void> start() async {
    _subscription ??= _store.updates.listen(_onUpdates);
    await refresh();
    await loadOffers();
  }

  /// PAY-1: asks the store what this account owns now, so a refund, a
  /// lapsed subscription or a family-shared purchase lands without a
  /// reinstall. Returns false when the store couldn't be asked, which
  /// leaves everything as it was.
  Future<bool> refresh() async {
    final confirmedBefore = _confirmed;
    final owned = await _store.owned();
    if (_disposed || owned == null) return false;
    // A purchase confirmed while the store was being asked is newer than
    // this answer, so it stays.
    _owned = _confirmed == confirmedBefore
        ? Set.unmodifiable(owned)
        : Set.unmodifiable({..._owned, ...owned});
    _checked = true;
    notifyListeners();
    return true;
  }

  /// "Restore purchases" beside the prices (PAY-1, PAY-10).
  Future<RestoreResult> restore() async {
    if (!await refresh()) return RestoreResult.unreachable;
    return _owned.isEmpty ? RestoreResult.nothingOwned : RestoreResult.restored;
  }

  /// PAY-2: the store's catalogue. A store that couldn't be asked keeps
  /// what was loaded before.
  Future<void> loadOffers() async {
    final offers = await _store.offers();
    if (_disposed) return;
    if (offers != null) {
      final sorted = [...offers]
        ..sort((a, b) {
          final byProduct = a.product.index.compareTo(b.product.index);
          if (byProduct != 0) return byProduct;
          return (a.plan?.index ?? -1).compareTo(b.plan?.index ?? -1);
        });
      _offers = List.unmodifiable(sorted);
    }
    _offersLoaded = true;
    notifyListeners();
  }

  /// Opens the store's purchase sheet for [offer]. Nothing changes here
  /// until the store confirms it (PAY-6). False if the sheet couldn't open.
  Future<bool> buy(StoreOffer offer) async {
    if (_failed != null) {
      _failed = null;
      notifyListeners();
    }
    return _store.buy(offer);
  }

  /// PAY-11: Google Play's page for the subscription, where it's managed
  /// or cancelled. False if it couldn't open.
  Future<bool> manageSubscription() => _store.openSubscriptionPage();

  Future<void> _onUpdates(List<PurchaseUpdate> updates) async {
    for (final update in updates) {
      if (_disposed) return;
      switch (update.outcome) {
        case PurchaseOutcome.pending:
          // PAY-6: the slots stay as they were until it's paid.
          _pending.add(update.product);
        case PurchaseOutcome.purchased:
          _pending.remove(update.product);
          _owned = Set.unmodifiable({..._owned, update.product});
          _confirmed++;
          _checked = true;
          if (_failed == update.product) _failed = null;
        case PurchaseOutcome.failed:
          _pending.remove(update.product);
          _failed = update.product;
        case PurchaseOutcome.cancelled:
          _pending.remove(update.product);
      }
      notifyListeners();
      // PAY-6: every purchase is finished with the store, whatever its
      // outcome, and only after what it grants is already in place.
      await update.finish();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
