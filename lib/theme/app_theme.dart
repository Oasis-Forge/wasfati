import 'package:flutter/material.dart';

import '../models/settings.dart' show AppStyle;
import '../widgets/chamfered_border.dart';
import 'colors.dart';
import 'decor.dart';
import 'type.dart';

/// LOOK-1/LOOK-2: builds the whole [ThemeData] for a look and a brightness
/// — [ColorScheme], [TextTheme] and every component theme design-styles.md
/// lists, with a [Decor] extension attached for what `ThemeData` itself
/// cannot carry. Screens never fork on [AppStyle]; they read `Theme.of`
/// and [Decor.of] like any other themed value (LOOK-2).
///
/// Both looks: elevation, shadow and surface tint are zero everywhere in
/// `ThemeData` itself (LOOK-7) — Ink has no raised object at all, and
/// Saffron's one 2dp press ledge is drawn by a widget reading
/// [Decor.ledgeDepth]/[Decor.ledgeColor], never by Material elevation.
/// Disabled content is composited at 55% (light) / 45% (dark) of
/// `onSurface`, never Material's default 38%, so it never drops under
/// 3:1 (LOOK-3); hint text is full `onSurfaceVariant`, never faded.
ThemeData wasfatiTheme(AppStyle style, Brightness brightness) {
  final cs = wasfatiColorScheme(style, brightness);
  final radii = wasfatiRadii(style);
  final isInk = style == AppStyle.ink;

  final textTheme = wasfatiTextTheme(style)
      .apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);

  // LOOK-3: never Material's default 38% (light: 2.38:1, fails).
  final disabledColor = cs.onSurface.withValues(
    alpha: brightness == Brightness.light ? 0.55 : 0.45,
  );
  final disabledBackground = cs.surfaceContainerHigh;

  // 1dp in Ink (hairline architecture), 1.5dp in Saffron (design-styles.md
  // "Shape and spacing", both looks).
  final outlineWidth = isInk ? 1.0 : 1.5;

  OutlinedBorder rounded(double radius) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  // LOOK-6: Saffron's chamfer on chips, one of the five named targets
  // (design-styles.md "Signature moves"); Ink stays a plain rounded rect.
  // Shared with Decor.chipShape below, so a hand-built badge (the recipe
  // step number) gets the same shape as an actual Chip instead of a second,
  // driftable definition.
  final OutlinedBorder chipShape = isInk
      ? rounded(radii.chip)
      : ChamferedBorder(borderRadius: radii.chip);

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
    toolbarHeight: isInk ? 60 : 64,
    titleTextStyle: textTheme.titleLarge,
    // A static hairline, always on (design-styles.md: not scroll-driven).
    shape: Border(bottom: BorderSide(color: cs.outlineVariant, width: 1)),
  );

  final cardTheme = CardThemeData(
    elevation: 0,
    color: cs.surfaceContainerLow,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radii.card),
      side: BorderSide(color: cs.outline, width: outlineWidth),
    ),
  );

  final chipTheme = ChipThemeData(
    shape: chipShape,
    // should-fix, platform review: a selected chip's only state signal used
    // to be a ~1.3:1 fill (primaryContainer on surface) — the same failure
    // LOOK-3 already calls out for the nav indicator, which does carry this
    // 2dp primary border. design-styles.md specifies exactly this per-chip
    // resolution for both looks.
    side: WidgetStateBorderSide.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? BorderSide(color: cs.primary, width: 2)
          : BorderSide(color: cs.outline, width: outlineWidth),
    ),
    backgroundColor: Colors.transparent,
    selectedColor: cs.primaryContainer,
    labelStyle: textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
    secondaryLabelStyle: textTheme.labelLarge?.copyWith(
      color: cs.onPrimaryContainer,
      fontWeight: FontWeight.w600,
    ),
    showCheckmark: false,
    padding: EdgeInsets.symmetric(
      horizontal: isInk ? 14 : 16,
      vertical: isInk ? 10 : 12,
    ),
    elevation: 0,
    pressElevation: 0,
  );

  final inputTheme = InputDecorationTheme(
    filled: true,
    fillColor: cs.surfaceContainerLow,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radii.field),
      borderSide: BorderSide(color: cs.outline, width: outlineWidth),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radii.field),
      borderSide: BorderSide(color: cs.outline, width: outlineWidth),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radii.field),
      borderSide: BorderSide(color: cs.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radii.field),
      borderSide: BorderSide(color: cs.error, width: isInk ? 1.5 : 2),
    ),
    contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
    constraints: isInk ? null : const BoxConstraints(minHeight: 56),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: (isInk ? textTheme.labelMedium : textTheme.labelSmall)
        ?.copyWith(color: cs.onSurfaceVariant),
    floatingLabelStyle: (isInk ? textTheme.labelMedium : textTheme.labelSmall)
        ?.copyWith(color: cs.primary),
    // LOOK-3: hint text at full onSurfaceVariant, never faded.
    hintStyle: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
    helperStyle: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
    errorStyle: textTheme.bodySmall?.copyWith(color: cs.error),
  );

  final listTileTheme = ListTileThemeData(
    minVerticalPadding: 12,
    contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
    horizontalTitleGap: isInk ? 14 : 12,
    titleTextStyle: textTheme.bodyLarge,
    subtitleTextStyle: (isInk ? textTheme.bodySmall : textTheme.bodyMedium)
        ?.copyWith(color: cs.onSurfaceVariant),
    iconColor: cs.onSurfaceVariant,
    selectedColor: cs.primary,
    // Selection is drawn by the row itself (a rail, a fill, a check
    // badge), never by M3's own tint (design-styles.md, both looks).
    selectedTileColor: Colors.transparent,
    shape: rounded(radii.listTile),
  );

  final dialogTheme = DialogThemeData(
    backgroundColor: cs.surfaceContainerLow,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shadowColor: Colors.transparent,
    // should-fix, platform review: `outlineVariant` is 1.68:1 against this
    // dialog's own fill (surfaceContainerLow) in Ink light — design-styles.md
    // is explicit that outlineVariant is only for a row separator inside an
    // already-bounded group and "may never be the edge of a control or of a
    // container" (LOOK-3's 3:1 floor). `outline` is what Saffron already
    // used, and what every other container edge in both looks uses.
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radii.dialog),
      side: BorderSide(color: cs.outline, width: outlineWidth),
    ),
    insetPadding: const EdgeInsets.all(24),
    titleTextStyle: isInk ? textTheme.titleMedium : textTheme.titleLarge,
    contentTextStyle: (isInk ? textTheme.bodyMedium : textTheme.bodyLarge)
        ?.copyWith(color: cs.onSurfaceVariant),
    barrierColor: brightness == Brightness.light
        ? Colors.black.withValues(alpha: 0.48)
        : Colors.black.withValues(alpha: 0.64),
  );

  final bottomSheetTheme = BottomSheetThemeData(
    backgroundColor: cs.surfaceContainerLow,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radii.sheet)),
    ),
    showDragHandle: true,
    dragHandleColor: cs.outline,
    dragHandleSize: const Size(40, 4),
  );

  final snackBarTheme = SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: cs.inverseSurface,
    contentTextStyle: (isInk ? textTheme.bodyMedium : textTheme.bodyLarge)
        ?.copyWith(color: cs.onInverseSurface),
    actionTextColor: cs.inversePrimary,
    shape: rounded(radii.snackBar),
    elevation: 0,
    insetPadding: const EdgeInsets.all(16),
  );

  final filledButtonTheme = FilledButtonThemeData(
    style: ButtonStyle(
      backgroundColor: backgroundWithDisabled(cs.primary),
      foregroundColor: foregroundWithDisabled(cs.onPrimary),
      minimumSize: WidgetStatePropertyAll(Size(0, isInk ? 52 : 56)),
      shape: WidgetStatePropertyAll(rounded(radii.button)),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      iconSize: WidgetStatePropertyAll(isInk ? 22 : 24),
      elevation: const WidgetStatePropertyAll(0),
      overlayColor: WidgetStatePropertyAll(cs.onPrimary.withValues(alpha: 0.1)),
    ),
  );

  final outlinedButtonTheme = OutlinedButtonThemeData(
    style: ButtonStyle(
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: !isInk && states.contains(WidgetState.pressed)
              ? cs.primary
              : cs.outline,
          width: isInk ? 1.5 : 2,
        ),
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return disabledColor;
        if (isInk) return cs.primary;
        return states.contains(WidgetState.pressed) ? cs.primary : cs.onSurface;
      }),
      minimumSize: WidgetStatePropertyAll(Size(0, isInk ? 52 : 56)),
      shape: WidgetStatePropertyAll(rounded(radii.button)),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      overlayColor: WidgetStatePropertyAll(cs.primary.withValues(alpha: 0.08)),
    ),
  );

  final textButtonTheme = TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: foregroundWithDisabled(cs.primary),
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      shape: WidgetStatePropertyAll(rounded(radii.button)),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
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
    shape: rounded(radii.button),
  );

  final dividerTheme = DividerThemeData(
    color: cs.outlineVariant,
    thickness: 1,
    space: 1,
  );

  final switchTheme = SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return disabledColor;
      return states.contains(WidgetState.selected) ? cs.onPrimary : cs.outline;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return disabledBackground;
      return states.contains(WidgetState.selected)
          ? cs.primary
          : cs.surfaceContainerHighest;
    }),
    trackOutlineColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? Colors.transparent
          : cs.outline,
    ),
  );

  final sliderTheme = SliderThemeData(
    activeTrackColor: cs.primary,
    inactiveTrackColor: cs.surfaceContainerHighest,
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
    labelStyle: isInk ? textTheme.titleSmall : textTheme.labelLarge,
    unselectedLabelStyle: isInk ? textTheme.titleSmall : textTheme.labelLarge,
    labelColor: cs.onSurface,
    unselectedLabelColor: cs.onSurfaceVariant,
    overlayColor: WidgetStatePropertyAll(cs.primary.withValues(alpha: 0.08)),
  );

  final navBarTheme = NavigationBarThemeData(
    height: isInk ? 72 : 80,
    backgroundColor: isInk ? cs.surfaceContainerLow : cs.surfaceContainer,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    indicatorColor: cs.primaryContainer,
    // The framework hard-codes the indicator's own 64x32 size
    // (navigation_bar.dart) — only shape and colour are themeable, so the
    // 2dp primary border is what carries the selected state: primary on
    // this background clears 3:1 while primaryContainer's fill alone does
    // not (design-styles.md, both looks).
    indicatorShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(isInk ? 10 : 12),
      side: BorderSide(color: cs.primary, width: 2),
    ),
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        size: isInk ? 24 : 26,
        color: states.contains(WidgetState.selected)
            ? cs.onPrimaryContainer
            : cs.onSurfaceVariant,
      ),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return textTheme.labelMedium?.copyWith(
        color: selected ? cs.onSurface : cs.onSurfaceVariant,
        fontWeight: selected
            ? (isInk ? FontWeight.w600 : FontWeight.w700)
            : FontWeight.w600,
      );
    }),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: cs,
    textTheme: textTheme,
    scaffoldBackgroundColor: cs.surface,
    // LOOK-3: what a disabled ListTile (Settings' backup rows while a backup
    // runs) and any other widget without its own disabled theme paints its
    // text in. Unset, it's Material's black/white at 38%, 2.62:1 on the
    // grouped-row fill in light.
    disabledColor: disabledColor,
    // LOOK-7: no shadow, elevation or surface tint anywhere — Saffron's
    // one press ledge is Decor data for a widget to draw, never Material
    // elevation (see the class doc comment above).
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
    listTileTheme: listTileTheme,
    dialogTheme: dialogTheme,
    bottomSheetTheme: bottomSheetTheme,
    snackBarTheme: snackBarTheme,
    filledButtonTheme: filledButtonTheme,
    outlinedButtonTheme: outlinedButtonTheme,
    textButtonTheme: textButtonTheme,
    floatingActionButtonTheme: fabTheme,
    dividerTheme: dividerTheme,
    switchTheme: switchTheme,
    sliderTheme: sliderTheme,
    tabBarTheme: tabBarTheme,
    navigationBarTheme: navBarTheme,
    extensions: [_decorFor(style, cs, radii, chipShape)],
  );
}

/// Saffron's one press ledge colour (LOOK-7), design-styles.md's `ledge`
/// token: `#A86C00`, fixed rather than derived from `primary`. should-fix,
/// platform review: deriving it as `primary` minus an absolute 0.18 HSL
/// lightness step composited to near-black (`#2E1B00`, 15.84:1 on the page)
/// in Saffron light, because in this build `primary` already **is** the
/// button's own fill and is itself fairly dark (`#8A5200`, L 0.27) — no
/// separate, brighter "slab" role survived the merge into one `ColorScheme`
/// per look for [primary] to shade relative to. This fixed value is
/// 4.19:1 on the light page and 4.34:1 on the dark one (design-styles.md's
/// own measurements), so it reads as shading, not a black rule, in both.
const _saffronLedge = Color(0xFFA86C00);

Decor _decorFor(
  AppStyle style,
  ColorScheme cs,
  WasfatiRadii radii,
  OutlinedBorder chipShape,
) {
  OutlinedBorder rounded(double radius) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  if (style == AppStyle.ink) {
    return Decor(
      // The reading-edge rail, Ink's signature move (design-styles.md
      // "Signature moves" #1).
      railWidth: 3,
      railColor: cs.primary,
      cardShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.card),
        side: BorderSide(color: cs.outline),
      ),
      // The hero photo's two bottom corners only (Directional, so it
      // mirrors with the language with no code branch).
      photoShape: RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.vertical(
          bottom: Radius.circular(radii.photo),
        ),
      ),
      chipShape: chipShape,
      buttonShape: rounded(radii.button),
      thumbnailShape: rounded(radii.chip),
      // LOOK-4: the amount in primary at w600.
      amountColor: cs.primary,
      amountWeight: FontWeight.w600,
      // LOOK-7: no shadow, elevation or ledge anywhere in Ink.
      ledgeDepth: 0,
      ledgeColor: Colors.transparent,
      rowHairline: cs.outlineVariant,
      groupedRowFill: cs.surfaceContainerLow,
      ornament: EmptyOrnament.khatam,
    );
  }

  return Decor(
    // Saffron marks a heading with a thicker 4dp bar rather than dropping
    // the rail entirely (design-styles.md's recipe/plan/settings screens).
    railWidth: 4,
    railColor: cs.primary,
    cardShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radii.card),
      side: BorderSide(color: cs.outline, width: 1.5),
    ),
    // "full-bleed and square-cut" — no rounding (design-styles.md).
    photoShape: const RoundedRectangleBorder(),
    chipShape: chipShape,
    buttonShape: rounded(radii.button),
    // LOOK-6, "The chamfer": one of the five things Saffron cuts.
    thumbnailShape: ChamferedBorder(borderRadius: radii.chip),
    // LOOK-4: Saffron keeps the amount in the body colour, only heavier.
    amountColor: cs.onSurface,
    amountWeight: FontWeight.w600,
    // LOOK-7: Saffron's one press ledge, under exactly three primary
    // actions; a widget built later reads this to draw and collapse it.
    ledgeDepth: 2,
    ledgeColor: _saffronLedge,
    rowHairline: cs.outlineVariant,
    groupedRowFill: cs.surfaceContainerLow,
    ornament: EmptyOrnament.lattice,
  );
}
