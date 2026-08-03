# Art Style Audit — the whole library, 2026-08-03

*Read-only history. Every image in `assets/library/` was viewed against the
locked style block and the two approved anchors (`ref_ash`, `ref_elspeth`).
Written after the first API-generated batch, which is what made a full audit
affordable.*

## The headline: there are two art styles in this game, not one

The library splits cleanly into two clusters that share almost no visual DNA.
This is the single biggest art problem in the project, and it is invisible
when you look at images one at a time — it only shows up side by side.

**Cluster A — "the paper cluster" (correct).** Visible cream watercolor paper,
often with a torn deckle edge. Loose scratchy ink linework sitting *on top of*
the wash. Muted granulated washes with large areas of untouched paper. Warm
amber used sparingly as an accent against blue-grey. Detail is selective —
the subject is drawn and the background dissolves.

Members: both anchors, `bg_needle_lane`, `bg_needle_lane_wrong`,
`bg_rooftop_dusk`, `bg_hollow_court`, `sc_title`, `sc_collar`, `sc_kettle`,
`sc_elspeth_still`, `en_gutter_wisp`, `en_rag_wraith`, `en_the_unpicked`,
`en_chained_dog`.

**Cluster B — "the full-bleed digital cluster" (wrong).** Three tells appear
together and appear nowhere in Cluster A:

1. **Edge-to-edge crop** with no paper margin at all.
2. **A mosaic / scale-like stipple texture** on flat surfaces — an AI
   rendering artifact, not watercolor granulation.
3. **Crushed true-black darks.** Watercolor never does this; shadows in
   Cluster A stay transparent.

Plus smooth airbrushed blending and uniformly high detail with nothing
receding.

Members: `bg_parlor_warm`, `bg_parlor_cold`, `bg_shambles`, `bg_gardens`,
`sc_threads_cut`, `sc_lamplighters_hall`, `sc_over_the_fences`,
`en_garden_watch`, `en_garden_watch_captain`.

Because the tells co-occur so precisely, Cluster B is almost certainly **one
generation batch from one tool or preset**. That is good news: it is a
preset problem, not nine independent mistakes.

## Why the old style block failed

The locked style block describes what we want but never forbids what we kept
getting. "Ink linework with muted watercolor washes" is satisfiable by a
digital painting that imitates the look. The fix, now in
`tools/genart_fixes.py` as `STRICT_STYLE`, names the failure modes as explicit
negatives: no digital painting, no airbrushed blending, no crushed blacks, no
stipple on flat surfaces, no uniform edge-to-edge detail, and it demands
visible paper grain and a deckle edge.

## Per-image findings worth keeping

**The parlor is the worst-felt problem.** `bg_parlor`, `bg_parlor_warm` and
`bg_parlor_cold` are the same room rendered three different ways (watercolor,
digital warm, digital cold). It is the location the player returns to most,
so the inconsistency is the most visible defect in the game.

**`bg_needle_lane` → `bg_needle_lane_wrong` is the correct recipe for a
variant**: same drawing, same medium, warmth selectively withdrawn. The story
reads as *story*, not as style drift. Apply this to the parlor pair rather
than generating cold rooms from scratch.

**Framing is undecided for enemies.** `en_chained_dog` is a scene vignette;
the anchors are isolated figures on empty paper. Both appear in the same
battle UI slot, so one will look matted and the other like a photo. Pick one
convention and hold every enemy to it.

**Two canon defects, not style defects:**

- `en_the_unpicked` contains **a human girl in the foreground** who is in no
  prompt and no design doc. It is an enemy portrait; it should be the
  Unpicked alone.
- The first `sc_hollow_court_desk` generation drew the ghost clerk as a
  **floating bedsheet**, contradicting `npc_clerk` (a prim ghost in an
  old-fashioned suit with pince-nez), and added an un-neckerchiefed black cat
  that reads as Ash but is off-model.

**One palette outlier:** `bg_hollow_court`'s focal light is **green** (a
banker's lamp) — the only green light source in the library, breaking the
warm-amber rule at the exact point the eye lands.

## UI: measured, not eyeballed

`assets/library/ui/` was checked programmatically with Pillow rather than by
eye, which is the reliable way to catch the two hazards in engineering law #3.

- **Opaque backgrounds: none.** All 32 UI files carry real alpha. This hazard
  is clear.
- **Transparent padding: seven offenders.** Content bounding box as a share of
  canvas: `ui_needle_pin` 26%, `ui_ash_head` 28%, `ui_paw_full` 31%,
  `ui_paw_empty` 34%, `ui_button_pile` 44%, `ui_icon_intent_hand` 53%,
  `ui_icon_intent_skills` 58%. These render small for their box unless the
  content region is detected and the art re-cropped on import.

Re-run that check after any UI art change:

```
python -c "from PIL import Image; ..."   # see the audit commit, or tools/
```

## Recommended order of work

1. Regenerate Cluster B with `STRICT_STYLE` — seven library files plus the two
   geese. Highest leverage: one preset fix repairs nine images.
2. Fix the two canon defects (`en_the_unpicked`, `sc_hollow_court_desk`).
3. Decide the enemy framing convention and hold to it.
4. Re-crop the seven padded UI elements on import rather than regenerating.
5. Recolor `bg_hollow_court`'s lamp to brass/amber — a tint pass, not a
   regeneration.
