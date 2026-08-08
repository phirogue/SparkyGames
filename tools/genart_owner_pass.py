"""Art for the 2026-08-05 owner pass: one missing scene, two to break
repetition runs, one recoloured.

    python tools/genart_owner_pass.py --list   # spend nothing
    python tools/genart_owner_pass.py

Library and archive were both checked first (art rules 1 and 2). Findings:
  - sc_hollow_stairs   does not exist anywhere; the stairs beat is new.
  - sc_needle_lane_*   only one view of the wrong lane exists, and it carries
                       four consecutive beats (law 19).
  - parlor             three takes archived, all the SAME angle; the Carrying
                       needs a different one, not an older one.
  - sc_kettle          the archived v1 is the same warm kitchen as the
                       shipped file, so restoring it would not fix the note.
                       Regenerated FROM the current image so it stays the
                       same room with the light taken out of it.

Ash appears in two of these and both are after the title card, so he is
generated from `ref_ash.png` WITH the neckerchief (art rule 4).
"""

import argparse
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REF_ASH = "assets/library/characters/ref_ash.png"
KETTLE = "assets/library/scenes/sc_kettle.png"

# (asset_id, ratio, [refs], prompt)
BATCH = [
    (
        "sc_hollow_stairs", "3:4", [REF_ASH],
        "A narrow stone stair climbing up out of an enormous dark hall of "
        "filing shelves towards one small warm doorway very far above. The "
        "shelves and ledgers fall away into blue-grey wash below and to "
        "either side; the stair is the only lit thing, and the light on it "
        "comes from the doorway at the top. This same black cat with the red "
        "neckerchief is small at the bottom of the frame, seen from behind, "
        "starting up. Vast, quiet, administrative. Not frightening — tiring."
    ),
    (
        "sc_needle_lane_deep", "3:4", None,
        "Deep in a narrow foggy alley at night, looking along it. The "
        "street lamps down its length are all dark, unlit, their glass cold. "
        "Fog off an estuary has come up past the doorsteps and sits in the "
        "lane like standing water. Wet cobbles, shuttered windows, a dead "
        "lamp in the near foreground with its ladder still leaning against "
        "it and nobody on the ladder. No people, no cat. Blue-grey, and one "
        "small amber window very far away that only makes the rest colder."
    ),
    (
        "sc_parlor_doorway", "3:4", None,
        "The doorway of a witch's workroom seen from inside the room at "
        "dawn, looking out into a dim hallway. Dozens of cut threads hang "
        "down the door frame and the walls to either side, all snipped at "
        "the same height, ends loose. A grey unlit lamp, a work table with "
        "scissors and pinned patterns, an empty chair pushed back. Nobody in "
        "the picture. Cold blue morning light from the left, no fire lit. "
        "The room after something has happened in it."
    ),
    (
        "sc_kettle", "3:4", [KETTLE, REF_ASH],
        "The SAME kitchen, the same stove, the same cat — but the fire is "
        "OUT and the room is cold. Keep the composition: the black cat with "
        "the red neckerchief up on his hind legs pushing the copper kettle "
        "off the stove top. Change the light: no warm glow from the stove "
        "door, no amber on the floorboards, no steam. Only thin blue "
        "moonlight through the window, the room in blue-grey shadow, the "
        "copper dull rather than shining. The same painting, at the wrong "
        "hour of the worst night."
    ),
]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true", help="dry run")
    parser.add_argument("--only", nargs="*")
    args = parser.parse_args()

    batch = [b for b in BATCH if not args.only or b[0] in set(args.only)]
    for asset_id, ratio, refs, prompt in batch:
        command = [
            sys.executable, str(REPO / "tools" / "genart.py"), asset_id,
            "--ratio", ratio, "--quality", "high", "--prompt", prompt,
        ]
        for ref in refs or []:
            command += ["--ref", ref]
        print(f"\n=== {asset_id} ({ratio}{', from ref' if refs else ''}) ===")
        if args.list:
            print("    " + prompt[:110] + "...")
            continue
        if subprocess.run(command, cwd=REPO).returncode != 0:
            sys.exit(f"{asset_id} failed")

    print(f"\n{len(batch)} image(s) {'would be ' if args.list else ''}generated.")
    if not args.list:
        print("Next: READ every file (law 1), wire, import, re-run kb_check.")


if __name__ == "__main__":
    main()
