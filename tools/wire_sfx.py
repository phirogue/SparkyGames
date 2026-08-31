"""Accept sound effects into the library, and wire the library into the game.

    ~\\assets\\<library>\\      three source libraries, outside the repo
            |                  tools/stage_sfx.py
    assets/incoming/sfx/       287 candidates, auditioned  [gitignored]
            |                  tools/wire_sfx.py --accept
    assets/library/sfx/        the ones the game uses      [tracked]
            |                  tools/wire_sfx.py --wire    (peak normalise)
    game/assets/sfx/           what the game loads         [tracked]

**game/data/sfx.json decides what gets wired.** This tool does not carry its
own list: it reads every `files` entry out of the cue map and pulls exactly
those. Add a variant to a cue and re-run; delete a cue and the orphan is
reported. That way the data and the assets cannot drift apart, and a cue
naming a file nobody staged fails here rather than as a silent tap in a fight.

WHY PEAK NORMALISE AND NOT `loudnorm`
    wire_music.py uses `loudnorm` because a two-minute bed has plenty for the
    EBU R128 window to chew on. Most cues here are under half a second, which
    is far below what loudnorm needs to measure -- run it on a 0.03s tap and it
    invents a gain from noise. So each file is peak-normalised to a common
    ceiling instead, which is exactly the right tool for one-shots: nothing
    clips, nothing hides, and the artistic balance is `gain_db` per cue in
    sfx.json rather than baked into the sample.

    python tools/wire_sfx.py              # accept + wire
    python tools/wire_sfx.py --wire       # re-normalise from the library only
    python tools/wire_sfx.py --check      # report drift, change nothing
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
INCOMING = REPO / "assets" / "incoming" / "sfx"
LIBRARY = REPO / "assets" / "library" / "sfx"
WIRED = REPO / "game" / "assets" / "sfx"
CUES = REPO / "game" / "data" / "sfx.json"
MANIFEST = LIBRARY / "MANIFEST.md"
STAGED_MANIFEST = INCOMING / "manifest.json"

## Every wired file is brought to this peak. -3 dBFS leaves headroom for two
## cues landing on the same frame (a claw and a hurt flash routinely do)
## without the SFX bus clipping into the score.
PEAK_DBFS = -3.0


def _tool(name: str) -> str:
    packaged = Path.home() / "Packages" / "ffmpeg" / "bin" / f"{name}.exe"
    return str(packaged) if packaged.exists() else name


def run(args: list[str]) -> str:
    done = subprocess.run(args, capture_output=True, text=True)
    return done.stdout + done.stderr


def wanted_files() -> list[str]:
    """Every file id named by any cue in sfx.json, deduplicated, in order."""
    data = json.loads(CUES.read_text(encoding="utf-8"))
    seen: dict[str, None] = {}
    for key, cue in data.get("cues", {}).items():
        if key.startswith("_") or not isinstance(cue, dict):
            continue          # "_battle": "..." section comments
        for f in cue.get("files", []):
            seen[str(f)] = None
    return list(seen)


def peak_db(path: Path) -> float | None:
    out = run([_tool("ffmpeg"), "-hide_banner", "-nostats", "-i", str(path),
               "-af", "volumedetect", "-f", "null", "-"])
    m = re.search(r"max_volume:\s*(-?[\d.]+) dB", out)
    return float(m.group(1)) if m else None


def full_scale_samples(path: Path) -> int:
    """How many samples sit at 0 dBFS.

    Peak alone does not catch the defect that matters. A file can measure a
    healthy mean and still have a handful of samples pinned at full scale —
    Vorbis ringing around a transient that was clipped at source — and those
    few samples are an audible click. Attenuation does not remove them, so the
    variant has to be dropped instead.
    """
    out = run([_tool("ffmpeg"), "-hide_banner", "-nostats", "-i", str(path),
               "-af", "volumedetect", "-f", "null", "-"])
    m = re.search(r"histogram_0db:\s*(\d+)", out)
    return int(m.group(1)) if m else 0


def duration(path: Path) -> float:
    out = run([_tool("ffprobe"), "-v", "error", "-show_entries",
               "format=duration", "-of", "default=nw=1:nk=1", str(path)])
    try:
        return round(float(out.strip().splitlines()[0]), 3)
    except (ValueError, IndexError):
        return 0.0


def accept(ids: list[str]) -> tuple[int, list[str]]:
    """incoming -> library, verbatim. The library copy is the master."""
    copied, missing = 0, []
    for fid in ids:
        src = INCOMING / f"{fid}.ogg"
        if not src.exists():
            missing.append(fid)
            continue
        dst = LIBRARY / f"{fid}.ogg"
        dst.parent.mkdir(parents=True, exist_ok=True)
        if not dst.exists() or dst.stat().st_size != src.stat().st_size:
            shutil.copy2(src, dst)
            copied += 1
    return copied, missing


def wire(ids: list[str]) -> list[dict]:
    """library -> game, peak-normalised. Returns manifest rows."""
    rows = []
    for fid in ids:
        src = LIBRARY / f"{fid}.ogg"
        if not src.exists():
            continue
        dst = WIRED / f"{fid}.ogg"
        dst.parent.mkdir(parents=True, exist_ok=True)

        before = peak_db(src)
        gain = 0.0 if before is None else PEAK_DBFS - before

        # Vorbis is not peak-preserving: the decoded result routinely lands a
        # decibel or two above where the pre-encode arithmetic put it, and on
        # a file that was already clipped at source it came back at 0.0 dBFS —
        # i.e. still clipping, which is the one outcome normalising is for.
        # So encode, MEASURE THE RESULT, and correct once against what the
        # encoder actually did. Converges in a single pass because the
        # overshoot is deterministic for a given file.
        after = None
        for _ in range(3):
            # -q:a 6 keeps a one-shot transparent; these are already lossy
            # sources and a second pass at low quality is where a tap starts
            # to sound like a click of static.
            subprocess.run(
                [_tool("ffmpeg"), "-y", "-hide_banner", "-loglevel", "error",
                 "-i", str(src), "-af", f"volume={gain:.2f}dB",
                 "-ar", "48000", "-c:a", "libvorbis", "-q:a", "6", str(dst)],
                check=True)
            after = peak_db(dst)
            if after is None or abs(after - PEAK_DBFS) <= 0.3:
                break
            gain += PEAK_DBFS - after

        rows.append({
            "id": fid,
            "sec": duration(dst),
            "peak_before": before,
            "peak_after": after,
            "clipped": full_scale_samples(dst),
            "gain_db": round(gain, 2),
        })
    return rows


def orphans(ids: list[str]) -> list[str]:
    """Files in the library or wired folder that no cue asks for any more."""
    want = {f"{i}.ogg" for i in ids}
    out = []
    for root in (LIBRARY, WIRED):
        if not root.exists():
            continue
        for f in root.rglob("*.ogg"):
            rel = f.relative_to(root).as_posix()
            if rel not in want:
                out.append(f"{root.name}/{rel}")
    return sorted(out)


def provenance() -> dict[str, dict]:
    """What stage_sfx.py recorded about each candidate, if it is still there."""
    if not STAGED_MANIFEST.exists():
        return {}
    rows = json.loads(STAGED_MANIFEST.read_text(encoding="utf-8"))
    return {r["file"].removesuffix(".ogg"): r for r in rows}


def write_manifest(rows: list[dict]) -> None:
    prov = provenance()
    lines = [
        "# SFX library — MANIFEST",
        "",
        "Generated by `python tools/wire_sfx.py`. **Do not hand-edit.**",
        "",
        "These are the sounds the game uses. `game/data/sfx.json` decides which",
        "files are here: this table is regenerated from it, so a cue and its",
        "assets cannot drift apart.",
        "",
        f"{len(rows)} files, peak-normalised to {PEAK_DBFS:+.1f} dBFS on the way",
        "into `game/assets/sfx/`. Per-cue balance is `gain_db` in sfx.json, not",
        "baked into these files.",
        "",
        "Licensing: Kenney CC0, Freesound CC0, Sonniss GDC royalty-free — all",
        "commercial-use, no attribution required. The Sonniss EULA forbids using",
        "its files to train audio models; see `docs/design/sfx-shortlist.md`.",
        "",
        "| id | sec | source | original |",
        "|---|---|---|---|",
    ]
    for r in sorted(rows, key=lambda x: x["id"]):
        p = prov.get(r["id"], {})
        lib = p.get("library", "?")
        orig = Path(p.get("source_file", "?")).name
        lines.append(f'| `{r["id"]}` | {r["sec"]:.2f} | {lib} | {orig} |')
    lines.append("")
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--accept", action="store_true", help="incoming -> library only")
    ap.add_argument("--wire", action="store_true", help="library -> game only")
    ap.add_argument("--check", action="store_true", help="report drift, change nothing")
    args = ap.parse_args()

    ids = wanted_files()
    print(f"{len(ids)} files named by game/data/sfx.json")

    if args.check:
        miss_lib = [i for i in ids if not (LIBRARY / f"{i}.ogg").exists()]
        miss_game = [i for i in ids if not (WIRED / f"{i}.ogg").exists()]
        extra = orphans(ids)
        for label, items in (("not in library", miss_lib),
                             ("not wired", miss_game),
                             ("orphaned", extra)):
            print(f"  {label}: {len(items)}")
            for i in items[:12]:
                print(f"     {i}")
        return 1 if (miss_lib or miss_game or extra) else 0

    do_accept = args.accept or not args.wire
    do_wire = args.wire or not args.accept

    if do_accept:
        copied, missing = accept(ids)
        print(f"accepted {copied} new into {LIBRARY}")
        if missing:
            print(f"!! {len(missing)} named by sfx.json but not staged:")
            for m in missing:
                print("   ", m)
            return 1

    rows: list[dict] = []
    if do_wire:
        rows = wire(ids)
        print(f"wired {len(rows)} into {WIRED}")
        write_manifest(rows)
        loud = [r for r in rows if r["peak_after"] is not None
                and r["peak_after"] > PEAK_DBFS + 0.5]
        if loud:
            print(f"!! {len(loud)} did not reach the target peak:")
            for r in loud[:8]:
                print(f'   {r["id"]}  {r["peak_after"]:+.1f} dB')
        # The one that matters: attenuation cannot remove these, so the fix is
        # always to drop the variant from sfx.json (there are others).
        clipped = [r for r in rows if r["clipped"] > 0]
        if clipped:
            print(f"!! {len(clipped)} still have samples at 0 dBFS — audible "
                  f"clicks. Drop them from sfx.json:")
            for r in clipped:
                print(f'   {r["id"]}  {r["clipped"]} full-scale samples')

    extra = orphans(ids)
    if extra:
        print(f"\n{len(extra)} orphaned file(s) no cue asks for — delete by hand:")
        for e in extra[:20]:
            print("   ", e)

    print("\nNow run:  godot --headless --path game --import      (law 23)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
