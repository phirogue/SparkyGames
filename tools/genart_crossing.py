"""Crossing-board glyphs for The Long Way Round (owner 2026-08-11: bring the
minigame boards up to the battle screen's standard, with real art).

Three 1:1 marks, generated on pure white and alpha-keyed locally the same way
the settings icons were (gpt-image-2 refuses background=transparent; see
genart_ui.py). Everything else the board needs already exists: environment
backdrops for the framed vignette, the wood portrait frame, the humour card
frames and glyphs for the hand.

Run:  python tools/genart_crossing.py [--dry-run]
"""

import sys
import time

from genart import RATIO_TO_SIZE, generate, load_key, next_free_path
from genart_ui import cut_alpha

WHITE_BG = (
    " Centered on a plain PURE WHITE background with nothing else in the "
    "frame -- no border, no panel, no shadow on the background, no scenery."
)

JOBS = [
    dict(
        id="ui_token_ash",
        prompt=(
            "A small game-piece mark of a slim black cat mid-stride, seen in "
            "full side profile walking to the right, wearing a tiny ragged "
            "red kerchief at the throat, tail up. Hand-drawn storybook ink "
            "and watercolour, loose ink line, flat and readable at thumbnail "
            "size like a map token. No text." + WHITE_BG
        ),
    ),
    dict(
        id="ui_icon_home_lamp",
        prompt=(
            "A small glyph of a warmly lit cottage window at night: a simple "
            "four-pane window with amber light glowing through it and a "
            "little sill, hand-drawn storybook ink and watercolour, flat and "
            "readable at thumbnail size like a map marker. No text."
            + WHITE_BG
        ),
    ),
    dict(
        id="ui_gust_swirl",
        prompt=(
            "A small glyph of a gust of wind: two or three curling storm "
            "swirl lines with a few flecks of rain caught in them, hand-drawn "
            "storybook ink in deep blue-grey watercolour, flat and readable "
            "at thumbnail size. No text." + WHITE_BG
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
        images = generate(job["prompt"], RATIO_TO_SIZE["1:1"], "high", 1,
            key, "gpt-image-2")
        target.write_bytes(images[0])
        print(job["id"], cut_alpha(target))
        time.sleep(1.0)


if __name__ == "__main__":
    main()
