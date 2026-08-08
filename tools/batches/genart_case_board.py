"""The six Case Board assets that were named by content and existed nowhere.

    python tools/batches/genart_case_board.py [--dry-run]

Found by `tools/kb_check.py` on its first run (2026-08-06): game/data/case.json
and testimonies.json name six art ids with no file in assets/library,
assets/archive or game/assets. The board rendered them through
UITheme.art_or_placeholder, so the screen was legible but unfinished.
`npc_shift_boss` had never been written down in art-needed.md at all.

CANON THAT MATTERS HERE (from case.json, the-unraveler.md, chapter 01):

- **Wick is guilty of almost everything except the murder.** He bought
  Elspeth's debts to evict her, and stopped paying for the Wickhouse ward two
  years ago. He is charming-awful, never cartoon-evil -- a man you would trust
  with a contract, which is the problem.
- **The Quiet Gentleman is a broker nobody remembers meeting first.** Being
  forgettable IS the character; a striking face would be a lie about him. He
  brokers without asking and is guilty of that, never of murder.
- **Shift-Boss Merrow is a CAT.** testimonies.json says `species: cat`, and
  Catalog rejects a human witness outright -- Ash cannot press humans, only
  animals about humans. A person here would have been a canon defect.

FRAMING (art rule 5 and the /genart table):
- `ev_` evidence: one object on plain cream paper, no environment, 1:1 --
  they read as things pinned to a board. `ev_candle_stub` is the reference.
- `npc_` portraits: 3:4, the character in their own setting with the setting
  dissolving into wash behind them. `npc_clerk` is the reference.

The ledger and the tally carry WRITING as part of the object. STRICT_STYLE
ends in "no text in the image", which is right for art generally and wrong
here, so each asks explicitly for illegible handwriting -- the shape of
writing without words a reader could catch wrong. A doubled word shipped in
the title logo once; unreadable script cannot repeat that.
"""

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from genart import RATIO_TO_SIZE, STRICT_STYLE, generate, load_key, next_free_path

JOBS = [
    # ---------------------------------------------------------- evidence (1:1)
    dict(
        id="ev_ledger",
        ratio="1:1",
        prompt=(
            "A single torn half-page from a guild ledger, lying alone on bare "
            "cream paper with a soft cast shadow. Heavy laid paper, one edge "
            "ripped raggedly across, ruled columns in faded red, rows of "
            "figures and dates written in iron-gall ink in a confident "
            "copperplate hand. THE HANDWRITING MUST BE ILLEGIBLE -- the shape "
            "and rhythm of copperplate script and columns of numerals, with no "
            "readable words or letters anywhere. A thumbprint of candle grease "
            "at one corner. Nothing else in the frame: no desk, no room, no "
            "hands."
        ),
    ),
    dict(
        id="ev_tally",
        ratio="1:1",
        prompt=(
            "A single weathered oak slat the length of a forearm, lying alone "
            "on bare cream paper with a soft cast shadow -- a lamplighters' "
            "shift-tally board. Chalk marks scored across it in groups of "
            "five, some smudged by a thumb, a few scrubbed out and re-marked. "
            "A leather thong through a hole at one end. Grain raised and grey "
            "from weather, one end darkened by handling. Marks and scratches "
            "ONLY -- no letters, no words, no numerals. Nothing else in the "
            "frame: no wall, no hook, no hands."
        ),
    ),
    dict(
        id="ev_seam",
        ratio="1:1",
        prompt=(
            "A single hand's length of dark waxed thread, lying alone and "
            "coiled loosely on bare cream paper with a soft cast shadow. It "
            "has been UNPICKED from a seam: one end still holds three or four "
            "intact stitches in a neat blanket-stitch, and the rest has been "
            "pulled loose into slack crimped loops that remember the shape "
            "they were sewn in. The intact stitches lean the WRONG WAY -- "
            "mirror-handed, as if sewn left-handed by someone copying a "
            "right-handed hand. A faint blue-grey shimmer clings to the "
            "unpicked length, like light caught in cobweb. Nothing else in the "
            "frame: no cloth, no needle, no hands."
        ),
    ),
    # --------------------------------------------------------- portraits (3:4)
    dict(
        id="npc_wick",
        ratio="3:4",
        prompt=(
            "Portrait of Guildmaster Ellery Wick, master of the Chandlers' "
            "Guild: a prosperous gaslamp-era human man in his late fifties, "
            "seen from the waist up behind a broad desk in a warm "
            "candle-maker's counting room. Heavy good coat, silk waistcoat, a "
            "watch chain, well-kept side-whiskers going silver. He is smiling "
            "-- an open, genuinely warm, entirely believable smile, the smile "
            "of a man who has just done you a favour and would like to do you "
            "another. HE MUST NOT LOOK VILLAINOUS: no sneer, no shadowed eyes, "
            "no menace, nothing theatrical. Behind him, dissolving into loose "
            "wash: racks of pale beeswax tapers, a ledger closed on the desk, "
            "a squat iron strongbox. Warm amber candlelight from the left "
            "against blue-grey shadow. One man alone -- no other figures, no "
            "animals."
        ),
    ),
    dict(
        id="npc_gentleman",
        ratio="3:4",
        prompt=(
            "Portrait of a man called only the Quiet Gentleman: a middle-aged "
            "gaslamp-era human of entirely average build, seen from the waist "
            "up, standing patiently in the fog at the mouth of a narrow lane "
            "at night. THE POINT OF HIM IS THAT HE IS FORGETTABLE -- a plain "
            "grey coat of no particular cut, a plain hat, unremarkable "
            "features arranged in a pleasant, mild, unmemorable expression. "
            "Nothing striking, no scar, no distinguishing mark, no "
            "flourish, nothing an eye would catch on. His face is turned "
            "slightly away and half-lost in the fog, so a viewer could not "
            "describe him afterwards. Gloved hands folded. Behind him, "
            "dissolving almost entirely into wash: wet cobbles, a gaslamp's "
            "far halo. Cold blue-grey throughout with one small warm amber "
            "note in the distant lamp. One man alone -- no other figures, no "
            "animals."
        ),
    ),
    dict(
        id="npc_shift_boss",
        ratio="3:4",
        prompt=(
            "Portrait of Shift-Boss Merrow, a CAT -- an ordinary,  "
            "battle-worn working tomcat, not a person and not anthropomorphic. "
            "Broad-headed brindled brown tabby with a torn ear and a "
            "scarred nose, sitting upright and square on a lamplighters' "
            "equipment bench at night, meeting the viewer's eye with the flat "
            "patient stare of somebody who keeps records out of spite and "
            "keeps them honestly. A short length of lamplighter's cord knotted "
            "loosely round his neck as a working badge -- NOT a red "
            "neckerchief. Behind him, dissolving into loose wash: racked "
            "lamplighters' ladders, a row of brass lamp-keys on hooks, a "
            "chalked slat. Warm amber lamplight against blue-grey night. One "
            "cat alone -- no humans, no other animals."
        ),
    ),
]


def main() -> None:
    dry = "--dry-run" in sys.argv
    key = None if dry else load_key()
    print(f"{len(JOBS)} images (~${0.19 * len(JOBS):.2f})"
          + ("  [DRY RUN]" if dry else ""))
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
        time.sleep(2)  # be polite to the API between calls
    if failures:
        print("\nfailed: " + ", ".join(failures))
        sys.exit(1)
    if not dry:
        print("\nNow READ every one of them before wiring (law 1 / art rule 8).")


if __name__ == "__main__":
    main()
