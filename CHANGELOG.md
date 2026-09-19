# Changelog

Notable changes per release, written for users. Versions follow [Semantic Versioning](https://semver.org) and match the app version and the `vX.Y.Z` git tags. Every merged PR is a release (see `docs/RELEASING.md`).

## [Unreleased]

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
