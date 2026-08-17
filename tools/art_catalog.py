"""The art catalog: what every image IS, so consistency can be checked instead
of remembered.

    python tools/art_catalog.py table          # the lookup table, as markdown
    python tools/art_catalog.py show sc_kettle # one asset, in full, with prompt
    python tools/art_catalog.py query --character ash --time night
    python tools/art_catalog.py check          # canon + coverage checks; exit 1 on fail
    python tools/art_catalog.py build          # refill prompts + usage, rewrite doc

The hand-written part is `assets/art-catalog.json`: for each image, what a
reader SEES in it -- who is in it, indoors or out, what time of day, whether
Ash is wearing the neckerchief. Those fields were filled in by looking at the
images, not by trusting the prompts, because the two disagree often enough to
matter: `sc_over_the_fences` was asked for with a neckerchief and came back
without one.

The derived part is filled by `build` and must never be hand-edited:

  prompt/prompt_source  lifted by AST out of the batch script that generated
                        the image (tools/batches/), or out of the two markdown
                        prompt archives for the pre-scripting assets.
  used_by               every place in game/story and game/data that names the
                        id, with the prologue beat index where there is one.
  wired                 whether a downscaled copy exists in game/assets.

`check` is the point of the whole thing. It answers the questions that used to
need somebody to remember the answer:

  * Is a daytime image being shown in a night scene?  (`sc_shambles_day` was.)
  * Is Ash wearing the neckerchief before he takes it?  (In `sc_kettle` he was.)
  * Does every image the game asks for exist, and does every image we own get
    used by anything?
"""

import argparse
import ast
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CATALOG = REPO / "assets" / "art-catalog.json"
LIB = REPO / "assets" / "library"
GAME_ASSETS = REPO / "game" / "assets"
STORY = REPO / "game" / "story"
DATA = REPO / "game" / "data"
DOC = REPO / "docs" / "design" / "art-catalog.md"

# The beat that changes Ash's canon. Everything before it is bare-necked;
# everything from it onward wears the kerchief (CLAUDE.md art rule 6).
COLLAR_BEAT = "sc_collar"


# --------------------------------------------------------------------------
# loading
# --------------------------------------------------------------------------


def load_catalog() -> dict:
    return json.loads(CATALOG.read_text(encoding="utf-8"))


def save_catalog(cat: dict) -> None:
    CATALOG.write_text(
        json.dumps(cat, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def library_ids() -> dict:
    """id -> path, for every master in the library."""
    return {p.stem: p for p in sorted(LIB.glob("*/*.png"))}


# --------------------------------------------------------------------------
# derived: prompts
# --------------------------------------------------------------------------


def _const(node):
    """Fold a literal / implicit-concat / Name expression to a value."""
    try:
        return ast.literal_eval(node)
    except Exception:
        pass
    if isinstance(node, ast.Name):
        return f"${node.id}"
    if isinstance(node, ast.List):
        return [_const(e) for e in node.elts]
    if isinstance(node, ast.BinOp):
        return f"{_const(node.left)}{_const(node.right)}"
    return None


def scrape_script_prompts() -> dict:
    """id -> (prompt, source). Parsed, never imported -- importing spends money."""
    found = {}
    scripts = sorted(REPO.glob("tools/genart_*.py")) + sorted(
        REPO.glob("tools/batches/genart_*.py")
    )
    for script in scripts:
        rel = script.relative_to(REPO).as_posix()
        tree = ast.parse(script.read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            rec = None
            # dict(id=..., prompt=...) form
            if isinstance(node, ast.Call) and getattr(node.func, "id", "") == "dict":
                kw = {k.arg: _const(k.value) for k in node.keywords}
                if isinstance(kw.get("id"), str) and isinstance(kw.get("prompt"), str):
                    rec = (kw["id"], kw["prompt"])
            # (id, ratio, ref, prompt) positional form
            elif isinstance(node, (ast.Tuple, ast.List)):
                vals = [_const(e) for e in node.elts]
                if (
                    len(vals) in (3, 4)
                    and isinstance(vals[0], str)
                    and isinstance(vals[-1], str)
                    and len(vals[-1]) > 60
                ):
                    rec = (vals[0], vals[-1])
            if rec and not rec[0].startswith("$"):
                found[rec[0]] = (rec[1], rel)  # later script wins = most recent take
    return found


def scrape_doc_prompts() -> dict:
    """The pre-scripting archive: prompts that only ever lived in markdown."""
    found = {}
    docs = [
        REPO / "docs" / "design" / "art-manifest.md",
        REPO / "docs" / "design" / "image-prompts-master.md",
    ]
    # `### \`id\` — ...` followed by a `> quoted prompt`, or `**\`id\`**` then `>`.
    header = re.compile(r"^(?:###\s+|\*\*)`([a-z0-9_]+)`")
    for doc in docs:
        if not doc.exists():
            continue
        rel = doc.relative_to(REPO).as_posix()
        current = None
        buf = []
        for line in doc.read_text(encoding="utf-8").splitlines():
            m = header.match(line.strip())
            if m:
                if current and buf:
                    found.setdefault(current, (" ".join(buf).strip(), rel))
                current, buf = m.group(1), []
                continue
            if current and line.strip().startswith(">"):
                buf.append(line.strip().lstrip("> ").strip())
            elif current and buf and not line.strip():
                found.setdefault(current, (" ".join(buf).strip(), rel))
                current, buf = None, []
        if current and buf:
            found.setdefault(current, (" ".join(buf).strip(), rel))
    return found


# --------------------------------------------------------------------------
# derived: usage
# --------------------------------------------------------------------------


def prologue_beats() -> list:
    """The prologue in order: one row per scene, with its art id if it has one.

    Order is authoritative -- it is what StoryLoader concatenates -- and it is
    the only way to know whether a beat happens before or after the collar.
    """
    index = json.loads((STORY / "prologue" / "index.json").read_text(encoding="utf-8"))
    beats = []
    for entry in index.get("arcs", []):
        fname = entry if isinstance(entry, str) else entry.get("file", "")
        path = STORY / "prologue" / fname
        if not path.exists():
            continue
        doc = json.loads(path.read_text(encoding="utf-8"))
        for scene in doc.get("scenes", []):
            beats.append(
                {
                    "index": len(beats),
                    "arc": fname.replace(".json", ""),
                    "type": scene.get("type"),
                    "environment": scene.get("environment"),
                    "art": scene.get("portrait"),
                }
            )
    return beats


def scan_usage(ids: set) -> dict:
    """id -> list of 'file:key' strings naming every reference to it.

    Content JSON names art in a field, so we can say WHICH field. Scenes and
    scripts name it in code (`sk_` + skill id, UITheme's chrome table), so
    those only get a filename -- but they still count as used. Leaving them
    out made every skill card and every icon look orphaned.
    """
    usage = {i: [] for i in ids}

    def walk(obj, label):
        if isinstance(obj, dict):
            for k, v in obj.items():
                if isinstance(v, str) and v in usage:
                    usage[v].append(f"{label}:{k}")
                walk(v, label)
        elif isinstance(obj, list):
            for v in obj:
                walk(v, label)

    for path in list(DATA.glob("*.json")) + list(STORY.rglob("*.json")):
        walk(
            json.loads(path.read_text(encoding="utf-8")),
            path.relative_to(REPO / "game").as_posix(),
        )

    for path in list((REPO / "game").rglob("*.gd")) + list(
        (REPO / "game").rglob("*.tscn")
    ):
        if "/tests/" in path.as_posix():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        label = path.relative_to(REPO / "game").as_posix()
        for i in ids:
            if i in text:
                usage[i].append(label)

    for i in usage:
        usage[i] = sorted(set(usage[i]))
    return usage


def wired_ids() -> set:
    return {p.stem for p in GAME_ASSETS.rglob("*.png")}


# --------------------------------------------------------------------------
# build
# --------------------------------------------------------------------------


def cmd_build(args) -> int:
    cat = load_catalog()
    assets = cat["assets"]
    by_id = {a["id"]: a for a in assets}

    script_prompts = scrape_script_prompts()
    doc_prompts = scrape_doc_prompts()
    usage = scan_usage(set(by_id))
    beats = prologue_beats()
    wired = wired_ids()

    beat_of = {}
    for b in beats:
        if b["art"]:
            beat_of.setdefault(b["art"], []).append(b["index"])

    filled = 0
    for a in assets:
        i = a["id"]
        prompt = script_prompts.get(i) or doc_prompts.get(i)
        if prompt:
            a["prompt"], a["prompt_source"] = prompt
            filled += 1
        else:
            a.setdefault("prompt", None)
            a.setdefault("prompt_source", None)
        a["used_by"] = usage.get(i, [])
        a["prologue_beats"] = beat_of.get(i, [])
        a["wired"] = i in wired

    save_catalog(cat)
    write_doc(cat)
    print(f"catalog: {len(assets)} assets, {filled} with a recorded prompt")
    print(f"doc: {DOC.relative_to(REPO).as_posix()}")
    return 0


# --------------------------------------------------------------------------
# checks
# --------------------------------------------------------------------------


def cmd_check(args) -> int:
    cat = load_catalog()
    assets = {a["id"]: a for a in cat["assets"]}
    places = cat["places"]
    cast = cat["characters"]
    lib = library_ids()
    beats = prologue_beats()
    problems = []

    def fail(kind, msg):
        problems.append((kind, msg))

    # 1. coverage, both directions.
    for i in sorted(set(lib) - set(assets)):
        fail("coverage", f"{i}: in assets/library but not in the catalog")
    for i in sorted(set(assets) - set(lib)):
        fail("coverage", f"{i}: in the catalog but no file in assets/library")

    # 2. vocabulary -- a typo'd character id makes a query silently wrong.
    for i, a in sorted(assets.items()):
        for c in a.get("characters", []):
            if c not in cast:
                fail("vocab", f"{i}: unknown character '{c}'")
        if a.get("place") and a["place"] not in places:
            fail("vocab", f"{i}: unknown place '{a['place']}'")

    # 3. the collar. Ash has no neckerchief until sc_collar; after it he
    #    always does (CLAUDE.md art rule 6).
    collar_at = next(
        (b["index"] for b in beats if b["art"] == COLLAR_BEAT), None
    )
    if collar_at is None:
        fail("canon", f"{COLLAR_BEAT} is not in the prologue -- cannot date the collar")
    else:
        for b in beats:
            a = assets.get(b["art"] or "")
            if not a or "ash" not in a.get("characters", []):
                continue
            worn = a.get("ash_neckerchief")
            if worn is None:
                continue  # not visible in frame; nothing to contradict
            expected = b["index"] >= collar_at
            if worn != expected:
                when = "after" if expected else "before"
                has = "wearing" if worn else "not wearing"
                fail(
                    "canon",
                    f"{a['id']}: beat {b['index']} is {when} the collar "
                    f"({COLLAR_BEAT} is beat {collar_at}), but Ash is {has} "
                    f"the neckerchief in it",
                )

    # 4. time of day. A scene's art must agree with the place it is shown in.
    for b in beats:
        a = assets.get(b["art"] or "")
        env = places.get(b["environment"] or "")
        if not a or not env:
            continue
        art_time, env_time = a.get("time_of_day"), env.get("time_of_day")
        if art_time in (None, "none", "unknown") or env_time in (None, "unknown"):
            continue
        if art_time not in env.get("also_reads_as", []) + [env_time]:
            fail(
                "time",
                f"{a['id']}: {art_time} art shown at beat {b['index']} in "
                f"'{b['environment']}', which is {env_time}",
            )

    # 5. cast. An image that should show Ash and shows a different cat is the
    #    drift art rule 4 exists to prevent -- but only while the game still
    #    draws it. A known-bad master kept in the library on purpose (see
    #    sc_shambles_day) is a note, not a failure; the defect is recorded so
    #    nobody wires it back in without reading why it was pulled.
    shelved = []
    for i, a in sorted(assets.items()):
        if not a.get("cast_defect"):
            continue
        if a.get("used_by"):
            fail("cast", f"{i}: {a['cast_defect']}")
        else:
            shelved.append(f"{i}: {a['cast_defect']}")

    # 6. orphans -- owned but never drawn. Not an error; worth knowing.
    #    Unwired AND unreferenced is the real signal: a master nothing ships
    #    and nothing names. Mockups are references, never shipped, so skip.
    orphans = [
        i
        for i, a in sorted(assets.items())
        if not a.get("used_by")
        and not a.get("wired")
        and not a.get("intentionally_unused")
        and a.get("kind") != "mockups"
    ]

    by_kind = {}
    for kind, msg in problems:
        by_kind.setdefault(kind, []).append(msg)

    # ASCII only: this prints to a cp1252 console and an em dash mojibakes.
    titles = {
        "coverage": "Coverage",
        "vocab": "Vocabulary",
        "canon": "Canon - the collar",
        "time": "Time of day",
        "cast": "Cast",
    }
    for kind in ("coverage", "vocab", "canon", "time", "cast"):
        msgs = by_kind.get(kind)
        if not msgs:
            continue
        print(f"\n{titles[kind]}  ({len(msgs)})")
        for m in msgs:
            print(f"  FAIL  {m}")

    if shelved:
        print(f"\nKnown-bad masters, currently unused  ({len(shelved)})")
        for s in shelved:
            print(f"  note  {s}")

    if orphans:
        print(f"\nUnused masters  ({len(orphans)})")
        print("  " + ", ".join(orphans))

    if problems:
        print(f"\n{len(problems)} problem(s).")
        return 1
    print("\nAll checks pass.")
    return 0


# --------------------------------------------------------------------------
# query / show / table
# --------------------------------------------------------------------------


def cmd_query(args) -> int:
    cat = load_catalog()
    rows = cat["assets"]

    def keep(a):
        if args.character and args.character not in a.get("characters", []):
            return False
        if args.time and a.get("time_of_day") != args.time:
            return False
        if args.setting and a.get("setting") != args.setting:
            return False
        if args.place and a.get("place") != args.place:
            return False
        if args.kind and a.get("kind") != args.kind:
            return False
        if args.neckerchief is not None and a.get("ash_neckerchief") != args.neckerchief:
            return False
        if args.text:
            hay = " ".join(
                str(a.get(k) or "") for k in ("id", "title", "description", "notes")
            ).lower()
            if args.text.lower() not in hay:
                return False
        if args.unused and a.get("used_by"):
            return False
        return True

    hits = [a for a in rows if keep(a)]
    for a in hits:
        who = ",".join(a.get("characters", [])) or "-"
        print(
            f"{a['id']:<28} {a.get('kind',''):<11} {a.get('setting',''):<9} "
            f"{a.get('time_of_day',''):<8} {who:<24} {a.get('title','')}"
        )
    print(f"\n{len(hits)} of {len(rows)}")
    return 0


def cmd_show(args) -> int:
    cat = load_catalog()
    a = next((x for x in cat["assets"] if x["id"] == args.id), None)
    if not a:
        print(f"no such asset: {args.id}", file=sys.stderr)
        return 1
    for k, v in a.items():
        if isinstance(v, list):
            v = ", ".join(str(x) for x in v) or "-"
        print(f"{k:>16}  {v if v not in (None, '') else '-'}")
    return 0


def write_doc(cat: dict) -> None:
    cols = [
        ("id", "Image"),
        ("kind", "Kind"),
        ("title", "What it is"),
        ("characters", "Who is in it"),
        ("setting", "In/Out"),
        ("place", "Place"),
        ("time_of_day", "Time"),
        ("ash_neckerchief", "Kerchief"),
        ("used_by", "Used by"),
    ]
    out = [
        "<!-- GENERATED by tools/art_catalog.py build -- do not edit. -->",
        "# Art catalog",
        "",
        "Every image in `assets/library/`, and what is in it. The source of",
        "truth is [`assets/art-catalog.json`](../../assets/art-catalog.json);",
        "this page is a rendering of it. `python tools/art_catalog.py check`",
        "is what actually enforces the two canon rules (the collar, and time",
        "of day matching the place a scene is shown in).",
        "",
        "Query it instead of reading it:",
        "",
        "```powershell",
        "python tools/art_catalog.py query --character ash --time night",
        "python tools/art_catalog.py query --place parlor",
        "python tools/art_catalog.py show sc_kettle    # full prompt + usage",
        "```",
        "",
    ]
    for kind in sorted({a["kind"] for a in cat["assets"]}):
        rows = [a for a in cat["assets"] if a["kind"] == kind]
        out += [f"## {kind} ({len(rows)})", ""]
        out.append("| " + " | ".join(c[1] for c in cols) + " |")
        out.append("|" + "|".join("---" for _ in cols) + "|")
        for a in sorted(rows, key=lambda r: r["id"]):
            cells = []
            for key, _ in cols:
                v = a.get(key)
                if key == "ash_neckerchief":
                    v = {True: "yes", False: "no", None: "—"}[v]
                elif key == "used_by":
                    v = f"{len(v)} place(s)" if v else "—"
                elif isinstance(v, list):
                    v = ", ".join(v) or "—"
                cells.append(str(v if v not in (None, "") else "—").replace("|", "/"))
            out.append("| " + " | ".join(cells) + " |")
        out.append("")
    DOC.write_text("\n".join(out), encoding="utf-8")


def cmd_table(args) -> int:
    cat = load_catalog()
    write_doc(cat)
    print(DOC.read_text(encoding="utf-8"))
    return 0


def main() -> int:
    # Titles carry em dashes and the Windows console defaults to cp1252,
    # which turns them into mojibake on the way out (law 24, output side).
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass

    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("build", help="refill prompts/usage/wiring and rewrite the doc")
    sub.add_parser("check", help="canon and coverage checks")
    sub.add_parser("table", help="render the markdown table")

    q = sub.add_parser("query", help="filter the catalog")
    q.add_argument("--character")
    q.add_argument("--time")
    q.add_argument("--setting")
    q.add_argument("--place")
    q.add_argument("--kind")
    q.add_argument("--text")
    q.add_argument("--unused", action="store_true")
    q.add_argument(
        "--neckerchief",
        type=lambda s: s.lower() in ("1", "true", "yes"),
        default=None,
    )

    s = sub.add_parser("show", help="one asset in full")
    s.add_argument("id")

    args = p.parse_args()
    return {
        "build": cmd_build,
        "check": cmd_check,
        "query": cmd_query,
        "show": cmd_show,
        "table": cmd_table,
    }[args.cmd](args)


if __name__ == "__main__":
    raise SystemExit(main())
