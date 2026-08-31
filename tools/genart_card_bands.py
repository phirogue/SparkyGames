"""Widen the energy cards' printed name band — 2026-08-30.

Owner defect: "the energy cards for the long way home minigame are too small
to fit the name of the energy type on them."

MEASURED, not eyeballed. The shipped frame is 393x512 in-game and its printed
band's inner clear area runs x=65..327 — 66.7% of the card's width. The humour
names at the 22px type floor (law 29) measure:

    Guile 48 · Shadow 71 · Ferocity 72 · Moonlight 94

so only Guile fits, and "Moonlight" would need a 141px-wide card. At the art's
true 3:4 that is 184px tall against a paw zone of 118 in a board budgeted to
the pixel — the picture the owner asked to be made BIGGER on 2026-08-16 would
have had to pay for it. Owner chose the art fix (2026-08-30).

One thing changes: the band spans ~92% of the card instead of 66.7%. Run with
--ref against the shipped frames so it is provably the SAME card and not four
new ones (art rule 9: prefer editing over re-rolling).

    python tools/genart_card_bands.py

~$0.19 x 4. genart.py writes into assets/library/ui/ and moves what it
displaces into assets/archive/superseded/.
"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIBRARY = ROOT / "assets" / "library" / "ui"

# The band is the ONLY difference asked for. Everything else is named too, so
# the edit has no licence to redesign the card: the first frame prompt came
# back with rails thick enough to eat a third of the portrait precisely
# because it did not say how wide they were (ui-template-prompts.md, Group C).
# Hence the explicit fraction here.
PROMPT = (
    "Keep this blank playing card template exactly as it is — same cream card "
    "face, same rounded corners, same {colour} double-line hand-inked border, "
    "same proportions, same empty centre. Change ONE thing: make the small "
    "empty name band across the bottom much WIDER, so it spans about 92% of "
    "the card's width, running nearly the full inner width of the card and "
    "stopping just short of the coloured border on each side. The band stays "
    "the same height and stays completely empty. Perfectly symmetric, no "
    "lettering anywhere on the card."
)

CARDS = {
    "ui_frame_card_red": "deep red",
    "ui_frame_card_green": "moss green",
    "ui_frame_card_black": "charcoal black",
    "ui_frame_card_blue": "pale silver-blue",
}


def main() -> int:
    failures = []
    for asset_id, colour in CARDS.items():
        source = LIBRARY / f"{asset_id}.png"
        if not source.exists():
            print(f"!! {asset_id}: no source to edit at {source}")
            failures.append(asset_id)
            continue
        print(f"== {asset_id} ({colour})")
        result = subprocess.run(
            [
                sys.executable, str(ROOT / "tools" / "genart.py"), asset_id,
                "--ref", str(source),
                "--ratio", "3:4",
                "--quality", "high",
                # A card frame's whole job is a printed band and a blank face;
                # the shared style block ends by forbidding text, which is
                # what we want, but it also describes a loose watercolour
                # scene, which a template is not. The reference carries the
                # look — that is the point of editing rather than re-rolling.
                "--no-style",
                "--prompt", PROMPT.format(colour=colour),
            ],
            cwd=str(ROOT),
        )
        if result.returncode != 0:
            failures.append(asset_id)
    if failures:
        print("\nFAILED: " + ", ".join(failures))
        return 1
    print("\nAll four frames regenerated. Now READ them and MEASURE the band "
          "(genart skill step 4) before wiring anything.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
