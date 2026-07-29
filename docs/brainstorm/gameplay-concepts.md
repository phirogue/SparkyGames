# Gameplay Concepts — Making a Roguelite Card Game Fit 3–5 Minutes

The hard design constraint is the session length. A classic Slay-the-Spire run
is 45–120 minutes; we need a *complete, satisfying* roguelite arc in 3–5
minutes. That forces different structural choices, explored below.

## What eats time in a deckbuilder (and what we must cut)

| Time sink | Typical cost | Our approach |
|---|---|---|
| Large decks (30+ cards) | Long shuffles, long fights | Micro-decks of 8–12 cards |
| Many encounters per run | 30–50 fights | 3–5 encounters per run |
| Map navigation | Minutes of pathing | One binary choice between encounters |
| Card-reward browsing | 20–30s per fight | Pick 1 of 2, big art, instant |
| Enemy turn animations | Seconds × hundreds | Snappy, interruptible animations |
| Analysis paralysis | Unbounded | Small hands (3–4 cards), soft timers |

## Structural options for the core loop

### Option A — Micro-Spire (compressed classic)
8–12 card deck, 3 fights + 1 boss per run, one fork in the road between fights.
Fights last 3–4 turns because numbers are tuned high (you and enemies die fast).
- Pros: familiar genre feel; deck identity still emerges.
- Cons: hardest to tune; risk of feeling like a demo of a bigger game.

### Option B — Fixed-turn duel (Snap-like)
Every encounter is exactly **6 turns**, both sides play simultaneously-revealed
cards into 2–3 locations/lanes; best board state wins. A run = 3 duels with
drafting between them.
- Pros: session length is *mathematically guaranteed*; simultaneous-reveal
  produces drama; **this structure is inherently PvP-ready** — replace the AI
  seat with a human later, zero redesign. Strongest fit for the multiplayer
  requirement.
- Cons: less "deckbuilder crunch"; location/lane design burden.

### Option C — Card Crawl grid (solitaire-crawl)
The dungeon is a stream of cards dealt into a 2×4 grid: enemies, weapons,
potions, story events. Clear the deck to finish the run. One deck = one run =
one story chapter, ~4 minutes by construction.
- Pros: proven 3–5 min format (Card Crawl/Card Thief); one-handed portrait
  play; extremely readable.
- Cons: shallower build variety; PvP retrofit is awkward.

### Option D — Encounter-puzzle chain
Each encounter is a hand-authored puzzle: fixed hand, fixed enemy, find the
line. A run = 3 puzzles drawn from a pool, plus a semi-random boss.
- Pros: puzzles carry narrative beautifully (each is a story moment); zero
  filler.
- Cons: content treadmill — authored puzzles get consumed and don't replay.

### Early read
**Option B (fixed-turn duel) as the combat core, wrapped in Option A's
mini-run structure** looks like the sweet spot: guaranteed session length,
PvP-compatible by design, with drafting between duels preserving roguelite
build identity. Validate against market research before committing.

## Roguelite meta-progression (the "lite" part)

Between runs, permanent progress must land — that's what makes 3-minute
sessions add up to retention:

- **Card collection:** new cards unlock via quests/story, expanding the draft
  pool (not raw power creep — sideways unlocks, à la Slay the Spire).
- **Story progression:** every run advances a quest — win *or lose*. Losses
  yield "story fragments" so no session feels wasted (critical at this length).
- **Relics/blessings:** run modifiers earned from completed quest chains.
- **Heroes:** 2–3 playable characters at launch, each with a distinct card pool
  and story perspective.

## Weaving story into runs without slowing them

- **Quest = run seed.** Player picks an active quest from a board; the quest
  determines the run's encounters, boss, and reward. Story selection happens
  *between* sessions, not during.
- **One story beat per encounter transition:** a single illustrated line of
  dialogue (skippable with a tap), never a wall of text mid-run.
- **Payoff scene after the run:** 15–30 seconds of dialogue/choice at the quest
  board — the "campfire" moment where narrative actually breathes.
- **Cards as lore:** every card has one flavor line; collections are the
  codex. Reading lore is optional, off the clock.

## Session math sanity check (Option B core)

- 3 duels × 6 turns × ~10s per turn-pair ≈ 3.0 min
- 2 draft picks × 10s + 2 story interstitials × 10s ≈ 0.7 min
- Post-run payoff scene ≈ 0.5 min
- **Total ≈ 4.2 minutes** — inside the 3–5 window with headroom.

## Open questions (answer after research lands)

1. Portrait or landscape? (Portrait = one-handed commuter play, strongly
   correlated with short-session success on mobile.)
2. Simultaneous reveal vs alternating turns for feel and for future PvP netcode?
3. How many launch cards do comparable games ship with? (Drives Midjourney
   asset planning.)
4. Soft timer on turns: does the genre tolerate it offline?
