# play/ — try one part of the game, without playing to it

Double-click anything in **`play/apps/`**. Each one boots the real game
straight into a single screen, fight, prowl or player state.

Or from a terminal:

```powershell
.\play\play.ps1              # menu
.\play\play.ps1 mantel       # by name
.\play\play.ps1 -List        # every part, with a line on what it's for
.\play\play.ps1 -Install     # regenerate the shims in apps\ from parts.json
```

## The rule that makes this safe

Every part launches through the game's component runner (`--scene <spec>`),
which builds a **throwaway profile**. Nothing here can read or write
`profile.json`, so you can die, spend everything, break things, and quit —
your real save is exactly where you left it.

## What's in the box

| group | what it's for |
|---|---|
| **Screens** | the title, the Mantel, the Casebook, the Case Board, the prologue |
| **Battles** | one fight each: tutorial, wisp, dog, wraith, the quest elite, stealth/Alarm, the boss |
| **Prowls** | full quests: the three board quests, the Press On economy, and one hit from the Hollow Court |
| **Chapter 1** | a case in progress, the spine systems demo, the recap card |
| **Player states** | first boot, post-prologue, worn mid-prowl, over-levelled, Moonlight-heavy, the Coat with the Swat kit |

## Adding one

Edit [parts.json](parts.json) — name, title, group, `spec`, one line of
`about` — then run `play.ps1 -Install`. Nothing is hardcoded in the script.

A `spec` is anything the component runner takes:

- `hub`, `title`, `journal`, `case`, `recap`
- `story:<index>`
- `battle:<encounter_id>[:skill,skill,...]`
- `quest:<quest_id>`
- `scenario:<name>` — a full player state from
  [game/tests/scenarios/](../game/tests/scenarios/), which is where to go
  when a part needs a specific deck, loadout, economy or case progress.
  Those specs can also pin a battle seed, so a part reproduces exactly.

## Related

- **Reproducing a bug**: write a scenario spec instead of steps to follow.
  See `game/tests/scenarios/README.md`.
- **Photographing a part**: add `--tour --tour-out <dir>` to any of these
  and the tour drives it and saves PNGs.
- **Breaking a part on purpose**: `/chaosplay` runs the irregular-play
  harness (`game/tests/fuzz.gd`) that hunts edge cases these launchers let
  you find by hand.
