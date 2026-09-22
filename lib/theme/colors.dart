import 'package:flutter/material.dart';

import '../models/settings.dart' show AppStyle;

/// LOOK-1/LOOK-3: the four hand-written [ColorScheme]s (one per look, per
/// brightness) and the shared shape constants both looks are built from.
/// Every value here is copied verbatim from `docs/research/design-styles.md`
/// (Ink: lines 30-70, Saffron: lines 231-270) — never `ColorScheme.fromSeed`,
/// so the contrast pairs `test/theme/contrast_test.dart` checks are exactly
/// the ones that were measured in the doc.

/// Named divider insets, so `DividerThemeData`'s indents can't drift
/// per-screen (design-styles.md "Shape and spacing" for each look).
@immutable
class WasfatiInsets {
  const WasfatiInsets({
    required this.group,
    required this.step,
    required this.list,
    required this.full,
  });

  /// Settings and sheet rows.
  final double group;

  /// Past the step-number badge.
  final double step;

  /// Past a thumbnail + gap + gutter.
  final double list;

  /// Between top-level sections (no inset).
  final double full;
}

/// Named corner radii, one set per look (design-styles.md "Shape and
/// spacing" for each look). Field names describe the component the radius
/// is for, not the number, so `app_theme.dart` never repeats a magic value.
@immutable
class WasfatiRadii {
  const WasfatiRadii({
    required this.progress,
    required this.chip,
    required this.button,
    required this.field,
    required this.searchBar,
    required this.card,
    required this.listTile,
    required this.dialog,
    required this.sheet,
    required this.photo,
    required this.snackBar,
  });

  /// Linear/circular progress track.
  final double progress;

  /// Chips, thumbnails, step-number boxes, small pills.
  final double chip;

  /// Filled/outlined/icon buttons and the FAB.
  final double button;

  /// Text fields.
  final double field;

  /// The M3 `SearchBar`.
  final double searchBar;

  /// Cards and grouped containers.
  final double card;

  /// `ListTileThemeData.shape`.
  final double listTile;

  /// Dialogs.
  final double dialog;

  /// The bottom sheet's top corners.
  final double sheet;

  /// The recipe hero photo's bottom corners (0 = square-cut, Saffron).
  final double photo;

  /// SnackBars.
  final double snackBar;
}

const inkInsets = WasfatiInsets(group: 16, step: 52, list: 92, full: 0);
const saffronInsets = WasfatiInsets(group: 16, step: 56, list: 92, full: 0);

const inkRadii = WasfatiRadii(
  progress: 4,
  chip: 10,
  button: 12,
  field: 12,
  searchBar: 12,
  card: 14,
  listTile: 10,
  dialog: 20,
  sheet: 24,
  photo: 18,
  snackBar: 12,
);

const saffronRadii = WasfatiRadii(
  progress: 4,
  chip: 12,
  button: 16,
  field: 12,
  searchBar: 14,
  card: 20,
  listTile: 12,
  dialog: 24,
  sheet: 24,
  photo: 0, // "square-cut", not rounded
  snackBar: 16,
);

/// حبر / Ink, light. design-styles.md lines 34-70 (light column).
const _inkLight = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF0B5F57),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFB4E3DB),
  onPrimaryContainer: Color(0xFF00201C),
  secondary: Color(0xFF4C6A3C),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFD3E6C7),
  onSecondaryContainer: Color(0xFF12240A),
  tertiary: Color(0xFF8A4D06),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFFCDFB4),
  onTertiaryContainer: Color(0xFF2C1700),
  error: Color(0xFFA32018),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD4),
  onErrorContainer: Color(0xFF3F0500),
  surface: Color(0xFFFBF7F0),
  onSurface: Color(0xFF1C1813),
  onSurfaceVariant: Color(0xFF574E43),
  surfaceDim: Color(0xFFE3D8C4),
  surfaceBright: Color(0xFFFFFDF9),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF1E8D8),
  surfaceContainer: Color(0xFFE9DECB),
  surfaceContainerHigh: Color(0xFFE1D4BD),
  surfaceContainerHighest: Color(0xFFD8C9AD),
  outline: Color(0xFF786D5D),
  outlineVariant: Color(0xFFC2B49B),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFF32291F),
  onInverseSurface: Color(0xFFF7EFE2),
  inversePrimary: Color(0xFF7FD5C9),
  surfaceTint: Color(0x00000000),
);

/// حبر / Ink, dark. design-styles.md lines 34-70 (dark column).
const _inkDark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF6FD5C8),
  onPrimary: Color(0xFF00352F),
  primaryContainer: Color(0xFF0A4B45),
  onPrimaryContainer: Color(0xFF9BEFE2),
  secondary: Color(0xFFA9CF95),
  onSecondary: Color(0xFF16300B),
  secondaryContainer: Color(0xFF2C4620),
  onSecondaryContainer: Color(0xFFC4EBB0),
  tertiary: Color(0xFFF0B45F),
  onTertiary: Color(0xFF452600),
  tertiaryContainer: Color(0xFF603D00),
  onTertiaryContainer: Color(0xFFFFDCA8),
  error: Color(0xFFFFB4A6),
  onError: Color(0xFF5F1005),
  errorContainer: Color(0xFF84271C),
  onErrorContainer: Color(0xFFFFDAD4),
  surface: Color(0xFF13120E),
  onSurface: Color(0xFFEFE7D8),
  onSurfaceVariant: Color(0xFFC2B6A2),
  surfaceDim: Color(0xFF13120E),
  surfaceBright: Color(0xFF3E392E),
  surfaceContainerLowest: Color(0xFF0D0C09),
  surfaceContainerLow: Color(0xFF1E1B16),
  surfaceContainer: Color(0xFF26231C),
  surfaceContainerHigh: Color(0xFF322E25),
  surfaceContainerHighest: Color(0xFF3E392E),
  outline: Color(0xFF978A78),
  outlineVariant: Color(0xFF5E5445),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFFEFE7D8),
  onInverseSurface: Color(0xFF26231C),
  inversePrimary: Color(0xFF0B5F57),
  surfaceTint: Color(0x00000000),
);

/// زعفران / Saffron, light. design-styles.md lines 237-270 (light column).
const _saffronLight = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF8A5200),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFFFDEAF),
  onPrimaryContainer: Color(0xFF2C1700),
  secondary: Color(0xFF2F6B45),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFC5E8CF),
  onSecondaryContainer: Color(0xFF052014),
  tertiary: Color(0xFF0F6058),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFB8E5DE),
  onTertiaryContainer: Color(0xFF00201C),
  error: Color(0xFFA3231B),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD4),
  onErrorContainer: Color(0xFF410200),
  surface: Color(0xFFFDFAF4),
  onSurface: Color(0xFF191410),
  onSurfaceVariant: Color(0xFF5A5145),
  surfaceDim: Color(0xFFE6DCC6),
  surfaceBright: Color(0xFFFFFEFA),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF5EDDD),
  surfaceContainer: Color(0xFFEEE4CF),
  surfaceContainerHigh: Color(0xFFE6DAC2),
  surfaceContainerHighest: Color(0xFFDDD0B3),
  outline: Color(0xFF7C6E5C),
  outlineVariant: Color(0xFFC7B79E),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFF33291E),
  onInverseSurface: Color(0xFFF8F0E3),
  inversePrimary: Color(0xFFF5B84A),
  surfaceTint: Color(0x00000000),
);

/// زعفران / Saffron, dark. design-styles.md lines 237-270 (dark column).
const _saffronDark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFF5B84A),
  onPrimary: Color(0xFF2A1A00),
  primaryContainer: Color(0xFF5E3D00),
  onPrimaryContainer: Color(0xFFFFDEAF),
  secondary: Color(0xFF8DD3A2),
  onSecondary: Color(0xFF06371D),
  secondaryContainer: Color(0xFF1E4F31),
  onSecondaryContainer: Color(0xFFA9EFBC),
  tertiary: Color(0xFF62D3C7),
  onTertiary: Color(0xFF00352F),
  tertiaryContainer: Color(0xFF004B44),
  onTertiaryContainer: Color(0xFF9BEFE2),
  error: Color(0xFFFFB4A6),
  onError: Color(0xFF5F1005),
  errorContainer: Color(0xFF8C2A1E),
  onErrorContainer: Color(0xFFFFDAD4),
  surface: Color(0xFF14100C),
  onSurface: Color(0xFFF2E9DB),
  onSurfaceVariant: Color(0xFFC6B9A4),
  surfaceDim: Color(0xFF14100C),
  surfaceBright: Color(0xFF41382C),
  surfaceContainerLowest: Color(0xFF0E0B08),
  surfaceContainerLow: Color(0xFF201B14),
  surfaceContainer: Color(0xFF29231B),
  surfaceContainerHigh: Color(0xFF352D22),
  surfaceContainerHighest: Color(0xFF41382C),
  outline: Color(0xFF9A8A75),
  outlineVariant: Color(0xFF5C5243),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFFF2E9DB),
  onInverseSurface: Color(0xFF29231B),
  inversePrimary: Color(0xFF8A5200),
  surfaceTint: Color(0x00000000),
);

/// The [ColorScheme] for [style]/[brightness] — never `ColorScheme.fromSeed`.
ColorScheme wasfatiColorScheme(AppStyle style, Brightness brightness) {
  return switch ((style, brightness)) {
    (AppStyle.ink, Brightness.light) => _inkLight,
    (AppStyle.ink, Brightness.dark) => _inkDark,
    (AppStyle.saffron, Brightness.light) => _saffronLight,
    (AppStyle.saffron, Brightness.dark) => _saffronDark,
  };
}

/// The named insets for [style] (identical shape, different step inset).
WasfatiInsets wasfatiInsets(AppStyle style) =>
    style == AppStyle.ink ? inkInsets : saffronInsets;

/// The named radii for [style].
WasfatiRadii wasfatiRadii(AppStyle style) =>
    style == AppStyle.ink ? inkRadii : saffronRadii;
