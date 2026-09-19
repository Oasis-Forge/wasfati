import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/recipes_state.dart';

/// The recipe list. Phase 1 shows the count or the empty state (RUN-1);
/// the list itself comes with Phase 2a.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<RecipesState>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: !state.loaded
          ? const Center(child: CircularProgressIndicator())
          : state.recipes.isEmpty
          ? _Empty(l10n: l10n)
          : Center(child: Text(l10n.recipesCount(state.recipes.length))),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.recipesEmptyTitle,
              style: text.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.recipesEmptyBody,
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: null, // the editor comes with Phase 2a
              icon: const Icon(Icons.add),
              label: Text(l10n.recipesAdd),
            ),
          ],
        ),
      ),
    );
  }
}
