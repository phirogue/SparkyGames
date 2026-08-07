# Asset Pipeline — Images, Music, SFX, Animation

> **SUPERSEDED 2026-08-06.** This describes the owner pasting prompts into
> ChatGPT and dropping files in `assets/incoming/`. Claude generates
> directly through the OpenAI API now — see the `/genart` skill and
> CLAUDE.md's art rules. Kept for the reasoning, not the procedure.
> Index: [ART-INDEX.md](ART-INDEX.md).


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

> **Superseded 2026-08-03: I generate the stills now.** The owner provided an
> `OPENAI_API_KEY` (gitignored `.env`), so image generation moved from "you
> paste prompts into ChatGPT" to `tools/genart.py` against **`gpt-image-2`**.
> The full loop — check library, check archive, generate, Read every result,
> promote, wire — is the **`/genart` skill**. Everything below this box that
> describes owner-run image sessions is history.

**You (accounts I can't drive):** Kling renders, and any hand-made art you
want to drop into `assets/incoming/` for me to file.

**Me:** generation (`tools/genart.py`), filing and retiring
(`tools/promote.py`), and everything after — background keying and content
trimming (`tools/genart_ui.py:cut_alpha`), resize/crop, WebP, Godot import,
and the bookkeeping in `docs/design/art-needed.md`.

**API reality, learned the hard way:**

| fact | consequence |
|---|---|
| `gpt-image-2` is current; `gpt-image-1` is the April-2025 snapshot | Same prompt gave a pencil sketch on `-1` and a finished watercolour on `-2`. Query `/v1/models`; never assume. |
| ChatGPT Plus does **not** include API credit | First run died on `billing_hard_limit_reached` despite an active plan. ~$0.19/image at high quality. |
| `--ref` posts to the images **edits** endpoint | The only reliable way to hold a character's design, and the right tool for "same image, one thing changed". |
| `gpt-image-2` rejects `background="transparent"` | UI is generated on white and keyed to alpha locally. |
| Output is 1024x1536 (2:3) | Slightly squarer than the 9:16 backdrops want — crop on the way to `game/assets/`. |

Alternatives if this ever needs revisiting: Recraft (vector icon sets),
Ideogram (legible text), Replicate/fal.ai (Flux, pennies per image), local
SD3/Flux (free with a decent GPU).

## The workflow (repeatable loop)

1. **`docs/design/art-needed.md`** is the live list; the prompt archive is
   `image-prompts-master.md`.
2. I generate with `/genart`, which checks the library first (never duplicate)
   and the archive before changing anything (a revert is free), uses
   `STRICT_STYLE`, and uses `--ref` for every recurring character.
3. I **Read every generated image** before it counts, then file it with
   `tools/promote.py`. Art goes straight into `assets/library/<kind>/`;
   whatever it displaces moves to `assets/archive/superseded/`. Nothing is
   ever deleted.
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

## Consistency audit (tool, 2026-08-03)

Every art drop gets an automated drift check before wiring:

    godot --headless --path game -s tests/art_audit.gd

It profiles each filename-prefix group (bg_, en_, sc_, sk_, ui_, ...) by
hue/saturation/brightness and flags images that sit far off their group's
profile, with a human-readable reason ("much darker than the group; hue
leans teal"). Report lands in `docs/design/art-audit-report.md`. Flags are
a shortlist for the owner's eyes — deliberate style breaks will flag too.
Scan dirs default to `game/assets`, `game/assets/ui`, every
`assets/library/<kind>/` folder, and `assets/incoming`; override with
`-- --dirs a,b,c`. It is a cheap first pass — it catches *statistical* outliers
(that's how `en_wisp_pair` surfaced), but it cannot see canon defects or the
ink-vs-digital medium split. Use the asset-auditor agent for those.
