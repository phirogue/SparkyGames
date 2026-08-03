# assets/ — raw art library

Hi-res sources live here. The game never loads from this tree; `game/assets/`
holds the downscaled, imported copies. See
[asset-pipeline.md](../docs/design/asset-pipeline.md) for the processing loop.

```
assets/
├── library/          ← canonical hi-res sources, filed by kind
│   ├── backdrops/    bg_*      district and room paintings      9:16
│   ├── characters/   ref_*, npc_*  anchors and NPC portraits    3:4
│   ├── enemies/      en_*      battle opponents                 3:4
│   ├── scenes/       sc_*      story beats                      3:4
│   ├── skills/       sk_*      skill card art                   1:1
│   ├── energy/       energy_*  the four humour glyphs           1:1
│   ├── logos/        logo_*    studio + title treatments
│   ├── ui/           ui_*      frames, buttons, icons, chrome
│   └── mockups/      mock_*, ui_objective  design references, rebuilt in code
├── incoming/         ← drop zone: new art lands here unsorted, then gets filed
│   └── procedural/   ← output of tools/genart.py, awaiting review
└── archive/
    ├── v1/           superseded earlier generations, kept for comparison
    └── early-tests/  the first loose style probes, pre-naming-convention
```

## Rules

- **Filed by id prefix.** The prefix decides the folder; a new `sc_` file goes
  in `scenes/` without discussion. Ids are stable and match `game/data/*.json`.
- **`incoming/` should normally be empty.** It's a staging area, not storage.
  File things out of it once reviewed.
- **Nothing is deleted.** Superseded art moves to `archive/`, so a regression
  can always be diffed against what it replaced.
- **`procedural/` is unreviewed.** API output lands there and stays until a
  human looks at it; promotion means moving it into `library/`.

## Generating

`python tools/genart.py <asset_id> --ratio 3:4 --prompt "..."` — reads
`OPENAI_API_KEY` from the gitignored `.env`, writes to `incoming/procedural/`.
`tools/genart_batch.py` holds the standing list of requested-but-unmade art.

Note: the API renders 1024x1536, which is 2:3 — slightly squarer than the 9:16
the backdrop prompts ask for. Backdrops need a crop on the way to
`game/assets/`.
