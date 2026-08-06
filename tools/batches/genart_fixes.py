"""Regenerate the art that failed the 2026-08-03 style audit.

Run:  python tools/genart_fixes.py [--dry-run]

The audit found a single shared failure mode across seven library files -- a
"full-bleed digital render" look: edge-to-edge crop with no paper margin,
airbrushed blending, crushed true-black darks, a mosaic/scale stipple on flat
surfaces, and uniformly high detail with nothing dissolving into wash.

STRICT_STYLE below names those tells as negatives. That is the whole point of
this pass: the old style block described what we wanted but never forbade what
we kept getting.
"""

import sys
from pathlib import Path

# Moved into tools/batches/ 2026-08-06; genart.py is one level up.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import time

from genart import (RATIO_TO_SIZE, STRICT_STYLE, generate, load_key,
                    next_free_path)


JOBS = [
    # --- worst offenders from the library audit ---
    dict(
        id="sc_vole_stalk",
        ratio="3:4",
        prompt=(
            "A lean black cat with glowing orange eyes and a frayed RED "
            "NECKERCHIEF pressed low against rooftop tiles at dusk, pupils "
            "wide, hindquarters raised in the pre-pounce wiggle, stalking a "
            "small unaware vole near a chimney pot a short distance away. Warm "
            "last light. Keep the sky a single loose wash -- no banded or neon "
            "colours."
        ),
    ),
    dict(
        id="bg_shambles",
        ratio="9:16",
        prompt=(
            "A night view over a sleeping market district: crooked timber "
            "shopfronts, market stalls under canvas covers, hanging shop signs, "
            "one lit lantern glowing warm amber down the lane, blue-grey fog "
            "pooling between the buildings. Keep the darks light and "
            "transparent so the paper still shows through; let the far end of "
            "the lane dissolve into bare paper."
        ),
    ),
    dict(
        id="sc_over_the_fences",
        ratio="3:4",
        prompt=(
            "A lean black cat with glowing orange eyes and a frayed RED "
            "NECKERCHIEF in full sprint, leaping between fence tops and garden "
            "walls at night, rooftops and one dark window ahead, urgency and "
            "grace. Warm amber lamplight somewhere in the scene against the "
            "blue-grey night. Let the fog be bare paper, not grey paint."
        ),
    ),
    dict(
        id="bg_gardens",
        ratio="9:16",
        prompt=(
            "Moonlit walled back gardens behind row houses: vegetable beds, a "
            "small greenhouse, laundry lines, clipped hedges casting deep soft "
            "shadows, a sleeping house beyond a fence with ONE warm amber lit "
            "window. Draw only the near hedge and beds in detail; let the far "
            "garden dissolve into loose blue-grey wash and bare paper."
        ),
    ),
    dict(
        id="bg_parlor_cold",
        ratio="3:4",
        prompt=(
            "A cozy cluttered witch's parlor at night, but tonight everything "
            "is wrong: a worn armchair, a small iron stove gone COLD and dark, "
            "the lamp out, spools of thread and hanging herbs, and thin blue "
            "moonlight through the window as the only light. Every thin thread "
            "hanging on the walls has been cut and dangles loose. Melancholy "
            "and still. Keep it a WATERCOLOUR: the darks must stay transparent "
            "washes with paper showing through, never solid black."
        ),
    ),
    # --- defects in today's new batch ---
    dict(
        id="sc_hollow_court_desk",
        ratio="3:4",
        prompt=(
            "A vast dim underground records office: towering bookshelves fading "
            "up into darkness, one small wooden desk with a brass lamp, and "
            "seated behind it a PRIM TRANSLUCENT GREY GHOST CLERK IN AN "
            "OLD-FASHIONED SUIT AND PINCE-NEZ SPECTACLES, with an expression of "
            "fussy professional disapproval. The ghost is a neatly dressed "
            "gentleman, NOT a floating bedsheet. A single empty cat-sized chair "
            "stands opposite the desk. NO CAT anywhere in the picture, no "
            "animals. Dust drifting in the lamplight."
        ),
    ),
    dict(
        id="sc_shambles_day",
        ratio="3:4",
        prompt=(
            "The same crooked timber market street by day, but overcast and "
            "quiet rather than sunny: leaning timber-framed shopfronts, a few "
            "market stalls under faded canvas, hanging shop signs, crates of "
            "vegetables, thin grey daylight through high fog, only two or three "
            "distant muted figures glimpsed at the far end. Cozy-gothic and "
            "subdued -- muted ochre and blue-grey, NOT a bright blue sky, NOT a "
            "crowd, NOT cheerful. Seen low, from a cat's height."
        ),
    ),
]


def main() -> None:
    dry = "--dry-run" in sys.argv
    key = None if dry else load_key()
    done, failed = [], []

    for i, job in enumerate(JOBS, 1):
        prompt = f"{STRICT_STYLE}\n\n{job['prompt']}"
        label = f"[{i}/{len(JOBS)}] {job['id']} ({job['ratio']})"
        if dry:
            print(f"{label}\n    {job['prompt'][:100]}...\n")
            continue
        print(f"{label} generating...", flush=True)
        try:
            blobs = generate(
                prompt, RATIO_TO_SIZE[job["ratio"]], "high", 1, key, "gpt-image-2"
            )
        except SystemExit as exc:
            print(f"    FAILED: {exc}", flush=True)
            failed.append(job["id"])
            continue
        path = next_free_path(job["id"])
        path.write_bytes(blobs[0])
        print(f"    wrote {path.name} ({len(blobs[0]) // 1024} KB)", flush=True)
        done.append(job["id"])
        time.sleep(1)

    if not dry:
        print(f"\ndone: {len(done)}   failed: {len(failed)}")
        if failed:
            print("failed ids:", ", ".join(failed))


if __name__ == "__main__":
    main()
