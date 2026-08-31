"""Where the machine-specific binaries live.

Every tool that shells out to Godot or ffmpeg resolves the binary HERE, so a
second machine — CI above all — is one environment variable away from running
the exact same gate as the dev box:

    GODOT_BIN     path to the Godot executable
    FFMPEG_BIN    path to ffmpeg
    FFPROBE_BIN   path to ffprobe

Resolution order: the environment variable, then this machine's known
install, then whatever is on PATH. The hardcoded fallbacks below are why CI
once had to re-implement the whole pipeline in YAML instead of calling
verify.py — never add a new binary path anywhere but here.
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path

_GODOT_DEFAULT = Path(r"C:\Users\yurim\tools\godot\Godot_v4.4.1-stable_win64_console.exe")
_FFMPEG_DEFAULT = Path(r"C:\Users\yurim\Packages\ffmpeg\bin\ffmpeg.exe")
_FFPROBE_DEFAULT = Path(r"C:\Users\yurim\Packages\ffmpeg\bin\ffprobe.exe")


def _resolve(env_name: str, default: Path, on_path: str) -> Path:
    named = os.environ.get(env_name, "")
    if named:
        return Path(named).expanduser()
    if default.exists():
        return default
    found = shutil.which(on_path)
    # Fall back to the default even when missing, so the caller's "not found
    # at <path>" error names a real location rather than an empty string.
    return Path(found) if found else default


def godot_binary() -> Path:
    return _resolve("GODOT_BIN", _GODOT_DEFAULT, "godot")


def ffmpeg_binary() -> Path:
    return _resolve("FFMPEG_BIN", _FFMPEG_DEFAULT, "ffmpeg")


def ffprobe_binary() -> Path:
    return _resolve("FFPROBE_BIN", _FFPROBE_DEFAULT, "ffprobe")
