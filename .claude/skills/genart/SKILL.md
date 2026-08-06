---
name: genart
description: Generate, verify and file game art via the OpenAI image API. Use for ANY request to create, change, fix or regenerate an image. Usage: /genart <what you need>
---

# Generate art — the whole loop, in order

Claude Code generates art directly now. The owner does not paste prompts into
ChatGPT any more. Everything runs through `tools/genart.py` against
`gpt-image-2`, billed per image (~$0.19 at high quality) from the key in the
gitignored `.env`.

**The expensive mistakes this skill exists to prevent:** regenerating something
that already exists, regenerating when an archived version was already right,
letting a recurring character drift into a different design, and shipping art
nobody looked at.

## 1. Before generating ANYTHING — two lookups, always

```
ls assets/library/<kind>/          # does this id already exist?
ls assets/archive/superseded/      # is an older take already what's wanted?
```

- **If the id exists in the library, do not generate.** Say so and ask what
  should change.
- **If the request is to CHANGE an existing image, check the archive first.**
  Older takes are kept as `<id>__<n>.png` precisely so a revert is free.
  Read the candidates and offer one before spending money.
- If the change is small ("same but X"), do NOT re-roll from scratch — use
  `--ref` on the current image (step 3). That is how the title logo gained its
  neckerchief with the lettering untouched.

## 2. Pick the framing — the conventions are fixed

| kind | framing |
|---|---|
| `en_` enemies | **scene vignette** — subject dominant, setting dissolving into wash behind it. `en_chained_dog` is the reference. |
| `sk_` skills | subject alone on **plain parchment**, no environment |
| `ev_` evidence | objects on **plain parchment** (they read as pinned to a board) |
| `bg_` backdrops | 9:16 · `sc_` scenes and `npc_`/`ref_` portraits | 3:4 · glyphs and icons | 1:1 |

**Prologue canon: Ash has NO red neckerchief.** He takes it in `sc_collar`, the
last beat before the title card. Anything set earlier uses
`ref_ash_prologue.png`; everything after uses `ref_ash.png`.

## 3. Generate

Always `STRICT_STYLE` from `tools/genart.py` — never the old style block
in the docs. The old one described what we wanted but never forbade what we
kept getting, and nine images drifted into a "full-bleed digital render" look
before anyone noticed.

```bash
# plain generation
python tools/genart.py <id> --ratio 3:4 --quality high --prompt "..."

# FROM a reference — mandatory for any recurring character, and for
# "same image, one thing changed". Posts to the images EDITS endpoint.
python tools/genart.py <id> --ref assets/library/characters/ref_ash.png --prompt "..."
```

- **Every character who appears more than once is generated with `--ref`
  against their `ref_<name>.png`.** Words alone let them drift — Ash came back
  a different breed, and a witch appeared in the cold parlor looking nothing
  like Elspeth. A new recurring character's first portrait becomes their
  reference immediately.
- **Room variants are edited from the room, not re-described.** `bg_parlor_cold`
  is `--ref bg_parlor_warm` with the light withdrawn, so it is provably the
  same room. Same recipe as `bg_needle_lane` → `bg_needle_lane_wrong`.
- **Logos and UI mockups skip the style block** (`--no-style`): it ends in "no
  text in the image", which is wrong for art whose whole job is lettering.
- **UI icons: do NOT pass `background=transparent`** — `gpt-image-2` rejects it.
  Generate on pure white and key the alpha locally; `tools/genart_ui.py` does
  this with `cut_alpha`, which also trims the canvas to content.
- Batches of related work go in a `tools/genart_*.py` script, run with
  `run_in_background`, so the log survives and the batch is re-runnable.

`genart.py` writes **straight into `assets/library/<kind>/`** and moves whatever
it displaces to `assets/archive/superseded/`. There is no staging folder.

## 4. Verify — Read every image, no exceptions

Engineering law 1 and law 3 both apply. **Read each generated file before
calling anything done.** Check:

- **Is it the right medium?** The correct look ("Cluster A") has visible cream
  paper with a deckle edge, loose ink over granulated wash, warm amber used
  sparingly against blue-grey, and detail that dissolves behind the subject.
  The failure look is edge-to-edge crop with no paper margin, a mosaic/stipple
  texture on flat surfaces, crushed true-black darks, and uniform detail.
- **Canon:** right character design, right neckerchief state, no invented
  extras. Real defects caught this way: an unexplained human girl in an enemy
  portrait, a bedsheet ghost contradicting the established clerk, a black cat
  in a scene that asked for none.
- **Text:** read lettering character by character. A doubled word shipped once.
- **UI geometry, measured not eyeballed:**

```bash
python -c "
from PIL import Image; import glob,os
for f in sorted(glob.glob('assets/library/ui/*.png')):
    im=Image.open(f).convert('RGBA'); w,h=im.size
    a=im.getchannel('A'); lo,_=a.getextrema(); bb=a.getbbox()
    pct=100*(bb[2]-bb[0])*(bb[3]-bb[1])/(w*h) if bb else 0
    if lo>=250 or pct<60: print(f'{os.path.basename(f):28s} alpha={lo<250} content={pct:.0f}%')
"
```
Anything under ~60% content will render tiny for its box — crop, don't
regenerate.

## 5. File the result

```bash
python tools/promote.py --list                       # always dry-run first
python tools/promote.py <winner> --reject <loser>
```

`promote.py` refuses when two files resolve to the same target rather than
letting one silently overwrite the other. **Never delete art** — losers are
archived so any version can be restored.

## 6. Close the loop

- Update `docs/design/art-needed.md` — tick off what now exists, record what
  the review found.
- New art needs wiring before it renders: downscale into `game/assets/`
  (backdrops 720, portraits/scenes 512, UI 512, glyphs 220), then
  `godot --headless --path game --import`, or the tour shows black boxes for
  files that exist (engineering law 11).
- Commit. Report what was made, what it cost, and what you rejected and why.

## Model note

`gpt-image-2` is current. `gpt-image-1` is the April-2025 snapshot and looks a
generation behind — it produced a pencil sketch where the newer model produced
a finished watercolour. Before assuming, ask the API what exists:

```bash
python -c "
import json,urllib.request,sys; sys.path.insert(0,'tools')
from genart import load_key
r=urllib.request.Request('https://api.openai.com/v1/models',headers={'Authorization':f'Bearer {load_key()}'})
print([m['id'] for m in json.load(urllib.request.urlopen(r))['data'] if 'image' in m['id']])
"
```

`chatgpt-image-latest` tracks what ChatGPT serves in-chat but needs the org
verified at platform.openai.com/settings/organization/general.
