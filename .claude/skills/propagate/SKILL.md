---
name: propagate
description: Before and after changing anything in this game - find every other place that change has to reach, then prove it got there. Use when adding or changing a skill, enemy, quest, screen, minigame, tuning number, profile field, art asset, or player-facing prose. Usage: /propagate <what you are changing>
---

# Propagate — a change is not done where you made it

Every component here is assembled from pieces in different files. A minigame is
a rules class AND a screen AND a data file AND a bot AND a launch spec. Adding
one and forgetting another does not fail loudly — it fails as a dead button, a
quest nobody photographed, a portrait that renders as a placeholder.

Those are the defects that reached owner reviews, repeatedly. Every one was a
propagation failure. This skill is the fix.

## Before you edit

1. **Find the chain.** Read `docs/architecture/change-map.json` and locate the
   entry matching what you are about to change:

   `add-or-change-a-skill` · `add-an-enemy` · `add-a-quest` · `add-a-screen` ·
   `add-a-minigame-module` · `change-a-tuning-number` · `add-a-profile-field` ·
   `add-or-change-art` · `change-player-facing-prose` ·
   `change-the-layout-contract`

2. **Read its `touch` list in order.** Each step says *why* it is there. Steps
   marked `"auto": true` need no action — something already derives from the
   file you are editing, and knowing that saves you hunting for a list to
   update. Steps marked `"optional": true` depend on the specifics.

3. **If your change has no entry**, it is a new kind of change. Trace it by
   hand, make the edit, then **add the chain to `change-map.json` in the same
   commit**. That is how the map stays true rather than decaying into fiction.

4. **Note the `laws` field.** It lists the CLAUDE.md laws this kind of change
   has broken before.

## After you edit

```powershell
python tools/kb_check.py
```

Eight checks, and they are honest about their own limits — `--list` prints what
is verified mechanically *and what is not*. Then run the tier that matches:

```powershell
python tools/verify.py --for core     # or rules / data / story / scenes / ui
```

## Reading the output

- **`ok`** — checked and clean.
- **`gap`** — a real defect that has been deliberately accepted, with a reason,
  in `docs/architecture/known-gaps.json`. Still printed every run so it cannot
  fade into the background. Do not add to that file to make a check go quiet;
  add to it only when the fix genuinely belongs to somebody else or costs money
  the owner has not agreed to spend, and always name where the real work is
  tracked.
- **`FAIL`** — propagation did not happen. The message names what is missing.

A gap that has since been fixed also fails, deliberately: it forces
`known-gaps.json` to be pruned rather than becoming a list of things that were
repaired long ago.

## The chains worth knowing by heart

**A new quest** needs a launcher in `play/parts.json` (then `play.ps1
-Install`). `tools/tour_all.py` reads `quests.json` directly, so photography
never drifts — but the launchers are a hand-kept manifest, and all six core
Chapter 1 quests had silently fallen out of it.

**A new `class_name` script or any new image** needs
`godot --headless --path game --import` before anything can see it. Without it
a new class fails to parse with "not declared in the current scope", and new
art renders as a black placeholder — indistinguishable from a file that is
genuinely missing.

**A tuning number** belongs in `game/data/rules.json` *and* in
`Rules.DEFAULTS`; `tests/unit/test_rules.gd` fails the moment they disagree.
Then re-run the sim and the fuzzer — the sim asks whether the fight is fair,
the fuzzer asks whether it can be broken, and neither substitutes for the
other.

**A new minigame module** needs all five pieces — rules class, screen, content
file, launch spec, bot — plus its name in `tools/kb_check.py`'s `MODULES` so
the five-piece check covers it from then on.
