import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_state.dart';

/// A text field's "12/60" counter in the user's digits (LANG-3, QTY-5):
/// Flutter's own counter always writes 123. A screen reader still hears how
/// many characters are left, as with Flutter's own. Pass it as
/// `buildCounter`.
Widget? digitCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) {
  final s = context.read<SettingsState>();
  final theme = Theme.of(context);
  return Text(
    maxLength == null
        ? s.number(currentLength)
        : '${s.number(currentLength)}/${s.number(maxLength)}',
    style:
        theme.inputDecorationTheme.counterStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
    semanticsLabel: maxLength == null
        ? null
        : MaterialLocalizations.of(context)
              .remainingTextFieldCharacterCount(maxLength - currentLength),
  );
}
