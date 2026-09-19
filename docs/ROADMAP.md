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
| W8–W10 | 16 Nov–6 Dec | 2c | Meal plan, groceries, Ramadan mode, backup, trash |
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
- [ ] The release workflow runs once by hand without secrets (unsigned artifacts, nothing published)
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
- [ ] **`/spec` round 2** (by W7): **PLAN** meal plan, **GRO** groceries and aisles, **RAM** Ramadan mode, and the final **PAY** quotas and tiers.
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
- [ ] Inject the storage layer and every device service into the state layer, so tests use an in-memory database and no-op fakes (sqflite + provider, per `docs/STACK_NOTES.md`).
- [ ] Migration scaffold: an ordered list of schema steps run on upgrade, with a test that upgrades the oldest schema.
- [ ] Reliable writes: write first, then change state; on failure roll back and show an error.
- [ ] Localization scaffolding with **Arabic as the first language and English second**. Every UI string lives in the ARB files, and right-to-left is the default layout (LANG-1–LANG-6).
- [ ] Schema step: record rules on every table: UUIDs, timestamps, soft delete (REC-1, REC-2, DEL-1).
- [ ] Schema step, recipes (REC-3–REC-9, ORG-1, ORG-2, and the install ID from SRV-4):
  - A recipe: title, photo, source URL and type, prep and cook time, servings.
  - Ingredient **groups** ("for the sauce").
  - Ingredient lines, each with an amount (a number or a range), a unit ID, a name, a note and the **original text**.
  - Steps as an ordered list.
  - Cookbooks, tags, notes, and a "cooked" count.
- [ ] **Quantity parser and formatter** (QTY-1–QTY-8; prototype from S1 already in `lib/models/quantity/`, with its table) and Arabic search normalization (ORG-4), as pure Dart with a test table built from the S1 fixtures:
  - Parses Western and Eastern Arabic digits, fractions, ranges, and Arabic and metric/US units.
  - Displays in the user's digit style.
  - Rounds countable items (حبة، فص، بيضة) sensibly.
  - Shows fractions, not 0.5.
- [ ] Tests: model round-trip, each migration step, the parser and scaler tables, widget tests for the main flows in right-to-left and left-to-right.
- [x] Platform decision: Android on Google Play in v1, iOS after, no desktop (19 September 2026, PRODUCT_RULES Decision 3).

## Phase 2a: Offline core (W3–W5)
- [ ] **Settings:** language (system / العربية / English), digit style (Western 123 by default, Arabic ١٢٣; QTY-5, Decision 5), units (metric / cups and spoons), week start (default by locale: Saturday in the Gulf), theme.
- [ ] **Recipes and cookbooks** (REC-3–REC-11, ORG-1, ORG-2, ORG-7):
  - Write a recipe by hand, edit it, add a photo from the picker.
  - Cookbooks and tags.
  - Grid or list view.
- [ ] **Find** (ORG-3–ORG-6): search by title **and ingredient** (it ignores Arabic diacritics and hamza/taa-marbuta variants, LANG-4); sort by recently added, A–Z, most cooked; filter by cookbook, tag and time.
- [ ] **Cook mode, free** (COOK-1–COOK-6; timers notify in the background, Decision 6): screen stays on, one step at a time in large text, step timers found in the text ("لمدة 15 دقيقة"), ingredient checklist, swipe between steps in right-to-left.
- [ ] **Scaling and conversion, free** (SCALE-1–SCALE-6):
  - Servings −/+ and ×½ / ×2.
  - Conversion between cups and spoons and grams/ml, where a density is known.
  - Scaling never silently skips a line: a line it can't scale is flagged.
- [ ] **Website import on the device** (IMP-2, IMP-5, IMP-6, IMP-9): paste or share a link → read the schema.org recipe → preview → save. Free and unlimited. A site without recipe data offers AI import instead (Phase 2b).
- [ ] **Delete, undo, trash** (DEL-1, DEL-2)
- [ ] **First run:** empty states with one clear first action, and one built-in sample recipe (RUN-1)

## Phase 2b: AI import (W6–W7)
- [ ] **Import server** (SRV-1–SRV-9):
  - Deploy the proxy from S3.
  - It turns a link, caption or image into the REC structure (structured output).
  - It keeps nothing it receives, and caches results by public post URL.
  - Rate limit per device, Play Integrity check, a monthly spending cap and alerts.
  - A test suite with the S1 and S3 fixtures that fails on regressions.
- [ ] **Share-sheet import** (IMP-1, IMP-3–IMP-9): TikTok, Instagram, YouTube and Facebook share into Wasfati → progress → **preview to edit before saving** → save. "Report a mistake" sends only the source link and the user's note, and only when they tap it.
- [ ] **Instagram fallback** (IMP-12, Decision 8): when a caption can't be read, offer paste or screenshot.
- [ ] **Emulator check of real share payloads** (S4 follow-up): what TikTok, Instagram, YouTube and Facebook put in a share (link only, or caption too). The user logs in to each app on the emulator. If Instagram includes the caption, IMP-12 becomes a rare path.
- [ ] **Photo import** (IMP-1, IMP-10): a cookbook page or handwritten recipe, from the camera or picker → server vision → preview.
- [ ] **Free AI-import quota** (IMP-7, SRV-4; 10 a month, Decision 4): a counter visible in the header, the reset date shown, and an import only counts when saved.
- [ ] **Network permission and privacy:** the first release with the server rewrites the privacy policy and the data-safety form in the same PR.

## Phase 2c: Plan and shop (W8–W10, shipped as updates during the closed test)
- [ ] **Meal plan** (PLAN-*): a week view with the locale's week start; add by day and meal (breakfast, lunch, dinner, snack); add the whole week to groceries.
- [ ] **Ramadan mode** (RAM-*):
  - Suhoor and iftar slots instead of meals.
  - A 30-day plan with Hijri dates.
  - Portions for gatherings.
  - Turned on automatically near Ramadan, and able to be switched off.
- [ ] **Groceries** (GRO-*):
  - Built from recipes and the plan.
  - Merges the same item across recipes with unit maths.
  - Aisles that know Arabic ingredient names.
  - Share the list as text on WhatsApp.
- [ ] **Share a recipe:** as an Arabic image card and as text (WhatsApp first).
- [ ] **Backup, restore, export** (BAK-1–BAK-5): after the last schema step, so the format covers every table.

## Phase 3: Store readiness (alongside 2c)
- [ ] Display name "وصفاتي" (Arabic) and "Wasfati" (English) on every platform: launcher label, bundle names.
- [ ] Launcher icons and splash screen, generated from one committed source.
- [ ] Store IDs, permanent after the first upload and free of personal names: `com.oasisforge.wasfati`.
- [ ] Privacy policy published, and updated for every feature that touches user data.
- [ ] The release build declares only the permissions the store listing admits to; the release workflow dumps the built artifact's permissions and fails on any it doesn't expect (RUN-2). Write the list against a real build, not from memory, and check both directions: a permission the app needs and lost is as much a bug as one a plugin added. Expected: INTERNET (the import server, ads), and camera only if the photo import uses it directly.

## Phase 4: Before release (W11)
- [ ] **Languages** (LANG-1–LANG-6): Arabic and English complete; every screen driven in Arabic at 1.3× text size.
- [ ] **Ads, Pro and Premium** (ADS-1–ADS-8, PAY-1–PAY-6; Decision 1):
  - Banners only on the library, grocery and plan screens; never in cook mode, the editor or the import preview.
  - Pro (one-time) removes ads.
  - Premium (subscription) gives AI imports beyond the quota, and nutrition later.
  - Every paywall has a visible close button.
  - The trial is reminded before it charges.
  - It rewrites the privacy policy, the data-safety form and the store listing in the same release (ADS-6).
- [ ] **Review prompt:** only after a successful import **and** a cooked recipe, never during setup.
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
