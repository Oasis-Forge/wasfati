import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// ADS-8: the ad IDs one build asks with. IDs aren't secrets — they ship in
/// the binary — so they live here, in the repo; `docs/RELEASING.md` has the
/// real ones and `android/app/build.gradle.kts` puts the matching app ID
/// into the manifest per build type. `test/services/ad_ids_test.dart` fails
/// if any copy drifts from this one.
@immutable
class AdIds {
  const AdIds({required this.appId, required this.bannerUnit});

  final String appId;

  /// The one banner unit every slot uses (ADS-9).
  final String bannerUnit;

  /// Created 20 September 2026 (`docs/RELEASING.md`). Only an Android
  /// release build ever asks with these.
  static const androidRelease = AdIds(
    appId: 'ca-app-pub-8287765177319119~8706163515',
    bannerUnit: 'ca-app-pub-8287765177319119/9667891390',
  );

  /// Google's published sample IDs for Android: every other build, so a
  /// development build never serves a live ad (ADS-8).
  static const androidTest = AdIds(
    appId: 'ca-app-pub-3940256099942544~3347511713',
    bannerUnit: 'ca-app-pub-3940256099942544/9214589741',
  );

  /// Google's published sample IDs for iOS. There's no iOS ad unit of our
  /// own until Phase 6, so an iOS release asks for no ads at all.
  static const iosTest = AdIds(
    appId: 'ca-app-pub-3940256099942544~1458002511',
    bannerUnit: 'ca-app-pub-3940256099942544/2435281174',
  );

  /// The IDs this build uses, or null when it has no ad unit. `kReleaseMode`
  /// is a compile-time constant, so a release build carries only
  /// [releaseFor]'s IDs and a debug or profile build only [testFor]'s: the
  /// other branch is compiled out, and the release workflow checks the
  /// built APK for Google's test publisher ID (ADS-8).
  static AdIds? get current => kReleaseMode
      ? releaseFor(defaultTargetPlatform)
      : testFor(defaultTargetPlatform);

  /// A release build's IDs on [platform].
  static AdIds? releaseFor(TargetPlatform platform) =>
      platform == TargetPlatform.android ? androidRelease : null;

  /// Every other build's IDs on [platform].
  static AdIds? testFor(TargetPlatform platform) => switch (platform) {
    TargetPlatform.android => androidTest,
    TargetPlatform.iOS => iosTest,
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is AdIds && other.appId == appId && other.bannerUnit == bannerUnit;

  @override
  int get hashCode => Object.hash(appId, bannerUnit);
}

/// What the network's consent flow answered (ADS-5).
@immutable
class AdConsent {
  const AdConsent({
    required this.canRequestAds,
    required this.privacyOptionsRequired,
  });

  /// ADS-5: a lookup that failed leaves the user unasked, and nothing is
  /// requested.
  static const unanswered = AdConsent(
    canRequestAds: false,
    privacyOptionsRequired: false,
  );

  /// Whether ads may be asked for at all. Refusing personalised ads still
  /// allows non-personalised ones; the network decides which it serves.
  final bool canRequestAds;

  /// Whether the law asks for a Settings row to change the answer later
  /// (the EEA, the UK, Switzerland).
  final bool privacyOptionsRequired;
}

/// A banner's size in logical pixels, measured before it's asked for, so
/// the slot can reserve exactly that much (ADS-2). [platformSize] is the
/// ad SDK's own size object, opaque here.
@immutable
class BannerDims {
  const BannerDims(this.width, this.height, [this.platformSize]);

  final int width;
  final int height;
  final Object? platformSize;

  @override
  bool operator ==(Object other) =>
      other is BannerDims && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// One banner from the ad SDK: loaded once, shown once it has an ad, and
/// disposed when its slot no longer wants it.
abstract interface class BannerHandle {
  /// Asks the network for an ad. Exactly one of the callbacks given to
  /// [AdService.banner] answers.
  void load();

  /// The ad itself; only built after the load callback said it loaded.
  Widget view();

  void dispose();
}

/// The ad network (ADS-1–ADS-9), behind an interface like every device
/// service: `main.dart` builds the real one (`GoogleAdService`), and tests
/// get [NoopAdService]. The app hands it nothing (ADS-7): no keywords, no
/// content links, no user records.
abstract interface class AdService {
  /// ADS-8: the banner unit this build asks with, or null when it has none
  /// (an iOS release until Phase 6), in which case no slot ever fills.
  String? get bannerUnit;

  /// ADS-5: asks the network whether consent is needed, shows its own form
  /// where the law asks for it, and returns the answer. Never throws: a
  /// lookup that fails returns [AdConsent.unanswered].
  Future<AdConsent> gatherConsent();

  /// ADS-5: Settings' row, the network's own form to change the answer.
  Future<AdConsent> changeConsent();

  /// Starts the SDK. Called once, only after consent allows requests.
  Future<void> start();

  /// The anchored adaptive banner's size at [width] (ADS-9), or null when
  /// the SDK has none for this screen.
  Future<BannerDims?> bannerSize(int width);

  /// A banner of [size] for [bannerUnit], not yet loaded.
  BannerHandle banner(
    BannerDims size, {
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  });
}

/// What [NoopAdService]'s banner shows once it has "loaded", so a test can
/// see which screens carry a filled slot.
const noopBannerKey = ValueKey('noop-banner');

/// The default in tests: no network, no SDK, and by default no consent, so
/// no slot ever fills. A test that wants banners passes [consent] allowing
/// requests and, to see them arrive, [fills]. Records every banner asked
/// for.
class NoopAdService implements AdService {
  NoopAdService({
    this.consent = AdConsent.unanswered,
    this.fills = false,
    this.height = 56,
    this.bannerUnit = 'noop-banner-unit',
  });

  AdConsent consent;

  /// Whether a banner "loads" (at once) or is never answered, which is the
  /// state ADS-2's reserved height is for.
  bool fills;

  final int height;

  @override
  final String? bannerUnit;

  /// How many consent flows were started (ADS-4, ADS-5).
  int consentAsks = 0;
  int consentChanges = 0;
  bool started = false;

  /// Every banner asked for, by width.
  final requests = <int>[];

  @override
  Future<AdConsent> gatherConsent() async {
    consentAsks++;
    return consent;
  }

  @override
  Future<AdConsent> changeConsent() async {
    consentChanges++;
    return consent;
  }

  @override
  Future<void> start() async => started = true;

  @override
  Future<BannerDims?> bannerSize(int width) async => BannerDims(width, height);

  @override
  BannerHandle banner(
    BannerDims size, {
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) => _NoopBanner(this, size, onLoaded);
}

class _NoopBanner implements BannerHandle {
  _NoopBanner(this._service, this._size, this._onLoaded);

  final NoopAdService _service;
  final BannerDims _size;
  final VoidCallback _onLoaded;
  bool _disposed = false;

  @override
  void load() {
    _service.requests.add(_size.width);
    if (!_service.fills) return;
    scheduleMicrotask(() {
      if (!_disposed) _onLoaded();
    });
  }

  @override
  Widget view() => const SizedBox.expand(key: noopBannerKey);

  @override
  void dispose() => _disposed = true;
}
