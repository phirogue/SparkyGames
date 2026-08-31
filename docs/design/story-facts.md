# Story Facts — state-driven conversation

*Decided 2026-08-31. Engine: `core/prowl_script.gd` (facts section),
`core/catalog.gd` (validation), `scenes/game.gd` (`_run_prowl_story`,
`_heal_facts`), `services/save_service.gd` (`profile.facts`). Tests:
`tests/unit/test_facts.gd`.*

## The problem this solves

Story beats used to lean on state nobody was tracking. "Cardew said it" was
quoted in the Wickhouse when Cardew only says it on one of three branches of
The Carrying; Bodkin introduced himself again to players who retried
Creditors after meeting him; An Empty Coat recited Merrow's branch-gated
filing detail to players who had never entered her hall. Every one of these
is the same defect: **a line whose appropriateness depends on player state
the content had no way to read.**

`when_attempt` cannot express any of this — it knows the quest was tried,
not what the player saw before the retreat. Post-battle first meetings were
un-gateable: gate them `first` and a player who retreated from the earlier
fight loses the meeting forever.

## The model

**Facts** are the durable configuration of what this Ash has seen, met and
learned: `{"met_bodkin": 1, "heard_cardew_again": 1, "knows_eleven": 1}`,
stored in `profile.facts`, values ints only (Godot's JSON floats, trap 26).

A story or flashback step:

- records facts the moment it is SHOWN — `"sets": {"met_bodkin": 1}` — you
  have met Bodkin even if you die in the next alley;
- gates on them — `"when_fact": {"fact": "met_bodkin", "not": 1}` — one
  clause or a list of clauses that must all hold. `"is"` requires the value;
  `"not"` forbids it; a missing fact matches every `not` and no `is`.

## The three authoring patterns

1. **First meeting** — intro beats gated `{"not": 1}`, a remembering variant
   gated `{"is": 1}`, and the fact set on the LAST beat of the intro
   sequence. Setting it earlier makes the remembering variant fire in the
   same run, because `sets` applies immediately (this bit once, in review).
   Example: Bodkin in `creditors`.
2. **Two-variant beat** — the same moment written twice, `is`/`not` on a
   fact a branch set elsewhere. Example: the wake's "Ninth. I filed it next
   to AGAIN / 'twice before'" on `heard_cardew_again`; the coat quest's
   eleven-missing card on `knows_eleven`.
3. **Plumbing** — `sets` with no reader yet (`met_wick`, `tansy_home`,
   `wick_exposed`). Legal by design: facts are cheap, and Chapter 2 will
   want to know what Chapter 1 did.

## What keeps it honest

- `Catalog.validate()`: shapes (int values, exactly one of `is`/`not`,
  facts only on story/flashback steps) and the typo check — **a fact gated
  on but never set anywhere fails boot**, because a typo'd gate reads as a
  missing page, not an error.
- `test_facts.gd` contract: every `is` gate has a `not` complement or an
  in-quest setter — an `is` with neither is a beat some players silently
  never see.
- **Old saves and scenarios** (law 7): `_heal_facts` re-derives facts on
  every profile adopt by replaying the `sets` of completed quests against
  the profile's own flags — unconditional beats, `first` beats, confirmed
  `when_flag` branches, and fact gates replayed in order.
- **Chaos hardening (2026-08-31 review).** Each of these is enforced, not
  advised:
  - Saves are player-owned files: `_heal_facts` runs
    `ProwlScript.sanitize_facts` first, so a hand-edited
    `"met_bodkin": "yes"` is dropped instead of misgating every later read.
    The heal never overwrites a live fact — it only adds derived ones.
  - `sets` behind a minigame gate or on a retry-only beat **fails boot**:
    derivation cannot replay either, so such a fact would be permanently
    lost to migrated saves.
  - A setter gated on another quest's fact **fails boot**: derivation walks
    `quests_done` in array order, and scenarios/hostile saves can put that
    array in any order — same-quest gating keeps derivation
    order-insensitive (held as a shuffled-derivation invariant in
    `test_facts.gd`).
  - `"sets": {fact: 0}` **fails boot**: a held 0 gates differently from an
    absent fact (`not 0` blocks, `not 1` passes) and an author reaching for
    0 to mean "un-set" would be betrayed silently. Absence is the un-set.
  - Scenario specs may hand-author `profile.facts`, but only with keys some
    content actually sets (`test_facts.gd`) — a typo'd fact photographs a
    state no player can reach.
  - `tools/art_repetition.py` knows gated variants (`when_flag` branches,
    `is`/`not` fact pairs, first/retry twins) are one picture-slot, not a
    run — it counts what a player can actually see.

## Open work

- A step-walk fuzzer over `ProwlScript.steps_of` with two personas the
  combat fuzzer cannot express (facts never pass through `do_command`):
  **the Withdrawer** (bail one step after every `sets`, then start a quest
  that reads the fact; assert derived ⊆ live facts and disk round-trip
  keeps the live fact) and **the Rereader** (replay a repeatable branch
  quest alternating branches; assert live facts and re-derivation agree on
  the last branch taken).

## What this is not

Not a scripting language. Facts gate PROSE; they do not grant rewards, move
standing or unlock quests — `requires`, `grant_*` and flags keep those jobs.
And flags keep in-quest branching (`when_flag` reads the choice made this
quest); facts are for knowledge that must travel BETWEEN quests or across
retries.
