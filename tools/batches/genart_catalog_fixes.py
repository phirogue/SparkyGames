"""Art the two catalogs proved was wrong or missing (2026-08-12).

    python tools/batches/genart_catalog_fixes.py --list   # spend nothing
    python tools/batches/genart_catalog_fixes.py

Every job here was found mechanically, by `art_catalog.py check` and
`story_catalog.py check`, not by somebody remembering. Nine images, ~$1.71 of
a $3.50 budget.

Library and archive were both checked first (art rules 1 and 2):
  - sc_shambles_day   the archived take is WORSE -- bright noon, blue sky,
                      crowds, no cat at all. No restore available.
  - sc_kettle         the archived take also shows a red band at the throat
                      and a LIT stove, so it fixes neither the collar nor the
                      cold room. No restore available.
  - Hollow Court      three views exist and all three are the same desk at
                      the same angle; the repetition is the defect, so an
                      older take of the same desk cannot help.
  - Bodkin, Tansy,
    the Fish-Giver    do not exist anywhere. Never drawn.

WHY EACH ONE:

A. Wrong picture in a shipped place
   sc_shambles_night  prologue.06 is written for night ('Eight bells from the
                      tower') and ships a broad-daylight market with a
                      white-bibbed tuxedo cat in it who is not Ash. New id;
                      sc_shambles_day stays in the library, unused.
   sc_kettle          prologue.30 is TWO BEATS before sc_collar, and the art
                      has Ash already wearing the kerchief he has not taken.
                      Regenerated from the existing image so the room, the
                      pose and the light survive and only the throat changes
                      (art rule 9: edit, do not re-roll).
   sc_threads_cut     prologue.24 is Ash refusing to go through the door yet
                      -- 'I am a cat who has learned to look at a room before
                      he is in it'. The art already shows the Unpicked
                      standing in that doorway, so it spoils beat 25's reveal
                      one beat early. Same room, empty doorway.

B. Law 16 -- repetition, enforced and currently violated
   sc_hollow_court_desk carries FIVE consecutive pages of hollow_court_refused
   and FOUR of hollow_court_repeat. The cap is three. Each of these three is a
   moment the prose already describes and no image exists for, so they break
   the run AND illustrate a line:
   sc_hollow_court_queue   refused.3 'The queue is ghosts, and the ghosts wave
                           me forward, which I find polite and insulting.'
   sc_hollow_court_thread  refused.4 'He runs my thread through his fingers.
                           There is a knot here that is not one of ours.'
   sc_hollow_court_stamp   refused.0 'The stamp says REFUSED. It is also,
                           somehow, still a paw print.'

C. Art rule 4 -- recurring characters with no reference image
   Words let a character drift; these three have appeared repeatedly with
   nothing to generate them FROM. Each portrait becomes their ref_ file.
   npc_bodkin       4 scenes across creditors and the_ward_that_failed
   npc_tansy        5 scenes across the_milk_debt
   npc_fish_giver   4 scenes across the_fish_giver

NECKERCHIEF DISCIPLINE (art rule 6, CLAUDE.md):
   Anything at or after sc_collar wears it; anything before does not.
   sc_shambles_night, sc_kettle, sc_threads_cut are all PROLOGUE -> generated
   from ref_ash_prologue and the prompt says bare throat explicitly.
   sc_hollow_court_queue is a repeat death, always post-collar -> ref_ash.
"""

import argparse
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
LIB = REPO / "assets" / "library"

REF_ASH = str(LIB / "characters" / "ref_ash.png")
REF_ASH_PRE = str(LIB / "characters" / "ref_ash_prologue.png")
CUR_KETTLE = str(LIB / "scenes" / "sc_kettle.png")
CUR_THREADS = str(LIB / "scenes" / "sc_threads_cut.png")

BARE = (
    "IMPORTANT: this cat wears NOTHING around its neck -- no red neckerchief, "
    "no scarf, no collar, no band, no ribbon. Its throat is bare black fur. "
)

# (asset_id, ratio, [refs], prompt)
BATCH = [
    # ---- A. wrong picture in a shipped place -------------------------------
    (
        "sc_shambles_night", "3:4", [REF_ASH_PRE],
        "Looking down into a sleeping night market from a rooftop above it. "
        "Below: crooked timber shopfronts, market stalls shut under canvas "
        "covers, produce crates left out, a hanging shop sign, one lit "
        "lantern far down the lane, fog pooling between the buildings. "
        "Nobody is out; the market has gone to bed. "
        "This same lean black cat sits on the roof ridge in the near "
        "foreground, seen from behind and slightly to one side, looking down "
        "at the street. " + BARE +
        "Stretched taut between two chimney stacks in the middle distance, a "
        "single thread of silver light, thin as a hair, faintly glowing -- "
        "the only bright thing in the picture besides the one lantern. "
        "Night. Blue-grey and cold, one small amber accent."
    ),
    (
        "sc_kettle", "3:4", [CUR_KETTLE, REF_ASH_PRE],
        "Keep this exact kitchen, this exact camera, this exact pose and this "
        "exact cold moonlit light. Change ONE thing: the cat's neck. "
        + BARE +
        "Remove any red neckerchief, red band or red marking at the throat "
        "entirely and paint plain black fur there. Everything else -- the "
        "black cat up on his hind legs shoving the steaming copper kettle off "
        "the stove with both forepaws, his expression of effort, the shelves, "
        "the window, the moonlight -- stays exactly as it is."
    ),
    (
        "sc_threads_cut", "3:4", [CUR_THREADS, REF_ASH_PRE],
        "Keep this exact room, this exact camera and this exact cold "
        "moonlight. Change ONE thing: the DOORWAY IS EMPTY. Remove the "
        "person-shaped figure of silver thread standing in the doorway "
        "completely -- there is nobody and nothing standing in the door, only "
        "a dark empty hall beyond it. Everything else stays: the wall of "
        "dozens of cut threads hanging down like torn hems all snipped at the "
        "same height, the embroidery hoops, the small black cat seen from "
        "behind in the foreground looking at the open door. " + BARE
    ),

    # ---- B. law 16: break the Hollow Court repetition runs ------------------
    (
        "sc_hollow_court_queue", "3:4", [REF_ASH],
        "A queue of translucent pale grey ghosts standing in line at a small "
        "wooden desk at the bottom of an enormous dark hall of filing "
        "shelves. The ghosts are ordinary city people, indistinct, patient. "
        "They have turned to look down at a small black cat with a frayed red "
        "neckerchief at the back of the queue, and the nearest ones are "
        "gesturing him forward to the front of the line. A grey ghost clerk "
        "waits at the desk under a single green-shaded lamp. "
        "Vast, quiet, administrative. Cold grey-green, one warm lamp."
    ),
    (
        "sc_hollow_court_thread", "3:4", [],
        "Close study of a desk in a dim records office. A translucent grey "
        "ghost clerk in a waistcoat, spectacles pushed down his nose, holds a "
        "length of fine silver thread up and runs it slowly through his "
        "fingers. On the open ledger below, the same thread is laid out flat "
        "along a ruled line, and the ruled line is plainly shorter than the "
        "thread. One small tight knot is visible in the thread. Green-shaded "
        "lamp, inkwell, blotter. His whole attention is on the knot. "
        "No text, no readable writing. Cold, with one warm pool of lamplight."
    ),
    (
        "sc_hollow_court_stamp", "3:4", [],
        "Extreme close view, from low down at desk height: a translucent grey "
        "hand bringing a wooden rubber stamp down hard onto a sheet of paper "
        "on a dark desk. The impression already made on the paper beside it "
        "is a single inked CAT PAW PRINT, dark and slightly smudged. An "
        "ink pad, a scatter of forms, the base of a green-shaded lamp. "
        "No letters, no words, no readable writing anywhere -- the only mark "
        "on the paper is the paw print. Cold grey-green with one warm "
        "lamplight edge."
    ),

    # ---- C. art rule 4: recurring characters with no reference image --------
    (
        "npc_bodkin", "3:4", [],
        "A battered old grey tomcat sitting in a dark doorway on a wet "
        "lamplit street. He has ONE eye -- the other socket is closed and "
        "scarred over -- and the remaining eye is bright and level and "
        "entirely unimpressed. One ear is torn away to half its length. His "
        "whiskers are bent like old wire, his coat is thick and scarred and "
        "the grey of wet slate, and he sits squarely with his chest out like "
        "somebody who has never once left a fight early. Behind him the "
        "street dissolves into blue-grey wash with one warm lantern. "
        "Street-wise, weathered, watchful. No collar, nothing round his neck."
    ),
    (
        "npc_tansy", "3:4", [],
        "A very small ginger tabby kitten, absurdly small, sitting upright on "
        "a stack of old papers on a shelf with her tail wrapped round her "
        "feet. Enormous round eyes, ears slightly too big for her head, one "
        "white sock. Her mouth is a little open and her whole body is blurred "
        "very slightly as if vibrating, because she is purring at a volume "
        "her size does not justify. Delighted and completely without shame. "
        "Warm lamplight against a dim storeroom dissolving into wash. "
        "Nothing round her neck."
    ),
    (
        "npc_fish_giver", "3:4", [],
        "A weathered middle-aged fishmonger in a canvas apron crouched in the "
        "alley behind his shuttered market stall at first light, setting down "
        "a battered tin plate of fish scraps on the cobbles. He is not "
        "looking at the plate; he is looking off to one side with the "
        "patient, slightly embarrassed face of a man doing something he does "
        "every single morning and would rather not be seen doing. Two or "
        "three cats wait at the edge of the frame, dissolving into wash. "
        "Grey dawn light, one warm window. Kind, tired, unremarkable."
    ),
]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true", help="print jobs, spend nothing")
    parser.add_argument("--only", action="append", default=[], metavar="ID")
    args = parser.parse_args()

    jobs = [j for j in BATCH if not args.only or j[0] in args.only]
    if args.list:
        for asset_id, ratio, refs, prompt in jobs:
            print(f"\n=== {asset_id}  [{ratio}]  refs={[Path(r).name for r in refs]}")
            print(prompt)
        print(f"\n{len(jobs)} images, about ${len(jobs) * 0.19:.2f}")
        return

    print(f"generating {len(jobs)} images (about ${len(jobs) * 0.19:.2f})\n")
    for asset_id, ratio, refs, prompt in jobs:
        cmd = [
            sys.executable, str(REPO / "tools" / "genart.py"), asset_id,
            "--ratio", ratio, "--prompt", prompt,
        ]
        for r in refs:
            cmd += ["--ref", r]
        print(f"--- {asset_id}")
        result = subprocess.run(cmd, cwd=REPO)
        if result.returncode != 0:
            print(f"    FAILED: {asset_id}")


if __name__ == "__main__":
    main()
