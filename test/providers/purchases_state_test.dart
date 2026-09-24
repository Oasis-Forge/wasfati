// PAY-1–PAY-11: what the store account owns, what it sells, and purchases
// in flight — all through the no-op store, never a real one.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/providers/purchases_state.dart';
import 'package:wasfati/services/store.dart';

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

Future<(PurchasesState, NoopPurchaseStore)> started({
  Set<Product> owned = const {},
  List<StoreOffer> offers = const [],
}) async {
  final store = NoopPurchaseStore(owned: owned, offers: offers);
  final state = PurchasesState(store);
  addTearDown(state.dispose);
  await state.start();
  return (state, store);
}

/// A store whose "what's owned" answer arrives only when a test says so.
class _HeldStore extends NoopPurchaseStore {
  Completer<void>? hold;

  @override
  Future<Set<Product>?> owned() async {
    final answer = await super.owned();
    await hold?.future;
    return answer;
  }
}

/// Lets the broadcast stream deliver and the state finish each update.
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('free: ads, 10 AI imports, and the store was asked at launch', () async {
    final (state, store) = await started();
    expect(store.ownedQueries, 1);
    expect(state.checked, isTrue);
    expect(state.tier, Tier.free);
    expect(state.adFree, isFalse);
    expect(state.aiImportQuota, 10);
  });

  test('PAY-1, PAY-7: Pro removes ads and keeps 10 AI imports', () async {
    final (state, _) = await started(owned: {Product.pro});
    expect(state.tier, Tier.pro);
    expect(state.adFree, isTrue);
    expect(state.aiImportQuota, 10);
  });

  test(
    'PAY-1, PAY-7: Premium removes ads and raises AI imports to 100',
    () async {
      final (state, _) = await started(owned: {Product.premium});
      expect(state.tier, Tier.premium);
      expect(state.adFree, isTrue);
      expect(state.aiImportQuota, 100);
    },
  );

  test('PAY-7: both can be owned together', () async {
    final (state, _) = await started(owned: {Product.pro, Product.premium});
    expect(state.tier, Tier.proAndPremium);
    expect(state.aiImportQuota, 100);
  });

  test('PAY-1, PAY-11: a lapsed subscription brings the ads back and the '
      'quota down to 10 at the next check', () async {
    final (state, store) = await started(owned: {Product.premium});
    expect(state.adFree, isTrue);
    store.ownedNow = {}; // Play: Premium ended, or was refunded
    expect(await state.refresh(), isTrue);
    expect(state.adFree, isFalse);
    expect(state.aiImportQuota, 10);
    expect(state.tier, Tier.free);
  });

  test('PAY-1: a family-shared purchase lands without a reinstall', () async {
    final (state, store) = await started();
    store.ownedNow = {Product.pro};
    await state.refresh();
    expect(state.ownsPro, isTrue);
  });

  test('a store that can\'t be asked changes nothing, and never counts as '
      'checked', () async {
    final store = NoopPurchaseStore(owned: {Product.pro})..ownedNow = null;
    final state = PurchasesState(store);
    addTearDown(state.dispose);
    await state.start();
    // No answer: not "free with ads" — ads wait for a real answer.
    expect(state.checked, isFalse);
    store.ownedNow = {Product.pro};
    await state.refresh();
    expect(state.checked, isTrue);
    expect(state.ownsPro, isTrue);
    store.ownedNow = null;
    expect(await state.refresh(), isFalse);
    expect(state.ownsPro, isTrue); // kept, not dropped
  });

  group('PAY-1: restore', () {
    test('finds what the account owns', () async {
      final (state, store) = await started();
      store.ownedNow = {Product.premium};
      expect(await state.restore(), RestoreResult.restored);
      expect(state.ownsPremium, isTrue);
    });

    test('says so when there\'s nothing to restore', () async {
      final (state, _) = await started();
      expect(await state.restore(), RestoreResult.nothingOwned);
    });

    test('says so when the store can\'t be reached', () async {
      final (state, store) = await started(owned: {Product.pro});
      store.ownedNow = null;
      expect(await state.restore(), RestoreResult.unreachable);
      expect(state.ownsPro, isTrue);
    });
  });

  group('PAY-2, PAY-6: what the store sells', () {
    test(
      'prices are the store\'s own, Pro first then monthly and yearly',
      () async {
        final (state, _) = await started(offers: [yearly, proOffer, monthly]);
        expect(state.offersLoaded, isTrue);
        expect(state.offers.map((o) => o.price), [
          'AED 14.99',
          'AED 9.99',
          'AED 79.99',
        ]);
        expect(
          state.offerFor(Product.premium, plan: PremiumPlan.yearly),
          yearly,
        );
        expect(state.sellsPremium, isTrue);
      },
    );

    test('nothing configured is nothing to sell', () async {
      final (state, _) = await started();
      expect(state.offersLoaded, isTrue);
      expect(state.sellsAnything, isFalse);
      expect(state.sellsPremium, isFalse);
    });
  });

  group('PAY-6: a purchase', () {
    test('changes nothing while pending, grants once paid, and is finished '
        'with the store whatever the outcome', () async {
      final (state, store) = await started(offers: [proOffer]);
      expect(await state.buy(proOffer), isTrue);
      expect(store.bought, [proOffer]);

      store.emit(Product.pro, PurchaseOutcome.pending);
      await flush();
      expect(state.isPending(Product.pro), isTrue);
      expect(state.adFree, isFalse); // the slots stay as they were

      store.emit(Product.pro, PurchaseOutcome.purchased);
      await flush();
      expect(state.isPending(Product.pro), isFalse);
      expect(state.adFree, isTrue);

      expect(store.finished, [
        (Product.pro, PurchaseOutcome.pending),
        (Product.pro, PurchaseOutcome.purchased),
      ]);
    });

    test(
      'a failure is shown until the next attempt, and still finished',
      () async {
        final (state, store) = await started(offers: [monthly]);
        await state.buy(monthly);
        store.emit(Product.premium, PurchaseOutcome.failed);
        await flush();
        expect(state.failed, Product.premium);
        expect(state.ownsPremium, isFalse);
        expect(store.finished.single, (
          Product.premium,
          PurchaseOutcome.failed,
        ));

        await state.buy(monthly);
        expect(state.failed, isNull);
        store.emit(Product.premium, PurchaseOutcome.cancelled);
        await flush();
        expect(state.failed, isNull);
        expect(state.ownsPremium, isFalse);
        expect(store.finished, hasLength(2));
      },
    );

    test("a check already under way doesn't undo a purchase that lands "
        'during it', () async {
      final store = _HeldStore();
      final state = PurchasesState(store);
      addTearDown(state.dispose);
      await state.start();
      store.hold = Completer<void>();
      final checking = state.refresh(); // asked before Pro was bought
      store.emit(Product.pro, PurchaseOutcome.purchased);
      await flush();
      expect(state.ownsPro, isTrue);
      store.hold!.complete(); // the store's older answer: nothing owned
      await checking;
      expect(state.ownsPro, isTrue);
    });

    test('a store sheet that won\'t open says so', () async {
      final (state, store) = await started(offers: [proOffer]);
      store.opens = false;
      expect(await state.buy(proOffer), isFalse);
    });
  });

  test(
    'PAY-11: "Manage or cancel" opens the store\'s subscription page',
    () async {
      final (state, store) = await started(owned: {Product.premium});
      expect(await state.manageSubscription(), isTrue);
      expect(store.subscriptionPagesOpened, 1);
    },
  );
}
