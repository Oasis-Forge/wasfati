# Competitor analysis: "ReciMe: Recipes & Meal Planner" (Android)

_Researched 19 September 2026. App: `com.recime.app`, version 5.1.0, installed from Google Play (UAE storefront) on an emulator._

**How:**
- Read the Play listing, its data-safety summary and the three reviews Play shows first.
- Installed the app and used it with made-up data, without an account. The onboarding ran twice, because the emulator restarted mid-run.
- Imported two Arabic recipes:
  - a web page: Fatafeat's lamb kabsa, `fatafeat.com/recipe/1632`
  - a YouTube Short: Fatafeat's lamb kabsa, shared into the app the way the YouTube app would
- Tried scaling, the grocery list, the meal plan, Discover, the paywalls and every Settings screen.
- Nothing was bought and no trial was started.

Everything below is in our own words; nothing from the app (assets, text, code) was copied.

**Not explored:**
- Import from a photo or from pasted text.
- The TikTok, Instagram and Pinterest apps themselves (not installed; the share path was tested with YouTube).
- Anything behind Plus: how well conversion, nutrition, cook mode, "Ask ReciMe" and PDF export work.
- Account sign-up and sync, and the cancel flow of a real subscription.
- Searching saved recipes by ingredient (Arabic text can't be typed on the emulator).

## Store snapshot

| | ReciMe |
|---|---|
| Rating | 4.7 from about 103K reviews |
| Installs | 1M+ (the app claims 15M+ cooks across platforms) |
| Chart | #1 top grossing in Food & Drink |
| Download size | 57 MB |
| Business model | Free tier with an import quota + ReciMe Plus subscription |
| Data safety | Collects personal info, photos and videos, and 3 other types; says nothing is shared with third parties; encrypted in transit; deletion on request |

## Price (seen in the app, UAE)

| Plan | Price | Trial |
|---|---|---|
| Plus yearly | AED 114.99 a year (shown as AED 9.58 a month, next to a crossed-out AED 229.98) | 7 days. The paywall shows a timeline: reminder notification on day 5, charge on day 7, with the date |
| Plus monthly | AED 18.99 a month | None |
| Lifetime / one-time | Not offered | — |

**Free tier:**
- **5 imports**, with a counter always in the header ("5 left").
- Social, photo, web and text imports all count. Writing a recipe by hand is free.
- An import only counts once it's saved.
- The quota "resets on September 27", 8 days after install.

**Plus-only:**
- unlimited imports
- unit conversion
- nutrition
- **step-by-step cook mode**
- "Ask ReciMe" (AI)
- PDF export
- search by creator

## At a glance

| Area | ReciMe (observed) | Wasfati today | Our plan |
|---|---|---|---|
| First run | About 20 screens before the app: 8 profiling questions, a notification pitch, a video tutorial, a fake "setting up" screen, a **Play review request before any use**, a paywall with no close button, then an account screen | Nothing built | Language and one sample recipe, then the app. No review request until after a successful import and cook. Every paywall has a visible close |
| Account / sign-in | Optional (Google, email, or Skip), but a guest profile is created anyway and Settings keeps nagging to create an account "so recipes are never lost" | Nothing built | No account in v1. Recipes live on the device; backup to a file |
| Ads & tracking | No ads seen; subscription-funded | Nothing built | Banners outside the cooking flow (ADS-1), UMP consent; Pro removes them |
| Price | AED 114.99/yr or AED 18.99/mo; 5 imports free before the first reset | Nothing built | A one-time Pro for no ads, plus a cheaper Premium subscription only for what costs us per use (AI imports beyond the free quota, nutrition). Cook mode, scaling and conversion are free forever |
| Import from social | Share from social apps, with a preview before saving (edit, cookbook, report mistake) in about 25 s; worked on an Arabic YouTube Short | Nothing built | Same share-sheet flow and preview, tuned for Arabic (see weak spots 1–3) |
| Import from web | In-app browser with Google search and an "Import to ReciMe" button; costs an import | Nothing built | Websites with recipe data (schema.org) parsed on the device, **free and unlimited** |
| Organize | Cookbooks, tags, search, sort A–Z or recently added, grid or list | Nothing built | The same, plus search by ingredient |
| Cooking | Servings −/+ scaling (free); conversion, cook mode and nutrition are paid | Nothing built | Free cook mode with the screen on, and scaling that understands Arabic units and digits |
| Planning & shopping | Weekly plan (Mon–Sun by default, configurable) by date and meal type; grocery list with aisle sort; "Order online" offers only Instacart, Walmart and Kroger in the UAE | Nothing built | Week starting Saturday or Sunday by locale; **Ramadan mode** (suhoor/iftar); aisles that know Arabic ingredients; Gulf delivery links later |
| Discover | English creator recipes; "kabsa" finds 2 English recipes | Nothing built | Not in v1 |
| Languages | English UI only; "auto-translate imports" into English, Spanish, German, French or Portuguese — no Arabic | Nothing built | Arabic first with a full right-to-left layout, English second |

## What they do well (worth matching)
- **Share-to-import with a preview:** one share, about 25 seconds, and a clean preview to edit or report before it's saved. It worked on an Arabic Short with no setup.
- **The quota is honest about itself:** the header counter, "writing is free", the reset date, and imports only counting once saved.
- **The trial timeline:** the paywall shows day 5 (reminder) and day 7 (charge, with the date). Monthly has no trial, so no surprise charge.
- **Sorting now exists:** A–Z and recently added. The review that asked for it is out of date.
- **Recipe → plan → groceries** in two taps, with a whole-week "Add to groceries".
- **Import feedback:** a rating sheet and "Report mistake" after import feed their extraction quality. This can be turned off in Preferences.

## Weak spots (our opening)
1. **Scaling is silently wrong with Eastern Arabic digits.** An imported recipe written with ١، ٢، ٣ changed from 5 to 10 servings, and **every quantity stayed the same**. Nothing warned the user. Western digits scale, but as decimals: "0.5 حبة كراث", "0.5 عود قرفة", "2.5 ملعقة كبيرة". No fractions, and countable items aren't rounded.
2. **Arabic units aren't understood:**
   - "1 كيلو جرام لحم ضأن" became the grocery item "جرام لحم ضأن" × 1, so the kilo was lost.
   - The abbreviation "١ ك" was kept as text.
   - A sub-recipe line (the dakous sauce: tomato, pepper, coriander…) stayed as one long ingredient.
   - The method came in as one paragraph instead of steps.
3. **No right-to-left layout:** Arabic lines are left-aligned in a left-to-right app, so the number sits visually at the *end* of the Arabic phrase. There's no Arabic UI and no Arabic translation.
4. **Groceries don't know Arabic:** all 22 Arabic items landed in "Uncategorized" in aisle view, and online ordering is US-only.
5. **Basics sit behind the paywall:** unit conversion, step-by-step cook mode and PDF export are Plus-only. Nutrition is paid too.
6. **A pushy first run:**
   - About 20 screens.
   - A Play review request before the app has been used at all.
   - A paywall whose only exit is the system Back gesture.
   - A guest profile made without asking.
   - An "account so recipes are never lost" nag.
7. **Price and trust:** AED 114.99 a year is framed against a crossed-out AED 229.98. The most-helpful Play review reports a trial cancellation that didn't go through and no way to get a refund (not verified in-app).
8. **Gulf defaults:** the week starts on Monday, there's nothing for Ramadan or Hijri dates, and there's no Gulf grocery store.

## Positioning
**"Arabic recipes that scale correctly, free to cook with":** save a recipe from TikTok, Instagram, YouTube or any Arabic site in one share. Wasfati understands Arabic units and digits and shows it right to left. Cook mode, scaling and conversion stay free; pay only to remove ads or for heavy AI importing.

## Roadmap impact
- **Phase 1 foundations (schema):**
  - Quantities stored as numbers with a unit ID and an original-text field.
  - A parser that reads Western and Eastern Arabic digits, fractions (½, 1/2) and Arabic unit words and abbreviations (كيلو، ك، جرام، كوب، ملعقة كبيرة/صغيرة، حبة، فص، عود، رشة، حزمة).
  - Test cases taken from both imports above.
  - Countable items round sensibly.
  - Ingredient groups ("for the sauce").
  - Steps stored as a list.
- **Phase 2 features, in order:**
  1. manual recipes and cookbooks
  2. search (ingredient too), sort and filter
  3. **free** cook mode and scaling
  4. on-device website import
  5. share-sheet AI import with a preview and "report mistake"
  6. photo import
  7. weekly plan (locale week start) and groceries with Arabic aisles
  8. Ramadan mode
- **Monetization:**
  - Show the quota counter and reset date the same honest way.
  - Keep the trial timeline idea.
  - Never gate cook mode, scaling or conversion.
  - A close button on every paywall.
  - Ask for a review only after value.
  - `/spec` sets the free AI-import quota and what Premium adds.
- **Deferred:** accounts and sync, nutrition, grocery delivery links, a Discover feed, iOS.
