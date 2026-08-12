"""Board furniture for the mission minigames (owner 2026-08-11: bring every
board up to the battle screen's standard).

Three textures shared across the five modules: the embroidery hoop that
frames Seam & Stitch, the linen square that fields Patch the Ward (and,
modulated dark, The Unpicking), and the stitched ribbon band Testimony's
statements are written on. Generated on white and alpha-keyed locally, same
pass as the settings icons (see genart_ui.py).

Run:  python tools/genart_minigames.py [--dry-run]
"""

import sys
import time

from genart import RATIO_TO_SIZE, generate, load_key, next_free_path
from genart_ui import cut_alpha

WHITE_BG = (
    " On a plain PURE WHITE background with nothing else in the frame -- no "
    "border, no panel, no shadow on the background, no scenery."
)

JOBS = [
    dict(
        id="ui_hoop",
        ratio="1:1",
        prompt=(
            "A round wooden embroidery hoop seen exactly from above, plain "
            "warm wood with a small brass tightening screw at the top, "
            "holding a stretched piece of plain cream linen cloth that "
            "completely fills the inside of the hoop with subtle woven "
            "texture, nothing embroidered on it. Hand-drawn storybook ink "
            "and watercolour. No text." + WHITE_BG
        ),
    ),
    dict(
        id="ui_cloth_linen",
        ratio="1:1",
        prompt=(
            "A square swatch of plain woven linen cloth in warm cream, seen "
            "flat from above, edges slightly frayed with a few loose thread "
            "ends, subtle woven texture, nothing embroidered on it. "
            "Hand-drawn storybook ink and watercolour. No text." + WHITE_BG
        ),
    ),
    dict(
        id="ui_ribbon_band",
        ratio="16:9",
        prompt=(
            "A single long horizontal band of cream fabric ribbon with a "
            "fine dark stitched running-seam border just inside its edges "
            "and slightly frayed short ends, empty in the middle with "
            "nothing written on it, subtle woven texture. Hand-drawn "
            "storybook ink and watercolour. No text." + WHITE_BG
        ),
    ),
]


def main() -> None:
    if "--dry-run" in sys.argv:
        for job in JOBS:
            print(job["id"])
        return
    key = load_key()
    for job in JOBS:
        target = next_free_path(job["id"])
        images = generate(job["prompt"], RATIO_TO_SIZE[job["ratio"]], "high",
            1, key, "gpt-image-2")
        target.write_bytes(images[0])
        print(job["id"], cut_alpha(target))
        time.sleep(1.0)


if __name__ == "__main__":
    main()
