# Art Still Needed — living checklist

*Updated 2026-08-03. Prompt archive:
[image-prompts-master.md](image-prompts-master.md). Style audit:
[2026-08-03-art-style-audit.md](../research/2026-08-03-art-style-audit.md).
Folder contract and conventions: [assets/README.md](../../assets/README.md).*

**Chapter 1 wave 1 is now outstanding** (see the next section) — the Case
Board ships with visible black-box placeholders where these belong. Every
image requested *before* Chapter 1 exists, and the library
(`assets/library/`, 99 images) holds only current, cleared art. 46 superseded
takes are in `assets/archive/` and can be restored at any time.

## Chapter 1, wave 1 — wanted now (the Case Board shows their gaps)

The Case Board renders these ids today as placeholder boxes. Framing: the
evidence set are **objects on plain parchment** (skill-card framing, not
scene vignettes) so they read as things pinned to a board; the two portraits
are **character portraits, 3:4**, and both recur, so each needs to become its
own `ref_` anchor the moment it exists (library rule 4).

| id | what it is |
|---|---|
| ~~`ev_candle_stub`~~ | **DONE 2026-08-04.** Beeswax stub, burnt low, bee seal pressed into the flank. Wired. |
| `ev_ledger` | a torn ledger page in a guildmaster's hand (L2) |
| `ev_tally` | a Lamplighters' shift-tally, chalk on a wooden slat (L3) |
| `ev_seam` | a hand's length of ward-thread, unpicked and backward (L4) |
| ~~`ev_docket`~~ | **DONE 2026-08-04.** Folded cart docket, consignee line scratched out. Wired. |
| `npc_wick` | Guildmaster Ellery Wick — charming-awful, never cartoon-evil |
| `npc_gentleman` | The Quiet Gentleman — a fixer nobody remembers meeting first |
| `npc_bodkin` | Bodkin: a scarred one-eyed grey tom. Enters at L1 as an ally |

**Read `docs/design/the-unraveler.md` before prompting Bodkin.** How he is
drawn is a fair-play matter, not a taste one.

Generation is now cheap and scripted, so the bottleneck is judgement, not
supply. **Before making anything, check the library — and if you're changing
an existing image, check the archive first.**

### The opening arc's own scenes — done 2026-08-04

Generated for the Chapter 1 opening arc (`quests.json`), read, wired and
shot in the tour. Both carry Ash and were generated from `ref_ash.png`
(post-title, so he wears the neckerchief), per library rule 4.

| id | what it is |
|---|---|
| `sc_the_carrying` | the witches lift Elspeth out of her chair at first light; the eldest is turned to the wall of cut threads; Ash on the mantel, watching |
| `sc_the_wake` | the tideline funeral: bier at the waterline, women in grey close in, guild delegates apart in good coats, Ash alone on a mooring post |

Brindle was **not** generated: `npc_brindle_magpie` was already in the
library and already right (library rule 1). That is one generation the
lookup saved, and the whole reason the lookup is rule 1.

**Still wanted for beats now written but not yet built:** `npc_shift_boss`
(the Lamplighters' testimony), and the L2-L5 evidence above.

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
| `npc_pigeon_postmaster` | Chapter 1 guild faces. `npc_brindle_magpie` and `npc_rat_boss` are now WIRED and referenced by find_the_magpie / ask_the_rats |
| `ui_case_board` | the Clue-style case board backing |
| `ui_paw_solid`, `ui_paw_stamp`, `ui_icon_menu` | replace the engine-drawn stand-ins |
| `ui_settings_row`, `ui_toggle_on`, `ui_toggle_off`, `ui_icon_sound`, `ui_icon_music`, `ui_icon_brightness`, `ui_icon_language` | the settings screen, which had no real art before |
| `mock_journal`, `mock_chapter_select`, `mock_settings` | design references, rebuilt in code — not shipped |
| `sc_hollow_court_desk`, `sc_shambles_day` | Chapter 1 scenes — both now referenced and wired |
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
