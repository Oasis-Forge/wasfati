# Product rules

_19 September 2026; round 2 on 20 September 2026._

This file defines how Wasfati behaves: the calculations, defaults, and edge cases behind each screen. Each section says what the competitor does (see `docs/research/competitor-analysis.md`), what we take from it, and our rule. We learn from their app; we don't copy its rules.

- Rule IDs (`DATA-1`) are stable: never renumber or reuse one. A dropped rule stays, struck through, with its date and reason. Tests, code comments, PRs, and roadmap items reference them.
- A rule is testable: a number, a default, an order, an edge case. "Entry is fast" isn't a rule; "a basic entry takes about four taps" is.
- "Not verified" marks competitor behavior we saw only partly.
- Every rule keeps the product principles in `CLAUDE.md`: Arabic first (right-to-left, Arabic units and numerals); no account in v1, and recipes leave the device only when the user sends them: a backup, a share, or a translation; only what the user sends for an AI import (a post link, caption, photo, or a recipe to translate) goes to our import server, which neither keeps it nor sells it; ads never appear in cook mode, the recipe editor or the import review; honest paying: store prices, two-tap cancel, a reminder before any trial charges, and nothing that already works moves behind a payment.

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
  - A recipe's groups, ingredient lines and steps move as one unit, not row by row: whichever side's `recipes` row is strictly newer takes its whole set of them, and the other side's rows for that recipe are never merged in. A tie keeps this phone's.
- **BAK-4** A backup from a newer schema is refused with a message to update the app. Older backups are migrated with the app's own schema steps.
- **BAK-5** Exported files use ISO dates and plain decimals with a `.`, whatever the language. Spreadsheet text starting with `=`, `+`, `-`, or `@` gets a leading apostrophe.
- **BAK-6** The backup file (round 2, 20 September 2026):
  - One zip file, `wasfati-backup-YYYY-MM-DD.zip`, holding `backup.json` and a `photos` folder.
  - Settings → Backup → "Save a backup" opens the system's save dialog, so the user picks Google Drive, Files or any folder; "Share" sends the same file through the share sheet. No storage permission is needed (RUN-2).
  - It holds everything the app keeps: recipes with their groups, lines, steps, photos, cookbooks, tags and cooked counts (REC-11), translation links (IMP-14), plan entries (PLAN-2), the grocery list and aisle choices (GRO-1, GRO-4), settings, the install ID and this month's AI-import count (SRV-4, IMP-7).
  - Records in the trash come along only as deletions, so a merge carries them (BAK-3); they never show as recipes (ORG-7).
  - Purchases aren't in it: they follow the store account (PAY-1).
- **BAK-7** Restore: Settings → Backup → "Restore" opens the system's file picker. The app first shows what the file holds ("١٢٠ وصفة، ٤ كتب طبخ، ٣ أسابيع في الخطة"), then offers **Merge** (the default, BAK-3) or **Replace** (confirmed twice).
  - Merge keeps this phone's settings and install ID; Replace takes the file's.
  - The automatic backup made first (BAK-2) is kept in the app's storage, the latest 3, and can be restored from the same screen.
  - A file that isn't a Wasfati backup, or is damaged, changes nothing and says so.
- **BAK-8** Reminder: with at least 10 recipes and no backup in the last 30 days (or ever), the library shows a one-line card ("آخر نسخة احتياطية قبل ٤٥ يومًا") with "Back up" and "Later". "Later" hides it for 30 days, and a switch in Settings turns it off for good. It never blocks anything and never shows in cook mode, the editor or the import preview.
- **BAK-9** Android's own device backup (to the user's Google account, when it's turned on in the phone's settings) includes the recipe database and settings, but not photos or caches: photos would pass Android's 25 MB limit, which stops the whole backup. A new phone restored that way gets its recipes back without photos; the backup file (BAK-6) carries them. A phone-to-phone transfer during setup has no such limit and includes photos. A recipe whose photo file is missing shows no photo, never a broken image.
- **BAK-10** Export: all recipes, or one cookbook, as a single text file in the shared-text format (SHARE-2), through the save dialog. It's for reading and printing, not for restoring, so amounts read as on screen (QTY-5); BAK-5 applies to the backup's JSON. Export is free, like backup (PAY-7).

## 3. First run and trust

**Learn:** asking for an account, permissions, or cloud backup up front costs trust before the app has earned any.

- **RUN-1** An empty screen explains itself with one clear first action.
- **RUN-2** The release build declares no permission a shipped feature doesn't need, so the store's data-safety answers stay true. The release workflow checks it.
- **RUN-3** The first launch asks only what the device can't tell (for example the language and currency) on one page, preselected from the locale. Permissions are requested when the feature that needs them is first used, and everything else works if they're refused.
- **RUN-4** A walkthrough of up to four pages follows setup. Every page has Skip, it respects reduce motion, it can be replayed from Settings, and it shows once. An update on a device that already has data skips setup and the walkthrough.
- **RUN-5** The store's review prompt (added 20 September 2026) is asked for only after the user has saved an import and marked a recipe as cooked (REC-9), right after cook mode closes with "Done", and at most once every 120 days. Never during setup, the walkthrough or a purchase. The app never asks "Do you like Wasfati?" first: the store's prompt isn't filtered by mood.
- **RUN-6** On a phone with no recipes at all, the first launch adds one built-in sample recipe, "شوربة عدس" ("Red lentil soup" when the app starts in English), so the first screen shows what a saved recipe looks like: amounts that scale (Eastern and Western digits and a word amount), a timer inside a step, and a note that says it's a sample. It has fixed IDs (REC-2) and behaves like any recipe. It's offered once: deleting it never brings it back, and a phone that already has recipes, in the library or the trash, never gets it. A merge that brings recipes in from a backup (BAK-3) moves a sample nobody has edited to the trash, so moving to a new phone doesn't leave it among the restored recipes. (Added 22 September 2026.)

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
- **ADS-9** Where banners go (Decision 12): one anchored adaptive banner in the bottom bar (ADS-3) of four screens: the library (All recipes and Cookbooks), the recipe page, the meal plan (PLAN-1) and groceries (GRO-5).
  - Never in cook mode (COOK-1), the editor, the import screens and preview (IMP-5), Settings, the purchase screen (PAY-10), sheets, dialogs or menus, the first run (ADS-4), or anything the app makes: shared text and images (SHARE-4), the grocery list it sends (GRO-6), backups and exports (BAK-6, BAK-10).
  - One ad unit serves every slot. It was created on 20 September 2026; its ID and the app ID are in `docs/RELEASING.md` (ADS-8).
  - A slot keeps at least 8 dp from any button, including the recipe page's "ابدأ الطبخ" and the navigation bar, so a tap meant for them can't land on the ad (AdMob's accidental-click policy).
- **PAY-1** Two products, each for what it costs us. **Pro** is a one-time purchase that removes ads. **Premium** is a subscription for what has a running server cost: AI imports beyond the free monthly quota, and later nutrition (PAY-3). Premium also removes ads. Both follow the store account, "Restore purchases" sits beside the prices, and the app asks the store what is owned at each launch, so a refund, a lapsed subscription or a family-shared purchase lands without a reinstall. Tiers, products and prices: PAY-7–PAY-11 (Decisions 1, 10, 11).
- **PAY-2** Prices come from the store, in the buyer's currency. Never hard-coded, and nothing to do with any currency setting in the app.
- **PAY-3** Nothing is sold before it exists. A tier that isn't finished is shown as "coming soon", with no price and no button.
- **PAY-4** Nothing that already works moves behind a payment. Paying removes ads and adds what is new.
- **PAY-5** Selling is quiet: one row in Settings, one small target on the ad slot, and one line where the free import quota runs out. No interstitial upsell, no countdown. A Premium trial is allowed only if the app reminds the user before it charges (at least 24 hours ahead) and cancelling is at most two taps from Settings (it opens the store's subscription page).
- **PAY-6** A purchase that fails or is left pending never charges twice and never leaves the app half-paid: the app finishes every purchase with the store whatever the outcome, and the slots stay as they were until it is confirmed. A store with no such product configured is a real state — show "nothing to sell yet" rather than a button that only fails.
- **PAY-7** Tiers at launch (round 2, 20 September 2026):

  | | Free | Pro (one-time) | Premium (subscription) |
  |---|---|---|---|
  | Banners (ADS-9) | Yes | None | None |
  | AI imports a month: social links, pasted text, photos and translations (IMP-7, IMP-16) | 10 | 10 | 100, fair use (SRV-4) |
  | Everything else: website import, cook mode, scaling and conversion, the plan, Ramadan mode, groceries, sharing, backup and export | Free | Free | Free |

  - Nutrition isn't listed or sold until it ships (PAY-3); it's an after-v1 item.
  - Pro and Premium can be owned together; the purchase screen marks what's owned.
- **PAY-8** Store products (Decision 10). Product IDs are permanent after the first upload, like the app ID:
  - `pro`: a one-time product, AED 14.99.
  - `premium`: a subscription with two auto-renewing base plans, `monthly` at AED 9.99 and `yearly` at AED 79.99.
  - These are the Play Console base prices. Other countries get Play's local prices, and the app only ever shows the store's price (PAY-2).
- **PAY-9** No free trial in v1 (Decision 11): the 10 free AI imports a month are how anyone tries Premium. If a trial is ever added, PAY-5's reminder and two-tap cancel come with it.
- **PAY-10** The purchase screen opens only from PAY-5's three places. It shows:
  - Pro and Premium side by side, with store prices (Premium monthly and yearly), what each includes (PAY-7), and "Owned" on what's bought.
  - "Restore purchases" next to the prices (PAY-1).
  - A close button at the top from the first frame, never delayed or hidden.
  - For Premium: that it renews until cancelled, and where to cancel (PAY-11).
  - No crossed-out prices, countdowns, "most popular" badges or preselected plan, and no ads (ADS-9).
- **PAY-11** Settings shows a "Subscription" row with the plan and, when Google Play's record gives it (SRV-4), the renewal date. "Manage or cancel" opens Google Play's page for this subscription: two taps from Settings (PAY-5).
  - When the store reports that Premium has ended, banners come back (unless Pro is owned) and the quota drops to 10 at once.
  - The month's count carries over both ways: 12 imports used stays 12 used, of 100 or of 10.
  - Everything imported stays (PAY-4).

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

  The screen shows the parsed form; editing a line re-parses it (QTY-1), and a line whose text is unchanged keeps what was read from it, so a translated copy's amounts are never read again from its new words (IMP-15, 24 September 2026). A line that can't be parsed keeps its original text, shows it unchanged, and is marked "not scalable" (SCALE-4).
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
  - **A bare 0** as the whole amount ("0 ملح", "٠ فلفل") is how some sites print "no amount given", so the line has no amount (QTY-2), not the number zero; a unit after it is still read. A zero that's only part of the amount (0.5, 10, ٠٫٥, 0-1) reads as a number (24 September 2026).
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
  - Lines in other languages always use 123, so an English line never reads "٤ cups" (19 September 2026). The app's own text follows the setting.
  - Fractions show as ½ ⅓ ¼ ⅔ ¾ ⅛ or mixed numbers (1½), never 0.5, for cups, spoons and count units.
  - Mass and volume in g/ml show whole numbers, and kg/l show up to 2 decimals.
  - An amount inside Arabic text is wrapped in a left-to-right isolate (LANG-5), so "1½ كوب" reads correctly.
- **QTY-6** Unit names agree with the number in Arabic: 1 كوب، 2 كوبان/كوبين، 3–10 أكواب، 11+ كوبًا. English uses singular and plural. They come from ICU plural messages (LANG-2), not string joining.
- **QTY-7** The parser is pure Dart with a table-driven test. The table's first rows are every ingredient line from both ReciMe tests (`docs/research/competitor-analysis.md`). A new parsing bug found anywhere becomes a new row before it's fixed.
- **QTY-8** A line with no number (added after the S1 spike, 19 September 2026):
  - A **singular** unit word means one ("حبة بصل", "كوب جزر", "ملعقة كبيرة ملح").
  - A **dual** form means two (كوبين، حزمتين، فصّان، ملعقتين كبيرتين).
  - A **plural** unit word with no number is just part of the name ("قطع الدجاج", "حبات هال").
  - An informal unit with no number ("رشة ملح") is to taste (QTY-2).
  - A bracketed equivalent ("3 أكواب (450 غرام)") is kept as the line's note, not as a second amount.

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
  - Added 19 September 2026, while building it:
    - **Liquids** (water, milk, broth, oil, cream) show in ml/l in the metric view, never grams.
    - Metric amounts of 1,000 or more step up to kg/l.
    - In the cups view, less than ¼ cup shows in spoons.
    - A spoon of unknown size ("ملعقة") is never converted.
  - The recipe page offers three views: as written (the default), g/ml, and cups. Scaling happens first, then conversion, then one rounding step (SCALE-3), so rounding errors never stack up.
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
  - This adds `POST_NOTIFICATIONS` to the release build's allowed list (RUN-2). So does `VIBRATE`, which the notifications plugin declares; it's granted at install with no dialog. It uses an inexact alarm, so no exact-alarm permission is needed.
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
- **ORG-7** Deleted recipes go to the trash (DEL-1, DEL-2) and appear nowhere else: not in search, cookbooks, counts, the plan (PLAN-6) or exports (BAK-10). A backup carries them only as deletions, for merging (BAK-6).

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
  - a photo from the camera or gallery (up to 4 pages per recipe, the server's limit since 24 September 2026)
  - text pasted in "Import"
- **IMP-2** A link is tried **on the device first**. If the page has schema.org `Recipe` data (JSON-LD or microdata), it's parsed locally (QTY-1) and is **free and unlimited**: it never uses the AI quota and never contacts our server. Only the page itself is fetched, directly from its site.
- **IMP-11** Reading website recipe data (S2, `docs/research/technical-constraints.md`):
  - The page is read with an HTML parser, not pattern matching (some sites leave the `type` attribute unquoted).
  - The recipe can be inside `@graph`, in a list, or in microdata.
  - Instructions can be one string (split on line breaks), a list of strings, `HowToStep` items, or `HowToSection` groups (REC-6).
  - Microdata with no ingredients counts as "no recipe data", so the page goes to AI import (IMP-3).
- **IMP-12** When a shared link's caption can't be read (Instagram always, per Decision 8; any `private_post` from SRV-7), the app shows one screen:
  - The post's link, and a one-line reason ("إنستغرام لا يسمح بقراءة هذا المنشور").
  - **Paste the caption:** a text box with a Paste button. The clipboard is read only when the user taps Paste, never on its own. It goes through text import (IMP-3).
  - **Share a screenshot:** opens the photo picker. It goes through photo import (IMP-10).
  - Cancel.
  - The source URL is kept on the saved recipe, so duplicates are still caught (IMP-9) and "Open original" works.
  - Only the paste or screenshot import uses the quota, and only when saved (IMP-7). Reaching this screen costs nothing.
- **IMP-3** Otherwise the import goes to our server (SRV-1): social links, pages without recipe data, pasted text, and photos. The user sees **before sending**, in one line, that it uses one of their AI imports and the count left ("سيستخدم استيرادًا واحدًا · بقي 7 من 10"). Premium hides the count.
- **IMP-4** Progress shows a single step list (reading, understanding, done). It can be cancelled. Past 45 seconds, it offers "Keep waiting" or "Cancel". A cancelled or failed import doesn't use the quota.
- **IMP-5** Every import opens a **preview** before anything is saved:
  - title, photo, servings, times, groups, ingredients, steps, all editable in place
  - a cookbook picker
  - Save
  - "Report a mistake"

  Closing the preview discards it after one confirmation. The preview has no ads (principle 4).
- **IMP-6** The server's result is normalized on the device:
  - The server sends verbatim text only, never a parsed amount (SRV-1); every ingredient line goes through QTY-1 on the device.
  - Lines like "مقادير الصلصة: …" or "للتتبيلة" become a named group (REC-4) with one line per item.
  - A step over 400 characters is split at sentence ends (. ، ؛ then، ثم).
  - The original caption or page text is kept in the recipe's notes, collapsed, so nothing is lost.
- **IMP-7** An AI import counts against the quota **only when saved** (PAY-1). The quota is 10 a calendar month, resetting on the 1st at 00:00 local time (Decision 4). The count is kept on the device and checked by the server (SRV-4). When it runs out, IMP-3's line becomes the one Premium upsell (PAY-5), and website imports (IMP-2) still work.
- **IMP-8** "Report a mistake" sends only the source link (for a photo import: nothing) and the user's optional note, only when the user taps Send. It never sends the recipe, the photo or anything else. There's no rating sheet after import.
  - Send opens the user's own mail app with a draft to oasisforge.support@gmail.com, the only address the app shows: a fixed subject, and a body holding the link, a blank line and the note. A photo or pasted-text import on its own has no link, so its body is just the note; a screenshot or a pasted caption from IMP-12's fallback keeps the post's link as its source, so it carries that link. The user sees the draft and sends it themselves; nothing goes through our server (Decision 19).
  - With no mail app on the phone, the app shows the address instead.
- **IMP-9** Duplicates: importing a source URL that's already saved asks "Open the saved one / Import again". It matches the normalized URL: no tracking parameters, and it follows `youtu.be` and `vm.tiktok.com` short links.
- **IMP-10** A photo import sends the images resized to at most 1600 px (JPEG 80), and the server discards them after the response (SRV-3). The recipe keeps the first image as its photo (REC-8), unless the user removes it in the preview.

- **IMP-13** The offline, no-quota fallback heading-based draft (added 19 September 2026; superseded as the primary path by AI import, IMP-3, since Phase 2b — now used for "أضفها بنفسك" and whenever AI import can't be reached, no quota or no network):
  - The first line is the title.
  - Lines after a heading like "المقادير" or "Ingredients" are ingredients; lines after "طريقة التحضير" or "Method" are steps.
  - With no headings, everything is an ingredient.
  - Hashtag lines are dropped.
  - The draft opens as the preview (IMP-5), and nothing is saved until Save.
  - A shared text that contains a link imports the link instead (IMP-2); a shared text with no link goes to AI import (IMP-3) instead of this heuristic.
- **IMP-14** Translate (Decision 9, 20 September 2026). A recipe written mostly in another language than the app's shows "ترجم إلى العربية" (or "Translate to English") on its page and in the import preview (IMP-5). "Mostly" means fewer than half of its title, ingredient names and steps are in the app's script (Arabic letters for Arabic, Latin for English).
  - It sends the recipe's words to the import server (SRV-11), then opens the result as a preview; nothing is saved until Save.
  - Saving makes a **copy**, a new recipe (REC-2), and never changes the original. The copy keeps the source URL and type, servings, times, cookbooks and tags; its cooked count starts at 0, and its photo is a copied file, so deleting one recipe never removes the other's photo (REC-8).
  - The copy shows "مترجمة من: <title>" and the original shows "الترجمة: <title>" (its newest translation), each opening the other. Deleting either leaves the other whole; the link just disappears.
  - Both keep the source URL, so importing it again finds a duplicate (IMP-9) and offers the one saved last.
  - The copy also keeps the notes and the unit view (SCALE-5); it has no rating (24 September 2026).
  - In an import preview, the translation opens as its own preview over the import's. Saving it saves the translation **instead of** the import: the import's draft is discarded with its photo, and nothing links the two, since the original was never saved. Closing the translation's preview goes back to the import's, unchanged (Decision 20).
  - A recipe past SRV-11's limits says so ("هذه الوصفة أطول من أن تُترجم دفعة واحدة") before the cost line, and nothing is sent.
- **IMP-15** Amounts never go through the model:
  - The app sends only words, each keyed by its ID: the title, group names, each line's name and note, and each step. It rebuilds every line with its original amount, range and unit ID (REC-5), so scaling, conversion and groceries behave exactly as before.
  - A line the parser couldn't read (REC-5: no amount, so it's shown as written) is sent whole; the returned text becomes its text, and only its name and note are read from it again. Every number in a returned line or step must match the numbers sent, or that line or step keeps its original text. Durations stay numbers, so cook-mode timers still work (COOK-4).
    - Numbers compare in any digit style, as a set: "1½", "1 1/2" and "١ ١/٢" match; a changed, added or dropped number doesn't. The title and group names are checked the same way.
    - A step must also give exactly the same cook-mode timers (COOK-4) as the original, or it keeps its text: "ساعة" for "1 hour" drops the number, and "until done" drops the timer.
    - A line keeps its original text whole if its name or its note fails. The preview says once when anything kept its original text (24 September 2026).
  - Every ID must come back exactly once; otherwise nothing changes, and the app offers "Try again" without using the quota (SRV-7).
  - Tested with a fake server that changes numbers: the saved copy's amounts, units and timers never change.
- **IMP-16** A translation is one AI import (IMP-7), counted only when the copy is saved, with IMP-3's line shown before sending. Translating in the preview of an AI import is part of that import and costs nothing more; translating a website import (IMP-2) or a saved recipe costs one.

## 13. Import server

**They do:** not visible. The server-side import worked for Arabic in about 25 s.

**Learn:**
- The server is a cost and a privacy surface.
- It must be cheap per import, keep nothing, and never be abusable as a free AI proxy.

- **SRV-1** The server runs on Cloudflare Workers (Decision 6). It has one endpoint that takes a link, text, or 1 to 4 images (IMP-10), and returns the recipe's **structure** in the REC shape (JSON validated against a schema): title, section groups, each ingredient line's text copied byte for byte from the source — including any placeholder the site prints — the steps in order, and servings, prep and cook minutes only when the source states them. It never returns parsed amounts or unit IDs: the device parses every line itself under QTY-1 (IMP-6), which measured more accurate than the model's own numbers (Decision 17). The same endpoint translates a recipe (SRV-11). Text imports and translations use Claude Haiku 4.5; photo imports use Claude Sonnet 5, which read Arabic amounts off a photographed page reliably where Haiku did not (Decision 21). Structured output throughout, with prompt caching requested on the system prompt and schema — it only takes effect above the model's minimum cacheable size, which the text-import prompt falls under (Decision 21). The model and prompt version come back with each result, for debugging.
- **SRV-2** For a link, the server fetches the public page or post (title, caption or description, and any recipe data) and sends only that text to the model. It never logs into anything, and never fetches a private post.
- **SRV-10** How the server gets a caption (S3):
  - **TikTok:** the public oEmbed endpoint.
  - **YouTube:** the public watch page's description.
  - **Instagram:** not read by the server (Decision 8). A shared Instagram link goes straight to the fallback in IMP-12, without a server request and without using the quota.
  - The server never pretends to be another company's crawler or browser, and never logs in.
  - A platform it can't read returns `private_post` (SRV-7), and the app offers to paste the caption as text (IMP-1).
- **SRV-3** The server keeps no content: no request bodies, captions, images or results in logs. Only aggregate counters are kept (imports, errors, tokens, cost per day). Images are held only in memory for the request.
- **SRV-4** Abuse and cost:
  - Each request carries an anonymous random install ID (created on first launch, stored on the device, included in backups) and a Play Integrity token. Requests without a valid token are refused.
  - Limits: 10 AI imports a month for free installs, 100 a month for Premium (fair use), and at most 20 requests per hour per install.
  - Premium is checked with Google Play's purchase record, not trusted from the app.
- **SRV-5** Cache: a successful result for a **public** link is cached by the normalized URL (IMP-9) for 30 days. A cache hit costs us nothing, but still counts for the user, because the quota is about imports, not our cost. Photo and text imports are never cached.
- **SRV-6** Spending cap: a monthly budget set in the Worker's config. At 80% it sends an alert. At 100%, AI imports pause for everyone with the message "Import is busy, try again later", and website imports (IMP-2) keep working.
- **SRV-7** Errors return a short code (`unreachable`, `not_a_recipe`, `private_post`, `limit_reached`, `busy`, `too_large` for more than 4 images, a body over 6 MB, or a translation past SRV-11's limits, and `bad_translation` when a translation's IDs didn't come back exactly once), which the app shows as a translated message (LANG-2). None of them uses the quota (IMP-4).
- **SRV-8** A regression suite of real Arabic inputs (both ReciMe test sources, plus the S3 spike's 10 captions and 5 photos) runs in the server repo's CI. A prompt or model change must keep every expected ingredient line and amount.
- **SRV-9** The privacy policy names the server, what it receives (IMP-3, IMP-10, and recipes sent for translation, IMP-14) and that it keeps nothing, in the release that ships it (ADS-6 style, same PR).
- **SRV-11** Translation (IMP-14, IMP-15): a request carries one recipe's words, keyed by ID, and the target language (ar or en). The server returns the same keys translated, with structured output.
  - It refuses more than 300 keys or 20,000 characters, so it can't serve as a general translator, and it counts against the same limits as imports (SRV-4).
  - Translations are never cached (SRV-5), and nothing is kept (SRV-3).
  - SRV-8's suite gains English and Arabic recipes to translate, and fails if any number changes.

## 14. Meal plan

**They do:**
- A weekly plan by date and meal type. The week starts on Monday by default, and that can be changed.
- A recipe goes to the plan, and a recipe or the whole week goes to groceries, in about two taps.
- Not verified: notes without a recipe, servings per entry, moving entries, and what happens to entries when a recipe is deleted.

**Learn:**
- A plan is how a saved recipe actually gets cooked. Families plan the week around lunch, the main meal in the Gulf, and around gatherings.
- A Monday week doesn't match the Arab weekend (weak spot 8).
- The plan feeds groceries, so it has to know how many people each meal is for.

- **PLAN-1** The plan shows one week as a list of 7 days, each with four meal slots in this order: فطور، غداء، عشاء، وجبة خفيفة (breakfast, lunch, dinner, snack).
  - The week starts on the day set in Settings. The default, "حسب المنطقة" (By region), takes it from the phone's region using the Unicode CLDR calendar data built into the app: Saturday in Egypt or Kuwait, Sunday in Saudi Arabia, Monday in the UK. With no region, it's Saturday in Arabic and Sunday in English.
  - It opens on the current week, scrolled to today, which is highlighted. Arrows move a week at a time, and "هذا الأسبوع" comes back.
  - An empty slot shows only a small "+".
  - Dates are local calendar dates (DATE-1).
- **PLAN-2** An entry is a recipe or a short note (1–60 characters, like "مطعم" or "بقايا الأمس"). A slot holds up to 10 entries, in the order added.
  - A recipe entry has its own servings, 1–100, starting at the recipe's (REC-7). A recipe without servings takes a multiplier instead: ×½, ×1, ×2 or ×3 (SCALE-2).
  - The entry's servings scale what goes to groceries (PLAN-5); the recipe itself doesn't change.
- **PLAN-3** Adding:
  - On a recipe page, "أضف إلى الخطة" opens a sheet with today and the last meal used (lunch at first) already picked. Adding takes three taps: the button, a day, Save.
  - In the plan, a slot's "+" opens a picker with the library's search (ORG-3) and "Write a note".
  - Adding never changes the recipe and never marks it as cooked (REC-9).
- **PLAN-4** A long press on an entry offers: move or copy to another day or meal, change servings, or remove, with Undo (DEL-2). "Clear week" removes every entry in the week shown, with Undo. Removing an entry never deletes the recipe and never touches the grocery list, since the shopping may be done.
- **PLAN-5** "Add to groceries" in the plan lists the recipe entries of the days shown, from today on, each ticked, so the user can untick what's already at home.
  - Each entry's lines are scaled by its servings (PLAN-2) and shown in the recipe's remembered view (SCALE-5, SCALE-6), then merged into the list (GRO-3).
  - An entry already added shows "أُضيفت" and starts unticked, so adding the same week twice doesn't double the list.
- **PLAN-6** An entry whose recipe is in the trash (DEL-1) is hidden from the plan and from "Add to groceries". Restoring the recipe brings it back; purging it (DEL-2) deletes the entry. A recipe's page shows its next planned meal ("في الخطة: الثلاثاء، غداء").

## 15. Ramadan mode

**They do:** nothing for Ramadan or Hijri dates (weak spot 8).

**Learn:**
- Ramadan is the busiest month for cooking and recipe searches in the Arab world, and Wasfati's launch hook (`docs/ROADMAP.md`).
- The day has two main meals, suhoor before dawn and iftar at sunset, with sweets and visits in the evening. Iftar gatherings cook for many more people.
- The first day depends on the moon sighting, which can differ by a day between countries, so the app's date must be easy to correct.

- **RAM-1** Ramadan mode is off by default. When on, it changes only the days inside Ramadan: their slots become السحور، الإفطار، وجبة خفيفة (suhoor, iftar, snack), in that order.
  - An entry already in breakfast, lunch or dinner on one of those days stays, under its own slot, so nothing is hidden.
  - Days outside Ramadan don't change, so the mode can stay on all year and apply itself each Ramadan.
- **RAM-2** Ramadan's dates come from the Umm al-Qura calendar, built into the app (no network).
  - With the mode on, each Ramadan day shows its Hijri date beside the usual one ("٥ رمضان"), and the day after the last one shows "عيد الفطر".
  - Settings can move the first day one day earlier or later, for the local moon sighting. That moves the whole month, and it resets for the next Ramadan.
- **RAM-3** From 7 days before Ramadan until its last day, while the mode is off, the plan shows one card: "رمضان بعد ٣ أيام. نحوّل الخطة إلى سحور وإفطار؟" with "تفعيل" and "ليس الآن". "ليس الآن" hides it until the next Ramadan, and the switch stays in Settings. The mode never turns itself on.
- **RAM-4** With the mode on, from 7 days before Ramadan until its end, the plan offers a "رمضان" view beside "الأسبوع": the whole month, day 1 to 29 or 30, with the same slots, entries and actions (PLAN-3, PLAN-4). There, "Add to groceries" (PLAN-5) lists the month's remaining entries. A gathering is an iftar entry with more servings (PLAN-2).
- **RAM-5** Ramadan mode shows no prayer or iftar times. They would need the user's location, a permission the app doesn't ask for (RUN-2), and prayer apps already do this well.

## 16. Groceries

**They do:**
- A grocery list filled from a recipe (with a picker of its ingredients) or from the whole week's plan, sortable by aisle.
- All 22 Arabic items in our test landed in "Uncategorized", and "1 كيلو جرام لحم ضأن" became "جرام لحم ضأن" × 1 (weak spots 2 and 4).
- "Order online" offers only US stores in the UAE.
- Not verified: how the same item merges across recipes, and sharing the list.

**Learn:**
- One shopping trip wants one short list: the onions from three recipes are one line with the right total.
- Aisles only help if they know Arabic names; an "Uncategorized" pile is no help.
- In the Gulf the list often goes to someone else, family or a driver, on WhatsApp.

- **GRO-1** There's one grocery list. An item has a name, an aisle (GRO-4), one or more amounts (each an exact number with a unit ID, QTY-4, or none), a done state, and the recipes its amounts came from.
  - Typing in "أضف غرضًا" parses the line (QTY-1): "2 كيلو طماطم" becomes 2 kg of طماطم, in vegetables and fruit.
- **GRO-2** "أضف إلى المشتريات" on a recipe page lists its lines as the page shows them, with the current scale and view (SCALE-6), each ticked.
  - To-taste lines (QTY-2) start unticked. Water and ice aren't listed.
  - One tap adds the ticked lines and says how many ("أُضيفت ٩ مكونات").
- **GRO-3** Merging: a new line joins an item that isn't done when their names match after ORG-4's normalization, with a leading "ال" dropped from each word.
  - The same unit adds up: 1 كوب + 2 كوب = 3 أكواب.
  - Mass with mass, or volume with volume, in different units, adds up in metric (g or ml, stepping up to kg or l from 1,000, SCALE-5): 1 كغ + 500 غ = 1.5 كغ.
  - A count with no unit and a count in حبة are the same: 2 بصل + حبة بصل = 3 بصل.
  - A range adds its upper end, so there's enough: 2–3 + 1 = 4.
  - A to-taste line adds no amount.
  - Anything else, like a can and a count, or cups and grams, stays as a second amount on the same item: "طماطم: 2 حبة + علبة".
  - The total is rounded once (SCALE-3).
  - A done item is never merged into: a line added after shopping makes a new item.
  - Names in different languages don't merge (no dictionary, like ORG-4).
- **GRO-4** Aisles are fixed, with translatable names (DATA-1), in the order of a walk through a store:
  1. خضار وفواكه (vegetables and fruit)
  2. لحوم ودواجن (meat and poultry)
  3. أسماك (fish and seafood)
  4. ألبان وأجبان وبيض (dairy, cheese and eggs)
  5. خبز ومخبوزات (bread and bakery)
  6. أرز ومعكرونة وبقوليات (rice, pasta, grains and pulses)
  7. بهارات (spices)
  8. زيوت وصلصات ومعلبات (oils, sauces and cans)
  9. مستلزمات الحلويات (baking and sweets: flour, sugar, yeast)
  10. مجمدات (frozen)
  11. مشروبات (drinks)
  12. أخرى (other)

  - A built-in table of Arabic and English ingredient names places each item, matching the normalized name (ORG-4) by its longest known phrase: "صدر دجاج مسحب" goes to meat and poultry.
  - **At least 95% of the ingredient names in the S1 and S2 fixtures land in a named aisle, not "أخرى"** (the answer to weak spot 4). A test checks it.
  - Moving an item to another aisle is remembered for that name, so the next "كزبرة" goes there too.
- **GRO-5** The list:
  - Aisles in GRO-4's order; items by name within an aisle (Arabic alphabetical order, ORG-5).
  - Amounts in the user's digits, with units agreeing with the number (QTY-5, QTY-6), and the recipes an item came from on a second line.
  - Ticking an item moves it into a collapsed "تم" section at the end; unticking moves it back.
  - "Clear done" and "Clear all" remove with Undo (DEL-2).
  - A "By recipe" view groups the amounts under each recipe, with hand-added items under "أضفتها بنفسك". Each recipe there has "Remove", which takes out only its own amounts. The view choice is remembered.
- **GRO-6** "Share" sends the items not yet done as plain text through the share sheet (WhatsApp first): a title line, the aisle headings, and one line per item ("• 2 كغ طماطم"), in the user's digits, with QTY-5's isolates so amounts read the right way. No link, no app name and no ad (ADS-9). An empty list can't be shared.
- **GRO-7** Deleting a recipe (DEL-1) leaves the list alone; its items just stop naming it. Cleared items follow DEL-1 and DEL-2 but never show in the recipe trash. The list is free (PAY-7), works offline, and is in backups (BAK-6).

## 17. Sharing a recipe

**They do:** PDF export is Plus-only. Sending a recipe to someone else: not verified.

**Learn:**
- Arab families pass recipes around on WhatsApp, as text or pictures, and the person receiving one may not have Wasfati.
- A shared recipe is the app's best advert, but only if it reads well in Arabic and doesn't feel like an ad.
- WhatsApp shrinks pictures to about 1,600 px on the long side, so one long picture of a recipe becomes unreadable.

- **SHARE-1** "مشاركة" on the recipe page offers "كنص" (as text) and "كصورة" (as images). Both go through the Android share sheet: nothing is uploaded and no web page is made (principle 2).
  - What's shared is what the page shows: the current scale and view (SCALE-6), in the user's digits (QTY-5).
  - Never shared: notes, the kept original caption (IMP-6), rating, tags, cookbooks and the cooked count.
- **SHARE-2** As text: the title; one line with whichever of servings and times are set (REC-3); the ingredients under "المقادير", with group headings (REC-4); the steps, numbered, under "الطريقة"; the source link, if any; and a last line, "من تطبيق وصفاتي", with the app's Play link.
  - Headings follow the app's language (LANG-2); the recipe itself stays as written.
  - Arabic lines carry QTY-5's isolates, so WhatsApp shows "1½ كوب" the right way.
- **SHARE-3** As images: portrait pages of 1,080 × 1,350 px, below WhatsApp's resize limit, shared together.
  - Page 1 has the photo (if any), the title, servings and times, then the ingredients; the steps follow on the next pages.
  - Body text is at least 32 px, and a page breaks between lines, never inside one.
  - Each page's footer shows "وصفاتي" and the page count ("٢/٣").
  - At most 6 pages; a longer recipe offers text instead.
  - Each line reads in its own direction, as on the recipe page (LANG-5). Pages always use the light palette of the look the user picked (LOOK-1), whatever the light/dark setting says, so a share looks like the app the sender uses and stays readable on a white chat background.
- **SHARE-4** Images are drawn on the device into the app's cache and deleted at the next start. No permission is needed (RUN-2), and a page carries no ad, QR code or tracking link (ADS-9).

## 18. Look and feel

**They do:**
- One look, built for English: white cards, a single accent colour, left-to-right layout. Arabic recipe lines sit left-aligned inside it, with the number visually at the end of the phrase (weak spot 3).
- No choice of look; dark mode was not verified.

**Learn:**
- A cooking app is read on a counter, at arm's length, often at night: legibility and contrast are features, not polish.
- The look is part of being Arabic-first. A Western layout with Arabic poured into it reads as a translation.
- Taste differs. One well-made look still feels wrong to part of the people who open it, and a choice costs little when the looks are data, not forks.

- **LOOK-1** Two looks, picked in Settings under "الطراز / Look": **حبر / Ink**, the default, and **زعفران / Saffron** (Decision 14). The choice is independent of the light/dark setting ("المظهر"), so there are four combinations plus "حسب الجهاز". It applies at once, without a restart (LANG-1), and it's stored with the settings, so a backup carries it (BAK-6). A shared recipe image uses the chosen look's light palette (SHARE-3, Decision 16).
- **LOOK-2** A look changes only colour, type, shape and drawn decoration. It never changes a string, a tooltip, the order or position of a control, or what a screen shows, so muscle memory, screenshots in help and the widget tests hold in both.
- **LOOK-3** Contrast, in both looks and both brightnesses:
  - body text at least 4.5:1 and large text at least 3:1 against every surface it can sit on;
  - the boundary of a control or container at least 3:1 (a fill step alone never makes a card a card);
  - disabled text at least 3:1, never Material's default 38% alpha;
  - hint text at full `onSurfaceVariant`, never faded.
  A pure-Dart test computes the WCAG 2.1 ratio of every text/surface pair each theme uses from its `ColorScheme` and fails below the bar.
- **LOOK-4** Amounts are the loudest text in an ingredient line (the app's claim is that they're right). **Ink** sets the amount in the primary colour at weight 600; **Saffron** in the body colour at weight 600. The amount and the unit word that agrees with it stay one phrase (QTY-6): the line is split at the isolate characters `formatLine` already emits, never re-parsed. Cook mode's ingredient sheet and the grocery list do the same.
- **LOOK-5** Type: one family, IBM Plex Sans Arabic (400–700), letter-spacing 0 on every token, even leading. Line height 1.75 on any text that can wrap to a second line and 1.5 on single-line chrome — from the font's own metrics, 1.729 em clears any Arabic glyph pair, tashkeel included. The full scale is in `docs/research/design-styles.md`.
- **LOOK-6** Decoration is drawn, never a bitmap, and mirrors with the language: Ink's heading rail (a 3 × 20 dp bar at the reading edge of every section heading), Saffron's 45° cut corner on photos, chips and step numbers, and the empty-state ornament are `ShapeBorder`s and `CustomPainter`s placed with `EdgeInsetsDirectional` / `BorderDirectional`. No new package, font or image.
- **LOOK-7** Depth: Ink has no shadow or elevation anywhere. Saffron has exactly one: a 2 dp press ledge under its three primary actions ("أضف وصفة", "ابدأ الطبخ" and cook mode's "التالي"), which collapses while pressed. Neither look tints surfaces by elevation.
- **LOOK-8** Every main screen renders in both looks, both brightnesses and both languages at 1.3× text on a 360 dp phone without overflow (LANG-6). Cook mode keeps COOK-2's sizes in both. The banner slot (ADS-9) sits in the same place in both, and an empty slot shows nothing in either.
- **LOOK-9** The launcher icon, the splash screen and the store icon are one design, from one committed source image, and they don't change with the look: the store shows one app. The app's name on the device is "وصفاتي" in Arabic and "Wasfati" in English (LANG-2).

## Decisions
<!-- Numbered and dated answers to open questions, citing the rules they settle. -->
1. (19 September 2026) Money model: ads, plus a one-time Pro that removes them, plus a Premium subscription for AI imports beyond the free quota and nutrition (PAY-1, PAY-5). This replaces the kit's one-time-only rule because AI imports cost us per use.
2. (19 September 2026) Wasfati has a thin import server: a serverless proxy that holds the AI key and turns a post link, caption or photo into a recipe (Claude Haiku 4.5 to start). It keeps nothing it's sent, caches results per public post URL, rate-limits per device, checks Play Integrity, and has a monthly spending cap. This reverses the suite's "no backend" default for this app only.
3. (19 September 2026) v1 targets Android on Google Play; iOS follows. No desktop.
4. (19 September 2026) Free AI imports: 10 per calendar month, resetting on the 1st; website imports with recipe data are free and unlimited (IMP-2, IMP-7, SRV-4).
5. (19 September 2026) Digits: Western 123 by default in both languages, Arabic ١٢٣ as a Settings option; the parser always reads both (QTY-1, QTY-5).
6. (19 September 2026) Cook-mode timers alert in the background with a notification; permission is asked at the first timer (COOK-4, COOK-5). The import server runs on Cloudflare Workers, with its code in a private repo, Oasis-Forge/wasfati-import (SRV-1).
7. (19 September 2026) Starter rule MONEY-1 doesn't apply: Wasfati handles no money. Prices come only from the store (PAY-2).
8. (19 September 2026) Instagram: users share the post link as usual. Because Instagram blocks logged-out reading, Wasfati then asks for the caption, pasted as text, or a screenshot, read by photo import (IMP-12, SRV-10). Faking a crawler is ruled out. Applying for Meta's official oEmbed API is a later item; if it's approved and returns captions, a shared link alone will be enough.
9. (19 September 2026; decided 20 September 2026) "Translate to Arabic": a recipe in another language gets a button, on its page and in the import preview, that saves a translated **copy** beside the original, linked both ways; the original never changes. It costs one AI import, except inside an AI import's own preview. The app sends only the words and keeps every amount and unit itself (IMP-14–IMP-16, SRV-11). An English app offers "Translate to English" the same way. The principles now say recipes also leave the device when the user shares or translates one.
10. (20 September 2026) Prices, as Play Console base prices: Pro AED 14.99 one-time; Premium AED 9.99 a month or AED 59.99 a year, about half of ReciMe's AED 18.99 and AED 114.99. The app shows the store's own price (PAY-2, PAY-7, PAY-8).
11. (20 September 2026) No free trial for Premium: the 10 free AI imports a month let everyone try it, and nothing can charge by surprise (PAY-9).
12. (20 September 2026) Banners go on four screens, the library, the recipe page, the meal plan and groceries, all from the one banner unit created that day; never in cook mode, the editor or the import preview (ADS-9). The recipe page has one because that's where most reading time goes; cooking itself stays ad-free in cook mode.
13. (20 September 2026) Round 2 calls taken without a question:
    - Ramadan mode is offered by a card and never switches itself on; once on, it stays on for later years (RAM-1, RAM-3).
    - One grocery list (GRO-1).
    - Android's device backup carries the database, not photos (BAK-9).
    - Shared recipe text ends with one line naming the app, with its Play link. Shared grocery lists and recipe images carry no link (SHARE-2, SHARE-4, GRO-6).
    - The "By region" week start uses CLDR's data for the phone's region, falling back to Saturday in Arabic and Sunday in English (PLAN-1).
    - The store's review prompt comes only after an import and a cooked recipe (RUN-5).
14. (20 September 2026) The app ships **two looks**, picked in Settings, not one: **حبر / Ink** (cream paper, near-black ink, a deep teal that marks every amount, hairlines instead of boxes, no shadows) and **زعفران / Saffron** (quiet cream page, solid saffron action blocks with near-black text on them, one corner cut at 45°). Each has a hand-tuned light and dark theme. Both keep every existing string, add no package, font or bitmap, and must pass AA for text on every surface in both brightnesses. Ink is the default. The full specification — palettes, type scale, components, per-screen plans — is in `docs/research/design-styles.md`; the rules get IDs with `/spec look` before any of it is built (Phase 3).
15. (22 September 2026) Merge can bring back an item purged more than 30 days ago (DEL-2): a purge hard-deletes with no tombstone, so a backup made before the purge has no way to tell a merge the item was ever deleted. Accepted for now: purging only ever removes what this device itself deleted and forgot about, and BAK-8's 30-day reminder makes a much-older backup the exception. BAK-3's "the later `updated_at` wins, deletions included" is read as applying to soft-deleted rows still in the database, not to rows already purged. Revisit if this surfaces as a real complaint.
16. (22 September 2026) A shared recipe image uses the light palette of the look the user picked (LOOK-1), whatever the light/dark setting says, rather than one fixed palette for everyone: the picture then looks like the app the sender actually uses, and it stays readable on a white chat background. The alternative, one fixed look for every share, was rejected because a زعفران user would be sending pictures of an app they don't have.
17. (23 September 2026) The import server's real cost, measured against five real Arabic posts (Fatafeat, Cookpad, Sayidaty, Atyabtabkha, a TikTok caption) run through both Claude Haiku 4.5 and Claude Sonnet 5: Haiku is the model, not Sonnet. Sonnet invented an ingredient out of a section heading and dropped an ingredient's name from the verbatim text on all 8 lines of one recipe, which IMP-6 forbids; Haiku's mistakes were smaller and recoverable, and speed and token counts were within 6% of each other, so there was no cost reason to prefer Sonnet. Asking the model for amounts as numerator/denominator pairs with a unit ID was wrong 5 times in 64 lines, always by inventing a unit the line never had; asking it only for the verbatim line text and letting the device's own parser read the amounts (QTY-1) agreed with the 5-times-wrong version 58 times out of 64, beat it 5 times, and lost once, for 49% fewer output tokens and half the wall time — so the server now returns structure only (SRV-1). Cost per import is about half a US cent with prompt caching on the ~4,700-token prompt and schema (SRV-1), roughly $0.005 against $0.009 without. At that cost, Premium's 300-import cap would have cost more than the yearly plan pays after the store's fee, so it drops to 100 (PAY-7, SRV-4) — still ten times the free tier and twenty times what ReciMe gives away, and a cap is far easier to raise later than a price is to change. The yearly base plan rises from AED 59.99 to AED 79.99 (PAY-8): a per-use cost eats quietly at a subscription's margin, and it eats hardest on the yearly plan, where one payment has to cover twelve months of importing instead of being re-priced every month.
18. (24 September 2026) SRV-4 says every request carries a Play Integrity token; the deployed server doesn't check for one yet. Confirmed live while finalizing Phase 2b (must-fix, review): a POST to `https://wasfati-import.thepromptkitchen.workers.dev/v1/import` with only `install_id` (no token, since `DeviceAiImportClient` never sent one) got a normal 200, not the 403 SRV-4 describes. Adding the token is server work first — a Play Console project link and a native plugin on our side only make sense once the Worker actually rejects untokened requests — so it's tracked in `Oasis-Forge/wasfati-import`, not here. Accepted for now: the app ships this phase without a token; `invalid_integrity_token` (SRV-7) stays mapped and shown for whenever the check turns on, so that day needs no app-side release. Re-verify with the same request before the next AI-import release.
19. (24 September 2026) "Report a mistake" (IMP-8) opens the user's own mail app with a draft to oasisforge.support@gmail.com, instead of posting the report to an endpoint of ours. The user sees exactly what is sent, the source link and their note and nothing more, and sends it themselves or doesn't; nothing is sent behind their back. The import server keeps nothing it's sent (SRV-3), and a report endpoint would be the one place it had to store something, the very thing SRV-3 rules out; a mail draft needs no endpoint, no storage and no new privacy surface. The cost is that a phone with no mail app can't send a report, so the app shows the address there instead. The draft opens through a few lines of platform glue for Android's `mailto:` intent rather than a package (`docs/STACK_NOTES.md`): it adds no permission and no dependency.

20. (24 September 2026) Translating inside an import's preview (IMP-14, IMP-16) opens the translation as a second preview over the import's, and saving it saves the translation **instead of** the import, not both. The user asked for the recipe in their language; saving the untranslated draft beside it would put a recipe in the library they never chose to keep, and one they'd then have to delete. The import's draft is discarded with its photo (the translation has its own copy of it, REC-8), and there is no "مترجمة من" link, since nothing was saved to link to. The draft's notes still hold the original caption (IMP-6), so nothing is lost. The cost is unchanged: one AI import in all, counted when the translation is saved — the import's own for an AI import, a translation's for a website import. Closing the translation's preview returns to the import's untouched, so the user can still save the original instead.
21. (24 September 2026) Photo imports use **Claude Sonnet 5**, not Haiku 4.5 (SRV-1, IMP-10). Measured on a synthetic Arabic recipe card — six ingredient lines in Arabic-Indic digits with a fraction, three numbered steps — sent as a clean scan and as a tilted phone photo, twice each: Haiku read 17 of 24 lines and 5 of 12 steps exactly, misread seven amounts (٢ as ٣, ١ ١/٢ as ١١/٤, ٢٥٠ as ٥٠) and invented a cook time once; Sonnet 5 read all 24 lines and all 12 steps exactly. A photo is the one import where the device has nothing to check the numbers against — there is no source text to re-parse, only what the model read — so the model that reads them right is worth about $0.011–0.021 a photo against Haiku's $0.008. Text imports and translations stay on Haiku 4.5. The same measurement corrected Decision 17's cost: the text-import prompt and schema come to about 3,300 tokens, under Haiku 4.5's 4,096-token minimum for prompt caching, so they are never cached and a text import costs about $0.008–0.009, not half a cent. Premium's cap of 100 still holds comfortably for text (about $0.85 a month at the very worst), but 100 photo imports would cost about $1.10–2.10 against roughly $2.31 net a month, so the margin on a photo-heavy subscriber is thin. Revisit with real usage before launch rather than guessing now.
22. (24 September 2026) Premium's server-side quota lands with the Play Console setup (Phase 5), not with the app's Premium. SRV-4 has the import server trust Premium only from Google Play's own purchase record, never from the app, and checking a purchase token needs a Google service account linked to the app's Play Console project — which doesn't exist yet. So the app now reads Premium from the store at every launch and raises its own count to 100 (PAY-1, PAY-7), while the deployed server still allows every install the free 10. Accepted, because nobody is shortchanged: Pro and Premium can only be bought once they're created in the Play Console (PAY-8), the same setup that brings the service account, so until then nobody can buy Premium and the purchase screen says nothing is for sale (PAY-6). The server's check goes live before Premium is offered to anyone, licence testers included, and so does PAY-11's renewal date, which comes from the same record. The alternative, trusting a flag the app sends, was rejected: it would make the 100 free for anyone who edits a request.

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
- **Phase 2b order:** the server (SRV-1–SRV-11) before share and photo import (IMP-1, IMP-3, IMP-4, IMP-7, IMP-8, IMP-10).
- **Phase 2b schema:** a step adding `translated_from` on recipes, the original's ID, for IMP-14's link. Translation (IMP-14–IMP-16, SRV-11) comes after the server. Shipped as schema step 6 on 24 September 2026: a plain column with an index and no foreign key, so a purge of either recipe never fails on the other.
- **Phase 2c schema, each step before the feature that reads it. Step 3 shipped on 20 September 2026 with the plan; the grocery tables are step 4:**
  - Plan entries: date, meal slot, a recipe or a note, servings or multiplier, order, and when it was added to groceries (PLAN-2, PLAN-5).
  - Grocery items, each with its amounts, and each amount with the recipe and plan entry it came from (GRO-1, GRO-5).
  - Aisle choices by name (GRO-4).
  - New settings: Ramadan mode, this year's start shift and the card's "not now" (RAM-2, RAM-3), and the last backup date and reminder switch (BAK-8).
- **Phase 2c order:** the plan's schema step → meal plan → the grocery tables → groceries (they read the plan) → Ramadan mode → sharing → backup, restore and export last (BAK-6 needs every table).
- **Permissions (RUN-2):**
  - `INTERNET` arrives with website import (IMP-2).
  - `POST_NOTIFICATIONS` arrives with cook-mode timers (COOK-5).
  - No `CAMERA`: photos come through the system camera and picker (IMP-1).
  - No exact alarms.
  - Keeping the screen on (COOK-3) uses the window flag, not a wake-lock permission.
  - Ads add `ACCESS_NETWORK_STATE` and `com.google.android.gms.permission.AD_ID`; purchases add `com.android.vending.BILLING`. Each joins the release workflow's allowed list in the PR that brings it, checked against a real build (Phase 3). Done 24 September 2026 (Phase 4): the ad SDK also brings the Privacy Sandbox's `ACCESS_ADSERVICES_AD_ID`, `_ATTRIBUTION` and `_TOPICS`, and `WAKE_LOCK` and `FOREGROUND_SERVICE` through WorkManager and the measurement API; no shipped feature needs them, so `AndroidManifest.xml` removes them from the merged manifest, and the real release build declares exactly the six allowed.
  - Backup, restore and sharing need none: they use the system's save and open dialogs and the share sheet.
- **Privacy policy:** website import (a page fetched directly from its site), the import server and translation (SRV-9), notifications, Android's device backup and backup files (BAK-9), and ads (ADS-6), each updated in the PR that ships it.
