# Changelog

Notable changes per release, written for users. Versions follow [Semantic Versioning](https://semver.org) and match the app version and the `vX.Y.Z` git tags. Every merged PR is a release (see `docs/RELEASING.md`).

## [Unreleased]

## [0.21.0] - 2026-09-26

### Changed
- The plan shows a strip of the week's days with one day's meals under it: tap a day to see its meals. Days that have meals carry a dot, and "هذا الأسبوع" brings you back to the current week.
- In the "رمضان" view, the month shows as rows of days in the same style, with عيد الفطر and its date at the end.
- Choosing a recipe for a meal uses the same search field as the library, and shows each recipe with its photo.
- Groceries open with your progress: a card shows how many items you've bought out of the list, with a ring, and which recipes they're from.
- Grocery items are grouped in a card per aisle, each showing how many of its items are done.

## [0.20.0] - 2026-09-26

### Changed
- A recipe now opens under its photo, with round buttons over it to go back, share, edit and more. Its prep time, cook time and servings show as tiles, and المكونات and طريقة التحضير sit on two tabs, with the servings and units in the Ingredients tab and the notes after the steps. Tapping the source chip opens the original page.
- "ابدأ الطبخ", add to plan and add to groceries stay at the bottom of the recipe, always at hand.
- Cook mode shows how far you've got on a step rail, gives each timer a bigger start button, shows running timers in a band under the rail, and puts "السابق", the ingredients and "التالي" at the bottom edge, where your thumb reaches them.
- Recipes shared as pictures follow the new سُفرة colours, with the amounts in bold.

### Fixed
- The Undo bar now disappears after five seconds instead of staying on screen until you close it.
- The recipe editor no longer asks to discard your changes when nothing changed.
- The recipe page keeps its place when you change the units or the servings.

## [0.19.0] - 2026-09-26

### Added
- The library's new home: a "صباح الخير" / "مساء الخير" greeting and "ماذا نطبخ اليوم؟", a row of quick filter chips for the filters you use most, and a filter sheet for the rest.
- A "تابع الطبخ" card on the library home while a cook-mode session can still be resumed, showing the step you're on and how far you've got.
- Cookbooks get their own cover art on the library home, built from the recipes inside them.

### Changed
- Recipes on the library home show as big photo cards or compact rows — whichever you picked last — in the new سُفرة look, with a drawn cover standing in for recipes that have no photo.
- Import (from a link, a photo or pasted text) and the recipe editor now follow the new سُفرة look.

## [0.18.0] - 2026-09-26

### Added
- The new سُفرة look, in two accent colours (زعفران Saffron and حبر Ink) with زعفران as the default for new installs — light and dark, both now included in the app's contrast tests.
- A floating navigation bar with الإعدادات (Settings) in it, and a centre "+" that opens one place to add a recipe — from a link, a photo, pasted text, or writing it yourself.
- Drawn covers for recipes without a photo, in both light and dark.

### Changed
- Every screen takes the new colours, shapes and shared components (buttons, cards, the segmented control, the stepper) at once; per-screen layouts follow in later releases.

## [0.17.0] - 2026-09-25

### Added
- A two-question welcome the first time you open Wasfati — your language and your digits — then a four-page tour you can skip at any page. It ends on a sample recipe in the language you chose.
- Pro and Premium. Pro removes ads for good with one purchase; Premium removes them too and raises AI imports to 100 a month. Prices come from Google Play, cancelling is two taps from Settings, and everything already in Wasfati stays free. They go on sale once they're live in Google Play.
- A small banner at the bottom of the library, a recipe's page, the meal plan and groceries — never while you cook, write a recipe or import one, and not until you've finished the welcome.
- Once you've imported a recipe and cooked one, Wasfati may ask for a review — at most once every four months.

### Changed
- Arabic search finds a recipe however its hamza, taa marbuta or alef maqsura is written, with or without tashkeel.
- The privacy policy covers ads, their consent and purchases through Google Play.

## [0.16.1] - 2026-09-25

### Changed
- Settings gathers its options into cards that follow the look you picked, and the meal plan's days do the same, with today marked along its edge.
- Numbers that change while you cook — the timer, the step count, the servings — no longer shift sideways as they change.

### Fixed
- Greyed-out options in Settings are easier to read.

## [0.16.0] - 2026-09-24

### Added
- Import a recipe from a photo: take a picture of a cookbook page or a handwritten card, or pick up to four from your gallery, and it comes back as a recipe to check before saving. The first photo becomes the recipe's picture, and where the photo was taken never leaves your phone.
- Translate a recipe: one written in another language offers "ترجم إلى العربية". It saves a translated copy beside the original, and every amount, unit and timer stays exactly as it was — only the words change.
- "أبلغ عن خطأ" in the import preview opens your own mail app with just the link and your note, so you see exactly what is sent before you send it.

### Fixed
- A recipe site's "0", printed where it has no amount to give, is no longer read as zero.

### Changed
- The privacy policy now covers photo imports, translation and reports.

## [0.15.0] - 2026-09-24

### Added
- Import a recipe from TikTok, Instagram or any post your phone can't read on its own: share it into Wasfati, or paste the caption, and it comes back as a clean Arabic recipe you check before saving.
- Ten AI imports a month, free. The count and its reset date sit on the import screen, and an import is only counted once you save it — a preview you cancel costs nothing. Recipes from websites like فتافيت and كوكباد are still read on your phone, free and unlimited.
- When a link can't be read, Wasfati asks for the caption instead. It reads your clipboard only when you tap "لصق", and keeps the original link on the saved recipe.

### Changed
- The privacy policy now describes the import server: what leaves your phone, when, that Anthropic's Claude turns it into a recipe, and that nothing you send is kept.

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
