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
- Component runner — test ONE piece without a full playthrough (throwaway
  profile): `godot --path game -- --scene <spec>` where spec is `hub`,
  `title`, `journal`, `story:<index>`, or
  `battle:<encounter_id>[:skill,skill,...]`
  (e.g. `--scene battle:prologue_wraith:pounce,slink,purr`).
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

## Hard-won engineering laws (each of these cost a review cycle — obey)

1. **See it before you say it's done.** Any visually-affecting change MUST be
   verified by running the screenshot tour and Reading the key shots BEFORE
   claiming completion:
   `& "C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe" --path game -- --tour`
   Shots land in `screenshots/`. Compare against `assets/incoming/ui_objective.png`
   and `reference/`. Use the /uitour skill.
2. **No guessed text boxes.** Every container that holds text sizes itself
   via `UITheme.measure_text` with the label's wrap width EQUAL to the
   measured width (a narrower wrap adds lines the measurement never saw —
   the too-small-bubble bug). When containers fight you, set both panel and
   label rects explicitly (see Coach).
3. **Never trust generated textures' geometry.** AI-generated assets carry
   opaque backgrounds and/or transparent padding. Consequences already paid:
   textured button styleboxes rendered smaller than their buttons (use the
   DRAWN styleboxes in UITheme); the rope "texture" was 15% rope, 85%
   transparent canvas (use `ThreadBar._content_region`-style opaque-band
   detection before region-drawing any art). Read every processed asset
   image before wiring it.
4. **Never round-trip .gd/.md files through PowerShell Get-Content/
   Set-Content** — PS 5.1 misdecodes UTF-8 and mints mojibake (—, ●, ❋
   destroyed once already). Use
   `[IO.File]::ReadAllText/WriteAllText($f, $c, UTF8-no-BOM)`.
5. **Layout is calibrated, never guessed (owner's method).** Steps:
   (1) black rectangle tuned until snug inside the page's dashed stitching
   → `UITheme.PAGE_MARGIN_*` = 68/40/70/136, content 582x1104;
   (2) colored zone boxes divide the content area per screen type BEFORE
   real widgets go in (`tests/calibrate.gd -- zones battle|story|choice|hub`
   — keep the maps in sync with each screen's layout contract);
   (3) for each text box, calibrate font size and character budget with
   measure_text so everything fits BEFORE placement;
   (4) only then place final objects. Re-run step 1 whenever the page art
   changes. Screens read the constants — never hand-edit margins.
6. **Tutorial promises must be deterministic.** If a coach step tells the
   player to do X, the scene data must guarantee X is possible
   (`shuffle: false` + ordered deck). Every post-battle story scene needs
   `when_outcome` variants — victory text after a retreat is a canon bug.
7. **New profile keys need DEFAULT_PROFILE + a migration thought** — old
   saves merge against defaults; a finished prologue implies its grants.
8. **After touching enemies/skills/costs, run the sim** and eyeball the
   table against docs/design/balance-notes.md:
   `godot --headless --path game -s tests/simulate.gd`
9. **Failed Godot API call? Diagnose, don't thrash.** Write a 10-line
   SceneTree diagnostic (see tests/smoke_boot.gd's origin) instead of
   guessing variants. Known traps already hit: `set_anchors_preset` keeps
   the rect (use `set_anchors_and_offsets_preset`); `StyleBoxTexture` has
   `set_texture_margin_all` not `set_texture_margin_size`; tiled
   `draw_texture_rect` needs `texture_repeat` or manual region tiling;
   autowrap Labels reserve no height inside H/VBox.
10. **Background agents that stall get one SendMessage nudge** telling them
    to finish from what they have with minimal extra searching.
11. **New asset files need an import pass before they render.** The game
    binary never imports; after adding images to `game/assets/`, run
    `godot --headless --path game --import` once or the tour shows black
    placeholders for files that exist (cost one full tour cycle).

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
