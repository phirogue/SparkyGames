"""One command that runs the RIGHT checks for what you changed.

    python tools/verify.py fast        # ~40s   before you say "that should work"
    python tools/verify.py standard    # ~4min  before every commit
    python tools/verify.py full        # ~20min before an owner review
    python tools/verify.py --for core  # the tier that matches what you touched

Why this exists
---------------
There are nine verification harnesses in this repo and each exists because
something shipped past a review without it. Nine commands is more than anyone
reliably remembers, so the ones that are slow or easy to forget got skipped —
which is how a battle screen hanging off the right edge of the book reached an
owner review completely unseen.

This runs them in the right order, stops at the first tier-breaking failure,
and prints exactly what to do next. It does not replace reading the
screenshots: the tour writes images, and law 1 says a human (or Claude) looks
at them. This just guarantees they were produced.

Exit code is 0 when the tier passes, 1 otherwise.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import godot_binary  # noqa: E402  (tools/paths.py owns binary paths)

REPO = Path(__file__).resolve().parent.parent
GODOT = godot_binary()


def godot(*args: str) -> list[str]:
    return [str(GODOT), *args]


# (name, command, why it is in this tier). Order matters: cheapest and most
# diagnostic first, so a broken build is reported in seconds rather than after
# a twenty-minute sweep.
STEPS = {
    "import": (
        godot("--headless", "--path", "game", "--import"),
        "new scripts and images are invisible until imported (law 11)",
    ),
    "tests": (
        godot("--headless", "--path", "game", "-s", "tests/run_tests.gd"),
        "the rules still hold",
    ),
    "smoke": (
        godot("--headless", "--path", "game", "-s", "tests/smoke_boot.gd"),
        "the game boots and every screen has a real size",
    ),
    "propagation": (
        [sys.executable, "tools/kb_check.py"],
        "the change reached every place it had to (docs/architecture/change-map.json)",
    ),
    "minigames": (
        godot("--headless", "--path", "game", "-s", "tests/minigames.gd"),
        "every puzzle is playable and unbreakable",
    ),
    "chaos": (
        godot("--headless", "--path", "game", "-s", "tests/fuzz.gd", "--", "--seeds", "60"),
        "playing badly on purpose cannot reach an illegal state (law 14)",
    ),
    "balance": (
        godot("--headless", "--path", "game", "-s", "tests/simulate.gd"),
        "the fights are still fair (law 8)",
    ),
    "art-repetition": (
        [sys.executable, "tools/art_repetition.py"],
        "no illustration carries more than 3 consecutive beats (law 19)",
    ),
    "art-canon": (
        [sys.executable, "tools/art_catalog.py", "check"],
        "no daylight art in a night scene, no kerchief before sc_collar (art rule 6)",
    ),
    "story-canon": (
        [sys.executable, "tools/story_catalog.py", "check"],
        "every scene written up; art matches the hour the scene happens; "
        "recurring characters have reference art (art rule 4)",
    ),
    "tour": (
        [sys.executable, "tools/tour_all.py"],
        "every quest photographed, nothing off the page (laws 1 and 17)",
    ),
}

TIERS = {
    "fast": ["import", "tests", "propagation"],
    "standard": ["import", "tests", "smoke", "propagation", "minigames", "chaos"],
    "full": list(STEPS),
}

# A hung headless Godot must hang the GATE, not the night: every step gets a
# ceiling, generous enough that only a genuine wedge (a stale .godot lock, a
# tour leg waiting on a dialog) trips it. Seconds.
TIMEOUTS = {"tour": 2400, "balance": 1200, "chaos": 1200}
DEFAULT_TIMEOUT = 600

# What a change to each area needs. Printed by --for so the tier is a decision
# rather than a guess.
FOR_AREA = {
    "core": ("standard", "rules changed: the fuzzer and the sim both have opinions"),
    "rules": ("standard", "a tuning dial moved: balance and chaos both re-run"),
    "data": ("standard", "content changed: validation and the bots cover it"),
    "story": ("full", "prose changed: art repetition and the story critic want a look"),
    "scenes": ("full", "UI changed: nothing but the tour proves it (law 1)"),
    "ui": ("full", "the layout contract changed: every screen has to be re-photographed"),
    "docs": ("fast", "prose about the game, not the game"),
    "tools": ("fast", "tooling: the propagation check covers the references"),
}


def run(name: str, quiet: bool) -> tuple[bool, float]:
    command, why = STEPS[name]
    print(f"  {name:16s} … ", end="", flush=True)
    started = time.time()
    try:
        done = subprocess.run(command, cwd=REPO, capture_output=True, text=True,
                              encoding="utf-8", errors="replace",
                              timeout=TIMEOUTS.get(name, DEFAULT_TIMEOUT))
    except subprocess.TimeoutExpired:
        elapsed = time.time() - started
        print(f"FAIL  {elapsed:5.1f}s   TIMED OUT — check for a stale Godot "
              "process holding the .godot lock (law 27)")
        return False, elapsed
    elapsed = time.time() - started
    output = (done.stdout or "") + "\n" + (done.stderr or "")
    # Godot exits 0 even when a script error scrolled past, so the streams are
    # searched as well as the exit code.
    broke = "SCRIPT ERROR" in output or "Parse Error" in output
    passed = done.returncode == 0 and not broke
    print(("ok  " if passed else "FAIL") + f"  {elapsed:5.1f}s   {why}")
    if not passed and not quiet:
        interesting = [line for line in output.splitlines()
                       if any(marker in line for marker in
                              ("FAIL", "SCRIPT ERROR", "Parse Error", "LAYOUT:", "problems"))]
        for line in (interesting or output.splitlines())[-14:]:
            print(f"        {line[:150]}")
    return passed, elapsed


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("tier", nargs="?", default="standard", choices=list(TIERS))
    parser.add_argument("--for", dest="area", choices=list(FOR_AREA),
                        help="pick the tier that matches what you changed")
    parser.add_argument("--quiet", action="store_true", help="suppress failure detail")
    args = parser.parse_args()

    tier = args.tier
    if args.area:
        tier, reason = FOR_AREA[args.area]
        print(f"{args.area}/ changed -> {tier} tier ({reason})\n")

    if not GODOT.exists():
        sys.exit(f"Godot not found at {GODOT} — set GODOT_BIN or see CLAUDE.md.")

    print(f"verify: {tier} tier ({len(TIERS[tier])} steps)\n")
    failed, total = [], 0.0
    for name in TIERS[tier]:
        passed, elapsed = run(name, args.quiet)
        total += elapsed
        if not passed:
            failed.append(name)
            # A broken build makes every later step meaningless noise.
            if name in ("import", "tests"):
                print(f"\n  stopping: nothing after `{name}` can be trusted.")
                break

    print(f"\n  {total:.0f}s total")
    if failed:
        print(f"  FAILED: {', '.join(failed)}")
        sys.exit(1)
    if tier == "full":
        print("  Now READ the screenshots in screenshots/ — the sweep proves they")
        print("  were produced, not that they look right (law 1).")
    print("  clean.")


if __name__ == "__main__":
    main()
