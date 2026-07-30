# Tabletop Mechanics Research: Gloomhaven, Push-Your-Luck, Classes, Equipment

*Compiled 2026-07-29 — for a 3–5 minute mobile roguelite card game.*

Note: two names from the research brief — "Voyage of the Marvellous" and
"Cursed Hoard" — could not be verified as existing games; "Cursed Hoard" is
treated as shorthand for the generic "bank-or-risk-it" pattern.

---

## 1. Gloomhaven's Card System In Depth

### The hand as health bar and timer

Gloomhaven's central innovation is that ability cards are simultaneously
**actions, stamina, and the scenario clock**. Each round you play two cards
from hand (or declare a rest). Cards go to a discard pile; resting recovers
discards back to hand — but **each rest permanently "burns" one card**. Big
flashy abilities also burn the card directly. When you can no longer play two
cards or rest, your character is **exhausted** and removed from the scenario —
no coming back. "Your hand of cards is your real health bar" — damage can even
be soaked by burning cards, so HP and stamina are one merged economy. Because
rests shrink your maximum, the whole scenario is a slowly tightening spiral.

This creates *systemic urgency without a visible countdown*: dawdling is
punished by economics, not by a timer UI. It is also natively push-your-luck —
burning your best card now for a big turn shortens your run.

### Two-action cards (top/bottom)

Every card has a **top action (usually attack) and a bottom action (usually
move)**. Each round you pick two cards and use **the top of one and the bottom
of the other**. Any card can also default to "Attack 2" (top) or "Move 2"
(bottom), so no draw is ever dead. One card = two possible uses; pairing
decisions produce deep combinatorics from a hand of ~10 cards.

### Initiative on cards

One chosen card's printed **initiative (1–99)** sets your turn order; fast
cards tend to be weaker, so initiative is itself a cost. Note: this shines in a
multi-actor grid game; in a 1v1 or lane game its value shrinks (Buttons & Bugs
largely flattens it).

### Campaign loop: town, quests, retirement

Between scenarios: buy/sell items (stock gated by **town prosperity**), city
and road events, level up. Every character has a secret **personal quest**;
completing it forces **retirement** — the character is permanently retired,
items return to the shop pool, prosperity rises, and **a sealed new class
unlocks**. This is the best tabletop model of a roguelite meta-loop:
*characters are runs at a macro scale*; the town, not the character, is the
persistent progression vessel.

### Class differentiation

Classes differ by card pool, hand size (9–12 = stamina), attack-modifier deck
customization (per-class "luck deck" perks), and a signature mechanic.
Distinctness comes from **resource shape** as much as from effects — a lesson
few video games copy.

### Digital adaptations and compressions

- **Gloomhaven Digital** (PC/console): faithful; praised for automating the
  fiddly bits. Criticisms are all about **interaction friction** (confirm-heavy
  turns, obtrusive tutorial) — not depth. Per-turn input count is the enemy on
  small screens.
- **Jaws of the Lion**: the officially streamlined version — map books, 4
  classes, incremental 5-scenario tutorial; proof the system tolerates
  aggressive trimming of components but not of the core card economy.
- **Frosthaven**: expanded with an **outpost phase** (building, crafting,
  seasonal events) — reviewers found it "largely administrative" and
  chore-like. Cautionary tale: keep the between-run loop snappy.
- **Buttons & Bugs (2024) — the key precedent.** Gloomhaven at pocket scale:
  ~$12, ~20 min/scenario, 20-scenario campaign, 6 classes. Compression moves:
  - **Hand of 4 double-sided cards**; play two per turn (top of one, bottom of
    other — preserved). A-sides flip to B-side and return to hand; B-sides
    discard. Exhaustion survives at ~**9 total actions per scenario**.
  - **Modifier deck → one die + small track**; main complaint is dice variance
    (dice lack the deck's self-correcting memory).
  - **Map compressed to a tiny mat**; line of sight, traps cut; statuses become
    icons; scenario special rules carry variety.
  - Reception: genuinely Gloomhaven-feeling at pocket scale; criticisms center
    on dice streakiness and rough early difficulty.

**What survives compression:** hand-as-depleting-resource, top/bottom dual-use
cards, burn-for-power, campaign unlock cadence. **What gets cut first:**
grid/line-of-sight, initiative nuance, modifier decks, logistics-heavy town
phases.

---

## 2. Push-Your-Luck Mechanics

### The canon

- **Quacks of Quedlinburg** — bag-building PYL: draw chips into your pot; each
  white chip risks **busting past 7**, which costs either your score or your
  buying power (never both — a softened bust). "Is it worth one more pull?"
  every single draw. Rubber-banding for trailing players. Crucially,
  *bag-building controls your odds*: you buy chips between rounds that make
  pushing safer or more explosive — the closest ancestor to a roguelite shop
  feeding a PYL engine.
- **Incan Gold / Diamant** — walk deeper; each card is treasure or hazard; a
  **second copy of the same hazard** wipes un-banked gems. **Visible odds**
  (count the hazards already drawn) + leave early to bank securely.
- **Deep Sea Adventure** — divers share **one oxygen pool**; every treasure
  weighs you down and drains shared air faster. The bust is "slow and
  insidious rather than a sudden reveal" — greed *degrades* you gradually.
  Excellent model for a weight/corruption meter.
- **Clank!** — deckbuilder where going **deeper** yields better loot, but noisy
  cards add your cubes to a bag; dragon attacks draw from the bag. Depth =
  reward, noise = risk-bag, escape = banking. Canonical proof that
  **deckbuilding + PYL depth-crawl** fuse cleanly.
- **Ra** — drawing another tile grows the shared lot but risks forcing a
  premature auction. Lesson: PYL is richer when "stop" is itself a positive
  action (call the auction), not just chickening out.
- **Dungeon Roll** — delve level by level; party dice deplete as dungeon dice
  escalate: each successive "continue" is strictly scarier.
- **Blackjack-likes** — purest visible-odds bust. Mobile's **Void Tyrant**
  (hit/stand to 12 as combat resolution) proves the pattern works one-thumb.

### Why it compels

1. **Escalating stakes** — each iteration raises both reward and loss
   probability; the decision gets harder every step, automatically producing a
   tension curve.
2. **Visible/countable odds** — the player must *feel* the odds shifting.
   Hidden odds turn PYL into a coin flip and kill agency.
3. **Loss aversion** — un-banked gains are "endowed"; risking what you hold
   hurts ~2x more than equivalent upside pleases.
4. **Softened/graduated busts** (Quacks' choose-your-penalty, Deep Sea's slow
   drain) keep busts dramatic but not run-ending-frustrating.
5. **Player-tunable odds** — long-term building changes your bust curve; that
   hook marries PYL to progression.

### PYL × roguelite structure

The natural fusion: **run rewards accrue to a temporary "carried" pool; the
player repeatedly chooses "extract now" vs "next room"; a bust loses the
carried pool (not meta-progress)**. Clank! and Dungeon Roll are the direct
templates. Two rules of thumb: never let a bust destroy *meta* progression,
and make the "bank" action feel like a play (extraction), not a concession.

---

## 3. Character Classes in Card Games

- **Slay the Spire**: 4 classes, each a closed pool with a distinct *resource
  grammar* — Ironclad (strength/exhaust/self-damage), Silent (poison/shivs/
  discard tempo), Defect (orb economy), Watcher (stances). Each class contains
  2–4 internal archetypes. Deliberate design ladder: first class teaches
  fundamentals, later classes layer novel resources.
- **Hearthstone**: identity framework is threefold — class **fantasy**, what it
  **excels** at, and where it **must struggle**. Defined weaknesses matter as
  much as strengths. Hero Powers give an always-available identity anchor even
  when draws are bad — useful for short runs.
- **Dawncaster**: 6 classes; within a class you customize basic attacks +
  weapon ability + starting card — "class" is a *space of loadouts*. Criticism:
  unlock pacing is "glacial."
- **Typical launch counts:** StS 3 (+1 later); StS2 5; Dicey Dungeons 6;
  Roguebook 4; Monster Train 5 clans. **Pattern: 3–6 at launch, 1–2 available
  immediately, the rest unlocked early and cheaply**, then deeper per-class
  unlocks pacing long-term play.
- **Unlock pacing:** StS's model (play class A to unlock B; per-class card
  unlocks over first ~10 runs) makes early losses feel like progress.
  Gloomhaven's retirement model is the aspirational version: **class unlocks
  tied to completing a character's personal story** — unlocks as narrative
  events.

---

## 4. Equipment & Economy Systems

**Four clean equipment patterns:**

1. **Slotted passives** — Gloomhaven's three *use types* are worth stealing:
   **passive**, **spent** (refresh per encounter/rest), and **consumed** (once
   per scenario). Slot limits keep items a *choice*, not a pile.
2. **Odds-modifiers** — Gloomhaven perks edit your modifier deck; Quacks chips
   edit your bag; Dicey Dungeons equipment transforms dice. Equipment that
   *changes your probability curve* is the natural fit for a PYL game.
3. **Consumables** — burst agency in emergencies; cheap shop filler that never
   power-creeps.
4. **Sticky/replace-only gear** — Loop Hero's "never unequip, only overwrite"
   creates constant micro-decisions; rarity splits stats so **rare isn't
   strictly better**.

**Gold economies:**

- **Gloomhaven**: gold scarce, looted mid-scenario at opportunity cost, spent
  in town; stock gated by prosperity. Money stays meaningful all campaign.
- **Slay the Spire**: the shop's genius is the **card-removal service** (75g,
  +25 each) — the best purchase is *subtracting*; escalating price is the
  run's main gold sink. Gold's job is "solve a specific deficiency," not "buy
  bigger numbers."
- **Pirates Outlaws**: dual currency — run-gold resets; persistent
  **reputation** buys characters/maps. Clean template for mobile.

**Avoiding power-creep in a persistent shop:** sell options and odds, not
stats; gate stock by progression; slot limits + trade-offs; sell
removal/refinement services; keep between-run economy resolvable in seconds.

---

## 5. Synthesis — Implications For Our Game

### Gloomhaven DNA that compresses well

- **Hand-as-timer/exhaustion**: the single most portable idea — Buttons & Bugs
  proves it at exactly our scale. A 3–5 minute run can *be* one exhaustion
  cycle: resources deplete as you delve; when empty, the run ends or you must
  extract. Merges run timer, health, and resources into one system with zero
  UI overhead — and it is natively push-your-luck.
- **Top/bottom dual-action cards**: doubles decision density per card, halves
  art needs, touch-native (tap top or bottom half).
- **Burn-for-power**: permanent removal for the run = self-balancing nova
  plays and a second PYL dial.
- **Town/quest/retirement loop**: shop gated by prosperity-like progression;
  personal quests that retire a character and unlock a new class = story-fused
  meta-loop. Keep the town phase to 2–3 taps.
- **Modifier variance with memory**: prefer a small modifier deck/bag over
  dice — deck memory is free digitally and doubles as an upgrade surface.

### Gloomhaven DNA that fights the constraint

- Hex grid, line of sight, positioning, multi-character control — cut
  entirely. A lane/single-space abstraction retains melee-vs-ranged flavor.
- Card-based initiative — reduce to a "fast cards act before the enemy, slow
  cards after" binary at most.
- Confirm-heavy turns — target ≤2 taps per turn.
- Crafting/building admin — don't.

### The push-your-luck spine

Each room/step deepens the delve; loot accrues to an un-banked satchel;
"extract" is always one tap away; going deeper improves multipliers while
hazards visibly accumulate. Rules distilled:

- Odds visible and countable (show hazards drawn, cards left, bust chance).
- Soften the bust: a bust costs the satchel *or* this run's upgrade, never
  meta-progress, never both.
- Let shop/equipment tune the risk curve (reroll hazards, raise thresholds,
  insure part of the satchel) — keeps the shop interesting without stat creep.
- Consider a "weight" mechanic: carried loot drains your hand faster — greed
  degrades rather than binary-busting.
- The exhaustion hand *is* the oxygen — sections 1 and 2 unify into one
  mechanic.
- PvP later: simultaneous secret stay/leave decisions and contested pots (Ra,
  Incan Gold) are the cheapest compelling PvP — async-friendly.

### Classes and economy

- Launch with 3–4 classes, one available immediately; differentiate by
  **resource shape** (hand size, burn rate, modifier deck, risk-affinity),
  give each an always-available signature power and a defined *weakness*.
- Unlock classes via retirement/personal-quest completion (story-fused).
  Pace early unlocks fast.
- Dual currency (run-gold resets; meta-reputation persists); equipment in
  limited slots with passive/per-rest/per-run taxonomy; sell services and
  odds-modifiers; gate stock by prosperity.

### Key precedent

**Gloomhaven: Buttons & Bugs** is the load-bearing proof that Gloomhaven's
feel survives compression to a 4-card hand and ~20-minute solo scenarios. Our
target is "Buttons & Bugs pace, digital-native odds, Clank!/Incan Gold
bank-or-delve spine, Gloomhaven town loop." Its two documented stumbles — dice
streakiness and harsh early difficulty — are both cheaply fixable digitally.

---

## Sources

Everything Is A Game, Dized rules, Gloomhaven fandom wiki (retirement,
personal quests, items), GamingTrend / Geeks Under Grace / Age of Miniatures
(Gloomhaven digital), Tabletop Bellhop / Roll to Review (Jaws of the Lion),
Meeple Mountain / Wargamer (Frosthaven), Wargamer / Shelfside / Zatu /
BoardGameViews (Buttons & Bugs), ShippBoard Games / Meeple Mountain /
BrandonTheGameDev (Quacks), Gametek (Incan Gold), Don't Eat the Meeples (PYL
roundup), WhatBoardGame (Clank!), Shelf Gamer / Bitewing (Ra), Wikipedia (Luck
Be a Landlord), Gamerant (casino roguelikes), slaythespire.gg, Blizzard
developer insights (class identity), 148Apps / In An Age / TV Tropes
(Dawncaster), Game Developer (Roguebook), ScreenRant / TouchArcade (Pirates
Outlaws), sts2front / GameHelper (StS economy), Medium / GameSpot (Loop Hero),
UltraBoardGames (Gloomhaven cards).
