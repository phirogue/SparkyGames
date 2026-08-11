# Death & the Nine Lives — how a 3-chapter game spends a 9-life cat

**Owner decision 2026-08-11** (options weighed in
[brainstorm/2026-08-10-nine-lives-overflow.md](../brainstorm/2026-08-10-nine-lives-overflow.md)).
This doc is the source of truth for what death is, what it costs, and what
happens when the lives run out. It supersedes the older "death is rare and
expensive" phrasing in
[difficulty-and-progression.md](difficulty-and-progression.md) and the death
section of [core-gameplay.md](core-gameplay.md), both updated to match.

## The problem it solves

Three chapters of missions can kill Ash far more than nine times, but the
premise — and the title — grant exactly nine lives. Save points are out;
replaying the story after a final death is out. And the design already
forbade a game over: [story-direction.md](story-direction.md) promises an
ending "only reachable by a cat who has died all nine canonical deaths,"
which is unreachable if the ninth death ends the game.

## The rule: lives are SPENT, never taken

**Ordinary combat cannot kill Ash.** Losing a fight is a defeat, not a
death: the run ends, the satchel spills where he fell, the enemy earns its
Grudge — but no life leaves the ledger.

A life is spent only at a **mortal beat**: an encounter the story has marked
(`mortal: true` in `data/encounters.json`), always signposted, always
authored. The prologue's parlor fight against the Unpicked is the first —
every player's death #1 is canon. Later chapters add their own; the nine
canonical deaths are a hand-written list, not an accident of bad luck.

- Engine: the encounter flag flows into `CombatState.mortal`;
  `AchievementTracker` splits DEFEAT into `lives_spent` (mortal) vs
  `refusals` (everything else). The chronicle records `life_spent` vs
  `court_refused` — the Casebook keeps both honest.
- Planned, not yet built: **staking a life** — a player-chosen spend (enter
  an overweight fight, force a door "that only opens to a cat who has died
  the right way", push past a forced exit). Spec it when Ch2 content first
  wants it. Staking plus scripted beats is how a curious player reaches all
  nine.

## The fiction: the Court refuses unscheduled deaths

Why doesn't losing kill him? Because death here is a **bureaucracy**, and
bureaucracies process what is scheduled. A death the docket expects is real
and costs a life plus the Toll. A cat who arrives dead *out of turn* is an
irregularity — and Ash's file (like his witch's) will not reconcile — so
the Clerk stamps **REFUSED** and sends him back up, minus a **filing fee**
(`prowl.refusal_rate` of banked gleam, smaller than the Toll) and whatever
the satchel held.

This keeps every defeat a Hollow Court scene — the Clerk relationship keeps
compounding on losses, not only on true deaths — and it turns the mercy
mechanic into *evidence*: WHY is the file irregular? That question belongs
to the case. The refusal scenes live in
`story/prologue/interludes.json → hollow_court_refused` and obey law 15:
every refusal reads differently, and two of the variants carry planted
clues (see the spoiler doc, below).

**Stated, not just enforced:** the first-visit arrangement page and the
first refusal each carry a `rule: true` line saying exactly what is and
isn't lost. Rules the game enforces but never states are the owner's #1
recurring defect class.

## The buried truth (SPOILERS — details in [the-unraveler.md](the-unraveler.md))

The Court's "refusal" is the bureaucracy's name for arithmetic it cannot
make balance. The real reason the thread never snaps is in the spoiler doc,
which owns the hint rules (every hint literally true, seeded from Chapter 1
refusal scenes onward). Nothing outside `docs/design/` may state or imply
it.

## The ninth life: a door, not a wall (Chapter 3)

Running the ledger to nought is not game over — it is the **Hollow Court's
job offer**. A cat whose file cannot close works off the arrears: Ash
continues as a probationary **hearth-cat of the Court**
(world-bible.md already staffs them), still on the case — the Court wants
Elspeth's file corrected more than anyone, and solving the murder is the
one thing that balances his own.

- This is an **authored Chapter 3 branch**, not a global overflow valve:
  reachable when the scripted mortal beats plus staked lives can actually
  total nine, i.e. from Ch3 (or a recklessly staking player slightly
  earlier). Day-side doors close, night-side doors open, and it feeds the
  "died all nine canonical deaths" ending.
- Content cost is bounded: post-ninth variants only for Ch3-era scenes.
  Spec the branch in the Ch3 chapter doc when Ch3 planning starts.

## Death accounting (for content writers)

| Outcome | Life | Cost | Scene |
|---|---|---|---|
| Retreat (Slip Away) | kept | half of unbanked satchel | retreat lines |
| Defeat, ordinary fight | kept | satchel + filing fee + Grudge | `hollow_court_refused` (rotating) |
| Defeat, `mortal` beat | **spent** | satchel + the Toll + Grudge | `hollow_court_first` / `_repeat` (counts down) |
| Ninth spent (Ch3) | — | day-side standing | the Court branch |

The `hollow_court_repeat` visits ("Third", "Four", "Halfway", "Two", "One")
are the canonical-death countdown and now appear only at mortal beats — each
of the nine deaths keeps a distinct, waiting scene. Budget obligation:
**across the whole game, scripted mortal beats + reachable stakes must be
able to reach nine**, or the ninth-life ending and the Ch3 branch are dead
letters. Prologue ships one. Track the running total here as chapters land.

## Hazards this decision creates (watch these)

- **Losing must still sting.** A refusal costs the satchel, a fee and a
  Grudge. If playtests show players shrugging off defeat, raise
  `prowl.refusal_rate` before inventing new punishment.
- **"Lives" naming collision.** The hub's status chip labeled "lives" shows
  max HP (the voice calls HP "lives in him"), while the nine-life ledger
  only surfaces in Court scenes. Follow-up: when the ledger starts moving
  in Ch2+, the Casebook or Mantel should show lives-remaining honestly —
  and the HP chip may need a different word.
- **Deliberate-refusal farming** is self-limiting (each refusal costs and
  grants nothing) but chaosplay should keep a persona on it.
- The Clerk's shipped line "what happens at nought — the file closes" is
  his *belief about standard procedure*, and stays true for standard files;
  Ash's is not one. Do not "fix" it.
