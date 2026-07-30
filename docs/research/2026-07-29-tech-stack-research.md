# Tech Stack Research

*Compiled 2026-07-29 — 2D roguelite deckbuilder for iOS + Android, solo dev on
Windows 11, Claude Code-heavy workflow, offline-first, PvP possible later.*

---

## 1. Engine / Framework Comparison

### Summary matrix

| Criterion | Godot 4 (GDScript) | Unity (C#) | Flutter + Flame | RN/Expo + Skia | Defold (Lua) | Capacitor + Phaser/Pixi (TS) |
|---|---|---|---|---|---|---|
| 2D card game fit | Excellent (true 2D engine) | Good (2D bolted onto 3D) | Good (code-only, no scene editor) | Adequate (turn-based only) | Very good | Very good |
| iOS+Android export pain | Low-medium (Android easy; iOS needs Mac step) | Low-medium (mature but heavy toolchain) | Low (iOS still needs Mac/cloud) | Lowest (EAS cloud builds iOS *from Windows*) | Medium (iOS bundling is Mac-editor-only) | Low-medium (native shell glue is yours) |
| Typical app size | ~25-50 MB (trimmable to ~10 MB) | ~30-50 MB minimum | ~15-25 MB | ~20-40 MB | **~5 MB** | Small binary + WebView runtime |
| Offline-first | Native, trivial | Native, trivial | Native, trivial | Native, needs care | Native, trivial | Needs service-worker/asset care |
| Animation "juice" | Excellent (Tween, particles, 2D shaders) | Excellent (DOTween, particles, shaders) | Good (hand-rolled) | Limited (no particle/shader ecosystem) | Good (lower-level) | Very good (Phaser tweens/particles; WebGL shaders) |
| Solo-dev maintainability | Excellent — free/MIT, tiny install, fast iteration | Good but heavyweight; license churn history | Good if you live in Dart | Good if you live in RN | Good; small team behind it | Excellent if you live in TS |
| AI-assistant fit (consensus) | **Very good** — text-based .tscn/.gd files; dedicated Claude Code skills exist; GDScript hallucinations are the known weak spot | Good C# knowledge, but scene/prefab YAML + editor state resists agents | Good (Dart known, Flame API less so) | Good (TS known, thin game ecosystem) | Moderate (smaller corpus) | **Best** — "every major frontier LLM was trained on Phaser"; pure TS |

### Detail per option

**Godot 4 (GDScript/C#).** The consensus pick for solo 2D mobile in 2025-26: a
real 2D engine, zero cost/royalties under MIT, fast editor iteration; at GMTK
Jam 2025 Godot hit 39% of submissions vs Unity's 41%, driven overwhelmingly by
solo devs. For AI-assisted work, Godot's plain-text scenes and scripts make it
one of the two representations agents handle best, and there are purpose-built
Claude Code skills that generate complete runnable Godot projects. Known
caveat: LLMs sometimes hallucinate Python idioms in GDScript — mitigated by
keeping the Godot class reference and a project style guide in CLAUDE.md, and a
tight run-and-verify loop. **Important:** C# mobile export is still
*experimental* (Android arm64/x64 only; iOS experimental) — use GDScript for a
mobile title. Android exports typically land 25-50 MB, trimmable with WebP
assets and custom export templates.

**Unity.** Runtime Fee cancelled; Personal free up to $200k revenue with
optional splash since Unity 6; Pro ~$2,200-2,310/yr. Strongest mobile
SDK/monetization ecosystem, but 2D tooling "feels bolted on," the editor is
heavyweight, and binary-ish scenes/prefabs plus editor-centric workflow make it
measurably worse for agentic coding than text-first engines. Overkill unless
already known deeply.

**Flutter + Flame.** Performs fine for a card game and benchmarks respectably
against Godot for 2D. But there is no scene editor — all layout/animation is
code — and the community is much smaller. Only compelling for existing Flutter
developers.

**React Native/Expo + Skia.** Feasible for turn-based games. Killer feature:
**EAS Build compiles iOS in Expo's cloud, no Mac needed** — free tier gives 15
iOS + 15 Android builds/month. But no real game engine: no particles, shaders,
tween/juice ecosystem — you'd hand-build the "feel" that sells a deckbuilder.
Not recommended as primary.

**Defold.** Best-in-class binary size (~5 MB) and mobile performance; free.
Dealbreaker: **iOS bundling is only available in the macOS editor** — the
cloud Extender builds native extensions, not signed iOS bundles from Windows.
Smaller community = thinner LLM training corpus. Pass.

**Capacitor + Phaser/PixiJS.** Officially documented pipeline (Phaser publishes
its own Capacitor tutorial); full store distribution, IAP, push, one codebase
across web/iOS/Android. Performance fine for a card game (devs ship 60fps
action games in Phaser 3 on mobile). The **single best AI-assist stack**: pure
TypeScript, official Phaser agent skills for Claude Code. Tradeoffs: WebView
audio latency quirks, native-plugin glue (IAP, Game Center/Play Games) is on
you, iOS build still requires the Mac step. Strong runner-up.

---

## 2. App Store Publishing, 2025–2026

### Apple

- **$99/year** Apple Developer Program; unlimited apps, includes App Store
  Connect + TestFlight. Individuals need no D-U-N-S. ~90% of reviews clear
  within 24-48h.
- **A Mac (real or cloud) is unavoidable for iOS builds.** Godot's docs are
  explicit: iOS export must be done from macOS with Xcode. Workarounds from
  Windows:
  - **GitHub Actions macOS runners** — Godot 4.3+ can archive *and sign* the
    IPA in the export step; marketplace actions exist that export and upload
    straight to TestFlight (dulvui/godot-ios-upload). Free plan: 2,000
    min/month for private repos, but macOS burns at **10x** (≈200 real macOS
    minutes); public repos are unlimited.
  - **Codemagic** — 500 free macOS M2 minutes/month on personal accounts.
  - **Cloud Macs** (MacinCloud/MacStadium, ~$25-50/mo) or a used **M1/M2 Mac
    mini (~$300-500 one-time)** for occasional Xcode debugging — worth having
    for the first submission and for entitlement issues CI can't debug well.
- Certificates/provisioning profiles are created in the Apple Developer portal
  from any OS; store them base64-encoded as CI secrets.

### Google Play

- **$25 one-time** registration.
- **New personal accounts (created after Nov 13, 2023) must run a closed test
  with at least 12 testers continuously opted in for 14 days** before applying
  for production access (reduced from 20 in December 2024). Organization
  accounts are exempt. Plan for this: recruit testers early (friends/family,
  r/AndroidClosedTesting, tester-exchange communities) and treat the 14-day
  window as the beta.
- **Android builds work fully on Windows**: JDK 17 + Android SDK + keystore;
  ship an **AAB**. Keep the upload keystore backed up; enroll in Play App
  Signing.

---

## 3. Save Data & Offline Architecture

**Local saves (launch):**

- JSON with a **`schema_version` field in every file**; on load, chain one-step
  migration functions and never delete old migrators.
- **Atomic writes**: write temp file, then rename; keep a rolling backup slot
  to survive corrupted writes.
- Keep the model **flat-ish (≤2 nesting levels)**, validate on load, fail soft
  to backup.
- In Godot: `user://` + `FileAccess`; use `store_string(JSON.stringify(...))`,
  not `store_var` of Objects (a known injection/corruption footgun). Light
  obfuscation (`FileAccess.open_encrypted`) only to deter casual editing — for
  a single-player roguelite, don't over-invest in anti-tamper.

**Cloud save (nice-to-have at launch):**

- Android: official Godot Foundation plugin **godot-play-game-services** covers
  Play Games sign-in, achievements, leaderboards, and Saved Games.
- iOS: official Godot iOS plugins for **Game Center and iCloud** key-value /
  document sync.
- Use platform cloud save purely as **blob backup of the local save** —
  last-write-wins with a timestamp — not as source of truth.

**Designing today so PvP doesn't force a rewrite:**

1. **Separate three state layers**: (a) *meta-progression* (unlocks, currency,
   story flags), (b) *run state* (current deck, HP, encounter), (c)
   *settings*. Different files, different sync policies. Meta is what a server
   will eventually own.
2. **Pure, engine-agnostic rules core**: card effects, combat resolution, and
   RNG live in plain GDScript classes (no Node dependencies, no rendering).
   The scene layer only renders state and forwards intents. This is exactly
   what lets the same rules run later on a server or in lockstep.
3. **Deterministic, seeded runs + command log**: drive all randomness from a
   stored seed and record player actions as an append-only list of commands
   (`{turn, action, target}`). Benefits now: replay, bug repro, daily-challenge
   seeds. Benefit later: async PvP and server validation are literally "replay
   the command log server-side" — the anti-cheat model authoritative servers
   use.
4. **Stable IDs everywhere**: string IDs for cards/relics/events defined in
   data files, never array indices; generate a local player UUID at first
   launch so accounts can link to a backend later without data loss.
5. Treat the local device as canonical until a server exists; then
   meta-progression migrates to server-authoritative with the local file as
   offline cache.

---

## 4. Multiplayer Later (Async or Realtime PvP)

For a 3-5 minute-run deckbuilder, the natural first PvP is **asynchronous**
(ghost decks, seeded duels, leaderboard raids — server-mediated turns), far
cheaper than realtime.

| Option | Fit | Cost | Notes |
|---|---|---|---|
| **Nakama (self-hosted)** | Best all-round: auth, matchmaker, turn-based *authoritative* matches, leaderboards, storage, server-side TS/Lua/Go logic | Free (Apache 2.0) + **$5-10/mo VPS** proven by indies | **First-class official Godot client.** Managed Heroic Cloud starts ~$600/mo — skip until revenue justifies it |
| **Supabase** | Great for async PvP, accounts, cloud saves, leaderboards; SQL fits relational game data | Generous free tier, ~$25/mo Pro | Not a game server; realtime channels OK for turn exchange; validation in edge functions |
| **Firebase** | Fast to ship async features | Free tier, then usage-based | Firestore's NoSQL model fights relational game data; no matchmaking primitives |
| **Custom server** | Full control | Highest eng time | Unjustified for solo dev when Nakama exists |

**Cheapest door-keeper-open choice:** pick an engine with a maintained Nakama
client (Godot, Unity, and Phaser/JS all qualify), and do the architecture in
§3 (pure rules core + command log + stable IDs). That combination means adding
async PvP later is a server-side replay/validation module plus a lobby UI —
not a rewrite.

---

## 5. Recommendation

### Primary stack: **Godot 4.x (latest stable) + GDScript**, Nakama-ready architecture, GitHub Actions CI

**Rationale:**

- Best purpose-built 2D engine with the tween/particle/shader toolkit that
  gives a deckbuilder its juice; zero licensing cost or lock-in (MIT).
- Text-based scenes + scripts are among the best representations for Claude
  Code, with existing Godot-specific Claude skills; mitigate GDScript
  hallucination with a pinned API/style reference in CLAUDE.md and headless
  `godot --check-only`/GUT tests in the loop.
- GDScript (not C#) because C# mobile export remains experimental — removes
  the one Godot mobile risk.
- Windows-first development works end-to-end for Android; iOS is solved by CI
  rather than a Mac-centric workflow.
- Official Play Games Services plugin, official iOS Game Center/iCloud
  plugins, and an official Nakama Godot client cover launch *and* the PvP
  future for ~$10/mo when the time comes.
- Runner-up for a web-dev-at-heart: Capacitor + Phaser (TypeScript) — the
  strongest AI-assist story — accepting WebView quirks and DIY native glue.
  Avoid Defold (no iOS bundling from Windows) and RN/Skia (no engine juice).

**Project structure (PvP-ready):**

```
game/
  core/            # Pure GDScript rules engine — NO Node/rendering deps
    cards/         #   card defs loaded from /data, effect resolvers
    combat/        #   turn state machine, seeded RNG
    run/           #   run generator, encounters, events
    commands.gd    #   action command types + append-only log
  data/            # JSON/.tres: cards, relics, enemies, story beats (stable string IDs)
  scenes/          # Presentation only: battle, map, menus; subscribes to core signals
  ui/              # Card widgets, tooltips, juice (tweens/particles/shaders)
  services/
    save_service.gd      # versioned JSON, atomic write, backup slot, migrations/
    cloud_save.gd        # thin adapter: PlayGames | iCloud | (later) server
    platform/            # per-OS plugin wrappers behind one interface
  story/           # dialogue/narrative data + runner
tests/             # GUT unit tests for core/ (the AI verification loop)
.github/workflows/ # CI
CLAUDE.md          # engine version, GDScript style rules, "core/ never touches Nodes"
```

The `core/` vs `scenes/` split is the single highest-leverage decision: it
makes the game testable headlessly (which is what makes Claude Code effective),
and it is the exact seam where a Nakama server module later re-runs the same
rules authoritatively.

**CI from Windows (GitHub Actions):**

1. **Every push:** Linux runner — headless Godot import + `--check-only`
   script validation + GUT tests on `core/`.
2. **Android (tag/release):** Linux runner — export AAB with keystore from
   secrets; upload to Play internal track via `r0adkll/upload-google-play`.
3. **iOS (tag/release):** `macos-latest` runner — cache export templates,
   `godot --headless --export-release iOS`, sign with base64-encoded cert +
   provisioning profile secrets, upload to TestFlight (dulvui/godot-ios-upload
   or App Store Connect API key). Budget the 10x macOS minute multiplier (~200
   effective free min/month private; public repo = unlimited, or add
   Codemagic's 500 free macOS minutes).
4. Day-to-day testing: real Android device via one-click deploy from Windows;
   iOS via TestFlight builds from CI (consider one used M1 Mac mini for
   first-submission debugging and store screenshots).

**Budget to ship:** $25 Google Play (once) + $99/yr Apple + $0 engine + $0-15/mo
CI = well under $200 year one; PvP later adds ~$10/mo (Nakama VPS) or a
Supabase free tier.

---

## Sources

Coding Quests, RocketBrush, Sunstrike Studios (Godot vs Unity 2025-26); Unity
pricing updates, CG Channel; filiph.net Flame benchmark; Genieee (Flame);
Defold iOS/bundling manuals; Pixune, gamedesigning.org (Defold); Phaser
Capacitor tutorial, Capacitor games guide, Phaser 3 mobile optimization
writeups; generalistprogrammer.com & GeekyAnts (RN/Skia); Expo pricing;
Google Play 12-tester policy + community guide; groovyweb & gotechsolutions
(App Store costs/process); Godot iOS export docs; dulvui/godot-ios-upload +
simondalvai.org walkthrough; GitHub Actions billing docs; Codemagic pricing;
Godot C# platform state article; godot-play-game-services plugin;
stevensplint.com (iCloud sync in Godot); Bugnet & gamineai (save best
practices/migrations); Gabriel Gambetta (client-server architecture); Heroic
Labs Nakama docs + comparisons; Snopek Games & Cloudzy (Nakama on cheap VPS);
Supabase-as-game-backend writeups; Unity forum (Firebase vs Supabase); LEADR
backend comparison; jonathansblog.co.uk & HN (Godot Claude Code skills);
ziva.sh & summerengine.com (Claude + Godot); blog.ax0x.ai (best engine for
AI); OpenGame paper (arxiv); chierhu.medium.com (AI coding tools analysis);
Godot forum (APK size).
