# Minigame prototypes — are the five modules buildable?

**Date:** 2026-08-03. Answers the question put to the five approved modules
in [minigames.md](../design/minigames.md): do the mechanics work, and can
they be built? Built deliberately **without art** — every board is drawn
from geometry (dots, lines, boxes, type), so nothing here waits on an image.

**Verdict: all five are buildable, and all five are built and playable.**
One had a real design hole, found by a bot rather than by a player. One
needs a balance pass before it ships. Details below.

## How to try them

Double-click anything in `play/apps/`, or:

    godot --path game -- --scene dev          # Developer Mode: jump anywhere
    godot --path game -- --scene stitch:chart_sampler
    godot --path game -- --scene testimony:shift_boss
    godot --path game -- --scene ward:ward_hall
    godot --path game -- --scene lattice:lattice_counting_room
    godot --path game -- --scene crossing:crossing_mereside

The agent that plays them without a human:

    godot --headless --path game -s tests/minigames.gd

## What was built

| Module | Rules | Content | Board | Verdict |
|---|---|---|---|---|
| Seam & Stitch | `core/stitch_state.gd` | 4 charts | dots + thread, taut on close | **works** |
| Testimony | `core/testimony_state.gd` | 1 witness, 4 ribbons | ribbon plates + evidence strip | **works** |
| Patch the Ward | `core/ward_state.gd` | 2 wards | grid + polyomino rack | **works** |
| The Unpicking | `core/lattice_state.gd` | 2 lattices | crossed lines, broken where under | **works** |
| The Long Way Round | `core/crossing_state.gd` | 2 crossings | route pips + gust plate + paw | **works, needs tuning** |

Every module follows the CombatState pattern the doc asked for: pure
RefCounted rules, one `do_command()`, `{ok, error}`, a CommandLog, and a
seed. That is what makes them unit-testable, bot-playable and replayable.

Puzzle content is data (`game/data/stitch_charts.json`, `testimonies.json`,
`wards.json`, `lattices.json`, `crossings.json`) with `Catalog.validate()`
coverage, so adding a puzzle never means touching a scene script.

## The agent

`game/tests/minigame_bots.gd` plays all five, two ways:

- **Solvers** ask *can this be finished?* — they play to win using only the
  public rules. A module whose solver cannot finish its own shipped content
  is not built, however good it looks.
- **Chaos bots** ask *does it break?* — random legal play plus malformed and
  out-of-range commands, against the same invariants the combat harness uses
  (`ChaosPlay`): a rejected command changes nothing, a finished session stays
  finished, energy is conserved, every session terminates, the log replays.

Both feed one report (`tests/minigames.gd`) and a committed slice
(`tests/unit/test_minigames.gd`, in the normal suite).

## What the bots found

### 1. The Long Way Round could not be finished (fixed)

The first run reported *"the crossing never resolved"* — the careful solver
looped to the command cap on every seed.

**Cause:** cards only ever left the hand on a slip, and Shelter was free. So
a cautious player's hand grew until it held one of every humour, every
posted gust matched something, no safe press existed, and the crossing had
no ending. Free shelters also allowed infinite gust-rerolling.

**Fix:** Shelter now **burns a card** — which is what the design doc already
said ("cards spent to slips/shelters go to the SAME spent pool"); the
implementation had simply dropped it. Waiting now costs what pressing costs,
hand and deck only ever shrink, and the crossing is guaranteed to end. A
second guard ends it when hand and deck are both empty, so an exhausted
player reaches an ending instead of a stall.

This is the module's load-bearing rule, not a detail: **the crossing must
consume the deck, or it has no clock.**

### 2. Shelter is unavailable with an empty hand (by design, now asserted)

Follow-on question: with nothing to burn, can the player get stuck? No —
Press On draws, so it is always available while the deck holds anything, and
an empty hand *and* deck ends the crossing. There is a test asserting this
soft-lock property directly rather than trusting the reasoning.

### 3. Two harness bugs, worth recording

The first run also produced 45 lines of noise from a post-session guard that
ran on unfinished sessions, and a crash from a probe indexing an empty list.
Both were the harness, not the game. **Suspect the harness first** is the
same rule the combat fuzzer earned.

## What still needs a decision

1. **The Long Way Round is too easy.** Careful play crosses 100% of the time
   in ~2–3 turns; reckless play also crosses 100%, losing 2–5 hp. A
   push-your-luck module where both lines always win has no gamble in it.
   The cause is structural: progress scales with hand size, so it
   accelerates faster than the storm can bite. Levers, cheapest first —
   lengthen routes hard (they are already 22 and 34), cap the advance,
   or make the gust reroll each press rather than each shelter. **This wants
   the owner's taste and a sim table, not a guess.** It does not block the
   prototype: the mechanic is proven, only the numbers are soft.
2. **Stitch charts are proven solvable, not proven UNIQUE.** Validation
   confirms the stored solution really is one closed loop that satisfies
   every clue — which is the existence proof the doc asked for. It does not
   prove there is only one answer. For a calm puzzle that is arguably fine;
   if uniqueness matters, the 2x2 chart is small enough to brute-force
   (4,096 states) and bigger ones will need a real solver.
3. **The ward rack is generous.** The greedy solver covers both tears
   perfectly, so "you will usually NOT cover everything" is not yet true of
   the shipped content. That is a content-tuning job: trim the rack or widen
   the tear once the gap effects matter to a real fight.
4. **Mirror mode is view-only.** `chart_mirror` flips the clue numbers, not
   the grid, which is the cheap reading of the Ch3 payoff. Whether that
   lands emotionally is an owner call to make with the chart in hand.

## What is deliberately not done

No story wiring: the modules resolve to an outcome card, not into
`when_outcome` prose in a lead (that is Phase 3–4 work). No drag input —
everything is tap or tap-then-tap, which is enough to feel the mechanics.
No tour stops in the main tour; the boards are photographed from the
component runner instead. No art, by design.

## Scope, re-estimated after building

The doc's estimates held, with one correction: **The Unpicking is cheaper
than [M]** because its thread rendering came out of Seam & Stitch's drawing
work almost unchanged, exactly as the build order predicted. **Patch the
Ward** was the biggest board, as forecast [M–L]. **The Long Way Round** was
indeed the smallest to build, and is the one that needs the most tuning —
reuse bought the code, not the balance.
