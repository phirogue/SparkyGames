"""The story catalog: every scene in the game, what happens in it, who is
there, where, and when.

    python tools/story_catalog.py table            # the whole thing, as markdown
    python tools/story_catalog.py show quest.the_wake.5
    python tools/story_catalog.py query --character bodkin
    python tools/story_catalog.py query --time day --source quest
    python tools/story_catalog.py cast             # who appears, how often, with what art
    python tools/story_catalog.py check            # consistency; exit 1 on failure
    python tools/story_catalog.py build            # refill derived fields, rewrite doc

Scenes are named `<source>.<n>`:
    prologue.00 .. prologue.33      the prologue, in the order StoryLoader reads it
    interlude.<set>.<n>             the Hollow Court page-sets and the mantel coach
    quest.<quest_id>.<n>            a step of a quest in game/data/quests.json

HAND-WRITTEN (in docs/design/story-catalog.json): synopsis, characters,
story_time, notes. Everything else is DERIVED from the game data by `build`
and must not be hand-edited -- if a quest gains a step, the catalog gains a
row the next time anyone runs it.

The distinction that matters here: `environment` is the MECHANICAL backdrop a
scene is played on (it carries the rules -- fog discounts Shadow, sunbeams
return cards). `story_time` is when the scene actually happens in the prose.
They are allowed to differ, and they do: `the_fish_giver` is a daytime quest
played entirely on the dusk rooftop. Recording both is the only way to notice.
"""

import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CATALOG = REPO / "docs" / "design" / "story-catalog.json"
ART_CATALOG = REPO / "assets" / "art-catalog.json"
STORY = REPO / "game" / "story"
DATA = REPO / "game" / "data"
DOC = REPO / "docs" / "design" / "story-catalog.md"

NARRATIVE = {"story", "flashback", "notice", "title"}

# How far apart two clock readings are, for the "is this art in the right
# scene" check. Adjacent readings are a judgement call; opposite ones are a bug.
CLOCK = {"dawn": 0, "day": 1, "dusk": 2, "night": 3}


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_catalog():
    return load(CATALOG)


def save_catalog(cat):
    CATALOG.write_text(
        json.dumps(cat, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


# --------------------------------------------------------------------------
# derive: walk the game's own story data
# --------------------------------------------------------------------------


def branch_of(step: dict) -> str:
    """The condition under which a player actually sees this scene."""
    if "when_outcome" in step:
        return f"outcome={step['when_outcome']}"
    if "when_attempt" in step:
        return f"attempt={step['when_attempt']}"
    if "when_flag" in step:
        f = step["when_flag"]
        if isinstance(f, dict):
            return f"{f.get('flag')}={f.get('value')}"
        return str(f)
    if "when_fact" in step:
        # Durable facts (ProwlScript): one clause or a list, all must hold.
        gate = step["when_fact"]
        parts = []
        for clause in gate if isinstance(gate, list) else [gate]:
            op = "=" if "is" in clause else "!="
            parts.append(f"{clause.get('fact')}{op}{clause.get('is', clause.get('not'))}")
        return " & ".join(parts)
    return ""


def derive_one(step, scene_id, source, order) -> dict:
    if isinstance(step, str):  # interlude plain page
        return {
            "id": scene_id, "source": source, "order": order, "type": "page",
            "environment": None, "art": None, "branch": "", "choices": [],
            "grants": [], "encounter": None, "lesson": None, "minigame": None,
            "lines": 1,
        }
    notes = step.get("notes") or []
    # Mechanical steps describe themselves; only prose needs writing up.
    auto = ""
    if step.get("type") == "battle":
        auto = f"Fight: {step.get('encounter')}"
    elif step.get("type") == "lesson":
        auto = f"Teaches: {step.get('lesson')}"
    elif step.get("type") == "minigame":
        auto = f"Minigame: {step.get('id')}"
    elif step.get("type") == "hollow_court_if_died":
        auto = "If he died in the fight above, the Hollow Court interlude runs here"
    return {
        "auto_synopsis": auto,
        "id": scene_id,
        "source": source,
        "order": order,
        "type": step.get("type", "story"),
        "environment": step.get("environment"),
        "art": step.get("portrait"),
        "branch": branch_of(step),
        "choices": step.get("choices", []) or [],
        "grants": (step.get("grant") or [])
        + ([step["add_card"]] if step.get("add_card") else []),
        "encounter": step.get("encounter"),
        "lesson": step.get("lesson"),
        "minigame": step.get("id") if step.get("type") == "minigame" else None,
        "lines": len(step.get("lines") or []) + len(notes),
    }


def derive_all() -> dict:
    """scene_id -> derived record, for every scene the game can show."""
    out = {}

    index = load(STORY / "prologue" / "index.json")
    n = 0
    for fname in index.get("arcs", []):
        path = STORY / "prologue" / fname
        if not path.exists():
            continue
        doc = load(path)
        arc = fname.replace(".json", "")
        for step in doc.get("scenes", []):
            sid = f"prologue.{n:02d}"
            rec = derive_one(step, sid, "prologue", n)
            rec["arc"] = arc
            rec["arc_title"] = doc.get("_arc", "")
            out[sid] = rec
            n += 1

    inter = load(STORY / "prologue" / "interludes.json")
    for key, pages in inter.items():
        if key.startswith("_") or not isinstance(pages, list):
            continue
        for i, step in enumerate(pages):
            sid = f"interlude.{key}.{i}"
            rec = derive_one(step, sid, "interlude", i)
            rec["arc"] = key
            rec["arc_title"] = key.replace("_", " ")
            out[sid] = rec

    quests = load(DATA / "quests.json")
    for qid, q in quests.items():
        if qid.startswith("_"):
            continue
        for i, step in enumerate(q.get("steps", [])):
            sid = f"quest.{qid}.{i}"
            rec = derive_one(step, sid, "quest", i)
            rec["arc"] = qid
            rec["arc_title"] = q.get("name", qid)
            rec["district"] = q.get("district", "")
            rec["quest_kind"] = q.get("kind", "")
            out[sid] = rec

    return out


# --------------------------------------------------------------------------
# build
# --------------------------------------------------------------------------


def cmd_build(args) -> int:
    cat = load_catalog()
    authored = cat["scenes"]
    derived = derive_all()

    # Only prose needs writing up. Battles, lessons and minigames describe
    # themselves from their own ids, so they never get an authored row --
    # otherwise the file fills with 54 blanks nobody will ever fill in.
    added, dropped = [], []
    for sid, rec in derived.items():
        if rec.get("auto_synopsis"):
            continue
        if sid not in authored:
            authored[sid] = {
                "synopsis": "", "characters": [], "story_time": "", "notes": None
            }
            added.append(sid)
    for sid in list(authored):
        if sid not in derived:
            dropped.append(sid)
            authored.pop(sid)

    cat["scenes"] = {
        sid: authored[sid] for sid in derived if sid in authored
    }
    save_catalog(cat)
    recs, cat = full_records()
    write_doc(cat, recs)

    print(f"catalog: {len(derived)} scenes")
    if added:
        print(f"  NEW, need writing up: {', '.join(added)}")
    if dropped:
        print(f"  gone from the game, dropped: {', '.join(dropped)}")
    print(f"doc: {DOC.relative_to(REPO).as_posix()}")
    return 0


def full_records() -> dict:
    cat = load_catalog()
    derived = derive_all()
    out = {}
    for sid, rec in derived.items():
        merged = {**cat["scenes"].get(sid, {}), **rec}
        # A mechanical step's derived one-liner stands in for a synopsis.
        if not merged.get("synopsis") and merged.get("auto_synopsis"):
            merged["synopsis"] = merged["auto_synopsis"]
        out[sid] = merged
    return out, cat


# --------------------------------------------------------------------------
# checks
# --------------------------------------------------------------------------


def cmd_check(args) -> int:
    recs, cat = full_records()
    art = load(ART_CATALOG) if ART_CATALOG.exists() else {"assets": [], "places": {}}
    art_by_id = {a["id"]: a for a in art.get("assets", [])}
    places = art.get("places", {})
    cast = cat.get("characters", {})
    problems = []

    def fail(kind, msg):
        problems.append((kind, msg))

    # 1. every narrative scene is written up.
    for sid, r in sorted(recs.items()):
        if r["type"] not in NARRATIVE and r["type"] != "page":
            continue
        if not r.get("synopsis"):
            fail("unwritten", f"{sid}: no synopsis")
        elif r["type"] in ("story", "flashback", "page") and not r.get("story_time"):
            fail("unwritten", f"{sid}: no story_time")

    # 2. vocabulary.
    for sid, r in sorted(recs.items()):
        for c in r.get("characters", []) or []:
            if c not in cast:
                fail("vocab", f"{sid}: unknown character '{c}'")

    # 2b. the two catalogs must name people the same way. They drifted once
    #     already -- the art called her `shift_boss`, the story calls her
    #     `merrow` -- and the only symptom was a character who appeared to
    #     have no reference art at all.
    art_cast = set(art.get("characters", {}))
    for c in sorted(art_cast - set(cast)):
        fail("vocab", f"'{c}' is in the art catalog's cast but not the story's")

    # 3. the art shown must match WHEN the scene happens, not merely the
    #    backdrop it is played on. This is the check the art catalog cannot
    #    make on its own -- it only knows the environment.
    for sid, r in sorted(recs.items()):
        a = art_by_id.get(r.get("art") or "")
        if not a:
            continue
        art_time, scene_time = a.get("time_of_day"), r.get("story_time")
        if art_time in (None, "none", "timeless") or scene_time in (
            None, "", "timeless", "unknown",
        ):
            continue
        if art_time == scene_time:
            continue
        gap = abs(CLOCK.get(art_time, 0) - CLOCK.get(scene_time, 0))
        if gap >= 2:
            fail(
                "art-time",
                f"{sid}: scene happens at {scene_time}, but its art "
                f"({a['id']}) is {art_time}",
            )

    # 4. the mechanical backdrop is allowed to disagree with the prose, but a
    #    scene written as daylight on a night-only environment is worth saying
    #    out loud -- it is how sc_shambles_day got shipped.
    daylit = []
    for sid, r in sorted(recs.items()):
        env = places.get(r.get("environment") or "")
        if not env or not r.get("story_time"):
            continue
        env_time = env.get("time_of_day")
        if env_time in (None, "timeless"):
            continue
        if r["story_time"] in ("day", "dawn") and env_time == "night":
            daylit.append(f"{sid} ({r['story_time']} on {r['environment']})")

    # 5. art rule 4: anybody who appears more than once needs a reference
    #    image before their second appearance, or they drift.
    appearances = {}
    for sid, r in recs.items():
        for c in r.get("characters", []) or []:
            appearances.setdefault(c, []).append(sid)
    art_chars = set()
    for a in art.get("assets", []):
        for c in a.get("characters", []) or []:
            art_chars.add(c)
    for c, where in sorted(appearances.items()):
        spec = cast.get(c, {})
        if spec.get("no_art_needed"):
            continue
        if len(where) > 1 and c not in art_chars:
            fail(
                "no-reference",
                f"{c}: speaks in {len(where)} scenes and has no image anywhere "
                f"in assets/library (art rule 4). First: {where[0]}",
            )

    titles = {
        "unwritten": "Scenes not written up",
        "vocab": "Vocabulary",
        "art-time": "Art shown at the wrong hour",
        "no-reference": "Recurring characters with no reference art",
    }
    by_kind = {}
    for kind, msg in problems:
        by_kind.setdefault(kind, []).append(msg)
    for kind in ("unwritten", "vocab", "art-time", "no-reference"):
        msgs = by_kind.get(kind)
        if not msgs:
            continue
        print(f"\n{titles[kind]}  ({len(msgs)})")
        for m in msgs:
            print(f"  FAIL  {m}")

    if daylit:
        print(f"\nDaylight prose on a night backdrop  ({len(daylit)})")
        for d in daylit:
            print(f"  note  {d}")

    if problems:
        print(f"\n{len(problems)} problem(s).")
        return 1
    print("\nAll checks pass.")
    return 0


# --------------------------------------------------------------------------
# query / show / cast / table
# --------------------------------------------------------------------------


def cmd_query(args) -> int:
    recs, _ = full_records()
    hits = []
    for sid, r in recs.items():
        if args.character and args.character not in (r.get("characters") or []):
            continue
        if args.time and r.get("story_time") != args.time:
            continue
        if args.source and r.get("source") != args.source:
            continue
        if args.arc and r.get("arc") != args.arc:
            continue
        if args.type and r.get("type") != args.type:
            continue
        if args.environment and r.get("environment") != args.environment:
            continue
        if args.art and r.get("art") != args.art:
            continue
        if args.branching and not r.get("choices"):
            continue
        if args.text:
            hay = " ".join(
                str(r.get(k) or "") for k in ("id", "synopsis", "notes", "arc_title")
            ).lower()
            if args.text.lower() not in hay:
                continue
        hits.append(r)

    for r in hits:
        who = ",".join(r.get("characters") or []) or "-"
        print(
            f"{r['id']:<34} {r['type']:<9} {str(r.get('story_time') or '-'):<8} "
            f"{str(r.get('environment') or '-'):<18} {who:<26} "
            f"{(r.get('synopsis') or '')[:60]}"
        )
    print(f"\n{len(hits)} of {len(recs)}")
    return 0


def cmd_show(args) -> int:
    recs, _ = full_records()
    r = recs.get(args.id)
    if not r:
        print(f"no such scene: {args.id}", file=sys.stderr)
        return 1
    order = [
        "id", "source", "arc", "arc_title", "district", "quest_kind", "order",
        "type", "synopsis", "story_time", "environment", "characters", "art",
        "branch", "choices", "grants", "encounter", "lesson", "minigame",
        "lines", "notes",
    ]
    for k in order:
        if k not in r:
            continue
        v = r[k]
        if isinstance(v, list):
            v = ", ".join(str(x) for x in v) or "-"
        print(f"{k:>12}  {v if v not in (None, '') else '-'}")
    return 0


def cmd_cast(args) -> int:
    recs, cat = full_records()
    art = load(ART_CATALOG) if ART_CATALOG.exists() else {"assets": []}
    art_of = {}
    for a in art.get("assets", []):
        for c in a.get("characters", []) or []:
            art_of.setdefault(c, []).append(a["id"])

    appearances = {}
    for sid, r in recs.items():
        for c in r.get("characters") or []:
            appearances.setdefault(c, []).append(sid)

    rows = sorted(appearances.items(), key=lambda kv: -len(kv[1]))
    print(f"{'character':<22} {'scenes':>6}  {'images':>6}  art")
    for c, where in rows:
        images = art_of.get(c, [])
        flag = "" if images else "   <-- no art anywhere"
        print(
            f"{c:<22} {len(where):>6}  {len(images):>6}  "
            f"{', '.join(images[:3])}{'...' if len(images) > 3 else ''}{flag}"
        )
    print(f"\n{len(rows)} speaking/appearing characters")
    return 0


def write_doc(cat, recs) -> None:
    cols = [
        ("id", "Scene"),
        ("type", "Type"),
        ("synopsis", "What happens"),
        ("characters", "Who"),
        ("environment", "Where (backdrop)"),
        ("story_time", "When"),
        ("art", "Art"),
        ("branch", "Shown when"),
    ]
    out = [
        "<!-- GENERATED by tools/story_catalog.py build -- do not edit. -->",
        "# Story catalog",
        "",
        "Every scene the game can show, in order, with what happens in it, who",
        "is in it, where it is played and when it happens. Source of truth is",
        "[`story-catalog.json`](story-catalog.json) (synopsis, cast, time) plus",
        "the game's own story data (everything else, re-derived on every build).",
        "",
        "**`Where` is the mechanical backdrop, `When` is the prose.** They are",
        "allowed to differ — `the_fish_giver` is a daytime quest played on the",
        "dusk rooftop — and recording both is the only way to notice when the",
        "difference is a mistake instead of a choice.",
        "",
        "```powershell",
        "python tools/story_catalog.py query --character bodkin",
        "python tools/story_catalog.py query --time day",
        "python tools/story_catalog.py cast      # who appears, and who has no art",
        "python tools/story_catalog.py check     # art shown at the wrong hour, etc.",
        "```",
        "",
    ]

    groups = {}
    for r in recs.values():
        groups.setdefault((r["source"], r["arc"], r.get("arc_title", "")), []).append(r)

    order = {"prologue": 0, "interlude": 1, "quest": 2}
    for (source, arc, title), rows in sorted(
        groups.items(), key=lambda kv: (order.get(kv[0][0], 9), kv[0][1])
    ):
        rows.sort(key=lambda r: r["order"])
        head = f"## {title or arc}"
        extra = []
        if source == "quest":
            r0 = rows[0]
            extra.append(f"`{arc}`")
            if r0.get("quest_kind"):
                extra.append(r0["quest_kind"])
            if r0.get("district"):
                extra.append(r0["district"])
        elif source == "prologue":
            extra.append(f"`{arc}`")
        else:
            extra.append(f"interlude `{arc}`")
        out += [f"{head} — {' · '.join(extra)}", ""]
        out.append("| " + " | ".join(c[1] for c in cols) + " |")
        out.append("|" + "|".join("---" for _ in cols) + "|")
        for r in rows:
            cells = []
            for key, _ in cols:
                v = r.get(key)
                if isinstance(v, list):
                    v = ", ".join(str(x) for x in v) or "—"
                cells.append(str(v if v not in (None, "") else "—").replace("|", "/"))
            out.append("| " + " | ".join(cells) + " |")
        out.append("")

    DOC.write_text("\n".join(out), encoding="utf-8")


def cmd_table(args) -> int:
    recs, cat = full_records()
    write_doc(cat, recs)
    print(DOC.read_text(encoding="utf-8"))
    return 0


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass

    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("build")
    sub.add_parser("check")
    sub.add_parser("table")
    sub.add_parser("cast")

    q = sub.add_parser("query")
    q.add_argument("--character")
    q.add_argument("--time")
    q.add_argument("--source", choices=["prologue", "interlude", "quest"])
    q.add_argument("--arc")
    q.add_argument("--type")
    q.add_argument("--environment")
    q.add_argument("--art")
    q.add_argument("--text")
    q.add_argument("--branching", action="store_true",
                   help="only scenes that offer the player a choice")

    s = sub.add_parser("show")
    s.add_argument("id")

    args = p.parse_args()
    return {
        "build": cmd_build, "check": cmd_check, "table": cmd_table,
        "cast": cmd_cast, "query": cmd_query, "show": cmd_show,
    }[args.cmd](args)


if __name__ == "__main__":
    raise SystemExit(main())
