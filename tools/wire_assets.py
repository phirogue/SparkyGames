"""Wire the art library into the game as downscaled runtime textures.

    python tools/wire_assets.py --list      # what would change
    python tools/wire_assets.py             # do it
    python tools/wire_assets.py sk_pounce   # just these ids

`assets/library/` holds the full-resolution masters (1024-1536px, several MB
each); the game ships downscaled copies in `game/assets/`. This is the step the
/genart skill calls "wiring". Before it existed the copy was done by hand, and
the hand drifted: the shipped skill cards were a whole generation behind the
library (flat crops instead of the deckle-edged parchment takes) and
`game/assets/ui/logo_ashcat_title.png` still showed Ash with a bare neck long
after he had been given the neckerchief.

Engineering law 11: run `godot --headless --path game --import` afterwards or
the tour renders black boxes for files that plainly exist.

NOT WIRED: `assets/library/ui/` chrome. Those masters are generated on opaque
fields -- ui_page carries a dark halo, ui_spool an olive backdrop -- and the
shipped copies had their backgrounds keyed and trimmed by hand. Copying them
raw would ship olive-field icons and move the page's stitching, which the
PAGE_MARGIN_* constants are calibrated against (laws 3 and 5). Re-doing that
pass is its own job; `logo_*` is exempt because it is a full-bleed poster.
"""

import argparse
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
LIB = REPO / "assets" / "library"
GAME = REPO / "game" / "assets"

# kind -> (rule, size, subfolder under game/assets). "w" pins the width so a
# family of art lands at one on-screen scale whatever the master's aspect;
# "long" pins the long edge, for glyphs and posters that are drawn to fit.
KINDS = {
    "backdrops": ("w", 720, ""),
    "enemies": ("w", 512, ""),
    "scenes": ("w", 512, ""),
    "characters": ("w", 512, ""),
    "skills": ("w", 300, ""),
    "energy": ("long", 220, ""),
    "logos": ("w", 720, "ui"),
}

# Masters that exist but nothing draws yet. Wiring them would grow the export
# for no pixels on screen, so they wait in the library until a screen asks.
UNWIRED = {
    "bg_mantel", "bg_mantel_scene", "npc_brindle_magpie", "npc_pigeon_postmaster",
    "npc_rat_boss", "ref_ash_prologue", "sc_hollow_court_desk",
}


def targets() -> list:
    out = []
    for kind, (rule, size, subdir) in KINDS.items():
        for src in sorted((LIB / kind).glob("*.png")):
            if src.stem not in UNWIRED:
                out.append((src, GAME / subdir / src.name, rule, size))
    return out


def resample(src: Path, dst: Path, rule: str, size: int) -> tuple:
    image = Image.open(src)
    image = image.convert("RGBA" if "A" in image.getbands() else "RGB")
    reference = image.width if rule == "w" else max(image.size)
    scale = min(1.0, size / reference)
    target = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    if target != image.size:
        image = image.resize(target, Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    image.save(dst, optimize=True)
    return target


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("ids", nargs="*", help="asset ids to wire (default: all)")
    parser.add_argument("--list", action="store_true", help="dry run")
    args = parser.parse_args()

    work = targets()
    if args.ids:
        wanted = set(args.ids)
        work = [t for t in work if t[0].stem in wanted]
        missing = wanted - {t[0].stem for t in work}
        if missing:
            sys.exit("not in the library (or listed UNWIRED): " + ", ".join(sorted(missing)))

    for src, dst, rule, size in work:
        before = Image.open(dst).size if dst.exists() else None
        if args.list:
            print(f"  {src.stem:26s} {Image.open(src).size} -> {before or 'MISSING'}")
            continue
        after = resample(src, dst, rule, size)
        note = "new" if before is None else ("resized" if before != after else "refreshed")
        print(f"  {src.stem:26s} {after}  {note}")

    print(f"\n{len(work)} texture(s) {'would be ' if args.list else ''}wired.")
    if not args.list:
        print("Now run: godot --headless --path game --import")


if __name__ == "__main__":
    main()
