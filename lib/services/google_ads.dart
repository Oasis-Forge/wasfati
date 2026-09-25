import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads.dart';

/// The real ad network: Google AdMob with its User Messaging Platform for
/// consent (ADS-5). Built only in `main.dart`; tests use [NoopAdService].
class GoogleAdService implements AdService {
  GoogleAdService() : _ids = AdIds.current;

  final AdIds? _ids;

  /// ADS-7: the one request every banner uses, and it carries nothing from
  /// the app: no keywords, no content or neighbouring links, no extras. A
  /// test checks every field stays empty. Personalisation follows the
  /// user's answer to the consent form, never a flag set here.
  static const request = AdRequest();

  @override
  String? get bannerUnit => _ids?.bannerUnit;

  @override
  Future<AdConsent> gatherConsent() async {
    try {
      final updated = await _requestConsentInfoUpdate();
      // ADS-5: a lookup that fails leaves the user unasked and requests
      // nothing — not even with an answer cached from an earlier launch.
      if (!updated) return AdConsent.unanswered;
      // Shows the network's own form only where the law asks for it (the
      // EEA, the UK, Switzerland) and only while it hasn't been answered.
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
      return await _status();
    } on PlatformException {
      return AdConsent.unanswered;
    } on MissingPluginException {
      return AdConsent.unanswered;
    }
  }

  @override
  Future<AdConsent> changeConsent() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
      return await _status();
    } on PlatformException {
      return AdConsent.unanswered;
    } on MissingPluginException {
      return AdConsent.unanswered;
    }
  }

  /// The consent SDK answers through one of two callbacks; either may
  /// fire, and only the first counts.
  Future<bool> _requestConsentInfoUpdate() {
    final done = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!done.isCompleted) done.complete(true);
      },
      (_) {
        if (!done.isCompleted) done.complete(false);
      },
    );
    return done.future;
  }

  Future<AdConsent> _status() async => AdConsent(
    canRequestAds: await ConsentInformation.instance.canRequestAds(),
    privacyOptionsRequired:
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required,
  );

  @override
  Future<void> start() async {
    await MobileAds.instance.initialize();
  }

  @override
  Future<BannerDims?> bannerSize(int width) async {
    // ADS-9: the anchored adaptive size. Not the "large" variant: a
    // BannerAd given an AnchoredAdaptiveBannerAdSize is rebuilt on Android
    // as the regular anchored adaptive size (the plugin's AdMessageCodec
    // passes isLarge = false), so this is the height the ad will really
    // have, and the slot reserves exactly that (ADS-2).
    try {
      final size =
          // ignore: deprecated_member_use
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (size == null) return null;
      return BannerDims(size.width, size.height, size);
    } on Exception {
      return null; // no size, no slot
    }
  }

  @override
  BannerHandle banner(
    BannerDims size, {
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) => _GoogleBanner(
    BannerAd(
      size:
          size.platformSize as AdSize? ??
          AdSize(width: size.width, height: size.height),
      adUnitId: bannerUnit!,
      request: request,
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        // The slot disposes the banner itself (BannerHandle.dispose).
        onAdFailedToLoad: (_, _) => onFailed(),
      ),
    ),
  );
}

class _GoogleBanner implements BannerHandle {
  _GoogleBanner(this._ad);

  final BannerAd _ad;
  bool _disposed = false;

  @override
  void load() => _ad.load();

  @override
  Widget view() => AdWidget(ad: _ad);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ad.dispose();
  }
}
