"""Photograph EVERY quest, not just the prologue.

    python tools/tour_all.py                 # prologue + every quest
    python tools/tour_all.py the_carrying     # just these
    python tools/tour_all.py --quests-only    # skip the prologue leg

Why this exists (owner, 2026-08-05): the screenshot tour only ever walked the
prologue, so a battle screen that broke its own page borders in the Magpie
quest shipped to an owner review completely unseen. A quest nobody
photographs is a quest nobody has looked at.

Each leg runs the real game through the component runner --
`--scene quest:<id>` -- with the tour attached, so it needs no playthrough to
reach and its shots land in `screenshots/quests/<id>/`. Legs are independent:
one broken quest does not stop the sweep, it is reported at the end.

Pairs with `tests/page_guard.gd`, which runs inside each leg and reports any
content outside the page margins; this script surfaces those as LAYOUT lines
and fails the sweep on them. Together they are the "see it before you say it
is done" law applied to content that is not the prologue.
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

# Godot's node dumps carry the game's own punctuation (em dashes, the aphorism
# asterisk); a Windows console in cp1252 cannot print them and would crash the
# sweep on its own report.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

REPO = Path(__file__).resolve().parent.parent
GODOT = Path(r"C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe")
SHOTS = REPO / "screenshots"


def quest_ids() -> list:
    data = json.loads((REPO / "game/data/quests.json").read_text(encoding="utf-8"))
    return [k for k in data if not k.startswith("_")]


def clear_shots(out: Path) -> None:
    """Empty a leg's output folder without removing the folder itself.

    `shutil.rmtree` fails here with WinError 5: the repo lives under OneDrive,
    which keeps a handle on directories it is syncing, and a sweep that dies
    on that is a sweep nobody runs — which is exactly how content stops being
    photographed (law 17). Deleting the PNGs is what actually matters; a stale
    empty directory harms nothing.
    """
    if not out.exists():
        out.mkdir(parents=True, exist_ok=True)
        return
    for stale in out.glob("*.png"):
        try:
            stale.unlink()
        except OSError:
            pass  # a locked file gets overwritten by the run anyway


def run_leg(scene: str, tag: str, timeout: int) -> tuple:
    """One tour leg. Returns (tag, shot_count, error-or-None)."""
    out = SHOTS / tag
    clear_shots(out)
    command = [
        str(GODOT), "--path", str(REPO / "game"), "--",
        "--tour", "--tour-out", tag,
    ]
    if scene:
        command += ["--scene", scene]
    try:
        done = subprocess.run(command, cwd=REPO, capture_output=True, text=True,
                              encoding="utf-8", errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired:
        return tag, 0, f"timed out after {timeout}s", []
    shots = sorted(out.glob("*.png")) if out.exists() else []
    # Godot exits 0 on a clean tour, 2 when PageGuard found content outside
    # the page. Script errors show up in the streams even when the process
    # survives them, and a leg with no shots never rendered at all.
    streams = (done.stderr or "") + "\n" + (done.stdout or "")
    noise = [ln for ln in streams.splitlines()
             if "SCRIPT ERROR" in ln or "Parse Error" in ln]
    if noise:
        return tag, len(shots), noise[0].strip(), []
    if not shots:
        return tag, 0, "produced no screenshots", []
    # One "LAYOUT: <shot>: <node> ... outside the page" line per defect.
    # Deduplicated by node path: the same broken widget is re-photographed on
    # every shot of that screen, and 761 lines for 3 real defects helps nobody.
    layout, seen = [], set()
    for line in streams.splitlines():
        if "LAYOUT: " not in line:
            continue
        detail = line.split("LAYOUT: ", 1)[1].strip()
        node = detail.split(": ", 1)[-1].split("  ")[0]
        if node in seen:
            continue
        seen.add(node)
        layout.append(detail)
    if layout:
        return tag, len(shots), f"{len(layout)} layout defect(s)", layout
    if done.returncode not in (0, None):
        return tag, len(shots), f"exited {done.returncode}", []
    return tag, len(shots), None, []


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("ids", nargs="*", help="quest ids (default: all)")
    parser.add_argument("--quests-only", action="store_true")
    parser.add_argument("--timeout", type=int, default=420)
    args = parser.parse_args()

    legs = []
    if not args.quests_only and not args.ids:
        legs.append(("", "prologue"))
    wanted = args.ids or quest_ids()
    unknown = set(args.ids) - set(quest_ids())
    if unknown:
        sys.exit("unknown quest id(s): " + ", ".join(sorted(unknown)))
    for quest_id in wanted:
        legs.append((f"quest:{quest_id}", f"quests/{quest_id}"))

    failures = []
    for scene, tag in legs:
        print(f"  {tag:34s} ", end="", flush=True)
        tag_name, count, error, layout = run_leg(scene, tag, args.timeout)
        if error:
            print(f"FAIL  ({count} shots)  {error[:90]}")
            for line in layout[:8]:
                print(f"          {line[:120]}")
            if len(layout) > 8:
                print(f"          ...and {len(layout) - 8} more")
            failures.append((tag_name, error))
        else:
            print(f"ok    {count} shots")

    print()
    if failures:
        print(f"{len(failures)} leg(s) failed:")
        for tag, error in failures:
            print(f"  {tag}: {error}")
        sys.exit(1)
    print(f"{len(legs)} leg(s) photographed into {SHOTS}/.")



if __name__ == "__main__":
    main()
