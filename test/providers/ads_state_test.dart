// ADS-4, ADS-5, ADS-7: the one place that decides whether a banner slot
// fills, over the no-op ad network and store (never a real one).
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/providers/ads_state.dart';
import 'package:wasfati/providers/purchases_state.dart';
import 'package:wasfati/services/ads.dart';
import 'package:wasfati/services/store.dart';

const allowed = AdConsent(canRequestAds: true, privacyOptionsRequired: false);

Future<(AdsState, NoopAdService, PurchasesState, NoopPurchaseStore)> make({
  AdConsent consent = allowed,
  Set<Product> owned = const {},
  bool storeAnswers = true,
  String? bannerUnit = 'unit',
}) async {
  final store = NoopPurchaseStore(owned: owned);
  if (!storeAnswers) store.ownedNow = null;
  final purchases = PurchasesState(store);
  addTearDown(purchases.dispose);
  final service = NoopAdService(consent: consent, bannerUnit: bannerUnit);
  final ads = AdsState(service, purchases);
  addTearDown(ads.dispose);
  await purchases.start();
  return (ads, service, purchases, store);
}

/// Lets the consent flow (async) finish.
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('ADS-4: nothing — not even the consent form — before setup and the '
      'walkthrough are finished', () async {
    final (ads, service, _, _) = await make();
    await flush();
    expect(service.consentAsks, 0);
    expect(ads.showBanners, isFalse);

    ads.setSetupFinished(true);
    await flush();
    expect(service.consentAsks, 1);
    expect(service.started, isTrue);
    expect(ads.showBanners, isTrue);
  });

  test('ADS-4: nothing before the store has said what\'s owned', () async {
    final (ads, service, purchases, store) = await make(storeAnswers: false);
    ads.setSetupFinished(true);
    await flush();
    expect(service.consentAsks, 0);
    expect(ads.showBanners, isFalse);

    store.ownedNow = {};
    await purchases.refresh();
    await flush();
    expect(service.consentAsks, 1);
    expect(ads.showBanners, isTrue);
  });

  test('ADS-5: consent that doesn\'t allow requests, or a lookup that '
      'failed, requests nothing', () async {
    final (ads, service, _, _) = await make(consent: AdConsent.unanswered);
    ads.setSetupFinished(true);
    await flush();
    expect(service.consentAsks, 1);
    expect(service.started, isFalse);
    expect(ads.showBanners, isFalse);
    expect(ads.showPrivacyChoices, isFalse);
  });

  test(
    'ADS-5: asked once a launch, and Settings\' row changes the answer',
    () async {
      final (ads, service, _, _) = await make(
        consent: const AdConsent(
          canRequestAds: false,
          privacyOptionsRequired: true,
        ),
      );
      ads.setSetupFinished(true);
      await flush();
      ads.setSetupFinished(false);
      ads.setSetupFinished(true);
      await flush();
      expect(service.consentAsks, 1);
      expect(ads.showPrivacyChoices, isTrue);
      expect(ads.showBanners, isFalse);

      service.consent = const AdConsent(
        canRequestAds: true,
        privacyOptionsRequired: true,
      );
      await ads.changeConsent();
      expect(service.consentChanges, 1);
      expect(ads.showBanners, isTrue);
    },
  );

  test('PAY-1: Pro removes every banner, and its owner is never asked for '
      'ad consent', () async {
    final (ads, service, _, _) = await make(owned: {Product.pro});
    ads.setSetupFinished(true);
    await flush();
    expect(ads.showBanners, isFalse);
    expect(service.consentAsks, 0);
  });

  test('PAY-1: Premium removes every banner too', () async {
    final (ads, service, _, _) = await make(owned: {Product.premium});
    ads.setSetupFinished(true);
    await flush();
    expect(ads.showBanners, isFalse);
    expect(service.consentAsks, 0);
  });

  test('PAY-11: a lapsed subscription brings the banners back', () async {
    final (ads, service, purchases, store) = await make(
      owned: {Product.premium},
    );
    ads.setSetupFinished(true);
    await flush();
    expect(ads.showBanners, isFalse);

    store.ownedNow = {};
    await purchases.refresh();
    await flush();
    expect(service.consentAsks, 1);
    expect(ads.showBanners, isTrue);
  });

  test('ADS-8: a build with no ad unit never fills a slot', () async {
    final (ads, service, _, _) = await make(bannerUnit: null);
    ads.setSetupFinished(true);
    await flush();
    expect(service.consentAsks, 0);
    expect(ads.showBanners, isFalse);
  });

  test('ADS-2: the banner is measured once per width', () async {
    final (ads, _, _, _) = await make();
    expect(ads.sizeFor(360), isNull);
    await ads.measure(360);
    await ads.measure(360);
    expect(ads.sizeFor(360), const BannerDims(360, 56));
  });
}
