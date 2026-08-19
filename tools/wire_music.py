"""Turn generated music takes into game-ready Ogg Vorbis.

The music counterpart to tools/stage_sfx.py. Same pipeline shape as art and
sound effects:

    assets/incoming/music/    raw takes straight out of the generator  [gitignored]
            |                 tools/wire_music.py   <- you are here
    assets/library/music/     accepted, loop-ready, normalised .ogg    [tracked]
            |                 tools/wire_music.py --wire
    game/assets/music/        wired into the game + imported           [tracked]

What the conversion does, per file:

  1. optional loop crossfade — an AI take ends, it does not loop. The tail is
     crossfaded back over the head so the last sample runs into the first
     (the file gets SHORTER by the crossfade length; that is the price).
  2. two-pass EBU R128 loudness normalisation — beds land near -18 LUFS,
     stings near -14, everything true-peak limited to -3 dBFS. Music sits
     UNDER the sound effects; sfx-shortlist.md normalises those to -3 peak.
  3. encode to 48 kHz stereo Ogg Vorbis. Godot imports .ogg natively and it
     loops without the encoder padding that makes an MP3 loop tick.

    python tools/wire_music.py                 # convert everything incoming
    python tools/wire_music.py --only mus_combat
    python tools/wire_music.py --measure       # report only, write nothing
    python tools/wire_music.py --loop 6        # override the crossfade seconds
    python tools/wire_music.py --wire          # library -> game/assets + import

Needs ffmpeg on PATH (it already is on this machine:
C:\\Users\\yurim\\Packages\\ffmpeg\\bin\\ffmpeg.exe). Nothing else.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
INCOMING = REPO / "assets" / "incoming" / "music"
LIBRARY = REPO / "assets" / "library" / "music"
WIRED = REPO / "game" / "assets" / "music"
GODOT = Path(r"C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe")

SOURCE_EXTS = (".wav", ".mp3", ".flac", ".m4a", ".ogg", ".opus")

# Per-track handling. `loop` is the crossfade length in seconds; 0 means the
# track plays once and stops (stings, and anything the game fades out itself).
# Ids are matched by prefix, so mus_combat_take2.mp3 uses the mus_combat row.
BED = {"lufs": -18.0, "loop": 6.0, "quality": 3}
STING = {"lufs": -14.0, "loop": 0.0, "quality": 4}

TRACKS: dict[str, dict] = {
	"mus_title": BED | {"loop": 4.0},
	"mus_mantel": BED | {"loop": 8.0},
	"mus_prowl": BED,
	"mus_combat": BED | {"loop": 4.0},
	"mus_chase": BED | {"loop": 4.0},
	"mus_stealth": BED | {"loop": 8.0},
	"mus_hollow_court": BED,
	"mus_elspeth": BED | {"loop": 8.0},
	"mus_unpicked": BED | {"loop": 8.0},
	"mus_tallowman": BED | {"loop": 6.0},
	"mus_needlework": BED,
	"mus_testimony": BED,
	"mus_shambles": BED,
	"mus_mereside": BED | {"loop": 8.0},
	"mus_ending": BED | {"loop": 0.0},   # an ending is allowed to end
	"sting_": STING,
}


def ffmpeg() -> str:
	return _tool("ffmpeg")


def ffprobe() -> str:
	return _tool("ffprobe")


def _tool(name: str) -> str:
	exe = shutil.which(name)
	if not exe:
		sys.exit(f"{name} is not on PATH. See docs/design/music-prompts.md.")
	return exe


def run(args: list[str]) -> str:
	proc = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
	if proc.returncode != 0:
		sys.exit(f"ffmpeg failed:\n{' '.join(args)}\n\n{proc.stderr[-2000:]}")
	return proc.stderr + proc.stdout


def settings_for(stem: str) -> dict:
	for prefix, cfg in TRACKS.items():
		if stem.startswith(prefix):
			return cfg
	print(f"  ! {stem}: no entry in TRACKS, treating it as a music bed")
	return BED


def probe(path: Path) -> dict:
	out = run([ffprobe(), "-v", "quiet", "-print_format", "json",
	           "-show_format", "-show_streams", str(path)])
	data = json.loads(out)
	stream = next(s for s in data["streams"] if s["codec_type"] == "audio")
	return {
		"seconds": float(data["format"]["duration"]),
		"rate": int(stream["sample_rate"]),
		"channels": int(stream["channels"]),
		"codec": stream["codec_name"],
	}


def measure_loudness(path: Path) -> dict:
	"""Pass one: what the file actually is, in EBU R128 terms."""
	out = run([ffmpeg(), "-hide_banner", "-i", str(path),
	           "-af", "loudnorm=print_format=json", "-f", "null", "-"])
	blob = re.findall(r"\{[^{}]*\"input_i\"[^{}]*\}", out, re.S)
	if not blob:
		sys.exit(f"could not read loudness from {path.name}")
	return json.loads(blob[-1])


def fold_loop(src: Path, dest: Path, crossfade: float, tmp: Path) -> None:
	"""Fold the tail back over the head so the end runs into the start.

	Output = [crossfade..end] crossfaded with [0..crossfade]. The result now
	BEGINS at the original `crossfade` mark and ENDS on that same material, so
	splicing end to start is inaudible. The file loses `crossfade` seconds.

	Done as three ffmpeg runs rather than one asplit graph on purpose: feeding
	both acrossfade inputs from one asplit stalls the graph and emits nothing
	("No filtered frames for output stream"). Two real files always work.
	"""
	body, head = tmp / "body.wav", tmp / "head.wav"
	run([ffmpeg(), "-hide_banner", "-y", "-ss", str(crossfade), "-i", str(src),
	     "-ar", "48000", "-ac", "2", str(body)])
	run([ffmpeg(), "-hide_banner", "-y", "-t", str(crossfade), "-i", str(src),
	     "-ar", "48000", "-ac", "2", str(head)])
	run([ffmpeg(), "-hide_banner", "-y", "-i", str(body), "-i", str(head),
	     "-filter_complex", f"[0][1]acrossfade=d={crossfade}:c1=tri:c2=tri",
	     "-ar", "48000", "-ac", "2", str(dest)])


def convert(src: Path, dest: Path, cfg: dict, loop_override: float | None) -> dict:
	crossfade = cfg["loop"] if loop_override is None else loop_override
	before = probe(src)
	if crossfade >= before["seconds"] / 2:
		print(f"  ! {src.name}: {crossfade}s crossfade on a {before['seconds']:.0f}s take "
		      f"is too much; skipping the loop fold")
		crossfade = 0.0

	with tempfile.TemporaryDirectory() as tmp:
		staged = Path(tmp) / "staged.wav"
		if crossfade > 0:
			fold_loop(src, staged, crossfade, Path(tmp))
		else:
			run([ffmpeg(), "-hide_banner", "-y", "-i", str(src),
			     "-ar", "48000", "-ac", "2", str(staged)])

		m = measure_loudness(staged)
		if float(m["input_i"]) < -70.0:
			sys.exit(f"{src.name} measures as silence after staging - check the take")
		# Pass two: linear normalisation using the measured values, so the
		# dynamics survive instead of being pumped by the single-pass limiter.
		norm = (f"loudnorm=I={cfg['lufs']}:TP=-3.0:LRA=11:"
		        f"measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
		        f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:"
		        f"offset={m['target_offset']}:linear=true:print_format=summary")
		dest.parent.mkdir(parents=True, exist_ok=True)
		run([ffmpeg(), "-hide_banner", "-y", "-i", str(staged), "-af", norm,
		     "-c:a", "libvorbis", "-q:a", str(cfg["quality"]),
		     "-ar", "48000", "-ac", "2", str(dest)])

	after = probe(dest)
	return {
		"name": src.name,
		"out": dest.name,
		"seconds_in": before["seconds"],
		"seconds_out": after["seconds"],
		"crossfade": crossfade,
		"lufs_in": float(m["input_i"]),
		"lufs_target": cfg["lufs"],
		"kb": dest.stat().st_size / 1024,
	}


def main() -> int:
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("--only", help="one track id (or prefix) instead of everything")
	ap.add_argument("--loop", type=float, default=None,
	                help="override the loop crossfade seconds for this run (0 disables)")
	ap.add_argument("--measure", action="store_true", help="report the incoming takes, write nothing")
	ap.add_argument("--wire", action="store_true",
	                help="copy assets/library/music -> game/assets/music and run the Godot import")
	args = ap.parse_args()

	if args.wire:
		return wire()

	if not INCOMING.exists():
		INCOMING.mkdir(parents=True, exist_ok=True)
		print(f"created {INCOMING.relative_to(REPO)} - drop the generated takes there")
		return 0

	takes = sorted(p for p in INCOMING.iterdir()
	               if p.suffix.lower() in SOURCE_EXTS
	               and (not args.only or p.stem.startswith(args.only)))
	if not takes:
		print(f"nothing to do: no audio in {INCOMING.relative_to(REPO)}")
		return 0

	if args.measure:
		print(f"{'file':<34}{'sec':>7}{'rate':>8}{'ch':>4}{'LUFS':>8}{'peak dBTP':>11}")
		for t in takes:
			info, m = probe(t), measure_loudness(t)
			print(f"{t.name:<34}{info['seconds']:>7.1f}{info['rate']:>8}{info['channels']:>4}"
			      f"{float(m['input_i']):>8.1f}{float(m['input_tp']):>11.1f}")
		return 0

	rows = []
	for t in takes:
		cfg = settings_for(t.stem)
		print(f"  {t.name} -> {t.stem}.ogg")
		rows.append(convert(t, LIBRARY / f"{t.stem}.ogg", cfg, args.loop))

	print(f"\n{'track':<26}{'in s':>7}{'out s':>7}{'xfade':>7}{'LUFS in':>9}{'-> target':>11}{'KB':>8}")
	for r in rows:
		print(f"{r['out']:<26}{r['seconds_in']:>7.1f}{r['seconds_out']:>7.1f}{r['crossfade']:>7.1f}"
		      f"{r['lufs_in']:>9.1f}{r['lufs_target']:>11.1f}{r['kb']:>8.0f}")
	print(f"\n{len(rows)} file(s) in {LIBRARY.relative_to(REPO)}. "
	      f"Listen to each one LOOPED before wiring - a crossfade can smear a beat. "
	      f"Then: python tools/wire_music.py --wire")
	return 0


def wire() -> int:
	if not LIBRARY.exists():
		sys.exit(f"{LIBRARY.relative_to(REPO)} does not exist yet - convert first")
	WIRED.mkdir(parents=True, exist_ok=True)
	copied = 0
	for src in sorted(LIBRARY.glob("*.ogg")):
		shutil.copy2(src, WIRED / src.name)
		copied += 1
		print(f"  {src.name}")
	if not copied:
		print("no .ogg in the library yet")
		return 0
	# Law 23: the game binary never imports; a new asset is invisible until this runs.
	if GODOT.exists():
		subprocess.run([str(GODOT), "--headless", "--path", str(REPO / "game"), "--import"],
		               capture_output=True, text=True)
		print(f"\n{copied} file(s) wired and imported.")
	else:
		print(f"\n{copied} file(s) copied. Godot not found at {GODOT} — "
		      f"run `godot --headless --path game --import` yourself (law 23).")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
