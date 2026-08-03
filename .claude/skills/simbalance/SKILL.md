---
name: simbalance
description: Run the bot playtest simulations and update balance-notes.md with analysis. Usage: /simbalance [what changed]
---

# Sim Balance — 8,400 fights of truth

Run after any change to enemies, skills, costs, decks, environments, or the
approach system.

1. `& "C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe" --headless --path game -s tests/simulate.gd`
2. Compare the table against docs/design/balance-notes.md targets:
   - Tutorials (vole, wisp): ~100% for ALL bots including random.
   - Dog: careless play punished ~10-15%.
   - Wraith: 0% for EVERY bot, stalker flees ~50%. It is a prologue
     story-beat, not a winnable quest fight (Pass 4 moved it off the
     board deliberately) — do not "fix" the zeroes.
   - Unpicked: 0% wins, death by turn ~7-13, escape possible.
   - Quest elites: skilled bots 75-100%, random meaningfully lower.
3. If targets drift: tune data (enemies.json/skills.json), re-run, repeat.
4. Update balance-notes.md: new table, tuning changes made, date.
5. When adding NEW mechanics (e.g. the Paw action-point proposal), teach the
   bots to use them first — sim results from bots that ignore a mechanic are
   noise.
