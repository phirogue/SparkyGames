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

> **Owner pass, 2026-08-09.** The prototypes were played and came back with
> a defect list. What it changed, in one place, because these override the
> per-module text below where they disagree:
>
> - **Every module teaches itself.** Three of the five "make no sense, need
>   a tutorial". Teaching is now coach marks over the live board, authored in
>   `game/data/minigame_tutorials.json` and validated like any other content;
>   a module plays its lesson on first sight and its **?** button replays it
>   forever. The one-page blurbs in `lessons.json` stay as flavour, but they
>   are not the teaching and never were.
> - **Patch the Ward is drag-and-drop, and patches may stack.** Placement no
>   longer refuses overlap or spill onto sound cloth; the only thing scored
>   is how much of the tear is still open. See #3.
> - **Squint says something.** It names a stitch to take out AND a gap the
>   seam runs through. See #1.
> - **The mirror chart's clues must be horizontally asymmetric**, or the
>   reflection changes nothing. `chart_mirror` was symmetric and therefore
>   indistinguishable from an ordinary chart; it was rewritten.
> - **A closed seam is checked after an unpick too.** Solving by taking out
>   the last wrong stitch used to do nothing at all.
> - Boards are drawn through `MinigameShell.guide_line`: 1px un-antialiased
>   lines were silently dropped by the mobile renderer, which is why the
>   stitch grid shipped with no right-hand column or bottom row.

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
adding a puzzle must never mean touching a scene script.

> **The "drawn boards only" rule is retired (owner 2026-08-11: funded art
> for the minigame boards, battle-screen standard).** Boards still DRAW
> their rules-bearing geometry (threads, pips, cells — anything whose
> position is the puzzle), but they now wear real furniture:
>
> - **The Long Way Round** is a full battle-skeleton page: the crossing's
>   environment backdrop in the battle's wood frame (the opponent is
>   weather), a coloured GUST plate + a NEXT-gust chip in the intent
>   chip's seat, the route as a stitched serpentine thread with brass
>   knots for banked ground, Ash himself (`ui_token_ash`) walking it
>   toward a lit window (`ui_icon_home_lamp`), the hand as the battle's
>   own humour-framed card chips (storm-owned cards wear `ui_gust_swirl`
>   and flutter), a battle status-chip strip, and the battle's feedback
>   vocabulary — floats, red wash on a slip, ghost cards blown off the
>   hand, settle/pulse on plates that change.
> - **Seam & Stitch** sews inside a real embroidery hoop (`ui_hoop`); the
>   grid lays out into the hoop's linen (`HOOP_INNER`), and the satisfied
>   count pulses when a clue comes right.
> - **Patch the Ward** fields its grid on frayed linen (`ui_cloth_linen`)
>   with sound cloth as a translucent wash so the weave shows through.
> - **The Unpicking** hangs its threads on the same linen modulated dark.
> - **Testimony** frames the witness in the battle's portrait frame with
>   their last reply beside it; statements are stitched ribbon bands
>   (`ui_ribbon_band`); new ribbons settle in, spent patience pulses.

> **Owner pass, 2026-08-13.** The five boards were played and came back with
> a defect list. These override the per-module text below where they disagree.
>
> - **The verbs under a board are bigger.** `MinigameShell.ACTION_FONT` is 42
>   and every action button FITS its face to the width its row actually gives
>   it (`MinigameShell.fit_font`), rather than being set to a size and hoped
>   at. "The text for squint and leave it should be bigger."
> - **Seam & Stitch says what is wrong with a board that is right.** A chart
>   that answers every clue and still is not one closed loop raises a card
>   naming *which* way the thread failed — a loose end, a fork at a hole, or
>   two separate rings (`StitchState.seam_fault`). Answering the numbers and
>   closing the loop are two rules, and the board had never said the second
>   one out loud.
> - **Patch the Ward is dealt, not laid out.** Later the same day the owner
>   replaced the rack outright: "treat it as another card game — each new
>   card drawn has a shape on it, the shape corresponds to the energy type.
>   Player can choose to draw more cards winding down the deck or leave early
>   with parts not covered." DRAW spends a card off the spool and hands you
>   the cloth it cuts; lifting a laid patch picks the cloth back up and moves
>   no cards at all, because the cost was the draw. See #3.
> - **Patches are quilt, and they turn where their picture is.** Every patch
>   is cut from one of four drawn weaves and stitched down with running
>   stitch. **Turn it** animates the swing on the drawn CARD'S FACE, because
>   a rotation that only exists under the finger cannot be gauged.
> - **The ward's price is on the page.** An energy strip (spool + a count per
>   humour, the battle's own glyphs) runs between the cloth and the card, so
>   what a draw costs is beside what a draw gives.
> - **The Unpicking never colours in its answer.** Colour is IDENTITY (each
>   thread keeps its dye so it can be followed); the over/under reading comes
>   from a real painter's-order STACK plus the shadow the upper thread casts.
>   Freed threads slide out; a refused pull shivers the thread and everything
>   lying across it. The one exception is `teach_free` in a lattice's data
>   (set on `lattice_counting_room`, the first one the player meets) and any
>   board while its lesson is playing — "turning red is fine for the tutorial
>   game".
> - **The Long Way Round posts an OBSTACLE, not a humour.** "What does it
>   mean for the gust to control a specific energy" was the right question.
>   The plate names the thing in the road — a chained dog, a crowd, a ward
>   across an arch — and prices it in the humour that gets you past it
>   (`minigames.crossing.obstacle.*` / `.cost.*`, three obstacles per humour
>   so the same plate is not shown all night, law 15). Press on carrying that
>   humour and the obstacle takes those cards and your ground; **Go Round**
>   (was Shelter) takes the long way for one card. **Read Ahead** (was Pick
>   the Line) says what it does.
> - **The route is a straight line**, left to right, with the pips closing up
>   to fit — never serpentine. Crossings were shortened accordingly (11–16,
>   from 20–34): the module "loses all your energy very quickly".
> - **The crossing's spool answers taps**, showing what is left to draw by
>   humour — "you should be able to see your deck contents to be able to
>   gauge the probability of making it" — and Press On is SEEN drawing: the
>   card flies off the spool into the paw. The location vignette lost its
>   portrait frame ("the location card here doesn't need a border").
> - **Testimony was streamlined.** The witness portrait is most of the top of
>   the board; the reply is a CARD at body size rather than a small column
>   beside the portrait; statements never scroll (the type is fitted to the
>   zone, floor 22); a pressed statement wears paler cloth; a Casebook chip
>   opens what the Casebook says about it and you hold it up from there; and
>   "Let it lie" is one thin plate (`MinigameShell.ACTIONS_THIN`), the height
>   it gave up going to the board.

---

## 1. Seam & Stitch — the ritual loop [prototype first]

**Lineage:** Slitherlink. **Verb:** sew one closed seam.

A stitch chart: a small dot-grid (4x4 to 6x6), some cells numbered with
how many of their four edges the seam must use. Drag along edges to sew;
tap a stitch to unpick it (free — calm puzzle, no punishment for
thinking). Win: one single closed loop satisfying every number. The
thread renders as real stitching and cinches taut on completion.

- **Player aid, not timer:** optional `Squint` (cost: 1 paw) says **two**
  things, both read off the chart's stored solution so neither can be a
  guess: one sewn stitch the seam does not use (drawn crossed, in blue),
  and one stitch the seam DOES use that is not sewn yet (drawn as a blue
  gap along the edge). It charges only when it has something to say.
  *Revised 2026-08-09*: the original only ever answered "is anything
  wrong?", and on a board with nothing wrong it answered "no" — which the
  owner correctly reported as the aid doing nothing. No hints beyond
  Squint; charts stay small.
- **Feedback is a colour, not a fade.** A satisfied clue goes green with a
  ring; an over-sewn one goes red with a ring. The original faded satisfied
  clues to light grey, which was "barely noticeable".
- **Mirror mode** (`mirrored: true`): the chart's clue numbers are shown
  as the reflection of the grid the player sews on — the Ch3 payoff where
  the player's own paw discovers what mirror-handed means
  (the-unraveler.md). Never used before Ch3.
  **A mirrored chart's clue grid MUST be horizontally asymmetric**, and a
  clue's colour follows the square it truly belongs to rather than the
  square it is drawn over — otherwise the reflection is invisible and the
  chart is an ordinary one wearing a warning label. The board carries a
  standing banner saying the rule, plus a drawn mirror axis.
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

### Seam & Stitch — variants the owner floated (2026-08-09, NOT yet promoted)

Written down so they are not re-invented, and so nobody builds them before
they are asked for. Neither is in scope.

- **Threads of more than one colour.** A chart where the seam is sewn in
  two or three threads, each with its own rule (a colour that may not
  cross itself, a colour that must touch every clue of its own hue). Turns
  one loop into interleaved loops. Wants a real design pass — the clue
  vocabulary has to say which colour it is counting, and the drawn board
  is already at its legibility limit at 6x6.
- **The Unpicking of a seam — one shot.** The inverse verb on the same
  board: start with the seam finished and take stitches OUT, where a
  removed stitch can never be put back. One wrong pull is permanent, so
  the whole puzzle is read-before-you-touch rather than try-and-undo. It
  is a different game from Seam & Stitch (which is deliberately calm and
  free to undo) and it is thematically the Unraveler's, not Elspeth's —
  which is either the reason to build it or the reason not to.

Squint's honesty currently rests on the chart's stored solution being *the*
solution. Nothing yet proves a chart has only one; if a second solution
existed, Squint could call a correct stitch wrong. Shipped charts are small
and hand-authored, but a uniqueness check in `validate_minigames_deep()` is
owed before charts are ever generated rather than written.

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

## 3. Patch the Ward — mend it off your own spool

**Lineage:** Patchwork / Calico, dealt as a push-your-luck draw.
**Verb:** mend.

> **Redesigned by the owner, 2026-08-13.** "Treat it as another card game.
> Each new card drawn has a shape on it, the shape corresponds to the energy
> type. Player can choose to draw more cards winding down the deck or leave
> early with parts not covered. Rather than having all patterns available
> from the get go." The rack is gone. Everything below is that design.

A torn ward is a grid with a ragged hole (4–12 damaged cells). There is no
basket of patches: there is your **spool**. **DRAW** takes the next card off
it, **spends it**, and hands you whatever cloth that card cuts. Lay the cloth
anywhere on the ward, then decide again — another card, or stop.

That decision is the whole module, and it is the same clock the rest of the
run keeps: every card drawn here is a card the next fight will not have.
Every torn square still open carries a data-declared *lingering* effect into
that fight (drafts: enemy first hit +1; cold: start 1 card down), and a
perfect mend grants one (`warmed`, or the ward's own boon). You will usually
NOT cover everything, and choosing where to stop is the point.

- **The card cuts the cloth.** `game/data/patch_shapes.json` maps every
  energy card id to a polyomino: the **humour is the character** of the cut
  and the **worth is its size**. Ferocity cuts long straight strips, guile
  cuts crooked ones, shadow cuts compact squares, Moonlight cuts the small
  odd piece that finishes a corner. A new energy card owes a shape or
  `Catalog.validate()` fails the build — an unplaceable draw is not
  something a player can tell apart from a bug.
- **Placement is a DRAG:** press the card, carry the cloth onto the ward,
  let go. Rotation is **Turn it**, and the swing plays on the card's own
  face (owner 2026-08-13) — a rotation that exists only under the finger
  cannot be gauged. A tap on the card also picks it up and a second tap on
  the cloth lays it, because a modal interaction with exactly one way in is
  how players get stuck (law 7).
- **Lifting a laid patch picks the cloth back up into the paw.** It costs
  nothing and returns nothing: the card went at the DRAW, which is where the
  decision was. This is the shape of the owner's earlier complaint — energy
  must only ever go down on a choice actually made — and it means the paw
  holds one piece of cloth at a time, so lifting cannot be used to fish.
- **Patches may stack, and may hang over sound cloth** (owner 2026-08-09).
  The only placement the rules refuse is one that falls off the grid. This
  replaced an exact-cover rule that rejected any placement outside a
  perfect tiling, which made a quilting game into a jigsaw with one answer
  and made a mis-drop read as a bug rather than as waste. Only torn squares
  still OPEN are scored. Lifting the top of a stack uncovers back to the
  patch underneath, which is why coverage is recomputed from the laying
  order rather than erased cell by cell.
- Shipped wards must still be *perfectly* coverable — the exact-cover search
  in `validate_minigames_deep()` stays, now run against the SHAPE TABLE with
  repeats allowed (the spool holds several of a card), as the proof that a
  perfect mend exists for a player lucky and good enough to find it.

- **Skill hook:** patching is where Ash's inheritance shows. Early
  charts' patches render crooked; after the Ch2 stitching lesson they
  neaten (pure rendering flourish, zero mechanics).
- **Systems hooks:** energy deck + spent pool (shared with combat via
  carryover), lingering effects (existing), rewards standing/gleam with
  the guild whose ward it is.
- **Data:** `game/data/wards.json` — id, grid, hole cells, gap_effect,
  perfect_effect, rewards, `when_outcome` ids (a ward carrying a `rack` is
  now a validation error). Shapes live in `game/data/patch_shapes.json`.
  Validate: hole coverable by the shape table; every energy card has a
  connected shape; effects known.
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

---

## Teaching (added 2026-08-09)

Every module owes the player an explanation, and the explanation is
content. `game/data/minigame_tutorials.json` holds one entry per module —
`stitch`, `stitch_mirror`, `ward`, `lattice`, `crossing`, `testimony` —
each a list of coach-mark steps played over the module's real board by
`ui/coach.gd`, the same overlay the prologue's battle uses.

- A step with no `wait` is a **note**: a tap anywhere advances it.
- A step with `"wait": true` is an **action**: it advances only when the
  player performs it, so its target must be something they can always do
  (law 17). That is why the action steps spotlight the whole board rather
  than one particular edge or thread.
- Targets are resolved per screen: `""` (a note in the middle of the
  page), `board`, `board:<key>` (an invisible `MinigameShell.Marker` laid
  over a drawn feature), or the name of a real button.
- A module plays its lesson once — profile flag `taught_<module>` — and
  the **?** in every board's header replays it on demand forever.
- `Catalog._validate_tutorials()` fails the build if a module has fewer
  than two steps, a step with no text, or an action step with no target.
- `tests/tour.gd` photographs every step of every module's lesson, then
  the board, then one real move, then the outcome card. Minigames were
  absent from the tour entirely until this pass, which is how a grid
  missing its right-hand column reached an owner review (law 2).

The one-page blurbs in `data/lessons.json` remain as flavour and as the
Casebook's replayable concept list. They are not the teaching.
