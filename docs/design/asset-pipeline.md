# Asset Pipeline — Images, Music, SFX, Animation

*2026-07-29. Owner has active credits on: **ChatGPT** and **Kling** (no
Midjourney after all — correction 2026-07-29). Budget stance: free where
possible, no new subscriptions yet.*

> **Correction (final, 2026-08-02):** Midjourney is out entirely. **ChatGPT**
> generates all stills (card art, portraits, scenes, backdrops, icons) and
> **Kling** handles motion (image-to-video on our stills). Kling also
> supports reference images for character consistency, which covers the
> consistency strategy. Style test prompts: [style-tests.md](style-tests.md).
> Commercial-use note: both tools must be on paid/commercial tiers; keep
> dated copies of each tool's commercial terms in `docs/publishing/`
> (Kling's free tier does not include commercial rights; paid memberships
> do).

## Summary: who makes what

| Asset type | Tool | Cost | Notes |
|---|---|---|---|
| Card art, character portraits, scene/story art, district backdrops | **ChatGPT** image gen (owner generates) | Already paid | The workhorse. Paid plan = commercial rights. I write prompt manifests, owner runs them |
| Icons, UI elements, transparent-background sprites, quick mockups | **ChatGPT** image gen (owner) | Already paid | Best at following exact instructions ("flat icon, transparent background, 3 sizes") and doing edits/variations of an existing image |
| Trailer, store-listing video, animated splash | **Kling** (owner) | Existing credits | Image-to-video on our best ChatGPT stills. For marketing only — no video files in-game |
| In-game animation (card plays, hits, purring, sunbeams) | **Godot itself** | Free | Tweens, particles, 2D shaders on static art. This is how the whole genre does "juice" — we need zero animation assets |
| Music | **Pixabay Music / FreePD / Kevin MacLeod** now; consider one month of **Suno** (~$10) later for a bespoke theme | Free now | Pixabay = no attribution needed; MacLeod = CC-BY (credit him). Suno commercial use requires a paid month — cheap, do it once, batch-generate the whole soundtrack |
| Sound effects | **Kenney.nl** (CC0 packs) + **Freesound** (filter license = CC0) + **jsfxr/ChipTone** for synthesized blips | Free | Kenney alone nearly covers a card game (card slides, clicks, impacts) |
| Fonts | **Google Fonts** (OFL) | Free | Storybook-ish display + highly readable UI face |

## What I can automate vs what needs you

**You (accounts I can't drive):** ChatGPT image sessions (you paste
prompts, download results), Kling renders.

**Me, locally and free:** everything after generation — background removal
(`rembg`, free/local), resize/crop/pad (ImageMagick), card-frame compositing
(script that drops art into the frame template), WebP conversion for app
size, import into Godot, and the art manifest bookkeeping.

**Me, via API — only if you ever provide a key (all optional):**

| API | Good for | Cost reality |
|---|---|---|
| OpenAI Images (`gpt-image-2`) | Programmatic icon/sprite batches, auto-variations | ~$0.02–0.19/image. Note: ChatGPT Plus does NOT include API credit — separate billing |
| Recraft | Vector icons, consistent icon sets | Free tier exists; nice-to-have |
| Ideogram | Images containing legible text (logos, shop signs) | Free tier exists |
| Replicate / fal.ai | Flux and other open models per-image | Pennies/image; alternative to everything above |
| Stability (SD3/Flux local) | Unlimited free generation **if** you have a decent GPU | $0 — worth checking what GPU is in this PC before buying anything |

**Recommendation: provide nothing new yet.** ChatGPT + Kling +
free audio covers the entire game. Revisit only if manual generation becomes
the bottleneck.

## The workflow (repeatable loop)

1. I maintain **`docs/design/art-manifest.md`**: every asset gets an id, a
   description, a ready-to-paste image prompt (with our style block),
   size/format target, and a status column.
2. You batch-generate in ChatGPT, drop raw images into
   **`assets/incoming/`** (I file them into `assets/library/<kind>/`) named by asset id.
3. I post-process (crop, rembg if needed, frame-composite, WebP), move to
   final locations (`assets/cards/`, `assets/scenes/`, ...), and tick the
   manifest.
4. Anything that needs transparency or precise instruction-following goes to
   ChatGPT instead; anything animated-for-marketing goes to Kling at the end.

## The programmatic animation layer (owner rule, 2026-07-30)

**Living elements are engine effects, never baked into images.** One static
image + code-driven motion = many feels, zero extra generations:

- **Flicker/glow:** wisp flames, lamplight, candle glow, the Unpicked's
  threads — tweened brightness/scale pulses over the static art. A calm wisp
  breathes slowly; an angry one flickers fast. Same image.
- **Tint states:** warm parlor vs cold parlor, day vs night streets, "wrong
  quiet" — color-graded variants of one backdrop.
- **Particles:** fog drift, dust motes, ember sparks, purr-threads, rain —
  Godot particle systems over any scene.
- **Card feel:** cards shiver when an enemy targets the hand, glow when
  affordable, tilt on hover — programmatic, applies to every card ever made.
- **Consequence for prompts:** generate art *without* dramatic baked-in
  lighting effects where possible (no lens flares, no motion blur) — the
  engine adds the life on top.

First implementations live in `game/scenes/battle.gd` (enemy breathing,
sunbeam flash, alarm pulse) — extend that pattern, don't regenerate art.

## Style consistency (the make-or-break for AI art)

- One locked **style block** appended to every image prompt (to be
  developed in a dedicated art-direction session: storybook ink-and-wash,
  gaslamp palette, single rim-light source — direction TBD with test
  batches).
- Use a **canonical Ash reference image** in every generation featuring Ash
  (ChatGPT image edits and Kling both accept reference images); same for
  recurring NPCs. Seed consistency is a myth across prompts — reference
  images are the reliable tool.
- **Card frames, icons, UI chrome are NOT AI-generated** — they're built
  once (vector/ChatGPT-assisted, human-finished) so the interface reads
  crisp at phone sizes. AI art lives *inside* frames, never as UI.
- Legal notes (from monetization research): generate on **paid/commercial
  tiers** of ChatGPT and Kling only (dated copies of their commercial terms
  live in `docs/publishing/`); human-edit hero assets (title art, icon, key
  marketing) both for
  quality and copyrightability; the store icon and logo should get human
  design attention — it's the single highest-leverage image we'll ship.

## Launch asset budget (from market research)

~120–200 card/skill illustrations, ~30–50 enemies/NPCs, ~15–25 story scenes,
~10 district backdrops (day/night variants), ~20–30 icons. At
batch-generation rates this is a few evenings of generation once the style block is
locked — the manifest will sequence it so Chapter 1 + Prequel assets come
first (~40 images for the vertical slice).
