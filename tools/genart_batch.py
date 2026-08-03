"""Generate every image requested in docs/design but never made.

Sources: art-needed.md, image-prompts-master.md (sections E and F).
Run:  python tools/genart_batch.py [--dry-run]

`style: False` means the shared style block is NOT prepended -- it ends with
"no text in the image", which is wrong for logos and UI mockups that need
lettering, and its "warm amber against blue-grey fog" pollutes icons that are
meant to sit on plain white.
"""

import sys
import time

from genart import STYLE, RATIO_TO_SIZE, generate, load_key, next_free_path

JOBS = [
    # --- Fixes ---
    dict(
        id="logo_ashcat_title",
        ratio="9:16",
        style=False,
        prompt=(
            "A hand-lettered game logo reading exactly \"The Nine Lives of "
            "Ashcat\" in elegant slightly-gothic storybook lettering, ink and "
            "watercolor style, with a small black cat silhouette curled around "
            "the letters and a thin silver thread winding through them, warm "
            "cream and charcoal with one ember-orange accent, on a plain dark "
            "background, high contrast, readable at small sizes. Spell it "
            "carefully: The Nine Lives of Ashcat -- the word \"of\" appears "
            "exactly once."
        ),
    ),
    dict(
        id="ui_paw_solid",
        ratio="1:1",
        style=False,
        prompt=(
            "A single cat paw print icon, SOLID dark walnut-brown ink fill like "
            "a real inked paw stamp, slightly rough hand-pressed edges, on a "
            "plain white background, simple and readable at small sizes, no "
            "outline-only areas, no text."
        ),
    ),
    # --- Casebook / Case board ---
    dict(
        id="ui_paw_stamp",
        ratio="1:1",
        style=False,
        prompt=(
            "A black cat's paw print stamped in dark ink on aged parchment, "
            "slightly smudged at one edge as if the paw lifted quickly, "
            "hand-drawn storybook ink and watercolor style, no text."
        ),
    ),
    dict(
        id="ui_case_board",
        ratio="3:4",
        style=False,
        prompt=(
            "An old corkboard page inside a leather casebook: three empty "
            "rectangular portrait spaces at top connected by red thread and "
            "brass pins, smaller empty note spaces below, ink annotations too "
            "small to read, aged parchment, hand-drawn storybook ink and "
            "watercolor style, no faces, no readable text."
        ),
    ),
    # --- Chapter 1 cast ---
    dict(
        id="npc_brindle_magpie",
        ratio="3:4",
        style=True,
        prompt=(
            "A sly, charming magpie perched on a heap of buttons, keys, rings "
            "and one pocket-watch, head tilted appraisingly, one eye catching "
            "lantern light, inside a cluttered night-market stall, cozy-gothic, "
            "no text."
        ),
    ),
    dict(
        id="npc_rat_boss",
        ratio="3:4",
        style=True,
        prompt=(
            "A portly, dignified old rat in a waistcoat made of stitched "
            "scraps, seated on a cotton-reel throne under the floorboards, "
            "candle-lit, holding a grain of wheat like a scepter, wry not "
            "sinister, no text."
        ),
    ),
    dict(
        id="npc_pigeon_postmaster",
        ratio="3:4",
        style=True,
        prompt=(
            "A rumpled city pigeon wearing a tiny leather message-satchel, "
            "standing at attention on a rooftop ledge post among sleeping "
            "pigeons, dawn fog, one nervous eye, no text."
        ),
    ),
    # --- Nice to have ---
    dict(
        id="ui_icon_menu",
        ratio="1:1",
        style=False,
        prompt=(
            "A small round hand-drawn icon of three short horizontal stitched "
            "lines like sewn seams, dark walnut ink on a small parchment "
            "circle, storybook ink and watercolor style, reads clearly at 32 "
            "pixels, plain background, no text."
        ),
    ),
    dict(
        id="sc_shambles_day",
        ratio="3:4",
        style=True,
        prompt=(
            "A busy market street at midday: crooked timber shopfronts, market "
            "stalls open under striped canvas covers, hanging shop signs, "
            "crates of vegetables, townsfolk browsing at a distance, bright "
            "midday sun with short shadows, cheerful and bustling, no text."
        ),
    ),
    # --- UI screen mockups (design references; lettering wanted) ---
    dict(
        id="mock_journal",
        ratio="9:16",
        style=False,
        prompt=(
            "A mobile game journal screen mockup, portrait, storybook parchment "
            "style: an open leather-cornered casebook page titled like a "
            "detective's journal, left-aligned handwritten-style entries with "
            "small ink icons (a paw print, a wax seal, a thread), tabs at the "
            "top shaped like leather bookmarks labeled for deeds and knowledge, "
            "a small back arrow in a parchment square top-left, stitched border "
            "around the page."
        ),
    ),
    dict(
        id="mock_chapter_select",
        ratio="9:16",
        style=False,
        prompt=(
            "A mobile game chapter select mockup, portrait, storybook style: a "
            "wooden drawer of case files seen from above, manila folders with "
            "wax seals and short handwritten labels, the first folder open "
            "showing a small illustration and a progress stamp, later folders "
            "tied shut with red thread, stitched parchment border."
        ),
    ),
    dict(
        id="mock_settings",
        ratio="9:16",
        style=False,
        prompt=(
            "A mobile game settings screen mockup, portrait, storybook "
            "parchment style: a short list of options as hand-inked rows with "
            "small icons (a bell for sound, a music note, a candle for "
            "brightness, a letter for language), each with a thread-and-toggle "
            "switch drawn as a button sewn on or off, stitched border, small "
            "back arrow top-left."
        ),
    ),
    # --- Chapter 1 scene art ---
    dict(
        id="bg_mantel_scene",
        ratio="9:16",
        style=True,
        prompt=(
            "A stone fireplace wall in a witch's parlor at night: a wide stone "
            "mantelpiece with two lit oil lamps, a cold hearth below, wall "
            "space above the mantel completely bare, moody blue shadows with "
            "warm lamplight pools. No papers or notes anywhere, no people, no "
            "cat, no text."
        ),
    ),
    dict(
        id="sc_hollow_court_desk",
        ratio="3:4",
        style=True,
        prompt=(
            "A vast dim underground records office: towering bookshelves fading "
            "up into darkness, one small wooden desk with a green-shaded lamp "
            "and a translucent grey ghost clerk seated behind it, a single "
            "cat-sized chair opposite, dust in the lamplight, no text."
        ),
    ),
]


def main() -> None:
    dry = "--dry-run" in sys.argv
    key = None if dry else load_key()
    done, failed = [], []

    for i, job in enumerate(JOBS, 1):
        prompt = job["prompt"]
        if job["style"]:
            prompt = f"{STYLE}\n\n{prompt}"
        label = f"[{i}/{len(JOBS)}] {job['id']} ({job['ratio']})"
        if dry:
            print(f"{label}\n    {prompt[:110]}...\n")
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
