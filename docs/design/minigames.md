# Mission minigames — committed designs

**Status:** owner-approved 2026-08-03. Five modules promoted from
`docs/brainstorm/minigames-for-missions.md` (which keeps the full
candidate list, tiers, and the kill list of rejected clichés). Still
pending owner thought: Pigeon Routes, Change-Ringing, Nine Pockets, and
the Tier-3 flavor bites — none may be built until promoted here.

> **Prototype status, 2026-08-03: all five are built and playable**, without
> art, as drawn geometry. Rules are pure core classes, content is data with
> validation, and a bot agent plays and stress-tests each one
> (`godot --headless --path game -s tests/minigames.gd`). Try any of them
> from `play/apps/` or Developer Mode (`--scene dev`).
> Findings, including one real design hole in The Long Way Round and the
> tuning it still needs, are in
> [2026-08-03-minigame-prototypes.md](../research/2026-08-03-minigame-prototypes.md).

Approved and in scope:

| # | Minigame | Mandate |
|---|---|---|
| 1 | Seam & Stitch | **Prototype FIRST** — owner wants to feel how it plays |
| 2 | Testimony | Core case mechanic; required by mid-Ch3 structurally |
| 3 | Patch the Ward | Core needlework system; feeds combat |
| 4 | The Unpicking | Heists + the killer's-verb beat |
| 5 | The Long Way Round | Traversal as **same deck, different actions** (owner framing) |

Shared rules for ALL modules (non-negotiable, from the laws):
one-thumb portrait inside the storybook zone template; 30–90 seconds per
beat; diegetic; failure is a story outcome with `when_outcome` prose
(success / partial / walk-away), never a game-over; deterministic under a
seed; a scenario spec + tour stop + unit tests per module; every module
gets an escape path and a tour tap-budget (law 13). Puzzle CONTENT lives
in `game/data/*.json` with stable ids and `Catalog.validate()` coverage —
adding a puzzle must never mean touching a scene script. All boards are
drawn (UITheme primitives, thread rendering), not generated art — no new
asset dependencies.

---

## 1. Seam & Stitch — the ritual loop [prototype first]

**Lineage:** Slitherlink. **Verb:** sew one closed seam.

A stitch chart: a small dot-grid (4x4 to 6x6), some cells numbered with
how many of their four edges the seam must use. Drag along edges to sew;
tap a stitch to unpick it (free — calm puzzle, no punishment for
thinking). Win: one single closed loop satisfying every number. The
thread renders as real stitching and cinches taut on completion.

- **Player aid, not timer:** optional `Squint` (cost: 1 paw) highlights
  one certainly-wrong stitch. No hints beyond that; charts stay small.
- **Mirror mode** (`mirrored: true`): the chart's clue numbers are shown
  as the reflection of the grid the player sews on — the Ch3 payoff where
  the player's own paw discovers what mirror-handed means
  (the-unraveler.md). Never used before Ch3.
- **Systems hooks:** completing a ritual grants its data-declared reward
  (evidence id / lingering `warmed` / story flag). Abandoning mid-chart =
  the walk-away outcome (the working "doesn't hold"; retry allowed, story
  notes it).
- **Data:** `game/data/stitch_charts.json` — id, grid size, clue map,
  `mirrored`, reward block, `when_outcome` text ids. Validate: clue
  values 0–3, at least one solution exists (validator may brute-force
  small grids at test time, not runtime).
- **First placement:** L4 Wickhouse re-warding (already committed as the
  ritual beat in chapter1-build-plan Phase 4). **Prototype now** as a
  component: `--scene stitch:<chart_id>` on a throwaway profile — owner
  plays it standalone before it's wired anywhere.
- **Scope:** [M]. Rendering (dots, drag-edges, taut-cinch) is the bulk;
  rules are ~100 lines of pure core (RefCounted `StitchState`, same
  do_command pattern as combat, replayable and unit-testable).

## 2. Testimony — press the witness

**Lineage:** Ace Attorney pressing; Case of the Golden Idol deduction.
**Verb:** catch the thread that doesn't hold.

A witness's statement lies on the page as 2–4 stitched ribbon cards.
Two moves: **press** a ribbon (tap — the witness elaborates; some
elaborations spawn a new ribbon), or **present** — drag an evidence chip
(from the Casebook strip along the bottom, populated from
`profile.case.evidence`) onto the ribbon it contradicts. The witness has
**patience** (3 paw-pips): a wrong presentation spends one and costs −1
standing with the witness's guild. Patience out = the partial outcome
(witness clams up; the lead continues poorer, never blocks). Correct
present = the break: new evidence and/or a `leads_done` advance.

- **Cat rule:** Ash cannot press humans — only animal witnesses, about
  humans. (Why a cat detective sees what the Watch cannot; canon.)
- **Fair-play rule:** a pressable ribbon never lies to the player;
  wrong-but-honest ribbons exist, contradiction is always provable from
  held evidence. Statements a player can't yet disprove show a faint
  loose-thread shimmer ONLY after the case's evidence makes them
  disprovable (no pixel-hunting).
- **Systems hooks:** consumes/produces Case Board state (evidence,
  leads); writes `standing`; can grant favor-knots ("you didn't press
  where it hurt — the shift-boss remembers").
- **Data:** `game/data/testimonies.json` — id, witness (name, portrait,
  guild), ribbons [{id, text, press_text, spawns?, contradicted_by?
  (evidence id), break_effects}], patience, `when_outcome` ids.
  Validate: every `contradicted_by` exists in some case's evidence; at
  least one ribbon is breakable; patience ≥ wrong-paths.
- **First placement:** L3 Prowl B — the Lamplighters' shift-boss (the
  choice-scene chain gains teeth: the Sway tally's finale is a Testimony
  beat). Then: suspect eliminations (the mid-Ch3 "third suspect breaks"
  IS a Testimony scene), Sootbeard's blink, the Pigeon Ballot.
- **Scope:** [M]. UI is story-screen-family; logic is a pure
  `TestimonyState` core class; content is data.

## 3. Patch the Ward — thread-patch quilting

**Lineage:** Patchwork / Calico / The Isle of Cats. **Verb:** mend.

A torn ward is a grid with a ragged hole (6–12 damaged cells). A rack
offers thread-patch polyominoes; each patch is **paid with an energy card
of its humour** from the player's actual hand/deck (the battle hand UI
docks at the bottom, unchanged) — Moonlight pays any patch, spent is
spent (the ward literally consumes tonight's energy; the mend is part of
the prowl's economy, not free). Drag patches into the hole; rotation on
double-tap. You will usually NOT cover everything: each uncovered cell
carries a data-declared *lingering* effect into the next encounter
(drafts: enemy first hit +1; cold: start 1 card down), and a perfect
patch grants one (`warmed`, or the ward's own boon).

- **Skill hook:** patching is where Ash's inheritance shows. Early
  charts' patches render crooked; after the Ch2 stitching lesson they
  neaten (pure rendering flourish, zero mechanics).
- **Systems hooks:** energy deck + spent pool (shared with combat via
  carryover), lingering effects (existing), rewards standing/gleam with
  the guild whose ward it is.
- **Data:** `game/data/wards.json` — id, grid, hole cells, patch rack
  [{shape, humour}], gap_effect, perfect_effect, rewards, `when_outcome`
  ids. Validate: hole coverable by rack; humours legal; effects known.
- **First placement:** L3 finale — Ash patches the Lamplighters' hall
  ward; that mend is WHY a guild of professionals trusts a cat (and sets
  the favor-knot economy beat already in chapters/01). Then: mending
  rounds as repeatable side missions (a wardkeeper income the free tier
  keeps forever); pre-boss defensive prep (choose to spend deck now for
  a safer fight).
- **Scope:** [M–L]. The polyomino board is the biggest new UI in the
  set; the payoff is a second full use of the existing card economy.

## 4. The Unpicking — pull threads in safe order

**Lineage:** pick-up-sticks/Mikado × knot topology. **Verb:** undo.

A lattice of 6–12 threads crossing on the page; each crossing has an
over/under. Only a thread with **no thread crossing over it** may be
pulled (tap; it slides out with a hiss). Pull everything to dismantle
the working. A wrong pull twangs the lattice: **+Alarm** (existing
stealth system — heist context) or, in ward contexts, one `gap_effect`
into the next fight. Later charts: elastic threads that re-cross when a
neighbor is removed (state changes mid-puzzle, telegraphed by a tremble).

- **The cold beat:** this is the killer's verb. Its first uses are
  utility (heists, knot-contracts); the late-game use — Ash unpicking a
  seam exactly as the Unraveler does, and being good at it — is a story
  beat the game must let land in silence (no coach, no joke; style guide
  note).
- **Systems hooks:** Alarm/stealth; the Gentleman's knot-contracts (Ch2
  favor economy); gap effects shared with Patch the Ward (same
  vocabulary, opposite direction — build them as one effects table).
- **Data:** `game/data/lattices.json` — id, threads [{id, path, over:
  [thread ids]}], error_cost ("alarm" | effect id), elastic rules,
  rewards, `when_outcome` ids. Validate: the over-graph is acyclic (a
  solvable order exists); error costs known.
- **First placement:** L2 or L4 heist interior (disarm the counting-room
  ward instead of fighting the alarm down) — implementer picks whichever
  lead's pacing needs it; the other keeps pure stealth-combat so the two
  heists don't rhyme. Ch2: knot-contracts.
- **Scope:** [M]. Shares thread rendering with Seam & Stitch — build
  Seam first and reuse its drawing layer.

## 5. The Long Way Round — push-your-luck traversal

**Lineage:** Can't Stop / Quacks of Quedlinburg. **Owner framing (the
design contract): the SAME energy deck, different actions.** No new
board, no new resources — a crossing is played with the battle screen's
skeleton: same hand fan, same paws, same spent pile; only the action row
and the "opponent" change.

The opponent zone becomes the crossing: a route track (progress pips
toward home) and a posted **gust** — a humour the storm currently owns.
Each turn, instead of skills:

- **Press On** — draw 1 and advance 1 per card currently in hand…
  but if any drawn/held card matches the gust humour, you **slip**:
  lose that much progress back and take 1 damage. (Hold a big hand to
  move fast; the gust punishes greed. Banked cards are safe — the bank
  finally shines.)
- **Pick the Line** (1 paw) — peek the next gust before choosing.
- **Shelter** (ends turn) — bank current progress (it can no longer be
  lost), discard the gust, a new one posts. The night still presses:
  from turn 8 gusts double (same escalation clock as combat).
- **Slip Away** — abandon the crossing (walk-away outcome; the long way
  round becomes the *very* long way round, story notes it).

Cards spent to slips/shelters go to the SAME spent pool and stay spent
into the prowl's next encounter — traversal and combat share one
stamina, which is the whole point ("the deck is the run's clock" now
includes the weather).

- **Systems hooks:** deck/hand/bank/paws/spent (all existing), carryover,
  night-presses, `when_outcome`. Mechanically this is a CombatState
  sibling: a pure `CrossingState` with `do_command()`, seeded, simmable —
  add a crossing table to simulate.gd the same week it lands.
- **Data:** `game/data/crossings.json` — id, length, gust script or
  seeded gust weights, hazard damage, environment id, rewards,
  `when_outcome` ids. Validate: length > 0, humours legal.
- **First placement:** the deferred survival/escort leads (Ch2 garden
  storm, rooftop chase). **Ch1 option (owner's call at Phase 4):** L4's
  survival prowl was converted to plain combat by the Phase-0 cut; if
  the prototype lands early and feels right, the Mereside approach
  crossing can use it instead — amend chapter1-build-plan Phase 4 then,
  not preemptively.
- **Scope:** [S–M] — smallest of the five precisely because of the
  owner's reuse framing.

---

## Build order (feeds chapter1-build-plan.md)

1. **Seam & Stitch prototype** — standalone component
   (`--scene stitch:<chart_id>`), 3 sample charts, owner plays it and
   calibrates feel BEFORE any story wiring. Its core-state pattern
   (RefCounted + do_command + seed) and thread-drawing layer are the
   template every other module copies.
2. **Testimony** — data + core state + story-family UI; first content is
   the L3 shift-boss scene. (The case spine it consumes is Phase-1 work,
   already in flight.)
3. **Patch the Ward** — after Testimony (its L3 slot follows the
   testimony beat narratively); shares the effects table with #4.
4. **The Unpicking** — reuses Seam's thread rendering; lands with the
   heist lead that wants it.
5. **The Long Way Round** — anytime after the prototype pattern settles;
   cheapest, and its sim table wants the carryover-mode sim (already owed
   by balance-notes Pass 5).

Every module ships with: a component-runner spec, a scenario JSON, a sim
or brute-force validity check where applicable, tour stops with
tap-budget, and `when_outcome` prose for all three outcomes. Charts/
lattices/testimonies are content: they follow the same id discipline,
validation, and "never hardcode in scripts" law as every other JSON.
