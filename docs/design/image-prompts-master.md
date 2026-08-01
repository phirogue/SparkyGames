# Master Image Prompt List — everything to generate (ChatGPT)

*2026-07-31. The single source of truth for image generation. Every prompt
ends with its aspect ratio. Save results to `assets/incoming/<id>.png`
(UI pieces to `assets/incoming/ui/`). Anything not yet generated shows
in-game as a black box describing itself, so you can see gaps by playing.*

**Paste this style context first in each conversation (or attach an existing
scene image and say "match this style"):**

> Hand-drawn storybook illustration style: ink linework with muted watercolor
> washes, warm amber light against blue-grey fog, cozy-gothic children's book
> aesthetic, high resolution, no text in the image.

Backgrounds don't need transparency (I crop/remove programmatically).
Generate at the largest size offered — I downscale on import.

---

## A. Branding (do these first — the game literally opens with them)

**`logo_sparkygames`** — ✅ GENERATED 2026-08-01, wired into the splash.

**`logo_ashcat_title`** — ⚠️ REGENERATE: the 2026-08-01 version reads "The
Nine Lives of **of** Ashcat" (doubled "of") — unusable for store/title.
Re-run the prompt below; consider adding: 'exactly the words "The Nine
Lives of Ashcat", check spelling carefully'.

**`logo_sparkygames`** original prompt — the studio splash:
> A charming hand-drawn studio logo emblem for a game studio called SparkyGames: a small ember-orange spark or flame with a curled cat tail silhouette wrapped around it, inside a simple round ink-drawn badge, warm amber and charcoal palette, storybook ink and watercolor style, clean readable silhouette that works small, centered on a plain dark background, no text. Aspect ratio: 1:1.

**`logo_ashcat_title`** — the game's title treatment (for the title card and store listing; text IS wanted here, ChatGPT handles short text well):
> A hand-lettered game logo reading "The Nine Lives of Ashcat" in elegant slightly-gothic storybook lettering, ink and watercolor style, with a small black cat silhouette curled around the letters and a thin silver thread winding through them, warm cream and charcoal with one ember-orange accent, on a plain dark background, high contrast, readable at small sizes. Aspect ratio: 16:9.

## B. Prologue content gaps (black boxes in the current build)

**`en_the_vole`** — the tutorial's first "enemy":
> A small fat smug vole standing by a chimney pot on rooftop tiles at dusk, utterly unaware it is being hunted, slightly comic, warm last light, storybook ink and watercolor character portrait. Aspect ratio: 3:4.

**`sc_vole_stalk`** — the hunt intro scene *(attach ref_ash.png)*:
> A black cat with a red neckerchief pressed low against rooftop tiles at dusk, pupils wide, hindquarters raised in the pre-pounce wiggle, stalking a small unaware vole near a chimney pot a short distance away, warm last light. Aspect ratio: 3:4.

**`sc_lamplighters_hall`** — decision branch A:
> The interior of a lamplighters' guild hall at night, abandoned mid-shift: ladders racked on the wall, long lighting-poles in their stands, a kettle gone cold on a small stove, one silver thread caught glinting on a brass lamp-hook in the foreground. Nobody there. Aspect ratio: 3:4.

**`sc_over_the_fences`** — decision branch B *(attach ref_ash.png)*:
> A black cat with a red neckerchief in full sprint leaping between fence tops and garden walls at night, motion-blurred fog, rooftops and one dark window ahead, urgency and grace. Aspect ratio: 3:4.

**`bg_shambles`** — worldbuilding scene + later quests:
> A night view over a sleeping market district: crooked timber shopfronts, market stalls under canvas covers, hanging shop signs, one lit lantern down the lane, fog pooling between the buildings. Aspect ratio: 3:4.

**`bg_gardens`** — the stealth-quest district:
> Moonlit walled back gardens behind row houses: vegetable beds, a greenhouse, laundry lines, clipped hedges casting deep shadows, a sleeping house beyond a fence. Aspect ratio: 3:4.

## C. Quest enemies (post-prologue, currently black boxes)

**`en_wisp_pair`**:
> Two small mischievous spirits made of pale blue flame hovering shoulder to shoulder over wet cobblestones, clearly conspiring, four hungry little eyes, faint blue glow beneath them. Aspect ratio: 3:4.

**`en_garden_watch`**:
> A large white goose standing guard in a moonlit garden, chest puffed, wings slightly raised, radiating self-importance and menace, slightly comic. Aspect ratio: 3:4.

**`en_garden_watch_captain`**:
> A large imperious white goose wearing a tiny ceremonial chain of office around its neck, standing on a garden wall at night like a commander reviewing troops, menacing and absurd. Aspect ratio: 3:4.

## D. Small UI stragglers

**`ui_ash_head`** *(attach ref_ash.png)*:
> A tiny emblem of a black cat's face with a red neckerchief, front view, simple bold shapes readable at 32 pixels, ink and watercolor, centered on a plain background. Aspect ratio: 1:1.

## E. UI screen mockups (look-and-feel references, like the battle/mantel mockups)

*These are design references I rebuild in code — gibberish text in them is
fine. One conversation, attach `reference/battle screen - v2.png` and say
"same game, same style".*

**`mock_journal`** — the Casebook (journal + glossary):
> A mobile game journal screen mockup, portrait, storybook parchment style matching the attached battle screen: an open leather-cornered casebook page titled like a detective's journal, left-aligned handwritten-style entries with small ink icons (a paw print, a wax seal, a thread), tabs at the top shaped like leather bookmarks labeled for deeds and knowledge, a small back arrow in a parchment square top-left, stitched border around the page. Aspect ratio: 9:16.

**`mock_loadout`** — deck & skills at the long rest:
> A mobile game loadout screen mockup, portrait, storybook parchment style: a sewing table seen from above with the cat's kit laid out — a row of four skill cards in ornate frames at top, below them energy cards arranged by color in four small stacks (red, green, black, silver-blue) with counts, a needle and thread beside them, an amber confirm button at the bottom, stitched border. Aspect ratio: 9:16.

**`mock_chapter_select`** — the case files:
> A mobile game chapter select mockup, portrait, storybook style: a wooden drawer of case files seen from above, manila folders with wax seals and short handwritten labels, the first folder open showing a small illustration and a progress stamp, later folders tied shut with red thread, stitched parchment border. Aspect ratio: 9:16.

**`mock_settings`**:
> A mobile game settings screen mockup, portrait, storybook parchment style: a short list of options as hand-inked rows with small icons (a bell for sound, a music note, a candle for brightness, a letter for language), each with a thread-and-toggle switch drawn as a button sewn on or off, stitched border, small back arrow top-left. Aspect ratio: 9:16.

**`mock_achievements`**:
> A mobile game achievements screen mockup, portrait, storybook style: rows of round bronze medallions on parchment, some polished and colorful, some faded grey and unearned, each with a short label space beside it, a scroll ribbon header, stitched border. Aspect ratio: 9:16.

## F. Post-prologue scene art (Chapter 1 — generate when credits allow)

**`bg_mantel_scene`** — the hub's full illustrated fireplace (from the
original Group E plan; the current hub is plain):
> A stone fireplace wall in a witch's parlor at night: a wide stone mantelpiece with two lit oil lamps, a cold hearth below, wall space above the mantel bare (notes will be pinned there by the game), moody blue shadows with warm lamplight pools. No papers or notes anywhere. Aspect ratio: 9:16.

**`sc_hollow_court_desk`** *(the Clerk portrait exists; this is the wide scene)*:
> A vast dim underground records office: towering bookshelves fading up into darkness, one small wooden desk with a green-shaded lamp and a translucent grey ghost clerk seated behind it, a single cat-sized chair opposite, dust in the lamplight. Aspect ratio: 3:4.

---

## Generation order

1. **A (branding)** — the game opens with these.
2. **B (prologue gaps)** — removes every black box from the tutorial.
3. **C (quest enemies)** — removes black boxes post-prologue.
4. **E (UI mockups)** — unlocks the next screens' look.
5. **D, F** — polish.
