"""Settings-screen UI elements, generated on white and cut to alpha locally.

gpt-image-2 rejects background="transparent" ("Transparent background is not
supported for this model"), and gpt-image-1 -- which does support it -- is the
old model whose output quality we rejected. So: generate on pure white with
the good model, then key out the white here. For flat icons on a clean white
field this is more reliable than the API flag anyway, and it lets us trim the
canvas at the same time -- the seven existing padded UI elements are the exact
hazard we're avoiding (CLAUDE.md engineering law 3).

Run:  python tools/genart_ui.py [--dry-run]
"""

import sys
import time

from PIL import Image

from genart import RATIO_TO_SIZE, generate, load_key, next_free_path

WHITE_BG = (
    " Centered on a plain PURE WHITE background with nothing else in the "
    "frame -- no border, no panel, no shadow on the background, no scenery."
)

JOBS = [
    dict(
        id="ui_settings_row",
        prompt=(
            "A single horizontal settings row plaque: a torn-edged strip of "
            "aged parchment with a fine dark-brown stitched border running "
            "around it and a small sprig of ink leaves in each corner, empty "
            "in the middle with nothing written on it. Hand-drawn storybook "
            "ink and watercolour. No text, no icons, no toggle switch."
        ),
        ratio="16:9",
    ),
    dict(
        id="ui_toggle_on",
        prompt=(
            "A toggle switch drawn as a sewn fabric pill: a rounded MOSS-GREEN "
            "felt track with a dashed stitch line around it, and a cream bone "
            "button sewn with a dark cross-stitch sitting at the RIGHT end of "
            "the track. Hand-drawn storybook ink and watercolour. No text."
        ),
        ratio="16:9",
    ),
    dict(
        id="ui_toggle_off",
        prompt=(
            "A toggle switch drawn as a sewn fabric pill: a rounded muted "
            "GREY-VIOLET felt track with a dashed stitch line around it, and a "
            "cream bone button sewn with a dark cross-stitch sitting at the "
            "LEFT end of the track. Hand-drawn storybook ink and watercolour. "
            "No text."
        ),
        ratio="16:9",
    ),
    dict(
        id="ui_icon_sound",
        prompt=(
            "A brass hand-bell tilted as if ringing, with two tiny ink motion "
            "ticks beside it, hand-drawn storybook ink and watercolour, warm "
            "brass and walnut ink, bold simple shapes that stay readable at 48 "
            "pixels. No text."
        ),
        ratio="1:1",
    ),
    dict(
        id="ui_icon_music",
        prompt=(
            "A single beamed pair of music notes in dark walnut ink with a soft "
            "blue-grey wash, two tiny ink stars beside them, hand-drawn "
            "storybook ink and watercolour, bold simple shapes readable at 48 "
            "pixels. No text."
        ),
        ratio="1:1",
    ),
    dict(
        id="ui_icon_brightness",
        prompt=(
            "A lit candle in a shallow tin dish, warm amber flame with three "
            "short ink rays around it, hand-drawn storybook ink and "
            "watercolour, bold simple shapes readable at 48 pixels. No text."
        ),
        ratio="1:1",
    ),
    dict(
        id="ui_icon_language",
        prompt=(
            "A sealed cream envelope seen face-on with a round red wax seal in "
            "the centre, hand-drawn storybook ink and watercolour, bold simple "
            "shapes readable at 48 pixels. No text."
        ),
        ratio="1:1",
    ),
]


def cut_alpha(path, threshold: int = 244) -> str:
    """Key out the white field and trim to content.

    Returns a short report so the caller can see the content actually fills
    the canvas rather than shipping another 30%-content element.
    """
    im = Image.open(path).convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            if r >= threshold and g >= threshold and b >= threshold:
                px[x, y] = (r, g, b, 0)
            elif r >= threshold - 18 and g >= threshold - 18 and b >= threshold - 18:
                # feather the rim so edges don't alias hard against the cut
                px[x, y] = (r, g, b, 128)
    bbox = im.getchannel("A").getbbox()
    if bbox:
        im = im.crop(bbox)
    im.save(path)
    nw, nh = im.size
    return f"alpha cut, trimmed {w}x{h} -> {nw}x{nh}"


def main() -> None:
    dry = "--dry-run" in sys.argv
    if dry:
        for j in JOBS:
            print(f"{j['id']} ({j['ratio']})")
        return
    key = load_key()
    ok = 0
    for i, job in enumerate(JOBS, 1):
        print(f"[{i}/{len(JOBS)}] {job['id']} generating...", flush=True)
        try:
            blobs = generate(
                job["prompt"] + WHITE_BG,
                RATIO_TO_SIZE[job["ratio"]],
                "high",
                1,
                key,
                "gpt-image-2",
            )
        except SystemExit as exc:
            print(f"    FAILED: {exc}", flush=True)
            continue
        path = next_free_path(job["id"])
        path.write_bytes(blobs[0])
        report = cut_alpha(path)
        print(f"    wrote {path.name} -- {report}", flush=True)
        ok += 1
        time.sleep(1)
    print(f"\ndone: {ok}/{len(JOBS)}")


if __name__ == "__main__":
    main()
