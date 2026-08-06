#!/usr/bin/env python3
"""PreToolUse guard for CLAUDE.md law 4 (mojibake protection).

Windows PowerShell 5.1 misdecodes UTF-8: round-tripping a file through
`Get-Content`/`Set-Content` turns every em-dash, bullet and ornament into
mojibake. It has already destroyed em-dashes, bullets and the ❋ ornament in
this repo once.

The law says "never do it". A law nobody can enforce is a law that gets
broken on a tired afternoon, so this hook enforces it: any shell command
that reads AND writes a text file through those cmdlets is refused, with the
correct incantation in the refusal message.

Reads a PreToolUse payload on stdin, writes a reason to stderr and exits 2
to block. Any other exit code allows the call.
"""

from __future__ import annotations

import json
import re
import sys

# Text formats that carry the ornaments PS 5.1 destroys. Data files are JSON
# (ASCII-safe escapes) so they are not at risk from this specific failure.
AT_RISK = r"\.(gd|md|tscn|py|ps1|json)\b"

READ_CMDLET = re.compile(r"\b(Get-Content|gc|cat|type)\b", re.IGNORECASE)
WRITE_CMDLET = re.compile(r"\b(Set-Content|Add-Content|Out-File|sc)\b", re.IGNORECASE)
AT_RISK_FILE = re.compile(AT_RISK, re.IGNORECASE)

# Deliberately ASCII-only: this text is printed to a Windows console whose
# code page mangles the very characters the law exists to protect. A refusal
# message that is itself mojibake does not teach anybody anything.
REMEDY = """BLOCKED by CLAUDE.md law 4: never round-trip text files through
PowerShell Get-Content/Set-Content. PS 5.1 misdecodes UTF-8 and mints
mojibake; it destroyed the em-dashes, bullets and ornaments in this repo once.

Use one of these instead:
  * the Edit or Write tool (preferred - they are UTF-8 safe)
  * [IO.File]::ReadAllText($f) / [IO.File]::WriteAllText($f, $c,
    (New-Object Text.UTF8Encoding $false))   # UTF-8, no BOM
  * the Bash tool, which does not have this defect
"""


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0  # unparseable payload is not this hook's business

    tool = payload.get("tool_name", "")
    if tool not in ("PowerShell", "Bash"):
        return 0

    command = str(payload.get("tool_input", {}).get("command", ""))
    if not command:
        return 0

    # Only the ROUND TRIP is dangerous. Reading alone is fine (and the model
    # is told to prefer Read anyway); writing fresh content with an explicit
    # -Encoding utf8 is fine. Read-then-write of an at-risk file is not.
    reads = READ_CMDLET.search(command)
    writes = WRITE_CMDLET.search(command)
    if not (reads and writes and AT_RISK_FILE.search(command)):
        return 0
    if "-Encoding utf8" in command or "UTF8Encoding" in command:
        return 0  # explicitly handled the encoding; let it through

    sys.stderr.write(REMEDY)
    return 2


if __name__ == "__main__":
    sys.exit(main())
