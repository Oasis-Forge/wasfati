# Competitor analysis: "ReciMe: Recipes & Meal Planner" (Android)

_Researched 19 September 2026. App: `com.recime.app`, listing last updated 19 September 2026 (version number not shown on the listing)._

**How:** read the Google Play listing (UAE storefront, English), its data-safety summary, and the three reviews Play shows first. Everything below is described in our own words; nothing from the app (assets, text, code) was copied.

**Not explored:** the app was not installed, so every feature below comes from the listing and is **not verified** hands-on. Not seen: the import accuracy on Arabic posts, the paywall screens and prices, the Discover feed, grocery ordering (likely unavailable in the Gulf), how nutrition is calculated, and whether any Arabic UI exists. Next step: install it on the emulator with made-up data and check the Arabic-import questions (capped run, see PLAYBOOK stage 2).

## Store snapshot

| | ReciMe |
|---|---|
| Rating | 4.7 from about 103K reviews |
| Installs | 1M+ (the listing claims 10M users across platforms) |
| Chart | #1 top grossing in Food & Drink |
| Business model | Free tier + auto-renewing subscription (monthly or yearly), 7-day free trial |
| Data safety | Collects personal info, photos and videos, and 3 other types; says nothing is shared with third parties; encrypted in transit; deletion on request |

## At a glance

| Area | ReciMe | Wasfati today | Our plan |
|---|---|---|---|
| Account / sign-in | Account with cloud sync; required for its multi-device model | Nothing built | No account in v1: recipes live on the device, backup to a file. Accounts and sync come later, only if users ask |
| Ads & tracking | No ads seen on the listing; subscription-funded | Nothing built | Ads outside the cooking flow (never in cook mode), UMP consent; Premium removes them |
| Price | Subscription after a 7-day trial; premium = unlimited social and photo imports, nutrition | Nothing built | Free: unlimited manual and website recipes + a monthly quota of AI imports. Premium: cheaper, local-currency pricing, cancel in two taps, reminder before any trial ends |
| Import from social media | Instagram, Facebook, TikTok, YouTube, Pinterest → ingredients and steps | Nothing built | Share sheet from TikTok, Instagram, YouTube → thin server proxy → AI extraction tuned for Arabic; always an editable review screen before saving; results cached per post URL |
| Import from websites / other apps / photos | Websites, other recipe apps and note apps, photo "smart importer" | Nothing built | Websites parsed on the device (schema.org Recipe), free. Photo import via cloud vision (on-device OCR has no Arabic) |
| Organize | Cookbooks, tags by meal, cuisine, diet | Nothing built | Cookbooks and tags **plus** the sorting and filtering users ask for: newest first, A–Z, search by ingredient |
| Cooking | Screen stays on, step by step, serving scaling, US ↔ metric | Nothing built | Same, with scaling that understands Arabic units (كوب، ملعقة كبيرة، رشة، حبة) and Eastern Arabic digits |
| Planning & shopping | Weekly plan (breakfast/lunch/dinner), grocery list by aisle or recipe, in-app grocery ordering | Nothing built | Weekly plan + **Ramadan mode** (suhoor/iftar, 30-day plan, Hijri dates); grocery list grouped by aisle; delivery links later |
| Nutrition | Calories and macros per recipe (premium) | Nothing built | Later phase; estimates tuned for Arab dishes that Western databases cover poorly |
| Sharing | Share a recipe by the usual apps (email, SMS, WhatsApp…) | Nothing built | WhatsApp-first: a recipe as an Arabic image card that brings people to the app |
| Languages | Listing and features are English-first; no Arabic seen | Nothing built | Arabic first with full right-to-left layout, English second |
| Platforms | Android, iOS, iPad | Nothing built | Android first; iOS later |

## What they do well (worth matching)
- **One place for every recipe source:** social posts, websites, other apps and photos all end up in one tidy format. This is the reason users pay.
- **A clean recipe format:** ingredients and steps separated and readable, whatever the source looked like.
- **The kitchen basics:** screen stays on while cooking, step-by-step mode, serving scaling and unit conversion.
- **Recipe → plan → shopping list:** the weekly plan feeds the grocery list, sorted by aisle, which turns a saved recipe into something the user actually cooks.
- **Cookbooks:** users like grouping recipes their own way.

## Weak spots (our opening)
1. **Trial billing trust:** the most-helpful review (about 1,460 people found it helpful) says a cancellation made two days before the trial ended didn't go through, the yearly fee was charged, and they couldn't find how to get a refund. A clear, honest subscription is an opening by itself.
2. **Price:** the same reviewer calls the yearly fee far too high. Gulf and wider Arab users will compare against a local price.
3. **Finding recipes again:** a 5-star-leaning reviewer asks for A–Z and newest-first sorting and search by ingredient, because recently added recipes are hard to find. Basic, and missing.
4. **Reliability of the account layer:** a recent review reports being logged out, slow recipe loading, the app not opening, and being unable to log back in. With no account in v1, we don't have this failure mode.
5. **No Arabic:** Arabic cooking content on TikTok, Instagram and YouTube is huge, but units, numerals, dialect ingredient names (طماطم / بندورة), family-size portions and Ramadan planning are not served by an English-first app. **Not verified:** how well its importer handles an Arabic post.
6. **Regional features:** grocery ordering is almost certainly not available in the Gulf (not verified), and there is nothing for Ramadan or Hijri dates.

## Positioning
**"Every recipe you save from TikTok and Instagram, in clean Arabic — no account, honest price":** save Arabic recipes from anywhere in one tap, cook them with Arabic units and a Ramadan planner, and never be surprised by a charge.

## Roadmap impact
- **Phase 1 foundations:** stored units and quantities as structured data from day one (Arabic unit names, fractions, Eastern Arabic digits), stable UUIDs on every record so sync can be added later, and the backup format.
- **Phase 2 features, in order:** manual recipes and cookbooks → sorting/filtering/ingredient search (weak spot 3) → cook mode and scaling → website import on the device → share-sheet AI import (needs the backend decision) → photo import → weekly plan and grocery list → Ramadan mode.
- **Monetization (Phase 3–4):** an honest Premium is a feature, not an afterthought: price in local currency, two-tap cancel, a reminder before any trial ends. Test every way the purchase flow can end.
- **New decision needed before Phase 2:** a thin server proxy for AI import (conflicts with the current "no backend" default). Rate limits, Play Integrity and a spending cap go with it.
- **Deferred:** accounts and cloud sync, nutrition, grocery delivery links, a Discover feed, iOS.
