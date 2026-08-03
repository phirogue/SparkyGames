# UI Template Prompts — for ChatGPT (copy-paste ready)

Companion to [ui-style-guide.md](ui-style-guide.md). Generates the reusable
UI kit matching the mockups in `reference/`.

## How to run these

1. **One group = one ChatGPT conversation** — it keeps a set visually
   matched. Start each conversation by pasting the STYLE CONTEXT below, then
   feed it the item prompts one at a time.
2. Always ask for **PNG with a fully transparent background** and **high
   resolution** (these render small; big source = clean downscale).
3. If a piece comes out warped, tapered, or asymmetric, regenerate — a
   crooked template repeats on every screen forever. "Same again but
   perfectly symmetric" usually fixes it.
4. Save results as `assets/library/ui/<id>.png` (create the folder). I
   slice, tune margins, and wire them into the Godot theme from there.
5. You can attach the `reference/battle screen - v2.png` mockup image at the
   start of each conversation and say "match this art style" — it helps a lot.

## STYLE CONTEXT (paste first in every conversation)

> I'm creating UI asset templates for a mobile card game with a hand-drawn
> storybook look: ink linework with muted watercolor washes, aged parchment
> in warm cream and amber tones, charcoal-grey ink, occasional stitched
> thread details (dashed "sewn" lines), cozy-gothic children's book
> aesthetic. Every asset I ask for must be: flat, front-facing, no
> perspective, no drop shadows, centered on a fully transparent background,
> high resolution PNG. Rectangular assets must be perfectly rectangular and
> symmetric so they can be stretched as UI panels. I'll ask for one asset at
> a time — keep them all visually consistent as one set.

---

## Group A — Surfaces

**`ui_page`** (the screen background):
> A tall rectangular aged parchment sheet texture in warm cream, with a decorative sewn border running around all four edges: a dashed dark-thread stitch line with small cross-stitch X marks at each corner, subtle paper grain and faint stains, slightly darker vignette toward the edges. The center must stay plain and even so text can sit on it. Perfectly rectangular and symmetric, portrait orientation.

**`ui_panel`** (general panel):
> A rectangular parchment panel in slightly lighter cream than a page background, bordered by a single clean hand-inked line with softly rounded corners, very subtle watercolor staining, plain even center. Perfectly rectangular and symmetric, landscape orientation about 3:1.

**`ui_strip`** (thin banner strip for log lines):
> A very thin wide horizontal parchment strip bordered by a fine dashed stitch line, plain center, slightly torn or deckled left and right edges. About 8:1 wide.

## Group B — Buttons & seals

**`ui_btn_amber`** (primary action — End Turn):
> A large rounded-rectangle button painted in warm amber-orange watercolor with a confident dark ink outline, subtle lighter highlight along the top edge as if lamplit, small stitch marks in the corners. Perfectly symmetric, about 4:1 wide.

**`ui_btn_parchment`** (default button):
> A rounded-rectangle parchment button with a dark ink outline and a very subtle watercolor shade at the bottom edge, plain center. Perfectly symmetric, about 3:1 wide.

**`ui_btn_dark`** (subtle action — Slip Away):
> A rounded-rectangle button painted in deep foggy blue-grey watercolor with wisps of lighter fog texture, dark ink outline, plain center. Perfectly symmetric, about 3:1 wide.

**`ui_seal_red`** (then ask for blue and gold variants):
> A round wax seal in deep red with an embossed cat paw print pressed into its center, slightly irregular hand-poured wax edges, ink-and-watercolor style.
> *(Follow-up: "Same seal, same size and style, in deep blue wax" → `ui_seal_blue`; "in old gold wax" → `ui_seal_gold`.)*

## Group C — Frames (transparent centers!)

**`ui_frame_portrait`** (enemy portraits):
> A rectangular picture frame of dark wood with worn brass corner caps, hand-inked with watercolor shading, in portrait orientation about 3:4 — the center of the frame must be fully transparent and empty. Perfectly rectangular and symmetric.

**`ui_frame_card`** (energy cards — generate 4 border colors):
> A blank playing card template in portrait orientation about 3:4: soft cream card face with gently rounded corners, a double-line hand-inked border inset from the edge in deep red, the large center area plain and empty for a glyph, a small empty name band across the bottom. Perfectly symmetric.
> *(Follow-ups, same everything except border color: "moss green" → guile, "charcoal black" → shadow, "pale silver-blue" → moonlight.)*

**`ui_frame_skill`** (skill buttons):
> A small ornate square frame with hand-inked scrollwork corners and a thin double border line, parchment-toned, center fully transparent and empty. Perfectly square and symmetric.

**`ui_ribbon`** (location/shop titles):
> A horizontal banner ribbon in cream parchment with forked swallow-tail ends and a gentle curl, dark ink outline and soft watercolor shading, plain center for text. Symmetric left-to-right, about 5:1 wide.

## Group D — Objects & icons (one conversation, one matched set)

Open with: *"Now a matched set of small UI icons, same ink-and-watercolor
style, each centered on transparent background, chunky enough to read at
32 pixels."* Then one line each:

- **`ui_thread_segment`**: > A short straight horizontal piece of twisted red embroidery thread, seamlessly tileable left-to-right (both ends cut clean at the image edge).
- **`ui_thread_fray`**: > The frayed unraveling end of a red embroidery thread, splitting into loose fibers, pointing right.
- **`ui_spool`**: > A small wooden thread spool wound with red thread, front view.
- **`ui_heart_full`**: > A small heart filled with deep red watercolor, dark ink outline.
- **`ui_heart_empty`**: > The same heart as only a faded ink outline, unfilled.
- **`ui_paw_full`**: > A small black cat paw print, solid ink.
- **`ui_paw_empty`**: > The same paw print as a faded outline only.
- **`ui_shield`**: > A small round wooden shield with an ink outline.
- **`ui_needle_pin`**: > A sewing needle angled diagonally with a short red thread through its eye, as if pinning a note to a wall.
- **`ui_button_pile`**: > A tiny pile of assorted shiny buttons and small trinkets in amber, silver and blue, glinting.
- **`ui_arrow_back`**: > A small parchment square tile with a hand-inked left-pointing arrow.
- **`ui_icon_intent_attack`**: > A small ragged ghost-sleeve swiping, ink and grey wash.
- **`ui_icon_intent_skills`**: > Small open scissors about to snip, ink drawing.
- **`ui_icon_intent_hand`**: > A small grasping shadowy hand reaching, ink and grey wash.
- **Medallions** (6): > A set of six small round achievement medallions, same size and rim style: one with a laurel medal, one crescent moon, one pocket watch, one shield, one trophy cup, one quill pen. Bronze-toned ink and watercolor.

*Humour glyphs (claw / cat eye / smoke / moon-through-needle) are already
prompted in [art-manifest.md](art-manifest.md) Batch 5 — generate them in
this same conversation so they match the set.*

## Group E — reminder (Kling, not ChatGPT)

**`bg_mantel_empty`** — the hub scene, generated in Kling with the usual
style block: the stone fireplace wall from the mockup with two oil lamps and
a hearth, but the mantel **bare** (no notes, no letters, no papers) and the
hearth **empty** — the game pins live quest notes and shop panels on top.

---

## Priority order

**A first** (check parchment in-game before anything else) → **B** →
**D thread/spool/hearts/paws** (battle status row) → **C** → rest of D →
**E**. Phase 1 of the build needs only Groups A and B.
