import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/quantity/format.dart';
import '../models/settings.dart';
import '../providers/settings_state.dart';

/// Settings (roadmap 2a): language (LANG-1), digit style (QTY-5), units
/// (SCALE-5), week start and theme. Changes apply at once.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SettingsState>();
    final s = state.settings;
    void set(AppSettings next) => state.update(next);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsetsDirectional.only(bottom: 32),
        children: [
          _Choice<LanguagePref>(
            title: l10n.settingsLanguage,
            value: s.language,
            options: {
              LanguagePref.system: l10n.languageSystem,
              LanguagePref.ar: 'العربية', // each language in its own name
              LanguagePref.en: 'English',
            },
            onChanged: (v) => set(s.copyWith(language: v)),
          ),
          _Choice<DigitStyle>(
            title: l10n.settingsDigits,
            value: s.digits,
            options: const {
              DigitStyle.western: '123',
              DigitStyle.arabic: '١٢٣',
            },
            onChanged: (v) => set(s.copyWith(digits: v)),
          ),
          _Choice<UnitSystem>(
            title: l10n.settingsUnits,
            value: s.units,
            options: {
              UnitSystem.metric: l10n.unitsMetric,
              UnitSystem.kitchen: l10n.unitsKitchen,
            },
            onChanged: (v) => set(s.copyWith(units: v)),
          ),
          _Choice<WeekStart>(
            title: l10n.settingsWeekStart,
            value: s.weekStart,
            options: {
              WeekStart.auto: l10n.weekStartAuto,
              WeekStart.saturday: l10n.saturday,
              WeekStart.sunday: l10n.sunday,
              WeekStart.monday: l10n.monday,
            },
            onChanged: (v) => set(s.copyWith(weekStart: v)),
          ),
          _Choice<ThemePref>(
            title: l10n.settingsTheme,
            value: s.theme,
            options: {
              ThemePref.system: l10n.themeSystem,
              ThemePref.light: l10n.themeLight,
              ThemePref.dark: l10n.themeDark,
            },
            onChanged: (v) => set(s.copyWith(theme: v)),
          ),
        ],
      ),
    );
  }
}

/// A heading and one row per option, the chosen one ticked.
class _Choice<T> extends StatelessWidget {
  const _Choice({
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: scheme.primary),
          ),
        ),
        for (final e in options.entries)
          ListTile(
            title: Text(e.value),
            trailing: e.key == value
                ? Icon(Icons.check, color: scheme.primary)
                : null,
            selected: e.key == value,
            onTap: () => onChanged(e.key),
          ),
      ],
    );
  }
}
