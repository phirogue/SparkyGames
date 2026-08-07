# Scenario specs — reproduce ANY player state without a playthrough

Launch with:

    godot --path game -- --scene scenario:<name>

where `<name>` is a file in this folder (without `.json`). The world is
throwaway: scenarios NEVER touch the real save.

## Spec format

```json
{
  "comment": "human note, ignored by the runner",
  "profile":   { ...partial profile, deep-merged over DEFAULT_PROFILE... },
  "carryover": { ...optional mid-prowl state (hp/deck/skill_charges)... },
  "seed":      12345,
  "story":     [ ...optional: this spec's OWN story scenes... ],
  "launch":    "hub" | "battle:<encounter_id>" | "quest:<quest_id>"
               | "story:<index>" | "journal"
}
```

- `profile` keys mirror `SaveService.DEFAULT_PROFILE`: `skills` (owned),
  `loadout` (chosen, up to `SaveService.LOADOUT_SIZE - 1`; empty = auto), `deck` (energy card ids), `gleam`,
  `max_hp`, `prologue_done`, `flags`, `codex`, `achievements`, and the
  chapter spine — `case` (`{active, evidence, leads_done}`), `standing`
  (guild id → int), `favors` (knot ids), `quests_done`.
- `seed` pins every battle's shuffle/AI rolls — the same tap sequence
  reproduces the same fight exactly. Omit (or 0) for clock-random.
- `carryover` drops you MID-prowl: worn deck, spent charges, low hp — the
  states that fresh-fight sims never see. **It only survives a
  `battle:` launch.** Starting a quest resets carryover (that is correct —
  a prowl begins fresh), so a `quest:` spec that sets carryover is silently
  ignoring it. Put the worn state in `profile` instead: `max_hp` for a cat
  one hit from the Court, `deck` for a thin pool.
- `story` replaces the prologue's scene list with the spec's own, so
  `launch: "story:0"` walks scenes that live nowhere else. This is how a
  story SYSTEM gets exercised before the chapter that uses it is written.
  Same schema as an arc file in `story/prologue/`.

## Shipped scenarios

| name | what it tests |
|---|---|
| `fresh_start` | first boot state, hub with only Scratch |
| `post_prologue` | standard 5-skill state after the tutorial |
| `coat_finale` | the Empty Coat with the garden-first Swat kit, pinned seed |
| `endgame_grinder` | maxed tonics, rare cards, all skills — over-leveled economy |
| `moonlight_rush` | wild-heavy deck vs the captain — payment-planner stress |
| `worn_mid_prowl` | carryover state: thin deck, 4 hp, spent charges |
| `ch1_case_open` | mid-case Chapter 1: Case Board with threads, recap card, standing and a knot owed |
| `ch1_spine_demo` | the Phase-1 story systems: evidence/knot/standing grants, a Remembered Day flashback, a favor redemption, a standing-gated scene |

A scenario can be photographed instead of played — add `--tour` and send
the shots somewhere of their own:

    godot --path game -- --tour --tour-out spine --scene scenario:ch1_spine_demo

Add one whenever a bug report says "it only happens when..." — encode that
state here so the reproduction is one command forever.
