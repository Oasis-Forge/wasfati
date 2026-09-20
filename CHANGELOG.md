# Changelog

Notable changes per release, written for users. Versions follow [Semantic Versioning](https://semver.org) and match the app version and the `vX.Y.Z` git tags. Every merged PR is a release (see `docs/RELEASING.md`).

## [Unreleased]

## [0.7.2] - 2026-09-20

### Changed
- The privacy policy is now one page in Arabic and English, and email is the only way to reach support. No app changes yet.

## [0.7.1] - 2026-09-20

### Changed
- The rules for the meal plan, Ramadan mode, groceries, sharing a recipe, backups, translation, and the Pro and Premium prices. No app changes yet.

## [0.7.0] - 2026-09-19

### Added
- Import a recipe from a link: paste or share a link from sites like Fatafeat, Cookpad or Sayidaty, check the recipe, and save it. Pages are read on your phone, free and unlimited, and the photo comes too.
- Share recipe text from any app into Wasfati: it opens as a draft with the title, ingredients and steps already split.
- If you import a page you already saved, Wasfati offers to open the saved one.

## [0.6.0] - 2026-09-19

### Added
- Cook mode, free and without ads: one step at a time in large text, and the screen stays on while you cook.
- Timers straight from the recipe: "لمدة 15 دقيقة" or "ساعة ونصف" becomes a button. Several can run at once, and you're told when one ends, even with the app in the background.
- The ingredients, scaled the way you set them, one tap away in cook mode, with checkboxes.
- "Mark as cooked" at the end. Cook mode picks up where you left off within 12 hours.

### Changed
- English ingredient lines always use 123, even when you've chosen ١٢٣.

## [0.5.0] - 2026-09-19

### Added
- Scale any recipe: ×½, ×2, ×3, or one serving at a time. Amounts round the way a cook would (½ onion, ⅛ cup, whole grams), including amounts written in ١٢٣.
- Lines that can't be scaled, like "salt to taste", are marked "not scaled", so nothing changes behind your back.
- Show amounts as written, in grams and millilitres, or in cups and spoons. Flour, sugar, rice and about 30 other ingredients convert by weight; water, milk, broth and oil stay in ml. Each recipe remembers your choice.
- Scaling and conversion are free.

## [0.4.0] - 2026-09-19

### Added
- Search your recipes by name or ingredient. Search forgives Arabic spelling differences (أ/ا، ة/ه، diacritics), and a recipe found by one of its ingredients says so ("يحتوي: كزبرة").
- Sort by newest, A–Z, recently cooked or most cooked, and filter by cookbook, tag, source, time or photo. Your sort and your list or grid view are remembered.
- Cookbooks: group recipes your way (a recipe can be in several), rename them or delete them without losing any recipes.
- Tags on recipes, with your most-used tags suggested as you type.

## [0.3.0] - 2026-09-19

### Added
- Write your own recipes: title, photo, servings, times, ingredients (one per line; a line ending with ":" starts a group like "للدقوس:"), steps and notes. Amounts are read as you type, including ١٢٣, fractions and words like كوبين.
- A recipe page with the amounts in your chosen digits (123 or ١٢٣), and each line reading in its own direction, so English and Arabic recipes both look right.
- Delete a recipe and undo it within 5 seconds; deleted recipes stay in the trash for 30 days.
- Settings: language, numbers (123 / ١٢٣), units, week start and theme.
- The IBM Plex Sans Arabic font.

## [0.2.0] - 2026-09-19

### Added
- The first app build: Wasfati opens in Arabic (right to left) or English, following the phone's language, with an empty recipe library ready for Phase 2.
- Recipes are stored safely on the phone: every save is all or nothing, deleted recipes wait 30 days in the trash, and nothing leaves the device.

## [0.1.5] - 2026-09-19

### Changed
- Planned how Instagram recipes are imported: share the post, then paste its caption or share a screenshot. No app changes yet.

## [0.1.4] - 2026-09-19

### Changed
- Groundwork: the engine that reads Arabic ingredient amounts and units (١٢٣, fractions, words like نصف and كوبين), with tests from real recipes. Not visible in the app yet.

## [0.1.3] - 2026-09-19

### Changed
- The rules for recipes, Arabic quantities and units, scaling, cook mode, organizing, import and the import server. No app changes yet.

## [0.1.2] - 2026-09-19

### Changed
- The full plan to v1: build order, weekly timeline, and a launch before Ramadan 2027. No app changes yet.

## [0.1.1] - 2026-09-19

### Changed
- Hands-on research of the leading recipe app, and the support email in the privacy policy. No app changes yet.

## [0.1.0] - 2026-09-19

### Added
- Project setup: docs, Claude Code tooling, CI, and the release workflow.
