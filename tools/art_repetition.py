"""Is the same picture on screen for too long in a row?

    python tools/art_repetition.py           # check everything, exit 1 on a run
    python tools/art_repetition.py --list    # just show the runs

Owner rule 2026-08-05: **no illustration may carry more than 3 consecutive
story beats.** Needle Lane sat behind five pages in a row and the prologue
stopped feeling like a walk through a city — it felt like one photograph with
different captions under it. Three is the ceiling; two is better.

What counts as a beat: any page the player taps through that shows an
illustration. A page with no portrait of its own inherits its environment's
backdrop, so a run of pages set in the same place with no portraits IS a run
of the same image — which is exactly the case that got missed by eye.

Reads the same content the game does:
  game/story/prologue/      every arc, assembled (plus the Hollow Court blocks)
  game/data/quests.json     each quest's steps[]
  game/data/environments.json  for the fallback image per environment
"""

import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DATA = REPO / "game" / "data"
LIMIT = 3


def load(path: Path) -> dict:
    raw = json.loads(path.read_text(encoding="utf-8"))
    return {k: v for k, v in raw.items() if not k.startswith("_")}


def env_images() -> dict:
    return {k: v.get("image", "") for k, v in load(DATA / "environments.json").items()}


def image_of(beat: dict, environments: dict, carried: str) -> str:
    """What picture is on screen for this beat. A story page with no portrait
    shows its environment's backdrop; a beat that names no environment at all
    keeps whatever was last on screen."""
    if beat.get("portrait"):
        return str(beat["portrait"])
    environment = str(beat.get("environment", ""))
    if environment:
        return environments.get(environment, "") or f"<{environment}>"
    return carried


def load_prologue() -> dict:
    """The prologue, assembled from story/prologue/ the way the game does.

    Mirrors game/services/story_loader.gd: read index.json, concatenate the
    arcs it names in order, merge the interludes on top. A run of one image
    that spans an arc boundary still counts as one run — which is the whole
    point of checking the assembled book rather than each file alone.
    """
    directory = REPO / "game/story/prologue"
    index = json.loads((directory / "index.json").read_text(encoding="utf-8"))
    book = {"scenes": []}
    for arc_file in index.get("arcs", []):
        arc = json.loads((directory / arc_file).read_text(encoding="utf-8"))
        book["scenes"].extend(arc.get("scenes", []))
    interludes_name = index.get("interludes")
    if interludes_name:
        for key, value in json.loads(
                (directory / interludes_name).read_text(encoding="utf-8")).items():
            if not key.startswith("_"):
                book[key] = value
    return book


def gate_of(step: dict):
    for key in ("when_flag", "when_outcome", "when_minigame", "when_attempt",
                "when_fact"):
        if key in step:
            return (key, step[key])
    return None


def exclusive(a: dict, b: dict) -> bool:
    """Can one player ever see BOTH of these steps in one pass? Adjacent
    variants of the same beat (flag branches, is/not fact pairs, first/retry
    twins) are one picture-slot, not a run of pictures — counting them as
    consecutive beats flags runs no player can experience."""
    ga, gb = gate_of(a), gate_of(b)
    if not ga or not gb or ga[0] != gb[0]:
        return False
    key, va, vb = ga[0], ga[1], gb[1]
    if key == "when_flag":
        return (isinstance(va, dict) and isinstance(vb, dict)
                and va.get("flag") == vb.get("flag")
                and va.get("value") != vb.get("value"))
    if key in ("when_outcome", "when_minigame", "when_attempt"):
        return va != vb
    if key == "when_fact":
        fa = va if isinstance(va, dict) else (va[0] if va else {})
        fb = vb if isinstance(vb, dict) else (vb[0] if vb else {})
        if fa.get("fact") != fb.get("fact"):
            return False
        if "is" in fa and "not" in fb and fa["is"] == fb["not"]:
            return True
        if "not" in fa and "is" in fb and fa["not"] == fb["is"]:
            return True
        return "is" in fa and "is" in fb and fa["is"] != fb["is"]
    return False


def collapse_exclusive(scenes: list) -> list:
    """Merge each run of pairwise-exclusive adjacent variants into one slot.
    If every variant shows the same picture the slot counts as one beat of
    it; variants showing different pictures cannot extend any single-image
    run for every player, so the slot breaks the run instead."""
    out, i = [], 0
    while i < len(scenes):
        group = [scenes[i]]
        j = i + 1
        while j < len(scenes) and all(exclusive(s, scenes[j]) for s in group):
            group.append(scenes[j])
            j += 1
        if len(group) == 1:
            out.append(scenes[i])
        else:
            looks = {(str(s.get("portrait", "")), str(s.get("environment", "")))
                     for s in group}
            if len(looks) == 1:
                out.append(group[0])
            else:
                out.append({"type": "__branch_split__"})
        i = j
    return out


def beats_of_story(story: dict, environments: dict) -> list:
    out, carried = [], ""
    for index, scene in enumerate(collapse_exclusive(story.get("scenes", []))):
        if scene.get("type") not in ("story", "flashback"):
            # A fight, a notice or a minigame breaks the run: the player's eye
            # has been somewhere else entirely.
            carried = ""
            out.append((index, None))
            continue
        carried = image_of(scene, environments, carried)
        out.append((index, carried))
    return out


def beats_of_quest(quest: dict, environments: dict) -> list:
    out, carried = [], ""
    for index, step in enumerate(collapse_exclusive(quest.get("steps", []))):
        if step.get("type", "battle") != "story":
            carried = ""
            out.append((index, None))
            continue
        carried = image_of(step, environments, carried)
        out.append((index, carried))
    return out


def runs(beats: list) -> list:
    """Consecutive stretches of the same image, longest first."""
    out, current, start = [], None, 0
    for index, image in beats + [(-1, "<end>")]:
        if image == current:
            continue
        if current and index != start:
            length = sum(1 for i, im in beats if im == current and i >= start)
            out.append((current, start, length))
        current, start = image, index
    # recompute lengths properly: walk once
    out, current, count, start = [], None, 0, 0
    for index, image in beats:
        if image == current and image:
            count += 1
            continue
        if current and count > 0:
            out.append((current, start, count))
        current, count, start = image, (1 if image else 0), index
    if current and count > 0:
        out.append((current, start, count))
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--limit", type=int, default=LIMIT)
    args = parser.parse_args()

    environments = env_images()
    sources = {"prologue": beats_of_story(load_prologue(), environments)}
    for quest_id, quest in load(DATA / "quests.json").items():
        sources[f"quest:{quest_id}"] = beats_of_quest(quest, environments)

    offenders = []
    for where, beats in sources.items():
        for image, start, length in runs(beats):
            if args.list and length > 1:
                print(f"  {where:28s} {image:24s} x{length} (from beat {start})")
            if length > args.limit:
                offenders.append((where, image, start, length))

    if not offenders:
        print(f"No illustration runs longer than {args.limit} beats.")
        return
    print(f"\n{len(offenders)} run(s) over the {args.limit}-beat ceiling:")
    for where, image, start, length in sorted(offenders, key=lambda o: -o[3]):
        print(f"  {where}: '{image}' carries {length} beats in a row "
              f"(from beat {start}) — break it up or draw another view")
    sys.exit(1)


if __name__ == "__main__":
    main()
