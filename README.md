# SparkyGames — *The Nine Lives of Ashcat*

A brand-new mobile roguelite card game for iOS (App Store) and Android
(Google Play). You are Ash, a murdered witch's cat familiar, spending your
nine lives to solve her murder in the fog-bound city of Hollowmere.

## Vision

- **Genre:** Roguelite deckbuilder card game
- **Setting:** Original fantasy world
- **Session length:** Each run is playable in **3–5 minutes**
- **Narrative:** Quest- and story-driven — the story is the reason you keep playing
- **Offline-first:** Fully playable with no connection

## Play the current build (Windows)

Double-click **`run_game.bat`** in the repo root — it opens the game in a
phone-shaped window (requires the Godot binary at
`C:\Users\yurim\tools\godot\`, already set up). Current build: the four
prologue encounters as one continuous prowl — tap skills to fight, tap hand
cards to bank them, End Turn / Slip Away below. Or open the project in the
Godot editor (`game/` folder) and press F5.

## Repository layout

The code is an **engine**; the game is **JSON**.

```
game/
  core/          pure rules — RefCounted only, no Node/FileAccess/global RNG
  services/      the only layer that touches the disk (content, save, prose)
  scenes/        UI; game.gd is the one file that decides what comes next
  ui/            shared widgets and the layout contract (UITheme)
  data/          content + tuning as JSON, keyed by stable string ids
  story/         prose — prologue/ (one file per arc) and world/ (canon)
  tests/         unit tests, the tour, the balance sim, the chaos fuzzer
docs/
  architecture/  HOW IT FITS TOGETHER — read this before changing anything
  design/        design documents (ART-INDEX.md indexes the art ones)
  research/      dated reports; read-only history
  brainstorm/    idea explorations, including rejected ones
tools/           verification and generation scripts (verify.py, kb_check.py)
  batches/       one-off generation runs, kept as history
play/            double-clickable launchers, generated from parts.json
assets/          the art library and its archive
screenshots/     tour output — generated and untracked, except reference/
```

## Working on it

```powershell
python tools/verify.py fast        # ~20s   before saying "that should work"
python tools/verify.py standard    # ~4min  before every commit
python tools/verify.py full        # ~20min before a review
python tools/kb_check.py           # did the change reach everywhere?
```

[`docs/architecture/README.md`](docs/architecture/README.md) says where each
kind of thing lives.
[`change-map.json`](docs/architecture/change-map.json) says, for each kind of
change, everywhere else it has to reach.

## Status

**Playable prologue build.** The full prologue runs end to end in Godot 4
(GDScript), backed by a unit-test suite, bot-playtest balance simulations
(`tests/simulate.gd`), and an automated screenshot tour for UI verification.
Decided: the Ashcat premise; wry-cute low-text tone; energy-deck +
equipped-skills combat; free Chapter 1 + single unlock, fully offline.
**Chapter 1 is in design** — content designs live in
`docs/design/chapters/`. Publishing prep (store accounts, compliance) is
tracked in `docs/publishing/` and `docs/OWNER-ACTIONS.md`.

## Development rules

See [CLAUDE.md](CLAUDE.md). Key rule: commit early, commit often, and push
after every working session.
