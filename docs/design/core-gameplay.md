# Core Gameplay Design — v0.4

> **v0.4 — IMPLEMENTED (owner battle review, 2026-08-08):**
>
> - **Banking is REMOVED.** "What's the point of banking a card if it can be
>   stolen" — the bank was a paw spent to move a card somewhere a thief could
>   still reach, a decision with no upside. The `bank` command, the banked
>   pool, and the `combat.bank_limit` dial are gone; hand-attacks steal from
>   the hand only, and Loaf remains the one guard against theft. The command
>   stays permanently refused (chaos probe + unit test), not quietly
>   half-working.
> - **Purr is a commitment.** Multi-turn channels held Ash still in fiction
>   only — you could purr and then keep fighting. Now, while the channel
>   holds, `play_skill` (Scratch included), `charge_skill` and `concentrate`
>   are refused ("the purr holds him still"); discarding and Slip Away stay
>   open. Damage still breaks it. The rule is stated on the card, in the
>   coach line, and as a "purring" band in the tray.
> - **One action, one chronicle line.** "Ash: Scratch." + "  1 damage."
>   collapsed into "Ash: Scratch — 1 damage." (owner: single line per action).
> - **Discard is gone too** (2026-08-09: "no reason to personally discard an
>   energy card... it gives no benefit"). A free action that only ever hurt
>   you was a trap, not a choice. Energy leaves the hand by powering an
>   action or by theft; the hand-card popup is a close-up, nothing more.
>
> - **Charge-to-power skills.** Skills no longer fire in one tap: energy is
>   fed onto the card one placement at a time (`charge_skill` command; the
>   popup shows the cost as humour-colored pips that fill as you feed). A
>   skill is usable only once fully powered. Power PERSISTS across turns —
>   the built-in windup mechanic. `play_skill` still auto-pays any remainder
>   in one go (equivalent to charging fully right now), which keeps bots and
>   tests on the old path valid.
> - **The Paw system (action points).** `paws` per turn (default 3, config
>   key `"paws"`); every energy placement — feeding a skill, banking — costs
>   one paw. Discards, instincts and free skills cost none. Shown as paw
>   icons in the status strip. Sim pass after implementation: balance table
>   unchanged within noise (bots rarely placed >3/turn) — wraith puzzle and
>   tutorial floors intact.
> - **Discard.** Tap a hand card → Bank / Discard / Not now. Discarding is
>   free but the card is SPENT — gone until the long rest at home.
> - **Concentrate.** A third action-row button: give up the whole turn to
>   will one spent energy back (best card of a chosen humour → top of deck;
>   the enemy acts). Cats staring at nothing, finally explained.
>
> - **Three energies + the wild (owner, 2026-08-01 later).** The humours
>   are FEROCITY, GUILE, SHADOW — and **MOONLIGHT** (internal data id
>   remains `mysticism`, for save-file stability), the fourth card type,
>   which is WILD: it pays any energy cost (exact matches spend first;
>   wilds cover shortfall). Costs keyed `mysticism` demand real Moonlight
>   — reserved for very special actions acquired later.
> - **The slow-draw economy.** Opening hand 3; exactly ONE energy recovers
>   from the deck per turn. Concentrate's willed-back card is always your
>   next draw.
>
> Still proposed, not built: **potent energy as rarity** (starter decks skew
> to 1s; 2–3-value cards become level-up/chapter rewards; gilded 4s later),
> and **budget growth** for paws with progression.

> **v0.2 additions (2026-07-30, owner-directed, implemented):**
>
> - **The Approach.** Before turn 1 you may spend from your opening hand to
>   choose how Ash enters: **Stalk** (Shadow 2 — begin hidden: the enemy's
>   first move is wasted and your first hit is sharpened), **Ambush**
>   (Ferocity 2 — open with 3 free damage, but its first hit comes back +2),
>   **Case It** (Guile 2 — draw 2, even past the hand limit), **Ward**
>   (Moonlight 2 — Block 4 that holds through the first enemy turn), or walk
>   in free. Initiative is a *choice*, not a stat. Story scenes can also grant
>   surprise (`start_hidden`) — arriving fast interrupts the Unpicked.
> - **Long-rest loadouts (owner rule).** Deck composition and equipped skills
>   change only at a long rest (the Mantel between prowls). Mid-prowl you are
>   who you packed. Catnaps refresh charges but never re-fit the kit.
> **v0.3 additions (2026-08-03, owner defect review, implemented):**
>
> - **Five out at a time.** The loadout law rose from four abilities to five,
>   Scratch included (`SaveService.LOADOUT_SIZE`) — more room for a plan. The
>   battle tray is built with exactly one column per slot, so the number is a
>   shared constant, not two numbers that agree by luck.
> - **Approaches cost a flat price.** The environment's `cost_mod` no longer
>   discounts them: how Ash goes in is about Ash, not about the alley, and the
>   chooser now names the bill in words ("Stalk — Spend 2 Shadow Energy").
> - **Slipping away costs something.** The enemy's WHOLE telegraphed move
>   lands on your back as you go — previously only attacks that targeted
>   health did, so walking out on a thief was free — and at the prowl level
>   half the satchel goes over the wall with you. Some encounters have no back
>   door at all (`no_retreat`, first used by the Unpicked).
> - **Loaf guards the hand.** Block answers damage; nothing answered theft, so
>   a hand-attacker was unanswerable. A loafed cat has nothing loose to take.
> **v0.4 additions (2026-08-04, owner defect review, implemented):**
>
> - **Scripted fights.** Three encounter fields let the story own an
>   encounter's shape without the rules learning about the story:
>   `hp_floor` (damage stops here — a lesson you can fail to death is a
>   lesson nobody hears), `doom_turn` (the fight ends, decided, on this turn)
>   and the scene-level `withdraw_after` (past this turn the only button is
>   Slip Away). The floor and the forced exit are ONE mechanic: an unkillable
>   enemy with no forced exit is a free win given enough turns — the sim
>   measured the rag-wraith at 100% for the brawler before the exit existed.
> - **`no_retreat` refuses out loud.** Tapping Slip Away in a locked room
>   plays the encounter's `no_retreat_text` and hands the player back to the
>   fight. Hiding the button read as a missing feature; refusing reads as a
>   locked door, which is the beat.
> - **The chronicle is the whole fight, and it has numbers.** `CombatState`
>   keeps a `_journal` of what each action DID — damage rolled, block soaked,
>   which card was lifted — drained by the scene into a scrolling strip.
>   Informational only; nothing in the rules reads it back.
> - **Decisions with consequences.** Story choices set flags that alter
>   mechanics and later scenes (first one shipped: the prologue route-home
>   choice — a Moonlight card of her stitching vs entering the boss with
>   surprise). Choices are remembered by the world.
> - **Multiple win paths, verified by data.** Simulated playtests (8,400 bot
>   fights per pass — see [balance-notes.md](balance-notes.md)) confirm the
>   stage-3 wraith can be out-tanked (94%), out-fled (banks progress), or
>   died to (aggression: 2%) — and that tutorials are safe at 100% even for
>   random play. Simple rules first; intricacy ramps by stage.
> - **Escalation philosophy.** Each chapter adds ONE rule to the puzzle
>   (prologue: approach + intents; Ch1: alarm + press-on; Ch2 onward: from
>   the adopted shortlist) so encounters grow intricate without rules bloat.
> - **Influences roadmap.** Genre research (D&D, Blades in the Dark, PbtA,
>   Persona, recent indies) distilled into adopt/adapt/reject verdicts and a
>   sequenced shortlist — The Flip, Devil's Bargains, Case→Expose, Boss
>   Tempo, Flashbacks — in
>   [2026-07-30-influences-research.md](../research/2026-07-30-influences-research.md).

Status: **draft for owner review**. Synthesizes the owner's energy/skills
concept (2026-07-29) with all four research reports. Numbers are starting
points for prototyping, not commitments.

## The core inversion

In a classic deckbuilder you draw *actions* and hope they fit your plan. Here
we flip it:

> **You choose your actions in advance. You draw the *fuel*.**

- **Skills** are equipped before the run (loadout, 4–6 slots). They are what
  Ash can *do*: pounce, vanish, hex, beguile. Big art, big text, few in number
  — they live at the bottom of the screen like a MOBA skill bar.
- **The deck is made of Energy cards**, not actions. Each turn you draw energy;
  you spend it to activate skills. Your build (class, equipment, story
  unlocks) determines the deck's energy mix.

Why this fits us specifically:

1. **Solves the #1 mobile genre complaint** (unreadable card text): energy
   cards are simple glyphs; only 4–6 skills need reading, once, at loadout.
2. **Build depth without in-run browsing**: deck construction happens between
   runs (fits 3–5 min sessions); in-run decisions are fast but tense.
3. **Clash Royale rhythm**: a steady energy drip + hand pressure produces the
   "always about to afford something" pull that makes elixir systems
   addictive — but turn-based, so it stays thoughtful.
4. **Simulation-ready**: skill bars + energy decks make a fully
   deterministic, bot-playable format — the engine that powers automated
   balance sims and replay debugging.

## Energy: the four Humours

Energy is a mix of mana and stamina — it is *Ash himself*, drawn from the four
humours of a witch's cat. (Names provisional, tuned for icon-readability.)

| Humour | Color | Nature | Typical skills fueled |
|---|---|---|---|
| **Ferocity** | Red | Body, violence | Claw, pounce, savage combos |
| **Guile** | Green | Wit, timing | Feints, traps, steals, counters |
| **Shadow** | Black | Stealth, fear | Vanish, ambush, terror |
| **Moonlight** | Silver | The witch's borrowed magic | Hexes, wards, mending, memory |

- Energy cards come in values 1–3, some with small riders ("Shadow 2 — worth 3
  if you're Hidden") so draws still carry texture.
- Hybrid cards (e.g., Ferocity/Shadow, pick one) smooth variance.
- **Class = energy profile + signature skills.** An Ember-aspect Ash runs hot
  (Ferocity-heavy deck, burn-fast skills); a Silver-tongue build runs
  Guile/Moonlight. Classes differ by *resource shape* (research: this is what
  makes Gloomhaven classes feel distinct), including deck size and hand size.

## The turn

1. **Draw** up to hand limit (default 5). 
2. **Spend** energy to activate skills (tap skill → costs drain from hand).
   Holding cards for later combos is allowed but risky — see "attacks on
   your hand". (Banking removed 2026-08-08.)
3. Enemy acts on a **telegraphed intent** shown at turn start.

Target: ≤3 taps per player turn (research: input friction, not depth, is what
killed Gloomhaven Digital's pacing on small screens).

## The three pressures (owner concept, formalized)

Enemy attacks choose a target — and the *choice is telegraphed*, so defense is
a real decision:

| Attack targets | Effect | Counterplay |
|---|---|---|
| **Health** | Classic damage; 0 HP = a life spent | Block/dodge skills, Moonlight wards |
| **Skills** | Jams a skill (locks it 1 turn) or burns one of its remaining charges | Guile counters; jam-resistant equipment |
| **Hand** | Forces a discard — can shatter a combo you were saving up | Spend it, or Loaf (nothing loose to take) |
| **Itself: guard** (`block`) | Raises a guard that soaks your damage until its next move | Time the big hit for the open turn |
| **Itself: mend** (`heal`) | Repairs its own thread | Out-pace the mending; slow fights favour it |

This makes *saving for a combo* a push-your-luck act in itself, and gives
enemies personality without new rules: brutes hit Health, hexers hit Skills,
thieves and horrors hit your Hand.

## Exhaustion: energy is the clock (Gloomhaven DNA)

**Spent energy does not reshuffle.** The deck is Ash's wind and nerve for the
whole adventure; when it thins, he is running on fumes.

- Skills also have **limited charges per adventure** (e.g., Pounce ×3,
  Ninth-Hour Hex ×1). Burned charges don't refresh mid-run.
- Small recoveries exist (Catnap at a safe ledge, milk-saucer caches, certain
  Moonlight skills) but never full refills.
- When your deck is nearly empty you can still act — every class has a free,
  weak **instinct action** (Scratch / Slink — the Hearthstone hero-power
  anchor) — but you are visibly a spent cat, and the game tells you so.

The deck level is therefore a **fuel gauge and run timer in one**: zero extra
UI, and it *is* the retreat motivation (next section).

## Retreat, death, and the cost of dying (owner requirement)

A story game can't treat death as free. The structure:

- **Extract (retreat)** is always available between encounters — one tap on
  **"Slip Away"** — and even mid-fight via certain skills/exits at a cost.
  Retreating **banks everything**: loot, evidence, story progress ("a cat that
  leaves is a cat that learned something"). The quest stays open; you return
  with your progress marked. Retreat is framed as feline wisdom, never
  cowardice — cats are the world's masters of deciding a fight is beneath
  them.
- **Death (a life spent)** hurts three ways, but never touches
  meta-progression (research rule: busts must not destroy meta):
  1. **The satchel spills** — un-banked loot and evidence from this run are
     lost where you fell. Some can be reclaimed by winning back to that spot.
  2. **The Toll** — the Hollow Court (death's bureaucracy) takes its fee for
     the returned life: your choice of one shadow-pocket item *or* a cut of
     banked Gleam. A softened, Quacks-style bust: it stings, you choose the
     sting.
  3. **The world remembers** — whatever killed you gains a *Grudge* (small
     buff, named after the kill: "Slew Ash Twice"), and certain NPCs comment.
     Dying is canon. It is also, occasionally, story: some doors only open to
     a cat who has died in a particular way (curiosity rewarded — sparingly).
- Net effect: **pressing on risks the satchel; retreating banks it; dying
  costs treasure, dignity, and gives your enemy a name for you.** The optimal
  emotional loop: push one encounter too far, *almost* die, slip away at 1 HP,
  come back sharper.

## Push-your-luck: the delve structure

A run ("prowl") is 2–4 encounters deep along one path — no map screen.

- After each encounter: **Slip Away** (bank half — running spills the rest,
  owner rule 2026-08-03) or **Press On** (next
  encounter richer: better loot multiplier, rarer evidence, deeper story).
- Odds are **visible and countable** (research rule): the next encounter's
  danger is shown as omens (paw-print icons), your remaining deck/charges are
  always on screen. The player computes the gamble at a glance.
- Environments modify costs (owner concept): each district/weather makes some
  humours cheaper or dearer — *Moonless night: Shadow skills cost −1, Moonlight
  +1*. Loadout vs destination is the strategic pre-run decision.
- Encounter count and turn caps guarantee the 3–5 minute envelope:
  - 2–4 encounters × 4–6 turns × ~8s ≈ 2.5–4 min
  - interstitial story beat (1 tap) + extraction scene ≈ 30–45s

## Between runs: the town loop (2–3 taps, never admin)

- **Quest board** → pick next prowl (quest = mission type + district + stakes).
  Mission types beyond combat are the five committed minigame modules —
  Seam & Stitch, Testimony, Patch the Ward, the Unpicking, the Long Way
  Round — all spec'd in **minigames.md**; all reuse the energy deck,
  paws, Alarm, and case systems rather than adding parallel resources.
- **Shop** (the Magpie Exchange): equipment for shadow-pockets, energy-deck
  tuning (add/remove/upgrade energy cards — the StS "removal service" lesson:
  subtraction is the best purchase), satchel insurance, charge refills.
  Dual currency: **Gleam** (run loot, spendable) and **Favors** (meta
  reputation, persistent — unlocks stock, classes, districts).
- **One story beat** — new every time, win or lose (Hades cadence).

## Cat behaviors as mechanics (owner request)

Being a cat is the game's texture. Real cat behaviors map onto systems, played
straight-faced (which is what makes them funny):

| Behavior | Mechanic |
|---|---|
| **Purring** | Channel skill: heal over 2 turns; Ash lies still until it ends (acting is refused), and it is interrupted if you take damage (a purr you can't finish is a tiny tragedy) |
| **Basking in sunlight** | Sunbeam tiles appear in some encounters/districts: end your turn in one to recover 1 energy card (weather-dependent — none on moonless nights, plentiful at noon quests) |
| **Scratching things** | Rugs, posts, and furniture are interactable props: scratch to sharpen (+1 Ferocity next attack), shred certain wards, and occasionally infuriate a shopkeeper (reputation consequences, worth it) |
| **Knocking things off shelves** | Guile skill: push an object off a ledge onto an enemy. The single most requested cat fantasy; must feel *premeditated* |
| **The Zoomies** | Rare instinct that triggers at low deck: one frantic free turn, then forced Catnap |
| **Loafing** | Defensive stance: tuck all paws, +block, but you cannot act next turn (committed loaf) |
| **Slow blink** | Diplomacy tool: the cat's "I trust you" — opens certain dialogue outcomes and calms beast-type enemies |
| **Bringing "gifts"** | Delivering a dead rat to an NPC is a legitimate — sometimes the only — way to raise their disposition. They will not always be grateful. That's their problem |
| **Catnap** | The between-encounter rest that restores charges; napping in *dangerous* places yields dream-fragments (flashback currency) — curiosity again |

Tone rule for mechanics copy: **cute on the surface, competent underneath** —
the pun lands in the flavor line, never in the rules text. ("Loaf. *Block 6.
All paws accounted for.*")

## Variance with memory

No raw dice anywhere (research: Buttons & Bugs' dice streakiness was its top
complaint). Crits/fumbles come from a tiny per-class **Fate deck** (modifier
deck with memory) that equipment and perks can edit — the odds surface that
keeps the shop interesting without stat creep.

## Open questions for the first prototype

1. Does drawing *only energy* feel low-agency in practice? Mitigations ready:
   riders on energy cards, hybrid cards, a "convert 2 energy → 1 any" instinct.
   Prototype will tell.
2. Hand limit 5 vs 4; deck size 18–24; skill slots 4 vs 6.
3. ~~Should banked (face-down) cards be capped at 2?~~ Resolved harder:
   banking itself was removed (owner 2026-08-08).
4. Mid-fight retreat pricing (lose this encounter's loot only?).
