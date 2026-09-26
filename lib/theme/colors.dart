import 'package:flutter/material.dart';

import '../models/settings.dart' show AppStyle;

/// LOOK-1/LOOK-3/Decision 23: سُفرة / Sufra's one hand-written [ColorScheme]
/// per accent (زعفران/Saffron, حبر/Ink) and brightness — never
/// `ColorScheme.fromSeed`, so the contrast pairs `test/theme/contrast_test.dart`
/// checks are exactly the ones measured against the design spec (the
/// scratchpad's `sufra-spec.md` §1). Every neutral token (page, card, sunk,
/// ink, ink2, line, border, herb, herbSoft, navInactive) is identical for
/// both accents — the spec's "the two options differ only in accent
/// colour" — so only the accent tokens below branch on [AppStyle].
@immutable
class SufraNeutrals {
  const SufraNeutrals({
    required this.page,
    required this.card,
    required this.sunk,
    required this.ink,
    required this.ink2,
    required this.line,
    required this.border,
    required this.herb,
    required this.onHerb,
    required this.herbSoft,
    required this.onHerbSoft,
    required this.navInactive,
    this.navBorder,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
  });

  final Color page;
  final Color card;
  final Color sunk;
  final Color ink;
  final Color ink2;
  final Color line;
  final Color border;
  final Color herb;
  final Color onHerb;
  final Color herbSoft;
  final Color onHerbSoft;
  final Color navInactive;

  /// LOOK-7: stands in for the navigation pill's lost shadow in dark, where
  /// [Decor.floatShadow] is empty — null in light, where the shadow still
  /// carries the job.
  final Color? navBorder;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
}

const _neutralsLight = SufraNeutrals(
  page: Color(0xFFF6F1EA),
  card: Color(0xFFFFFFFF),
  sunk: Color(0xFFEFE8DF),
  ink: Color(0xFF1F1A15),
  ink2: Color(0xFF62574C),
  line: Color(0xFFE8E0D5),
  border: Color(0xFF8F8475),
  herb: Color(0xFF2E6B4F),
  onHerb: Color(0xFFFFFFFF),
  herbSoft: Color(0xFFE3F0E8),
  onHerbSoft: Color(0xFF1E4A36),
  navInactive: Color(0xFFA89C8F),
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF410E0B),
);

const _neutralsDark = SufraNeutrals(
  navBorder: Color(0xFF3A332C),
  page: Color(0xFF14110E),
  card: Color(0xFF201C18),
  sunk: Color(0xFF2B2621),
  ink: Color(0xFFF5EFE8),
  ink2: Color(0xFFBDB2A6),
  line: Color(0xFF332D27),
  border: Color(0xFF8C8072),
  herb: Color(0xFF7FC7A0),
  onHerb: Color(0xFF1F1A15),
  herbSoft: Color(0xFF1D3328),
  onHerbSoft: Color(0xFFBFE8CF),
  // design-styles.md §Palette: dark navInactive is ink2, not the light
  // navInactive value reused.
  navInactive: Color(0xFFBDB2A6),
  error: Color(0xFFF2B8B5),
  onError: Color(0xFF601410),
  errorContainer: Color(0xFF8C1D18),
  onErrorContainer: Color(0xFFF9DEDC),
);

SufraNeutrals sufraNeutrals(Brightness brightness) =>
    brightness == Brightness.light ? _neutralsLight : _neutralsDark;

/// One accent's four tokens (design spec §1, "Colour"): the accent itself,
/// the text/icon colour that sits directly on it, the soft fill and the
/// text/icon colour on that fill.
@immutable
class SufraAccent {
  const SufraAccent({
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
  });

  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color onAccentSoft;
}

// زعفران / Saffron (paprika) — the default for a new install.
const _saffronLight = SufraAccent(
  accent: Color(0xFFC2410C),
  onAccent: Color(0xFFFFFFFF),
  accentSoft: Color(0xFFFCE9DD),
  onAccentSoft: Color(0xFF7A2A08),
);
const _saffronDark = SufraAccent(
  accent: Color(0xFFF28A4B),
  onAccent: Color(0xFF1F1A15), // ink-dark text, not white (spec §1)
  accentSoft: Color(0xFF3A2418),
  onAccentSoft: Color(0xFFFFD2B5),
);

// حبر / Ink (teal).
const _inkLight = SufraAccent(
  accent: Color(0xFF0F766E),
  onAccent: Color(0xFFFFFFFF),
  accentSoft: Color(0xFFDDF1EE),
  onAccentSoft: Color(0xFF0B4F49),
);
const _inkDark = SufraAccent(
  accent: Color(0xFF5EC9BD),
  onAccent: Color(0xFF1F1A15),
  accentSoft: Color(0xFF16332F),
  onAccentSoft: Color(0xFFBFEDE6),
);

SufraAccent sufraAccent(AppStyle style, Brightness brightness) {
  return switch ((style, brightness)) {
    (AppStyle.saffron, Brightness.light) => _saffronLight,
    (AppStyle.saffron, Brightness.dark) => _saffronDark,
    (AppStyle.ink, Brightness.light) => _inkLight,
    (AppStyle.ink, Brightness.dark) => _inkDark,
  };
}

/// LOOK-10: the six drawn-cover tints (a light fill and its dark tone for
/// the star pattern and the centred letter), style-independent — the same
/// six tints in both accents, so a recipe's cover never changes when the
/// user changes "الطراز". Order fixed, so a stable hash into this list
/// (`RecipeCover`) always lands on the same tint for the same recipe. Exact
/// hex values from `docs/research/design-styles.md` §Palette (the mockups
/// show only sage; the other five extend the same warm, muted family).
const List<(Color light, Color dark)> _sufraCoverTintsLight = [
  (Color(0xFFDDE8D5), Color(0xFF3F5A36)), // sage
  (Color(0xFFF3DCCB), Color(0xFF7A4B2E)), // clay
  (Color(0xFFF5E6B8), Color(0xFF7A5C12)), // honey
  (Color(0xFFF0D9D9), Color(0xFF7A3F3F)), // dusty rose
  (Color(0xFFD8E3EC), Color(0xFF35526E)), // denim
  (Color(0xFFE6D9EC), Color(0xFF5B3E70)), // plum
];

/// The same six tints' "Dark tone (on card)" column (design-styles.md
/// §"The six drawn-cover tints"): in dark, a cover with no photo is the
/// card colour with this lighter tone on it, never the light pastel fill.
/// Same order as [_sufraCoverTintsLight], so a stable hash into either list
/// (`RecipeCover.tintIndexFor`) lands on the same tint for the same recipe.
const List<Color> _sufraCoverTonesDark = [
  Color(0xFF8FBE86), // sage
  Color(0xFFD69A6B), // clay
  Color(0xFFD9B84A), // honey
  Color(0xFFD99B9B), // dusty rose
  Color(0xFF7FA8C9), // denim
  Color(0xFFB08FC4), // plum
];

/// LOOK-10: [brightness]'s six drawn-cover tints — a light fill with its
/// dark tone in light, or the dark `card` fill with a lighter tone in dark
/// — style-independent (the same six tints in both accents).
List<(Color light, Color dark)> sufraCoverTints(Brightness brightness) {
  if (brightness == Brightness.light) return _sufraCoverTintsLight;
  final card = _neutralsDark.card;
  return [for (final tone in _sufraCoverTonesDark) (card, tone)];
}

/// LOOK-1/LOOK-3: the hand-written [ColorScheme] for [style]/[brightness].
/// Every field is named explicitly against a Sufra token — never
/// `ColorScheme.fromSeed` — per the mapping the redesign spec fixes:
/// primary/onPrimary/primaryContainer/onPrimaryContainer from the accent,
/// secondary from herb, surface/surfaceContainerLowest from page/card, the
/// container ladder from sunk, onSurface/onSurfaceVariant from ink/ink2,
/// outline/outlineVariant from border/line, surfaceTint transparent (a
/// hand-tuned palette never lets Material tint a surface on top of it).
ColorScheme wasfatiColorScheme(AppStyle style, Brightness brightness) {
  final n = sufraNeutrals(brightness);
  final a = sufraAccent(style, brightness);
  // `inverseSurface` is this brightness's own `ink` token, which already
  // reads as the *opposite* brightness's surface (light's ink is dark,
  // dark's ink is light). `inversePrimary` has to read on that inverse
  // surface, so it uses the *opposite* brightness's accent, not this one's:
  // light needs the dark accent (light on ink's dark), dark needs the light
  // accent (dark-ish on ink's light) — both measured in
  // contrast_test.dart's `onFillPairs` group, as the SnackBar-action pair
  // (`inversePrimary/inverseSurface`).
  final inverseAccent = sufraAccent(
    style,
    brightness == Brightness.light ? Brightness.dark : Brightness.light,
  ).accent;

  return ColorScheme(
    brightness: brightness,
    primary: a.accent,
    onPrimary: a.onAccent,
    primaryContainer: a.accentSoft,
    onPrimaryContainer: a.onAccentSoft,
    secondary: n.herb,
    onSecondary: n.onHerb,
    secondaryContainer: n.herbSoft,
    onSecondaryContainer: n.onHerbSoft,
    // No third accent in the spec: tertiary mirrors secondary (herb) rather
    // than inventing an unspecified hue.
    tertiary: n.herb,
    onTertiary: n.onHerb,
    tertiaryContainer: n.herbSoft,
    onTertiaryContainer: n.onHerbSoft,
    error: n.error,
    onError: n.onError,
    errorContainer: n.errorContainer,
    onErrorContainer: n.onErrorContainer,
    surface: n.page,
    onSurface: n.ink,
    onSurfaceVariant: n.ink2,
    surfaceDim: brightness == Brightness.light ? n.sunk : n.page,
    surfaceBright: brightness == Brightness.light ? n.card : n.sunk,
    surfaceContainerLowest: n.card,
    surfaceContainerLow: n.card,
    surfaceContainer: n.sunk,
    surfaceContainerHigh: n.sunk,
    surfaceContainerHighest: n.sunk,
    outline: n.border,
    outlineVariant: n.line,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: n.ink,
    onInverseSurface: n.page,
    inversePrimary: inverseAccent,
    // A hand-tuned palette: Material never lays its own tint on a surface.
    surfaceTint: const Color(0x00000000),
  );
}
