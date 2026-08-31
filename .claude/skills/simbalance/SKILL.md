---
name: simbalance
description: Run the bot playtest simulations and update balance-notes.md with analysis. Usage: /simbalance [what changed]
---

# Sim Balance — 19,200 fights of truth

Run after any change to enemies, skills, costs, decks, environments, or the
approach system.

1. `& "C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe" --headless --path game -s tests/simulate.gd`
2. Compare the table against docs/design/balance-notes.md targets:
   - Tutorials (vole, wisp): ~100% for ALL bots including random.
   - Dog: careless play punished ~10-15%.
   - Wraith: ~0% for EVERY bot (a freak brawler kill lands about 1-in-300;
     03_the_wrong_lamps carries the victory line for it, law 17). It is a
     prologue story-beat, not a winnable quest fight (Pass 4 moved it off
     the board deliberately) — do not "fix" the zeroes.
   - Unpicked: 0% wins, death by turn ~7-13, escape possible.
   - Quest elites: skilled bots 75-100%, random meaningfully lower.
   The COARSE floor of these targets is enforced by the sim itself
   (`_check_targets` in tests/simulate.gd, 2026-08-31): tutorials winnable,
   wraith/Unpicked at zero, the dog punishing, elites and the boss beatable
   by skilled play, purchased builds carrying their fights. The sim exits 1
   when one breaks, so `verify full` fails on breakage — the finer prose
   targets above are still yours to eyeball in the table.
3. If targets drift: tune data (enemies.json/skills.json), re-run, repeat.
4. Update balance-notes.md: new table, tuning changes made, date.
5. When adding NEW mechanics (e.g. the Paw action-point proposal), teach the
   bots to use them first — sim results from bots that ignore a mechanic are
   noise.
