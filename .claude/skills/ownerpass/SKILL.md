---
name: ownerpass
description: The full pre-review pass — everything the owner would catch, caught first. Sweeps every quest for layout defects, checks art repetition, and runs the story and first-time-player critics. Run BEFORE telling the owner anything is ready to review, and on a regular cadence while building. Usage: /ownerpass [what changed]
---

# Owner pass — find it before the owner does

Every owner review so far has come back with the same *kinds* of defect:
content off the page, encounters with no story reason, terms shown before
they are explained, an image repeated until the scene goes flat, a rule the
game enforces but never says. All of them are findable without the owner.

This skill is that search. **Run it before saying anything is ready to
review**, and after any batch of content work.

## 1. Green before you look at anything

```bash
& "C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe" --headless --path game -s tests/run_tests.gd
```

Fix failures first — a red suite makes every later result untrustworthy.

## 2. Sweep every quest, not just the prologue

```bash
python tools/tour_all.py
```

Photographs the prologue and **every quest** into `screenshots/`, and fails
on any content outside the page (`tests/page_guard.gd` checks each shot
mechanically — Godot knows the rects; nobody has to notice by eye).

A failing leg prints the offending node paths. To find out *why* a screen is
the wrong shape, ask the engine rather than reading the code:

```bash
godot --path game -- --rect-probe --scene battle:<encounter_id>
godot --path game -- --rect-probe --scene quest:<quest_id>
```

Dev launches arrive EQUIPPED (a full five-card tray), so what you photograph
is the fight the game actually ships — not a bare-clawed version of it.

## 3. Check the pictures are doing work

```bash
python tools/art_repetition.py --list
```

Ceiling: **no illustration carries more than 3 consecutive story beats**
(owner rule 2026-08-05). Over that, the scene stops feeling like a place and
starts feeling like one photograph with captions under it. The fix is
usually a second view of the same location, not a different location.

## 4. Read the shots

Not all of them — the ones the change touched, plus every `*_battle_open_*`
and every `*_story_choices*`. Use the **screenshot-critic** agent for a
sweep of a whole folder.

## 5. Run the two critics

Launch both in one message so they work in parallel:

- **story-critic** — why is this fight happening, who is saying this line,
  is a term shown before it is explained, is the picture repeated, does this
  beat earn its page, is the tone right.
- **first-timer** — what rule does the game enforce but never say, what
  number has no meaning, what tutorial forces one action, what tooltip does
  not change with the state it describes.

Give each of them **what changed**, so they weight recent work.

## 6. If rules changed, prove nothing broke

```bash
godot --headless --path game -s tests/fuzz.gd -- --seeds 60      # /chaosplay
godot --headless --path game -s tests/minigames.gd
godot --headless --path game -s tests/simulate.gd                # /simbalance
```

## 7. Report

Say what you ran, what it found, and what you fixed — in that order. List
anything you found and did NOT fix, and why. **Never report "ready to
review" with a known unfixed defect unmentioned**; the owner will find it,
and finding it costs a whole review cycle.

## Cadence

Run the whole thing:
- before any "this is ready" message to the owner,
- after any batch of story or quest content,
- after any change to `core/` rules, the coach, or lessons,
- and at least once per working session that touched `game/`.

Steps 1–3 are cheap and scriptable; run them even when you are only halfway
through a change.
