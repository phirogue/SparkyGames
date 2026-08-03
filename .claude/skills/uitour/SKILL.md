---
name: uitour
description: Run the screenshot tour of the game and visually verify the rendered screens before declaring any UI work done. Usage: /uitour [focus]
---

# UI Tour — see it before you say it's done

Run the automated screenshot tour, then INSPECT the results with your own
eyes. Never report a visual change complete without doing this.

## Steps

1. Run tests first (fail fast on logic breaks):
   `& "C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe" --headless --path game -s tests/run_tests.gd`
2. If ANY new image files were added to game/assets since the last run,
   import them first or every new texture renders as a placeholder
   (the game binary does not import — only the editor does):
   `& "C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe" --headless --path game --import`
   If layout changed, also verify the zone template first:
   `& "...Godot..." --path game -s tests/calibrate.gd -- zones battle`
   (also: `zones story|choice|hub`, or bare margins mode for boundaries).
3. Clear old shots and run the tour (a game window flashes briefly — normal):
   `Remove-Item screenshots/*.png -Force; & "C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe" --path game -- --tour`
4. Glob `screenshots/*.png` and **Read at minimum**: one `battle_open_*`, one
   `battle_coach_*` (if tutorial changed), one `battle_skill_detail`, one
   `story_full`, and the shot matching whatever was changed (the `[focus]`
   argument names it).
5. Judge each against `assets/library/mockups/ui_objective.png` and the checklist:
   - Nothing crosses the page stitching (side 64 / top 54 / bottom 92).
   - Every text fits inside its box (measure_text law).
   - Buttons encase their labels; tap targets ≥ 96px.
   - Placeholders (black boxes) are expected only for unmade art.
   - Fonts ≥ 24px for anything the player must read.
6. Report defects found (file:line of the responsible code where possible),
   fix, and re-run until clean. Only then is the work "done".
