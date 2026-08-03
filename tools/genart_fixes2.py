"""Second regeneration wave from the 2026-08-03 style audit.

Wave 1 (genart_fixes.py) took the worst backdrops and scenes. This finishes
the "full-bleed digital" cluster and fixes two canon defects in the enemies.

Run:  python tools/genart_fixes2.py [--dry-run]
"""

import sys
import time

from genart import RATIO_TO_SIZE, generate, load_key, next_free_path
from genart_fixes import STRICT_STYLE

JOBS = [
    # --- remainder of the full-bleed digital cluster ---
    dict(
        id="bg_parlor_warm",
        ratio="3:4",
        prompt=(
            "A cozy cluttered witch's parlor interior: a worn armchair beside a "
            "small iron stove with a copper kettle gently steaming, walls hung "
            "with embroidery hoops and spools of faintly glowing silver thread, "
            "herbs drying from the beams, a saucer of milk by the hearth. Warm "
            "golden lamplight, lived-in and loved. Leave the corners of the "
            "room loose and unfinished so the paper shows through."
        ),
    ),
    dict(
        id="sc_threads_cut",
        ratio="3:4",
        prompt=(
            "Interior of a dark workroom at night from a cat's low viewpoint: "
            "walls of embroidery hoops and pinned threads where every thread "
            "has been freshly cut, loose ends hanging and drifting. Thin blue "
            "moonlight. Through a doorway at the far end, a tall shape woven of "
            "glowing silver threads stands with its back turned, mid-work. "
            "Quiet dread. Suggest the cut threads with a FEW dozen confident "
            "ink strokes, not thousands of fine strands -- this must stay "
            "readable at phone size. Keep one small warm amber accent."
        ),
    ),
    dict(
        id="sc_lamplighters_hall",
        ratio="3:4",
        prompt=(
            "The interior of a lamplighters' guild hall at night, abandoned "
            "mid-shift: ladders racked on the wall, long lighting-poles in "
            "their stands, a kettle gone cold on a small stove, and one silver "
            "thread caught glinting on a brass lamp-hook in the foreground. "
            "Nobody there. Warm amber lamplight against blue-grey shadow. No "
            "signage or lettering of any kind on the walls."
        ),
    ),
    # --- enemy defects ---
    dict(
        id="en_garden_watch",
        ratio="3:4",
        prompt=(
            "A large white goose standing guard in a moonlit walled garden, "
            "chest puffed, wings slightly raised, radiating self-importance and "
            "menace, slightly comic. The goose is the clear subject; let the "
            "garden behind it dissolve into loose blue-grey wash and bare "
            "paper. Suggest the feathers with a few loose strokes -- do not "
            "render every feather."
        ),
    ),
    dict(
        id="en_garden_watch_captain",
        ratio="3:4",
        prompt=(
            "A large imperious white goose wearing a tiny ceremonial chain of "
            "office around its neck, standing on a garden wall at night like a "
            "commander reviewing troops, menacing and absurd. The goose is the "
            "clear subject; the garden and house behind dissolve into loose "
            "wash and bare paper. Suggest the feathers with a few loose strokes "
            "-- do not render every feather. No photographic moon."
        ),
    ),
    dict(
        id="en_the_unpicked",
        ratio="3:4",
        prompt=(
            "A tall looming figure woven entirely from glowing silver threads, "
            "a vaguely human silhouette with long loose thread-ends trailing "
            "away, standing alone in a dark doorway. Beautiful and wrong. "
            "IMPORTANT: the thread figure is COMPLETELY ALONE in the picture -- "
            "no people, no children, no bystanders, no animals, nobody watching "
            "it. One warm amber lamp somewhere in the room for contrast."
        ),
    ),
    # --- skill cards where Ash went off-model ---
    # ASH_CANON is repeated verbatim because the audit found the character
    # drifting whenever the description was loose. Long term this should use
    # the /v1/images/edits endpoint with ref_ash.png attached -- reference
    # images do the consistency work, not words (art-manifest.md, rule 3).
    dict(
        id="sk_slink",
        ratio="1:1",
        prompt=(
            "ASH: a LEAN, ANGULAR, SHORT-HAIRED black cat with a narrow "
            "wedge-shaped head, slim build, glowing amber-orange slit eyes, and "
            "a frayed RED NECKERCHIEF of visible cloth at his throat. He is NOT "
            "a longhair, NOT round-faced, NOT fluffy, and has no thick ruff. "
            "Scene: Ash melting into a pool of shadow under a gaslamp, only his "
            "orange eyes and red neckerchief visible in the dark shape. Keep "
            "the eyes flat ink-and-wash, not glossy."
        ),
    ),
    dict(
        id="sk_pounce",
        ratio="1:1",
        prompt=(
            "ASH: a LEAN, ANGULAR, SHORT-HAIRED black cat with a narrow "
            "wedge-shaped head, slim build, glowing amber-orange slit eyes, and "
            "a frayed RED NECKERCHIEF at his throat. The neckerchief must read "
            "clearly as a TIED PIECE OF RED CLOTH knotted at the neck with "
            "frayed ends -- not a stripe, not a streak, not a wound. Scene: Ash "
            "leaping through the air with claws out, dynamic pose, night "
            "rooftop behind him dissolving into loose wash. Keep his coat "
            "smooth and sleek, not shaggy."
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
