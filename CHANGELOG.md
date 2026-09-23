# Changelog

Notable changes per release, written for users. Versions follow [Semantic Versioning](https://semver.org) and match the app version and the `vX.Y.Z` git tags. Every merged PR is a release (see `docs/RELEASING.md`).

## [Unreleased]

## [0.14.1] - 2026-09-23

### Changed
- The rules behind the coming AI import: what the import server sends back, the model it uses, and what Premium will include. No app changes yet.

## [0.14.0] - 2026-09-23

### Added
- Two looks, chosen in Settings under "الطراز": حبر, quiet ink on paper, and زعفران, warmer, with cut corners and a button you can feel. Each has its own light and dark, the choice applies at once, and a backup remembers it.
- Wasfati now wears its own name and face: وصفاتي on an Arabic phone, Wasfati on an English one, with a new icon and splash screen.

### Changed
- Amounts now stand out in every ingredient line, on the recipe page, in cook mode and on the grocery list.
- A recipe shared as pictures follows the look you picked.
- Changing your phone's own language now changes Wasfati straight away, instead of at the next start.

### Fixed
- Restoring a backup made on another phone no longer mixes one recipe's ingredients and steps from both phones: the newer version of that recipe wins, whole.
- A backup is now written and read straight from the file, so a large photo library no longer has to fit in memory.
- A recipe whose photo went missing, after Android restored the phone itself, no longer shows up under "بصورة".

## [0.13.0] - 2026-09-22

### Added
- A first look: a new install opens with one sample recipe, شوربة عدس, to try scaling, unit conversion and cook mode on. Delete it whenever you like; it won't come back.

## [0.12.0] - 2026-09-22

### Added
- Back up everything to one file you keep: recipes and their photos, cookbooks, tags, the meal plan, the grocery list and your settings. Save it to Google Drive or Files, or send it anywhere through the share sheet.
- Restore by merging with what's on your phone, where the newer version of each item wins, deletions included, or by replacing it. Before any restore, Wasfati keeps an automatic copy of what was there; the last three stay in Settings.
- A gentle reminder once you have 10 recipes and no backup in 30 days. Turn it off in Settings.
- Export all your recipes, or one cookbook, as a text file.
- Android's own phone backup now includes your recipes and settings; photos travel in Wasfati's backup file.

### Changed
- The privacy policy now describes backups and exports.

## [0.11.0] - 2026-09-22

### Added
- Share a recipe from its page, as text or as pictures. Both show the recipe exactly as you're looking at it: scaled, converted, and in your digits.
- As text: the ingredients and numbered steps, the source link, and a line with where to get Wasfati. Your notes, tags and rating stay private.
- As pictures: portrait pages sized so WhatsApp keeps them sharp, with the photo on the first page. Each line reads in its own direction, and a page never breaks in the middle of a line.

## [0.10.0] - 2026-09-22

### Added
- Ramadan mode. On Ramadan days the plan shows السحور، الإفطار and وجبة خفيفة, with the Hijri date beside each day and عيد الفطر after the last. Anything already planned for lunch or dinner stays where you put it.
- A week before Ramadan the plan offers to switch; it never switches by itself. Turn it on or off any time in Settings.
- A whole-month view for planning Ramadan, and "add to groceries" for the rest of the month.
- If your country starts Ramadan a day earlier or later than the Umm al-Qura calendar, move it in Settings; it resets for the next year.

## [0.9.0] - 2026-09-21

### Added
- A grocery list. Add a recipe's ingredients exactly as the recipe shows them, scaled and converted, or send the whole week's plan in one go. The same ingredient from several recipes becomes one line with the right total: 1 كغ and 500 غ make 1.5 كغ.
- Twelve aisles that know Arabic ingredient names, from خضار وفواكه to مستلزمات الحلويات. Move an item to another aisle and it remembers.
- Tick items off as you shop, clear them with Undo, see the list by recipe, and send it to WhatsApp as text.

### Changed
- English recipes with ounces, pounds and fluid ounces now scale and convert.

## [0.8.0] - 2026-09-20

### Added
- A meal plan: one week at a time, with فطور، غداء، عشاء and وجبة خفيفة every day. The week starts on the day your region uses (Saturday in Egypt, the Emirates and Kuwait; Sunday in Saudi Arabia), or on the day you choose in Settings.
- Plan a recipe in three taps from its page, or write a note like "مطعم" straight into a meal. Each planned meal keeps its own number of servings.
- Move or copy a meal to another day, clear a whole week, and undo any of it.
- A recipe's page tells you the next meal it's planned for.

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
