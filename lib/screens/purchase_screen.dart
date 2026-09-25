import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/quantity/arabic_text.dart' show ownIsolate;
import '../providers/purchases_state.dart';
import '../providers/settings_state.dart';
import '../services/store.dart';

/// PAY-10: opens the purchase screen. Only PAY-5's three places call it:
/// the Settings "Subscription" row, the ad slot's small "remove ads"
/// target, and the import screen's line once the free AI imports run out.
/// Never before setup and the walkthrough are finished (RUN-3, RUN-4): each
/// place already hides itself then, and this is the backstop.
Future<void> openPurchaseScreen(BuildContext context) async {
  if (!context.read<SettingsState>().settings.firstRunComplete) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const PurchaseScreen(),
    ),
  );
}

/// Pro and Premium side by side (PAY-10), each with the store's own prices
/// (PAY-2), what it includes (PAY-7), and "Owned" once bought. A close
/// button from the first frame; no crossed-out prices, countdowns, badges
/// or preselected plan, and never an ad (ADS-9).
class PurchaseScreen extends StatelessWidget {
  const PurchaseScreen({super.key});

  Future<void> _restore(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final purchases = context.watch<PurchasesState>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final failed = purchases.failed;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // PAY-10: at the top from the first frame, never delayed or hidden.
        leading: IconButton(
          tooltip: l10n.purchaseClose,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.purchaseTitle),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
        children: [
          // PAY-4: nothing that works moves behind a payment.
          Text(l10n.purchaseLead, style: text.bodyLarge),
          const SizedBox(height: 16),
          if (!purchases.offersLoaded)
            const LinearProgressIndicator()
          else if (!purchases.sellsAnything)
            // PAY-6: a store with nothing configured is a real state.
            Text(l10n.purchaseNothingYet, style: text.bodyMedium),
          const SizedBox(height: 12),
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
            Text(l10n.purchaseFailed, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 8),
          // PAY-1, PAY-10: "Restore purchases" right by the prices.
          Align(
            child: TextButton.icon(
              onPressed: () => _restore(context),
              icon: const Icon(Icons.restore),
              label: Text(l10n.purchaseRestore),
            ),
          ),
          const SizedBox(height: 8),
          // PAY-10, PAY-11: that Premium renews, and where to cancel it.
          Text(l10n.purchasePremiumRenews, style: text.bodySmall),
        ],
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
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
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

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              premium ? l10n.purchasePremium : l10n.purchasePro,
              style: text.titleMedium,
            ),
            Text(
              premium ? l10n.purchasePremiumKind : l10n.purchaseProKind,
              style: text.bodySmall,
            ),
            const SizedBox(height: 12),
            // PAY-7: what it includes.
            _Includes(l10n.purchaseNoAds),
            _Includes(l10n.purchaseAiImports(quota, settings.number(quota))),
            if (premium) _Includes(l10n.purchaseFairUse),
            const Spacer(),
            const SizedBox(height: 12),
            if (owned)
              Row(
                children: [
                  Icon(Icons.check_circle, color: scheme.primary, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.purchaseOwned,
                      style: text.titleSmall?.copyWith(color: scheme.primary),
                    ),
                  ),
                ],
              )
            else if (purchases.isPending(product))
              // PAY-6: nothing changes until the store confirms it.
              Text(l10n.purchasePending, style: text.bodySmall)
            else if (offers.isEmpty)
              // PAY-3: not sold yet — no price and no button.
              Text(l10n.purchaseComingSoon, style: text.titleSmall)
            else
              for (final offer in offers)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 8),
                  // PAY-10: every plan the same kind of button, none
                  // preselected; the label is the store's own price.
                  child: OutlinedButton(
                    // Half a phone's width each: a narrower inset than the
                    // theme's, so a price and its period fit on one line.
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => _buy(context, offer),
                    child: Text(priceLabel(offer), textAlign: TextAlign.center),
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
      ),
    );
  }
}

class _Includes extends StatelessWidget {
  const _Includes(this.line);

  final String line;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(line)),
      ],
    ),
  );
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
