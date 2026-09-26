# Design styles: سُفرة · Sufra

_Designed 26 September 2026 (Decision 23). One design, warm and photo-forward, replaces the two styles of Decision 14 — حبر (Ink) and زعفران (Saffron) — whose names now label the two accent colours a Sufra install can pick in Settings, not two different layouts. Reference mockups: `docs/design/sufra/*.dc.html` and their rendered PNGs, one phone screen each at 390 × 844 CSS px; a CSS px is one Flutter dp throughout this document._

## At a glance

Every screen sits on a warm linen page with white cards floating on soft shadows, food photography shown large, and pill-shaped controls everywhere a Material app would draw a rectangle. The signature moves:

- **Photo-forward cards.** The library grid is dominated by the dish photo; text sits on a dark gradient over the lower half rather than beside it.
- **The sheet over the hero photo.** The recipe page's content panel starts 30 dp above the bottom of a full-bleed photo and overlaps it, rounded top corners first.
- **The dark floating navigation pill.** A near-black pill floats clear of the bottom edge on the four main screens, with a raised accent "+" at its centre that opens every way to add a recipe.
- **Pill controls throughout.** Buttons, chips, the search field, segmented controls and steppers are all radius-999 pills; only cards, photos and sheets keep large-but-finite radii.
- **The drawn cover.** A recipe with no photo gets a tinted, patterned illustration instead of a placeholder, keyed off its own ID so it's stable everywhere it appears.
- **Amounts in the accent.** Every quantity in an ingredient or grocery line is set in the accent colour at weight 700 — carried over unchanged from Decision 14, now on a warmer page.

The two accents from Decision 14 stay exactly as user-facing choices — **زعفران / Saffron** (paprika-orange, default for new installs) and **حبر / Ink** (teal) — but now differ from each other in colour only (LOOK-2): one shared layout, one shared shape language, one shared shadow system.

## Palette

Hex values are exact, taken from the spec's tokens; CSS px in the mockups equal Flutter dp.

### Shared surfaces (identical in both accents)

| Token | Light | Dark | Use |
|---|---|---|---|
| `page` | `#F6F1EA` | `#14110E` | screen background |
| `card` | `#FFFFFF` | `#201C18` | cards, modal sheets, the search field |
| `sunk` | `#EFE8DF` | `#2B2621` | segmented-control track, stepper track, chip rest state, banner placeholder |
| `ink` | `#1F1A15` | `#F5EFE8` | main text, icons, the light-mode nav pill's own fill |
| `ink2` | `#62574C` | `#BDB2A6` | secondary text, captions, inactive icons on a light surface |
| `line` | `#E8E0D5` | `#332D27` | hairline separators inside a card, and (dark only) a card's own edge |
| `border` | `#8F8475` | `#8C8072` | the 1 px edge of a field, unselected chip or outlined button |
| `herb` | `#2E6B4F` | `#7FC7A0` | done/checked state, the "in the plan" band's icon |
| `herbSoft` | `#E3F0E8` | `#1D3328` | the "in the plan" band fill, a checked checkbox's fill |
| `onHerbSoft` | `#1E4A36` | `#BFE8CF` | text/icon on `herbSoft` |
| `onHerb` *(added here, see §Contrast)* | `#FFFFFF` | `#1F1A15` | the check glyph on a `herb`-filled checkbox |

### زعفران Saffron (default for new installs)

| Token | Light | Dark |
|---|---|---|
| `accent` | `#C2410C` | `#F28A4B` |
| `onAccent` | `#FFFFFF` | `#1F1A15` |
| `accentSoft` | `#FCE9DD` | `#3A2418` |
| `onAccentSoft` | `#7A2A08` | `#FFD2B5` |

### حبر Ink

| Token | Light | Dark |
|---|---|---|
| `accent` | `#0F766E` | `#5EC9BD` |
| `onAccent` | `#FFFFFF` | `#1F1A15` |
| `accentSoft` | `#DDF1EE` | `#16332F` |
| `onAccentSoft` | `#0B4F49` | `#BFEDE6` |

`AppStyle.saffron` / `AppStyle.ink` (`lib/models/settings.dart`, unchanged) select which of these two four-row tables feeds the one Sufra `ColorScheme` builder — replacing today's `isInk` branches across every `ThemeData` sub-theme with a single shape language parameterised only by four colours. The stored default flips to `AppStyle.saffron` (LOOK-1); an install with a saved choice keeps it.

### Flutter `ColorScheme` mapping

| Role | Token | Role | Token |
|---|---|---|---|
| `primary` | `accent` | `secondaryContainer` | `herbSoft` |
| `onPrimary` | `onAccent` | `onSecondaryContainer` | `onHerbSoft` |
| `primaryContainer` | `accentSoft` | `surface` | `page` |
| `onPrimaryContainer` | `onAccentSoft` | `surfaceContainerLowest` | `card` |
| `secondary` | `herb` | `onSurface` | `ink` |
| `onSecondary` | `onHerb` | `onSurfaceVariant` | `ink2` |
| | | `outline` | `border` |
| | | `outlineVariant` | `line` |

Every role above also gets a same-named field on a `SufraColors` `ThemeExtension`, so a Sufra-specific widget reads `Theme.of(context).extension<SufraColors>()!.ink2` by its design name instead of reaching through the M3 role, while ordinary Material widgets (dialogs, form fields) still pick up the right colour automatically through `ColorScheme`.

### `ThemeExtension<SufraColors>`: tokens `ColorScheme` has no role for

- `sunk` (both brightnesses, above)
- `navPillFill` — light: `ink` (`#1F1A15`); dark: `#2B2621`, 1 px border `navPillBorder` `#3A332C`
- `navInactive` — `#A89C8F` in light (against the light-mode pill's `ink` fill); in dark the pill's own `ink2` (`#BDB2A6`) already does the job at 7.19:1 against `navPillFill`, so no second dark value is minted
- `shadowLift` — `0 1px 2px rgba(47,32,18,.06), 0 8px 24px rgba(47,32,18,.08)`, light only
- `shadowFloat` — `0 12px 32px rgba(31,26,21,.28)`, light only
- `cardHairlineDark` — `line` (dark), the 1 dp border a card takes in place of a shadow
- six `coverTint` / `coverTone` pairs (below), for the drawn cover
- `radiusCard` 22, `radiusPhotoCard` 24, `radiusSheet` 28, `gutter` 20 (mirrors §Shape, kept here too since custom painters and the drawn cover read them directly rather than via `Theme.of(context).cardTheme`)

### The six drawn-cover tints

LOOK-10 picks one of six tints from the recipe's ID. The spec's mockups show only sage; the other five extend the same warm, muted family and clear contrast comfortably in both brightnesses (tone-on-tint in light, tone-on-`card` in dark, computed in §Contrast):

| Name | Light tint | Light tone | Dark tone (on `card`) |
|---|---|---|---|
| sage | `#DDE8D5` | `#3F5A36` | `#8FBE86` |
| clay | `#F3DCCB` | `#7A4B2E` | `#D69A6B` |
| honey | `#F5E6B8` | `#7A5C12` | `#D9B84A` |
| dusty rose | `#F0D9D9` | `#7A3F3F` | `#D99B9B` |
| denim | `#D8E3EC` | `#35526E` | `#7FA8C9` |
| plum | `#E6D9EC` | `#5B3E70` | `#B08FC4` |

## Contrast

Computed with the WCAG 2.1 sRGB relative-luminance formula; every value below is measured, not estimated. Bars: 4.5:1 for body text, 3:1 for large text (≥14 px at weight ≥600, which covers every accent-coloured amount, LOOK-4) and for a control's boundary, no bar for a purely decorative hairline (LOOK-3's own card exemption).

**Light, shared tokens (both accents):** `ink`/page 15.36, /card 17.26, /sunk 14.20. `ink2`/page 6.26, /card 7.03, /sunk 5.78. `border`/card 3.67, /page 3.26 (both clear the 3:1 boundary bar). `line`/card 1.31 — decorative only, never a control edge.

**Light, Saffron:** `accent`/page 4.61, /card 5.18, /sunk **4.26**. `onAccent` (white) on `accent` 5.18. `herb`/page 5.61, /card 6.30; `onHerb` (white) on `herb` 6.30; `onHerbSoft`/`herbSoft` 8.57.

**Light, Ink:** `accent`/page 4.87, /card 5.47, /sunk **4.50**. `onAccent` (white) on `accent` 5.47.

**Dark, shared tokens:** `ink`/page 16.48, /card 14.83, /sunk 13.12. `ink2`/page 9.03, /card 8.13, /sunk 7.19. `border`/card 4.39, /page 4.88. `line`/card 1.25 — decorative, matches the light ratio's role.

**Dark, Saffron:** `accent`/page 7.63, /card 6.86, /sunk 6.07. `onAccent` (`#1F1A15`) on `accent` 7.00. `herb`/page 9.48, /card 8.53; `onHerbSoft`/`herbSoft` 10.06.

**Dark, Ink:** `accent`/page 9.46, /card 8.52, /sunk 7.54. `onAccent` (`#1F1A15`) on `accent` 8.68.

**Navigation pill.** Light (fill = `ink`): `onAccent`-white active icon+label/fill 17.26; `navInactive`/fill 6.42; the active dot, Saffron 3.33, Ink 3.15 — both clear 3:1 but only just, which is fine because LOOK-7 already marks the active slot by colour **and** the dot, never the dot alone. Dark (fill = `navPillFill` `#2B2621`): `ink`/fill 13.12; `ink2` (standing in for `navInactive`)/fill 7.19; `navPillBorder`/fill 1.21 and fill/page 1.26 — both below 3:1, accepted under the same exemption as a card's dark hairline: the pill is a container read by its shape, fixed position and icon content, not by an edge a finger has to find.

**Flags — pairs under their bar, and what covers them:**
1. `accent`/`sunk`, light: Saffron 4.26, Ink 4.50 — both under or right at the 4.5 body-text bar. Covered by construction: LOOK-4 sets every accent-coloured piece of text at weight ≥600 (700 for amounts), which is "large text" (3:1), cleared with margin. **Rule:** never set accent-coloured text at regular (400) weight on `sunk`; keep regular-weight accent text (a link, say) to `card` or `page`.
2. `onHerb` white on `herb`-dark: **1.98:1, fails outright.** `herb`-dark (`#7FC7A0`) is a bright mint, the same shape of problem `accent`-dark solves by flipping its text colour (this document's dark-mode `ColorScheme` already does this for `onPrimary`). `onHerb` gets the identical flip — white in light, `#1F1A15` in dark (8.69:1) — so a dark-mode checked checkbox's check glyph stays legible. This token is new; nothing in the spec's dark table named it, because the spec only shows the recipe page (light) and cook mode (dark) — neither has a checked checkbox on-screen.
3. Card and nav-pill hairlines in dark (both ~1.2–1.3:1) are intentionally under 3:1: LOOK-3 exempts a card's edge from the boundary bar because a card is "known by its content and a shadow," and the same logic covers the pill, a container rather than an interactive control.

**Digits, hint text, disabled text** carry over from Decision 14 unchanged: Western 0–9 by default with an ١٢٣ Settings option (both parsed, QTY-1/QTY-5); hint text at full `ink2`, never faded; disabled text at `ink2` (already ≥3:1 everywhere above), never Material's 38% default.

## Type

One family, **IBM Plex Sans Arabic** (400–700), `letterSpacing: 0` on every token — unchanged reasoning from Decision 14: the font's own metrics (upem 1000, `USE_TYPO_METRICS` on, winAscent 1.128 em, winDescent 0.601 em) put its collision-free floor at 1.729 em, so LOOK-5 rounds that to two built heights: **1.75** on any token whose text can wrap to a second line, **1.50** on chrome that is always one line by construction (a pill's label, a nav caption — sized and clipped so it never needs a second line).

The mockups' own CSS line-heights (30/700/**1.45** for `display`, 14/400/**1.6** for `bodyS`, and so on) are a per-artboard visual choice for a screen that is a fixed screenshot and never reflows (§2 of the design spec). The built `TextTheme` applies LOOK-5's binary rule instead, since LOOK-8 requires every screen to survive 1.3× text on a 360 dp phone without clipping:

| Token | Size / weight | Height | Use |
|---|---|---|---|
| `display` | 30 / 700 | 1.75 | home greeting, welcome title |
| `titleL` | 26 / 700 | 1.75 | recipe title, screen titles (الخطة، المشتريات، الإعدادات) |
| `title` | 19 / 700 | 1.75 | section headings, aisle names |
| `titleS` | 16 / 600 | 1.75 | card titles, list item titles |
| `body` | 16 / 400 | 1.75 | ingredient lines, step text, paragraphs |
| `bodyS` | 14 / 400 | 1.75 | subtitles, meta ("50 دقيقة · 4 حصص") |
| `label` | 14 / 600 | 1.50 | button, chip and segmented labels (always `maxLines: 1`) |
| `caption` | 12 / 600 | 1.50 | badges, nav labels, small counters (always `maxLines: 1`) |
| `cookStep` (derived) | 27 / 500 | 1.75 | cook mode's step text |

`cookStep` is `body.fontSize * 1.6875` (16 → 27, the mockup's own value), defined as a multiplier rather than a literal so COOK-2's "at least 1.5× body" floor holds even if `body` ever moves; a unit test asserts `cookStep.fontSize >= body.fontSize * 1.5`, the same pattern Decision 14 used. `MaterialApp.textHeightBehavior` keeps `leadingDistribution: TextLeadingDistribution.even` app-wide, since Flutter's `proportional` default starves the descent band Arabic bowls and tashkeel live in.

## Shape, spacing and depth

**Radii:** cards 22, photo cards 24, a sheet's or dialog's top corners 28. Buttons, chips, the search field, segmented controls and steppers are pills (999); round icon buttons are circles. Smaller in-card radii: stat tiles and the quota-row border-card 18, add-sheet tiles and the scale-bar card 22, aisle/settings icon tiles 11–12, the "in the plan" / Ramadan-offer bands 16.

**Heights:** primary buttons 56, secondary buttons 48, chips 36 visual with a 48 tap target, round icon buttons 44 (48 in cook mode's top row; the bottom-row ingredients button in cook mode matches its 56 dp neighbours instead, so the row reads as one control), the search field 52, the navigation pill 68. Touch targets never drop under 44 × 44.

**Spacing:** a 20 dp screen gutter and a 28 dp gap between sections, both fixed tokens (`gutter`, above) rather than ad hoc numbers scattered per screen.

**Depth, two shadows, light only:**
- `shadowLift` on every card, the search field and floating round buttons — a soft, close-in shadow plus a wider ambient one.
- `shadowFloat`, deeper, on the navigation pill and the two primary-action buttons that float over content (a recipe page's "ابدأ الطبخ", cook mode's "التالي").

Neither is a Material `elevation` value: both are hand-drawn two-layer `BoxShadow` lists on a `SufraCard`/`SufraButton`-style wrapper, because M3's single-shadow elevation can't reproduce a two-layer warm shadow, and `surfaceTintColor` stays `Colors.transparent` everywhere so Material's elevation tint never appears — carried over unchanged from Decision 14. **Dark mode drops both shadows entirely**: a card, sheet or the navigation pill instead takes a 1 dp `line`/`navPillBorder` hairline, per §Contrast's exemption.

## Components

| Component | Maps to | Notes |
|---|---|---|
| Primary button | `FilledButtonThemeData` + `shadowFloat` wrapper | pill, `primary` fill, `onPrimary` text, 56 dp, full-width when it's a screen's one main action |
| Secondary button | `OutlinedButtonThemeData` | pill, 1.5 dp `border`, `ink` text, 48–56 dp |
| Chip | `ChipThemeData` | pill (999); unselected = `card` fill + `shadowLift` (library quick filters) or plain `sunk` fill (inline badges like `×2`); selected = `ink` fill + white text, or `accentSoft` fill + `onAccentSoft` text where it sits inside an already-accented context |
| Card | `SufraCard` widget, not `CardThemeData`'s elevation | 22 dp (24 photo), `card` fill, `shadowLift`; dark drops the shadow for a 1 dp `line` border |
| Text field | `InputDecorationTheme` | `card` fill, 1 dp `border` at rest / 2 dp `accent` focused; a 16 dp radius for multi-line fields (the editor), since a pill is wrong for a field that wraps |
| Search field | `SufraSearchField` widget | pill, 52 dp, `card` fill, `shadowLift`, leading search icon, trailing 44 dp `accent`-circle filter button ("تصفية") |
| Modal sheet | `BottomSheetThemeData` | `card` fill (a distinct floating surface over a `rgba(20,14,10,.45)` scrim), 28 dp top radius, 40×4 `border` grab handle — the add sheet |
| Recipe page's content panel | not a `BottomSheetThemeData` sheet | `page` fill (it's the screen's own scroll body continuing past the photo, not a separate surface), same 28 dp top radius and overlap-by-30 dp |
| Dialog | `DialogThemeData` | `card` fill, 22 dp radius, same scrim as the modal sheet |
| Snackbar | a pill-shaped cousin of the nav pill | `ink` fill / `onSurface`-flip text in light, `card` fill + `line` border in dark, floating with `shadowLift`, 16 dp radius |
| Checkbox | `CheckboxThemeData` | 24 dp **circle** (not M3's square); unchecked = 1.5 dp `border` ring; checked = `herb` fill, `onHerb` check |
| Switch | `SwitchThemeData` | 44×26 pill track, `sunk` off / `accent` on, a `shadowLift` white knob |
| Segmented pill | `SegmentedPill` widget (not M3 `SegmentedButton`, which is squared) | `sunk` track; two selected treatments share one widget behind a `raised` flag: a `card`-fill thumb + `shadowLift` for a screen's primary view switch (all-recipes/cookbooks, ingredients/steps) — in dark, where `card` is darker than `sunk` and would read as a hole in the track, the thumb fills with `line` (lighter than `sunk`) and keeps its 1dp `border` edge, a flat `accentSoft` fill with no shadow for a secondary control nested inside another card (the scale bar's unit toggle) — so a screen never stacks two raised pills |
| Servings stepper | `ServingsStepper` widget | `sunk` pill track holding two 40 dp circular ± buttons (`card` fill + `shadowLift`) around a `titleS` value |
| Round icon button | `RoundIconButton` widget | circle; light = `card` fill + `shadowLift`; dark = `sunk` fill, no shadow (except the always-solid-`accent` centre "+"/play, which ignores brightness) |
| Drawn cover | `DrawnCover` widget (`CustomPainter`), replaces the narrower `lib/widgets/ornament.dart` | one of six `coverTint` fills (§Palette), an 8-point khatam line pattern in the matching tone at 18% opacity (~28 dp pitch), the title's first Arabic letter centred at 72/700 in the tone |
| Navigation pill | `FloatingNavBar` widget, replaces `NavigationBarThemeData`/`NavigationBar` | not expressible as a `NavigationBarThemeData` shape/indicator: a 68 dp pill floating 12 dp above the edge with a raised 52 dp accent circle at its centre, so it is hand-built |
| Banner slot | `lib/widgets/ad_slot.dart` `AdSlot`, unchanged logic | restyled only: `sunk` fill, dashed `border` top/bottom, «إعلان» caption; still sits 8 dp above the nav pill, outside scrolling content (ADS-3, ADS-9) |

## Screen by screen

**Navigation shell** (`home_screen.dart`) — `HomeScreen`'s `NavigationBar` is replaced by `FloatingNavBar`: خمس مواضع, right to left, الوصفات، الخطة، (centre +), المشتريات، الإعدادات (LOOK-7). `AdSlot` sits 8 dp above it. Pushed screens (a recipe, cook mode, the editor, import, a cookbook, purchase) build no pill.

**Add sheet** (`AddSheet.dc.html`, LOOK-11) — a new bottom sheet opened by the pill's centre "+", replacing today's three scattered entry points (the FAB's direct `openEditor(context)` call and the AppBar's import icon). A 2×2 tile grid — link and pasted-text tiles both route into the existing `ImportScreen` (which already handles IMP-1/IMP-3 in one flow), the photo tile routes into `ImportScreen`'s photo picker (IMP-10), and "أضفها بنفسك" opens `RecipeEditorScreen` directly — plus the quota row (IMP-7) reusing whatever widget already renders "X من 10 متبقية". No new import logic, only a new front door.

**Library and cookbooks** (`home_screen.dart` `LibraryHome`, `library_view.dart`) — the greeting/question header, the كل الوصفات/كتب الطبخ `SegmentedPill`, `SufraSearchField` with its filter circle, the quick-filter chip row, and the conditional "تابع الطبخ" resume card (COOK-6) all sit above `_RecipeCard`'s new photo-card treatment: full-bleed photo, bottom gradient to `rgba(20,14,10,.78)`, white text over it, a frosted source-badge chip. `RecipeThumb` becomes `DrawnCover` wherever a recipe has no photo (LOOK-10). `CookbookScreen` keeps its own `AdSlot` (ADS-9).

**Recipe page** (`recipe_screen.dart`, LOOK-13) — full-bleed hero photo (330 dp) with four floating `RoundIconButton`s (back, share, edit, more); the content panel (`page` fill, not `card` — see §Components) overlapping it by 30 dp holds the source/tag chip row, `titleL` title, up to three stat tiles (REC-3), the `herbSoft` "في الخطة" band (PLAN-3) when planned, the المكونات/طريقة التحضير `SegmentedPill` (opens on Ingredients), the scale bar (`ServingsStepper` + multiplier chips + a second, flat `SegmentedPill` for the unit view, SCALE-6), and the ingredient card (`AmountLine`-style rows, a rotated-square accent bullet, `line` hairlines). A fixed bottom bar over a `page`→transparent fade holds "ابدأ الطبخ" (COOK-1) and two `RoundIconButton`s for plan (PLAN-3) and groceries (GRO-2), then `AdSlot`. `RecipeDark.dc.html` is the same layout on dark tokens with طريقة التحضير selected: steps become rows with a 32 dp `accentSoft` numbered square, and any timer phrase inside a step's text becomes a small tappable `sunk` pill in `label`/`accent` (COOK-4's timer, surfaced inline rather than only in cook mode).

**Cook mode** (`cook_mode_screen.dart`, LOOK-14) — always dark tokens regardless of the device's theme setting, no `AdSlot` ever (COOK-1). A segmented step rail (done cells `accent` at 45%, the current cell solid and 6 dp tall, future cells `sunk`) replaces `_TimersBar`'s sibling progress indicator; the step counter and the active scale (`×2`, an `accentSoft` pill) sit under it; step text at `cookStep`; the timer card is a 150 dp ring (`sunk` track, `accent` arc) over a start-timer pill, with a `sunk` running-timer band below it once started. Three bottom controls — السابق (`OutlinedButton`, `border`), a round ingredients button (`sunk`), التالي (`FilledButton`, `shadowFloat`) — sit at the edge a wet thumb reaches (COOK-2).

**Plan** (`plan_screen.dart`, PLAN-1) — a week-range header with a "أضف الأسبوع إلى المشتريات" `RoundIconButton`, a 7-pill week strip (`_DayCard`→ a 46×72 pill; today = `ink` fill + white text + an accent dot; a day with entries carries a `herb` dot, per the amended PLAN-1 that replaced last week's one-long-list view), then **one day's** timeline under a `line`-coloured vertical rail with a node per meal slot (فطور، غداء، عشاء، وجبة خفيفة, PLAN-1's fixed order): a recipe slot is a card with a 56 dp photo/`DrawnCover` thumb, a note slot (`_FromLine`-equivalent) is a plain card with a pencil icon, and an empty slot is a dashed `border` outline with «+ إضافة» in `accent` label text. RAM-3's offer card and RAM-4's رمضان/الأسبوع toggle sit above the strip using the same card and `SegmentedPill` components, unchanged in behaviour.

**Groceries** (`groceries_screen.dart`, GRO-1–GRO-7) — an `ink`-filled progress card (dark-on-light for drama, the one card in the whole app that inverts the ladder on purpose) with a ring progress indicator and the "من: …" recipe-name caption; a `SufraSearchField`-styled add field (GRO-1's parse-on-type); a حسب الممر/حسب الوصفة `SegmentedPill`; then aisle cards (GRO-4's fixed order) with a tinted rounded-square icon tile, the aisle name, a count, and 52 dp item rows with a 24 dp circular checkbox, the name, and the amount right-aligned in `accent`/700 (LOOK-4), forced LTR. **The mockup's static frame shows a ticked item staying inline with strikethrough — the built screen still moves it into the collapsed "تم" section per GRO-5** once the tick animation (§Motion) finishes; "Clear done"/"Clear all" keep their Undo (DEL-2).

**Settings** (`settings_screen.dart`) — a Pro/Premium upsell card (no price, no badge, no countdown, PAY-6) using the same tile-icon-plus-text layout as every grouped row below it; three groups — المظهر واللغة، الطبخ والخطة، بياناتك — each a caption heading over one `SufraCard` of 60 dp rows (a tinted icon tile, the label, the current value, a chevron), `line` hairlines inset 64 dp. الطراز's value carries a 14 dp accent dot; الأرقام is an inline mini `SegmentedPill` (123/١٢٣) instead of a chevron row, matching Decision 5's rule that this is a toggle, not a picker; وضع رمضان gets the switch component in place of a chevron (RAM-1). PAY-11's subscription row and ADS-5's consent row join بياناتك in the same pattern once they exist (Phase 5).

**First run and the walkthrough** (`first_run_screen.dart`, `walkthrough_screen.dart`) — `Welcome.dc.html`'s four-page walkthrough: an `accentSoft` blob behind three rotated, badge-marked recipe cards, a `display` title, `ink2` body copy, 4 page-dots (an accent 24×8 pill for the current page, `border` 8×8 dots otherwise), and a full-width primary pill "التالي". `SetupScreen`'s choices (style, language, digits, week start — RUN-3/RUN-4) reuse `_Choice`'s existing grouped-row pattern restyled to match Settings.

**Purchase** (`purchase_screen.dart`, PAY-6/PAY-10) — `_TierCard` becomes a `SufraCard` per tier with the Pro/Premium colours and the primary-pill purchase button; store prices only (PAY-2), never invented ones.

**Editor, import, preview and translate** (`recipe_editor_screen.dart`, `import_screen.dart`, `translate_flow.dart`) — restyled, not re-laid-out: the same field order, the same group labels now on `SufraCard` groups, the same progress/failure states, now in pill buttons and `InputDecorationTheme`'s new fill/radius. No `AdSlot` on any of the three (ADS-1, ADS-9).

## Motion

Five notes, all skipped under `MediaQuery.disableAnimations` / reduce-motion (a static swap replaces every transition below, with no missing state):

1. Press feedback: scale to 0.97 over 120 ms on any pill button or tappable card.
2. A modal sheet slides up over 280 ms, ease-out.
3. The recipe hero photo parallaxes at 0.5× under the content panel while it scrolls.
4. A ticked grocery item animates into the collapsed "تم" section 600 ms after the tick (GRO-5).
5. Cook mode's step content cross-fades over 200 ms between steps.

## Build order

Five PRs, `docs/ROADMAP.md`'s Redesign section, each based on `main` and merged in order:

1. **Foundation, navigation, the add sheet** (LOOK-1–LOOK-8, LOOK-10) — this PR: both accents' tokens in light and dark, the contrast test, the shared components above, `FloatingNavBar` with الإعدادات in it, the add sheet, `AdSlot` restyled. زعفران becomes the default for new installs.
2. **Library and adding** (LOOK-12, ORG-3–ORG-6, IMP-1–IMP-5) — the library home, cookbooks, the import screens, preview and editor.
3. **Recipe page and cook mode** (LOOK-13, LOOK-14, COOK-1–COOK-6, SCALE-6, IMP-14) — the hero, the sheet, the tabs, the action bar; cook mode; translate and shared images (SHARE-3) in the new palette.
4. **Plan and groceries** (PLAN-1–PLAN-5, RAM-1–RAM-4, GRO-1–GRO-6) — the week strip and day timeline, Ramadan, the progress card and aisle cards.
5. **Settings, first run, purchase** (RUN-3, RUN-4, PAY-6, PAY-10, PAY-11, ADS-5) — grouped settings rows, setup and the walkthrough, the purchase screen; retire the Ink/Saffron-only widgets (`rail_heading.dart`, `ornament.dart`, `chamfered_border.dart`, `pressable_slab.dart`) that this design no longer needs.
