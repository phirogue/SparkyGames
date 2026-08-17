"""The propagation checker: does a change that landed in one place reach all of them?

    python tools/kb_check.py            # every check, human output
    python tools/kb_check.py --quiet    # only failures (for CI)
    python tools/kb_check.py --list     # what is checked, and what is not

Why this exists
---------------
Every component in this game is made of pieces that live in different files: a
minigame is a rules class AND a screen AND a data file AND a bot AND a launch
spec. Adding one and forgetting another does not fail loudly — it fails as a
dead button, a quest nobody photographed, a portrait that renders as a black
rectangle. Those defects reached owner reviews repeatedly, which is what
`docs/architecture/change-map.json` and this script exist to stop.

The change map says where a kind of change must propagate. This script proves
the propagation actually happened, mechanically, for the things a machine can
see. It is deliberately not clever: every check below is one the repo can
answer for itself today.

Exit code is 0 when clean, 1 when anything failed.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

REPO = Path(__file__).resolve().parent.parent
GAME = REPO / "game"
DATA = GAME / "data"
STORY = GAME / "story"
ASSETS = GAME / "assets"

# Fields anywhere in the content JSON whose value is an art id resolved as
# `res://assets/<id>.png` by UITheme.tex(). Keep in step with ui_theme.gd.
ART_FIELDS = {"portrait", "image", "seal", "art", "icon"}

# The five mission modules, and the shape each one is required to have. This
# table is the machine-readable half of "adding a minigame" in the change map.
MODULES = {
    "stitch": "stitch_charts",
    "testimony": "testimonies",
    "ward": "wards",
    "lattice": "lattices",
    "crossing": "crossings",
}

results: list[tuple[str, str, str]] = []  # (status, check, detail)


def ok(check: str, detail: str = "") -> None:
    results.append(("ok", check, detail))


def fail(check: str, detail: str) -> None:
    results.append(("FAIL", check, detail))


def known(check: str, detail: str) -> None:
    """An accepted gap: printed every run, does not fail the build."""
    results.append(("known", check, detail))


def accepted_gaps() -> dict:
    path = REPO / "docs/architecture/known-gaps.json"
    if not path.exists():
        return {}
    return {k: v for k, v in read_json(path).items() if not k.startswith("_")}


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def walk(node, found, fields=ART_FIELDS):
    """Yield every (field, value) pair anywhere in a nested structure."""
    if isinstance(node, dict):
        for key, value in node.items():
            if key in fields and isinstance(value, str) and value:
                found.add(value)
            walk(value, found, fields)
    elif isinstance(node, list):
        for item in node:
            walk(item, found, fields)


# --------------------------------------------------------------- the checks

def check_art_references_resolve() -> None:
    """Every art id named in content exists on disk.

    A missing one renders as a black rectangle or an empty frame — it does not
    raise, which is exactly why it reaches a review. Law 11's import pass is
    the other half of this: a file that exists but was never imported is just
    as black, so the shipped .import sidecar is checked too.
    """
    referenced: set[str] = set()
    for path in sorted(DATA.glob("*.json")) + sorted(STORY.rglob("*.json")):
        walk(read_json(path), referenced)
    missing, unimported = [], []
    for art_id in sorted(referenced):
        png = ASSETS / f"{art_id}.png"
        if not png.exists():
            missing.append(art_id)
        elif not png.with_suffix(".png.import").exists():
            unimported.append(art_id)
    gap = accepted_gaps().get("missing_art", {})
    accepted = set(gap.get("ids", []))
    # An accepted gap that has closed must be removed from known-gaps.json, or
    # the file rots into a list of things that were fixed years ago.
    healed = sorted(accepted - set(missing))
    if healed:
        fail("art references resolve",
             f"known-gaps.json still accepts art that now exists: {', '.join(healed)} "
             f"— delete those entries")
        return
    unaccepted = [art_id for art_id in missing if art_id not in accepted]
    if unaccepted:
        fail("art references resolve",
             f"{len(unaccepted)} id(s) named in content have no file: "
             + ", ".join(unaccepted[:8]) + ("..." if len(unaccepted) > 8 else ""))
    elif missing:
        known("art references resolve",
              f"{len(missing)} accepted gap(s) — {', '.join(sorted(missing))} "
              f"(tracked in {gap.get('tracked_in', 'known-gaps.json')})")
    elif unimported:
        fail("art references resolve",
             f"{len(unimported)} file(s) exist but were never imported (law 11 — run "
             f"`godot --headless --path game --import`): " + ", ".join(unimported[:8]))
    else:
        ok("art references resolve", f"{len(referenced)} ids, all present and imported")


def check_every_data_file_is_loaded() -> None:
    """A data file DataLoader never opens is content nobody can reach."""
    loader = (GAME / "services/data_loader.gd").read_text(encoding="utf-8")
    orphans = [p.name for p in sorted(DATA.glob("*.json")) if p.name not in loader]
    if orphans:
        fail("every data file is loaded",
             "not opened by data_loader.gd: " + ", ".join(orphans))
    else:
        ok("every data file is loaded", f"{len(list(DATA.glob('*.json')))} files")


def check_minigame_modules_are_complete() -> None:
    """Each module needs all five of its pieces, or it is a dead button."""
    game_gd = (GAME / "scenes/game.gd").read_text(encoding="utf-8")
    bots = (GAME / "tests/minigame_bots.gd").read_text(encoding="utf-8")
    broken = []
    for module, data_stem in MODULES.items():
        pieces = {
            "rules": (GAME / f"core/{module}_state.gd").exists(),
            "screen": (GAME / f"scenes/minigames/{module}_screen.gd").exists(),
            "content": (DATA / f"{data_stem}.json").exists(),
            "launch spec": f'"{module}"' in game_gd,
            "bot": module in bots,
        }
        absent = [name for name, present in pieces.items() if not present]
        if absent:
            broken.append(f"{module} (missing: {', '.join(absent)})")
    if broken:
        fail("minigame modules are complete", "; ".join(broken))
    else:
        ok("minigame modules are complete", f"{len(MODULES)} modules, 5 pieces each")


def check_every_screen_is_reachable() -> None:
    """A screen the orchestrator never shows cannot be played or photographed.

    Reachable means named by game.gd (which owns every route) OR used by another
    scene — the shared minigame shell is a builder every module screen calls,
    not a page anybody navigates to.
    """
    scene_sources = {
        path: path.read_text(encoding="utf-8")
        for path in sorted(GAME.glob("scenes/**/*.gd"))
    }
    orphans = []
    for script, _ in scene_sources.items():
        name = script.name
        if name in ("game.gd", "main.gd"):
            continue
        stem = name.removesuffix(".gd")
        class_name_form = "".join(part.title() for part in stem.split("_"))
        referenced = any(
            name in text or class_name_form in text
            for other, text in scene_sources.items() if other != script
        )
        if not referenced:
            orphans.append(str(script.relative_to(GAME)))
    if orphans:
        fail("every screen is reachable",
             "never routed to or used by another scene: " + ", ".join(orphans))
    else:
        ok("every screen is reachable", f"{len(scene_sources)} scene scripts")


def check_every_quest_has_a_launcher() -> None:
    """play/parts.json is how the owner reaches a part without a playthrough.

    tour_all.py reads quests.json directly so photography cannot drift, but the
    double-clickable launchers are a hand-kept manifest — the exact thing that
    silently falls behind.
    """
    quests = [k for k in read_json(DATA / "quests.json") if not k.startswith("_")]
    parts = read_json(REPO / "play/parts.json")
    entries = parts if isinstance(parts, list) else parts.get("parts", [])
    specs = " ".join(str(entry.get("spec", "")) for entry in entries)
    missing = [q for q in quests if f"quest:{q}" not in specs]
    if missing:
        fail("every quest has a launcher",
             "no play/parts.json entry (add one and re-run `play.ps1 -Install`): "
             + ", ".join(missing))
    else:
        ok("every quest has a launcher", f"{len(quests)} quests")


def check_generated_docs_declare_themselves() -> None:
    """A generated doc that does not say so gets hand-edited, then regenerated
    over the top of the edit. The header is the only thing that stops it."""
    generated = {
        "docs/design/bestiary.md":
            "godot --headless --path game -s tests/bestiary.gd",
        "docs/design/art-audit-report.md":
            "godot --headless --path game -s tests/art_audit.gd",
        "docs/design/art-catalog.md":
            "python tools/art_catalog.py build",
        "docs/design/story-catalog.md":
            "python tools/story_catalog.py build",
    }
    bad = []
    for rel, command in generated.items():
        path = REPO / rel
        if not path.exists():
            bad.append(f"{rel} (missing)")
            continue
        head = path.read_text(encoding="utf-8")[:600].lower()
        says_generated = "generated" in head
        says_dont_edit = any(phrase in head for phrase in
                             ("hand-edit", "hand edit", "do not edit", "don't edit"))
        names_rebuild = command.split()[-1] in head  # the script that rebuilds it
        if not (says_generated and says_dont_edit and names_rebuild):
            bad.append(f"{rel} (header must say GENERATED, warn against hand-editing, "
                       f"and name `{command}`)")
    if bad:
        fail("generated docs declare themselves", "; ".join(bad))
    else:
        ok("generated docs declare themselves", f"{len(generated)} docs")


def check_change_map_paths_exist() -> None:
    """The map is only useful while it points at real files."""
    map_path = REPO / "docs/architecture/change-map.json"
    if not map_path.exists():
        fail("change map paths exist", "docs/architecture/change-map.json is missing")
        return
    change_map = read_json(map_path)
    stale = []
    for change, spec in change_map.get("changes", {}).items():
        for step in spec.get("touch", []):
            target = step.get("path", "")
            if not target or any(ch in target for ch in "*?"):
                continue  # globs are patterns, not promises
            if not (REPO / target).exists():
                stale.append(f"{change} -> {target}")
    if stale:
        fail("change map paths exist",
             f"{len(stale)} dead path(s): " + "; ".join(stale[:6]))
    else:
        ok("change map paths exist",
           f"{len(change_map.get('changes', {}))} change types")


def check_tools_referenced_by_docs_exist() -> None:
    """Docstrings and skills name commands. A named tool that does not exist
    sends whoever followed the instruction on a hunt."""
    named = set()
    for path in list(REPO.glob("tools/*.py")) + list(REPO.glob(".claude/skills/*/SKILL.md")):
        text = path.read_text(encoding="utf-8", errors="replace")
        named.update(re.findall(r"tools/[a-z_0-9]+\.py", text))
        named.update(re.findall(r"tests/[a-z_0-9]+\.gd", text))
    missing = sorted(n for n in named if not (REPO / n).exists()
                     and not (GAME / n).exists())
    if missing:
        fail("tools named in docs exist", ", ".join(missing))
    else:
        ok("tools named in docs exist", f"{len(named)} references")


CHECKS = [
    check_art_references_resolve,
    check_every_data_file_is_loaded,
    check_minigame_modules_are_complete,
    check_every_screen_is_reachable,
    check_every_quest_has_a_launcher,
    check_generated_docs_declare_themselves,
    check_change_map_paths_exist,
    check_tools_referenced_by_docs_exist,
]

# Honesty about coverage: things the change map calls for that a machine
# cannot check yet. Printed by --list so the gap is visible rather than
# assumed away.
NOT_CHECKED = [
    "whether a new enemy's bestiary entry was regenerated (needs a content hash)",
    "whether balance-notes.md was updated after a tuning change (prose)",
    "whether new art matches the house style (asset-auditor agent)",
    "whether a new quest reads as a story (story-critic agent)",
]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--quiet", action="store_true", help="print failures only")
    parser.add_argument("--list", action="store_true", help="describe the checks")
    args = parser.parse_args()

    if args.list:
        print("Checked mechanically:")
        for check in CHECKS:
            summary = (check.__doc__ or "").strip().splitlines()[0]
            print(f"  {check.__name__.removeprefix('check_'):36s} {summary}")
        print("\nNOT checked mechanically (still needs eyes):")
        for gap in NOT_CHECKED:
            print(f"  - {gap}")
        return

    for check in CHECKS:
        try:
            check()
        except Exception as error:  # a broken check must not look like a pass
            fail(check.__name__.removeprefix("check_"), f"check itself errored: {error}")

    failures = [r for r in results if r[0] == "FAIL"]
    gaps = [r for r in results if r[0] == "known"]
    marks = {"ok": "ok  ", "FAIL": "FAIL", "known": "gap "}
    for status, check, detail in results:
        if args.quiet and status == "ok":
            continue
        print(f"  {marks[status]}  {check:34s} {detail}")
    print()
    if failures:
        print(f"{len(failures)} propagation check(s) failed.")
        print("See docs/architecture/change-map.json for where each change must reach.")
        sys.exit(1)
    summary = f"all {len(results)} propagation checks pass"
    if gaps:
        summary += f" ({len(gaps)} accepted gap(s) — see docs/architecture/known-gaps.json)"
    print(summary + ".")


if __name__ == "__main__":
    main()
