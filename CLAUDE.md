# SparkyGames — Project Instructions

*The Nine Lives of Ash.* Mobile roguelite card game (fantasy, story-driven,
3–5 minute runs) for iOS and Google Play. Offline-first, single player,
standalone story.

**Before changing anything you have not changed before, read
[`docs/architecture/README.md`](docs/architecture/README.md)** — it says where
each kind of thing lives. When you change something,
[`docs/architecture/change-map.json`](docs/architecture/change-map.json) says
everywhere else it has to reach, and `python tools/kb_check.py` proves it got
there.

---

## Verify with one command

```powershell
python tools/verify.py fast        # ~20s   before saying "that should work"
python tools/verify.py standard    # ~4min  before every commit
python tools/verify.py full        # ~20min before an owner review
python tools/verify.py --for scenes   # picks the tier from what you touched
```

`--for` takes `core`, `rules`, `data`, `story`, `scenes`, `ui`, `docs`, `tools`.
Individual harnesses are listed in the architecture README; run them directly
when you want one. **The tour writes images; it does not look at them.** Law 1
still means you read the screenshots yourself.

Godot binary: `C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe`

---

## The laws

Each of these cost a review cycle. The tag says whether a machine catches a
violation or whether it is on you. **Anything marked `[judgement]` is a place
where nothing will stop you** — those are the ones to slow down for.

### Seeing the work

1. **See it before you say it's done.** `[judgement]` No visually-affecting
   change is finished until you have run the tour and *Read the shots*. Compare
   against `assets/library/mockups/ui_objective.png` and `reference/`. Use
   `/uitour`. This applies to art as much as to screens — reading is how we
   caught an unexplained human girl in an enemy portrait and a doubled word in
   the title logo.
2. **Photograph EVERY quest, not just the prologue.** `[enforced: tools/tour_all.py
   + tests/page_guard.gd]` A battle screen hanging off the right edge of the
   book reached an owner review unseen because the tour only ever walked the
   prologue. A quest nobody photographs is a quest nobody has looked at.
   Wrong-shaped screen? Ask the engine: `godot --path game -- --rect-probe
   --scene <spec>`.
3. **Run `/ownerpass` before saying anything is ready to review.** `[judgement]`
   Every owner review so far returned the same classes of defect — encounters
   with no story reason, terms shown before they are explained, rules the game
   enforces but never states. All findable without the owner. **Never report
   "ready" with a known unfixed defect unmentioned.**

### Layout and text

4. **Layout is calibrated, never guessed** (owner's method). `[partly enforced:
   tests/unit/test_layout.gd]` (1) black rectangle tuned snug inside the page's
   dashed stitching → `UITheme.PAGE_MARGIN_*` = 68/40/70/136, content 582x1104;
   (2) coloured zone boxes divide the content area *before* real widgets go in
   (`tests/calibrate.gd -- zones battle|story|choice|hub`); (3) calibrate font
   size and character budget with `measure_text` so text fits *before*
   placement; (4) only then place final objects. Re-run step 1 whenever the
   page art changes. Screens read the constants — never hand-edit margins.
5. **No guessed text boxes.** `[judgement]` Every container holding text sizes
   itself via `UITheme.measure_text` with the label's wrap width **equal** to
   the measured width. A narrower wrap adds lines the measurement never saw —
   the too-small-bubble bug. When containers fight you, set both panel and
   label rects explicitly (see Coach).
6. **Screens keep FIXED zone templates.** `[enforced: tests/unit/test_layout.gd]`
   Zone heights are named consts at the top of each scene script and must sum
   (with separations) to `UITheme.CONTENT_HEIGHT` exactly. New content goes
   INTO an existing zone — floating extras broke the budget twice. If content
   truly needs room, change the template FIRST and verify with the zone map.
7. **Every guided/modal state needs an escape path, and the tour must drive
   it.** `[partly enforced: tour tap-budget failsafe]` Coach steps pointing at
   non-interactive targets were only skippable (stuck players); an unwinnable
   charge loop ran the tour to 2,000 screenshots. Dim-taps advance; keep both
   when adding modal flows.
29. **The type floor: no player-facing text below 22px; body text is 30.**
   `[enforced: tests/unit/test_typography.gd]` The owner flagged small text on
   EVERY screen reviewed (2026-08-09 standing order: "actively corrected so I
   don't need to comment each time"). Use `UITheme.TYPE_*` (TITLE 44 /
   HEADING 34 / BODY 30 / SUPPORT 26 / FLOOR 22); the battle screen is the
   calibration reference. Raising a size means re-measuring its zone (law 4).
   Genuinely non-player-facing text carries `# type-floor-exempt: <why>`.
   The screenshot-critic hunts what the scanner cannot see.

### Content and code

8. **`game/core/` is pure rules.** `[judgement]` RefCounted only — no Node, no
   rendering, no FileAccess, no global RNG. Randomness through `CoreRng`;
   player actions through `CombatState.do_command()`, recorded in `CommandLog`.
   Load-bearing for deterministic tests, the sims and replay debugging (there
   is no PvP, ever — the determinism is for us).
9. **Player-facing prose lives in JSON, never in `.gd`.** `[partly enforced:
   tests/unit/test_strings.gd]` Story, rules text, coach lines, notices, quest
   beats, interface prose: `story/*.json`, `data/*.json`. A string a writer
   might want to change must not require editing a program — and a string
   inside code is a string no content tool can validate, translate or review.
10. **Tuning numbers live in `data/rules.json`.** `[enforced:
    tests/unit/test_rules.gd]` Costs, caps, limits, rates, prices, the starting
    kit. `Rules.DEFAULTS` holds the shipped values as a fallback and the test
    fails the moment the two disagree. If changing a number can only break the
    build rather than change the game, it is structure and stays a const.
11. **Content lives in `game/data/*.json` with stable string ids.**
    `[enforced: Catalog.validate()]` Never hardcode content values in scripts.
    Add validation when you add a content field.
12. **Player-facing text is validated, not remembered.** `[enforced:
    Catalog.validate()]` The fourth humour's data id is `mysticism`; the player
    only ever sees **Moonlight**. Code goes through `Catalog.humour_name()` —
    but hand-written `rule_text` did not, and shipped for a chapter.
13. **Energy never reshuffles; spent is spent.** `[judgement]` Do not "fix"
    this in a refactor.
14. **New profile keys need `DEFAULT_PROFILE` + a migration thought.**
    `[partly enforced: tests/unit/test_save.gd]` Old saves merge against
    defaults. Ask "what does an old save IMPLY?" — a finished prologue implies
    its grants.
15. **Repeated content must vary.** `[partly enforced: tools/art_repetition.py]`
    Anything shown many times in a run — the Hollow Court after each death
    above all — needs genuine variants. A death that reads identically to the
    last death tells the player nothing happened.
16. **No illustration carries more than 3 consecutive story beats** (owner
    2026-08-05). `[enforced: tools/art_repetition.py]` Past that a scene stops
    reading as a place and starts reading as one photograph with different
    captions under it. The fix is usually a second VIEW of the same location.

30. **Prose keeps the house style — checked, not remembered.** `[partly
   enforced: story-critic house-style section]` Deduced from the owner's own
   line edits (2026-08-10): referents resolve on the card they appear on
   (lines display one per card); metaphors must cash out to a concrete
   meaning; timeline claims are literal ("everyone this week said sorry" when
   nobody had spoken); never narrate the feeling the action already carries;
   **no mechanics exposition in narrative voice and no future-telling** —
   narration reports what happened, never what the game will do later; a
   motif is said once, ever; rewards need a diegetic payer; a retried quest
   must not re-meet people (`when_attempt`). Run the story-critic after ANY
   content change and fix matches without being asked.

### Testing

17. **Tutorial promises must be deterministic.** `[judgement]` If a coach step
    tells the player to do X, the scene data must guarantee X is possible
    (`shuffle: false` + ordered deck). Every post-battle story scene needs
    `when_outcome` variants — victory text after a retreat is a canon bug.
18. **After touching enemies/skills/costs, run the sim.** `[judgement]`
    `godot --headless --path game -s tests/simulate.gd`, then eyeball the table
    against `docs/design/balance-notes.md`.
19. **Playtest the irregular, not just the sensible.** `[enforced:
    tests/fuzz.gd]` The balance sim plays well; players do not. Run
    `/chaosplay` after ANY change to `core/` rules, commands, skills, enemies
    or environments. Chief invariant: **a rejected command must change
    nothing** — that one caught a real defect where a fumbled tap silently
    burned the player's approach. New mechanic ⇒ new persona and/or new
    invariant. **"Nobody would do that" is a bug report, not a defence.**
20. **A test you have to register is a test that never runs.** `[enforced:
    tests/run_tests.gd]` Discovery is automatic — every `test_*.gd` in
    `tests/unit/` runs. Writing the file IS registering it.
21. **A dev launch arrives EQUIPPED.** `[judgement]` The throwaway profile
    starts with Scratch alone, so every quest ever photographed was fought
    bare-clawed — which is not the game. `_equip_for_testing()` gives dev
    launches a full tray and a purse. Test the fight that ships.

### Traps that cost real time

22. **Never trust generated textures' geometry.** `[judgement]` AI assets carry
    opaque backgrounds and/or transparent padding. Paid for already: textured
    button styleboxes rendered smaller than their buttons (use the DRAWN
    styleboxes in UITheme); the rope "texture" was 15% rope, 85% transparent
    canvas (use `ThreadBar._content_region`-style opaque-band detection before
    region-drawing any art). Read every processed asset image before wiring it.
23. **New files need an import pass before anything can see them.**
    `[enforced: tools/kb_check.py for art]` The game binary never imports. After
    adding images to `game/assets/` **or a new `class_name` script**, run
    `godot --headless --path game --import` once — otherwise the tour shows
    black placeholders for files that plainly exist, and a new class fails to
    parse with "not declared in the current scope". Cost two full tour cycles
    and one debugging detour. Wiring art is `python tools/wire_assets.py` —
    never hand-copy from `assets/library/`.
24. **Never round-trip `.gd`/`.md` through PowerShell `Get-Content`/
    `Set-Content`.** `[enforced: .claude/settings.json hook]` PS 5.1 misdecodes
    UTF-8 and mints mojibake (—, ●, ❋ destroyed once already). Use the
    Edit/Write tools, or `[IO.File]::ReadAllText/WriteAllText` with UTF-8
    no-BOM.
25. **Never clear a container that holds a sibling you keep a handle on.**
    `[judgement]` `_refresh_hand_fan` used to clear `hand_fan`, which freed the
    `banked_row` living inside it; every later `_refresh()` then died
    *half-done*. Six entries on one defect list were all this one line.
    Rebuildable content gets its OWN child layer.
26. **Failed Godot API call? Diagnose, don't thrash.** `[judgement]` Write a
    10-line SceneTree diagnostic instead of guessing variants. Known traps:
    `set_anchors_preset` keeps the rect (use `set_anchors_and_offsets_preset`);
    `StyleBoxTexture` has `set_texture_margin_all` not `set_texture_margin_size`;
    tiled `draw_texture_rect` needs `texture_repeat`; autowrap Labels reserve no
    height inside H/VBox; **Godot's JSON parser returns every number as a
    float**, so `12` from a file never strictly equals the int `12` in code.
27. **A stale Godot process holds the `.godot` lock and hangs everything.**
    `[judgement]` If a headless run takes minutes instead of seconds, check for
    leftover instances (`Get-Process Godot*`) and kill them before debugging
    anything else.
28. **Background agents that stall get one SendMessage nudge** telling them to
    finish from what they have with minimal extra searching.

---

## Owner standing decisions

These override anything older you may read in a doc.

- **No PvP / no multiplayer, ever** (2026-08-02). Do not propose PvP-motivated
  work. Determinism stays for tests, sims and replay debugging.
- **"Moonlight"** is the fourth humour's player-facing name; data id stays
  `mysticism` for save stability.
- **No endless/daily prowls.** Standalone story with hand-designed missions,
  plus auto-generated cases as replayable side content.
- **AI honesty.** Development leans heavily on AI (art, music, code). Not a
  selling point, not hidden. Never claim hand-made. See
  `docs/design/ai-transparency.md`.
- **Five minigames approved** (2026-08-03, spec in `docs/design/minigames.md`).
  Do not build unpromoted ones.
- **Free at launch, with a donation tip jar; Chapter 2 sold when ready**
  (2026-08-31). Supersedes the free-Ch1 + $6.99-unlock model. What shipped
  free stays free forever. See `docs/design/monetization.md`.
- **Every choice needs a consequence**; repetition is the enemy; notifications
  never mix with narrative; text is short, big, and fits; the opponent is the
  biggest thing on screen.

### Product constraints (no violation without owner sign-off)

- A complete run must fit in 3–5 minutes.
- Fully playable offline.
- Story/quests are core, not decoration.
- Monetization must not gate offline single-player progress behind connectivity.

---

## Art

**`/genart` is the workflow** for any request to create, change, fix or
regenerate an image. Model `gpt-image-2`, ~$0.19/image, billed separately from
any ChatGPT plan — so generation **spends real money and should be confirmed**.

1. **Check `assets/library/<kind>/` FIRST.** Never generate what exists — a
   duplicate wastes money and forks the canon.
2. **Changing an existing image? Check `assets/archive/` first.** An earlier
   take is often already what's wanted, and restoring one is free.
3. **`assets/library/` holds only images the game uses.** Everything superseded
   lives in `assets/archive/`. **Never delete art — archive it.**
4. **Recurring characters are generated FROM a reference image**
   (`tools/genart.py --ref <file>`), never from a text description. Words let a
   character drift — Ash came back a different breed once. Every character
   appearing more than once needs a `ref_<name>.png` before their second
   appearance.
5. **Framing:** enemies are scene vignettes (subject dominant, setting
   dissolving into wash — `en_chained_dog` is the reference). Skill cards are
   the subject on plain parchment, no environment.
6. **Prologue canon: Ash has NO red neckerchief.** He takes it in `sc_collar`,
   the last beat before the title card. Correct everywhere after.
7. **Use `STRICT_STYLE`** — it names the failure modes as explicit negatives,
   which is the only thing that reliably prevents full-bleed digital drift.
   Logos and UI mockups skip the style block (`--no-style`).
8. **Read every generated image before calling it done.** For UI, *measure*
   rather than eyeball — content under ~60% of canvas renders tiny for its box,
   and that wants a crop, never a regeneration.
9. **Prefer editing over re-rolling.** A from-scratch variant invents new
   content; `--ref` keeps it provably the same subject.

Track needs in `docs/design/art-needed.md`. Audit batches with the
`asset-auditor` agent.

---

## Conventions

- **Commit regularly** — after every meaningful unit of work. **Push at the end
  of every session.** Remote is `origin` → github.com/phirogue/SparkyGames.
  Short imperative summary; body explains *why* when it isn't obvious.
- Never commit secrets, keystores, certificates or store credentials.
- Design decisions live in `docs/design/`, one topic per file. **The docs are
  the source of truth, not chat history** — when a decision is made, update the
  doc.
- `docs/research/` is read-only dated history: write a new doc rather than
  rewriting an old conclusion.
- `docs/brainstorm/` keeps rejected ideas — they explain why the chosen
  direction won.
- **Generated files say so in their header** and are rebuilt, never edited:
  `docs/design/bestiary.md`, `play/apps/*.cmd`, `screenshots/` (except
  `reference/`).
- GDScript: typed where practical, tabs, snake_case, `class_name` for shared
  classes. Scenes subscribe to core state; they never mutate it directly.
- Every new rule or bug fix gets a `test_*` method in `game/tests/unit/`.

### Getting to a thing without playing to it

- **Developer Mode:** `godot --path game -- --scene dev` — one in-game list
  that jumps to every screen, beat, fight, prowl, minigame and saved state.
  Built FROM the catalog and story files, so new content appears with no code
  change.
- **Component runner:** `godot --path game -- --scene <spec>` where spec is
  `dev`, `hub`, `title`, `journal`, `case`, `recap`, `story:<index>`,
  `battle:<encounter_id>[:skill,...]`, `quest:<quest_id>`, `scenario:<name>`,
  or a minigame (`stitch:<id>`, `testimony:<id>`, `ward:<id>`, `lattice:<id>`,
  `crossing:<id>`). Throwaway profile — never writes the real save.
- **Scenario runner:** reproduce ANY player state from a JSON spec in
  `game/tests/scenarios/`. When a bug report says "only happens when…", encode
  that state as a scenario so the repro is one command forever. A scenario can
  be *photographed* rather than played — the only way to shoot states the
  prologue never reaches: `godot --path game -- --tour --tour-out <dir>
  --scene scenario:<name>`.
- **Launchers:** `play/apps/*.cmd`, double-clickable. Add a part by editing
  `play/parts.json` and running `play.ps1 -Install` — **never** by hand-writing
  a shim.
