import 'package:flutter/material.dart';

import '../models/settings.dart' show AppStyle;
import 'colors.dart';
import 'decor.dart';
import 'type.dart';

/// LOOK-1/LOOK-6, Decision 23: builds the whole [ThemeData] for an accent
/// and a brightness — one layout, سُفرة / Sufra, with the accent (زعفران/
/// Saffron or حبر/Ink) picked in Settings. Screens never fork on
/// [AppStyle]; they read `Theme.of` and [Decor.of] like any other themed
/// value (LOOK-2: the accent changes only colour).
///
/// Cards, the search field and floating round buttons carry one soft warm
/// shadow in light (`Decor.liftShadow`) and the navigation pill and primary
/// buttons a deeper one (`Decor.floatShadow`); dark has no shadows — a 1dp
/// hairline stands in on a card's own edge instead (`Decor.cardHairline`).
/// Material's own elevation tint is never used: every `*ThemeData` below
/// sets elevation/surfaceTintColor to 0/transparent.
ThemeData wasfatiTheme(AppStyle style, Brightness brightness) {
  final cs = wasfatiColorScheme(style, brightness);
  final n = sufraNeutrals(brightness);
  final isLight = brightness == Brightness.light;

  final textTheme = sufraTextTheme().apply(
    bodyColor: cs.onSurface,
    displayColor: cs.onSurface,
  );

  // LOOK-3: never Material's default 38% (light: 2.38:1, fails).
  final disabledColor = cs.onSurface.withValues(alpha: isLight ? 0.55 : 0.45);
  final disabledBackground = n.sunk;

  const pill = StadiumBorder();
  OutlinedBorder rounded(double radius) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  // design spec §1 "Shadows": --lift and --float, empty in dark.
  final liftShadow = isLight
      ? const [
          BoxShadow(
            color: Color(0x0F2F2012), // rgba(47,32,18,.06)
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x142F2012), // rgba(47,32,18,.08)
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ]
      : const <BoxShadow>[];
  final floatShadow = isLight
      ? const [
          BoxShadow(
            color: Color(0x471F1A15), // rgba(31,26,21,.28)
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ]
      : const <BoxShadow>[];

  WidgetStateProperty<Color?> foregroundWithDisabled(Color normal) =>
      WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ? disabledColor : normal,
      );

  WidgetStateProperty<Color?> backgroundWithDisabled(Color normal) =>
      WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ? disabledBackground : normal,
      );

  final appBarTheme = AppBarTheme(
    backgroundColor: cs.surface,
    foregroundColor: cs.onSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    centerTitle: false,
    toolbarHeight: 64,
    titleTextStyle: textTheme.titleLarge,
    // No Sufra mockup draws a rule under a screen title — it sits directly
    // on the linen/page. `line` (design spec §1) is only a hairline
    // separator inside a card, or (dark only) a card's own edge.
  );

  // LOOK-6: 22dp radius, a shadow in light (drawn by SufraCard/other
  // widgets, never Material elevation) and a 1dp hairline edge in dark.
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(22),
    side: isLight ? BorderSide.none : BorderSide(color: n.line),
  );

  final cardTheme = CardThemeData(
    elevation: 0,
    color: n.card,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    shape: cardShape,
  );

  final chipTheme = ChipThemeData(
    shape: pill,
    side: WidgetStateBorderSide.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? BorderSide.none
          : BorderSide(color: cs.outline),
    ),
    backgroundColor: n.sunk,
    selectedColor: cs.onSurface,
    // A plain `TextStyle.color` is state-aware here (`WidgetStateColor`
    // implements `Color`, and RawChip resolves it against the chip's own
    // states): FilterChip only ever reads `labelStyle` — never
    // `secondaryLabelStyle`, which only ChoiceChip picks up — so a selected
    // FilterChip label must read as `card` (on the dark `selectedColor`
    // fill) here too, not just `onSurfaceVariant` (LOOK-3: was 2.45:1
    // light, 1.82:1 dark).
    labelStyle: textTheme.labelLarge?.copyWith(
      color: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? n.card
            : cs.onSurfaceVariant,
      ),
    ),
    secondaryLabelStyle: textTheme.labelLarge?.copyWith(
      color: n.card,
      fontWeight: FontWeight.w600,
    ),
    showCheckmark: false,
    // design-styles.md: chips are 36dp visual with a 48dp tap target. The
    // default `labelPadding` (8dp) is kept — several chips carry an
    // `avatar` icon that needs that gap — so only the outer padding is
    // trimmed to still land on 16dp sides and ~36dp height.
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    elevation: 0,
    pressElevation: 0,
  );

  final inputTheme = InputDecorationTheme(
    filled: true,
    fillColor: n.card,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cs.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cs.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cs.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cs.error, width: 2),
    ),
    contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
    floatingLabelStyle: textTheme.labelMedium?.copyWith(color: cs.primary),
    // LOOK-3: hint text at full onSurfaceVariant, never faded.
    hintStyle: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
    helperStyle: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
    errorStyle: textTheme.bodySmall?.copyWith(color: cs.error),
  );

  // LOOK-6: the search field is a 52dp pill.
  final searchBarTheme = SearchBarThemeData(
    elevation: const WidgetStatePropertyAll(0),
    backgroundColor: WidgetStatePropertyAll(n.card),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    shape: const WidgetStatePropertyAll(pill),
    side: WidgetStatePropertyAll(BorderSide(color: cs.outline)),
    constraints: const BoxConstraints(minHeight: 52, maxHeight: 52),
    hintStyle: WidgetStatePropertyAll(
      textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
    ),
    textStyle: WidgetStatePropertyAll(
      textTheme.bodyMedium?.copyWith(color: cs.onSurface),
    ),
  );

  final listTileTheme = ListTileThemeData(
    minVerticalPadding: 12,
    contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
    horizontalTitleGap: 12,
    titleTextStyle: textTheme.bodyLarge,
    subtitleTextStyle: textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    ),
    iconColor: cs.onSurfaceVariant,
    selectedColor: cs.primary,
    selectedTileColor: Colors.transparent,
    shape: rounded(16),
  );

  // LOOK-6: dialogs at 28dp.
  final dialogTheme = DialogThemeData(
    backgroundColor: n.card,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: cs.outline),
    ),
    insetPadding: const EdgeInsets.all(24),
    titleTextStyle: textTheme.titleMedium,
    contentTextStyle: textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    ),
    barrierColor: isLight
        ? Colors.black.withValues(alpha: 0.48)
        : Colors.black.withValues(alpha: 0.64),
  );

  // LOOK-6: a bottom sheet's top corners at 28dp, with a drag handle.
  final bottomSheetTheme = BottomSheetThemeData(
    backgroundColor: n.card,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    showDragHandle: true,
    dragHandleColor: cs.outline,
    dragHandleSize: const Size(40, 4),
  );

  // LOOK-6: floating snackbars at 16dp.
  final snackBarTheme = SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: cs.inverseSurface,
    contentTextStyle: textTheme.bodyMedium?.copyWith(
      color: cs.onInverseSurface,
    ),
    actionTextColor: cs.inversePrimary,
    shape: rounded(16),
    elevation: 0,
    insetPadding: const EdgeInsets.all(16),
  );

  // LOOK-6: buttons are pills — primary 56dp, everything else 48dp.
  final filledButtonTheme = FilledButtonThemeData(
    style: ButtonStyle(
      backgroundColor: backgroundWithDisabled(cs.primary),
      foregroundColor: foregroundWithDisabled(cs.onPrimary),
      minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
      shape: const WidgetStatePropertyAll(pill),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      iconSize: const WidgetStatePropertyAll(24),
      elevation: const WidgetStatePropertyAll(0),
      overlayColor: WidgetStatePropertyAll(cs.onPrimary.withValues(alpha: 0.1)),
    ),
  );

  final outlinedButtonTheme = OutlinedButtonThemeData(
    style: ButtonStyle(
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.pressed) ? cs.primary : cs.outline,
          width: 1.5,
        ),
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return disabledColor;
        return states.contains(WidgetState.pressed) ? cs.primary : cs.onSurface;
      }),
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      shape: const WidgetStatePropertyAll(pill),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      overlayColor: WidgetStatePropertyAll(cs.primary.withValues(alpha: 0.08)),
    ),
  );

  final textButtonTheme = TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: foregroundWithDisabled(cs.primary),
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      shape: const WidgetStatePropertyAll(pill),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
    ),
  );

  final iconButtonTheme = IconButtonThemeData(
    style: ButtonStyle(
      shape: const WidgetStatePropertyAll(CircleBorder()),
      foregroundColor: foregroundWithDisabled(cs.onSurface),
      minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
    ),
  );

  final fabTheme = FloatingActionButtonThemeData(
    backgroundColor: cs.primary,
    foregroundColor: cs.onPrimary,
    elevation: 0,
    focusElevation: 0,
    hoverElevation: 0,
    highlightElevation: 0,
    disabledElevation: 0,
    extendedTextStyle: textTheme.labelLarge,
    shape: const StadiumBorder(),
  );

  final dividerTheme = DividerThemeData(
    color: cs.outlineVariant,
    thickness: 1,
    space: 1,
  );

  // LOOK-6: circular checkboxes.
  final checkboxTheme = CheckboxThemeData(
    shape: const CircleBorder(),
    side: BorderSide(color: cs.outline, width: 1.5),
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return disabledBackground;
      return states.contains(WidgetState.selected)
          ? cs.secondary
          : Colors.transparent;
    }),
    // `onSecondary` is `onHerb` (design-styles.md flag 2): a hard-coded
    // white tick on herb reads at 1.98:1 in dark, well under LOOK-3's 3:1
    // for a state indicator.
    checkColor: WidgetStatePropertyAll(cs.onSecondary),
  );

  final switchTheme = SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return disabledColor;
      // `outline` (not `card`), so the "off" thumb reads against the sunk
      // track (LOOK-3: card-on-sunk is only ~1.2:1 without the drop shadow
      // Flutter's Switch thumb doesn't draw).
      return states.contains(WidgetState.selected) ? cs.onPrimary : cs.outline;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return disabledBackground;
      return states.contains(WidgetState.selected) ? cs.primary : n.sunk;
    }),
    trackOutlineColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? Colors.transparent
          : cs.outline,
    ),
  );

  final progressTheme = ProgressIndicatorThemeData(
    color: cs.primary,
    linearTrackColor: n.sunk,
    circularTrackColor: n.sunk,
  );

  final segmentedButtonTheme = SegmentedButtonThemeData(
    style: ButtonStyle(
      shape: const WidgetStatePropertyAll(pill),
      // The unselected fill is `sunk` (not transparent), so the whole group
      // reads as one sunk pill track — the design's segmented-pill — with
      // the selected segment's `card` fill lifted on top of it, rather than
      // bare text with no track at all.
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? n.card : n.sunk,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? cs.onSurface
            : cs.onSurfaceVariant,
      ),
      // A group edge at `outline` (>= 3:1, LOOK-3), since the sunk fill
      // alone isn't a boundary against the page (~1:1).
      side: WidgetStatePropertyAll(BorderSide(color: cs.outline)),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
    ),
  );

  final sliderTheme = SliderThemeData(
    activeTrackColor: cs.primary,
    inactiveTrackColor: n.sunk,
    thumbColor: cs.primary,
    overlayColor: cs.primary.withValues(alpha: 0.12),
    disabledActiveTrackColor: disabledColor,
    disabledInactiveTrackColor: disabledBackground,
    disabledThumbColor: disabledColor,
    valueIndicatorColor: cs.inverseSurface,
    valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(
      color: cs.onInverseSurface,
    ),
  );

  final tabBarTheme = TabBarThemeData(
    indicator: UnderlineTabIndicator(
      borderSide: BorderSide(color: cs.primary, width: 3),
    ),
    indicatorSize: TabBarIndicatorSize.label,
    dividerColor: cs.outlineVariant,
    dividerHeight: 1,
    labelStyle: textTheme.labelLarge,
    unselectedLabelStyle: textTheme.labelLarge,
    labelColor: cs.onSurface,
    unselectedLabelColor: cs.onSurfaceVariant,
    overlayColor: WidgetStatePropertyAll(cs.primary.withValues(alpha: 0.08)),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: cs,
    textTheme: textTheme,
    scaffoldBackgroundColor: cs.surface,
    disabledColor: disabledColor,
    shadowColor: Colors.transparent,
    splashFactory: InkRipple.splashFactory,
    highlightColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: appBarTheme,
    cardTheme: cardTheme,
    chipTheme: chipTheme,
    inputDecorationTheme: inputTheme,
    searchBarTheme: searchBarTheme,
    listTileTheme: listTileTheme,
    dialogTheme: dialogTheme,
    bottomSheetTheme: bottomSheetTheme,
    snackBarTheme: snackBarTheme,
    filledButtonTheme: filledButtonTheme,
    outlinedButtonTheme: outlinedButtonTheme,
    textButtonTheme: textButtonTheme,
    iconButtonTheme: iconButtonTheme,
    floatingActionButtonTheme: fabTheme,
    dividerTheme: dividerTheme,
    checkboxTheme: checkboxTheme,
    switchTheme: switchTheme,
    progressIndicatorTheme: progressTheme,
    segmentedButtonTheme: segmentedButtonTheme,
    sliderTheme: sliderTheme,
    tabBarTheme: tabBarTheme,
    extensions: [
      Decor(
        sunk: n.sunk,
        cardHairline: isLight ? null : n.line,
        liftShadow: liftShadow,
        floatShadow: floatShadow,
        // LOOK-7: always a dark chrome, regardless of the app's own
        // brightness — light: `ink` (already dark); dark: `sunk`, with a
        // border standing in for the shadow it loses.
        navFill: isLight ? n.ink : n.sunk,
        navBorder: n.navBorder,
        navInactive: n.navInactive,
        // Always a light label on the pill's own dark chrome: white in
        // light (the pill fill is `ink`, itself dark), `ink` in dark (the
        // pill fill is `sunk`, and dark's `ink` is the light token).
        navActive: isLight ? Colors.white : n.ink,
        coverTints: sufraCoverTints(brightness),
        gutter: 20,
        // The plan's own "today" highlight bar (unrelated to RailHeading,
        // which no longer draws one).
        railWidth: 4,
        railColor: cs.primary,
        cardShape: cardShape,
        // "full-bleed", never rounded — the recipe hero photo.
        photoShape: const RoundedRectangleBorder(),
        chipShape: pill,
        buttonShape: pill,
        thumbnailShape: rounded(24),
        // LOOK-4: the amount in the accent at w700, for both accents.
        amountColor: cs.primary,
        amountWeight: FontWeight.w700,
        // Decision 23 drops Saffron's one press ledge: PressableSlab
        // renders every wrapped button flat now.
        ledgeDepth: 0,
        ledgeColor: Colors.transparent,
        rowHairline: n.line,
        groupedRowFill: n.card,
        ornament: EmptyOrnament.khatam,
        // LOOK-12: the library's photo-forward grid card and a cookbook
        // tile's collage (design spec §1: 24dp).
        photoCardRadius: 24,
        // LOOK-3: the photo card's title scrim, at least 78% near-black.
        photoScrim: const Color(0xC7140E0A),
      ),
    ],
  );
}
