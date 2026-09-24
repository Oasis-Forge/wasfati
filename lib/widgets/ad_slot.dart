import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/ads_state.dart';
import '../providers/purchases_state.dart';
import '../screens/purchase_screen.dart';
import '../services/ads.dart';

/// The one banner slot (ADS-1–ADS-3, ADS-9), for a screen's bottom bar —
/// never its scrolling body — so it sits outside the content and above the
/// navigation bar by construction (ADS-3). Only the four screens Decision
/// 12 names build it: the library, the recipe page, the meal plan and
/// groceries.
///
/// Whether it fills is decided in one place, `AdsState.showBanners`
/// (ADS-7); when that's false this is nothing at all, no height and no
/// frame. When it's true, the slot first reserves the measured banner's
/// full height, empty and unpainted, and only then asks for an ad (ADS-2),
/// so an arriving ad never moves anything. It keeps the reservation if no
/// ad comes, and asks again a minute later.
///
/// While its route is covered by another page (TickerMode off), it lets
/// its banner go, so no ad is ever loaded where it can't be seen.
class AdSlot extends StatefulWidget {
  const AdSlot({super.key, this.aboveSystemBar = false});

  /// True where nothing else below the slot keeps it off the system
  /// navigation bar (the recipe page, which has no navigation bar of its
  /// own): the slot then adds the system bar's inset below itself, but only
  /// while it's showing (ADS-3).
  final bool aboveSystemBar;

  /// ADS-9: at least 8 dp between the ad and any button, including the
  /// content's last button above and the navigation bar below
  /// (AdMob's accidental-click policy).
  static const gap = 8.0;

  /// PAY-5: the line above the ad for the one small "remove ads" target.
  static const targetLine = 32.0;

  /// ADS-2: the height the slot reserves for an ad [adHeight] tall, before
  /// asking for it.
  static double reservedHeight(int adHeight) =>
      targetLine + gap + adHeight + gap;

  @override
  State<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends State<AdSlot> {
  BannerHandle? _banner;
  BannerDims? _dims;
  bool _loaded = false;
  bool _scheduled = false;
  Timer? _retry;

  /// The width the slot was last laid out at: the banner's width, as
  /// anchored adaptive banners are the full width they sit in.
  int? _width;

  /// Brings the banner in line with what the slot should show, after the
  /// frame that laid out its reservation (ADS-2: reserve, then ask).
  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _reconcile();
    });
  }

  void _reconcile() {
    final ads = context.read<AdsState>();
    final width = _width;
    final visible = TickerMode.valuesOf(context).enabled;
    final dims = ads.showBanners && width != null ? ads.sizeFor(width) : null;
    if (ads.showBanners && width != null && dims == null) ads.measure(width);
    if (dims == null || !visible || dims != _dims) _drop();
    if (dims == null || !visible || _banner != null || _retry != null) return;
    _dims = dims;
    late final BannerHandle banner;
    banner = ads.banner(
      dims,
      onLoaded: () {
        if (mounted && identical(_banner, banner)) {
          setState(() => _loaded = true);
        }
      },
      onFailed: () {
        if (!mounted || !identical(_banner, banner)) return;
        setState(_drop);
        _retry = Timer(const Duration(minutes: 1), () {
          _retry = null;
          if (mounted) _schedule();
        });
      },
    );
    _banner = banner..load();
  }

  void _drop() {
    _banner?.dispose();
    _banner = null;
    _loaded = false;
  }

  @override
  void dispose() {
    _retry?.cancel();
    _drop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ads = context.watch<AdsState>();
    final purchases = context.watch<PurchasesState>();
    // Also a dependency, so covering or uncovering the route rebuilds the
    // slot: the ad leaves the tree first, and is let go after this frame.
    final visible = TickerMode.valuesOf(context).enabled;
    final systemBar = widget.aboveSystemBar
        ? MediaQuery.paddingOf(context).bottom
        : 0.0;
    _schedule();
    if (!ads.showBanners) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.truncate();
        if (width != _width) {
          _width = width;
          _schedule();
        }
        final dims = ads.sizeFor(width);
        if (dims == null) return const SizedBox.shrink();
        final loaded = _loaded && visible && _banner != null && _dims == dims;
        return Padding(
          // Only while showing: an ad-free page keeps its full height.
          padding: EdgeInsets.only(bottom: systemBar),
          child: SizedBox(
            height: AdSlot.reservedHeight(dims.height),
            child: Column(
              children: [
                SizedBox(
                  height: AdSlot.targetLine,
                  // PAY-5: selling is quiet — one small target on the slot,
                  // shown with the ad and only when the store has
                  // something to sell (PAY-6).
                  child: loaded && purchases.sellsAnything
                      ? Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, AdSlot.targetLine),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 12,
                              ),
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .labelMedium,
                            ),
                            onPressed: () => openPurchaseScreen(context),
                            child: Text(l10n.adSlotRemoveAds),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: AdSlot.gap),
                SizedBox(
                  width: dims.width.toDouble(),
                  height: dims.height.toDouble(),
                  // ADS-2: nothing painted until an ad has arrived.
                  child: loaded ? _banner!.view() : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
