# Monetization Strategy Research

*Compiled 2026-07-29 — for an indie mobile roguelite card game (fantasy,
story-driven, 3–5 min runs, offline-first, Midjourney art, solo dev). iOS App
Store + Google Play.*

---

## 1. Monetization Models That Work in This Genre (2025–2026)

### 1a. Premium (paid upfront) — the genre's proven winner

The roguelite deckbuilder is arguably the *strongest* mobile genre for premium
pricing right now:

- **Balatro** ($9.99, no IAP, no ads): ~**$21.3M revenue and 3.1M downloads on
  mobile alone** per 2025 data (Pocket Tactics). Earlier milestones: **$500K in
  5 days**, **~$1M in the first week** (Mobilegamer.biz, PocketGamer.biz),
  $4.4M by the December 2024 Game Awards surge, ~$9M IAP revenue by January
  2025 (Statista).
- **Slay the Spire** ($9.99 iOS; as low as $6.99 in sales; on Apple Arcade
  since 2023): long-tail steady seller, consistently a top-paid card game.
- **Market context:** premium mobile releases were **up 77% in 2025 (~750
  titles)**, with Balatro, Slay the Spire, and Dead Cells cited as drivers;
  PC/console-to-mobile ports rose from 7 (2024) to 23 (2025) (GameDev.net,
  Sensor Tower State of Gaming).
- **Caveat:** premium is still a tiny slice of the ~$82B mobile games market
  (free games = ~96% of downloads, F2P ≈ 98% of revenue). Premium's discovery
  problem is real: without Balatro-level press/awards, a paid app by an unknown
  solo dev fights an uphill visibility battle. Typical indie premium mobile
  outcomes are 4–5 figures, not 7.

### 1b. Free + single unlock ("shareware") — the best fit for unknown indies

- **Night of the Full Moon:** free download with ~40–60% of content (4
  classes); paid DLC characters and story mode; everything ≈ **$10 à la carte
  or $8 complete edition**; no forced ads, no loot boxes. Widely praised as "a
  free-to-play game that would be worth paying for." It has sustained years of
  chart presence on this model — the strongest template match for *our* game
  (story chapters gate naturally).
- **Card Crawl / Tinytouchtales (Arnold Rauers):** classic shareware model —
  free portion, optional rewarded ads to sample locked content, **one durable
  IAP unlocks everything and removes ads**. Card Crawl earned **~€33K
  lifetime** for what was essentially a solo side project. Notably, for **Card
  Crawl 2** Rauers moved to fuller F2P because shareware revenue plateaus and
  doesn't fund 5+ years of live support — a signal that single-unlock caps your
  ceiling but is low-risk. **Card Crawl Adventure** used free + $1 character
  unlocks.
- **Phantom Rose 2 Sapphire** (solo dev, went F2P on mobile): occasional ads +
  IAP for currency/skins/permanent upgrades — reviewers flagged the "permanent
  upgrades for money" element as bordering on pay-to-win (TouchArcade).
- **Pirates Outlaws** ($0.99 + grindy currency IAP for characters/maps) shows
  the hybrid trap: paid entry *plus* store draws criticism for long grinds
  (148Apps).

### 1c. F2P with IAP / battle pass — works only at live-ops scale

- **Marvel Snap** is the genre's F2P benchmark: **$104M+ revenue / 22.7M
  downloads (~$6.78 per download)**, ~$10/month Season Pass as the backbone,
  cosmetics and card acquisition on top; **no ads, no loot-box gacha** (Udonis,
  Naavik). This requires a content team, server infrastructure, monthly
  seasons, and a major IP — not replicable by a solo dev at launch.
- Battle passes work for roguelite audiences *only* when cosmetic/content-based,
  and they demand a relentless content cadence (a new season every 4–8 weeks
  forever).

### 1d. Rewarded ads

- Viable as a *supplement* in free versions (Tinytouchtales model: watch an ad
  to try a locked class or get a run modifier). Players tolerate **opt-in
  rewarded video**; they punish interstitials and forced ads in reviews
  (AppFollow review mining, Android Police). For a niche genre audience with
  modest DAU, ad revenue will be small — a bridge, not a pillar.

---

## 2. What This Audience Tolerates vs. Hates

**Tolerated / appreciated** (from review mining and genre precedent):

- One-time payments; "pay once, own forever" is a selling point this audience
  actively seeks out
- Free demo → single unlock ("I got to try it, then happily paid")
- Paid DLC characters/story chapters at fair prices (Night of the Full Moon,
  Slay the Spire/Downfall pattern)
- Optional, opt-in rewarded ads with a permanent "remove ads" IAP
- Cosmetics (card backs, boards, character skins) that never touch balance

**Hated — active review-bombing / 1-star risk in this genre:**

- **Energy/stamina systems** — this audience plays runs back-to-back; capping
  runs is the single fastest way to tank a roguelite's rating. AppFollow's
  review analysis: energy systems "exist to create a pain point that IAP
  solves" and free players who hit walls "leave and write bad reviews"
- **Forced interstitial ads** mid-run or between runs
- **Pay-to-win**: buyable power (cards, relics, permanent stat boosts) — see
  Phantom Rose 2 and Pirates Outlaws criticism; this genre's core appeal is
  skill-based mastery, and paid power invalidates it
- **Gacha/loot boxes** — genre-culturally toxic (Marvel Snap explicitly avoids
  them and is praised for it) and a regulatory minefield (Section 4)
- **Bait-and-switch**: launching clean and adding aggressive monetization later
  is a classic review-bomb trigger

Rule of thumb: this is a Steam-adjacent audience playing on phones. Monetize
like an indie PC game, not like a Match-3.

---

## 3. Offline-First Constraints

| Mechanism | Works offline? | Notes |
|---|---|---|
| Paid upfront app | **Yes** | Store handles license; game runs fully offline after install. |
| One-time non-consumable IAP (full unlock, DLC, cosmetics) | **Yes (after purchase)** | Purchase moment needs connectivity, but StoreKit/Play Billing cache entitlements; restore/verification works locally thereafter. Best-in-class fit. |
| Consumable IAP (currency) | Mostly | Client-side balances work offline but invite save-editing piracy; fine for single-player. |
| Rewarded / interstitial ads | **No** | Ad SDKs require connectivity to fill; offline sessions = zero fill = broken reward loops. Also drag in privacy SDKs, ATT prompts, consent dialogs — pollutes an offline-first architecture. |
| Battle pass / seasons | **No (practically)** | Needs trusted server time, remote content config, and anti-clock-tampering. |
| Subscriptions | Partially | Renewal checks need periodic connectivity; awkward for offline-first. |
| PvP monetization (later) | No | Requires the online infrastructure you'd build for PvP anyway. |

**Implication:** an offline-first architecture *structurally selects* premium
and one-time IAPs. Ads and battle passes would force connectivity requirements
that contradict a core product promise ("play on the subway/plane") that is
itself a marketable feature for 3–5 minute runs.

---

## 4. Legal / Store Considerations

### Platform fees

- **Apple App Store Small Business Program:** 15% (instead of 30%) on all paid
  apps, IAP, and subscriptions for developers under **$1M/year proceeds**; must
  enroll as Account Holder; exceeding $1M mid-year moves subsequent sales to
  30%, with re-qualification possible the following year.
- **Google Play:** 15% on the **first $1M/year**, but you must **enroll and set
  up an Account Group in Play Console**; earnings above $1M in a year are
  charged 30% for the remainder.
- Net math at $9.99: you keep ~$8.49 per sale (minus taxes) under 15%. Also
  budget $99/yr Apple Developer + $25 one-time Google.

### Loot boxes / randomized paid content — avoid entirely

- **Belgium and the Netherlands:** paid loot boxes treated as illegal gambling
  — effectively banned.
- **EU Digital Fairness Act** (expected late 2025/2026): Parliament's IMCO
  committee has recommended prohibiting loot boxes, manipulative in-app
  currencies, and pay-to-win mechanics in games likely accessed by minors.
  Existing EU consumer-law interpretation already requires loot-box advertising
  and probability disclosure.
- **China:** pre-launch probability disclosure, public odds page, 90-day
  transaction logs. **South Korea:** mandatory odds disclosure regime.
- **Practical takeaway for a solo dev:** any *paid* randomized content (paid
  card packs, paid random skins) creates per-country compliance overhead and
  geo-blocking risk far exceeding its revenue. Randomness earned through
  *gameplay* (normal roguelite card draws/rewards) is fine everywhere. Keep
  money → deterministic content only.

### Midjourney commercial terms

- Paid subscribers (Basic/Standard/Pro/Mega) **own their outputs and may use
  them commercially**, including game assets. Free-tier images are **CC BY-NC
  (non-commercial)** — never ship them.
- If **gross annual revenue exceeds $1M**, you must be on a **Pro or Mega
  plan** for company ownership rights. Cheap insurance: generate on Pro if
  optimistic.
- **Copyright limits:** per the US Copyright Office's January 2025 report,
  purely AI-generated images are **not copyrightable** (human authorship
  required); only human contributions (selection, arrangement, edits, code,
  writing, game design) are protectable, and registrations must disclose
  appreciable AI material. Practical effect: competitors could legally reuse
  raw AI art; mitigate by human-editing key assets (touch-ups, compositing) and
  leaning on trademark for the game's name/logo (commission a human-made logo).
- **Store policies:** Google Play's AI-Generated Content policy (mid-2025)
  targets apps that *generate* AI content — a game *shipping* pre-made AI art
  is not in scope, but you remain responsible for the content (no
  IP-infringing lookalikes — avoid prompts that yield style-of-famous-IP
  results). Apple has no ban on AI-generated art in games; risk vectors are
  4.3 spam/asset-flip rejection (mitigated by polish and cohesive art
  direction). Reputational note: some players are hostile to AI art —
  cohesive, heavily curated/edited art direction matters more than hiding it.

---

## 5. Recommended Strategy

### Model: **Free download + generous demo + single "Full Game" unlock, with deterministic content DLC later.** (Night of the Full Moon template, tuned by Card Crawl's lessons.)

Why not pure premium: we lack Balatro's press machine; a paywall at install
kills discovery for an unknown title, and the story/chapter structure gives a
*natural* free-sample boundary. Why not F2P/battle pass: offline-first
architecture, solo-dev content bandwidth, and this audience's allergy to
live-ops monetization all rule it out at launch.

### Phase 1 — Launch (offline-first, single-player)

- **Free:** Chapter 1 of the story (~1.5–2 hrs, a full satisfying arc), 2 of
  4–5 characters, endless/daily-run mode with the free characters. No ads at
  all — "no ads, ever" is a marketing line and keeps the binary lean and
  offline-pure.
- **One IAP: "Unlock Full Game" — $6.99** (non-consumable; restorable; works
  offline after purchase). All chapters, all launch characters, all difficulty
  ascensions. Undercuts Balatro/StS ($9.99); above the $2.99 junk tier to
  signal quality. Run occasional $4.99 sales.
- Optional at launch: one **$2.99 "Supporter Pack"** of cosmetic card
  backs/boards (pure margin, zero balance impact).
- Enroll in **both** 15% small-business programs before launch. Ship with
  Midjourney **paid-plan** art, human-edited; human-made logo/wordmark;
  trademark the name if budget allows.
- **Avoid:** energy systems, interstitials, any paid randomness, launch-day
  battle pass, timers.

### Phase 2 — Post-launch (months 3–18)

- **Deterministic DLC:** new character class + story chapter bundles at
  **$2.99–3.99 each**, plus a **"Complete Edition" bundle** IAP that always
  prices everything at ~15% off à la carte (~$12.99 total ceiling).
- Free content updates between paid drops (new cards/relics/events) to sustain
  reviews and store featuring — free updates are the marketing budget.
- More cosmetic packs ($1.99–2.99). Still no ads. *Only if* conversion on the
  unlock is poor (<1.5–2% of installs), test a rewarded-ad layer for free users
  only ("watch an ad to play a locked character today"),
  Tinytouchtales-style, with the full unlock removing ads forever — fallback,
  not plan.
- Consider a **premium PC/Steam release at $9.99–12.99** — this genre's
  audience lives there, and Steam wishlists feed mobile installs.

### Phase 3 — Multiplayer / live era (if PvP ships)

- PvP requires servers → connectivity is now legitimate for that mode only;
  keep single-player offline.
- Add a **cosmetic-and-content Season Pass at $4.99–7.99 per ~2-month season**
  (Marvel Snap charges ~$10/month but ships a new meta card monthly with a full
  team — scale to our cadence). Rewards: cosmetics, emotes, profile flair, and
  *early access* (not exclusivity) to characters that later join the paid
  catalog.
- All gameplay content must remain earnable or buyable **directly and
  deterministically** — no paid packs/gacha (keeps us clean in Belgium/NL and
  future-proof for the Digital Fairness Act, and keeps the community on side).
- Never retro-monetize the single-player campaign — that's the bait-and-switch
  review-bomb scenario.

### Revenue expectations (be sober)

Realistic solo-indie outcomes on this model: low-four to five figures in year
one without press; the Night of the Full Moon path (long tail, steady chapter
DLC, years of chart presence) is the success case; €33K lifetime (Card Crawl)
is a *good* shareware outcome; Balatro's $21M is a lottery ticket, not a plan.
The single-unlock model maximizes rating (drives organic installs), minimizes
legal surface area, matches offline-first architecture exactly, and leaves
every door (DLC, Steam, seasons) open.

---

## Sources

Pocket Tactics, PocketGamer.biz, Mobilegamer.biz, Statista (Balatro revenue);
GameDev.net / Sensor Tower (premium market 2025); Indie Bandits & Steam
community (Night of the Full Moon); Tinytouchtales (Card Crawl figures);
Android Police (Card Crawl Adventure, ads); TouchArcade (Phantom Rose 2);
148Apps (Pirates Outlaws); Udonis & Naavik (Marvel Snap); AppFollow
(review-mining, monetization playbook); RevenueCat & Qonversion & SplitMetrics
& Appbot (store fee programs); Promise Legal, Esports Legal News, Franssen
Tolboom, Wikipedia (loot box law, Digital Fairness Act); Midjourney ToS,
Terms.Law (commercial use); Jones Day & Skadden (US Copyright Office 2025
report); AppsOnAir & AppitVentures (store AI policies); Choost Games (no-MTX
audience); Sportskeeda (StS Apple Arcade).
