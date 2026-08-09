"""Chapter 1 wave 2: the back half's battles, plus the Court's two changes.

    python tools/batches/genart_wave2.py [--dry-run]

The four back-half quests shipped 2026-08-08 with their story complete and
six ids accepted as gaps in docs/architecture/known-gaps.json: three battle
backdrops and three enemies. This batch closes them, plus the two Hollow
Court desk variants art-needed.md wants so the Clerk's escalation is SEEN
as well as read (law 15 — those pages currently drop their portrait).

CANON THAT MATTERS HERE (world-bible.md, the-unraveler.md, enemies.json):

- **Wickrow sells light to the frightened.** Every doorway wears a small
  warded flame with the guild bee on the brass; the district has never once
  been seen dark. Warm amber against deep blue-grey is the whole point.
- **The Drowned are patient, not horrid.** "Never fast. Always arriving."
  Dry-footed on a wet street — the wrongness is the CALM, not gore. No
  zombie theatrics; the Mere's people simply stand too still, too near.
- **The Tallowman is gentle.** A hundred years of guild votives poured into
  one patient shape that apologizes sincerely. It must read kindly and
  enormous, never monstrous — the fight's horror is that it would rather
  you left.
- **The candle-golem is on shift, not angry.** Night staff, poured wax, a
  lit wick where the thinking would go.
- **The Hollow Court variants are EDITS of sc_hollow_court_desk** (room
  variants are edited from the room, not re-described): visit six gains a
  cat-sized chair; visit eight turns the lamp up. Nothing else may change,
  and no cat appears — the pages are Ash's own eyes.

FRAMING (the /genart table): backdrops 9:16, no figures anywhere (the enemy
is drawn OVER them); enemies 3:4 scene vignettes, subject dominant, setting
dissolving into wash (en_chained_dog is the reference); scenes 3:4.
"""

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from genart import RATIO_TO_SIZE, STRICT_STYLE, edit, generate, load_key, next_free_path

REPO = Path(__file__).resolve().parent.parent.parent

JOBS = [
    # -------------------------------------------------------- backdrops (9:16)
    dict(
        id="bg_wickrow",
        ratio="9:16",
        prompt=(
            "A narrow gaslamp-era shopping street at night in the chandlers' "
            "district: crooked timber shopfronts leaning over wet cobbles, and "
            "in EVERY doorway a small brass lantern holding one steady warded "
            "flame, dozens of them receding down the street like a rosary of "
            "little fires. Hanging shop signs with candle and bee shapes "
            "(shapes only — no readable lettering). Warm amber flame-light "
            "pooling in each doorway against deep blue-grey night, faint fog "
            "high between the eaves. The street is EMPTY: no people, no "
            "animals, no figures of any kind — a stage awaiting its actor."
        ),
    ),
    dict(
        id="bg_mereside",
        ratio="9:16",
        prompt=(
            "A drowned waterfront street at night: stone terraces and house "
            "fronts stepping down INTO flat black lake water, the lowest "
            "windows half-submerged and dark. Thick fog rolling off the water "
            "up the street. To one side, the flank of a great brick warehouse "
            "with a faint silver thread-like shimmer stitched along its "
            "footing, as if the wall were hemmed with cobweb light. Wet "
            "cobbles in the foreground holding pale reflections. Cold "
            "blue-green and grey throughout, one distant warm window high up. "
            "The street is EMPTY: no people, no animals, no figures of any "
            "kind, nothing standing in the water."
        ),
    ),
    dict(
        id="bg_guildhall",
        ratio="9:16",
        prompt=(
            "The interior of a candle-makers' guildhall at night, built like "
            "a chapel to flame: banked tiers of thousands of lit votive "
            "candles rising up both sides, wax run down the tiers in pale "
            "frozen falls, the air bright with massed candlelight and a "
            "faint heat-shimmer. A broad stone stair climbing at the back "
            "toward an unseen upper office. Polished dark floor holding "
            "golden reflections. Overwhelming warm amber and honey light "
            "with deep brown-grey shadow at the edges. The hall is EMPTY: "
            "no people, no animals, no figures of any kind."
        ),
    ),
    # ---------------------------------------------------------- enemies (3:4)
    dict(
        id="en_candle_golem",
        ratio="3:4",
        prompt=(
            "A candle-golem: a man-shaped figure poured from votive beeswax, "
            "standing square in a counting-house doorway at night. Its body "
            "is smooth-run candle wax the colour of old cream, drips frozen "
            "down its shoulders and forearms like slow epaulettes, seams "
            "where it was poured in sections. Where a head would think, one "
            "short lit WICK burns with a small steady flame, faintly lighting "
            "its own chest and the door frame. Its face is a gentle blank "
            "suggestion in the wax — calm, on shift, not angry, not "
            "monstrous. Posture upright and patient, arms loose. The doorway "
            "and shelves behind it dissolve into loose blue-grey wash. One "
            "figure alone — no humans, no animals, no second creature."
        ),
    ),
    dict(
        id="en_the_drowned",
        ratio="3:4",
        prompt=(
            "One of the Drowned: a human-shaped figure standing perfectly "
            "still on wet night cobbles, waterlogged gaslamp-era clothes "
            "hanging heavy and calm as if just lifted from a lake, lake-weed "
            "dark at the hem, skin pale grey-green where it shows. Its face "
            "is downcast and indistinct in shadow — quiet, patient, almost "
            "polite, with NO gore, no wounds, no skeleton, no horror-film "
            "theatrics; the wrongness is only the stillness. Around its bare "
            "feet the wet street is DRY in a small ring — dry-footed on a "
            "wet street. Fog and a drowned terrace behind it dissolve into "
            "cold blue-green wash. One figure alone — no other people, no "
            "animals."
        ),
    ),
    dict(
        id="en_the_tallowman",
        ratio="3:4",
        prompt=(
            "The Tallowman: an enormous gentle figure poured from a hundred "
            "years of votive tallow and beeswax, filling a guildhall floor, "
            "twice the height of the doorway behind it. A soft rounded "
            "mountain of cream and honey-coloured wax with a kind, patient, "
            "almost apologetic face suggested in its surface, broad hands "
            "held open like warming pans, and a dozen small votive flames "
            "guttering in the wax of its shoulders and back like candles on "
            "a shrine. It must read KINDLY and enormous — no fangs, no "
            "claws, no snarl, nothing monstrous; the unsettling part is its "
            "patience. Banked votive candlelight behind it dissolves into "
            "warm amber wash. One figure alone — no humans, no animals."
        ),
    ),
]

# Room variants are EDITED from the room, never re-described (the recipe that
# made bg_parlor_cold provably the same room as bg_parlor_warm).
EDIT_JOBS = [
    dict(
        id="sc_hollow_court_chair",
        ref=REPO / "assets/library/scenes/sc_hollow_court_desk.png",
        ratio="3:4",
        prompt=(
            "Keep this exact scene — the same translucent clerk at the same "
            "lamplit desk, same filing shelves, same palette, same "
            "composition — and add ONE new thing: beside the full-size chair "
            "facing the desk, a second chair, exactly cat-sized, neat and "
            "plainly made, as if it had always been there and nobody will "
            "mention it. Change nothing else. No cat appears."
        ),
    ),
    dict(
        id="sc_hollow_court_lamp",
        ref=REPO / "assets/library/scenes/sc_hollow_court_desk.png",
        ratio="3:4",
        prompt=(
            "Keep this exact scene — the same translucent clerk at the same "
            "desk, same filing shelves, same composition — with ONE change: "
            "the desk lamp has been turned UP, throwing a wider, warmer, "
            "brighter pool of light across the desk and the clerk, pushing "
            "the shadows further back, and one single paper file lies out "
            "OPEN on the desk instead of filed away. Change nothing else. "
            "No cat appears."
        ),
    ),
]


def main() -> None:
    dry = "--dry-run" in sys.argv
    key = None if dry else load_key()
    total = len(JOBS) + len(EDIT_JOBS)
    print(f"{total} images (~${0.19 * total:.2f})" + ("  [DRY RUN]" if dry else ""))
    failures = []
    for job in JOBS:
        print(f"\n  {job['id']} ({job['ratio']})")
        if dry:
            print("    " + job["prompt"][:110] + "...")
            continue
        try:
            images = generate(
                f"{STRICT_STYLE}\n\n{job['prompt']}",
                RATIO_TO_SIZE[job["ratio"]], "high", 1, key, "gpt-image-2",
            )
            target = next_free_path(job["id"])
            target.write_bytes(images[0])
            print(f"    -> {target}")
        except Exception as error:
            print(f"    FAILED: {error}")
            failures.append(job["id"])
        time.sleep(2)
    for job in EDIT_JOBS:
        print(f"\n  {job['id']} (edit of {job['ref'].name})")
        if dry:
            print("    " + job["prompt"][:110] + "...")
            continue
        try:
            images = edit(
                f"{STRICT_STYLE}\n\n{job['prompt']}",
                [job["ref"]], RATIO_TO_SIZE[job["ratio"]], "high", 1, key,
                "gpt-image-2",
            )
            target = next_free_path(job["id"])
            target.write_bytes(images[0])
            print(f"    -> {target}")
        except Exception as error:
            print(f"    FAILED: {error}")
            failures.append(job["id"])
        time.sleep(2)
    if failures:
        print("\nfailed: " + ", ".join(failures))
        sys.exit(1)
    if not dry:
        print("\nNow READ every one of them before wiring (law 1 / art rule 8).")


if __name__ == "__main__":
    main()
