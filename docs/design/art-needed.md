# Art Still Needed — living checklist

*Updated 2026-08-03. This is the CURRENT to-generate list; the full prompt
archive with everything already made lives in
[image-prompts-master.md](image-prompts-master.md). The full-library style
audit is [2026-08-03-art-style-audit.md](../research/2026-08-03-art-style-audit.md).*

**Status: every image ever requested has now been generated.** The backlog
below is no longer "make the missing art" — it is "review, fix, and file what
exists". New art comes from `tools/genart.py` (OpenAI `gpt-image-2`), so the
bottleneck is judgement, not generation.

**Where things live:** organized sources in `assets/library/<kind>/`,
unreviewed API output in `assets/incoming/procedural/`. See
[assets/README.md](../../assets/README.md).

**The style block to use is now `STRICT_STYLE` in `tools/genart_fixes.py`,**
not the old one. The old block described what we wanted but never forbade what
we kept getting; the new one names the failure modes as explicit negatives.
That change alone fixed nine images.

---

## A. Awaiting review — generated 2026-08-03, sitting in `procedural/`

Nothing here is wired into the game yet. Promotion means: look at it, pick the
winner, move it into `assets/library/<kind>/`, downscale into `game/assets/`,
run the import pass.

| id | verdict so far |
|---|---|
| `logo_ashcat_title` | ✅ **typo fixed** — reads "The Nine Lives of Ashcat", one "of". Strong lettering. Ready to promote. |
| `bg_mantel_scene` | ✅ best hub candidate — bare wall above the mantel for pinned notes, symmetrical, UI-friendly |
| `bg_mantel` | ⚠️ three candidates exist (`bg_mantel`, `_img2`, `bg_mantel_scene`); plain `bg_mantel` is a pencil sketch from the old model — discard it |
| `npc_brindle_magpie` | ✅ excellent |
| `npc_rat_boss` | ✅ excellent |
| `npc_pigeon_postmaster` | ✅ excellent |
| `ui_case_board` | ✅ good; the lower "note" spaces aren't blank, so text can't go there |
| `mock_journal` | ✅ excellent, legible English |
| `mock_chapter_select` | ✅ excellent, legible English |
| `mock_settings` | ✅ excellent, legible English |
| `ui_paw_solid` | ✅ solid fill as asked — needs background removal (ships on white) |
| `ui_paw_stamp` | ⚠️ usable, but the parchment is baked in; on a casebook page that's parchment-on-parchment |
| `ui_icon_menu` | ⚠️ fine but content fills only ~45% of canvas — crop before use |
| `sc_hollow_court_desk` | ❌ regenerated: first take drew a bedsheet ghost (contradicts `npc_clerk`) and an off-model black cat |
| `sc_shambles_day` | ❌ regenerated: first take was a sunny crowded human market, wrong tone entirely |

## B. Regenerated to fix style drift — also in `procedural/`

The audit found nine library images sharing one "full-bleed digital render"
failure mode. `tools/genart_fixes.py` and `genart_fixes2.py` re-run them with
`STRICT_STYLE`. **Verified working** — compare the new `sc_vole_stalk` and
`bg_shambles` against the originals still in `assets/library/`.

Wave 1: `sc_vole_stalk`, `bg_shambles`, `sc_over_the_fences`, `bg_gardens`,
`bg_parlor_cold`, `sc_hollow_court_desk`, `sc_shambles_day`.

Wave 2: `bg_parlor_warm`, `sc_threads_cut`, `sc_lamplighters_hall`,
`en_garden_watch`, `en_garden_watch_captain`, `en_the_unpicked`, `sk_slink`,
`sk_pounce`.

Each needs the same treatment: compare new against old, keep the better one,
file it.

## C. Known-good, no action

`bg_needle_lane`, `bg_needle_lane_wrong`, `bg_rooftop_dusk`, `bg_hollow_court`,
`sc_title`, `sc_collar`, `sc_kettle`, `sc_elspeth_still`, `en_gutter_wisp`,
`en_rag_wraith`, `en_chained_dog`, `sk_swat`, `sk_purr`, `sk_loaf`,
`sk_shelf_justice`, both anchors, both logos, all 32 UI pieces.

## D. Decisions

**Enemy framing: SCENE VIGNETTES (owner, 2026-08-03).** Enemies are drawn in
their setting — the goose on its garden wall, the dog at the end of its chain —
not as isolated figures on empty paper. `en_chained_dog` is the reference for
how this should look: subject clearly dominant in the foreground, setting
behind it dissolving into loose wash and bare paper. The paper edge stays
visible; "vignette" means *the scene fades out*, not that it bleeds to the
crop. Hold every enemy to this.

Still open:

1. **Seven UI elements have heavy transparent padding** — content fills
   26–58% of canvas (`ui_needle_pin` 26%, `ui_ash_head` 28%, `ui_paw_full`
   31%, `ui_paw_empty` 34%, `ui_button_pile` 44%, `ui_icon_intent_hand` 53%,
   `ui_icon_intent_skills` 58%). Fix by re-cropping on import, not by
   regenerating.
2. **`bg_hollow_court`'s lamp is green** — the only green light in the game,
   at the focal point. A tint pass fixes it.
3. **Skill-card character consistency needs reference images.** Words alone
   let Ash drift (`sk_slink` came back a different breed). The
   `/v1/images/edits` endpoint accepts `ref_ash.png` as a reference — that is
   the real fix, and `genart.py` doesn't support it yet.

## E. Still unmade

Nothing. The energy glyphs were never re-audited as a set (the reviewer only
got through `energy_claw`, which sits on a flat grey field rather than paper) —
worth a second look before Chapter 1 art begins.

---

*Wiring, when a batch is approved: downscale to `game/assets/` (backdrops 720,
portraits/scenes 512, UI 512, glyphs 220) and run
`godot --headless --path game --import` or the tour shows black placeholders.*
