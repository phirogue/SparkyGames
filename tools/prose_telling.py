"""Flag exposition-dump paragraphs in the novel.

House rule (story-bible/04-line-rules.md, D5): the book explains its world in
scenes, not in paragraphs. An exposition dump is a paragraph that stops the
scene to define a thing, recite an institution's charter, or summarise a
character's history, in generalised present tense, with nothing happening.

This is a HEURISTIC. It ranks paragraphs for a human to judge; it does not
decide. A noir narrator earns a good deal of summary, and the real test is the
one the notes give:

    Does a scene elsewhere already do this work?
    If yes, the summary goes. If no, it stays and earns its place.

Usage:
    python tools/prose_telling.py                 # rank everything over threshold
    python tools/prose_telling.py --top 20        # worst 20 only
    python tools/prose_telling.py --min 6.0       # raise the bar
    python tools/prose_telling.py novel/chapters/00_prologue.tex
"""
from __future__ import annotations

import argparse
import glob
import os
import re
import sys

DEFAULT_GLOB = "novel/chapters/*.tex"

# Generalised-present markers: the grammar of explaining rather than showing.
GENERIC = [
    r"\bit means\b", r"\bmeans\b", r"\bunderstand\b", r"\balways\b", r"\bnever\b",
    r"\bevery\b", r"\banyone\b", r"\bnobody\b", r"\banybody\b", r"\bthey are\b",
    r"\bthere are\b", r"\bwhich is\b", r"\bwhich in this\b", r"\bthe rule\b",
    r"\bthe way it works\b", r"\bis called\b", r"\bhave a name\b",
    r"\bin this city\b", r"\bthe city calls\b", r"\bthe kind of\b",
    r"\bthe sort of\b", r"\bfor the record\b", r"\bis a trade\b",
]

# "Rag-wraiths: clothes whose owners are missing." — the definition colon.
DEFCOLON = re.compile(r"[A-Za-z\-\}]+s?: (a|an|the|clothes|people|things|what)\b", re.I)

# Future-telling about the manuscript — a standing prohibition. Ash IS writing
# the record, so "this chapter" and "this book" are his own units and are fine;
# what is banned is narration promising what the book will later do.
FRAME_BREAK = re.compile(
    r"\b(later|the next|the last|the final|the remaining) chapters?\b|"
    r"\bthis book (will|is going to|ends|closes|stands on)\b|"
    r"\bby the end of this (book|account)\b", re.I)

ACTION = [
    r"\bI (went|ran|jumped|sat|stood|took|put|looked|said|asked|climbed|slipped|"
    r"waited|turned|felt|saw|heard|walked|crossed|stopped|got|made|left|found)\b",
    r"\bhe (said|asked|turned|wrote|looked|nodded|stood|took)\b",
    r"\bshe (said|asked|turned|looked|nodded|stood|took)\b",
]


def score(par: str) -> float | None:
    """Generalised-present density minus action density, per 100 words."""
    words = len(par.split())
    if words < 35:
        return None
    if "``" in par or "''" in par:      # dialogue on the page: it is a scene
        return None
    low = par.lower()
    generic = sum(len(re.findall(p, low)) for p in GENERIC)
    generic += 3 * len(DEFCOLON.findall(par))       # definitions weigh heavy
    action = sum(len(re.findall(p, low)) for p in ACTION)
    return round((generic - 1.5 * action) * 100.0 / words, 1)


def paragraphs(path: str):
    """Yield (line_number, text) for prose paragraphs, skipping LaTeX commands."""
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    line = 1
    for block in text.split("\n\n"):
        stripped = block.strip()
        if stripped and not stripped.startswith("\\"):
            yield line, stripped
        line += block.count("\n") + 2


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", help="files to scan (default: all chapters)")
    parser.add_argument("--min", type=float, default=4.0, help="score threshold")
    parser.add_argument("--top", type=int, default=0, help="show only the worst N")
    args = parser.parse_args()

    targets = args.paths or sorted(glob.glob(DEFAULT_GLOB))
    if not targets:
        print(f"no chapters found (looked for {DEFAULT_GLOB})", file=sys.stderr)
        return 2

    rows, frame_breaks = [], []
    for path in targets:
        for line, par in paragraphs(path):
            value = score(par)
            if value is not None and value >= args.min:
                rows.append((value, os.path.basename(path), line, par))
            if FRAME_BREAK.search(par):
                frame_breaks.append((os.path.basename(path), line, FRAME_BREAK.search(par).group(0)))

    rows.sort(reverse=True)
    shown = rows[: args.top] if args.top else rows

    print(f"{len(rows)} paragraphs at or above {args.min}\n")
    for value, name, line, par in shown:
        print(f"--- [{value}] {name}:{line}")
        print(par[:400].replace("\n", " "))
        print()

    if frame_breaks:
        print("FRAME BREAKS (narration referring to the book as a book):")
        for name, line, hit in frame_breaks:
            print(f"  {name}:{line}  — {hit!r}")
        print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
