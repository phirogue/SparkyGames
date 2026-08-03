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
OUT_DIR = REPO / "assets" / "incoming" / "procedural"

STYLE = (
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
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / f"{asset_id}.png"
    version = 2
    while path.exists():
        path = OUT_DIR / f"{asset_id}_v{version}.png"
        version += 1
    return path


def generate(prompt: str, size: str, quality: str, count: int, key: str) -> list:
    body = json.dumps(
        {
            "model": "gpt-image-1",
            "prompt": prompt,
            "size": size,
            "quality": quality,
            "n": count,
        }
    ).encode("utf-8")
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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("asset_id")
    parser.add_argument("--prompt", help="prompt text; omit to read stdin")
    parser.add_argument("--ratio", default="9:16", choices=sorted(RATIO_TO_SIZE))
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

    images = generate(
        prompt, RATIO_TO_SIZE[args.ratio], args.quality, args.n, load_key()
    )
    for blob in images:
        path = next_free_path(args.asset_id)
        path.write_bytes(blob)
        print(f"wrote {path.relative_to(REPO)}  ({len(blob) // 1024} KB)")


if __name__ == "__main__":
    main()
