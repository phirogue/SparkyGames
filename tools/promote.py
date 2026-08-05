"""Promote reviewed art from incoming/procedural into the library.

    python tools/promote.py <file.png> [more.png ...]      # promote by filename
    python tools/promote.py --all                          # promote everything
    python tools/promote.py --list                         # show what would happen

The library holds every image cleared to be used or requested to exist; the
archive holds everything superseded. Nothing is ever deleted (CLAUDE.md art
rules 2 and 3) -- when a promotion displaces an existing library file, that
file moves to assets/archive/superseded/<id>__<n>.png so it can be reviewed or
restored later.

Filing is by id prefix, so `sc_foo.png` lands in scenes/ without being told.
A `_v2` / `_img2` / `_kerchief` suffix is stripped to get the real id, so the
winning variant promotes to the canonical name.
"""

import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PROC = REPO / "assets" / "incoming" / "procedural"
LIB = REPO / "assets" / "library"
SUPERSEDED = REPO / "assets" / "archive" / "superseded"

PREFIX_TO_KIND = [
    ("bg_", "backdrops"),
    ("en_", "enemies"),
    # Case Board objects. Framed like skills -- the thing alone on plain
    # parchment -- because on the board they read as pinned to it.
    ("ev_", "evidence"),
    ("sc_", "scenes"),
    ("sk_", "skills"),
    ("energy_", "energy"),
    ("logo_", "logos"),
    ("mock_", "mockups"),
    ("ui_objective", "mockups"),
    ("ui_", "ui"),
    ("npc_", "characters"),
    ("ref_", "characters"),
]

# Variant suffixes we strip to recover the canonical asset id.
VARIANT = re.compile(r"_(v\d+|img\d+|kerchief|new|fixed)$")


def kind_for(asset_id: str) -> str:
    for prefix, kind in PREFIX_TO_KIND:
        if asset_id.startswith(prefix):
            return kind
    raise SystemExit(f"no folder rule for id '{asset_id}' -- add one to PREFIX_TO_KIND")


def canonical_id(stem: str) -> str:
    while VARIANT.search(stem):
        stem = VARIANT.sub("", stem)
    return stem


def move(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    tracked = subprocess.run(
        ["git", "ls-files", "--error-unmatch", str(src.relative_to(REPO))],
        cwd=REPO, capture_output=True,
    ).returncode == 0
    if tracked:
        subprocess.run(["git", "mv", "-f", str(src.relative_to(REPO)),
                        str(dst.relative_to(REPO))], cwd=REPO, check=True)
    else:
        shutil.move(str(src), str(dst))


def next_archive_path(asset_id: str) -> Path:
    SUPERSEDED.mkdir(parents=True, exist_ok=True)
    i = 1
    while (SUPERSEDED / f"{asset_id}__{i}.png").exists():
        i += 1
    return SUPERSEDED / f"{asset_id}__{i}.png"


def promote(path: Path, dry: bool) -> None:
    asset_id = canonical_id(path.stem)
    kind = kind_for(asset_id)
    target = LIB / kind / f"{asset_id}.png"

    if target.exists():
        archived = next_archive_path(asset_id)
        print(f"  archive  {target.relative_to(REPO)} -> {archived.relative_to(REPO)}")
        if not dry:
            move(target, archived)
    print(f"  promote  {path.relative_to(REPO)} -> {target.relative_to(REPO)}")
    if not dry:
        move(path, target)


def reject(path: Path, dry: bool) -> None:
    """Archive a procedural file without promoting it -- a losing variant."""
    archived = next_archive_path(canonical_id(path.stem))
    print(f"  reject   {path.relative_to(REPO)} -> {archived.relative_to(REPO)}")
    if not dry:
        move(path, archived)


def resolve(names: list) -> list:
    out = []
    for a in names:
        p = Path(a)
        if not p.is_absolute():
            p = PROC / p if (PROC / p).exists() else Path(a)
        if not p.exists():
            raise SystemExit(f"not found: {a}")
        out.append(p)
    return out


def main() -> None:
    argv = sys.argv[1:]
    dry = "--list" in argv

    # everything after --reject is rejected; before it, promoted
    if "--reject" in argv:
        i = argv.index("--reject")
        promote_names = [a for a in argv[:i] if not a.startswith("--")]
        reject_names = [a for a in argv[i + 1:] if not a.startswith("--")]
    else:
        promote_names = [a for a in argv if not a.startswith("--")]
        reject_names = []

    if "--all" in argv or (dry and not promote_names and not reject_names):
        promote_files = sorted(PROC.glob("*.png"))
    else:
        promote_files = resolve(promote_names)
    reject_files = resolve(reject_names)

    # Guard: two sources resolving to the same library target means one would
    # silently overwrite the other. Refuse rather than pick a winner by luck.
    seen = {}
    for f in promote_files:
        aid = canonical_id(f.stem)
        if aid in seen:
            raise SystemExit(
                f"COLLISION: '{seen[aid].name}' and '{f.name}' both promote to "
                f"'{aid}.png'. Pick one and --reject the other."
            )
        seen[aid] = f

    if not promote_files and not reject_files:
        print("nothing to do")
        return

    print(f"{'DRY RUN -- ' if dry else ''}"
          f"{len(promote_files)} promote, {len(reject_files)} reject:")
    for f in reject_files:
        reject(f, dry)
    for f in promote_files:
        promote(f, dry)
    if not dry:
        print("\ndone. Library holds the current versions; superseded and "
              "rejected takes are in assets/archive/superseded/.")


if __name__ == "__main__":
    main()
