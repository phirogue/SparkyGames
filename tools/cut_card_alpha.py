"""Lift the energy-card frames off the dark field they were generated on.

Law 22, collected again on 2026-08-30: the wider-band regeneration came back
1024x1536 and FULLY OPAQUE — the card floating in a near-black surround with a
white glow around it — where the frames it replaced were cut out properly. Wire
that as-is and every energy card renders as a black tile with a card printed
somewhere in the middle of it.

`genart_ui.cut_alpha` keys out WHITE and is no use here. The key that works on
this field is COLOUR, not brightness: the card's face and its cream border ring
are warm (R - B well above zero), while the background, the glow and the ink
outlines are all neutral greys. So:

  1. mark the warm, bright pixels          -> the card's cream, nothing else
  2. dilate by the outline's own width     -> takes the dark ink edge back in
  3. fill each row between its first and   -> a rounded rectangle is convex, so
     last marked pixel                        this restores the exact silhouette
  4. feather one pixel, crop to content

Deterministic and free. Run it again on any future regeneration of these four:

    python tools/cut_card_alpha.py
"""

from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
LIBRARY = ROOT / "assets" / "library" / "ui"
CARDS = [
    "ui_frame_card_red", "ui_frame_card_green",
    "ui_frame_card_black", "ui_frame_card_blue",
]

## The card's cream reads R-B ~= 60 at the face and ~= 35 in the border ring;
## the glow at its brightest is neutral to within a couple of counts. 14 sits
## clear of both.
WARMTH = 14
BRIGHTNESS = 120
## How far past the cream to take the mask, to catch the card's outer ink
## line. Tuned DOWN from 9px on 2026-08-30: 9 reached past the ink and pulled
## a rim of the generated glow in with it, which rendered as a grey halo
## around every card. 5 stops inside the line — the outermost hairline of ink
## is sacrificed, which at the 96-150px the card is actually drawn at is
## nothing, and a halo is not.
DILATE = 11
## Rows with less marked than this are specks, not card.
MIN_RUN = 40


def silhouette(im: Image.Image) -> Image.Image:
    w, h = im.size
    px = im.load()
    mask = Image.new("L", (w, h), 0)
    mpx = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            if r - b > WARMTH and r > BRIGHTNESS:
                mpx[x, y] = 255
    mask = mask.filter(ImageFilter.MaxFilter(DILATE))
    # Convexify each row: a rounded rectangle has exactly one run per row, so
    # filling between the extremes restores the face the ink lines broke up.
    mpx = mask.load()
    for y in range(h):
        first, last, count = -1, -1, 0
        for x in range(w):
            if mpx[x, y]:
                if first < 0:
                    first = x
                last = x
                count += 1
        if first < 0 or count < MIN_RUN:
            for x in range(w):
                mpx[x, y] = 0
            continue
        for x in range(first, last + 1):
            mpx[x, y] = 255
    return mask.filter(ImageFilter.GaussianBlur(1.0))


def main() -> int:
    problems = []
    for asset_id in CARDS:
        path = LIBRARY / f"{asset_id}.png"
        if not path.exists():
            problems.append(f"{asset_id}: missing")
            continue
        im = Image.open(path).convert("RGBA")
        before = im.size
        im.putalpha(silhouette(im))
        bbox = im.getchannel("A").getbbox()
        if bbox:
            im = im.crop(bbox)
        im.save(path)
        w, h = im.size
        area = 100.0 * (w * h) / (before[0] * before[1])
        print(f"{asset_id}: {before[0]}x{before[1]} -> {w}x{h} "
              f"({area:.0f}% of the generated canvas)")
    for problem in problems:
        print("!! " + problem)
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
