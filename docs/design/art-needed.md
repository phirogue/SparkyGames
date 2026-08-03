# Art Still Needed — living checklist

*Updated 2026-08-02. This is the CURRENT to-generate list; the full prompt
archive with everything already made lives in
[image-prompts-master.md](image-prompts-master.md). Save results to
`assets/incoming/<id>.png`. Every prompt ends with its aspect ratio.*

**Good news:** every image the game references today exists — enemies,
backdrops, story scenes, skills, glyphs, both logos. Nothing renders as a
black box. Everything below is either a fix, a polish, or Chapter-1 prep.

**Paste this style context first (or attach an existing scene and say
"match this style"):**

> Hand-drawn storybook illustration style: ink linework with muted
> watercolor washes, warm amber light against blue-grey fog, cozy-gothic
> children's book aesthetic, high resolution, no text in the image.

---

## A. Fixes (highest value)

**1. `logo_ashcat_title` — REGENERATE (typo).** The current title art
reads "The Nine Lives of **of** Ashcat" and is live in the game. Same
prompt as before; add: *exactly the words "The Nine Lives of Ashcat",
check the spelling carefully*:
> A hand-lettered game logo reading "The Nine Lives of Ashcat" in elegant
> slightly-gothic storybook lettering, ink and watercolor style, with a
> small black cat silhouette curled around the letters and a thin silver
> thread winding through them, warm cream and charcoal with one
> ember-orange accent, on a plain dark background, high contrast,
> readable at small sizes. Aspect ratio: 9:16.

**2. `ui_paw_solid` — the paw action icon.** The kit's paw came out as a
faint speckled outline, so the game currently draws its own pips. A solid
version replaces the drawn one everywhere:
> A single cat paw print icon, SOLID dark walnut-brown ink fill like a
> real inked paw stamp, slightly rough hand-pressed edges, on a plain
> white background, simple and readable at small sizes, no outline-only
> areas, no text. Aspect ratio: 1:1.

## B. The Mantel (hub) — the one screen without its painting

**3. `bg_mantel`:**
> A cozy witch's parlor at night seen from a cat's height: a stone
> fireplace with a wooden mantelpiece holding small objects (a key, a
> sealed letter, a little bell), embers glowing low, an armchair with a
> knitted blanket, moonlight through a window, warm amber and blue-grey,
> hand-drawn storybook ink and watercolor, no people, no cat, no text.
> Aspect ratio: 9:16.

## C. The Casebook & Case board (journal features next in line)

**4. `ui_paw_stamp`** — Ash "signs" his deeds:
> A black cat's paw print stamped in dark ink on aged parchment, slightly
> smudged at one edge as if the paw lifted quickly, storybook style.
> Aspect ratio: 1:1.

**5. `ui_case_board`** — the murder-case (Clue) board backing:
> An old corkboard page inside a leather casebook: three empty
> rectangular portrait spaces at top connected by red thread and brass
> pins, smaller empty note spaces below, ink annotations too small to
> read, aged parchment, hand-drawn storybook style, no faces, no
> readable text. Aspect ratio: 3:4.

## D. Chapter 1 cast (guild faces — needed as Ch1 quests get built)

**6. `npc_brindle_magpie`** — the Magpie Exchange's proprietor:
> A sly, charming magpie perched on a heap of buttons, keys, rings and
> one pocket-watch, head tilted appraisingly, one eye catching lantern
> light, inside a cluttered night-market stall, hand-drawn storybook ink
> and watercolor, cozy-gothic, no text. Aspect ratio: 3:4.

**7. `npc_rat_boss`** — the Rats Under the Floor:
> A portly, dignified old rat in a waistcoat made of stitched scraps,
> seated on a cotton-reel throne under the floorboards, candle-lit,
> holding a grain of wheat like a scepter, wry not sinister, storybook
> ink and watercolor, no text. Aspect ratio: 3:4.

**8. `npc_pigeon_postmaster`** — the Pigeon Post:
> A rumpled city pigeon wearing a tiny leather message-satchel, standing
> at attention on a rooftop ledge post among sleeping pigeons, dawn fog,
> one nervous eye, storybook ink and watercolor, no text.
> Aspect ratio: 3:4.

## E. Nice-to-have (no rush; drawn stand-ins work today)

**9. `ui_icon_menu`** — the corner settings button (currently three drawn
lines):
> A small round hand-drawn icon of three short horizontal stitched lines
> like sewn seams, dark walnut ink on a small parchment circle,
> storybook style, reads clearly at 32 pixels, no text.
> Aspect ratio: 1:1.

**10. `sc_shambles_day`** — a day variant for future scenes (ChatGPT:
attach the existing `bg_shambles` and ask for "the same market street,
midday, busy"):
> Aspect ratio: 3:4.

---

*When a batch lands: drop files in `assets/incoming/`, then in-game
wiring is: downscale to `game/assets/` (backdrops 720, portraits/scenes
512, UI 512, glyphs 220) and run the import pass. Check items off here
as they ship.*
