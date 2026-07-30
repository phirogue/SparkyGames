# SparkyGames — Project Instructions

Mobile roguelite card game (fantasy, story-driven, 3–5 minute runs) for iOS and
Google Play. Offline-first single player at launch; PvP possible later. Card art
comes from Midjourney, provided by the project owner.

## Git rules (important)

- **Commit regularly.** After every meaningful unit of work — a finished
  document, a working feature, a set of related edits — make a commit. Do not
  let uncommitted work pile up across multiple tasks.
- **Push at the end of every working session**, and after any commit that
  completes a milestone. Remote is `origin` → github.com/phirogue/SparkyGames.
- Commit messages: short imperative summary line, body explaining *why* when it
  isn't obvious.
- Never commit secrets, keystores, signing certificates, or store credentials.
  Keep those out of the repo (see .gitignore).

## Engine & code conventions (Godot 4.4.x, GDScript)

- Local Godot binary: `C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe`
- Run tests after any change to `game/`:
  `& "C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe" --headless --path game -s tests/run_tests.gd`
- **`game/core/` is pure rules**: RefCounted classes only — no Node, no
  rendering, no FileAccess, no global RNG. All randomness goes through
  `CoreRng`; all player actions go through `CombatState.do_command()` and are
  recorded in `CommandLog`. This is load-bearing for replays and future PvP.
- Content lives in `game/data/*.json` with stable string ids; never hardcode
  content values in scripts. `Catalog.validate()` must stay green — add
  validation when adding content fields.
- Energy never reshuffles; spent is spent. Do not "fix" this in a refactor.
- GDScript style: typed where practical, tabs for indentation, snake_case,
  `class_name` for shared classes. Scenes subscribe to core state; they never
  mutate it directly.
- Tests: add a `test_*` method to `game/tests/unit/` for every new rule or
  bug fix; register new test files in `tests/run_tests.gd`.

## Project conventions

- Design decisions live in `docs/design/`; one topic per file. When a decision
  is made, update the doc — the docs are the source of truth, not chat history.
- Research reports live in `docs/research/` and are read-only history: write a
  new dated doc rather than rewriting an old conclusion.
- Brainstorms and rejected ideas live in `docs/brainstorm/` — keep them, they
  explain why the chosen direction won.
- Card art from Midjourney goes in `assets/cards/` named after the card's id
  (e.g. `ember_fox.png`). Track art needs in `docs/design/art-manifest.md`.

## Product constraints (do not violate without owner sign-off)

- A complete run must fit in 3–5 minutes.
- The game must be fully playable offline.
- Story/quests are core, not decoration — features should serve the narrative
  loop.
- Monetization must not gate offline single-player progress behind connectivity.
