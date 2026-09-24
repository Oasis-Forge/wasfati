import 'package:flutter/foundation.dart';

import '../services/ads.dart';
import 'purchases_state.dart';

/// Ads (ADS-1–ADS-9): whether a banner slot fills, the network's consent
/// (ADS-5), and the banner's measured size (ADS-2). [showBanners] is the
/// one place in the code that decides whether a slot fills (ADS-7), so an
/// ad-free build and a paid ad-free app are the same code path.
class AdsState extends ChangeNotifier {
  AdsState(this._service, this._purchases) {
    _purchases.addListener(_onPurchases);
  }

  final AdService _service;
  final PurchasesState _purchases;
  bool _disposed = false;

  bool _setupFinished = false;
  AdConsent? _consent;
  bool _asking = false;
  bool _started = false;
  final _sizes = <int, BannerDims?>{};
  final _measuring = <int>{};

  /// ADS-4: whether first-run setup and the walkthrough (RUN-3, RUN-4)
  /// are finished. Nothing — not even the consent form — happens before.
  bool get setupFinished => _setupFinished;

  /// ADS-4's gate, set from the state layer (app.dart's `_PayingSync`).
  void setSetupFinished(bool finished) {
    if (finished == _setupFinished) return;
    _setupFinished = finished;
    notifyListeners();
    _maybeStart();
  }

  /// ADS-1–ADS-9, and PAY-1: a slot fills only when all of these hold —
  ///  * setup and the walkthrough are finished (ADS-4);
  ///  * the store has said what this account owns, and it's neither Pro
  ///    nor Premium (PAY-1, PAY-7);
  ///  * the network's consent has been answered and allows requests
  ///    (ADS-4, ADS-5), and the SDK has started;
  ///  * this build has an ad unit (ADS-8).
  bool get showBanners =>
      _setupFinished &&
      _purchases.checked &&
      !_purchases.adFree &&
      _started &&
      _service.bannerUnit != null;

  /// ADS-5: Settings keeps a row to change the answer, where the law asks.
  bool get showPrivacyChoices => _consent?.privacyOptionsRequired ?? false;

  /// ADS-5: the network's own form, from Settings. Refusing means
  /// non-personalised ads, never a nag or a feature withheld.
  Future<void> changeConsent() async {
    final consent = await _service.changeConsent();
    if (_disposed) return;
    _consent = consent;
    if (consent.canRequestAds && !_started) await _start();
    if (!_disposed) notifyListeners();
  }

  /// Starts the SDK; one that fails to start just shows no ads.
  Future<void> _start() async {
    try {
      await _service.start();
      _started = true;
    } on Exception {
      _started = false;
    }
  }

  void _onPurchases() {
    notifyListeners();
    _maybeStart();
  }

  /// ADS-4, ADS-5: asks for consent once, and only when an ad could
  /// actually follow — never for a Pro or Premium owner, never before the
  /// store has answered, and never before setup is finished. A lookup that
  /// fails leaves the user unasked, and nothing is requested this launch.
  Future<void> _maybeStart() async {
    if (_asking || _consent != null) return;
    if (!_setupFinished || !_purchases.checked || _purchases.adFree) return;
    if (_service.bannerUnit == null) return;
    _asking = true;
    try {
      final consent = await _service.gatherConsent();
      if (_disposed) return;
      _consent = consent;
      if (consent.canRequestAds) await _start();
    } finally {
      _asking = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// ADS-2: the banner's size at [width], once measured; null until then.
  BannerDims? sizeFor(int width) => _sizes[width];

  /// Measures the anchored adaptive banner at [width] once, before any ad
  /// is asked for, so a slot can reserve its height first (ADS-2).
  Future<void> measure(int width) async {
    if (_sizes.containsKey(width) || !_measuring.add(width)) return;
    final dims = await _service.bannerSize(width);
    _measuring.remove(width);
    if (_disposed) return;
    _sizes[width] = dims;
    notifyListeners();
  }

  /// A banner for the one ad unit (ADS-9), not yet loaded.
  BannerHandle banner(
    BannerDims size, {
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) => _service.banner(size, onLoaded: onLoaded, onFailed: onFailed);

  @override
  void dispose() {
    _disposed = true;
    _purchases.removeListener(_onPurchases);
    super.dispose();
  }
}
