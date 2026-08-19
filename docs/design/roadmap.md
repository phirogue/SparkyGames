# Roadmap & Standing Design Decisions

*2026-07-31. Consolidates owner directives that shape ongoing work.*

## Staged releases & updates (owner rule)

- **Release plan:** ship Prologue + Chapter 1 first; then one chapter at a
  time as app updates, plus fixes between.
- **What this requires (already true or planned):**
  - Chapters are data (`story/*.json`, quests, encounters) — new chapters are
    content drops, not code rewrites.
  - Saves are versioned with migrations (`schema_version`) so updates never
    eat progress. Every chapter release bumps content, not save schema, where
    possible.
  - Chapter gating: a `chapters` list in data with `available: true/false`;
    the paid unlock flips entitlement, updates flip availability. The
    chapter-select "case files" screen shows future chapters as tied-shut
    folders (Zeigarnik: visible locked content is a feature).
  - Marketing tie-in: every chapter release = an Apple "New Content"
    featuring nomination (see marketing research).
  - CI already builds AAB/TestFlight on tags — releases are tags.

## Decision points (Walking-Dead-style, art-cheap)

Design rules for choices (first one shipped in the prologue):

1. **Choices are text-first** on the existing story-card layout — no new art
   per branch. The scene art stays; the *consequence* is carried by flags,
   journal lines, and later dialogue variants (cheap, reactive).
2. **Max 3 options** (readability rule), labels short.
3. **Consequences are real but economical:** a flag + a mechanical nudge
   (card, surprise, favor) + at least one later acknowledgment line. The
   Telltale lesson: "X will remember this" *feeling* comes from callbacks,
   not branching cinematics.
4. **The Casebook records every choice** (implemented) — the player's own
   trail of decisions is the replay hook.
5. Bigger forks (chapter endings, verdicts) may branch quest availability —
   still data, still no extra art beyond existing scene pools.
6. Future: devil's-bargain-formatted choices (influences research shortlist
   #2) — a named certain price, logged, always collected.

## Programmatic effects library (shimmer, scratch, etc.)

Owner direction: distinctive moments via engine effects, not new images.
Build these as reusable helpers (`game/ui/fx.gd`, upcoming):

- **Shimmer** — a moving diagonal highlight band (shader or animated
  gradient) for: silver thread moments, Moonlight cards, the Weft. One
  `CanvasItem` shader, parameterized speed/angle.
- **Scratch** — three quick ink slashes drawn over a target (Line2D +
  fade tween) on damage dealt; heavier variant for Pounce crits.
- **Unstitch** — dashes peeling off the ThreadBar when the enemy loses HP
  (extend existing widget).
- **Ember drift / fog roll** — GPUParticles2D presets per environment.
- **Card feel** — hover tilt, play-arc tween, hand-attack shiver (cards
  shake when the intent targets your hand — telegraph reinforcement).
- **Seal press** — wax seal scale-punch on confirming choices.
- Rule: every effect is a function call on existing nodes; zero new art.

## Adaptive layout & safe areas

- Canvas 720×1280 with `canvas_items`/`expand` already adapts 960-wide
  (tablets) to 1680-tall (21:9); anchors keep bands pinned; middle absorbs
  slack (see mobile UI research).
- TODO before device beta: `SafeAreaContainer` applying
  `DisplayServer.get_display_safe_area()` ÷ final-transform scale (min top
  60, bottom 48); multi-ratio tour runs (`window_width_override` matrix:
  960×1280, 720×1600, 720×1680) with screenshots per ratio.

## Soundtrack integration (when tracks arrive)

- Tracks land in `assets/incoming/music/` per
  [music-prompts.md](music-prompts.md); `python tools/wire_music.py` folds
  each take into a loop, normalizes it (−18 LUFS beds, −14 stings, −3 dBTP)
  and encodes 48 kHz Ogg into `assets/library/music/`; `--wire` copies to
  `game/assets/music/` and runs the import pass.
- `MusicService` autoload: crossfade per screen/environment (mantel, prowl,
  combat, stealth, court, boss), stings on victory/defeat/achievement,
  volume settings persisted. Priority order if credits are limited: combat →
  mantel → prowl → stings.

## Prose pass (from text/psychology research — writing law now)

- Story cards: 3–5 tap-lines × 8–14 words, ≤80 words/card; art carries the
  nouns; end lines on the destabilizing word. Prologue needs a trim pass to
  meet the law (several lines currently run 15–20 words).
- Peak-end: every run ends on a story sting (deaths have the Court; add
  rotating lines for wins/retreats so no ending repeats verbatim).
