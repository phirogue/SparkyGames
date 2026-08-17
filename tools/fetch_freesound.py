"""Fetch CC0 sounds from Freesound for the gaps Kenney and Sonniss leave.

Downloads to C:\\Users\\yurim\\assets\\freesound — outside the repo, like the
other libraries (see docs/design/sfx-shortlist.md). Only the curated shortlist
is ever staged into assets/incoming/sfx/ for audition (tools/stage_sfx.py).

**CC0 ONLY.** The filter is not a preference, it is the licence policy: CC0
needs no attribution and cannot be revoked, so nothing has to be tracked
through to the store listing. Freesound also carries CC-BY and
CC-BY-NC material; NC would make the game unshippable and BY would mean
maintaining a credits manifest forever. Do not widen the filter.

Needs a free API key from https://freesound.org/apiv2/apply — put it in the
repo-root .env as:

    FREESOUND_API_KEY=...

    python tools/fetch_freesound.py            # fetch every query below
    python tools/fetch_freesound.py --only cat # just the queries tagged 'cat'
    python tools/fetch_freesound.py --dry-run  # search and report, download nothing
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://freesound.org/apiv2"
DEST = Path.home() / "assets" / "freesound"
ENV = Path(__file__).resolve().parent.parent / ".env"

# Each query targets a hole in the other two libraries. `group` lets you fetch
# one theme at a time; `secs` bounds duration so a 4-minute field recording
# never lands in a folder of one-shots.
#
# Keep queries to ONE or TWO words. CC0 is a small slice of Freesound, so a
# descriptive three-word phrase ("unravel string pull", "rubber stamp paper")
# reliably returns nothing — seven of the first draft's queries came back empty
# for exactly that reason. Probe a candidate before adding it.
QUERIES = [
    # The conspicuous absence: 509 files from Kenney + Sonniss, a game about a
    # cat, not one cat.
    {"group": "cat", "q": "cat purr", "secs": (0.5, 15)},
    {"group": "cat", "q": "cat meow", "secs": (0.2, 4)},
    {"group": "cat", "q": "cat hiss", "secs": (0.2, 4)},
    {"group": "cat", "q": "cat growl", "secs": (0.2, 6)},
    {"group": "cat", "q": "cat trill", "secs": (0.1, 4)},      # the chirrup

    # Thread and cloth — the game's whole material vocabulary.
    {"group": "thread", "q": "wire snap", "secs": (0.05, 3)},
    {"group": "thread", "q": "elastic snap", "secs": (0.05, 3)},
    {"group": "thread", "q": "fabric tear rip", "secs": (0.2, 4)},
    {"group": "thread", "q": "sewing needle fabric", "secs": (0.1, 4)},
    {"group": "thread", "q": "cloth rustle", "secs": (0.2, 5)},
    {"group": "thread", "q": "string pull", "secs": (0.1, 5)},
    {"group": "thread", "q": "fabric stretch", "secs": (0.1, 5)},

    # Rooftops, the Crossing, the fog.
    {"group": "roof", "q": "bird wings", "secs": (0.2, 8)},
    {"group": "roof", "q": "pigeon", "secs": (0.2, 8)},
    {"group": "roof", "q": "wind gust", "secs": (1, 30)},

    # The Mantel, the Court, interiors.
    {"group": "room", "q": "room tone", "secs": (5, 60)},
    {"group": "room", "q": "candle flame flicker", "secs": (1, 20)},
    {"group": "room", "q": "wooden floor creak", "secs": (0.3, 5)},
    {"group": "room", "q": "office stamp", "secs": (0.05, 3)},  # the Court
    {"group": "room", "q": "crowd murmur", "secs": (3, 60)},

    # Other animals the bestiary needs.
    {"group": "beast", "q": "rat squeak", "secs": (0.1, 4)},
    {"group": "beast", "q": "crow raven call", "secs": (0.2, 6)},
]

FIELDS = "id,name,username,license,duration,filesize,previews,tags,url"


def api_key() -> str:
    if not ENV.exists():
        sys.exit(f"No .env at {ENV}. Add FREESOUND_API_KEY=... to it.")
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.startswith("FREESOUND_API_KEY="):
            key = line.split("=", 1)[1].strip()
            if key:
                return key
    sys.exit("FREESOUND_API_KEY missing or empty in .env — get one free at "
             "https://freesound.org/apiv2/apply")


def search(key: str, query: str, secs: tuple[float, float], limit: int) -> list[dict]:
    lo, hi = secs
    params = {
        "query": query,
        # CC0 only — see the module docstring. Do not widen.
        "filter": f'license:"Creative Commons 0" duration:[{lo} TO {hi}]',
        "sort": "rating_desc",
        "fields": FIELDS,
        "page_size": limit,
        "token": key,
    }
    url = f"{API}/search/text/?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.load(r).get("results", [])


def download(sound: dict, out_dir: Path, key: str) -> Path | None:
    # Token auth is read-only: it reaches previews, not originals (those need
    # OAuth2). Previews are lossy — fine for auditioning and, at phone-speaker
    # scale, usually fine to ship. Re-fetch an original by hand if one matters.
    uri = sound["previews"].get("preview-hq-ogg") or sound["previews"].get("preview-hq-mp3")
    if not uri:
        return None
    safe = "".join(c if c.isalnum() or c in " -_." else "_" for c in sound["name"])
    # The uploader's filename often carries its own extension (".wav", ".mp3")
    # which has nothing to do with what the preview actually is — always take
    # the suffix from the preview URL, or Godot imports a Vorbis file as MP3.
    ext = Path(urllib.parse.urlparse(uri).path).suffix or ".ogg"
    out = out_dir / (f'{sound["id"]}_{Path(safe).stem}{ext}')
    if out.exists():
        return out
    req = urllib.request.Request(uri, headers={"Authorization": f"Token {key}"})
    with urllib.request.urlopen(req, timeout=120) as r:
        out.write_bytes(r.read())
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--only", help="fetch just one group (cat, thread, roof, room, beast)")
    ap.add_argument("--per-query", type=int, default=8)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--dest", type=Path, default=DEST)
    args = ap.parse_args()

    key = api_key()
    manifest: list[dict] = []

    for spec in QUERIES:
        if args.only and spec["group"] != args.only:
            continue
        results = search(key, spec["q"], spec["secs"], args.per_query)
        print(f'\n{spec["group"]}/{spec["q"]}: {len(results)} CC0 hits')
        out_dir = args.dest / spec["group"]
        if not args.dry_run:
            out_dir.mkdir(parents=True, exist_ok=True)

        for s in results:
            # Belt and braces: the API filter should already guarantee this.
            if s["license"] != "http://creativecommons.org/publicdomain/zero/1.0/":
                print(f'   SKIP non-CC0: {s["name"]} ({s["license"]})')
                continue
            print(f'   {s["duration"]:6.2f}s  {s["name"]}  (by {s["username"]})')
            if args.dry_run:
                continue
            path = download(s, out_dir, key)
            manifest.append({
                "group": spec["group"], "query": spec["q"], "id": s["id"],
                "name": s["name"], "user": s["username"], "license": "CC0",
                "duration": s["duration"], "url": s["url"],
                "file": str(path.relative_to(args.dest)) if path else None,
            })

    if manifest:
        # Provenance even for CC0 — so a sound can always be traced back.
        (args.dest / "provenance.json").write_text(
            json.dumps(manifest, indent=1), encoding="utf-8")
        print(f"\n{len(manifest)} files -> {args.dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
