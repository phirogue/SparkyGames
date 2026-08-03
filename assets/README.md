# assets/ — raw art library

Hi-res sources live here. The game never loads from this tree; `game/assets/`
holds the downscaled, imported copies. See
[asset-pipeline.md](../docs/design/asset-pipeline.md) for the processing loop.

```
assets/
├── library/          ← every image cleared to be used or requested to exist
│   ├── backdrops/    bg_*      district and room paintings      9:16
│   ├── characters/   ref_*, npc_*  anchors and NPC portraits    3:4
│   ├── enemies/      en_*      battle opponents                 3:4
│   ├── scenes/       sc_*      story beats                      3:4
│   ├── skills/       sk_*      skill card art                   1:1
│   ├── energy/       energy_*  the four humour glyphs           1:1
│   ├── logos/        logo_*    studio + title treatments
│   ├── ui/           ui_*      frames, buttons, icons, chrome
│   └── mockups/      mock_*, ui_objective  design references, rebuilt in code
├── incoming/         ← manual drop zone for art the owner supplies by hand;
│                       file it into library/ once reviewed. Should be empty.
└── archive/
    ├── superseded/   every version a newer take replaced, `<id>__<n>.png`
    ├── v1/           the first generation batch
    └── early-tests/  the first loose style probes, pre-naming-convention
```

## Rules

- **The library is the current state.** It holds exactly the images that are
  used or are meant to be used — nothing experimental, nothing superseded.
- **Nothing is ever deleted.** When a new take replaces an old one, the old
  file moves to `archive/superseded/<id>__<n>.png`. Any version can be
  reviewed or restored later.
- **Filed by id prefix.** The prefix decides the folder; a new `sc_` file goes
  in `scenes/` without discussion. Ids are stable and match `game/data/*.json`.
- **Before generating anything, check the library** — never make an image that
  already exists. **Before changing an image, check `archive/`** — an earlier
  take is often already what's wanted, and restoring one is free.

## Conventions

- **Enemies are scene vignettes** — subject dominant, setting dissolving into
  wash behind it. `en_chained_dog` is the reference.
- **Skill cards are on plain parchment** — the subject alone, no environment.
- **Prologue Ash has no red neckerchief.** He takes it in `sc_collar`, the last
  beat before the title card. Use `ref_ash_prologue.png` for any earlier scene
  and `ref_ash.png` for everything after.
- **Recurring characters are generated from their reference image**, never from
  a description — words let them drift.

## Tools

```
python tools/genart.py <id> --ratio 3:4 --prompt "..."      # new image
python tools/genart.py <id> --ref library/characters/ref_ash.png --prompt "..."
python tools/promote.py <file> --reject <loser>             # file/retire art
```

`genart.py` writes straight into `library/<kind>/` and archives whatever it
displaces — there is no staging step. `--ref` switches to the images *edits*
endpoint, which is how character consistency and "same image, one thing
changed" are done. Standing regeneration batches live in
`tools/genart_fixes.py`, `genart_fixes2.py`, `genart_round3.py`, `genart_ui.py`.

Note: the API renders 1024x1536, which is 2:3 — slightly squarer than the 9:16
the backdrop prompts ask for. Backdrops need a crop on the way to
`game/assets/`. `gpt-image-2` rejects `background="transparent"`; UI art is
generated on white and keyed to alpha locally by `genart_ui.py:cut_alpha`,
which also trims the canvas so nothing ships with padding.
