"""Chapter 1 opening arc — the four images that content now references.

    python tools/genart_ch1_arc.py            # do it
    python tools/genart_ch1_arc.py --list     # show what would run, spend nothing

Library and archive were both checked first (art rules 1 and 2): none of these
four ids exist in either, and Brindle was NOT generated because
`npc_brindle_magpie.png` was already in the library and already right.

The two scenes carry Ash, so they go through the images EDITS endpoint against
`ref_ash.png` (art rule 4 — words alone let him drift into a different breed).
Both beats are after the title card, so he WEARS the neckerchief; the
prologue reference would be the wrong one here.

The two evidence objects are framed like skill cards: the thing alone on plain
parchment, no environment, because on the Case Board they read as pinned to it.
"""

import argparse
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REF_ASH = "assets/library/characters/ref_ash.png"

# (asset_id, ratio, ref-or-None, prompt)
BATCH = [
    (
        "sc_the_carrying", "3:4", REF_ASH,
        "A cold witch's parlor at first light. Three women in grey homespun "
        "lift a body wrapped in undyed linen out of a high-backed armchair. "
        "The eldest is huge and heavy-shouldered and has stopped in the "
        "doorway to look at the walls, where dozens of cut threads hang down "
        "like torn hems. The two younger women are doing the lifting and are "
        "frightened of it. This same black cat with the red neckerchief sits "
        "on the mantelpiece above the dead hearth, absolutely still, watching. "
        "Grey dawn through a tall window, one guttered candle. Quiet, formal "
        "grief held at arm's length — nobody is weeping and nobody is looking "
        "at anybody."
    ),
    (
        "sc_the_wake", "3:4", REF_ASH,
        "A funeral at the tideline at dusk. A shrouded figure lies on a low "
        "wooden bier at the edge of a wide flat grey estuary, wet sand around "
        "it. Women in grey stand close in around the bier; a small group of "
        "guild delegates in good dark coats and hats stand well apart from "
        "them, further up the beach, present but not mourning. This same black "
        "cat with the red neckerchief is up on a tarred mooring post, alone, "
        "apart from both groups, facing the water. Low amber light off the "
        "wet sand against a cold blue-grey sky and a far shoreline dissolving "
        "into wash."
    ),
    (
        "ev_candle_stub", "1:1", None,
        "A single object lying on plain undyed parchment, nothing else in the "
        "picture, no background scene and no table: a short stubby beeswax "
        "candle end, honey-coloured, burnt down low with a blackened wick and "
        "a run of melted wax down one side. Pressed into the soft wax on its "
        "flank is a small round guild seal. Painted as a careful study of one "
        "object, warm against the cream paper."
    ),
    (
        "ev_docket", "1:1", None,
        "A single object lying on plain undyed parchment, nothing else in the "
        "picture, no background scene and no table: a small grubby paper cart "
        "delivery docket, creased from being folded once, thumbed and stained "
        "at one corner. It carries faint ruled lines and blocks of illegible "
        "handwriting, and one line near the bottom has been heavily scratched "
        "out with ink. Painted as a careful study of one object."
    ),
]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true", help="dry run, spend nothing")
    parser.add_argument("--only", nargs="*", help="just these asset ids")
    args = parser.parse_args()

    batch = BATCH
    if args.only:
        batch = [b for b in BATCH if b[0] in set(args.only)]

    for asset_id, ratio, ref, prompt in batch:
        command = [
            sys.executable, str(REPO / "tools" / "genart.py"), asset_id,
            "--ratio", ratio, "--quality", "high", "--prompt", prompt,
        ]
        if ref:
            command += ["--ref", ref]
        print(f"\n=== {asset_id} ({ratio}{', from ref' if ref else ''}) ===")
        if args.list:
            print("    " + prompt[:110] + "...")
            continue
        result = subprocess.run(command, cwd=REPO)
        if result.returncode != 0:
            sys.exit(f"{asset_id} failed (exit {result.returncode})")

    print(f"\n{len(batch)} image(s) {'would be ' if args.list else ''}generated.")
    if not args.list:
        print("Next: READ every file (law 1), then wire_assets.py + --import.")


if __name__ == "__main__":
    main()
