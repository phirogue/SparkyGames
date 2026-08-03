# Art Still Needed — living checklist

*Updated 2026-08-03. Prompt archive:
[image-prompts-master.md](image-prompts-master.md). Style audit:
[2026-08-03-art-style-audit.md](../research/2026-08-03-art-style-audit.md).
Folder contract and conventions: [assets/README.md](../../assets/README.md).*

**Nothing is outstanding.** Every image ever requested exists, and the library
(`assets/library/`, 99 images) holds only current, cleared art. 46 superseded
takes are in `assets/archive/` and can be restored at any time.

Generation is now cheap and scripted, so the bottleneck is judgement, not
supply. **Before making anything, check the library — and if you're changing
an existing image, check the archive first.**

---

## What's ready but not yet wired into the game

These exist in the library and are cleared for use; the game does not
reference them yet. Wiring means: downscale into `game/assets/` (backdrops 720,
portraits/scenes 512, UI 512, glyphs 220), run
`godot --headless --path game --import`, then reference the id from
`game/data/*.json`.

| id | for |
|---|---|
| `logo_ashcat_title` | title screen — typo fixed AND Ash now wears his neckerchief |
| `bg_mantel`, `bg_mantel_scene` | the hub. `_scene` has a deliberately bare wall for pinned notes; `bg_mantel` is the fuller painting |
| `npc_brindle_magpie`, `npc_rat_boss`, `npc_pigeon_postmaster` | Chapter 1 guild faces |
| `ui_case_board` | the Clue-style case board backing |
| `ui_paw_solid`, `ui_paw_stamp`, `ui_icon_menu` | replace the engine-drawn stand-ins |
| `ui_settings_row`, `ui_toggle_on`, `ui_toggle_off`, `ui_icon_sound`, `ui_icon_music`, `ui_icon_brightness`, `ui_icon_language` | the settings screen, which had no real art before |
| `mock_journal`, `mock_chapter_select`, `mock_settings` | design references, rebuilt in code — not shipped |
| `sc_hollow_court_desk`, `sc_shambles_day` | Chapter 1 scenes |
| `ref_ash_prologue` | reference only — the bare-necked Ash, for prologue scenes |

## Open work

1. **Seven older UI elements have heavy transparent padding** — content fills
   only 26–58% of canvas (`ui_needle_pin` 26%, `ui_ash_head` 28%,
   `ui_paw_full` 31%, `ui_paw_empty` 34%, `ui_button_pile` 44%,
   `ui_icon_intent_hand` 53%, `ui_icon_intent_skills` 58%). Fix by re-cropping
   on import — `genart_ui.py:cut_alpha` already does exactly this trim and can
   be pointed at them. Do NOT regenerate; the art is fine.
2. **`bg_hollow_court`'s lamp is green** — the only green light in the game, at
   the focal point. A tint pass fixes it; no regeneration needed.
3. **The four energy glyphs were never audited as a set.** `energy_claw` sits
   on a flat grey field rather than paper, which is suspect. Check whether the
   four read as a matched set before Chapter 1 art begins.
4. **`en_the_vole` and `en_wisp_pair` are mild drift** — full-bleed with no
   paper margin, where the rest of the enemies now have visible deckle edges.
   Worth a regeneration pass with `STRICT_STYLE` when convenient.
5. **Recurring characters still need reference sheets.** `ref_ash` and
   `ref_elspeth` exist and `ref_ash_prologue` is new. The three Chapter 1 NPC
   portraits currently double as their own references — fine for now, but any
   second appearance must be generated with `--ref` against them.

## Chapter 1 and beyond

No prompts written yet. When they are, they go in
[image-prompts-master.md](image-prompts-master.md) and get generated with
`STRICT_STYLE`, the framing conventions in
[assets/README.md](../../assets/README.md), and `--ref` for every returning
character.
