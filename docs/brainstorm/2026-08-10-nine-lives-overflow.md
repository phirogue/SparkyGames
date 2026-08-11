# Nine lives vs. a whole game of dying — overflow options (2026-08-10)

> **DECIDED 2026-08-11:** the recommended layering was adopted — option 1
> (lives spent, never taken) + option 2 (the Court refuses unscheduled
> deaths) + option 6 (the buried truth, hinted from Ch1) + option 3 as an
> authored Chapter 3 branch. Source of truth:
> [../design/death-and-lives.md](../design/death-and-lives.md); spoiler
> layer in [../design/the-unraveler.md](../design/the-unraveler.md). This
> file stays as the record of the options NOT taken and why.

Owner question: the game is 3 chapters with many missions; Ash can die far
more than 9 times, but the premise grants exactly 9 lives. No save points.
Replaying the same story after a final death isn't interesting. What are our
options? (Owner floated: Ash becomes an agent of the Hollow Court; some
"deaths" are only injuries, but the game must explain it.)

## The observation that reframes it

The design **already forbids running out of lives from being game over**:
[story-direction.md](../design/story-direction.md) promises *"one ending only
reachable by a cat who has died all nine canonical deaths."* If the ninth
death ended the game, that ending would be unreachable. So the question was
never "how do we prevent a game over" — it's *"what is true about death in
this world such that nine is a real number, most losses aren't deaths, and
the ninth is a door rather than a wall?"*

Also already in canon and load-bearing here:

- Death is designed rare: knockouts/retreats are the default failure
  ([difficulty-and-progression.md](../design/difficulty-and-progression.md),
  `hp_floor`, Slip Away banks everything).
- The Hollow Court is death's *civil service* — dockets, the Toll, a Clerk
  who finds Ash "professionally irregular and personally delightful."
- Elspeth's file at the Court is **wrong**, and this terrifies them
  ([world-bible.md](../design/world-bible.md)).
- Hearth-cats of the Court already exist (spectral cats in the Court's
  employ; "professional courtesy applies to Ash. Mostly.").
- Bodkin "is fond of Ash — the one thing he will not unpick"
  ([the-unraveler.md](../design/the-unraveler.md), whole-game spoiler).
- The ninth-life ending is "a conversation between two cats about what their
  witch was worth."

## Options

### 1. Lives are SPENT, never taken (knockout-by-default, death-by-choice)

Sharpen the existing "death is rare" rule into a guarantee: ordinary combat
**cannot** kill Ash. Losing = knocked out — dragged home by Tansy, waking in
a gutter with the satchel spilled and a Grudge earned. The fiction: cat-magic
doesn't pay out a life for anything so undignified as *losing a fight*.
A life leaves the counter only when it is **staked**: scripted mortal moments
the story authors, plus optional player choices ("Stake a life" to push past
a `withdraw_after`, enter an overweight fight, or force a door only the dead
may pass — canon already has "some doors only open to a cat who has died the
right way").

- Nine becomes a number the writers and the player control together; the
  "nine canonical deaths" secret ending becomes a deliberate collection run,
  not an accident.
- Cheapest option: it's mostly a rules *clarification* plus knockout scene
  variants (`when_outcome` machinery already exists).
- Risk: if knockouts sting too little, losing stops mattering. Knockout must
  keep the satchel spill + Grudge.

### 2. The Court refuses irregular deaths (the bounce-back)

Death is a bureaucracy, and bureaucracies only process what's *scheduled*.
Ash's file — like his witch's — is irregular. When he arrives dead out of
turn, the Clerk stamps **REFUSED** and sends him back, minus a filing fee.
Mechanically identical to a knockout (satchel spills, a fee, a Grudge) but
staged AT the Hollow Court, so every "death" still buys a Court scene and
the Clerk relationship keeps compounding. Only deaths the docket expects —
the canonical, scripted ones — actually decrement the counter.

- Explains the mercy *diegetically*, in comedy that is exactly this game's
  tone ("You are not on today's list. Come back when you're expected.").
- Feeds the mystery: WHY is Ash's file irregular? Because his lives are
  Elspeth's unfinished magic and her file is wrong — the mercy mechanic is
  evidence.
- Needs variant density (law 15): refused-at-the-desk scenes will be seen
  many times and must genuinely vary.

### 3. Agent of the Hollow Court (owner's idea, developed)

The ninth death isn't game over — it's **employment**. A cat whose ledger
won't balance works off the arrears. Ash continues as a probationary
hearth-cat: still on the case, because the Court *wants* the case solved —
correcting Elspeth's file is the one thing that balances his. Consequences:
day-side doors close (some living NPCs can't hear him; merchants gate),
night-side doors open; deaths past nine become disciplinary dockets and
fees; the ending he can reach changes. Framed this way it's not a fail
state, it's a *branch* — arguably the richest version of "died all nine
canonical deaths."

- Strongest narrative payoff; builds on existing canon (hearth-cats, the
  Toll, the Clerk).
- Most expensive: a true fork — post-ninth-death variants for every story
  scene Ash can still visit, alternate gating, ending work. Realistic as an
  authored Chapter-3-era branch, unrealistic as an "any time, anywhere"
  overflow valve for Chapter 1.

### 4. The ninth life is held in escrow (play on credit)

The counter never reaches zero by ordinary means: the Court holds Ash's
ninth life in escrow against Elspeth's unsettled estate. At one life, every
further "death" is survived **on credit** — and the debt is real: fees,
Grudges, and the Quiet Gentleman's *personal* interest (a cat in life-debt
is exactly the merchandise he brokers). Debt level colors NPC dialogue and
weighs on the endings.

- A lightweight merge of options 2 and 3: infinite continuation, mounting
  narrative pressure, no content fork.
- The debt spiral needs a relief valve (see option 5) or a floor, or
  late-game players arrive at the accusation buried and bitter.

### 5. Lives can be earned back (the re-stitched thread)

Nine is a **cap**, not a one-way countdown. "The dead are loose threads;
ghosts are stitches that haven't been tied off." Tying one off — settling a
ghost, finishing one of Elspeth's unfinished wards, a Court side-docket —
returns a life: a thread tied is a thread returned. Slow, finite per
chapter, always a quest rather than a purchase.

- Makes side content mean something in the premise's own currency; keeps
  death scary but not ruinous.
- Risk: if farmable, tension deflates; if too stingy, it doesn't solve the
  problem. Probably a *complement* to another option, not the answer alone.

### 6. Someone is keeping him alive (the Bodkin mercy) — SPOILER

Past the point where the thread should snap, it doesn't. The game doesn't
explain it — *yet*. NPCs notice ("you smell of thread that isn't yours").
Late Chapter 3 the player learns the truth: Bodkin has been re-knotting
Ash's thread all along — he is fond of Ash, the one thing he will not
unpick. The mercy mechanic the player leaned on all game IS the final clue.

- Devastating retroactive payoff; mechanically nearly free.
- Handle with the every-Bodkin-line-literally-true rule; must be foreshadowed
  enough that the counter never feels like a lie. Best used as the *secret
  explanation behind* option 2 or 4, not as a visible system.

### 7. The other eight strays (legacy succession) — recorded, likely rejected

Ash was Elspeth's ninth stray; eight predecessors are alive. Final death
passes the case — evidence, chronicle, Grudges — to another stray with
different humours; Ash haunts along as advisor. True roguelite legacy.
Rejected for core scope: new playable character = art refs, voice, full
dialogue variants. Worth remembering for post-launch case files.

## Recommended layering (proposal, not decided)

- **Base rule: option 1.** Ordinary losses are knockouts; lives are only
  ever *spent* — by the script at authored mortal beats, or by the player
  staking one. This alone dissolves the arithmetic problem.
- **Fiction & mystery: option 2** explains the base rule in-world and turns
  it into evidence, with **option 6** as the buried true answer.
- **Option 3 as an authored branch,** entered at scripted Chapter-3-era
  moments (or by a player who stakes recklessly), not as a global overflow
  valve — that keeps its cost bounded and its meaning intact.
- **Option 5 sparingly** if playtests show players hoarding lives out of
  fear.

Whatever is chosen: the rule must be **stated to the player** (owner defect
class: rules the game enforces but never explains) and the lives counter UI
must be honest about what it counts.
