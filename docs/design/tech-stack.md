# Tech Stack — DECIDED (2026-07-29)

Owner approved the research recommendation
([2026-07-29-tech-stack-research.md](../research/2026-07-29-tech-stack-research.md)).

## The stack

- **Engine:** Godot 4.x (latest stable), **GDScript** (not C# — mobile C#
  export is still experimental).
- **Orientation:** portrait, one-handed (the market gap).
- **Architecture:** pure rules engine in `game/core/` with **zero Node/
  rendering dependencies**; scenes only render state and forward intents.
  Seeded RNG + append-only command log from day one (replays, daily seeds,
  and later server-validated PvP for free).
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
- **PvP later:** Nakama self-hosted (~$10/mo VPS) via its official Godot
  client — no commitment now; the core/command-log architecture is the hedge.

## Costs

$25 Google Play (once) + $99/yr Apple + $0 engine + ~$0 CI at our scale.
