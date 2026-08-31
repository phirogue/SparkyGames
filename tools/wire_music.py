"""Turn generated music takes into game-ready, loopable Ogg Vorbis.

The music counterpart to tools/stage_sfx.py. Same pipeline shape as art and
sound effects:

    assets/incoming/music/    raw takes straight out of the generator  [gitignored]
            |                 tools/wire_music.py   <- you are here
    assets/library/music/     accepted, loop-ready, normalised .ogg    [gitignored]
            |                 tools/wire_music.py --wire                (MANIFEST tracked)
    game/assets/music/        wired into the game + imported           [tracked]

The library copy is where you audition; the wired copy is what ships, and the
two are byte-identical, so only the wired one is committed (see .gitignore).

Per take, in order:

  1. TRIM. A generated take opens with dead air and closes with a fade-out and
     more dead air - up to 2.5s of it in the delivered batch. Folded into a
     loop unexamined, that silence lands exactly on the seam, which is the one
     place a player is guaranteed to hear it. The RMS envelope finds where the
     music actually starts, and where the ending fade begins.
  2. FOLD. The tail is crossfaded back over the head, so the file begins and
     ends on the same musical material and end-to-start is inaudible. The file
     gets shorter by the crossfade length; that is the whole cost. Tracks with
     `loop: 0` (the ending theme) skip this - they are allowed to end.
  3. LEVEL. Two-pass EBU R128: beds to -18 LUFS, stings to -14, true peak
     capped at -3 dBTP. Music sits UNDER the effects, which sfx-shortlist.md
     normalises to -3 dBFS peak.
  4. ENCODE. 48 kHz stereo Ogg Vorbis. Godot imports .ogg natively, and it
     loops without the encoder padding that puts a tick in every MP3 loop.
  5. CHECK. Level either side of the seam is measured and reported. That
     catches a fold that landed in silence. It CANNOT hear a fold that landed
     mid-phrase - only ears do that, which is why the report says so.

    python tools/wire_music.py                 # convert everything incoming
    python tools/wire_music.py --only mus_combat
    python tools/wire_music.py --measure       # report the raw takes, write nothing
    python tools/wire_music.py --loop 8        # override the crossfade seconds
    python tools/wire_music.py --no-trim       # keep the take's own head and tail
    python tools/wire_music.py --wire          # library -> game/assets + import

Takes may carry the generator's take number: mus_combat-2.mp3 and
mus_combat_take2.wav both become mus_combat.ogg.

Needs ffmpeg on PATH and numpy. Both are already installed here.
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

import numpy as np

REPO = Path(__file__).resolve().parent.parent
INCOMING = REPO / "assets" / "incoming" / "music"
LIBRARY = REPO / "assets" / "library" / "music"
WIRED = REPO / "game" / "assets" / "music"
MANIFEST = LIBRARY / "MANIFEST.md"
sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import godot_binary  # noqa: E402  (tools/paths.py owns binary paths)

GODOT = godot_binary()

SOURCE_EXTS = (".wav", ".mp3", ".flac", ".m4a", ".ogg", ".opus")

# Analysis constants. The envelope is coarse on purpose: we are looking for
# where music starts and stops, not for transients.
HOP = 0.02              # seconds per envelope frame
SILENCE_BELOW = 34.0    # dB under the track's loud level = "not playing"
FADE_BELOW = 9.0        # dB under the loud level = "this is the ending fade"
FADE_MIN = 1.2          # a quiet patch shorter than this is music, not a fade
MAX_TRIM_FRACTION = 0.25   # never eat more than a quarter of a take

# Per-track handling. `loop` is the crossfade length in seconds; 0 means the
# track plays once and stops. Ids are matched by prefix.
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

TAKE_SUFFIX = re.compile(r"(?:[-_ ]?(?:take)?[-_ ]?\d+)$", re.I)


def track_id(stem: str) -> str:
	"""mus_combat-2 / mus_combat_take2 / mus_combat 3 -> mus_combat."""
	return TAKE_SUFFIX.sub("", stem).strip(" -_")


def _tool(name: str) -> str:
	exe = shutil.which(name)
	if not exe:
		sys.exit(f"{name} is not on PATH. See docs/design/music-prompts.md.")
	return exe


def ffmpeg() -> str: return _tool("ffmpeg")
def ffprobe() -> str: return _tool("ffprobe")


def run(args: list[str]) -> str:
	proc = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
	if proc.returncode != 0:
		sys.exit(f"ffmpeg failed:\n{' '.join(args)}\n\n{proc.stderr[-2000:]}")
	return proc.stderr + proc.stdout


def settings_for(name: str) -> dict:
	for prefix, cfg in TRACKS.items():
		if name.startswith(prefix):
			return cfg
	print(f"  ! {name}: no entry in TRACKS, treating it as a music bed")
	return BED


def probe(path: Path) -> dict:
	data = json.loads(run([ffprobe(), "-v", "quiet", "-print_format", "json",
	                       "-show_format", "-show_streams", str(path)]))
	stream = next(s for s in data["streams"] if s["codec_type"] == "audio")
	return {
		"seconds": float(data["format"]["duration"]),
		"rate": int(stream["sample_rate"]),
		"channels": int(stream["channels"]),
		"codec": stream["codec_name"],
	}


def measure_loudness(path: Path) -> dict:
	out = run([ffmpeg(), "-hide_banner", "-i", str(path),
	           "-af", "loudnorm=print_format=json", "-f", "null", "-"])
	blob = re.findall(r"\{[^{}]*\"input_i\"[^{}]*\}", out, re.S)
	if not blob:
		sys.exit(f"could not read loudness from {path.name}")
	return json.loads(blob[-1])


def envelope(path: Path) -> np.ndarray:
	"""RMS per HOP seconds, in dB relative to the track's own loud level.

	Mono 8 kHz is plenty: this measures whether music is playing, not what it
	sounds like. Returns dB where 0 = the track's 90th-percentile level, so the
	thresholds below are relative to the material rather than to full scale (a
	quiet ambient bed and a busy combat cue then want the same treatment).
	"""
	raw = subprocess.run([ffmpeg(), "-v", "quiet", "-i", str(path),
	                      "-ac", "1", "-ar", "8000", "-f", "s16le", "-"],
	                     capture_output=True)
	samples = np.frombuffer(raw.stdout, dtype=np.int16).astype(np.float32) / 32768.0
	frame = int(8000 * HOP)
	usable = (samples.size // frame) * frame
	if usable == 0:
		return np.array([-120.0])
	rms = np.sqrt((samples[:usable].reshape(-1, frame) ** 2).mean(axis=1))
	loud = float(np.percentile(rms, 90)) or 1e-9
	return 20.0 * np.log10(np.maximum(rms, 1e-9) / loud)


def find_edges(env: np.ndarray, seconds: float,
               cut_fade: bool = True) -> tuple[float, float, str]:
	"""Where the music really starts and stops.

	Returns (start, end, note). `end` backs off an ending fade-out as well as
	flat silence: a fade crossfaded into the loop head makes the seam dip, and
	a dip once a minute reads as a fault in the game rather than a choice.

	`cut_fade` is False for a track that does not loop (mus_ending). There the
	fade IS the ending, and cutting it would leave the last chord chopped.
	"""
	playing = np.flatnonzero(env > -SILENCE_BELOW)
	if playing.size == 0:
		return 0.0, seconds, "silent?"
	start = max(0.0, playing[0] * HOP - 0.05)
	end = min(seconds, (playing[-1] + 1) * HOP + 0.05)
	note = ""

	full = np.flatnonzero(env > -FADE_BELOW)
	if cut_fade and full.size:
		fade_starts = (full[-1] + 1) * HOP
		if end - fade_starts >= FADE_MIN:
			end = min(end, fade_starts + 0.30)   # keep a breath of the decay
			note = "fade cut"

	floor = seconds * (1.0 - MAX_TRIM_FRACTION)
	if end - start < floor:                      # refuse to gut the take
		end = min(seconds, start + floor)
		note = (note + " capped").strip()
	return start, end, note


def trim(src: Path, dest: Path, start: float, end: float) -> None:
	run([ffmpeg(), "-hide_banner", "-y", "-ss", f"{start:.3f}", "-to", f"{end:.3f}",
	     "-i", str(src), "-ar", "48000", "-ac", "2", str(dest)])


def fold_loop(src: Path, dest: Path, crossfade: float, tmp: Path) -> None:
	"""Fold the tail back over the head so the end runs into the start.

	Output = [crossfade..end] crossfaded with [0..crossfade]. The result now
	BEGINS at the original `crossfade` mark and ENDS on that same material, so
	splicing end to start is inaudible.

	Three ffmpeg runs rather than one asplit graph on purpose: feeding both
	acrossfade inputs from a single asplit stalls the filter graph and writes an
	empty file ("No filtered frames for output stream") with a zero exit code.
	"""
	body, head = tmp / "body.wav", tmp / "head.wav"
	run([ffmpeg(), "-hide_banner", "-y", "-ss", str(crossfade), "-i", str(src),
	     "-ar", "48000", "-ac", "2", str(body)])
	run([ffmpeg(), "-hide_banner", "-y", "-t", str(crossfade), "-i", str(src),
	     "-ar", "48000", "-ac", "2", str(head)])
	run([ffmpeg(), "-hide_banner", "-y", "-i", str(body), "-i", str(head),
	     "-filter_complex", f"[0][1]acrossfade=d={crossfade}:c1=tri:c2=tri",
	     "-ar", "48000", "-ac", "2", str(dest)])


def seam_check(path: Path) -> dict:
	"""Level either side of the loop point, in dB relative to the track.

	A big gap between them, or either side sitting in silence, means the fold
	landed somewhere it should not have. Continuity of LEVEL is all this can
	see; whether the fold lands on a bar line is a question for ears.
	"""
	env = envelope(path)
	window = max(1, int(0.25 / HOP))
	head = float(env[:window].mean())
	tail = float(env[-window:].mean())
	return {"head_db": head, "tail_db": tail, "gap_db": abs(head - tail),
	        "quiet": head < -SILENCE_BELOW or tail < -SILENCE_BELOW}


def convert(src: Path, dest: Path, cfg: dict, loop_override: float | None,
            do_trim: bool) -> dict:
	before = probe(src)
	loops = (cfg["loop"] if loop_override is None else loop_override) > 0
	start, end, note = (find_edges(envelope(src), before["seconds"], loops) if do_trim
	                    else (0.0, before["seconds"], "no trim"))

	with tempfile.TemporaryDirectory() as tmp:
		tmp_dir = Path(tmp)
		trimmed = tmp_dir / "trimmed.wav"
		trim(src, trimmed, start, end)
		trimmed_seconds = probe(trimmed)["seconds"]

		crossfade = cfg["loop"] if loop_override is None else loop_override
		if crossfade > 0 and crossfade > trimmed_seconds * MAX_TRIM_FRACTION:
			crossfade = round(trimmed_seconds * MAX_TRIM_FRACTION, 1)
			note = (note + " short fold").strip()

		staged = tmp_dir / "staged.wav"
		if crossfade > 0:
			fold_loop(trimmed, staged, crossfade, tmp_dir)
		else:
			staged = trimmed

		m = measure_loudness(staged)
		if float(m["input_i"]) < -70.0:
			sys.exit(f"{src.name} measures as silence after staging - check the take")
		# Pass two: linear normalisation from the measured values, so the
		# dynamics survive instead of being pumped by a single-pass limiter.
		norm = (f"loudnorm=I={cfg['lufs']}:TP=-3.0:LRA=11:"
		        f"measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
		        f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:"
		        f"offset={m['target_offset']}:linear=true:print_format=summary")
		dest.parent.mkdir(parents=True, exist_ok=True)
		run([ffmpeg(), "-hide_banner", "-y", "-i", str(staged), "-af", norm,
		     "-c:a", "libvorbis", "-q:a", str(cfg["quality"]),
		     "-ar", "48000", "-ac", "2", str(dest)])

	after = probe(dest)
	out = measure_loudness(dest)
	seam = seam_check(dest) if crossfade > 0 else {"gap_db": 0.0, "quiet": False}
	return {
		"source": src.name,
		"out": dest.name,
		"seconds_in": before["seconds"],
		"seconds_out": after["seconds"],
		"trimmed_head": start,
		"trimmed_tail": before["seconds"] - end,
		"crossfade": crossfade,
		"lufs_in": float(m["input_i"]),
		"lufs_out": float(out["input_i"]),
		"peak_out": float(out["input_tp"]),
		"seam_gap": seam["gap_db"],
		"seam_quiet": seam["quiet"],
		"note": note,
		"kb": dest.stat().st_size / 1024,
	}


def write_manifest(rows: list[dict]) -> None:
	lines = [
		"# Music library - MANIFEST",
		"",
		"**GENERATED** by `python tools/wire_music.py`. Do not hand-edit;",
		"re-run the tool.",
		"",
		"Every track here was trimmed, folded into a loop, normalised and encoded",
		"from a raw generator take in `assets/incoming/music/` (gitignored).",
		"Prompts and the delivery format:",
		"[docs/design/music-prompts.md](../../../docs/design/music-prompts.md).",
		"",
		"`seam` is the level difference across the loop point, in dB. Small is",
		"good; it says the fold did not land in silence. It cannot say the fold",
		"lands on a bar line - **that needs ears.**",
		"",
		"| track | from | length | fold | trimmed | LUFS | peak | seam | KB |",
		"|---|---|---|---|---|---|---|---|---|",
	]
	for r in sorted(rows, key=lambda x: x["out"]):
		trimmed = f"{r['trimmed_head']:.1f}s / {r['trimmed_tail']:.1f}s"
		fold = f"{r['crossfade']:.0f}s" if r["crossfade"] else "once"
		seam = "n/a" if not r["crossfade"] else f"{r['seam_gap']:.1f} dB"
		lines.append(f"| `{r['out']}` | {r['source']} | {r['seconds_out']:.0f}s | {fold} | "
		             f"{trimmed} | {r['lufs_out']:.1f} | {r['peak_out']:.1f} | {seam} | "
		             f"{r['kb']:.0f} |")
	lines.append("")
	MANIFEST.parent.mkdir(parents=True, exist_ok=True)
	MANIFEST.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
	ap = argparse.ArgumentParser(description=__doc__,
	                             formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("--only", help="one track id (or prefix) instead of everything")
	ap.add_argument("--loop", type=float, default=None,
	                help="override the loop crossfade seconds for this run (0 disables)")
	ap.add_argument("--no-trim", action="store_true",
	                help="keep the take's own head and tail exactly as delivered")
	ap.add_argument("--measure", action="store_true",
	                help="report the incoming takes, write nothing")
	ap.add_argument("--wire", action="store_true",
	                help="copy assets/library/music -> game/assets/music and import")
	args = ap.parse_args()

	if args.wire:
		return wire()

	if not INCOMING.exists():
		INCOMING.mkdir(parents=True, exist_ok=True)
		print(f"created {INCOMING.relative_to(REPO)} - drop the generated takes there")
		return 0

	takes = sorted(p for p in INCOMING.iterdir()
	               if p.suffix.lower() in SOURCE_EXTS
	               and (not args.only or track_id(p.stem).startswith(args.only)))
	if not takes:
		print(f"nothing to do: no audio in {INCOMING.relative_to(REPO)}")
		return 0

	if args.measure:
		print(f"{'file':<34}{'sec':>7}{'rate':>8}{'ch':>4}{'LUFS':>8}{'peak dBTP':>11}"
		      f"{'head':>7}{'tail':>7}")
		for t in takes:
			info, m = probe(t), measure_loudness(t)
			start, end, _ = find_edges(envelope(t), info["seconds"])
			print(f"{t.name:<34}{info['seconds']:>7.1f}{info['rate']:>8}{info['channels']:>4}"
			      f"{float(m['input_i']):>8.1f}{float(m['input_tp']):>11.1f}"
			      f"{start:>7.1f}{info['seconds'] - end:>7.1f}")
		return 0

	seen: dict[str, str] = {}
	rows = []
	for t in takes:
		name = track_id(t.stem)
		if name in seen:
			print(f"  ! {t.name}: {seen[name]} already claimed '{name}' - skipping. "
			      f"Keep one take per track.")
			continue
		seen[name] = t.name
		cfg = settings_for(name)
		print(f"  {t.name} -> {name}.ogg")
		rows.append(convert(t, LIBRARY / f"{name}.ogg", cfg, args.loop, not args.no_trim))

	write_manifest(rows)
	print(f"\n{'track':<24}{'in s':>7}{'out s':>7}{'cut':>7}{'fold':>6}"
	      f"{'LUFS':>7}{'peak':>7}{'seam':>7}{'KB':>7}  note")
	for r in rows:
		cut = r["trimmed_head"] + r["trimmed_tail"]
		seam = "-" if not r["crossfade"] else f"{r['seam_gap']:.1f}"
		flag = "  <- SEAM IN SILENCE" if r["seam_quiet"] else ""
		print(f"{r['out']:<24}{r['seconds_in']:>7.1f}{r['seconds_out']:>7.1f}{cut:>7.1f}"
		      f"{r['crossfade']:>6.1f}{r['lufs_out']:>7.1f}{r['peak_out']:>7.1f}"
		      f"{seam:>7}{r['kb']:>7.0f}  {r['note']}{flag}")
	print(f"\n{len(rows)} track(s) in {LIBRARY.relative_to(REPO)}, manifest written.")
	print("Play each one LOOPED before shipping - the seam numbers prove the fold is not "
	      "in silence, they cannot hear a fold landing mid-phrase.")
	print("Then: python tools/wire_music.py --wire")
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
		print(f"\n{copied} file(s) copied. Godot not found at {GODOT} - "
		      f"run `godot --headless --path game --import` yourself (law 23).")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
