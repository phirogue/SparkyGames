# Music library - MANIFEST

**GENERATED** by `python tools/wire_music.py`. Do not hand-edit;
re-run the tool.

Every track here was trimmed, folded into a loop, normalised and encoded
from a raw generator take in `assets/incoming/music/` (gitignored).
Prompts and the delivery format:
[docs/design/music-prompts.md](../../../docs/design/music-prompts.md).

`seam` is the level difference across the loop point, in dB. Small is
good; it says the fold did not land in silence. It cannot say the fold
lands on a bar line - **that needs ears.**

| track | from | length | fold | trimmed | LUFS | peak | seam | KB |
|---|---|---|---|---|---|---|---|---|
| `mus_chase.ogg` | mus_chase-1.mp3 | 34s | 4s | 0.0s / 0.6s | -18.0 | -3.6 | 2.8 dB | 453 |
| `mus_combat.ogg` | mus_combat-2.mp3 | 67s | 4s | 0.0s / 0.1s | -18.0 | -4.9 | 5.5 dB | 834 |
| `mus_elspeth.ogg` | mus_elspeth-1.mp3 | 140s | 8s | 0.1s / 3.3s | -18.0 | -5.3 | 0.8 dB | 1655 |
| `mus_ending.ogg` | mus_ending-1.mp3 | 133s | once | 0.1s / 0.0s | -18.0 | -4.7 | n/a | 1604 |
| `mus_hollow_court.ogg` | mus_hollow_court-1.mp3 | 76s | 6s | 0.4s / 2.5s | -18.0 | -4.8 | 5.1 dB | 864 |
| `mus_mantel.ogg` | mus_mantel-1.mp3 | 145s | 8s | 0.0s / 3.9s | -18.0 | -5.3 | 3.1 dB | 1666 |
| `mus_mereside.ogg` | mus_mereside-1.mp3 | 164s | 8s | 0.7s / 5.7s | -18.0 | -4.9 | 3.9 dB | 1884 |
| `mus_needlework.ogg` | mus_needlework-2.mp3 | 114s | 6s | 0.0s / 2.5s | -18.0 | -3.3 | 0.4 dB | 1322 |
| `mus_prowl.ogg` | mus_prowl-1.mp3 | 80s | 6s | 0.1s / 1.5s | -18.0 | -4.0 | 8.9 dB | 990 |
| `mus_shambles.ogg` | mus_shambles-2.mp3 | 65s | 6s | 0.1s / 0.2s | -18.0 | -5.0 | 0.7 dB | 806 |
| `mus_stealth.ogg` | mus_stealth-1.mp3 | 73s | 8s | 0.0s / 1.1s | -18.1 | -2.9 | 5.9 dB | 866 |
| `mus_tallowman.ogg` | mus_tallowman-2.mp3 | 143s | 6s | 0.5s / 3.4s | -18.0 | -5.4 | 2.6 dB | 1640 |
| `mus_testimony.ogg` | mus_testimony-2.mp3 | 40s | 6s | 0.1s / 1.8s | -18.0 | -5.2 | 3.7 dB | 502 |
| `mus_title.ogg` | mus_title-1.mp3 | 120s | 4s | 0.1s / 4.2s | -18.0 | -5.6 | 1.1 dB | 1401 |
| `mus_unpicked.ogg` | mus_unpicked-2.mp3 | 49s | 8s | 0.0s / 2.5s | -18.0 | -3.3 | 0.2 dB | 550 |
