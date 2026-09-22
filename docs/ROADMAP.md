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
  - Rate limit per device, Play Integrity check, a monthly spending cap and alerts.
  - A test suite with the S1 and S3 fixtures that fails on regressions.
  - Check S3b's measured cost per import against Premium's price (PAY-8): a Premium user at the 300 fair-use cap must cost less than the monthly plan pays after the store's fee (about AED 8.49). If not, lower the cap (SRV-4) before launch.
- [ ] **Share-sheet import** (IMP-1, IMP-3–IMP-9): TikTok, Instagram, YouTube and Facebook share into Wasfati → progress → **preview to edit before saving** → save. "Report a mistake" sends only the source link and the user's note, and only when they tap it.
- [ ] **Instagram fallback** (IMP-12, Decision 8): when a caption can't be read, offer paste or screenshot.
- [ ] **Emulator check of real share payloads** (S4 follow-up): what TikTok, Instagram, YouTube and Facebook put in a share (link only, or caption too). The user logs in to each app on the emulator. If Instagram includes the caption, IMP-12 becomes a rare path.
- [ ] **Translate** (IMP-14–IMP-16, SRV-11, Decision 9): "ترجم إلى العربية" on a recipe in another language, and in the import preview, saves a linked copy and leaves the original alone. Amounts and units never go through the model. A schema step stores the link to the original.
- [ ] **Photo import** (IMP-1, IMP-10): a cookbook page or handwritten recipe, from the camera or picker → server vision → preview.
- [ ] **Free AI-import quota** (IMP-7, SRV-4; 10 a month, Decision 4): a counter visible in the header, the reset date shown, and an import only counts when saved.
- [ ] **Network permission and privacy:** the first release with the server rewrites the privacy policy and the data-safety form in the same PR.

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
- [ ] Display name "وصفاتي" (Arabic) and "Wasfati" (English) on every platform: launcher label, bundle names.
- [ ] Launcher icons and splash screen, generated from one committed source.
- [ ] **Two looks** (LOOK-*, Decision 14; `/spec look` first): "حبر / Ink" and "زعفران / Saffron", each with its own light and dark, picked in Settings and carried in backups. Replaces today's stock Material look. Specified in `docs/research/design-styles.md`; about 1,300–2,000 lines per style, no new packages or fonts.
- [ ] Store IDs, permanent after the first upload and free of personal names: `com.oasisforge.wasfati`.
- [ ] Privacy policy published, and updated for every feature that touches user data.
- [ ] The release build declares only the permissions the store listing admits to; the release workflow dumps the built artifact's permissions and fails on any it doesn't expect (RUN-2). Write the list against a real build, not from memory, and check both directions: a permission the app needs and lost is as much a bug as one a plugin added. Today: INTERNET, POST_NOTIFICATIONS and VIBRATE. Ads add ACCESS_NETWORK_STATE and AD_ID, and purchases add BILLING (Roadmap impact in `docs/PRODUCT_RULES.md`). No camera permission: photos come through the system camera and picker.

## Phase 4: Before release (W11)
- [ ] **Languages** (LANG-1–LANG-6): Arabic and English complete; every screen driven in Arabic at 1.3× text size.
- [ ] **Ads, Pro and Premium** (ADS-1–ADS-9, PAY-1–PAY-11; Decisions 1, 10–12):
  - One banner unit on the library, the recipe page, the plan and groceries; never in cook mode, the editor or the import preview. The IDs are in `docs/RELEASING.md` (ADS-8).
  - Pro (`pro`, AED 14.99 one-time) removes ads.
  - Premium (`premium`, AED 9.99 a month or AED 59.99 a year) removes ads and raises AI imports to 300 a month. No trial (Decision 11).
  - The purchase screen has a close button from the first frame, and no crossed-out prices or countdowns (PAY-10).
  - Cancelling is two taps from Settings (PAY-11).
  - It rewrites the privacy policy, the data-safety form and the store listing in the same release (ADS-6).
- [ ] **Review prompt** (RUN-5): only after a saved import **and** a recipe marked as cooked, at most once every 120 days, never during setup.
- [ ] **First-run setup and walkthrough** (RUN-3, RUN-4): last. Language and digit style, then up to four pages. No profiling questions.

## Phase 5: Google Play
- [ ] Finish the Android one-time setup in `docs/RELEASING.md`: signing, contact details (oasisforge.support@gmail.com), payments profile, secrets.
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
- With the language on "حسب الجهاز", a change of the phone's own language while Wasfati is open applies at the next launch, not at once (LANG-1): `lib/app.dart` resolves the locale when the settings change, not on the platform's locale change.
- Merging two phones that both edited the same recipe can mix its ingredient lines and steps from each side, because rows merge one by one instead of as one recipe (BAK-3). `lib/services/backup.dart`.
- A backup is built and read whole in memory, so a very large photo library could run out of memory (BAK-6). `lib/services/backup.dart`.
- The library's "بصورة" filter still lists a recipe whose photo file is missing after an Android device-backup restore (BAK-9, ORG-6). `lib/models/library.dart`.
- The backup flow's logic sits in the Settings screen rather than a state class (CLAUDE.md: screens stay presentational). `lib/screens/settings_screen.dart`.
- `Decor.cardShape`, `Decor.rowHairline` and `Decor.groupedRowFill` (LOOK-6) are built for both looks but read nowhere yet — no hand-built widget uses a grouped-row fill or hairline on the settings groups or the plan's day cards, or the hand-rolled card shape. `lib/widgets/digit_box.dart` (`DigitBox`, for the timer clock, the step numeral and a ×factor readout, LOOK-5) is likewise unused and untested outside its own widget test: `app_test.dart` and `groceries_test.dart` already match cook mode's/the plan's numbers by exact text, so wiring it in now would mean updating those matches too. Deferred rather than wired in or deleted (platform review, `feat/looks-and-branding`) — pick this up with its own screen-by-screen pass and a driven-by-hand check, not as a drive-by. `lib/theme/decor.dart`, `lib/theme/app_theme.dart`, `lib/widgets/digit_box.dart`.
