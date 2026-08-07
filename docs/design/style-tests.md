# Art Style Tests — Kling Prompts (copy-paste ready)

> **DECIDED — historical record.** The bake-off that locked Style A on
> 2026-07-29. Kept as the evidence behind a settled decision; the live
> style block is `STRICT_STYLE` in `tools/genart.py`.
> Index: [ART-INDEX.md](ART-INDEX.md).


> **DECIDED 2026-07-29: Style A (Storybook Ink & Wash) wins.** The locked
> style block and the full production prompt list live in
> [art-manifest.md](art-manifest.md). This doc is kept as history.

Goal: pick ONE style for the whole game before mass-generating assets. Below
are **6 candidate styles × 3 test subjects** (18 prompts). Generate at least
the *Ash portrait* for all six styles first — that alone may decide it. Then
run the other two subjects for your top 2–3 styles.

**How to run these in Kling (image generation):**
- Use the *Image* tab, paste the prompt as-is.
- Aspect ratio: **3:4** for the portrait and card scene, **9:16** for the
  backdrop (our game is portrait).
- Generate 2–4 per prompt; keep the best; name files
  `style-<letter>-<subject>.png` (e.g. `style-a-ash.png`) and drop them in
  `assets/incoming/style-tests/`.

**The three test subjects** (same across all styles so comparison is fair):
1. **Ash portrait** — our hero: a lean black cat with ember-orange eyes and a
   frayed red collar.
2. **Card scene** — the "Pounce" skill card art: the cat mid-leap at a
   glowing wisp.
3. **Backdrop** — Needle Lane: a foggy gaslamp street at night.

What to judge: Does Ash look like a *character* (not a photo of a cat)? Does
the mood say "wry, a little cute, secretly sad"? Will it stay readable at
phone size? Can you imagine 200 images in this style feeling consistent?

---

## Style A — Storybook Ink & Wash
*Classic pen-and-ink with muted watercolor washes. The "illustrated novel" look. Ages beautifully, hides AI artifacts well.*

**A1 — Ash portrait:**
> Storybook ink and watercolor illustration of a lean black cat with glowing ember-orange eyes and a frayed red collar, sitting upright with quiet dignity on a rooftop at dusk, loose expressive ink linework, muted watercolor washes in charcoal grey and warm amber, soft fog, hand-drawn children's book style with a melancholy mood, textured paper background, no text

**A2 — Card scene (Pounce):**
> Storybook ink and watercolor illustration of a black cat with ember-orange eyes leaping dramatically through the air with claws out toward a small glowing blue wisp of light, dynamic diagonal composition, loose ink linework, muted watercolor washes, dark alley background with warm lantern glow, hand-drawn fairytale book style, textured paper, no text

**A3 — Backdrop (Needle Lane):**
> Storybook ink and watercolor illustration of a narrow foggy cobblestone street at night lined with crooked gaslamps and leaning Victorian houses, warm amber lamplight against blue-grey fog, empty street, melancholy fairytale mood, loose ink linework with muted watercolor washes, hand-drawn children's book style, vertical composition, no text

## Style B — Dark Whimsical (Coraline / Laika)
*Stop-motion-feel gothic cuteness. Big expressive eyes, exaggerated proportions, spooky-cozy.*

**B1 — Ash portrait:**
> Dark whimsical stop-motion style character portrait of a slender black cat with oversized glowing amber eyes and a frayed red collar, slightly exaggerated elongated proportions, standing on a moonlit rooftop, gothic fairytale atmosphere, deep blues and purples with one warm orange accent, handcrafted felt and clay texture feel, Coraline-inspired spooky-cozy mood, cinematic soft lighting, no text

**B2 — Card scene (Pounce):**
> Dark whimsical stop-motion style illustration of a slender black cat with oversized amber eyes pouncing through the air at a small glowing wisp spirit, exaggerated dynamic pose, gothic alley with crooked walls behind, deep blue and purple palette with warm orange glow accents, handcrafted puppet texture feel, spooky-cozy fairytale mood, cinematic rim lighting, no text

**B3 — Backdrop (Needle Lane):**
> Dark whimsical stop-motion style environment of a crooked foggy Victorian street at night, leaning houses with glowing windows, twisted gaslamps, cobblestones, deep blues and purples with warm amber window light, handcrafted miniature set feel, Coraline-inspired gothic fairytale mood, vertical composition, empty street, no text

## Style C — Painterly Gouache (Ghibli-adjacent)
*Soft matte gouache painting, warm and atmospheric. The coziest option; strongest emotional range.*

**C1 — Ash portrait:**
> Gouache painting of a lean black cat with warm amber eyes and a frayed red collar sitting on a chimney at golden dusk, soft matte brushstrokes, Studio Ghibli inspired warmth, painterly clouds and rooftops behind, gentle melancholy mood, muted earthy palette with warm golden light, storybook animation concept art style, no text

**C2 — Card scene (Pounce):**
> Gouache painting of a black cat leaping through the air with claws extended toward a small glowing blue spirit wisp, soft matte painterly brushstrokes, Studio Ghibli inspired animation concept art, night alley with warm lantern light and cool shadows, dynamic motion, gentle painterly texture, no text

**C3 — Backdrop (Needle Lane):**
> Gouache painting of a foggy gaslamp street at night, narrow cobblestone lane with old crooked houses and warm glowing windows, blue-grey fog with pools of amber lamplight, Studio Ghibli inspired background art, soft matte brushstrokes, quiet melancholy atmosphere, vertical composition, empty street, no text

## Style D — Etched Gothic (Gorey / vintage engraving, with color)
*Fine crosshatched linework like an old etching, limited color. The wittiest, most "literary" option — matches the wry narrator perfectly, but the least cute.*

**D1 — Ash portrait:**
> Vintage etching style illustration of an elegant black cat with piercing pale amber eyes and a frayed red collar, fine crosshatched engraving linework, Edward Gorey inspired gothic pen illustration, mostly black ink on cream paper with only the red collar and amber eyes in color, dry wit and quiet dignity in the cat's expression, Victorian mood, no text

**D2 — Card scene (Pounce):**
> Vintage etching style illustration of a black cat leaping at a small glowing wisp of light, fine crosshatched engraving linework, Edward Gorey inspired gothic illustration, black ink on cream paper with selective color only on the cat's amber eyes and the wisp's blue glow, dramatic Victorian composition, no text

**D3 — Backdrop (Needle Lane):**
> Vintage etching style illustration of a foggy Victorian street at night with gaslamps and crooked row houses, fine crosshatched engraving linework, Edward Gorey inspired gothic pen illustration, black ink on cream paper with selective warm amber color only in the lamplight and windows, ominous but elegant mood, vertical composition, no text

## Style E — Modern Game Painterly (Hearthstone / Cult of the Lamb energy)
*Saturated, punchy, high-contrast digital painting built for small screens. The most "game-looking" option; reads perfectly at card size.*

**E1 — Ash portrait:**
> Stylized digital game art portrait of a sleek black cat character with large expressive glowing orange eyes and a frayed red collar, confident smug expression, bold shapes and clean silhouette, rich saturated colors, dramatic rim lighting against a moonlit rooftop, polished card game illustration style, high contrast, painterly rendering, no text

**E2 — Card scene (Pounce):**
> Stylized digital card game illustration of a sleek black cat mid-pounce with claws out, lunging at a glowing blue wisp spirit, dynamic action pose with motion energy, bold shapes, rich saturated colors, dramatic lighting with strong rim light, polished collectible card art style, high contrast and readable silhouette, no text

**E3 — Backdrop (Needle Lane):**
> Stylized digital game environment art of a foggy gaslamp street at night, bold shapes and dramatic lighting, warm amber gaslamps cutting through blue fog, crooked Victorian houses, rich saturated painterly style, polished mobile game background, strong depth and atmosphere, vertical composition, empty street, no text

## Style F — Paper-Cut / Shadow Theatre
*Layered paper silhouettes with glowing backlight. The most distinctive and ownable look; thematically perfect (shadows are our lore) but the biggest artistic risk.*

**F1 — Ash portrait:**
> Layered paper cut art of a black cat silhouette with glowing amber cutout eyes and a red paper collar, sitting on a rooftop, shadow theatre style with warm light glowing from behind layered paper clouds and moon, deep blue and black paper layers with golden backlight, handcrafted papercraft diorama feel, elegant and mysterious, no text

**F2 — Card scene (Pounce):**
> Layered paper cut art of a black cat silhouette leaping at a glowing paper wisp, shadow theatre style, dynamic diagonal composition, layered deep blue and black paper with warm golden light glowing between the layers, handcrafted papercraft diorama, dramatic backlit scene, no text

**F3 — Backdrop (Needle Lane):**
> Layered paper cut art of a foggy Victorian street at night, shadow theatre style with crooked house silhouettes in layered dark blue paper, glowing amber gaslamps and windows as warm backlit cutouts, misty depth between paper layers, handcrafted diorama feel, vertical composition, no text

---

## After you pick

Tell me the winning style (and any tweaks — "C but darker", "E but less
saturated"). I'll then:
1. Lock a reusable **style block** appended to every future prompt.
2. Write the full **art manifest** for the Prologue + Chapter 1 (~50 images)
   in that style, batched in generation order.
3. We'll also test **character consistency** in the winner (Kling supports
   reference images — we'll use your best Ash as the anchor for every Ash
   image after).
