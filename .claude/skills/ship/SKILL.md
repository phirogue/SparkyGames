---
name: ship
description: Full pre-commit gate for SparkyGames - tests, smoke boot, screenshot tour, then commit and push. Usage: /ship <commit subject>
---

# Ship — the only road to a commit

Nothing lands on main without passing every gate, in order:

1. **Unit tests**:
   `& "C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe" --headless --path game -s tests/run_tests.gd`
   Must print ALL GREEN.
2. **Smoke boot** (screens have real size):
   `... -s tests/smoke_boot.gd` — must print OK.
3. **EVERY-QUEST sweep** if anything visual or content changed this session:
   `python tools/tour_all.py` -- photographs the prologue AND every quest,
   and FAILS on content outside the page (law 17). Read the shots the change
   touched (see /uitour). Skippable only for pure docs commits.
   Then `python tools/art_repetition.py` (law 19: no picture carries more
   than 3 beats in a row).
4. **Sim check** if enemies/skills/costs/deck data changed:
   `... -s tests/simulate.gd` — compare against docs/design/balance-notes.md;
   update that doc if numbers moved.
5. Commit with a body explaining WHY (per CLAUDE.md git rules, with the
   Co-Authored-By line), then `git push`.
6. **`/ownerpass`** before any commit that ends a piece of work the owner
   will look at -- it adds the story-critic and first-timer passes on top of
   these gates (law 22). Cheap to skip mid-change; never skip it before
   saying "ready to review".
7. If any gate fails: fix first. Never commit red; never skip with
   --no-verify.

Also remember: new profile keys need SaveService.DEFAULT_PROFILE entries and
a migration thought; new story scenes with battles need when_outcome
variants for retreat/defeat.
