# Architecture — how this game is put together

Read this before changing anything you have not changed before. It answers two
questions: **where does this kind of thing live**, and **when I change it, what
else has to move**.

- Machine-readable propagation chains: [`change-map.json`](change-map.json)
- Prove the propagation happened: `python tools/kb_check.py`
- The invariants that cost a review cycle each: [`../../CLAUDE.md`](../../CLAUDE.md)

---

## The shape of it

The code is an **engine**. The game is **JSON**. That split is the point, and
most of the maintenance rules below exist to keep it honest.

```
game/
  core/       PURE RULES. RefCounted only — no Node, no rendering, no
              FileAccess, no global RNG. Randomness goes through CoreRng;
              player actions go through do_command() and land in CommandLog.
              This is load-bearing for deterministic tests, the balance sims
              and replay debugging. There is no PvP and never will be — the
              determinism is for US.

  services/   THE ONLY LAYER THAT TOUCHES THE DISK.
              DataLoader   content JSON -> Catalog
              SaveService  the player's profile, versioned, temp-write + backup
              Strings      interface prose from story/interface.json
              MusicService the score: two players, one crossfade, and the rule
                           that asking for the track already playing does
                           nothing (a story beat swaps screens every page)

  scenes/     UI. Screens subscribe to core state and never mutate it.
              game.gd is the flow orchestrator: the one file that decides
              what comes next. Everything else is a dumb page.

  ui/         Shared widgets and the layout contract (UITheme).

  data/       CONTENT + TUNING, keyed by stable string ids.
  story/      PROSE. Scene scripts, and the game's own voice.
  tests/      Unit tests, plus the harnesses that are the real safety net.
  assets/     The shipped images and music, wired from assets/library by a
              script (tools/wire_assets.py, tools/wire_music.py).
```

### Which file owns a number

| The number is… | It lives in | Example |
|---|---|---|
| a balance decision | `data/rules.json` | hand limit, the Toll, Magpie prices |
| a piece of content | `data/*.json` | an enemy's hp, a skill's cost |
| page geometry | the screen's own `ZONE_*` consts | `ZONE_OPPONENT := 394` |
| the page itself | `UITheme.PAGE_MARGIN_*` | 68/40/70/136 |
| structure | a `const` in the class that owns it | `ProwlScript.BATTLE` |

If changing it can only break the build rather than change the game, it is
structure. Otherwise it is a dial, and dials live in `rules.json`.

### Which file owns a sentence

**Player-facing prose never lives in a `.gd` file.** A string embedded in code
is a string no content tool can validate, translate or review.

| The words are… | They live in |
|---|---|
| a prologue scene | `story/prologue/<arc>.json` (order in `index.json`) |
| worldbuilding the game reads | `story/world/*.json` |
| the game's own voice (prowl book-keeping, chronicle, captions) | `story/interface.json` |
| a quest beat | `data/quests.json` |
| a teaching page | `data/lessons.json` |
| a rule card, a name, a blurb | the content record in `data/*.json` |

### Which file owns a sound

A **place** owns its music, not a screen: `environments.json` carries `music`
beside `image`, so the Hollow Court sounds like the Hollow Court whether the
player arrived by dying, by a story beat or from the dev menu.

| The track is for… | It is named in |
|---|---|
| a place | `data/environments.json` → `music` |
| a screen (title, hub, journal, exchange…) | `data/music.json` → `screens` |
| a mission module | `data/music.json` → `minigames` |
| a fight the story treats as more than a fight | `data/encounters.json` → `music` |
| every other fight | `data/music.json` → `defaults.battle` |

Silence is only ever deliberate — a key mapped to `""`. A key that is simply
MISSING falls back to the bed rather than going quiet, because a room that
suddenly plays nothing reads as a broken game and nobody files it as a bug.
`godot --path game -- --tour --music-log` prints what every screen plays;
it is the only way to inspect a system screenshots cannot see.

---

## The verification harnesses

These are not optional extras — each one exists because something shipped past
a review without it.

| Harness | Command | Answers |
|---|---|---|
| unit tests | `godot --headless --path game -s tests/run_tests.gd` | do the rules still hold? |
| propagation | `python tools/kb_check.py` | did the change reach everywhere? |
| screenshot tour | `godot --path game -- --tour` | what does it actually look like? |
| every-quest sweep | `python tools/tour_all.py` | …including content that is not the prologue |
| page guard | (runs inside the tour) | is anything off the page? |
| balance sim | `godot --headless --path game -s tests/simulate.gd` | is the fight fair? |
| chaos fuzzer | `godot --headless --path game -s tests/fuzz.gd -- --seeds 60` | can it be put in a state it should not be in? |
| minigame bots | `godot --headless --path game -s tests/minigames.gd` | are the puzzles playable and unbreakable? |
| art repetition | `python tools/art_repetition.py` | has one illustration gone flat from overuse? |

**The sim and the fuzzer are not substitutes for each other.** `simulate.gd`
asks *is this fair?* with bots that play well. `fuzz.gd` asks *can this break?*
by playing badly on purpose. The first real defect the fuzzer found was a
fumbled tap silently burning the player's approach — no sensible bot would
ever have found it.

---

## Traps already paid for

Each of these cost real time at least once. The full list with rationale is in
CLAUDE.md; these are the ones that bite during ordinary work.

- **A new `class_name` script needs an import pass** before anything can see it.
  `godot --headless --path game --import`. Same for new images — without it the
  tour renders black placeholders for files that plainly exist.
- **`set_anchors_preset` keeps the old rect.** Use
  `set_anchors_and_offsets_preset`, or tap targets collapse to zero size.
- **Autowrap labels reserve no height** inside an H/VBox. Measure with
  `UITheme.measure_text` at a wrap width *equal* to the label's width — a
  narrower wrap adds lines the measurement never saw.
- **Never clear a container holding a sibling you kept a handle on.** Freeing
  `banked_row` along with the hand fan produced six separate defects from one
  line. Rebuildable content gets its own child layer.
- **Never round-trip text through PowerShell `Get-Content`/`Set-Content`.**
  PS 5.1 misdecodes UTF-8 and mints mojibake. A hook now blocks this
  (`tools/hooks/guard_encoding.py`).
- **Generated files are generated.** `docs/design/bestiary.md` is rebuilt from
  the enemy data; hand-edits are erased on the next run.

---

## Adding something new

Look it up in [`change-map.json`](change-map.json), walk the `touch` list in
order, run everything in `verify`. The chains covered today:

`add-or-change-a-skill` · `add-an-enemy` · `add-a-quest` · `add-a-screen` ·
`add-a-minigame-module` · `change-a-tuning-number` · `add-a-profile-field` ·
`add-or-change-art` · `change-player-facing-prose` · `change-the-layout-contract`

`kb_check.py --list` prints what is verified mechanically **and what is not** —
the gaps are stated rather than assumed away.
