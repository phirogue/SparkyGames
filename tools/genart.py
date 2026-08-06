"""Generate art from docs/design/art-needed.md prompts via the OpenAI Images API.

Usage:
    python tools/genart.py <asset_id> [--ratio 9:16] [--quality high] [--n 1]

Reads OPENAI_API_KEY from .env at the repo root. Prompts are passed on stdin or
via --prompt; the shared storybook style block is prepended automatically.
Results land in assets/incoming/procedural/<asset_id>.png (never overwrites --
subsequent runs get _v2, _v3, ...).

Cost note: gpt-image-1 is billed per image (~$0.02-0.19). See
docs/design/asset-pipeline.md.
"""

import argparse
import base64
import json
import sys
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LIB = REPO / "assets" / "library"
sys.path.insert(0, str(Path(__file__).resolve().parent))

# gpt-image-1 is the April-2025 snapshot named in asset-pipeline.md; it is
# several generations behind what ChatGPT serves in-chat and looks it. Ask the
# /v1/models endpoint before assuming this is still the newest.
DEFAULT_MODEL = "gpt-image-2"

# THE HOUSE STYLE. Lives here, in the tool everything calls, because for a
# while it did not: this file kept the loose 2026-08-01 block below while the
# strict one lived in `genart_fixes.py` -- a one-off batch script. Anybody who
# ran `genart.py` directly therefore got the style that drifts, which is the
# opposite of what CLAUDE.md's art rule 7 says happens.
#
# What makes it work is the NEGATIVES. "Ink linework with muted watercolour
# washes" is perfectly satisfiable by a digital painting imitating that look,
# and nine images drifted exactly that way before anyone compared them side by
# side. They shared three precise tells, which meant they were one bad preset
# and one fix repaired all nine. Naming the failure modes is the whole trick.
STYLE = (
    "Hand-drawn storybook illustration on visible cream watercolor paper: "
    "paper grain and a soft torn deckle edge are visible at the borders. "
    "Loose, scratchy ink linework sits ON TOP of muted granulated watercolor "
    "washes, with large areas of untouched bare paper. Warm amber light used "
    "sparingly as the accent against blue-grey shadow. Cozy-gothic children's "
    "book aesthetic. Selective detail only -- the focal subject is drawn, and "
    "everything behind it dissolves into loose transparent wash. "
    "IMPORTANT NEGATIVES: this must NOT look like a digital painting, 3D "
    "render, matte painting, or photograph. No airbrushed or smooth gradient "
    "blending. No crushed pure-black darks -- shadows stay transparent. No "
    "mosaic, scale, or stipple texture on flat surfaces. No uniform "
    "edge-to-edge detail. No text anywhere in the image."
)

# The name the batch scripts and CLAUDE.md use. Same string, one definition.
STRICT_STYLE = STYLE

# The pre-audit block, kept only so the 2026-08-03 style audit stays legible:
# this is what the drifted images were generated with. Do not use it.
LEGACY_STYLE_2026_08_01 = (
    "Hand-drawn storybook illustration style: ink linework with muted "
    "watercolor washes, warm amber light against blue-grey fog, cozy-gothic "
    "children's book aesthetic, high resolution, no text in the image."
)

# gpt-image-1 only accepts these three; map our manifest ratios onto them.
RATIO_TO_SIZE = {
    "9:16": "1024x1536",
    "3:4": "1024x1536",
    "2:3": "1024x1536",
    "1:1": "1024x1024",
    "16:9": "1536x1024",
    "4:3": "1536x1024",
}


def load_key() -> str:
    env = REPO / ".env"
    if not env.exists():
        sys.exit("No .env at repo root. Create it with OPENAI_API_KEY=sk-...")
    for line in env.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("OPENAI_API_KEY="):
            key = line.split("=", 1)[1].strip().strip('"').strip("'")
            if key:
                return key
    sys.exit("OPENAI_API_KEY is empty in .env")


def next_free_path(asset_id: str) -> Path:
    """Where a freshly generated image goes: straight into the library.

    Owner decision 2026-08-03 -- no more incoming/ staging step. The library
    holds every image cleared to be used or requested to exist; anything it
    displaces moves to assets/archive/superseded/ rather than being lost
    (CLAUDE.md art rules 2 and 3).

    A `_v2`-style suffix in asset_id still resolves to the canonical name, so
    a regeneration replaces the file it is a new take of.
    """
    from promote import canonical_id, kind_for, next_archive_path, move

    canonical = canonical_id(asset_id)
    target = LIB / kind_for(canonical) / f"{canonical}.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        archived = next_archive_path(canonical)
        move(target, archived)
        print(f"    (archived previous {canonical}.png -> {archived.name})")
    return target


def generate(
    prompt: str,
    size: str,
    quality: str,
    count: int,
    key: str,
    model: str,
    background: str = None,
) -> list:
    """background='transparent' asks the API for real alpha, which saves a
    rembg pass on UI icons. Ignored for photographic subjects."""
    payload = {
        "model": model,
        "prompt": prompt,
        "size": size,
        "quality": quality,
        "n": count,
    }
    if background:
        payload["background"] = background
        payload["output_format"] = "png"
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        "https://api.openai.com/v1/images/generations",
        data=body,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            payload = json.load(resp)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        sys.exit(f"OpenAI API error {exc.code}: {detail}")
    return [base64.b64decode(item["b64_json"]) for item in payload["data"]]


def _multipart(fields: list, files: list) -> tuple:
    """Build a multipart/form-data body. fields=[(name,value)], files=[(name,path)]."""
    boundary = "----genart7d3f9b1c2e5a"
    out = bytearray()
    for name, value in fields:
        out += f"--{boundary}\r\n".encode()
        out += f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
        out += f"{value}\r\n".encode()
    for name, path in files:
        data = Path(path).read_bytes()
        out += f"--{boundary}\r\n".encode()
        out += (
            f'Content-Disposition: form-data; name="{name}"; '
            f'filename="{Path(path).name}"\r\n'.encode()
        )
        out += b"Content-Type: image/png\r\n\r\n"
        out += data + b"\r\n"
    out += f"--{boundary}--\r\n".encode()
    return bytes(out), f"multipart/form-data; boundary={boundary}"


def edit(
    prompt: str, refs: list, size: str, quality: str, count: int, key: str, model: str
) -> list:
    """Generate FROM reference images via the images/edits endpoint.

    This is how character consistency is actually achieved -- words alone let a
    character drift between generations (art-manifest.md rule 3, and CLAUDE.md
    art rule 4). Pass the canonical ref_<name>.png as a reference and the model
    holds the design. Also the right tool for "same image, one thing changed".
    """
    fields = [
        ("model", model),
        ("prompt", prompt),
        ("size", size),
        ("quality", quality),
        ("n", str(count)),
    ]
    files = [("image[]", r) for r in refs]
    body, content_type = _multipart(fields, files)
    req = urllib.request.Request(
        "https://api.openai.com/v1/images/edits",
        data=body,
        headers={"Authorization": f"Bearer {key}", "Content-Type": content_type},
    )
    try:
        with urllib.request.urlopen(req, timeout=900) as resp:
            payload = json.load(resp)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        sys.exit(f"OpenAI API error {exc.code}: {detail}")
    return [base64.b64decode(item["b64_json"]) for item in payload["data"]]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("asset_id")
    parser.add_argument("--prompt", help="prompt text; omit to read stdin")
    parser.add_argument("--ratio", default="9:16", choices=sorted(RATIO_TO_SIZE))
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=(
            "gpt-image-2 (newest), chatgpt-image-latest (tracks in-chat "
            "ChatGPT), gpt-image-1.5, gpt-image-1 (old -- avoid)"
        ),
    )
    parser.add_argument(
        "--suffix", default="", help="appended to the filename, e.g. a model tag"
    )
    parser.add_argument(
        "--ref",
        action="append",
        default=[],
        metavar="PNG",
        help=(
            "reference image to generate FROM (repeatable). Switches to the "
            "images/edits endpoint. Required for any recurring character -- "
            "attach their ref_<name>.png so they don't drift."
        ),
    )
    parser.add_argument("--quality", default="high", choices=["low", "medium", "high"])
    parser.add_argument("--n", type=int, default=1)
    parser.add_argument(
        "--no-style", action="store_true", help="skip the shared style block"
    )
    args = parser.parse_args()

    prompt = args.prompt if args.prompt else sys.stdin.read()
    prompt = prompt.strip()
    if not prompt:
        sys.exit("Empty prompt.")
    if not args.no_style:
        prompt = f"{STYLE}\n\n{prompt}"

    key = load_key()
    size = RATIO_TO_SIZE[args.ratio]
    if args.ref:
        for r in args.ref:
            if not Path(r).exists():
                sys.exit(f"reference not found: {r}")
        images = edit(prompt, args.ref, size, args.quality, args.n, key, args.model)
    else:
        images = generate(prompt, size, args.quality, args.n, key, args.model)
    for blob in images:
        path = next_free_path(args.asset_id + args.suffix)
        path.write_bytes(blob)
        print(f"wrote {path.relative_to(REPO)}  ({len(blob) // 1024} KB)")


if __name__ == "__main__":
    main()
