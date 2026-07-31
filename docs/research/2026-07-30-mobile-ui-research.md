# Mobile Game UI Best Practices — Numbers for Our 720×1280 Canvas

*Compiled 2026-07-30. Full cheat sheet applied to the game the same day.*

## The one conversion rule

Phones are ~360–430dp wide; our canvas is 720px wide, so **1dp/sp/pt ≈ 2px on
our canvas**. Godot's default 16px font is effectively **8sp — half the
platform minimum**. This is the exact mistake Slay the Spire mobile shipped
(persistent "text is WAY too small" reviews).

## Typography (px on our canvas)

| Role | px |
|---|---|
| Fine print floor | 22–24 |
| Captions/hints | 26 |
| **Body (the workhorse)** | **30** (≈15sp) |
| Emphasized body | 32 |
| Buttons | 30–32 semibold |
| Subheadings | 40 |
| Screen titles | 48 |
| Hero numerals (cost/HP) | 48–68 bold |

## Touch targets

- Minimum interactive rect: **96×96px** (Material 48dp; Apple 88px)
- Standard button height: **96–104px**; primary action (End Turn): **112–128px**
- Gap between targets: 16px min, 32 preferred
- Small icons: 48px glyph inside a 96px hit rect

## Aspect ratios & safe areas

- With `canvas_items` + `expand`, our canvas ranges **720–960 wide ×
  1280–1680 tall** (4:3 tablets widen; 20:9–21:9 phones lengthen). Anchor top
  and bottom bands; let the middle absorb slack. Full-bleed art ≥ 1000×1700.
- Safe areas: `DisplayServer.get_display_safe_area()` is in PHYSICAL pixels —
  divide by the viewport final-transform scale before applying as margins.
  Fallback minimums: top 60px (expect up to 120 on iPhone), bottom 48–70px.
  **TODO: implement SafeAreaContainer before device testing.**

## Portrait card-battler conventions

- Thumb zones (Hoober, 49% one-handed): bottom third = easy; top third =
  hard. Hand + actions bottom, End Turn bottom-right, opponent info top
  (display-only).
- **Numbers live on cards; sentences live in a tap-to-inspect view** (Marvel
  Snap / Hearthstone pattern; StS mobile's failure was ignoring it). Our skill
  preview panel already implements this.
- Card frames: 5:7 (physical TCG) or 3:4 (art-forward); art crop 1:1 for
  avatar reuse. Story illustrations: honor the generated 3:4 (never crop
  square).

## Godot gotchas

1. Set theme `default_font_size` ≈ 30 (done in UITheme).
2. `canvas_items` oversamples FONTS automatically (crisp on 1440p phones) but
   NOT textures — author art at 2× on-canvas display size.
3. Test matrix: 960×1280, 720×1280, 720×1600, 720×1680 windows + one real
   device. Tour screenshots should eventually run at multiple ratios.
4. Scale card scenes with `scale` (not resize) for hand-vs-inspect states.
5. Ship a UI-size accessibility slider eventually (`content_scale_factor`).

Full sources in the research transcript (Apple HIG, Material 3, LogRocket,
Godot docs, Marvel Snap Apple Design interview, Kobiton 2026 resolutions,
Smashing Magazine thumb-zone research).
