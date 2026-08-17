"""Fetch the Kenney CC0 audio packs used by the SFX shortlist.

The packs are deliberately NOT in this repo (see docs/design/sfx-shortlist.md).
They download to C:\\Users\\yurim\\assets\\kenney-audio — outside the repo and
outside OneDrive — so the library neither bloats git nor syncs to the cloud.
Only the curated shortlist is ever staged into assets/incoming/sfx/ for
audition (tools/stage_sfx.py); survivors go on to assets/library/sfx/.

Licence: Creative Commons Zero. Commercial use, no attribution required.

    python tools/fetch_kenney.py [--dest <dir>]
"""
from __future__ import annotations

import argparse
import sys
import urllib.request
import zipfile
from pathlib import Path

DEFAULT_DEST = Path.home() / "assets" / "kenney-audio"

# Kenney's download URLs carry a content hash; they change when a pack is
# revised. If one 404s, re-read it off the pack page at kenney.nl/assets/<slug>.
PACKS = {
    "kenney_interface-sounds": "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
    "kenney_ui-audio": "https://kenney.nl/media/pages/assets/ui-audio/490d233f68-1677590494/kenney_ui-audio.zip",
    "kenney_rpg-audio": "https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip",
    "kenney_impact-sounds": "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
    "kenney_music-jingles": "https://kenney.nl/media/pages/assets/music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip",
}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dest", type=Path, default=DEFAULT_DEST)
    args = ap.parse_args()

    zips = args.dest / "zips"
    zips.mkdir(parents=True, exist_ok=True)

    total = 0
    for name, url in PACKS.items():
        archive = zips / f"{name}.zip"
        if not archive.exists():
            print(f"downloading {name} ...")
            urllib.request.urlretrieve(url, archive)
        with zipfile.ZipFile(archive) as z:
            z.extractall(args.dest / name)
        count = len(list((args.dest / name).rglob("*.ogg")))
        total += count
        print(f"  {name}: {count} .ogg")

    print(f"\n{total} files in {args.dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
