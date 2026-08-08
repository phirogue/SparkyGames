# screenshots/ — the tour's output

**Almost everything in this folder is generated and untracked.** The screenshot
tour rewrites every image on every run, so committing them added roughly
200 MB of new blobs per tour commit — 903 MB of the repo's history, for files
that are one command away.

```
screenshots/
  prologue/     generated — godot --path game -- --tour
  quests/       generated — python tools/tour_all.py
  reference/    TRACKED — the curated "this is correct" set
```

## Regenerating

```powershell
# the prologue walk
& "C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe" --path game -- --tour

# every quest as well (law 17 — a quest nobody photographs is a quest
# nobody has looked at)
python tools/tour_all.py
```

Add new images first if any landed, or the shots come back black:

```powershell
& "C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe" --headless --path game --import
```

## What did NOT change

Laws 1 and 17 stand. No visually-affecting change is done until the sweep has
been run and the shots have been **read**. Untracking them changes where the
images live, not whether anybody looks at them — and `tests/page_guard.gd`
still fails the sweep mechanically when content leaves the page.

## reference/

The tracked set is small and hand-picked: one canonical shot per screen type,
committed when that screen was signed off. It exists so a suspected regression
has something to be compared against. Replace a reference shot only when the
new look is the intended one — that commit is the record of the decision.
