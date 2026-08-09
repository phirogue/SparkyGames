# UI Style Guide & Implementation Plan

*2026-07-30. Direction locked by the three mockups in `reference/`
(battle screen v2, the mantle v2, story screen). This doc is the build plan:
what the look is made of, which template assets to generate, with which
tools, and in what order.*

## The type scale (owner standing order, 2026-08-09)

Small text was flagged at every owner review until it became a rule. The
scale lives in `UITheme.TYPE_*` and the floor is **enforced** by
`tests/unit/test_typography.gd` (source scan) plus the screenshot-critic
agent (what a scanner can't see). The 720-wide canvas is ≈2x phone density,
so 30px here ≈ 15sp on device.

| Role | px | Used for |
|---|---|---|
| `TYPE_TITLE` | 44+ | screen titles |
| `TYPE_HEADING` | 34 | section headings, popup names |
| `TYPE_BODY` | 30 | anything the player must read to play (battle reference) |
| `TYPE_SUPPORT` | 26 | blurbs, flavor, secondary lines |
| `TYPE_FLOOR` | 22 | the smallest legal player-facing size |

Raising a size means re-measuring its container (law 4/law 2) — the floor
has already forced short captions ("lives", not "lives in him") rather than
wrapped small ones, which is the intended pressure. Non-player-facing text
(dev menu, missing-art placeholders) carries `# type-floor-exempt: <why>`.

## What the mockups tell us (analysis)

1. **The UI is a storybook page.** Every screen sits on aged parchment with a
   stitched/dashed border — the interface is literally *sewn together*
   (magic system = sewing; the UI obeys the lore).
2. **The hub is a place, not a menu.** The Mantel mockup is one full
   illustration (stone fireplace wall, oil lamps, hearth) with interactive
   elements — quest notes pinned with needles and wax seals, shop panels in
   the hearth, gleam as a pile of buttons — composited on top.
3. **Information becomes objects:** HP bar = a fraying red thread. Deck
   count = a wooden spool. Gleam = shiny buttons. Lives = paw prints.
   Achievements = medallions on a scroll. Nothing looks like a "widget."
4. **Cards are simple and iconic:** white card, colored border per humour,
   one big glyph (claw slashes / cat eye / smoke / moon-and-needle), name at
   the bottom. Skill buttons are small framed paintings with charge pips.
5. **The AI-generated placeholder text is garbage — and that's fine.** All
   real text is rendered by the engine with real fonts; the mockups only
   define the *containers*.

## Architecture: how this gets built in Godot

**One global `Theme` resource + a small set of custom widget scenes.**

- **Template textures as 9-patch (`StyleBoxTexture`)**: a parchment panel
  generated once stretches to any size with corners intact. This is the
  workhorse — ~12 templates skin every panel/button in the game.
- **Custom widget scenes** (each built once, reused everywhere):
  - `EnergyCard` — card frame + humour glyph + name; colored border via
    per-humour frame variants (or one neutral frame + tinted border layer).
  - `SkillButton` — ornate frame + skill art + name plate + charge pips
    (pips are engine-drawn circles; filled/empty from state).
  - `ThreadHealthBar` — custom `_draw()`: a thread texture segment repeated
    for current HP, a frayed-end sprite at the tip, dashed line for the
    missing portion. Animates by *unstitching* when damage lands.
  - `QuestNote` — parchment note template + needle pin sprite + wax seal
    (color variant per quest type) + real text; each instance gets ±2° of
    random rotation so the mantel looks hand-pinned.
  - `IntentBanner`, `LocationBanner` — ribbon/scroll 9-patches + icon slot.
- **Full-scene screens**: hub background is ONE illustration generated
  *empty* (bare mantel, no notes, empty hearth) so the dynamic elements are
  real controls placed on top. Story screens keep full-bleed art inside the
  stitched page frame (already wired).
- **Fonts (Google Fonts, OFL, free):**
  - Display/headers: **IM Fell English** (the aged-print look in the mockups)
  - Story/narration italic: **IM Fell English Italic**
  - UI labels & numbers: **Alegreya** / **Alegreya SC** (readable serif that
    matches, holds up at small sizes)
- **Programmatic life layer** (per the animation design rule): lamp flames
  flicker (glow sprite + noise tween), hearth embers (particles), thread bar
  unstitches on hit, wax seals "press" on tap, notes wobble when touched,
  End Turn button pulses gently when it's the only sensible action.

## Tool split

| Task | Tool | Why |
|---|---|---|
| Template/9-patch pieces (panels, frames, buttons, banners, note, seal) | **ChatGPT** | Precision, symmetry, transparent backgrounds, iterating on a single object |
| Icon set (hearts, paws, shield, spool, glyphs, intent icons, medallions) | **ChatGPT** | Consistent matched sets on transparency |
| Full-scene art (empty mantel hub, story illustrations, skill art) | **Kling** | Scene richness; reference-image consistency |
| Slicing, margins, transparency cleanup, downscale | **Me (local)** | ImageMagick/rembg, then StyleBox margin tuning in Godot |
| Theme, widgets, animations, fonts | **Me (Godot)** | All code — stays crisp at any resolution |

## Template asset manifest (the "UI kit")

Generate in ChatGPT, one session per group so sets stay matched. Every prompt
should end with: *"perfectly rectangular and symmetric, flat front-facing
view, no perspective, centered on a fully transparent background, high
resolution."* Save as `assets/library/ui/<id>.png`.

**Group A — Surfaces (the foundation):**
- `ui_page` — full-page aged parchment texture with stitched dashed border
  all the way around (the screen background; also sliced for big panels)
- `ui_panel` — smaller parchment panel, ink-line edge, subtle stain
- `ui_strip` — thin horizontal parchment strip (log line, banners' base)

**Group B — Buttons:**
- `ui_btn_amber` — large warm amber/orange rounded button, ink outline
  (End Turn; primary actions)
- `ui_btn_parchment` — parchment button with wax-seal accent (default)
- `ui_btn_dark` — dark blue-grey button, fog texture (Slip Away; subtle
  actions)
- `ui_seal_red` / `ui_seal_blue` / `ui_seal_gold` — three wax seals
  (quest types, confirmations)

**Group C — Frames:**
- `ui_frame_portrait` — wood-and-gilt corner frame for enemy portraits
- `ui_frame_card` — white energy-card face with plain border (engine tints
  the border per humour)
- `ui_frame_skill` — ornate small square frame for skill buttons
- `ui_ribbon` — banner ribbon with forked ends (location names, shop title)

**Group D — Objects & icons (one matched session):**
- `ui_thread_segment` + `ui_thread_fray` — the HP thread and its frayed end
- `ui_spool` — wooden thread spool (deck count)
- `ui_heart_full` / `ui_heart_empty`, `ui_paw_full` / `ui_paw_empty`
- `ui_shield`, `ui_needle_pin`, `ui_button_pile` (gleam), `ui_scroll_end`
- Humour glyphs (already prompted in art-manifest Batch 5): claw, eye,
  smoke, moon-through-needle
- Intent icons: sleeve (attack), snip-scissors (skills), grasping hand
  (hand-steal)
- 5–6 achievement medallions (generic: medal, moon, clock, shield, trophy,
  quill)

**Group E — Scenes (Kling, using existing style consistency):**
- `bg_mantel_empty` — the hub fireplace scene from the mockup but with a
  BARE mantel (no notes, no letters), empty hearth, lamps unlit-to-dim; the
  engine pins everything else on top
- (Later) per-district story frames if the single stitched frame wants
  variety

## Build phases (each ends playable + committed)

1. **Foundation:** fonts in, `ui_page`/`ui_panel`/buttons as theme
   styleboxes → every existing screen instantly wears parchment. Biggest
   visual jump for least work.
2. **Battle kit:** EnergyCard, SkillButton with pips, ThreadHealthBar,
   banners, status row icons → the battle screen matches mockup v2.
3. **The Mantel:** empty hub scene + QuestNote widgets + hearth shop panels
   + gleam pile + achievements scroll → hub matches mockup v2.
   *Done 2026-08-04, along with Settings, the Magpie Exchange and the loadout
   page — the shop and the loadout picker became screens of their own. Layout
   contracts and what the build cost are in [ui-screens.md](ui-screens.md).*
4. **Polish pass:** lamp flicker, ember particles, unstitch animation, seal
   press, note wobble, button pulses.

## Practical generation notes

- Ask ChatGPT for **3x the display size** (e.g., a button that renders
  ~300px wide → request ~900px) — downscaling hides artifacts.
- 9-patch pieces must have **clean straight edges and symmetric corners**;
  if a generation curves or tapers, regenerate — a warped 9-patch haunts
  every screen forever.
- Generate Group A first and check it in-game before doing the rest: if the
  parchment reads wrong at phone size, the whole kit shifts.
- The mockups themselves stay in `reference/` as the acceptance test: each
  phase is done when a screenshot next to the mockup feels like the same
  game.
