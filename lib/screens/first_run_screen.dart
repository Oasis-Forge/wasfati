import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/quantity/format.dart';
import '../models/settings.dart' show appLanguage;
import '../providers/recipes_state.dart';
import '../providers/settings_state.dart';
import '../theme/decor.dart';
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
/// and the digit style — each a pair of large cards with the device's own
/// answer already chosen. No account, no profiling question, no
/// permission, no paywall and no review request. Every choice applies at
/// once (LANG-1), so the page itself switches language as it's tapped.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SettingsState>();
    final theme = Theme.of(context);
    final decor = Decor.of(context);
    final device = WidgetsBinding.instance.platformDispatcher.locales;
    final language = appLanguage(state.settings.language, device).languageCode;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  decor.gutter,
                  32,
                  decor.gutter,
                  16,
                ),
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.setupTitle,
                      style: theme.textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.setupBody,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SetupQuestion<String>(
                    title: l10n.settingsLanguage,
                    value: language,
                    // Each language in its own name (LANG-1).
                    options: const {'ar': 'العربية', 'en': 'English'},
                    onChanged: (code) =>
                        state.chooseSetupLanguage(code, device),
                  ),
                  const SizedBox(height: 28),
                  _SetupQuestion<DigitStyle>(
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
              padding: EdgeInsetsDirectional.fromSTEB(
                decor.gutter,
                8,
                decor.gutter,
                16,
              ),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  shadows: decor.floatShadow,
                ),
                child: SizedBox(
                  width: double.infinity,
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

/// A question's heading and its two answers as large cards side by side.
class _SetupQuestion<T> extends StatelessWidget {
  const _SetupQuestion({
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
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, e) in options.entries.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: SetupChoiceCard(
                    label: e.value,
                    selected: e.key == value,
                    onTap: () => onChanged(e.key),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// RUN-3: one answer, a large card on the page colour. The chosen one is
/// marked by an accent edge **and** a filled check, never colour alone
/// (LOOK-3), and says so to a screen reader.
///
/// SufraCard's surface with a 2dp edge it has no option for yet, and the
/// same 0.97 press scale every tappable card has (design-styles.md, Motion
/// #1). It can move onto SufraCard once that takes a border colour.
class SetupChoiceCard extends StatefulWidget {
  const SetupChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<SetupChoiceCard> createState() => _SetupChoiceCardState();
}

class _SetupChoiceCardState extends State<SetupChoiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final decor = Decor.of(context);
    final label = widget.label;
    final selected = widget.selected;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final card = AnimatedContainer(
      duration: duration,
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: decor.liftShadow,
        border: Border.all(
          color: selected ? cs.primary : (decor.cardHairline ?? cs.surface),
          width: 2,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: theme.textTheme.titleMedium),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: duration,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? cs.primary : Colors.transparent,
                    border: selected
                        ? null
                        : Border.all(color: cs.outline, width: 1.5),
                  ),
                  child: selected
                      ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 120),
        child: card,
      ),
    );
  }
}
