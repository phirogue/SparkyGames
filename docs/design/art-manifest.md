# Art Manifest — Style A (Storybook Ink & Wash), Kling prompts (v2)

**Style locked 2026-07-29: Style A.** Rewritten 2026-07-30 for how Kling
actually behaves.

## Ground rules (learned the hard way)

1. **Every prompt is standalone.** Kling has no memory between generations —
   no prompt below refers to any other image in words.
2. **Prompts are kept simple.** Kling fumbles fiddly specifics (which finger
   a thimble is on, exactly what hangs on a wall). Each prompt pushes only
   3–5 strong elements. If a generation keeps failing on one detail, **drop
   the detail** — I'd rather have a clean image than a fought-over one.
3. **Reference images do the consistency work, not words.** Each item below
   has a **Reference:** line saying exactly which file to attach in Kling's
   reference/subject slot. `—` means attach nothing.
4. **Variants are made in-engine, not in Kling.** We generate ONE parlor, one
   Needle Lane, etc. Cold/night/ruined versions come from tinting, lighting,
   and overlays in Godot. Never ask Kling for "the same room but X."
5. Save picks as `assets/incoming/<id>.png`. Generate 2–4 candidates each;
   keep the simplest good one (these render at phone size).

**Style block** — the same final sentence is baked into every prompt below:

> storybook ink and watercolor illustration, loose ink linework, muted
> watercolor washes in charcoal grey and warm amber, hand-drawn children's
> book style, textured cream paper, no text

**Aspect ratios:** backdrops 9:16 · characters & scenes 3:4 · skill art 1:1.

---

## Batch 0 — The two anchors (do these FIRST, alone)

These two files become the reference images for almost everything else. Spend
your patience here — regenerate until you *love* them.

### `ash_ref` — AR 3:4 — Reference: —
> A lean black cat with glowing orange eyes and a frayed red collar, sitting upright with dignity, tail wrapped around its paws, full body, plain pale background, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `elspeth_ref` — AR 3:4 — Reference: —
> An elderly witch with silver hair in a bun and small round spectacles, wearing a patched shawl with glowing silver embroidery, sitting in an armchair with sewing in her lap, warm lamplight, kind sharp face, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

---

## Batch 1 — Backdrops (AR 9:16, no references needed)

### `bg_rooftop_dusk` — Reference: —
> Crooked slate rooftops and chimney pots at golden dusk, a fairytale city sloping down toward a dark lake, warm amber light and long blue shadows, empty sky in the upper third, no people, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `bg_needle_lane` — Reference: —
> A narrow foggy cobblestone street at night with crooked gaslamps and leaning old row houses, warm lamplight glowing through blue-grey fog, empty and quiet, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

*(In-engine variants: "wrong quiet" = desaturate + one lamp masked dark.)*

### `bg_parlor` — Reference: —
> A cozy cluttered witch's cottage room with a worn armchair, a small iron stove with a copper kettle, spools of thread and hanging herbs, warm golden lamplight, lived-in and loved, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

*(In-engine variants: cold/murder-night parlor = blue tint, dimmed lamp glow,
engine-drawn cut-thread overlay sprites. One generation covers both.)*

### `bg_hollow_court` — Reference: —
> A vast dim underground archive of towering bookshelves fading into darkness, one small wooden desk lit by a single green desk lamp in the center, dust in the lamplight, solemn and endless, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

---

## Batch 2 — Enemies & NPCs (AR 3:4)

### `en_gutter_wisp` — Reference: —
> A small mischievous spirit made of pale blue flame with two hungry little eyes, the size of a bottle, hovering above wet cobblestones at night, faint blue glow beneath it, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `en_chained_dog` — Reference: —
> A big scruffy guard dog barking at the end of a taut chain, huge chest and wild eyes, slightly comic, night yard behind it, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `en_rag_wraith` — Reference: —
> A ghost made of empty floating clothes, a long coat and scarf and gloves moving as if worn by an invisible person, hollow hood with no face, drifting in fog above cobblestones, eerie, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `en_the_unpicked` — Reference: —
> A tall looming figure woven entirely from glowing silver threads, vaguely human silhouette with long loose thread-ends trailing away, standing in a dark doorway, beautiful and wrong, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `npc_clerk` — Reference: —
> A prim translucent grey ghost clerk in an old-fashioned suit and pince-nez spectacles, seated at a wooden desk holding a rubber stamp, expression of fussy professional disapproval, lit by a green desk lamp, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

---

## Batch 3 — Story scenes (AR 3:4 — **attach references as listed**)

### `sc_ash_vole_gift` — Reference: **ash_ref.png**
> A lean black cat with orange eyes and a red collar trotting proudly along a rooftop ridge at dusk carrying a small vole in its mouth, tail high, very pleased with itself, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `sc_elspeth_still` — Reference: **elspeth_ref.png**
> An elderly witch with silver hair and round spectacles sitting very still in an armchair in a cold moonlit room, eyes closed, sewing fallen to the floor beside her, quiet and sorrowful, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `sc_kettle` — Reference: **ash_ref.png**
> A black cat with a red collar stretching up on its hind legs to push a steaming copper kettle off a small stove, moonlit kitchen, determined little face, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `sc_collar` — Reference: —
> A frayed red cat collar with a small brass bell lying on a wooden sewing table beside a pincushion and a spool of silver thread, thin moonlight, quiet still life, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `sc_title` — Reference: **ash_ref.png** — AR 9:16
> A black cat with glowing orange eyes and a red collar standing on a moonlit rooftop looking over a foggy gaslamp city, a single thin silver thread trailing from its chest out over the rooftops, lonely and brave, empty space in the upper third, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

---

## Batch 4 — Skill card art (AR 1:1 — **attach ash_ref.png to ALL of these**)

### `sk_pounce` — Reference: **ash_ref.png**
> A black cat with orange eyes leaping through the air with claws out, dynamic pose, night rooftop behind, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `sk_swat` — Reference: **ash_ref.png**
> A calm black cat sitting still while one front paw strikes out in a blur of motion, composed face, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `sk_slink` — Reference: **ash_ref.png**
> A black cat melting into a pool of shadow under a gaslamp, only its orange eyes and red collar visible in the dark shape, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `sk_purr` — Reference: **ash_ref.png**
> A black cat curled in a neat sleeping circle with gentle silver threads of light rising from its fur, warm and peaceful, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `sk_loaf` — Reference: **ash_ref.png**
> A black cat in a perfect bread loaf pose with all paws tucked under its body, eyes half closed, serene and immovable, faint silver shimmer around it, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `sk_shelf_justice` — Reference: **ash_ref.png**
> A black cat on a high shelf pushing a porcelain jug over the edge with one paw while looking directly at the viewer, the jug falling, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

### `sk_scratch` — Reference: **ash_ref.png**
> A black cat's paw swiping quickly with three thin ink slash marks in the air, simple composition with lots of empty paper, storybook ink and watercolor illustration, loose ink linework, muted watercolor washes in charcoal grey and warm amber, hand-drawn children's book style, textured cream paper, no text

---

## Batch 5 — Humour energy glyphs (AR 1:1) — **use ChatGPT, not Kling**

Icons need precision and transparency — that's ChatGPT's strength. Ask ChatGPT
for each, in one session so it keeps them matched (a matched set is the goal;
regenerate the odd one out):

1. "A simple hand-inked emblem of a single curved cat claw, warm ember
   red-orange watercolor wash, centered on a transparent background, flat
   storybook icon style, no text."
2. Same instruction, but: "a half-closed knowing cat eye, moss green."
3. Same instruction, but: "a cat silhouette dissolving into smoke, charcoal
   black."
4. Same instruction, but: "a crescent moon threaded through a needle's eye,
   pale silver-blue."

---

## Status tracker

| id | batch | status |
|---|---|---|
| ash_ref | 0 | ☐ |
| elspeth_ref | 0 | ☐ |
| bg_rooftop_dusk | 1 | ☐ |
| bg_needle_lane | 1 | ☐ |
| bg_parlor | 1 | ☐ |
| bg_hollow_court | 1 | ☐ |
| en_gutter_wisp | 2 | ☐ |
| en_chained_dog | 2 | ☐ |
| en_rag_wraith | 2 | ☐ |
| en_the_unpicked | 2 | ☐ |
| npc_clerk | 2 | ☐ |
| sc_ash_vole_gift | 3 | ☐ |
| sc_elspeth_still | 3 | ☐ |
| sc_kettle | 3 | ☐ |
| sc_collar | 3 | ☐ |
| sc_title | 3 | ☐ |
| sk_pounce | 4 | ☐ |
| sk_swat | 4 | ☐ |
| sk_slink | 4 | ☐ |
| sk_purr | 4 | ☐ |
| sk_loaf | 4 | ☐ |
| sk_shelf_justice | 4 | ☐ |
| sk_scratch | 4 | ☐ |
| hu_ferocity..moonlight | 5 | ☐ (ChatGPT) |

Chapter 1's prompts get added here after Batch 0–2 confirm the reference
workflow holds.
