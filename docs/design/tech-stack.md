# Tech Stack — DECIDED (2026-07-29)

Owner approved the research recommendation
([2026-07-29-tech-stack-research.md](../research/2026-07-29-tech-stack-research.md)).

## The stack

- **Engine:** Godot 4.x (latest stable), **GDScript** (not C# — mobile C#
  export is still experimental).
- **Orientation:** portrait, one-handed (the market gap).
- **Architecture:** pure rules engine in `game/core/` with **zero Node/
  rendering dependencies**; scenes only render state and forward intents.
  Seeded RNG + append-only command log from day one (deterministic tests,
  bot simulation, replay debugging, and shareable seeded runs for free).
- **Data:** all cards/skills/enemies/quests as JSON with stable string IDs.
- **Saves:** versioned JSON (`schema_version`), atomic write + rolling
  backup; three files: meta-progression / run state / settings.
- **Android:** built locally on Windows (JDK 17 + Android SDK), ship AAB,
  Play App Signing.
- **iOS:** GitHub Actions macOS runner exports, signs, and uploads to
  TestFlight (no Mac required day-to-day; consider a used M1 mini only if
  first submission fights us).
- **CI:** every push = headless Godot import + script check + GUT unit tests
  on `core/`; tagged releases = Android AAB + iOS TestFlight jobs.
- **No multiplayer, ever** (owner decision, 2026-08-02). The game is
  single-player; no servers, no accounts. The core/command-log architecture
  stays for its own sake: deterministic testing, bot simulation, replay
  debugging, and shareable seeded runs.

## Costs

$25 Google Play (once) + $99/yr Apple + $0 engine + ~$0 CI at our scale.
