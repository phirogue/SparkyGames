# Owner idea dump — 2026-08-01 (recorded verbatim-ish, with status)

Raw stream from the owner mid-session. Items marked DONE/DOC'D landed
immediately; the rest await design or implementation.

- **Purr activates phone vibrations** — juice idea; use
  `Input.vibrate_handheld()` during purr channel ticks. TODO (mobile
  builds only; settings toggle).
- **Thematic action cards can be upgraded** — skill upgrade tracks (spend
  skill points from mission rewards). DOC'D in
  difficulty-and-progression.md (upgrade axes).
- **Vole-fight deck refresh from the excitement of winning** — DONE as
  fiction (victory line: "the whole deck of me, wound fresh"); staged
  tutorial decks already reset per battle.
- **Enemies run the same card/energy system as Ash** — the symmetric
  engine: creatures have decks/skills like Ash so fights can be
  simulated both ways and an opponent agent can be trained. This is the
  long-term engine bet (also the PvP path). Core is already pure and
  deterministic; enemy-side decks are a v0.4+ refactor of `_enemy_act`.
- **The vole can flee after 3 turns if not beaten** — enemy `flees_after`
  field + an `ESCAPED` outcome (prey fights become timed puzzles). TODO
  core + data + tests.
- **Vole HP requires Pounce + Scratch** — DONE (hp 3 → 5; coach teaches
  the finishing Scratch).
- **No shopping before the first Magpie quest** (and per-merchant intro
  quests generally) — DOC'D; hub gating TODO when quests move to Ch1.
- **Filler quests: hunting runs; sparring against friends** to test
  loadouts, repeatable, no story cost — DOC'D in
  difficulty-and-progression.md.
- **Need to save the game** — exists (SaveService, atomic, versioned);
  what's missing is MID-PROWL resume (app killed between encounters).
  TODO: serialize prowl carryover into the profile.
- **3 chapters × ≥10 core quests × ~10 min each** — DOC'D in
  story-structure.md.
- **City guilds with standing, rivalries, 3-chapter arcs** — DOC'D in
  story-structure.md (rats, pigeons, magpies, lamplighters, parlor cats,
  the Hollow Court).
- **Stories must feel different quest to quest** — DOC'D (variety rule).
- **Scenario-specific action types for chases/diplomacy** — DOC'D
  (non-combat scenarios reuse the engine; loadout = personality).
- **Repeatable vs one-shot vs knockout scenarios; death rare & costly** —
  DOC'D (rules of engagement).
- **Character upgrades: hand size, actions/paws, HP, skill points, deck
  size** — DOC'D; all knobs already exist as CombatState config.
- **Skill combos unlock higher-tier actions** — DOC'D (discovery as
  progression). Needs combo detection in core flags (skills_used order
  is already logged per fight).
- **Energy loadout = personality in non-combat play** — DOC'D.
