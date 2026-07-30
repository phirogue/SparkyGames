# SparkyGames — *The Nine Lives of Ashcat*

A brand-new mobile roguelite card game for iOS (App Store) and Android
(Google Play). You are Ash, a murdered witch's cat familiar, spending your
nine(-thousand) lives to solve her murder in the fog-bound city of Hollowmere.

## Vision

- **Genre:** Roguelite deckbuilder card game
- **Setting:** Original fantasy world
- **Session length:** Each run is playable in **3–5 minutes**
- **Narrative:** Quest- and story-driven — the story is the reason you keep playing
- **Offline-first:** Fully playable with no connection
- **Multiplayer:** Architecture keeps the door open for PvP against other players later
- **Art:** Card illustrations generated in Midjourney, provided by the project owner

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
src/             Game source code (engine TBD from tech research)
assets/          Card art, UI, audio (Midjourney images land here)
```

## Status

**Phase 1 — Design.** Research complete (market, monetization, tech stack,
tabletop mechanics — see `docs/research/`). Story, world, core gameplay, and
monetization directions drafted in `docs/design/`. Decided: the Ashcat
premise; wry-cute low-text tone; energy-deck + equipped-skills combat; free
Chapter 1 + single unlock, fully offline; **engine: Godot 4 + GDScript**.
Prologue and Chapter 1 content designs are in `docs/design/chapters/`. Next:
Godot project scaffold, art manifest, Google Play account creation (see
`docs/publishing/`).

## Development rules

See [CLAUDE.md](CLAUDE.md). Key rule: commit early, commit often, and push
after every working session.
