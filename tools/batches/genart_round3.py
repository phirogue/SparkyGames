"""Round 3: owner corrections of 2026-08-03.

  * Prologue canon -- Ash has NO neckerchief until sc_collar, the last beat
    before the title. Three scenes had it wrongly added.
  * Skill cards move to plain parchment (enemies keep scene vignettes).
  * bg_parlor_cold grew a witch who looks nothing like ref_elspeth; the room
    should be EMPTY.
  * The settings screen needs its individual elements to actually exist --
    mock_settings is a picture of a screen, not usable art.

Every job that contains a character uses --ref against a canonical reference
so the character cannot drift (CLAUDE.md art rule 4).

Run:  python tools/genart_round3.py [--dry-run]
"""

import sys
from pathlib import Path

# Moved into tools/batches/ 2026-08-06; genart.py is one level up.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import time
from pathlib import Path

from genart import RATIO_TO_SIZE, edit, generate, load_key, next_free_path

REPO = Path(__file__).resolve().parent.parent
PROC = REPO / "assets" / "incoming" / "procedural"
REF_ASH = REPO / "assets" / "library" / "characters" / "ref_ash.png"
REF_ASH_PRO = PROC / "ref_ash_prologue.png"

# Repeated verbatim wherever Ash appears -- loose descriptions let him drift.
ASH = (
    "a LEAN, ANGULAR, SHORT-HAIRED black cat with a narrow wedge-shaped head, "
    "slim build, and glowing amber-orange slit eyes"
)
PARCHMENT = (
    "The subject sits alone on PLAIN AGED PARCHMENT with nothing behind it -- "
    "no room, no street, no landscape, no scenery of any kind. Bare paper "
    "fills the rest of the frame. A soft ink-and-wash shadow under the subject "
    "is fine; a background is not."
)

# --- step 1: build the no-neckerchief Ash reference from the canonical one ---
REF_JOB = dict(
    id="ref_ash_prologue",
    ratio="3:4",
    refs=[str(REF_ASH)],
    prompt=(
        "Reproduce this exact cat portrait with ONE change: REMOVE the red "
        "neckerchief entirely so the cat's throat and chest are bare black fur. "
        "Everything else identical -- same cat, same lean short-haired build, "
        "same wedge head, same amber-orange eyes, same upright pose, same "
        "ink-and-watercolour style, same pale background. No collar, no scarf, "
        "no ribbon, nothing at the neck."
    ),
)

# --- prologue scenes: Ash BEFORE he takes the neckerchief ---
SCENE_JOBS = [
    dict(
        id="sc_vole_stalk",
        ratio="3:4",
        prompt=(
            f"This cat is Ash: {ASH}. He has NO neckerchief, NO collar, NO "
            "scarf and NO ribbon -- his throat is bare black fur. Scene: Ash "
            "pressed low against rooftop tiles at dusk, pupils wide, "
            "hindquarters raised in the pre-pounce wiggle, stalking a small "
            "unaware vole near a chimney pot a short distance away. Warm last "
            "light, sky a single loose wash."
        ),
    ),
    dict(
        id="sc_over_the_fences",
        ratio="3:4",
        prompt=(
            f"This cat is Ash: {ASH}. He has NO neckerchief, NO collar, NO "
            "scarf and NO ribbon -- his throat is bare black fur. Scene: Ash in "
            "full sprint leaping between fence tops and garden walls at night, "
            "rooftops and one dark window ahead, urgency and grace. One warm "
            "amber lamp against the blue-grey night; let the fog be bare paper."
        ),
    ),
    dict(
        id="sc_ash_vole_gift",
        ratio="3:4",
        prompt=(
            f"This cat is Ash: {ASH}. He has NO neckerchief, NO collar, NO "
            "scarf and NO ribbon -- his throat is bare black fur. Scene: Ash "
            "trotting proudly along a rooftop ridge at dusk carrying a small "
            "vole in his mouth, tail high, very pleased with himself. Warm "
            "amber dusk against blue-grey rooftops."
        ),
    ),
]

# --- skill cards: plain parchment, Ash WITH his neckerchief (post-prologue) ---
SKILL_JOBS = [
    ("sk_pounce", "leaping through the air with claws out, dynamic pose"),
    ("sk_swat", "sitting calm and composed while one front paw strikes out in a blur of motion"),
    ("sk_slink", "melting into a pool of his own shadow, only his orange eyes and red neckerchief clearly visible in the dark shape"),
    ("sk_purr", "curled in a neat sleeping circle with gentle silver threads of light rising from his fur, warm and peaceful"),
    ("sk_loaf", "in a perfect bread-loaf pose with all paws tucked under his body, eyes half closed, serene and immovable"),
    ("sk_shelf_justice", "pushing a porcelain jug off an edge with one paw while looking directly at the viewer, the jug falling"),
    ("sk_scratch", "one paw swiping quickly, with three thin ink slash marks in the air beside it"),
]

# --- settings screen: the pieces mock_settings only depicts ---
UI_JOBS = [
    dict(
        id="ui_settings_row",
        prompt=(
            "A single horizontal settings row plaque: a torn-edged strip of "
            "aged parchment with a fine dark-brown stitched border running "
            "around it and a small sprig of ink leaves in each corner, empty in "
            "the middle with nothing written on it. Hand-drawn storybook ink "
            "and watercolour. No text, no icons, no toggle."
        ),
    ),
    dict(
        id="ui_toggle_on",
        prompt=(
            "A small toggle switch drawn as a sewn fabric pill: a rounded "
            "MOSS-GREEN felt track with a dashed stitch line around it, and a "
            "cream bone button sewn with a dark cross-stitch sitting at the "
            "RIGHT end of the track. Hand-drawn storybook ink and watercolour. "
            "No text."
        ),
    ),
    dict(
        id="ui_toggle_off",
        prompt=(
            "A small toggle switch drawn as a sewn fabric pill: a rounded "
            "muted GREY-VIOLET felt track with a dashed stitch line around it, "
            "and a cream bone button sewn with a dark cross-stitch sitting at "
            "the LEFT end of the track. Hand-drawn storybook ink and "
            "watercolour. No text."
        ),
    ),
    dict(
        id="ui_icon_sound",
        prompt=(
            "A small brass hand-bell icon tilted as if ringing, with two tiny "
            "ink motion ticks beside it, hand-drawn storybook ink and "
            "watercolour, warm brass and walnut ink, simple and readable at 48 "
            "pixels. No text."
        ),
    ),
    dict(
        id="ui_icon_music",
        prompt=(
            "A small icon of a single beamed pair of music notes in dark "
            "walnut ink with a soft blue-grey wash, two tiny ink stars beside "
            "them, hand-drawn storybook ink and watercolour, simple and "
            "readable at 48 pixels. No text."
        ),
    ),
    dict(
        id="ui_icon_brightness",
        prompt=(
            "A small icon of a lit candle in a shallow tin dish, warm amber "
            "flame with three short ink rays around it, hand-drawn storybook "
            "ink and watercolour, simple and readable at 48 pixels. No text."
        ),
    ),
    dict(
        id="ui_icon_language",
        prompt=(
            "A small icon of a sealed cream envelope seen face-on with a round "
            "red wax seal in the centre, hand-drawn storybook ink and "
            "watercolour, simple and readable at 48 pixels. No text."
        ),
    ),
]


def run(label, fn, asset_id):
    print(f"{label} generating...", flush=True)
    try:
        blobs = fn()
    except SystemExit as exc:
        print(f"    FAILED: {exc}", flush=True)
        return None
    path = next_free_path(asset_id)
    path.write_bytes(blobs[0])
    print(f"    wrote {path.name} ({len(blobs[0]) // 1024} KB)", flush=True)
    time.sleep(1)
    return path


def main() -> None:
    dry = "--dry-run" in sys.argv
    jobs_total = 2 + len(SCENE_JOBS) + len(SKILL_JOBS) + len(UI_JOBS)
    if dry:
        print(f"{jobs_total} jobs: 1 ref, {len(SCENE_JOBS)} prologue scenes, "
              f"{len(SKILL_JOBS)} skills, {len(UI_JOBS)} settings UI")
        return
    key = load_key()
    n = 0

    # 1. the no-neckerchief Ash reference, edited from the canonical anchor
    n += 1
    ref_path = run(
        f"[{n}/{jobs_total}] ref_ash_prologue (from ref_ash)",
        lambda: edit(REF_JOB["prompt"], REF_JOB["refs"], RATIO_TO_SIZE["3:4"],
                     "high", 1, key, "gpt-image-2"),
        "ref_ash_prologue",
    )
    if ref_path is None:
        sys.exit("cannot continue: the prologue Ash reference failed")

    # 2. prologue scenes, generated FROM that reference
    for job in SCENE_JOBS:
        n += 1
        prompt = f"{STRICT_STYLE}\n\n{job['prompt']}"
        run(f"[{n}/{jobs_total}] {job['id']} (ref: ash-prologue)",
            lambda p=prompt: edit(p, [str(ref_path)], RATIO_TO_SIZE["3:4"],
                                  "high", 1, key, "gpt-image-2"),
            job["id"])

    # 3. skill cards on plain parchment, from the canonical Ash
    for sid, action in SKILL_JOBS:
        n += 1
        prompt = (
            f"{STRICT_STYLE}\n\nThis cat is Ash: {ASH}, wearing a frayed RED "
            f"NECKERCHIEF that reads clearly as tied cloth. Ash is {action}. "
            f"{PARCHMENT}"
        )
        run(f"[{n}/{jobs_total}] {sid} (parchment, ref: ash)",
            lambda p=prompt: edit(p, [str(REF_ASH)], RATIO_TO_SIZE["1:1"],
                                  "high", 1, key, "gpt-image-2"),
            sid)

    # 4. the cold parlor, EDITED from the warm one so it is provably the same
    # room. Generating it fresh is what produced a witch who looks nothing like
    # ref_elspeth. This is the bg_needle_lane -> _wrong recipe: same drawing,
    # warmth withdrawn.
    warm = PROC / "bg_parlor_warm.png"
    if warm.exists():
        n += 1
        cold_prompt = (
            "Reproduce this exact room from the exact same viewpoint, with only "
            "the LIGHT changed: the iron stove is COLD and dark, the lamp is "
            "out, and thin blue moonlight through the window is the only light. "
            "Every thin thread and line hanging on the walls has been CUT and "
            "dangles loose like torn hems. Same furniture, same layout, same "
            "composition, same ink-and-watercolour medium -- only the light and "
            "the cut threads change. CRITICAL: the room is COMPLETELY EMPTY -- "
            "no people, no witch, no old woman, no figures, no cat, nobody at "
            "all. Keep the darks transparent washes with paper showing through, "
            "never solid black."
        )
        run(f"[{n}/{jobs_total}] bg_parlor_cold (edit of warm parlor)",
            lambda: edit(cold_prompt, [str(warm)], RATIO_TO_SIZE["3:4"],
                         "high", 1, key, "gpt-image-2"),
            "bg_parlor_cold")
    else:
        print("SKIP bg_parlor_cold -- bg_parlor_warm.png not in procedural/")

    # 5. settings UI, transparent so it needs no rembg pass
    for job in UI_JOBS:
        n += 1
        run(f"[{n}/{jobs_total}] {job['id']} (transparent)",
            lambda j=job: generate(j["prompt"], RATIO_TO_SIZE["1:1"], "high",
                                   1, key, "gpt-image-2", background="transparent"),
            job["id"])

    print("\nround 3 complete")


if __name__ == "__main__":
    main()
