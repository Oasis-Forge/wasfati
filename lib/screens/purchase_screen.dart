import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/quantity/arabic_text.dart' show ownIsolate;
import '../providers/purchases_state.dart';
import '../providers/settings_state.dart';
import '../services/store.dart';
import '../theme/decor.dart';
import '../widgets/round_icon_button.dart';
import '../widgets/sufra_card.dart';

/// PAY-10: opens the purchase screen. Only PAY-5's places call it:
/// Settings (its Pro card and PAY-11's "Subscription" row), the ad slot's
/// small "remove ads" target, and the import screen's line once the free
/// AI imports run out. Never before setup and the walkthrough are finished
/// (RUN-3, RUN-4): each place already hides itself then, and this is the
/// backstop.
Future<void> openPurchaseScreen(BuildContext context) async {
  if (!context.read<SettingsState>().settings.firstRunComplete) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const PurchaseScreen(),
    ),
  );
}

/// PAY-1: asks the store what this account owns, and says what it found.
/// From the purchase screen, beside the prices, and from Settings.
Future<void> restorePurchases(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final result = await context.read<PurchasesState>().restore();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(switch (result) {
          RestoreResult.restored => l10n.purchaseRestored,
          RestoreResult.nothingOwned => l10n.purchaseNothingToRestore,
          RestoreResult.unreachable => l10n.purchaseStoreUnreachable,
        }),
      ),
    );
}

/// Pro and Premium side by side (PAY-10), each on its own card with the
/// store's own prices (PAY-2), what it includes (PAY-7), and "Owned" once
/// bought. A close button from the first frame; no crossed-out prices,
/// countdowns, badges or preselected plan — every price the same outlined
/// button — and never an ad (ADS-9).
class PurchaseScreen extends StatelessWidget {
  const PurchaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final purchases = context.watch<PurchasesState>();
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final cs = theme.colorScheme;
    final decor = Decor.of(context);
    final failed = purchases.failed;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PAY-10: at the top from the first frame, never delayed or
            // hidden — outside the scrolling content, so it never scrolls
            // away either.
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                decor.gutter - 2,
                8,
                decor.gutter,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: RoundIconButton(
                  icon: Icons.close,
                  tooltip: l10n.purchaseClose,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  decor.gutter,
                  8,
                  decor.gutter,
                  32,
                ),
                children: [
                  // A full-screen route with no app bar: its title names
                  // the route for TalkBack, as an AppBar title would.
                  Semantics(
                    header: true,
                    namesRoute: true,
                    child: Text(l10n.purchaseTitle, style: text.headlineMedium),
                  ),
                  const SizedBox(height: 4),
                  // PAY-4: nothing that works moves behind a payment.
                  Text(
                    l10n.purchaseLead,
                    style: text.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  if (!purchases.offersLoaded)
                    const Padding(
                      padding: EdgeInsetsDirectional.only(bottom: 16),
                      child: LinearProgressIndicator(),
                    )
                  else if (!purchases.sellsAnything)
                    // PAY-6: a store with nothing configured is a real state.
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 16),
                      child: SufraCard(
                        color: decor.sunk,
                        padding: const EdgeInsetsDirectional.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.purchaseNothingYet,
                                style: text.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // PAY-10: side by side, the same size and weight.
                  const IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _TierCard(product: Product.pro)),
                        SizedBox(width: 12),
                        Expanded(child: _TierCard(product: Product.premium)),
                      ],
                    ),
                  ),
                  if (failed != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.purchaseFailed,
                      style: text.bodyMedium?.copyWith(color: cs.error),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // PAY-1, PAY-10: "Restore purchases" right by the prices.
                  Align(
                    child: TextButton.icon(
                      onPressed: () => restorePurchases(context),
                      icon: const Icon(Icons.restore),
                      label: Text(l10n.purchaseRestore),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // PAY-10, PAY-11: that Premium renews, and where to cancel it.
                  Text(
                    l10n.purchasePremiumRenews,
                    style: text.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One product's card (PAY-7, PAY-10).
class _TierCard extends StatelessWidget {
  const _TierCard({required this.product});

  final Product product;

  Future<void> _buy(BuildContext context, StoreOffer offer) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final opened = await context.read<PurchasesState>().buy(offer);
    if (opened) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.purchaseStoreUnreachable)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final purchases = context.watch<PurchasesState>();
    final settings = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final cs = theme.colorScheme;
    final premium = product == Product.premium;
    final owned = premium ? purchases.ownsPremium : purchases.ownsPro;
    final quota = premium
        ? PurchasesState.premiumAiImportsPerMonth
        : SettingsState.freeAiImportsPerMonth;
    final offers = premium
        ? [
            for (final plan in PremiumPlan.values)
              ?purchases.offerFor(product, plan: plan),
          ]
        : [?purchases.offerFor(product)];

    // PAY-2: the store's price exactly as the store wrote it, never
    // re-digited: its "." may group thousands ("Rp 329.000"), which the
    // Arabic decimal mark would turn into 329 point 000. Isolated in its
    // own direction (LANG-5), so "AED" stays on the same side of the number
    // whatever the text around it.
    String priceLabel(StoreOffer offer) {
      final price = ownIsolate(offer.price);
      return switch (offer.plan) {
        null => l10n.purchasePriceOnce(price),
        PremiumPlan.monthly => l10n.purchasePriceMonthly(price),
        PremiumPlan.yearly => l10n.purchasePriceYearly(price),
      };
    }

    String period(StoreOffer offer) => switch (offer.plan) {
      null => l10n.purchasePeriodOnce,
      PremiumPlan.monthly => l10n.purchasePeriodMonthly,
      PremiumPlan.yearly => l10n.purchasePeriodYearly,
    };

    return SufraCard(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: premium ? cs.secondaryContainer : cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                premium ? Icons.workspace_premium_outlined : Icons.auto_awesome,
                size: 22,
                color: premium
                    ? cs.onSecondaryContainer
                    : cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            premium ? l10n.purchasePremium : l10n.purchasePro,
            style: text.headlineSmall,
          ),
          Text(
            premium ? l10n.purchasePremiumKind : l10n.purchaseProKind,
            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          // PAY-7: what it includes.
          _Includes(l10n.purchaseNoAds),
          _Includes(l10n.purchaseAiImports(quota, settings.number(quota))),
          if (premium) _Includes(l10n.purchaseFairUse),
          const Spacer(),
          const SizedBox(height: 12),
          if (owned)
            DecoratedBox(
              decoration: ShapeDecoration(
                color: cs.secondaryContainer,
                shape: const StadiumBorder(),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: cs.onSecondaryContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.purchaseOwned,
                        style: text.labelLarge?.copyWith(
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (purchases.isPending(product))
            // PAY-6: nothing changes until the store confirms it.
            Text(l10n.purchasePending, style: text.bodyMedium)
          else if (offers.isEmpty)
            // PAY-3: not sold yet — no price and no button.
            Text(
              l10n.purchaseComingSoon,
              style: text.titleSmall?.copyWith(color: cs.onSurfaceVariant),
            )
          else
            for (final offer in offers)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                // PAY-10: every plan the same kind of button, none
                // preselected; the label is the store's own price.
                child: OutlinedButton(
                  // Two lines on purpose, the store's price over its
                  // period, so every pill is the same height whatever the
                  // currency (PAY-2: "Rp 329.000", "US$") and the width
                  // (LOOK-8's 360dp at 1.3x). Read aloud as one phrase.
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => _buy(context, offer),
                  child: Semantics(
                    label: priceLabel(offer),
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // A long store price shrinks to fit rather
                          // than clip or wrap (LOOK-7's rule), inside a
                          // fixed line box, so the pill's height never
                          // changes with the currency or the script.
                          _PillLine(ownIsolate(offer.price), text.labelLarge!),
                          _PillLine(period(offer), text.labelSmall!),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          if (premium && owned) ...[
            const SizedBox(height: 8),
            // PAY-11: where to cancel, from here too.
            TextButton(
              onPressed: () => manageSubscription(context),
              child: Text(l10n.purchaseManage, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }
}

/// One line of a price pill: a fixed-height line box whose text scales
/// down to fit the width, never wrapping or clipping. [size] gives the
/// size and weight; the colour stays the button's own.
class _PillLine extends StatelessWidget {
  const _PillLine(this.text, this.size);

  final String text;
  final TextStyle size;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        fontSize: size.fontSize,
        fontWeight: size.fontWeight,
        height: size.height,
        letterSpacing: size.letterSpacing,
      ),
    );
    final height =
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 14) *
        (style.height ?? 1.4);
    return SizedBox(
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: style,
          strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
          maxLines: 1,
        ),
      ),
    );
  }
}

class _Includes extends StatelessWidget {
  const _Includes(this.line);

  final String line;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 3),
            child: Icon(Icons.check, size: 18, color: cs.secondary),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(line)),
        ],
      ),
    );
  }
}

/// PAY-11: "Manage or cancel" opens Google Play's page for the
/// subscription — one tap from Settings, and Play's own cancel is the
/// second.
Future<void> manageSubscription(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final opened = await context.read<PurchasesState>().manageSubscription();
  if (opened) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.purchaseManageFailed)));
}
