# Art docs — start here

There are nine documents about art in this folder, written between 2026-07-29
and 2026-08-06, and several describe a pipeline that no longer exists. This
page says which is which so nobody follows a retired process again.

**The workflow itself is the `/genart` skill and `CLAUDE.md`'s art rules.** Not
a doc — a procedure, kept where the model will actually read it.

## Current

| Doc | What it is for |
|---|---|
| [art-needed.md](art-needed.md) | **The live checklist.** What is missing right now. Checked mechanically by `python tools/kb_check.py`. |
| [ui-style-guide.md](ui-style-guide.md) | The visual contract for screens — the thing screens are built against. |
| [art-catalog.md](art-catalog.md) | **GENERATED.** What is IN every image — cast, indoor/outdoor, time of day, whether Ash has the kerchief. Query it with `python tools/art_catalog.py query`; `check` enforces the collar rule and time-of-day agreement. Source of truth is `assets/art-catalog.json`. |
| [art-manifest.md](art-manifest.md) | Every asset id, its framing and aspect ratio. The naming authority. |
| [ui-template-prompts.md](ui-template-prompts.md) | Prompts for the reusable UI furniture (frames, plates, seals). |
| [music-prompts.md](music-prompts.md) | Soundtrack identity and generation prompts. Nothing generated yet. |

## History — read, do not follow

These recorded decisions that have since been made, or processes that have
since been replaced. They are kept because they explain *why* the current
answer is the current answer.

| Doc | Superseded by | Why |
|---|---|---|
| [asset-pipeline.md](asset-pipeline.md) | `/genart` + CLAUDE.md art rules | Describes the owner pasting prompts into ChatGPT and dropping files in `assets/incoming/`. Claude generates directly through the API now. |
| [image-prompts-master.md](image-prompts-master.md) | `tools/batches/` | The prompt archive from before generation was scripted. The prompt that made an image now lives in the batch script that made it. |
| [image-requests.md](image-requests.md) | art-needed.md | An older wants-list, overtaken by the live checklist. |
| [ui-mockup-prompts.md](ui-mockup-prompts.md) | ui-template-prompts.md | Written when the UI was grey placeholder buttons. |
| [style-tests.md](style-tests.md) | — | The bake-off that chose Style A on 2026-07-29. The decision is locked; this is the evidence for it. |
| [art-audit-report.md](art-audit-report.md) | — | **GENERATED.** Rebuild with `godot --headless --path game -s tests/art_audit.gd`. Never hand-edit. |

## The three rules that cost money when broken

1. **Check `assets/library/<kind>/` before generating anything.** A duplicate
   wastes ~$0.19 and forks the canon.
2. **Changing an existing image? Check `assets/archive/` first.** An earlier
   take is often already what is wanted, and restoring one is free.
3. **Recurring characters are generated from a reference image, never from a
   description.** Words let a character drift — Ash came back a different
   breed once.

## Where the art actually lives

```
assets/library/<kind>/   only images the game uses — backdrops, characters,
                         enemies, energy, evidence, logos, scenes, skills, ui
assets/archive/          everything superseded. NEVER delete art; archive it.
game/assets/             the shipped copies, wired by tools/wire_assets.py
                         (never hand-copied — doing it by hand let the shipped
                         skill cards fall a whole generation behind)
```

After adding anything to `game/assets/`, run
`godot --headless --path game --import` or the tour renders black placeholders
for files that plainly exist.
