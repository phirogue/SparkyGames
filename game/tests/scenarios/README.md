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
  "launch":    "hub" | "battle:<encounter_id>" | "quest:<quest_id>"
               | "story:<index>" | "journal"
}
```

- `profile` keys mirror `SaveService.DEFAULT_PROFILE`: `skills` (owned),
  `loadout` (chosen ≤3, empty = auto), `deck` (energy card ids), `gleam`,
  `max_hp`, `prologue_done`, `flags`, `codex`, `achievements`.
- `seed` pins every battle's shuffle/AI rolls — the same tap sequence
  reproduces the same fight exactly. Omit (or 0) for clock-random.
- `carryover` drops you MID-prowl: worn deck, spent charges, low hp — the
  states that fresh-fight sims never see.

## Shipped scenarios

| name | what it tests |
|---|---|
| `fresh_start` | first boot state, hub with only Scratch |
| `post_prologue` | standard 5-skill state after the tutorial |
| `coat_finale` | the Empty Coat with the garden-first Swat kit, pinned seed |
| `endgame_grinder` | maxed tonics, rare cards, all skills — over-leveled economy |
| `moonlight_rush` | wild-heavy deck vs the captain — payment-planner stress |
| `worn_mid_prowl` | carryover state: thin deck, 4 hp, spent charges |

Add one whenever a bug report says "it only happens when..." — encode that
state here so the reproduction is one command forever.
