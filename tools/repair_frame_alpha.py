"""Fill alpha holes INSIDE ui_frame_portrait's drawn wood.

The white-key pass (genart_ui.cut_alpha) that lifted the frame off its
generated background also keyed the bright highlight pixels inside the wood
and the brass corners, leaving pinholes the owner can see the page through
(owner defect 2026-08-10: "the current one has transparent bits along the
wood image").

Repair, not regeneration: transparency connected to the canvas border is the
true outside, transparency connected to the centre is the true aperture —
both stay. Every other transparent/semi pixel is a hole in the wood and gets
its alpha restored (RGB is inpainted from opaque neighbours when the keyed
pixel's colour was destroyed). Deterministic, free, and the frame the layout
was calibrated against does not change shape.

SPENT, 2026-08-17. The frame this repairs was replaced by
`ui_frame_portrait_thin` and archived, so LIBRARY below no longer resolves and
running this does nothing useful. Kept because the technique is the reusable
part: any white-keyed master can come back with pinholes in it, and the
flood-fill-from-the-border/flood-fill-from-the-centre trick is how you tell a
hole in the art from the art's real outside and its real aperture. Point
LIBRARY at the master that needs it.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
LIBRARY = ROOT / "assets" / "library" / "ui" / "ui_frame_portrait.png"
ARCHIVE = ROOT / "assets" / "archive" / "superseded" / "ui_frame_portrait__holes.png"

EDGE_GUARD = 3  # px of anti-aliased edge to leave untouched


def longest_soft_run(cells):
    """(start, length) of the longest consecutive True run."""
    best = (0, 0)
    start, length = 0, 0
    for i, v in enumerate(cells):
        if v:
            if length == 0:
                start = i
            length += 1
            if length > best[1]:
                best = (start, length)
        else:
            length = 0
    return best


def main() -> None:
    im = Image.open(LIBRARY).convert("RGBA")
    w, h = im.size
    px = im.load()
    soft = [[px[x, y][3] < 224 for x in range(w)] for y in range(h)]

    # The aperture is the one region that must STAY transparent. Cracks in
    # the wood connect to it, so flood-fill lies — measure it geometrically:
    # in each middle row/column the aperture is the longest transparent run;
    # the rect is the median of those runs (cracks are outliers, the median
    # ignores them).
    xs0, xs1, ys0, ys1 = [], [], [], []
    for y in range(int(h * 0.3), int(h * 0.7)):
        start, length = longest_soft_run(soft[y])
        if length > w * 0.4:
            xs0.append(start)
            xs1.append(start + length)
    for x in range(int(w * 0.3), int(w * 0.7)):
        col = [soft[y][x] for y in range(h)]
        start, length = longest_soft_run(col)
        if length > h * 0.4:
            ys0.append(start)
            ys1.append(start + length)
    xs0.sort(); xs1.sort(); ys0.sort(); ys1.sort()
    ap = (xs0[len(xs0) // 2], ys0[len(ys0) // 2],
          xs1[len(xs1) // 2], ys1[len(ys1) // 2])
    print("aperture rect", ap)

    def keep(x, y):
        # The aperture (plus its anti-aliased fringe), and the canvas edge.
        if ap[0] - EDGE_GUARD <= x < ap[2] + EDGE_GUARD \
                and ap[1] - EDGE_GUARD <= y < ap[3] + EDGE_GUARD:
            return True
        return x < EDGE_GUARD or y < EDGE_GUARD \
            or x >= w - EDGE_GUARD or y >= h - EDGE_GUARD

    holes = [(x, y) for y in range(h) for x in range(w)
             if soft[y][x] and not keep(x, y)]
    print(f"holes to repair: {len(holes)}")

    ARCHIVE.parent.mkdir(parents=True, exist_ok=True)
    im.save(ARCHIVE)  # never delete art — the holed take is retrievable

    hole_set = set(holes)
    for x, y in holes:
        r, g, b, a = px[x, y]
        if a < 32:
            # The key destroyed the colour too: average the opaque ring.
            rs = gs = bs = n = 0
            for dx in range(-2, 3):
                for dy in range(-2, 3):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in hole_set:
                        nr, ng, nb, na = px[nx, ny]
                        if na >= 224:
                            rs += nr; gs += ng; bs += nb; n += 1
            if n:
                # Keyed pixels were bright highlights — bias back toward
                # light so the glint reads as a glint, not a smudge.
                r = min(255, int(rs / n * 1.15))
                g = min(255, int(gs / n * 1.15))
                b = min(255, int(bs / n * 1.10))
        px[x, y] = (r, g, b, 255)

    im.save(LIBRARY)
    print(f"repaired {len(holes)} px -> {LIBRARY}")


if __name__ == "__main__":
    main()
