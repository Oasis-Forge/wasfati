# Roadmap

Goal: ship Wasfati v1 to Google Play. Wasfati is an Arabic-first recipe saver: import from TikTok, Instagram, YouTube and websites; cook, scale, plan and shop.

Behavior is defined in `docs/PRODUCT_RULES.md`, and items cite its rule IDs. Group related items into larger PRs; CI must pass. Tick items in the same PR that completes them, and date every decision that adds, moves, or drops one.

## Plan at a glance (drafted 19 September 2026)

Weeks start on Mondays. W0 is 21 September 2026.

**Assumption:** one developer with AI agents, full time. With two developers, Phases 2a and 2b can run in parallel. The QR and Notes dates come first; if Wasfati only gets part-time capacity, every date below slips by the same factor.

**Launch anchor:** Ramadan 2027 is expected to begin around 8 February 2027. Ramadan mode is the launch hook, so the app should be live on Play by **mid-January 2027** at the latest.

| Week | Dates | Phase | Outcome |
|---|---|---|---|
| W0 | 21–27 Sep | 0 | `/spec` round 1, spikes S1–S4, release workflow run by hand |
| W1–W2 | 28 Sep–11 Oct | 1 | Data model, quantity parser, migrations, localization (ar + en) |
| W3–W5 | 12 Oct–1 Nov | 2a | Recipes, cookbooks, search, cook mode, scaling, website import |
| W6–W7 | 2–15 Nov | 2b | Import server, share-sheet import with a preview, photo import |
| W8 | 16–22 Nov | 5 | **Closed test starts** (12 testers, 14 days) on the 2a+2b build; later items ship as updates during the test |
| W8–W10 | 16 Nov–6 Dec | 2c | Meal plan, Ramadan mode, groceries, sharing, backup |
| W11 | 7–13 Dec | 4 | Ads, Pro, Premium; first-run walkthrough |
| W12 | 14–20 Dec | 5 | Apply for production (after the 14 days); store listing in Arabic and English |
| W13–W14 | 21 Dec–3 Jan | 5 | Production review and rollout. **Target: live by 3 January 2027** |

This follows the QR pattern (decided 2026-09-16 for QR): the closed-test build is trimmed, and v1 items ship as updates during the test.

## Phase 0: Tooling and decisions
Set up before the first feature, while it's cheap.
- [x] `CLAUDE.md`, `.claude/` settings, format hook, `/spec` `/verify` `/release` `/ship` `/handoff` skills, `build-doctor` agent (`/kickoff`)
- [x] GitHub repo, Dependabot, CI (checks + a build for every mobile platform) green on a first PR
- [x] `main` ruleset: PR required, the CI checks required, no force pushes or deletion (`docs/RELEASING.md`)
- [x] Every merged PR is a release: the CI version check, then a tag and a draft GitHub Release on merge. `v0.1.0` is the first.
- [x] The release workflow runs once by hand without secrets (unsigned artifacts, nothing published): 21 September 2026, run 35636267793 built and released nothing
- [x] Privacy policy draft served by GitHub Pages
- [x] Competitor research, hands-on (`docs/research/competitor-analysis.md`, PR #1)
- [x] **`/spec` round 1** (19 September 2026): §7–§13 of `docs/PRODUCT_RULES.md`, Decisions 4–7. Areas:
  - **REC** recipe model
  - **QTY** quantities, units and the parser
  - **SCALE** scaling and conversion
  - **COOK** cook mode
  - **ORG** cookbooks, tags, search and sort
  - **IMP** import: website, share, photo, preview, report mistake
  - **SRV** the import server's contract, quotas and limits
- [x] **`/spec` round 2** (20 September 2026): §14–§17 of `docs/PRODUCT_RULES.md`, new rules in §2, §3, §6, §12 and §13, and Decisions 9–13. Areas:
  - **PLAN** meal plan
  - **RAM** Ramadan mode
  - **GRO** groceries and aisles
  - **SHARE** sharing a recipe as text or images
  - **BAK** the backup file, restore, the reminder and export
  - **ADS/PAY** where banners go, tiers, products and prices (no trial)
  - **IMP/SRV** Translate (Decision 9)
- [ ] **Spikes** (W0), each with a written result in `docs/research/technical-constraints.md`. Done 19 September 2026: S1 (80-row parser table passes, QTY-8), S2 (5 of 8 Arabic sites work on the device, IMP-11) and S4 (`receive_sharing_intent`, manifest only). **S3 is half done:** caption fetching works for TikTok and YouTube, Instagram is pending (Decision 8), and the cost measurement needs an API key.
  - **S1 Quantity parser:** Western and Eastern Arabic digits, fractions (½, 1/2, ¼), ranges (2–3), Arabic units and abbreviations (كيلو، ك، غ/جرام، كوب، ملعقة كبيرة/صغيرة، حبة، فص، عود، رشة، حزمة، علبة). Use the real lines from both ReciMe tests as fixtures.
  - **S2 Website import on the device:** read schema.org `Recipe` JSON-LD from Fatafeat and 5 other Arabic sites. Record which have it and which need AI.
  - **S3 Import server:**
    - A serverless proxy that calls Claude Haiku 4.5 with structured output.
    - Measure the real cost per import on 10 Arabic captions and 5 photos, not estimates.
    - Measure the latency.
    - Check how to fetch a caption for TikTok, Instagram and YouTube.
  - **S4 Share target:** receiving shared text or URLs and images from TikTok, Instagram and YouTube on Android, in Flutter only (no hand-written Kotlin).
- [x] **Decision: where the server code lives** (19 September 2026, Decision 6): Cloudflare Workers, code in the private repo `Oasis-Forge/wasfati-import`.
  - Recommended: a separate private repo, `Oasis-Forge/wasfati-import`, holding the worker code and deploy config. Keys live only in the provider's secret store.
  - This keeps the public app repo free of anything secret.

## Phase 1: Foundations (W1–W2)
Groundwork every feature builds on. Settle everything that shapes stored data now, before real users have any.
- [x] Strict lints (unawaited futures, declared return types, consistent quotes, const where possible).
- [x] Inject the storage layer and every device service into the state layer, so tests use an in-memory database and no-op fakes (sqflite + provider, per `docs/STACK_NOTES.md`).
- [x] Migration scaffold: an ordered list of schema steps run on upgrade, with a test that upgrades the oldest schema.
- [x] Reliable writes: write first, then change state; on failure roll back and show an error.
- [x] Localization scaffolding with **Arabic as the first language and English second**. Every UI string lives in the ARB files, and right-to-left is the default layout (LANG-1–LANG-6).
- [x] Schema step: record rules on every table: UUIDs, timestamps, soft delete (REC-1, REC-2, DEL-1).
- [x] Schema step, recipes (REC-3–REC-9, ORG-1, ORG-2, and the install ID from SRV-4):
  - A recipe: title, photo, source URL and type, prep and cook time, servings.
  - Ingredient **groups** ("for the sauce").
  - Ingredient lines, each with an amount (a number or a range), a unit ID, a name, a note and the **original text**.
  - Steps as an ordered list.
  - Cookbooks, tags, notes, and a "cooked" count.
- [x] **Quantity parser and formatter** (QTY-1–QTY-8; prototype from S1 already in `lib/models/quantity/`, with its table) and Arabic search normalization (ORG-4), as pure Dart with a test table built from the S1 fixtures:
  - Parses Western and Eastern Arabic digits, fractions, ranges, and Arabic and metric/US units.
  - Displays in the user's digit style.
  - Rounds countable items (حبة، فص، بيضة) sensibly.
  - Shows fractions, not 0.5.
- [x] Tests: model round-trip, each migration step, the parser and scaler tables, widget tests for the main flows in right-to-left and left-to-right.
- [x] Platform decision: Android on Google Play in v1, iOS after, no desktop (19 September 2026, PRODUCT_RULES Decision 3).

## Phase 2a: Offline core (W3–W5)
- [x] **Settings:** language (system / العربية / English), digit style (Western 123 by default, Arabic ١٢٣; QTY-5, Decision 5), units (metric / cups and spoons), week start (default by locale: Saturday in the Gulf), theme.
- [x] **Recipes and cookbooks** (REC-3–REC-11, ORG-1, ORG-2, ORG-7): PR 1 (v0.3.0) editor and recipe page; PR 2 (v0.4.0) cookbooks, tags, grid view:
  - Write a recipe by hand, edit it, add a photo from the picker.
  - Cookbooks and tags.
  - Grid or list view.
- [x] **Find** (ORG-3–ORG-6, v0.4.0): search by title **and ingredient** (it ignores Arabic diacritics and hamza/taa-marbuta variants, LANG-4); sort by recently added, A–Z, most cooked; filter by cookbook, tag and time.
- [x] **Cook mode, free** (COOK-1–COOK-6; timers notify in the background, Decision 6; v0.6.0): screen stays on, one step at a time in large text, step timers found in the text ("لمدة 15 دقيقة"), ingredient checklist, swipe between steps in right-to-left.
- [x] **Scaling and conversion, free** (SCALE-1–SCALE-6; v0.5.0, schema step 2 stores the per-recipe view):
  - Servings −/+ and ×½ / ×2.
  - Conversion between cups and spoons and grams/ml, where a density is known.
  - Scaling never silently skips a line: a line it can't scale is flagged.
- [x] **Website import on the device** (IMP-2, IMP-5, IMP-6, IMP-9, IMP-11, IMP-13; v0.7.0; the share target for links and text is in too): paste or share a link → read the schema.org recipe → preview → save. Free and unlimited. A site without recipe data offers AI import instead (Phase 2b).
- [x] **Delete, undo, trash** (DEL-1, DEL-2)
- [x] **First run:** empty states with one clear first action, and one built-in sample recipe (RUN-1, RUN-6; v0.13.0)

## Phase 2b: AI import (W6–W7)
- [ ] **Import server** (SRV-1–SRV-11):
  - Deploy the proxy from S3.
  - It turns a link, caption or image into the REC structure (structured output).
  - It keeps nothing it receives, and caches results by public post URL.
  - Rate limit per device, Play Integrity check, a monthly spending cap and alerts. Not enforced yet on the deployed Worker as of 24 September 2026 (Decision 18, must-fix, review) — the app ships without a token until the server side lands.
  - A test suite with the S1 and S3 fixtures that fails on regressions.
  - S3b's measured cost per import, checked against Premium's price (PAY-8): about half a US cent per import with prompt caching on, measured 23 September 2026 against five real Arabic posts through Claude Haiku 4.5. The 300 fair-use cap would have cost more than the yearly plan pays after the store's fee, so it's cut to 100 a month (PAY-7, SRV-4, Decision 17). Re-check before launch if the prompt or the model changes.
- [x] **Share-sheet import** (IMP-1, IMP-3–IMP-9): a link or shared text goes to AI import when the device-only path (IMP-2) can't read it → progress, with the cost line before sending (IMP-3) → **preview to edit before saving** → save. "Report a mistake" (IMP-8, Decision 19) shipped on `feat/phase-2b`: a mail draft to the support address holding only the source link and the user's note, sent by the user from their own mail app. What real apps put in a share is its own item below, still open.
- [x] **Instagram fallback** (IMP-12, Decision 8): when a caption can't be read, the app offers to paste it, read from the clipboard only on tap, or a screenshot ("أو صورة للشاشة", through photo import, `feat/phase-2b`), with the original link kept as the source either way.
- [ ] **Emulator check of real share payloads** (S4 follow-up): what TikTok, Instagram, YouTube and Facebook put in a share (link only, or caption too). The user logs in to each app on the emulator. If Instagram includes the caption, IMP-12 becomes a rare path.
- [x] **Translate** (IMP-14–IMP-16, SRV-11, Decisions 9 and 20; schema step 6; `feat/phase-2b`): "ترجم إلى العربية" ("Translate to English" in an English app) on a recipe's page and in the import preview, when fewer than half of its title, ingredient names and steps are in the app's script. The cost line shows first, except inside an AI import's own preview, where it's part of that import. Only words go out, keyed by ID (`POST /v1/translate`); every line keeps its own amount, range and unit, and a text whose numbers or cook-mode timers changed keeps its original. An incomplete answer offers "Try again" at no cost, and a recipe past the server's limits says so before anything is sent. Saving makes a new recipe with its own photo file, linked both ways ("مترجمة من" / "الترجمة"); backups carry the link. In an import preview, the translation is saved instead of the import. Covered by tests with a fake server; the live `/v1/translate` endpoint hasn't been called from a phone yet.
- [x] **Photo import** (IMP-1, IMP-10): a cookbook page or handwritten recipe, from the camera or picker → server vision → preview. Shipped on `feat/phase-2b`: 1 to 4 photos (the camera a page at a time, the picker up to 4), resized on the device to 1600 px at JPEG 80, the cost line before sending, the first photo kept as the recipe's unless removed; no `CAMERA` permission.
- [x] **Free AI-import quota** (IMP-7, SRV-4; 10 a month, Decision 4): a counter visible in the header, the reset date shown, and an import only counts when saved.
- [x] **Network permission and privacy:** the first release with the server rewrites the privacy policy and the data-safety form in the same PR. `docs/privacy-policy.html` (both languages) no longer claims "no server" — it now has a dedicated Importing with AI section naming Anthropic's Claude, what's sent (a link, pasted text or install ID), the 30-day public-link cache, and that translation uses the same server (SRV-9); effective date 24 September 2026. `store/play/data-safety.md` created (didn't exist before) with the Play Console answers: Device or other IDs and "Other user-generated content" collected, shared only with Anthropic as a processor, not used for ads or tracking. Photo import (IMP-1, IMP-10) shipped on `feat/phase-2b`, and both docs now say so: the policy names photos (up to 4, shrunk on the phone, held only in memory) and "Report a mistake"'s mail draft, and the data-safety form adds **Photos and videos → Photos**, collected only for a photo import, processed ephemerally.

## Phase 2c: Plan and shop (W8–W10, shipped as updates during the closed test)
- [x] **Meal plan** (PLAN-1–PLAN-4, PLAN-6; schema step 3; v0.8.0): a week view starting on the day from Settings; recipes or notes by day and meal (breakfast, lunch, dinner, snack), each with its own servings; move, copy, clear a week, and undo. "Add the week to groceries" (PLAN-5) ships with the grocery list.
- [x] **Ramadan mode** (RAM-1–RAM-5; v0.10.0):
  - Suhoor, iftar and snack slots on Ramadan days, with Hijri dates (Umm al-Qura, movable by a day).
  - A whole-month view for planning Ramadan; gatherings use each entry's servings.
  - Offered by a card 7 days before Ramadan, never switched on by itself.
  - No prayer or iftar times (they would need location).
- [x] **Groceries** (GRO-1–GRO-7, PLAN-5; schema step 4; v0.9.0):
  - Built from recipes and the plan, scaled as shown, with "add the week to groceries" (PLAN-5).
  - Merges the same item across recipes with unit maths.
  - 12 aisles that know Arabic ingredient names (at least 95% of the test fixtures placed).
  - Share the list as text on WhatsApp.
- [x] **Share a recipe** (SHARE-1–SHARE-4; v0.11.0): as text, or as image pages sized for WhatsApp.
- [x] **Backup, restore, export** (BAK-1–BAK-10; v0.12.0): after the last schema step, so the format covers every table. A backup file with photos, merge or replace, a monthly reminder, Android's device backup without photos, and a text export.

## Phase 3: Store readiness (alongside 2c)
- [x] Display name "وصفاتي" (Arabic) and "Wasfati" (English) on every platform: launcher label, bundle names (LOOK-9).
- [x] Launcher icons and splash screen, generated from one committed source (LOOK-9).
- [x] **Two looks** (LOOK-1–LOOK-9, Decision 14; `/spec look` first): "حبر / Ink" and "زعفران / Saffron", each with its own light and dark, picked in Settings and carried in backups. Replaces today's stock Material look. Specified in `docs/research/design-styles.md`; about 1,300–2,000 lines per style, no new packages or fonts.
- [x] Store IDs, permanent after the first upload and free of personal names: `com.oasisforge.wasfati`. Checked 24 September 2026, the same everywhere: Android's `applicationId` and `namespace` (`android/app/build.gradle.kts`), the Kotlin package and its path (`android/app/src/main/kotlin/com/oasisforge/wasfati/MainActivity.kt`), the iOS bundle ID in all three build configurations (`ios/Runner.xcodeproj`; its test target is `com.oasisforge.wasfati.RunnerTests`), and the release workflow's `PACKAGE_NAME`. The built APK reports `package: com.oasisforge.wasfati`. It becomes permanent at the first Play upload (Phase 5).
- [x] Privacy policy published, and updated for every feature that touches user data: live at https://oasis-forge.github.io/wasfati/privacy-policy (GitHub Pages, from `main`'s `docs/`). Checked 24 September 2026: the live page is byte for byte `docs/privacy-policy.html` on `main`. Its "Importing with AI" section names Anthropic's Claude, it's effective 24 September 2026, and the only "no server" left is website import's own ("no server of ours is involved"), which is true for that path. The photo-import and "Report a mistake" paragraphs from `feat/phase-2b` aren't on `main` yet, so they go live when that work merges; check the page again then.
- [x] The release build declares only the permissions the store listing admits to; the release workflow dumps the built artifact's permissions and fails on any it doesn't expect (RUN-2). Write the list against a real build, not from memory, and check both directions: a permission the app needs and lost is as much a bug as one a plugin added. Checked 24 September 2026 against a real `flutter build apk --release` (0.16.0+24) with `aapt2 dump permissions`: INTERNET, POST_NOTIFICATIONS and VIBRATE, plus the app's own signature-level `com.oasisforge.wasfati.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` from AndroidX, which the check skips. Nothing extra and nothing missing, so the allowed list is unchanged. Photo import's `image_picker` added no permission (only its file provider and the photo-picker backport's disabled service): no CAMERA, READ_MEDIA_IMAGES or READ_EXTERNAL_STORAGE. "Report a mistake" doesn't use `url_launcher`: it's an `ACTION_SENDTO` `mailto:` intent in `MainActivity.kt`, which needs no permission and no `<queries>` entry. The workflow now fails both ways: a permission outside the list, or one on it that the build lost. Ads add ACCESS_NETWORK_STATE and AD_ID, and purchases add BILLING (Roadmap impact in `docs/PRODUCT_RULES.md`). No camera permission: photos come through the system camera and picker.

## Phase 4: Before release (W11)
- [x] **Languages** (LANG-1–LANG-6): Arabic and English complete; every screen driven in Arabic at 1.3× text size. Shipped:
  - LANG-2: prep and cook time are one message each ("Prep {time}"), not a label joined to a value. `test/l10n/messages_test.dart` fails on a message missing from either file, mismatched placeholders, English left in the Arabic file (brand names aside), or a screen or widget writing its own words.
  - LANG-3: no number is baked into a message any more. Validation limits, the time filter, the editor's hint, and English's "one" cases take the number in the user's digits. Arabic digits use the Arabic decimal mark (١٫٥). The plan shows ×½ and ×٢, never ×1/2. Store prices, text-field counters and the editor's own numbers follow the digit setting.
  - LANG-4: search also ignores Latin accents, the Turkish dotted and dotless i, the Persian keyboard's ی and ک, Quranic marks, and the digit style. This sits on top of ORG-4's hamza, taa marbuta, alef maqsura and tashkeel. Stored keys (groceries, tags) are unchanged.
  - LANG-5: the plan's week arrows were mirrored twice and pointed inward in Arabic; they now point outward. Cook mode's ingredients icon and the plan's move icon have right-to-left versions. ×2 and "30–60" stay left to right inside Arabic text, and a plan entry's "٦ حصص" is no longer forced left to right.
  - LANG-6: `test/widget/looks_test.dart` covers every screen at 1.3× text on a 360 dp phone, in both languages and both digit styles:
    - library, cookbooks, both a right-to-left and a left-to-right recipe, every cook-mode page and its ingredients sheet, the editor, the plan and groceries with rows, and import
    - all of Settings, the purchase screen in three states, and the replayed walkthrough (setup and a first walkthrough are in `first_run_test.dart`)
  - It caught a plan entry row overflowing in English: the amount now drops under the title when the two don't fit.
  - Driven in widget tests only so far. The by-hand pass on the emulator at 1.3× text comes with this branch's `/ship`.
- [ ] **Ads, Pro and Premium** (ADS-1–ADS-9, PAY-1–PAY-11; Decisions 1, 10–12):
  - One banner unit on the library, the recipe page, the plan and groceries; never in cook mode, the editor or the import preview. The IDs are in `docs/RELEASING.md` (ADS-8).
  - Pro (`pro`, AED 14.99 one-time) removes ads.
  - Premium (`premium`, AED 9.99 a month or AED 79.99 a year) removes ads and raises AI imports to 100 a month. No trial (Decision 11).
  - The purchase screen has a close button from the first frame, and no crossed-out prices or countdowns (PAY-10).
  - Cancelling is two taps from Settings (PAY-11).
  - It rewrites the privacy policy, the data-safety form and the store listing in the same release (ADS-6).
- [x] **Review prompt** (RUN-5): only after a saved import **and** a recipe marked as cooked, at most once every 120 days, never during setup. `in_app_review` behind `StoreReview`; asked when cook mode closes from its last page, by "Done" or by "Mark as cooked" (which closes it too); a saved import is a live recipe that isn't written by hand.
- [x] **First-run setup and walkthrough** (RUN-3, RUN-4): last. Language and digit style, then up to four pages. No profiling questions. `AppSettings.firstRunComplete`; schema step 7 marks an upgraded install complete; the digits are preselected from the device locale's own numbers (only Egyptian Arabic writes ١٢٣); the sample (RUN-6) is added when setup ends, in the language chosen there; the walkthrough replays from Settings.

## Redesign: سُفرة / Sufra (before Phase 5; added 26 September 2026, Decision 23)
The same features in a new design and layout (LOOK-1–LOOK-14). Five PRs, each based on `main` and merged in order; each one carries the ones before it until they're merged. The mockups are in `docs/design/sufra/`.
- [x] **Foundation and navigation** (LOOK-1–LOOK-8, LOOK-10): tokens for both accents in light and dark; a new contrast test; the shared components (pill buttons, round icon buttons, cards, the segmented control, the stepper, the drawn cover); the floating navigation pill with الإعدادات in it and the centre "+" with its add sheet (LOOK-11); the banner slot above it. Every screen takes the new palette and shapes at once; the layouts follow area by area. زعفران becomes the default for new installs.
- [ ] **Library and adding** (LOOK-12, ORG-3–ORG-6, IMP-1–IMP-5): the library home and cookbooks; the import screens, preview and editor in the new style.
- [ ] **Recipe page and cook mode** (LOOK-13, LOOK-14, COOK-1–COOK-6, SCALE-6, IMP-14): the hero and sheet, the fact tiles, the Ingredients and Steps tabs, the action bar; cook mode; the translate flow and shared recipe images (SHARE-3) in the new palette.
- [ ] **Plan and groceries** (PLAN-1–PLAN-5, RAM-1–RAM-4, GRO-1–GRO-6): the week strip and a day's timeline; the Ramadan view; the grocery progress card and aisle cards.
- [ ] **Settings, first run and purchase** (RUN-3, RUN-4, PAY-6, PAY-10, PAY-11, ADS-5): settings as grouped rows opening pickers; setup and the walkthrough; the purchase screen; the Ink and Saffron-only widgets retired.

## Phase 5: Google Play
- [ ] Finish the Android one-time setup in `docs/RELEASING.md`: signing, contact details (oasisforge.support@gmail.com), payments profile, secrets.
- [ ] **Premium on the import server** (SRV-4, PAY-7, PAY-11; Decision 22), before Premium is offered to anyone, licence testers included: link a Google service account to the Play Console project; the Worker (`Oasis-Forge/wasfati-import`) verifies a Premium purchase token with Google Play's own record and allows 100 AI imports a month for it, 10 otherwise; the app sends the token with each AI import and translation; and Settings' Subscription row shows the renewal date from that record. Create the products first (`docs/RELEASING.md`, Android step 10).
- [ ] Internal testing from a release, including Pro and Premium bought by licence testers.
- [ ] **Closed test from W8 (16 November 2026):** at least 12 testers for 14 days before production access; start with the 2a+2b build. Recruit Arabic-speaking testers in W6.
- [ ] Store listing in Arabic and English from `store/play/` (text, screenshots, feature graphic, icon), privacy policy URL, data-safety form, and `app-ads.txt` in `Oasis-Forge/oasis-forge.github.io`.
- [ ] EU trader status, then apply for production (W12) and roll out (target: live by 3 January 2027).

## Phase 6: Apple (after v1 on Play)
- [ ] iOS: TestFlight from a release, App Store privacy labels, listings in Arabic and English, then App Review.

## After v1
- Apply for Meta's official Instagram oEmbed API (Decision 8). If it returns captions, a shared Instagram link imports directly.
- Accounts and cloud sync across devices (only if users ask).
- Nutrition estimates tuned for Arab dishes (Premium).
- Links to Gulf grocery delivery apps.
- A Discover feed of popular Arabic recipes.
- Import from other recipe apps (ReciMe, Paprika exports).
- iOS.

## Known bugs
<!-- Found and not fixed yet: what, where, and the rule it breaks. -->
