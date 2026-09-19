# Technical constraints: W0 spikes

_19 September 2026._

Four spikes, each answering one question before Phase 1:
- **S1:** can we read Arabic quantities?
- **S2:** can website imports run on the device?
- **S3:** can a server get a post's caption, and what does an AI import cost?
- **S4:** can the app receive shares without Kotlin?

Raw notes, scripts and samples:
- S1: in this repo.
- S3: in the private `Oasis-Forge/wasfati-import` repo, under `spikes/`.
- S2 and S4: session notes.

## S1: Arabic quantity parser (QTY-1–QTY-8)

**Result:** it works as pure Dart. It lives in `lib/models/quantity/` (rational, units, parser, format), with an 80-row test table in `test/models/quantity/parser_test.dart`, and all rows pass.

The table holds every ingredient line from:
- both ReciMe tests (a web import and a YouTube Short)
- two Instagram captions and a TikTok caption (S3)
- five Arabic recipe websites (S2)

**What it handles:**
- **Digits and numbers:** Western, Eastern Arabic and Persian digits; ٫ as the decimal point; ½-style glyphs, including a glyph written before the whole number ("¼ 1" = 1¼); slash fractions; mixed numbers.
- **Number words:** واحد–عشرة، نصف، ربع، ثلث, and "ونصف / و نصف" added after a number or a unit.
- **Ranges:** 2-3، ٢–٣، 2 إلى 3، 2 أو 3.
- **Units:** longest match first, so "كيلو جرام" is one unit and "١ ك" is a kilo. Levantine spellings (معلقة) and abbreviations (م.ك، كغ، جم) are known.
- **Dual nouns mean two:** كوبين، حزمتين، فصّان، ملعقتين كبيرتين.
- **A singular unit word with no number means one** ("حبة بصل", "كوب جزر"). A plural one doesn't ("قطع الدجاج" stays a name). This became QTY-8.
- **Name before amount:** "زيت الزيتون 3 ملاعق كبيرة", "معكرونة 500 غراماً".
- **Brackets:** a bracketed equivalent ("(450 غرام)") is moved into the note.
- **To taste:** "حسب الذوق" and a bare "رشة" have no amount and are never scaled.
- **Display:** fractions (1½, never 0.5), Arabic digits on request, and unit names that agree with the number (كوبان، أكواب، كوبًا). Parse → show → parse gives back the same amount (QTY-4).
- **Scaling (SCALE-3):** Eastern-digit lines scale correctly. ReciMe left them unchanged.

**Known limits, not blockers:**
- A size word after the unit stays in the name ("حزمة **صغيرة** بقدونس").
- Two ingredients run together in one line aren't split ("الذرة مذوب بربع كوب ماء ملعقة كبيرة نشاء").
- Typos ("حص ثوم") stay as names.
- A trailing unit without a number ("فلفل أسود رشّة") stays in the name.

For each new case: add a row first, then fix it (QTY-7).

## S2: website import on the device (IMP-2)

**Result:** 5 of 8 popular Arabic recipe sites (62%) publish usable schema.org `Recipe` JSON-LD, and none blocked a normal mobile browser request.

| Site | Recipe data | Ingredients | Instructions |
|---|---|---|---|
| fatafeat.com | JSON-LD | 27 clean lines | 2 `HowToStep`; step 1 joins about 6 actions with " , " |
| cookpad.com/sa | JSON-LD | 14 lines; some have no amount | 14 clean `HowToStep` |
| kitchen.sayidaty.net | JSON-LD, with nutrition | 11 clean lines | **one string**, `\r\n`-separated |
| atyabtabkha.com | JSON-LD, with nutrition | Word order is sometimes prep note → amount → name | 11 clean `HowToStep` |
| supermama.me | JSON-LD | 8 lines; "¼ 1 كوب" glyph order | a list of strings |
| zahratalkhaleej.ae | none (article only) | — | AI fallback |
| mawdoo3.com | microdata for SEO only; no ingredients | — | AI fallback |
| sotor.com | none | — | AI fallback |

**What this means for the build:**
- Find the JSON-LD with a **real HTML parser**, not a regex: supermama writes `type=application/ld+json` without quotes. The recipe can also sit inside `@graph` or a list.
- Accept every instruction shape: a single string (split on line breaks), a list of strings, `HowToStep`, or `HowToSection` (becomes a step group, REC-6).
- IMP-6's splitting of long steps is needed even for structured sites (fatafeat).
- Every ingredient line goes through the S1 parser. All 28 lines S2 collected are in the S1 table.
- About 40% of pages need the AI fallback, so the "use AI import instead" path (IMP-3) is a main path, not an edge case.

## S3: fetching captions, and what an import costs (SRV-2, SRV-1)

**S3a, fetching captions** (from a home connection; `spikes/s3-fetch.mjs`):

| Platform | How | Caption returned |
|---|---|---|
| TikTok | Official public oEmbed endpoint (`tiktok.com/oembed?url=`) | **Full caption** (672 and 862 characters, including the ingredient lists) in about 0.3 s |
| YouTube | The public watch page's embedded `shortDescription` | **Full description** (1,029 and 1,543 characters) in about 1–2 s. oEmbed gives only the title |
| Instagram | Logged-out page | **Nothing** with a normal browser request. The full caption (562 and 1,223 characters) appears only when the request claims to be Facebook's link-preview crawler |

**Risks and next steps:**
- **Instagram:** pretending to be another company's crawler is against Instagram's terms and could stop working at any time, so we shouldn't build on it. This is an open decision (see "Decisions needed").
- **Server IPs:** the results came from a home IP address. Cloudflare's data-centre addresses may be treated differently, so S3a must run again from a deployed Worker before Phase 2b.
- **Share contents (S4):** TikTok, Instagram and YouTube shares usually contain only the link, not the caption (not verified yet), so the server has to fetch the caption.

**S3b, cost and latency of a real import:**
- `spikes/s3-cost.mjs` is ready: Claude Haiku 4.5, structured output, the REC shape, on the 6 fetched captions.
- It **hasn't run yet**: it needs an Anthropic API key in the environment (not committed; see "Decisions needed").
- The estimate from 19 September was about $0.006 per caption import, about $0.06 per free user a month at the full quota (Decision 4). Replace it with measured numbers.
- The photo half (5 real recipe photos) still needs photos.

## S4: receiving shares without Kotlin (IMP-1)

**Result:** the `receive_sharing_intent` package (1.9.0, the most actively maintained) works with **manifest changes only**. `MainActivity.kt` stays as generated, so the Flutter-only rule holds.

**Setup:**
- On `MainActivity`, add intent filters for `SEND text/*`, `SEND image/*` and `SEND_MULTIPLE image/*`, and set `android:launchMode="singleTask"`.
- Read a share with `getInitialMedia()` on cold start and `getMediaStream()` while running, then call `reset()`.

**Traps:**
- Open issues report the same share arriving twice (#158) and an old share being delivered again after the system killed the app (#228). The import flow must ignore a share it has already handled; IMP-9's duplicate check plus a short-lived "last share handled" guard covers both.
- What TikTok, Instagram, YouTube and Facebook actually put in the share (link only, or caption plus link) isn't documented anywhere reliable. Verify it on the emulator when the share target is built.

**Short links to handle (IMP-9):**
- `vm.tiktok.com/…`
- `youtu.be/…?si=…`
- `instagram.com/reel/…?igsh=…`
- `fb.watch/…`, `facebook.com/share/r/…`

## Decisions needed
1. ~~**Instagram captions.**~~ Decided 19 September 2026 (Decision 8, IMP-12): share the link, then paste the caption or share a screenshot. The Meta oEmbed API comes after v1.
2. **API key for S3b.** Set `ANTHROPIC_API_KEY` in your environment (from console.anthropic.com), then run `npm run spike:cost` in `wasfati-import`. A few cents of usage.
