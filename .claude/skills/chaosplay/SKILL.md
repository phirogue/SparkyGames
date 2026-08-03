---
name: chaosplay
description: Hunt combat edge cases by playing badly on purpose - irregular strategies, degenerate loops, and illegal commands. Run after ANY change to core rules, commands, skills, enemies or environments. Usage: /chaosplay [what changed]
---

# Chaos Play — break it before a player does

`simulate.gd` asks *is this fight fair?* using bots that play sensibly.
This asks *can this fight be put into a state it should not be in?* — and
plays badly on purpose to find out. Both are required; neither substitutes
for the other.

## Run it

```
& "C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe" --headless --path game -s tests/fuzz.gd -- --seeds 60
```

Narrow once something fails:

```
... -s tests/fuzz.gd -- --persona hoarder --encounter prologue_dog --seeds 200
```

A small fixed slice already runs with every commit
(`tests/unit/test_chaos.gd`) — the full sweep is for when you changed the
rules, and before any release build.

## The ten ways it plays badly

`random_legal`, `chaos_illegal` (malformed and out-of-range commands),
`hoarder` (banks and charges, never fires), `discarder` (throws the hand
away), `overcharger` (feeds an already-powered skill), `concentrator`
(gives up every turn), `slipper` (flees at arbitrary moments), 
`instinct_only`, `approach_spammer`, `pacifist` (never acts at all).

Each is a real player pathology, not noise. Add one whenever you catch
yourself thinking "nobody would do that" — that thought is the bug report.

## The seven invariants

1. A **rejected command changes nothing**. Half-applied actions are how
   free-resource bugs happen. This one has already caught a real defect.
2. **Energy is conserved**: deck + hand + banked + spent never changes count.
3. **Spent is spent**: the deck only grows via `concentrate` or a sunbeam on
   `end_turn` — CLAUDE.md's no-reshuffle law, enforced rather than remembered.
4. **Bounds hold**: hp never over max, block/alarm/paws never negative, paws
   never over the limit, the bank never over `BANK_LIMIT`.
5. **A finished encounter is finished** — nothing is accepted afterwards.
6. **The run terminates** — no command sequence spins forever.
7. **The log replays**: same seed + same commands = the same final state.

## Triage — do this in order

1. **Suspect the harness first.** If a violation implicates the bot's own
   randomness or its bookkeeping, fix `chaos_play.gd`, not the game. The
   bot must never draw from `state.rng`; that stream belongs to the game.
2. **Reproduce from the seed.** Every violation prints its encounter,
   persona and seed. Re-run that single cell.
3. **Write the failing case as a unit test BEFORE fixing it** — in
   `tests/unit/test_combat.gd` if it is a rules bug, so the specific defect
   is pinned forever and not just covered by a fuzz sweep that might not
   re-roll it.
4. **Fix the rule, then re-run the full sweep**, then `run_tests.gd`, then
   `simulate.gd` (a rules fix can move the balance table).
5. If the "violation" turns out to be intended behaviour, **change the
   invariant and say why in a comment** — never delete it silently.

## After a real fix

- Add a scenario spec if the state is reachable in play, so it can be tried
  by hand from `play/apps/`.
- Note it in the commit body: what irregular play found it, and what a
  player would have seen.
