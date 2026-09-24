import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/quantity/format.dart';
import '../models/settings.dart' show appLanguage;
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../widgets/ornament.dart';
import '../widgets/pressable_slab.dart';
import 'walkthrough_screen.dart';

/// The first launch (RUN-3, RUN-4): setup, then the walkthrough, then the
/// library. Shown only while `firstRunComplete` is false; once the
/// walkthrough is finished or skipped, the app's root swaps this for the
/// library, and it never shows on its own again.
class FirstRunFlow extends StatefulWidget {
  const FirstRunFlow({super.key});

  @override
  State<FirstRunFlow> createState() => _FirstRunFlowState();
}

class _FirstRunFlowState extends State<FirstRunFlow> {
  bool _setupDone = false;
  bool _finishing = false;

  /// RUN-6: the sample is offered as the walkthrough ends (Skip or its last
  /// button), in the language the first run ends in, just before the
  /// library it ends in. Never sooner: back from the walkthrough, or a
  /// relaunch part-way through it, reopens setup, where the language can
  /// still change, and the sample is offered only once.
  Future<void> _finish() async {
    if (_finishing) return; // a double tap offers it once
    _finishing = true;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final recipes = context.read<RecipesState>();
    final settings = context.read<SettingsState>();
    try {
      await recipes.addSampleOnFirstRun(arabic: arabic);
      await settings.completeFirstRun();
    } finally {
      _finishing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_setupDone) {
      return SetupScreen(onContinue: () => setState(() => _setupDone = true));
    }
    // Back from the walkthrough returns to setup, not out of the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _setupDone = false);
      },
      child: WalkthroughScreen(onDone: _finish),
    );
  }
}

/// RUN-3: one page asking only what the device can't tell — the language
/// and the digit style — each with the device's own answer already chosen.
/// No account, no profiling question, no permission, no paywall and no
/// review request. Every choice applies at once (LANG-1), so the page
/// itself switches language as it's tapped.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final device = WidgetsBinding.instance.platformDispatcher.locales;
    final language = appLanguage(state.settings.language, device).languageCode;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 32, 24, 16),
                children: [
                  const Center(child: Ornament(size: 96, opacity: 0.12)),
                  const SizedBox(height: 16),
                  Text(
                    l10n.setupTitle,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.setupBody,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _SetupChoice<String>(
                    title: l10n.settingsLanguage,
                    value: language,
                    // Each language in its own name (LANG-1).
                    options: const {'ar': 'العربية', 'en': 'English'},
                    onChanged: (code) =>
                        state.chooseSetupLanguage(code, device),
                  ),
                  const SizedBox(height: 24),
                  _SetupChoice<DigitStyle>(
                    title: l10n.settingsDigits,
                    value: state.settings.digits,
                    options: const {
                      DigitStyle.western: '123',
                      DigitStyle.arabic: '١٢٣',
                    },
                    onChanged: state.chooseDigits,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: PressableSlab(
                  child: FilledButton(
                    onPressed: onContinue,
                    child: Text(l10n.setupContinue),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A heading and two side-by-side answers, the chosen one marked.
class _SetupChoice<T> extends StatelessWidget {
  const _SetupChoice({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [
            for (final e in options.entries)
              ButtonSegment<T>(value: e.key, label: Text(e.value)),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.single),
        ),
      ],
    );
  }
}
