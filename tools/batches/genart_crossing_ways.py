"""The eight things that stand in a road (docs/design/minigames.md #5).

The Long Way Home was rebuilt on the owner's 2026-08-13 note as a chain of
DECISION POINTS, each with its own picture that changes as Ash comes to it.
These are those pictures: not places, but obstacles — the thing itself
dominant, the street dissolving into wash behind it.

Framed 16:9 because the board shows them as a wide band across the top of
the page, and shot at CAT HEIGHT: the point of every one of them is that it
is a problem for something twelve inches tall.

    python tools/batches/genart_crossing_ways.py            # all eight
    python tools/batches/genart_crossing_ways.py bg_way_dog # just one
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Every prompt ends with the same framing clause, because the whole set has to
# read as one journey rather than as eight unrelated pictures.
FRAMING = (
    " Seen from a cat's eye level, low to the wet cobbles. The obstacle fills "
    "the frame and the street behind it dissolves into loose wash. Night, "
    "unless otherwise said, with warm amber lamplight used sparingly against "
    "blue-grey shadow. No animals and no people unless the description names "
    "them."
)

WAYS = {
    "bg_way_gate": (
        "A tall iron gate shut across a narrow lane, its bars running floor to "
        "top of frame, no gap beneath it and none at the hinge. Beyond the bars "
        "the lane carries on into fog and one distant lamp."
    ),
    "bg_way_dog": (
        "A big chained yard-dog, awake and watchful, its chain running taut to "
        "a ring in the wall. It fills the right of the frame; the only way past "
        "is the narrow strip of dark along the left-hand wall."
    ),
    "bg_way_crowd": (
        "A crowd packed across a lane at night, seen as a forest of boots, "
        "coat-hems, walking sticks and lantern-light overhead. No faces — the "
        "people are legs and shadow, because that is all a cat can see of them."
    ),
    "bg_way_gap": (
        "A gap between two rooftops, too wide to walk, with the black drop of "
        "the street far below between them. Wet slate on both sides, chimney "
        "stacks against a cold sky."
    ),
    # Second take. The first read "the obstacle fills the frame" and invented
    # a giant barrel to be that obstacle — but here the obstacle IS the light,
    # and the emptiness is the whole point, so the prompt has to say so and
    # forbid a foreground prop outright (art rule: name the failure mode).
    "bg_way_lityard": (
        "A completely EMPTY courtyard at night, lit wall to wall by lamps on "
        "every side. Pale bare cobbles running unbroken from edge to edge with "
        "NO object anywhere in the foreground — no barrels, no crates, no "
        "carts, no barrows, nothing to hide behind. The emptiness and the open "
        "light ARE the subject. A far doorway a long way off across it, and "
        "not one patch of shadow the whole way."
    ),
    "bg_way_arch": (
        "A stone archway with a ward drawn across it: waxed thread strung "
        "corner to corner and chalk marks on the stones, taut and deliberate, "
        "still humming with the hand that tied it."
    ),
    "bg_way_water": (
        "Black canal water between two stone wharves, with a single narrow "
        "plank laid across it. The plank is wet and slightly bowed; the water "
        "gives back one broken reflection of a lamp."
    ),
    "bg_way_watch": (
        "A watchman standing on a street corner with a raised lantern, seen "
        "from behind and below — boots, coat-hem, the long thrown shadow, and "
        "the pool of light he is holding over the crossing."
    ),
}


def generate(asset_id: str, description: str) -> int:
    print(f"--- {asset_id}")
    result = subprocess.run(
        [sys.executable, "tools/genart.py", asset_id,
         "--ratio", "16:9", "--quality", "high",
         "--prompt", description + FRAMING],
        cwd=ROOT,
    )
    return result.returncode


def main() -> int:
    wanted = sys.argv[1:] or list(WAYS)
    failed = []
    for asset_id in wanted:
        if asset_id not in WAYS:
            print(f"unknown id '{asset_id}'")
            return 2
        if generate(asset_id, WAYS[asset_id]) != 0:
            failed.append(asset_id)
    print(f"\n{len(wanted) - len(failed)}/{len(wanted)} generated")
    if failed:
        print("failed: " + ", ".join(failed))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
