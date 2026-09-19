# Product rules

_19 September 2026._

This file defines how Wasfati behaves: the calculations, defaults, and edge cases behind each screen. Each section says what the competitor does (see `docs/research/competitor-analysis.md`), what we take from it, and our rule. We learn from their app; we don't copy its rules.

- Rule IDs (`DATA-1`) are stable: never renumber or reuse one. A dropped rule stays, struck through, with its date and reason. Tests, code comments, PRs, and roadmap items reference them.
- A rule is testable: a number, a default, an order, an edge case. "Entry is fast" isn't a rule; "a basic entry takes about four taps" is.
- "Not verified" marks competitor behavior we saw only partly.
- Every rule keeps the product principles in `CLAUDE.md`: Arabic first (right-to-left, Arabic units and numerals); no account in v1, and recipes leave the device only through a backup the user chooses to make; only what the user sends for an AI import (a post link, caption or photo) goes to our import server, which neither keeps it nor sells it; ads never appear in cook mode, the recipe editor or the import review; honest paying: store prices, two-tap cancel, a reminder before any trial charges, and nothing that already works moves behind a payment.

## Section shape

`/spec <area>` writes a section in this shape:

> ## N. Area
>
> **They do:** what the competitor does, in our words. Parts we couldn't check: not verified.
>
> **Learn:** the user need behind it, and where they fall short.
>
> - **AREA-1** Our rule.

The sections below are starter rules that held up in an earlier app. Keep, change, or delete each one, and record the choice under Decisions.

## 1. Data foundations

**Learn:** undo, trash, backup merge, sync, and translations all depend on these being right before any user data exists.

- **REC-1** Every record has `created_at` and `updated_at`.
- **REC-2** Every record ID is a UUID v4, so records from a backup or another device never collide. Built-in defaults use fixed IDs instead, so the same default matches across devices.
- **DEL-1** Deleting sets `deleted_at`; it doesn't remove the row. Deleted records count nowhere: totals, charts, search, or export.
- **DEL-2** Delete needs no confirmation. A snackbar offers Undo for about 5 seconds. Deleted items stay in the trash for 30 days, then get purged on app start.
- **DATA-1** User-facing names of built-in items (default categories, default accounts) are translatable labels referenced by ID, never stored text.
- ~~**MONEY-1**~~ _(Not applicable, 19 September 2026, Decision 7.)_ If the app handles money: amounts are integers in thousandths of a unit (`12.50` → `12500`), so sums never drift and every ISO currency fits. The record's type carries the sign.
- **DATE-1** A date the user picks is a local calendar date. It stays on that date if the device's time zone changes later.

## 2. Backup and export

**Learn:** a raw database file breaks across schema versions, and defaults that send data off the device cost trust.

- **BAK-1** A backup is a file with the app version and the schema version, saved or shared only when the user chooses to.
- **BAK-2** Before a restore replaces or merges anything, the app saves an automatic backup of the current data.
- **BAK-3** Merge matches records by ID (REC-2); the later `updated_at` wins, deletions included (DEL-1). The app then shows how many records were added, updated, and unchanged.
- **BAK-4** A backup from a newer schema is refused with a message to update the app. Older backups are migrated with the app's own schema steps.
- **BAK-5** Exported files use ISO dates and plain decimals with a `.`, whatever the language. Spreadsheet text starting with `=`, `+`, `-`, or `@` gets a leading apostrophe.

## 3. First run and trust

**Learn:** asking for an account, permissions, or cloud backup up front costs trust before the app has earned any.

- **RUN-1** An empty screen explains itself with one clear first action.
- **RUN-2** The release build declares no permission a shipped feature doesn't need, so the store's data-safety answers stay true. The release workflow checks it.
- **RUN-3** The first launch asks only what the device can't tell (for example the language and currency) on one page, preselected from the locale. Permissions are requested when the feature that needs them is first used, and everything else works if they're refused.
- **RUN-4** A walkthrough of up to four pages follows setup. Every page has Skip, it respects reduce motion, it can be replayed from Settings, and it shows once. An update on a device that already has data skips setup and the walkthrough.

## 4. Languages

**Learn:** a translated app only feels native when numbers, dates, plurals, search, and layout direction are right too. A cut-off label looks broken.

- **LANG-1** The app follows the device language and falls back to English. Settings offers "System default" and each language in its own name. A change applies without a restart.
- **LANG-2** Every user-facing text comes from the message files, including notifications, widgets, and generated files. Plurals and variable parts are ICU messages, never pieced-together strings. CI fails on a missing message or mismatched placeholders.
- **LANG-3** Dates, numbers, and amounts follow the chosen language's format. Files the app writes don't (BAK-5).
- **LANG-4** Search ignores case and accents in every language, including the Turkish dotted and dotless i.
- **LANG-5** Right-to-left languages mirror the layout: navigation, lists, swipe actions, arrows. Amounts, numbers, and expressions stay left to right inside them.
- **LANG-6** Translations are machine-made in the same PR that adds or changes the English message. Widget tests render the main screens in every language on a phone-size screen at 1.3× text size, and fail on overflow.

## 5. App lock

**Learn:** private data needs a lock, but a forgotten app PIN locks people out of their own records.

- **LOCK-1** App lock is off by default and uses the device's own biometrics or screen lock, so the app never stores a PIN. Turning it on or off asks for authentication first.
- **LOCK-2** With app lock on, the app asks at launch and after at least a minute in the background, and hides its content until unlocked. Notifications and widgets show no private data.
- **LOCK-3** If the device no longer has biometrics or a screen lock, app lock turns itself off instead of locking the data away.

## 6. Ads and paying
<!-- Delete this section if the app is free and carries nothing. -->

**Learn:** ads pay for a free app, but a banner that covers a row, moves a button under a finger, or interrupts an entry is what makes a free app feel cheap — and the money only comes if people keep the app. A subscription to *not* see something is resented; what is sold must already work.

- **ADS-1** Banners only, in slots the layout reserves, on a named handful of screens. No interstitials, no pop-ups, no rewarded video, and nothing on the entry forms, the walkthrough, setup, dialogs, widgets, or generated files.
- **ADS-2** A slot reserves its height before it asks for an ad, so an arriving ad never shifts what is under a finger, and an empty slot shows nothing at all: no frame, no placeholder.
- **ADS-3** A slot sits outside the scrolling content and above the system navigation bar. Put it in the screen's bottom bar rather than at the end of the body, and the rule holds by construction instead of by padding.
- **ADS-4** No ad is requested until setup and the walkthrough are finished (RUN-3, RUN-4) and consent has been answered, so the first minutes of the app belong to the app. None loads while the app is locked (LOCK-2).
- **ADS-5** Where the law asks for it (the EEA, the UK, Switzerland), the network's own consent form appears before the first request, and Settings keeps a row to change the answer later. Refusing means non-personalised ads, never a nag or a feature withheld. A consent lookup that fails leaves the user unasked and requests nothing.
- **ADS-6** What the ad SDK collects is declared in the store data-safety form, the privacy labels, and the privacy policy, in the same plain words as the rest. The release that adds ads rewrites all of them, and the first-run privacy page, together.
- **ADS-7** The ad SDK is handed nothing from the app: no user records, and no keywords derived from them. One place in the code decides whether a slot fills, so an ad-free build and a paid ad-free app are the same code path.
- **ADS-8** Only a release build asks with the real ad units; every other build uses the network's test units. Serving live ads from a development build is how an ad account gets suspended. IDs are not secrets — they ship in the binary — so they live in the repo, and a test fails if the copies in the code and the platform manifests drift apart.
- **PAY-1** Two products, each for what it costs us. **Pro** is a one-time purchase that removes ads. **Premium** is a subscription for what has a running server cost: AI imports beyond the free monthly quota, and nutrition. Premium also removes ads. Both follow the store account, "Restore purchases" sits beside the prices, and the app asks the store what is owned at each launch, so a refund, a lapsed subscription or a family-shared purchase lands without a reinstall. Exact quotas and tier contents: `/spec` after the hands-on research (Decision 1).
- **PAY-2** Prices come from the store, in the buyer's currency. Never hard-coded, and nothing to do with any currency setting in the app.
- **PAY-3** Nothing is sold before it exists. A tier that isn't finished is shown as "coming soon", with no price and no button.
- **PAY-4** Nothing that already works moves behind a payment. Paying removes ads and adds what is new.
- **PAY-5** Selling is quiet: one row in Settings, one small target on the ad slot, and one line where the free import quota runs out. No interstitial upsell, no countdown. A Premium trial is allowed only if the app reminds the user before it charges (at least 24 hours ahead) and cancelling is at most two taps from Settings (it opens the store's subscription page).
- **PAY-6** A purchase that fails or is left pending never charges twice and never leaves the app half-paid: the app finishes every purchase with the store whatever the outcome, and the slots stay as they were until it is confirmed. A store with no such product configured is a real state — show "nothing to sell yet" rather than a button that only fails.

## 7. Recipes

**They do:**
- A recipe holds a title, a photo, prep and cook times, servings, ingredients, instructions, notes, tags, cookbooks, a star rating, "Mark as cooked", and a link back to the source.
- Imported ingredients keep their text, with the leading number split off.
- A sauce's ingredients listed on one source line stay one line.
- The method arrives as the source's paragraphs: one step can be the whole recipe.
- A guest profile is created in the background even when you skip sign-up.

**Learn:**
- People save recipes to cook them later, often offline and in the kitchen, so a recipe must be complete on the device.
- The structure has to match how Arabic recipes are written: ingredient groups ("مقادير الصلصة"), many short steps, and amounts in several notations.
- Keeping the original text makes every automatic parse reversible.

- **REC-3** A recipe has a title (required, 1–120 characters) and an optional photo, source URL, source type, prep time, cook time, servings, notes and rating (1–5). Everything except the title can be empty, and an empty field is hidden on the recipe screen, never shown as "0" or "—". Source type is one of: written, website, social, photo.
- **REC-4** Ingredients live in ordered **groups**. A recipe starts with one unnamed group. A named group ("للصلصة") shows its name as a heading. Moving a line between groups keeps its ID (REC-2).
- **REC-5** An ingredient line stores:
  - its **original text**, exactly as written or imported
  - an optional amount: one number, or a range min–max
  - an optional unit ID (QTY-3)
  - a name
  - an optional note ("مفروم", "حسب الذوق")

  The screen shows the parsed form; editing a line re-parses it (QTY-1). A line that can't be parsed keeps its original text, shows it unchanged, and is marked "not scalable" (SCALE-4).
- **REC-6** Instructions are an ordered list of steps, each at most 2,000 characters. Steps can also be grouped (REC-4). Imports split long paragraphs into steps (IMP-6); in the editor, a line break in pasted text starts a new step.
- **REC-7** Servings is a whole number from 1 to 100. It defaults to empty. A recipe with no servings scales only by multiplier (SCALE-2).
- **REC-8** Photos:
  - Saved in the app's private storage, resized to at most 1600 px on the long side, JPEG quality 85.
  - An imported photo is downloaded once, at import time, so the recipe works offline.
  - Deleting a recipe deletes its photo when the trash is purged (DEL-2).
- **REC-9** "Cooked" is a count plus the last date cooked. Cook mode's last step offers "Mark as cooked" (COOK-6). The count feeds "Most cooked" sorting (ORG-5).
- **REC-10** There's no account and no profile. Nothing identifies the user or device except the anonymous install ID the import server needs (SRV-4).
- **REC-11** Backups include every recipe field, groups, steps, photos, cookbooks, tags and cooked counts (BAK-1). A restore that merges matches recipes by ID (BAK-3).

## 8. Quantities and units

**They do:**
- Western digits and slash fractions are read (1, 1/2).
- Eastern Arabic digits (١، ٢، ٣) are kept only as text.
- Arabic unit words stay part of the text.
- In the grocery picker, "1 كيلو جرام لحم ضأن" became "جرام لحم ضأن" × 1, so the kilo was lost.
- The abbreviation "١ ك" stays as text.

**Learn:**
- Every other feature (scaling, conversion, groceries, cook mode) depends on reading an amount and a unit correctly.
- Arabic recipes mix both digit systems, words for fractions (نصف، ربع), ranges, and dialect or abbreviated units. Getting this right is Wasfati's main edge (competitor weak spots 1 and 2).

- **QTY-1** The parser reads, at the start of a line or after the ingredient name:
  - **Digits:** Western digits, Eastern Arabic digits (٠–٩), Persian digits (۰–۹), and the Arabic decimal separator (٫).
  - **Numbers with fractions:** mixed numbers (1 1/2, ١ ١/٢, 1½) and Unicode fractions (½ ¼ ¾ ⅓ ⅔ ⅛).
  - **Number words:** واحد/واحدة، اثنين/اثنتين، ثلاث… عشرة، نصف، ربع، ثلث، ربع إلا.
  - **Ranges:** 2-3, 2–3, ٢-٣, ٢ إلى ٣, 2 أو 3.
  - It never guesses: text it can't read stays in the name, and the line has no amount.
- **QTY-2** A line with no amount, or with "حسب الرغبة/حسب الذوق/رشة" and no number, is a to-taste line. It's never scaled, and groceries list it without an amount (GRO rules, round 2).
- **QTY-3** Units come from a fixed table of unit IDs, each with Arabic and English names, singular, dual and plural forms, and known abbreviations:

  | Kind | Units |
  |---|---|
  | Mass | غرام/جرام/غ/g, كيلو/كيلوغرام/كغ/ك/kg, oz, lb |
  | Volume | مل/ml, لتر/ل/l, كوب/كاس/cup, ملعقة كبيرة/م.ك/tbsp, ملعقة صغيرة/م.ص/tsp, fl oz |
  | Count | حبة، فص، عود، شريحة، ورقة، حزمة/ربطة، علبة، كيس، قطعة، رأس |
  | Informal | رشة، قبضة، حفنة |

  - "كيلو جرام" is one unit (kg), never "كيلو" + "جرام".
  - A unit word the table doesn't know stays in the name, and the line still scales by its number.
- **QTY-4** Amounts are stored as exact numbers: a rational (numerator/denominator), or a decimal with up to 3 places. Parsing then showing a line without changes gives back the same value (round-trip test).
- **QTY-5** Display:
  - Amounts use the digit style from Settings: Western 123 by default, Arabic ١٢٣ optional (Decision 5), in both languages.
  - Fractions show as ½ ⅓ ¼ ⅔ ¾ ⅛ or mixed numbers (1½), never 0.5, for cups, spoons and count units.
  - Mass and volume in g/ml show whole numbers, and kg/l show up to 2 decimals.
  - An amount inside Arabic text is wrapped in a left-to-right isolate (LANG-5), so "1½ كوب" reads correctly.
- **QTY-6** Unit names agree with the number in Arabic: 1 كوب، 2 كوبان/كوبين، 3–10 أكواب، 11+ كوبًا. English uses singular and plural. They come from ICU plural messages (LANG-2), not string joining.
- **QTY-7** The parser is pure Dart with a table-driven test. The table's first rows are every ingredient line from both ReciMe tests (`docs/research/competitor-analysis.md`). A new parsing bug found anywhere becomes a new row before it's fixed.

## 9. Scaling and conversion

**They do:**
- Servings −/+ is free. Western-digit amounts scale, but as decimals: 0.5 حبة كراث، 0.5 عود قرفة، 2.5 ملعقة.
- **Lines with Eastern Arabic digits don't scale at all.** Nothing tells the user.
- Unit conversion is Plus-only.

**Learn:**
- Scaling is for cooking for more people, or fewer: in the Gulf that often means doubling for a gathering.
- A wrong amount ruins a dish, so a silent failure is worse than no feature.
- Conversion is a basic kitchen need, not a luxury.

- **SCALE-1** Scaling and conversion are free forever (PAY-4, principle 5).
- **SCALE-2** A recipe scales by servings (1–100) when REC-7 is set, and always by the multipliers ×½, ×1, ×2, ×3. The factor shows at the top of the ingredients ("×2 · 12 حصة"), and "Reset" returns to ×1.
- **SCALE-3** Scaled amounts:
  - Count units round to the nearest ½ (حبة، فص، عود، بيضة); below ½ they show as ½.
  - Cups and spoons round to the nearest ⅛.
  - g/ml round to whole numbers (to 5 above 100).
  - Ranges scale both ends.
  - Scaling never changes what's stored (REC-5); it's a view.
- **SCALE-4** A line the parser couldn't read (REC-5) or a to-taste line (QTY-2) isn't scaled. When the factor isn't ×1, such lines show a small "not scaled" mark, and the header says how many ("2 مكونات لم يتم تعديلها"). Scaling **never silently skips a line** — the direct answer to competitor weak spot 1.
- **SCALE-5** Conversion has two views: Metric (g, ml) and Kitchen (cups, spoons).
  - Volume converts exactly: 1 cup = 240 ml, 1 tbsp = 15 ml, 1 tsp = 5 ml.
  - Converting volume to mass happens only when the ingredient is in the density table (flour, sugar, rice, butter, oil, milk, water, honey and about 30 more, Arabic and English names); otherwise the line stays in its own unit.
  - The chosen view is remembered per recipe.
- **SCALE-6** The scale factor and conversion view carry into cook mode (COOK-2) and into "add to groceries" (GRO rules, round 2).

## 10. Cook mode

**They do:** step-by-step cook mode is Plus-only. It wasn't opened, so its behavior is not verified.

**Learn:**
- The cook's hands are messy, the phone is on the counter, and steps are read from a distance.
- Cook mode is where an Arabic recipe app earns daily use, so it's free and it has no ads.

- **COOK-1** Cook mode is free, and **no ad appears in it** (ADS-1, principle 4). It opens from a "ابدأ الطبخ / Start cooking" button on every recipe with at least one step.
- **COOK-2** It shows one step per page, in text at least 1.5× the body size, with the step number ("الخطوة 3 من 8"). Swipe or tap the edges to move; in right-to-left, the next step is to the left. A pull-up sheet lists the ingredients, scaled and converted as set (SCALE-6), with a checkbox per line.
- **COOK-3** The screen stays on while cook mode is open (a wake lock held only then, released when cook mode closes or the app goes to the background).
- **COOK-4** Timers:
  - Durations in a step become tap-to-start timers: "15 دقيقة", "ساعة ونصف", "10-15 min" (the upper end of a range), and Eastern digits too.
  - Several timers can run at once, each labelled with its step.
  - A running timer shows in cook mode's header and survives leaving cook mode.
- **COOK-5** When a timer ends:
  - It rings and vibrates in the app.
  - In the background, it posts a notification. Notification permission is asked the first time a timer starts, not before (RUN-3).
  - If notifications are refused, the timer still rings while the app is open, and cook mode says once that background alerts are off.
  - This adds `POST_NOTIFICATIONS` to the release build's allowed list (RUN-2). It uses an inexact alarm, so no exact-alarm permission is needed.
- **COOK-6** The last page offers "Mark as cooked" (REC-9) and "Done". Leaving cook mode anywhere keeps the page, so reopening within 12 hours resumes at the same step.

## 11. Organizing and finding

**They do:**
- "All recipes" and "Cookbooks" tabs, search by title, sort A–Z or recently added, a grid or list toggle, and tags.
- Searching by ingredient is not verified.
- Reviews asked for sorting, which has since been added.

**Learn:**
- A collection grows fast when saving is one share.
- Finding "the chicken one I saved from TikTok last week" needs recency, ingredients and source.
- Arabic search has to ignore spelling variants.

- **ORG-1** Cookbooks are user-named (1–60 characters). A recipe can be in any number of cookbooks, or none. "All recipes" is built in and isn't a cookbook. Deleting a cookbook never deletes its recipes.
- **ORG-2** Tags are free text (1–30 characters). A recipe has up to 20. Tags are suggested from existing ones as you type.
- **ORG-3** Search matches the title, ingredient names, tags and notes. **Ingredient matches rank below title matches**, and results show the matching ingredient ("يحتوي: كزبرة").
- **ORG-4** Arabic search normalizes both the query and the text (LANG-4):
  - Diacritics and tatweel are removed.
  - أ/إ/آ → ا, ة → ه, ى → ي, ؤ → و, ئ → ي.
  - "طماطم" and "بندورة" are **not** treated as the same (no dictionary in v1).
- **ORG-5** Sort: Recently added (default), A–Z (Arabic alphabet order for Arabic titles), Recently cooked, Most cooked. The choice is remembered.
- **ORG-6** Filter chips: cookbook, tag, source type (REC-3), total time (under 30 min, 30–60 min, over 1 h), and "Has photo". Filters combine with search.
- **ORG-7** Deleted recipes go to the trash (DEL-1, DEL-2) and appear nowhere else: not in search, cookbooks, counts or backup exports.

## 12. Import

**They do:**
- Share from social apps, or use a built-in browser with Google search.
- Web, social, photo and text imports all cost one of 5 free imports, and only count when saved.
- A preview allows editing, picking a cookbook, saving, and "Report mistake"; a 5-star "How did we do?" sheet follows.
- An Arabic website recipe and an Arabic YouTube Short both imported in about 25 s. Sub-recipes and steps weren't split.
- Photo and text import are not verified.

**Learn:**
- The share sheet is the whole product: one share and a clean recipe.
- Websites that already publish structured recipe data don't need AI, so charging for them is unnecessary.
- The preview is where trust is built: nothing is saved without the user seeing it.

- **IMP-1** Sources:
  - a link or text shared from any app (Android share sheet)
  - a link pasted in "Import"
  - a photo from the camera or gallery (up to 3 pages per recipe)
  - text pasted in "Import"
- **IMP-2** A link is tried **on the device first**. If the page has schema.org `Recipe` data (JSON-LD or microdata), it's parsed locally (QTY-1) and is **free and unlimited**: it never uses the AI quota and never contacts our server. Only the page itself is fetched, directly from its site.
- **IMP-3** Otherwise the import goes to our server (SRV-1): social links, pages without recipe data, pasted text, and photos. The user sees **before sending**, in one line, that it uses one of their AI imports and the count left ("سيستخدم استيرادًا واحدًا · بقي 7 من 10"). Premium hides the count.
- **IMP-4** Progress shows a single step list (reading, understanding, done). It can be cancelled. Past 45 seconds, it offers "Keep waiting" or "Cancel". A cancelled or failed import doesn't use the quota.
- **IMP-5** Every import opens a **preview** before anything is saved:
  - title, photo, servings, times, groups, ingredients, steps, all editable in place
  - a cookbook picker
  - Save
  - "Report a mistake"

  Closing the preview discards it after one confirmation. The preview has no ads (principle 4).
- **IMP-6** The server's result is normalized on the device:
  - Every ingredient line goes through QTY-1, and the server's own amounts are only a hint.
  - Lines like "مقادير الصلصة: …" or "للتتبيلة" become a named group (REC-4) with one line per item.
  - A step over 400 characters is split at sentence ends (. ، ؛ then، ثم).
  - The original caption or page text is kept in the recipe's notes, collapsed, so nothing is lost.
- **IMP-7** An AI import counts against the quota **only when saved** (PAY-1). The quota is 10 a calendar month, resetting on the 1st at 00:00 local time (Decision 4). The count is kept on the device and checked by the server (SRV-4). When it runs out, IMP-3's line becomes the one Premium upsell (PAY-5), and website imports (IMP-2) still work.
- **IMP-8** "Report a mistake" sends only the source link (for a photo import: nothing) and the user's optional note, only when the user taps Send. It never sends the recipe, the photo or anything else. There's no rating sheet after import.
- **IMP-9** Duplicates: importing a source URL that's already saved asks "Open the saved one / Import again". It matches the normalized URL: no tracking parameters, and it follows `youtu.be` and `vm.tiktok.com` short links.
- **IMP-10** A photo import sends the images resized to at most 1600 px (JPEG 80), and the server discards them after the response (SRV-3). The recipe keeps the first image as its photo (REC-8), unless the user removes it in the preview.

## 13. Import server

**They do:** not visible. The server-side import worked for Arabic in about 25 s.

**Learn:**
- The server is a cost and a privacy surface.
- It must be cheap per import, keep nothing, and never be abusable as a free AI proxy.

- **SRV-1** The server runs on Cloudflare Workers (Decision 6). It has one endpoint that takes a link, text, or up to 3 images, and returns a recipe in the REC structure (JSON validated against a schema). The model is Claude Haiku 4.5 to start, with structured output. The model and prompt version come back with each result, for debugging.
- **SRV-2** For a link, the server fetches the public page or post (title, caption or description, and any recipe data) and sends only that text to the model. It never logs into anything, and never fetches a private post.
- **SRV-3** The server keeps no content: no request bodies, captions, images or results in logs. Only aggregate counters are kept (imports, errors, tokens, cost per day). Images are held only in memory for the request.
- **SRV-4** Abuse and cost:
  - Each request carries an anonymous random install ID (created on first launch, stored on the device, included in backups) and a Play Integrity token. Requests without a valid token are refused.
  - Limits: 10 AI imports a month for free installs, 300 a month for Premium (fair use), and at most 20 requests per hour per install.
  - Premium is checked with Google Play's purchase record, not trusted from the app.
- **SRV-5** Cache: a successful result for a **public** link is cached by the normalized URL (IMP-9) for 30 days. A cache hit costs us nothing, but still counts for the user, because the quota is about imports, not our cost. Photo and text imports are never cached.
- **SRV-6** Spending cap: a monthly budget set in the Worker's config. At 80% it sends an alert. At 100%, AI imports pause for everyone with the message "Import is busy, try again later", and website imports (IMP-2) keep working.
- **SRV-7** Errors return a short code (`unreachable`, `not_a_recipe`, `private_post`, `limit_reached`, `busy`), which the app shows as a translated message (LANG-2). None of them uses the quota (IMP-4).
- **SRV-8** A regression suite of real Arabic inputs (both ReciMe test sources, plus the S3 spike's 10 captions and 5 photos) runs in the server repo's CI. A prompt or model change must keep every expected ingredient line and amount.
- **SRV-9** The privacy policy names the server, what it receives (IMP-3, IMP-10) and that it keeps nothing, in the release that ships it (ADS-6 style, same PR).

## Decisions
<!-- Numbered and dated answers to open questions, citing the rules they settle. -->
1. (19 September 2026) Money model: ads, plus a one-time Pro that removes them, plus a Premium subscription for AI imports beyond the free quota and nutrition (PAY-1, PAY-5). This replaces the kit's one-time-only rule because AI imports cost us per use.
2. (19 September 2026) Wasfati has a thin import server: a serverless proxy that holds the AI key and turns a post link, caption or photo into a recipe (Claude Haiku 4.5 to start). It keeps nothing it's sent, caches results per public post URL, rate-limits per device, checks Play Integrity, and has a monthly spending cap. This reverses the suite's "no backend" default for this app only.
3. (19 September 2026) v1 targets Android on Google Play; iOS follows. No desktop.
4. (19 September 2026) Free AI imports: 10 per calendar month, resetting on the 1st; website imports with recipe data are free and unlimited (IMP-2, IMP-7, SRV-4).
5. (19 September 2026) Digits: Western 123 by default in both languages, Arabic ١٢٣ as a Settings option; the parser always reads both (QTY-1, QTY-5).
6. (19 September 2026) Cook-mode timers alert in the background with a notification; permission is asked at the first timer (COOK-4, COOK-5). The import server runs on Cloudflare Workers, with its code in a private repo, Oasis-Forge/wasfati-import (SRV-1).
7. (19 September 2026) Starter rule MONEY-1 doesn't apply: Wasfati handles no money. Prices come only from the store (PAY-2).

## Roadmap impact
<!-- Rules that change the data model or the build order, and where they land in docs/ROADMAP.md. Schema changes go in Phase 1. -->
- **Phase 1 schema:**
  - Recipes (REC-3–REC-9): groups (REC-4), ingredient lines with the original text, amount/range and unit ID (REC-5, QTY-4), steps (REC-6), photos (REC-8), and the cooked count (REC-9).
  - Cookbooks and tags (ORG-1, ORG-2).
  - The install ID (SRV-4), included in backups (REC-11).
- **Phase 1 code:**
  - The quantity parser and formatter with the unit table (QTY-1–QTY-7), built before any screen reads amounts.
  - Arabic search normalization (ORG-4).
- **Phase 2a order:** recipes and cookbooks → find → scaling and conversion (SCALE-1–SCALE-6) → cook mode (COOK-1–COOK-6) → website import on the device (IMP-2, IMP-5, IMP-6, IMP-9).
- **Phase 2b order:** the server (SRV-1–SRV-9) before share and photo import (IMP-1, IMP-3, IMP-4, IMP-7, IMP-8, IMP-10).
- **Permissions (RUN-2):**
  - `INTERNET` arrives with website import (IMP-2).
  - `POST_NOTIFICATIONS` arrives with cook-mode timers (COOK-5).
  - No `CAMERA`: photos come through the system camera and picker (IMP-1).
  - No exact alarms.
  - Keeping the screen on (COOK-3) uses the window flag, not a wake-lock permission.
- **Privacy policy:** website import (a page fetched directly from its site), the import server (SRV-9) and notifications, each updated in the PR that ships it.
