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

```
docs/
  research/      Market, monetization, and tech-stack research reports
  design/        Game design documents (gameplay, story, cards, economy)
  brainstorm/    Idea explorations and concept pitches
game/            Godot 4 project — core/ (pure rules), scenes/, services/,
                 ui/, tests/, data/ (JSON content)
assets/          Card art, UI, audio (raw generated images land here)
reference/       Visual reference material for UI verification
screenshots/     Output of the automated screenshot tour
```

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
