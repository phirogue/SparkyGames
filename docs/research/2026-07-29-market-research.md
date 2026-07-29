# Mobile Roguelite / Deckbuilder Card Game Market Research

*Compiled 2026-07-29 — to inform design of a story-driven, fantasy,
3–5-minute-run, offline-first mobile card roguelite.*

---

## 1. Landscape: Successful Roguelite Card Games on Mobile (2023–2026)

### Tier 1: Premium ports of PC hits

| Game | Price (mobile) | Ratings | Notes |
|---|---|---|---|
| **Balatro** (2024) | $9.99 + Apple Arcade | Universally acclaimed; #1 top-selling paid game on both iOS and Android at launch | 2M+ units in <6 months across all platforms before mobile even shipped; called "one of the best mobile conversions in years." Landscape-only — a repeatedly cited flaw for phone play. |
| **Slay the Spire** (mobile) | $6.99 iOS / ~$9.99 Android; free on Apple Arcade | ~4.2/5 (2.6K iOS ratings) | The genre template (250+ playable cards). Complaints: tiny card text on phones, 30fps on iOS, an online "syncing" check that breaks offline play, lost saves on reinstall, first-tap input bug. Runs are 45–90 min — far too long for commute play. |
| **Monster Train** (2023 mobile) | $9.99 (later $7.99) | 86 Metascore PC; well-received port | Runs 45–60 min. Landscape, dense UI — praised for depth, not for phone ergonomics. |
| **Wildfrost** (2024 mobile) | ~$6.99 | Strong reviews; TouchArcade "superb, but not for everyone" | Fully portrait-optimized (rare and praised). ~30-min runs. Complaint: hand of cards becomes cramped/hard to select on phones. Notoriously difficult early on. |
| **Voice of Cards** trilogy (mobile 2023) | ~$17.99 each (Square Enix pricing) | Mixed-positive | Not a roguelite — a linear JRPG told entirely in cards with a voiced narrator. Criticized for online DRM check on a single-player mobile game. |

### Tier 2: Mobile-first / mobile-native successes

| Game | Price | Ratings | Notes |
|---|---|---|---|
| **Marvel Snap** (2022, F2P) | Free + IAP | 30M installs in 3 months; $116M mobile revenue year one; $275M+ by 2nd anniversary | The proof that 3–4-minute card sessions work at massive scale. Top-grossing digital TCG of 2023, beating MTG Arena and Yu-Gi-Oh. |
| **Night of the Full Moon** (2017, still updated) | $0.99 base + ~$1 chapter/class IAPs | Very high App Store rating (~4.8); 78% positive on Steam | Chinese-made Red Riding Hood roguelite; the standard-bearer for *story-driven* card roguelites. Now 10 classes, 700+ cards, 142 enemies, multiple endings driven by in-run choices. Criticism: too easy for genre veterans. |
| **Dawncaster** (2021, mobile-first) | $4.99 + optional expansion IAPs | **4.72/5 (iOS)**, 4.5/5 Google Play — among the best-rated in genre | Portrait, 60fps, battery-friendly, offline-friendly. 900–1,100+ cards after expansions (Synthesis +160 cards, Infernal Invasions +32). Story choices affect runs; some players find re-reading dialogue on replays tedious. |
| **Pirates Outlaws** (2019) | ~$0.99–$4.99 (cheap premium) | 4.5/5 (1,800+ iOS ratings); 63rd percentile OpenCritic | 16 heroes, 700+ cards, 200 relics. Praised: content volume, streamlined fast turns. |
| **Meteorfall: Journeys** (2018) | $2.99 | Beloved cult classic; Metacritic-positive | Swipe-based (Reigns-style) deckbuilder, one-thumb portrait play, 4 classes, hand-drawn cartoon art. Reviewers still preferred it to StS mobile for phone ergonomics. |
| **Card Crawl / Card Thief** (Tinytouchtales) | Free demo → ~$3 unlock | 4.46/5; **1.3M+ downloads**, still ~260/day years later | 2–3-minute solitaire dungeon runs from a 54-card deck. The archetype of the "micro-run" card game. |
| **Solitairica** (2016) | ~$4 iOS / free-to-try Android | Called "mobile roguelike card game perfection" by fans | Solitaire-RPG hybrid; runs in short encounter chunks. |

### Notable newer entrants (2024–2026)

- **Dungeon Clawler** (Stray Fawn, mobile Nov 2024, 1.0 April 2026):
  claw-machine roguelike deckbuilder, $4.99–$5.59, **4.84/5 from 17K ratings**,
  ~11K downloads/month — evidence that a novel "physical gimmick + deckbuilder"
  premise still breaks through.
- **Luck Be a Landlord** (mobile 2023): slot-machine roguelite, 94% positive
  (5.3K Steam reviews), premium, no MTX.
- **Breach Wanderers**: F2P deckbuilder, 600+ cards, ads removed via single
  $2.99 IAP — a hybrid model players tolerate well.
- **Vault of the Void** ($6.99): brilliant but criticized as "designed for
  iPad" — cramped phone UI.
- **Slay the Spire 2** (PC Early Access March 2026): 3M copies in week one,
  $108M+ on Steam — the genre's audience is still growing, and a mobile port is
  inevitable, which will reset the bar.

### Cross-cutting praise/complaint patterns

**Players praise:** premium/no-MTX pricing, portrait one-handed play, true
offline, fast turns, depth-per-minute, unlockable characters/classes.

**Players complain about:** landscape-only UIs, unreadable card text on phones,
online checks/DRM in single-player games, lost saves, runs too long to finish
in a sitting, story text you must re-click on every replay, difficulty spikes
(Wildfrost).

Market context: the roguelike market is estimated at ~$3.8B (2025) growing
~10.8% CAGR; mobile is sharply bifurcated between premium "player-respecting"
titles ($3–$10) and F2P. The "demo-to-premium" model (free download, one IAP
unlocks everything — Card Crawl, Slice & Dice, Solitairica, Breach Wanderers)
is repeatedly identified as the best of both worlds for indie card games on
mobile.

---

## 2. Short-Session Design: Who Actually Hits 3–5 Minutes, and How

Most classic deckbuilder roguelites do NOT hit 3–5 minutes: StS 45–90 min/run,
Monster Train 45–60, Wildfrost ~30, Balatro ~10–30. The games that genuinely
deliver complete 3–5-minute experiences use specific structures:

1. **Fixed turn count (Marvel Snap):** Every match is exactly 6 turns, ~3–4
   minutes. Analysts credit this "predetermined length" for the "one more
   match" loop and for multiplying daily open opportunities (lunch, bus, ad
   break). Simultaneous turn resolution removes waiting. A 12-card deck
   compresses deckbuilding itself into minutes, which drives long-term
   retention through constant experimentation.
2. **Single small deck as the level (Card Crawl):** One run = dealing through a
   fixed 54-card deck on a 2x2 grid; 2–3 minutes, fully self-contained,
   score-chased. The deck *is* the dungeon.
3. **Solitaire board-clear puzzles (Card Thief, Solitairica):** each encounter
   is a compact puzzle with a visible end state; sessions end when the
   board/deck is exhausted.
4. **One-lane, one-thumb combat (Meteorfall):** single enemy, swipe left/right
   decisions, no grid/targeting overhead — turns take seconds.
5. **Snap/retreat mechanics (Marvel Snap):** letting players concede cheaply
   (or double stakes) shortens dead games and keeps average session time low
   without frustration.

**Design levers that compress run time:** small deck (10–15 cards), fixed
encounter count per run (e.g., 3–5 fights), fixed turn caps per fight, single
lane / single enemy focus, simultaneous or low-latency turn resolution, no
map-walking between fights, meta-progression carried *between* runs rather than
inside long runs. Note the trade-off: Snap commentary emphasizes the design
compresses *decision density* rather than removing depth — "pressure over
duration."

Also important: a 3–5-minute-run game is structurally a "chained micro-run"
roguelite — think Card Crawl's scored runs or Night of the Full Moon's chapter
fights — not a miniaturized Slay the Spire. Nobody has successfully shrunk the
full StS act structure to 5 minutes; the successes changed the unit of play
instead.

---

## 3. Story-Driven Card Games: How Narrative Is Delivered and Received

- **Night of the Full Moon** is the best proof-of-concept for our exact
  concept: a fairy-tale (Red Riding Hood/Grimm) roguelite where "even the story
  itself is based on cards" — narrative choices appear *as encounter cards
  during the run*, endings differ by choices, and each purchasable class
  unlocks a different storyline perspective. Very highly rated; low-pressure
  monetization ($1 chapters). This is a mobile-native, portrait, offline,
  story-first card roguelite that has thrived for 8+ years.
- **Dawncaster** delivers story via quest-lines and in-run choice events that
  materially change the run; each campaign is a written adventure. Reception is
  strong (4.7/5) but with a documented caveat: **replayed story becomes
  click-through fatigue** — "if a game is meant to be replayed over and over,
  it needs to evolve the story somehow."
- **Voice of Cards** shows the ceiling and floor of narrative-forward card
  presentation: praised aesthetic and narration, but criticized as shallow
  ("barely shuffled the deck") — presentation alone doesn't carry it, and it
  isn't replayable.
- **Wildfrost** is the counter-example: lore-light by design; reviewers
  explicitly say "if you're looking for a deep storyline, go elsewhere." It
  succeeds on mechanics — showing story is optional but *differentiating* when
  present.
- **The Hades playbook** (the accepted best practice for roguelite narrative):
  make characters aware of the loop; deliver a new small story beat after
  *every* run, win or lose ("failure is progress"); use a hub between runs for
  relationship/dialogue progression; gate story on run outcomes so death
  advances the plot rather than repeating it. For a 3–5-minute-run game this is
  ideal: short runs = frequent story beats = high narrative cadence, as long as
  beats are short (1–3 lines/scene) and never repeat verbatim.

**Player-response summary:** roguelite audiences welcome narrative when (a)
it's skippable/fast, (b) it never repeats identically, and (c) it's tied to
progression (unlocks, endings, characters). They punish walls of static text on
replays and story that blocks the "one more run" loop.

---

## 4. Gaps and Opportunities

1. **The 3–5-minute *roguelite* run is nearly unoccupied.** Marvel Snap owns
   3-minute PvP; Card Crawl owns 2-minute solitaire; but there is no prominent
   *story-driven fantasy roguelite* with complete 3–5-minute runs. Everything
   with roguelite depth runs 30+ minutes; everything short is either
   PvP-live-service or narrative-free score-chasing.
2. **Portrait mode is explicitly underserved.** Late-2025 genre analysis calls
   portrait-mode demand a standing gap — Balatro's lack of portrait is its
   single most-cited mobile flaw. Portrait + one-thumb = commuter's game.
3. **True offline-first is a differentiator.** Repeated complaints about StS
   mobile and Voice of Cards center on online checks in single-player games.
   "Works on a plane, saves never lost" is a marketable feature.
4. **Story-rich is rare in the genre.** Only Night of the Full Moon and
   Dawncaster meaningfully combine roguelite cards + narrative, and both have
   known weaknesses (NotFM: too easy, dated presentation, chapter-IAP friction;
   Dawncaster: repeated-text fatigue, 30-min+ runs). A Hades-style drip-fed
   narrative in a card roguelite has not really been executed on mobile.
5. **Proven monetization slot:** demo-to-premium at $4–$7 (or $0.99 + $1–2
   story-chapter expansions à la NotFM) matches genre expectations, avoids
   F2P/PvP fairness problems ("card games and F2P monetization are historically
   incompatible" for competitive play), and leaves room for later cosmetic-only
   PvP.
6. **PvP later is viable:** Snap proves short-session card PvP works, but its
   economy problems suggest launching single-player premium and adding
   async/friend PvP later, never selling power.

**Verdict:** yes — a story-rich fantasy roguelite with complete 3–5-minute
runs, portrait, offline, premium-friendly pricing sits at the intersection of
three documented demands (short sessions, portrait/offline respect, narrative)
that no incumbent fully serves. The closest competitor is Night of the Full
Moon, which is 8 years old and beatable on difficulty depth, presentation, and
narrative cadence.

---

## 5. Art Requirements: Card Illustration Counts at Launch

| Game | Unique card/asset illustrations (approx.) | Style |
|---|---|---|
| Card Crawl | ~54 deck cards + 35 ability cards (~90 pieces) | Simple, stylized, single artist |
| Meteorfall | ~150 cards across 4 classes + enemies | Hand-drawn cartoon, single artist |
| Marvel Snap (launch) | ~150–170 cards (plus variants later) | High-end licensed art |
| Balatro | 150 jokers + 22 tarot + 11 planet + 32 vouchers + decks ≈ 220 pieces | Pixel art (cheap per piece) |
| Slay the Spire | ~250 playable cards + ~50 relics + enemies | Painterly thumbnails (small, low-detail) |
| Wildfrost | ~160-card pool (269 total incl. all types), 22 companions + enemies | Cute vector-ish 2D |
| Night of the Full Moon | 700+ cards, 142 enemies (grown over 8 years; launch was far smaller) | Storybook illustration |
| Pirates Outlaws / Dawncaster | 700–1,100 (accumulated via years of expansions) | Papercraft / painted |

**Practical takeaway:** shipped v1.0 scope for an indie in this genre clusters
around **100–250 unique card illustrations** plus **20–60 enemy/character
portraits**, **10–20 relic/item icons**, and **10–30 event/story scene
images**. The 700+ numbers are multi-year accumulations, not launch
requirements. Note that StS-style card art is tiny on screen (low detail
tolerance), while NotFM/Dawncaster-style storybook art does double duty as
narrative atmosphere — the latter suits a Midjourney pipeline well (consistent
stylized prompt set; card frames/UI done separately by hand for consistency).

---

## Implications for Our Game

1. **Structure the run like Snap/Card Crawl, not mini-StS:** ~10–15 card deck,
   3–5 encounters per run, hard turn caps or deck-exhaustion end conditions,
   single-lane combat, portrait, one thumb. Target decision density, not
   content volume, per run.
2. **Narrative cadence = Hades in card form:** every 3–5-minute run ends with a
   short story beat regardless of win/loss; quests/chapters advance across
   runs; choices appear *as cards in the run* (NotFM's signature trick). Never
   repeat text verbatim; keep beats to seconds, always skippable.
3. **Price/monetization:** free demo → single $4.99–$6.99 unlock, or $0.99 +
   ~$1–2 story-chapter/class expansions. No energy, no gacha, no forced ads.
   This is what the genre's audience rewards with 4.5+ ratings.
4. **Offline-first and save integrity are marketing features,** not just
   engineering choices — the biggest complaints against premium incumbents are
   online checks and lost saves.
5. **Ship PvP later, async and cosmetic-only,** leveraging the fixed-turn
   structure (fixed turns make async PvP trivially fair and fast).
6. **Art plan:** budget ~120–200 card illustrations, ~30–50 enemies, ~15–25
   event/story scenes, ~20 icons for launch — well within a Midjourney + human
   cleanup pipeline. Choose one strongly consistent storybook style (it doubles
   as narrative identity and differentiates from Balatro's pixel art and StS's
   thumbnails).
7. **Beatable benchmark:** Night of the Full Moon is the direct comp — match
   its story-in-cards structure, exceed it on difficulty options, run brevity,
   and presentation polish.

---

## Sources

TouchArcade (Balatro, Monster Train, Card Crawl, Card Thief, Wildfrost, Voice
of Cards, Meteorfall), GameRant (Balatro sales), WorldsApps (StS, Dawncaster
reviews), MiniReview (Night of the Full Moon, Solitairica), App Store /
Google Play listings (NotFM, Pirates Outlaws, Dungeon Clawler, Breach
Wanderers), 148Apps (Dawncaster), Deconstructor of Fun & MarvelSnapZone &
PocketGamer.biz & GameWorldObserver (Marvel Snap economics/design), OpenCritic
(Pirates Outlaws), fandom wikis for card counts (Balatro, StS, Wildfrost),
Dexerto (Snap launch roster), Antinomy mobile roguelike guide 2025, MarketIntelo
(roguelike market size), Robin Guo ("billion-dollar roguelike"), Rogueliker
(2026 releases), GamesHub & Davide Aversa (Hades narrative case studies),
Playing Software ("the run"), thoughts.jock.pl (Slay the Spire 2).
