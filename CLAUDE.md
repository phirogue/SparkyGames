# SparkyGames — Project Instructions

Mobile roguelite card game (fantasy, story-driven, 3–5 minute runs) for iOS and
Google Play. Offline-first, single player, standalone story — **no multiplayer,
ever** (owner decision 2026-08-02). Art comes from ChatGPT (stills) + Kling
(motion), provided by the project owner; music will be AI-generated. The
project is openly AI-assisted (see docs/design/ai-transparency.md) — never
market it as hand-made, never hide the AI either. The fourth humour's
player-facing name is **Moonlight**; its data id stays `mysticism` (save
stability) — UI must go through `Catalog.humour_name()`.

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
  world; NEVER writes the real save): `godot --path game -- --scene <spec>`
  where spec is `hub`, `title`, `journal`, `story:<index>`,
  `battle:<encounter_id>[:skill,skill,...]`, `quest:<quest_id>`, or
  `scenario:<name>`.
- Scenario runner — reproduce ANY player state (loadout, deck, gleam,
  carryover, pinned battle seed) from a JSON spec in
  `game/tests/scenarios/`; see that folder's README. When a bug report
  says "only happens when...", encode that state as a scenario so the
  repro is one command forever. A spec may carry its own story scenes, and
  a scenario can be PHOTOGRAPHED instead of played — the only way to shoot
  states the prologue never reaches (a case mid-chapter, a flashback):
  `godot --path game -- --tour --tour-out <dir> --scene scenario:<name>`.
  UI layout is shared via `UITheme.page_scaffold` — change the page once,
  every screen follows.
- **`game/core/` is pure rules**: RefCounted classes only — no Node, no
  rendering, no FileAccess, no global RNG. All randomness goes through
  `CoreRng`; all player actions go through `CombatState.do_command()` and are
  recorded in `CommandLog`. This is load-bearing for deterministic tests,
  the balance sims, and replay debugging (there is no PvP, ever).
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
   Shots land in `screenshots/`. Compare against `assets/library/mockups/ui_objective.png`
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
    placeholders for files that exist (cost two full tour cycles now).
12. **Screens keep FIXED zone templates.** Zone heights are named consts
    at the top of each scene script and must sum (with separations) to
    UITheme.CONTENT_HEIGHT exactly. New content goes INTO an existing
    zone — floating extras broke the budget twice (a hint label, toast
    lines injected into story text). If content truly needs room, change
    the template FIRST and verify with the calibrate zone map.
13. **Every guided/modal state needs an escape path, and the tour must
    drive it.** Coach steps pointing at non-interactive targets were
    only skippable (stuck players); an unwinnable charge loop ran the
    tour to 2,000 screenshots. Dim-taps advance; the tour has a
    tap-budget failsafe; keep both when adding modal flows.
14. **Playtest the irregular, not just the sensible.** The balance sim
    plays well; players do not. After ANY change to `core/` rules,
    commands, skills, enemies or environments, run the chaos harness —
    `godot --headless --path game -s tests/fuzz.gd -- --seeds 60` (use
    the /chaosplay skill) — which plays badly on purpose (hoarding,
    discarding everything, spamming approaches, illegal and malformed
    commands) and asserts the seven invariants in `tests/chaos_play.gd`.
    Chief among them: **a rejected command must change nothing.** That
    one already caught a real defect — a fumbled tap silently burned the
    player's approach, because `approach_locked` was set before the
    command was validated. New mechanic ⇒ new persona and/or new
    invariant; "nobody would do that" is a bug report, not a defence.
    The `chaos-playtester` agent designs new attacks when the sweep has
    been green for a while.

## Project conventions

- Design decisions live in `docs/design/`; one topic per file. When a decision
  is made, update the doc — the docs are the source of truth, not chat history.
- Research reports live in `docs/research/` and are read-only history: write a
  new dated doc rather than rewriting an old conclusion.
- Brainstorms and rejected ideas live in `docs/brainstorm/` — keep them, they
  explain why the chosen direction won.
- Generated card art (ChatGPT/Kling) goes in `assets/cards/` named after the card's id
  (e.g. `ember_fox.png`). Track art needs in `docs/design/art-needed.md`.

## Art library rules (owner, 2026-08-03 — obey before generating anything)

1. **Check the library FIRST. Never generate an image that already exists.**
   Before any generation, list `assets/library/<kind>/` and confirm the id is
   genuinely absent. A duplicate wastes money and forks the canon.
2. **Asked to CHANGE an existing image? Check `assets/archive/` before
   generating.** Older takes of most assets are archived; an earlier version is
   often already what's wanted, and restoring one is free and instant.
   Generate only after confirming the archive holds no suitable replacement.
3. **`assets/library/` contains ONLY images actually used by the game.**
   Everything superseded, rejected, or experimental lives in `assets/archive/`.
   Never delete art — archive it, so any version can be reviewed or restored.
4. **Recurring characters are generated FROM a reference image, never from a
   text description.** Words let a character drift (Ash came back a different
   breed once; a witch appeared in the cold parlor looking nothing like
   Elspeth). Use `tools/genart.py --ref <file>`, which posts to the images
   *edits* endpoint with the reference attached. Every character appearing
   more than once needs a `ref_<name>.png` in
   `assets/library/characters/` before their second appearance.
5. **Framing conventions:** enemies are **scene vignettes** (subject dominant,
   setting dissolving into wash behind it — `en_chained_dog` is the reference).
   Skill cards are the subject on **plain parchment**, no environment.
6. **Prologue canon: Ash has NO red neckerchief.** He takes it in `sc_collar`,
   the last beat before the title card. Any scene set earlier
   (`sc_vole_stalk`, `sc_ash_vole_gift`, `sc_over_the_fences`) must show him
   bare-necked. The neckerchief is correct everywhere after the title.
7. **Use `STRICT_STYLE`** from `tools/genart_fixes.py`, not the old style
   block. It names the failure modes as explicit negatives, which is the only
   thing that reliably prevents the full-bleed digital drift.

## Product constraints (do not violate without owner sign-off)

- A complete run must fit in 3–5 minutes.
- The game must be fully playable offline.
- Story/quests are core, not decoration — features should serve the narrative
  loop.
- Monetization must not gate offline single-player progress behind connectivity.
