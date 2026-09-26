import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/decor.dart';
import 'round_icon_button.dart';

/// LOOK-6: the library's (and, from PR 4, groceries') search field — a
/// pill that carries the same soft warm shadow as a card in light
/// (`Decor.liftShadow`), with the filter action as a 44dp accent circle
/// inside its trailing edge rather than a separate button beside it.
class SufraSearchField extends StatelessWidget {
  const SufraSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    required this.clearTooltip,
    required this.onFilterTap,
    required this.filterTooltip,
    this.filterActive = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String clearTooltip;
  final VoidCallback onFilterTap;
  final String filterTooltip;

  /// ORG-6: a dot on the filter circle while a filter with no quick chip
  /// of its own is in effect, so choosing one in the sheet leaves a trace.
  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final decor = Decor.of(context);
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        shadows: decor.liftShadow,
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => SearchBar(
          controller: controller,
          hintText: hintText,
          leading: const Icon(Icons.search),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.fromSTEB(18, 4, 4, 4),
          ),
          onChanged: onChanged,
          trailing: [
            if (controller.text.isNotEmpty)
              IconButton(
                tooltip: clearTooltip,
                icon: const Icon(Icons.close),
                onPressed: onClear,
              ),
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  RoundIconButton(
                    icon: Icons.tune,
                    tooltip: filterTooltip,
                    size: 44,
                    backgroundColor: cs.primary,
                    color: cs.onPrimary,
                    onPressed: onFilterTap,
                  ),
                  if (filterActive)
                    PositionedDirectional(
                      top: 2,
                      end: 2,
                      // ORG-6: named for a screen reader (was-fix: a plain
                      // decorative dot carried no semantics at all), and the
                      // accent rather than `cs.error` — a filter in effect
                      // isn't a validation error.
                      child: Semantics(
                        label: l10n.filterActiveHint,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.primary,
                            border: Border.all(color: cs.onPrimary, width: 1.5),
                          ),
                        ),
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
