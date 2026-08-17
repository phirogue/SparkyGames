"""Pull selected libraries out of the Sonniss #GameAudioGDC 2026 bundle.

The bundle is 5 zips totalling 7.5 GB and we want about 900 MB of it. Rather
than download the lot, this reads each archive's central directory over an HTTP
range request, then range-fetches only the members of the chosen libraries and
inflates them locally. Transfer is proportional to what we keep.

Downloads to C:\\Users\\yurim\\assets\\sonniss-gdc2026 — outside the repo, like
the other libraries (see docs/design/sfx-shortlist.md).

LICENCE (bundled as 'License - GDC Game Audio.pdf'): royalty-free, unlimited
projects for life, commercial use, no attribution, modification allowed. May
not be resold as-is or passed off as your own recording.

**NO AI TRAINING OR USAGE.** The EULA forbids using these sounds "for the
purpose of developing, training, or enhancing artificial intelligence
technologies". Shipping them in the game is fine. Feeding one to an audio
model as a reference or audio-to-audio input is NOT — do not do to these what
tools/genart.py --ref does to images.

    python tools/fetch_sonniss.py            # fetch the LIBRARIES list
    python tools/fetch_sonniss.py --list     # print every library in the bundle
"""
from __future__ import annotations

import argparse
import struct
import subprocess
import sys
import urllib.request
import zlib
from pathlib import Path

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0 Safari/537.36")
BASE = "https://downloads.sonniss.com/Sonniss.com-GDC2026-GameAudioBundle{}of5.zip"
DEST = Path.home() / "assets" / "sonniss-gdc2026"

# Chosen against the game's real gaps: the book UI, the Court's bureaucracy,
# thread and cloth foley, animals, rooftop weather, the music-box palette.
LIBRARIES = [
    "344 Audio - Antique Books",
    "344 Audio - Antique Clocks",
    "344 Audio - Antique Typewriter",
    "344 Audio - Antique Small Metals",
    "344 Audio - Antique Luggage",
    "344 Audio - Dog Vocalisations Vol. 1",
    "344 Audio - Casino Cards Vol. 1",
    "344 Audio - Ghostly Presences Vol. 1",
    "Sonic Bat - Music Boxes",
    "Sonic Bat - Stormy Night Ambience",
    "SoundBits - Vox Bestiae - Source Elements",
    "CB_Sounddesign - Applicable Sounds - Organic UI and Building Games SFX",
    "Cinematic Sound Design - Paper Foley",
    "Cinematic Sound Design - UI Interaction Elements",
    "Cinematic Sound Design - User Interface",
    "Cinematic Sound Design - System & UI Feedback Elements",
    "Cinematic Sound Design - Interface & Infographics",
    "Cinematic Sound Design - Hybrid Game & UI Elements",
    "Epic Stock Media - Board Game - Sound Set Kit for Tabletop and Digital Games",
    "Epic Stock Media - Fantasy Game 2 - Sound Kit for Enchanted Realms",
    "Epic Stock Media - Strange Game Ambient Loops 3",
    "InMotionAudio - Foley T-Shirt",
    "InMotionAudio - Washing Basket Foley",
    "InMotionAudio - Velcro",
    "InMotionAudio - Instrument Case",
    "InMotionAudio - Sinister Textures 4",
    "InMotionAudio - Sinister Textures 5",
    "InMotionAudio - Chimney Wind",
    "Ivo Vicic - Campfire - Bonfire FX",
    "Ivo Vicic - Church Bells",
    "Jake Fielding - Interior Wind Rain and Storms",
    "License - GDC Game Audio.pdf",
    "Readme.txt",
    "Game Audio GDC Bundle 2026 (Part 9) Filelist.xlsx",
]

TMP = DEST / "_range.tmp"


def curl_range(url: str, start: int, end: int) -> bytes:
    """urllib hangs for minutes when the CDN stalls a long transfer; curl can
    abort a stalled socket and retry, so the big ambience files get through."""
    want = end - start + 1
    TMP.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(6):
        subprocess.run([
            "curl.exe", "-sS", "-A", UA, "-r", f"{start}-{end}",
            "--speed-limit", "20000", "--speed-time", "30",
            "--retry", "3", "--retry-delay", "2", "--max-time", "900",
            "-o", str(TMP), url,
        ], capture_output=True, text=True)
        if TMP.exists() and TMP.stat().st_size == want:
            data = TMP.read_bytes()
            TMP.unlink()
            return data
        print(f"    retry {attempt + 1} (bytes {start}-{end})")
    raise RuntimeError(f"range {start}-{end} of {url} failed")


def size_of(url: str) -> int:
    for _ in range(5):
        req = urllib.request.Request(
            url, headers={"User-Agent": UA, "Range": "bytes=0-0"})
        with urllib.request.urlopen(req, timeout=60) as r:
            cr = r.headers.get("Content-Range")     # bytes 0-0/TOTAL
            if cr:
                return int(cr.split("/")[1])
    raise RuntimeError(f"could not size {url}")


def central_directory(url: str) -> list[dict]:
    """Read just the archive's index — a few hundred KB, not a gigabyte."""
    total = size_of(url)
    tail = curl_range(url, max(0, total - 65536), total - 1)
    i = tail.rfind(b"PK\x05\x06")
    if i < 0:
        raise RuntimeError(f"no end-of-central-directory in {url}")
    count, cd_size, cd_off = struct.unpack("<HII", tail[i + 10:i + 20])
    if 0xFFFFFFFF in (cd_off, cd_size) or count == 0xFFFF:
        j = tail.rfind(b"PK\x06\x06")
        count, cd_size, cd_off = struct.unpack("<QQQ", tail[j + 32:j + 56])

    cd = curl_range(url, cd_off, cd_off + cd_size - 1)
    entries, p = [], 0
    while p + 46 <= len(cd) and cd[p:p + 4] == b"PK\x01\x02":
        method, = struct.unpack("<H", cd[p + 10:p + 12])
        csize, usize = struct.unpack("<II", cd[p + 20:p + 28])
        n_len, x_len, c_len = struct.unpack("<HHH", cd[p + 28:p + 34])
        lho, = struct.unpack("<I", cd[p + 42:p + 46])
        name = cd[p + 46:p + 46 + n_len].decode("utf-8", "replace")
        extra = cd[p + 46 + n_len:p + 46 + n_len + x_len]

        if 0xFFFFFFFF in (csize, usize, lho):        # ZIP64 override
            q = 0
            while q + 4 <= len(extra):
                hid, hsz = struct.unpack("<HH", extra[q:q + 4])
                if hid == 0x0001:
                    vals, r = [], q + 4
                    for cur in (usize, csize, lho):
                        if cur == 0xFFFFFFFF and r + 8 <= q + 4 + hsz:
                            vals.append(struct.unpack("<Q", extra[r:r + 8])[0])
                            r += 8
                        else:
                            vals.append(cur)
                    usize, csize, lho = vals
                    break
                q += 4 + hsz

        entries.append({"name": name, "method": method, "csize": csize,
                        "usize": usize, "lho": lho})
        p += 46 + n_len + x_len + c_len
    return entries


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--list", action="store_true",
                    help="print every library in the bundle and exit")
    ap.add_argument("--dest", type=Path, default=DEST)
    args = ap.parse_args()

    index = {BASE.format(n): central_directory(BASE.format(n))
             for n in range(1, 6)}

    if args.list:
        libs: dict[str, list[int]] = {}
        for entries in index.values():
            for e in entries:
                lib = e["name"].split("/")[0]
                got = libs.setdefault(lib, [0, 0])
                got[0] += 1
                got[1] += e["csize"]
        for lib, (n, b) in sorted(libs.items()):
            print(f"{n:3d} files  {b / 1e6:8.1f} MB  {lib}")
        return 0

    wanted, seen_loose = set(LIBRARIES), set()
    jobs = []
    for url, entries in index.items():
        for e in entries:
            if e["name"].endswith("/"):
                continue
            top = e["name"].split("/")[0]
            if top not in wanted:
                continue
            if "/" not in e["name"]:      # licence/readme repeat in all 5 zips
                if top in seen_loose:
                    continue
                seen_loose.add(top)
            jobs.append((url, e))

    total = sum(e["csize"] for _, e in jobs)
    print(f"{len(jobs)} files, {total / 1e6:.0f} MB to transfer\n")

    done = 0
    for url, e in sorted(jobs, key=lambda j: j[1]["csize"]):
        out = args.dest / e["name"]
        if out.exists() and out.stat().st_size == e["usize"]:
            done += e["csize"]
            continue
        out.parent.mkdir(parents=True, exist_ok=True)

        head = curl_range(url, e["lho"], e["lho"] + 29)
        if head[:4] != b"PK\x03\x04":
            raise RuntimeError(f"bad local header for {e['name']}")
        n_len, x_len = struct.unpack("<HH", head[26:30])
        start = e["lho"] + 30 + n_len + x_len

        blob = curl_range(url, start, start + e["csize"] - 1) if e["csize"] else b""
        if e["csize"] and e["method"] == 8:
            blob = zlib.decompress(blob, -zlib.MAX_WBITS)
        elif e["csize"] and e["method"] != 0:
            raise RuntimeError(f"unsupported compression {e['method']}")
        if len(blob) != e["usize"]:
            raise RuntimeError(f"size mismatch for {e['name']}")
        out.write_bytes(blob)

        done += e["csize"]
        print(f"[{done / total * 100:5.1f}%] {e['usize'] / 1e6:8.1f} MB  {e['name']}")
        sys.stdout.flush()

    print(f"\nwrote to {args.dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
