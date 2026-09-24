import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';

/// The store's own in-app review prompt (RUN-5). The store decides whether
/// it actually appears — it keeps its own quota — and never says what the
/// user did, so this returns nothing.
abstract interface class StoreReview {
  Future<void> request();
}

/// The default in tests: asks no store, and counts every request.
class NoopStoreReview implements StoreReview {
  int requests = 0;

  @override
  Future<void> request() async => requests++;
}

/// The real prompt, through `in_app_review`; built only in `main.dart`.
/// A phone without the store (or a store too old for in-app review) gets
/// nothing: never an error, and never a fallback to the store listing.
class DeviceStoreReview implements StoreReview {
  const DeviceStoreReview();

  @override
  Future<void> request() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } on PlatformException {
      // No store, or it refused: nothing to show, nothing to retry.
    } on MissingPluginException {
      // Not on a platform the plugin supports.
    }
  }
}
