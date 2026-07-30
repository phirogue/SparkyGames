# Core Gameplay Design — v0.1 (proposal)

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
4. **PvP-ready**: two players with skill bars and energy decks is a symmetric,
   fair, async-friendly duel format.

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
2. **Spend** energy to activate skills (tap skill → costs drain from hand),
   and/or **bank** a card face-down for later combos (saving is allowed but
   risky — see "attacks on your hand").
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
| **Hand** | Forces a discard — can shatter a combo you were saving up | Spend it or shield it; "slippery" banked cards |

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

- After each encounter: **Slip Away** (bank all) or **Press On** (next
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
| **Purring** | Channel skill: heal over 2 turns; interrupted if you take damage (a purr you can't finish is a tiny tragedy) |
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
3. Should banked (face-down) cards be capped at 2? Probably yes.
4. Simultaneous-reveal variant for future PvP: both sides commit skill
   activations, then resolve — test early since it changes feel.
5. Mid-fight retreat pricing (lose this encounter's loot only?).
