# Chapter 1 "Wax and Wick" — build plan

**Date:** 2026-08-03. Sequencing doc: what gets built, in what order, and
what gates each step. Sources: chapters/01-case-file-wax-and-wick.md (the
design), the 2026-08-02 critical review (the gaps), the-unraveler.md (the
culprit — REQUIRED READING before writing any Ch1 prose), and
missions-and-environments.md (the module cost model).

**Ground truth today:** built = combat module, story/choice screens, hub
with loadout picker, journal v1, shop, Press On/carryover economy,
stealth/alarm (one environment), shared page scaffold, scenario runner +
pinned seeds, 4-persona sim, screenshot tour. Prologue playable end-to-end.

---

## Phase 0 — decisions & scope lock ✅ SIGNED OFF 2026-08-03

All three gates cleared by the owner on 2026-08-03. Recorded here because
the docs are the source of truth, not chat history.

1. **Mission-module cut list — APPROVED as recommended:**
   - **KEEP: Heist/Alarm** — the stealth/alarm system already exists in
     combat; a heist is a stealth encounter chain with a "leave with the
     thing" win condition. Cheapest module, biggest fantasy payoff (L2
     ledger job, L4 Wickhouse).
   - **KEEP: Ritual stitch-work** — one small self-contained pattern
     minigame (tap the sequence the diagram shows, calm pacing). Needed
     because Ch3's finale performs the mirror-stitch clue with the
     player's own paws (the-unraveler.md) — build the system now, simple.
   - **CONVERT: Diplomacy (Sway)** → choice-scenes. The story screen
     already does choices; a Sway meter is choice-scenes with a visible
     tally. No new engine surface for Ch1; revisit as a real module in Ch2.
   - **DEFER: Survival, Escort** → Ch2+. Both leads that used them become
     combat-with-environment variants (survival = night-presses starts
     early; escort = ally HP bar as a second thread — defer that widget).

   Consequences already written into
   [chapters/01-case-file-wax-and-wick.md](chapters/01-case-file-wax-and-wick.md):
   L3 loses its escort prowl and its Sway meter, L4's survival prowl
   becomes a combat prowl under a Mereside environment rule.
2. **Culprit — CONFIRMED.** [the-unraveler.md](the-unraveler.md) stands:
   the Unraveler is **Bodkin**. The veto window is closed; Ch1 prose may
   now plant clues against it. Bodkin enters at L1.
3. **Art rights — CLEARED for the Ch1 batch.** Owner verified ChatGPT's
   commercial terms on 2026-08-03. The whole ~35-image Ch1 batch is
   ChatGPT stills, so generation is unblocked. **Still open, and neither
   blocks Chapter 1:** Kling (motion — marketing only, no video ships in
   the game) and the AI music tool's commercial tier (subscribe *before*
   generating — free-tier songs stay non-commercial). Both remain in
   [OWNER-ACTIONS §2](../OWNER-ACTIONS.md).

## Phase 1 — chapter spine systems (build BEFORE content, ~1 week)

Order matters; each unblocks the next:

1. **Case Board UI** — the chapter's spine. A journal-family page (uses
   `UITheme.page_scaffold`) showing: suspects (portrait chips), evidence
   objects collected (every lead ends with a *thing*), and threads
   connecting them. Data-driven from `game/data/case.json` (new file:
   evidence id → name, art, lead, unlock text; Catalog.validate coverage
   from day one). The Case Board IS the recap mechanism — opening it
   answers "where was I?"
2. **"Previously on" recap card** — one story-screen page auto-composed
   from case.json state (latest evidence + current lead), shown on every
   cold launch mid-chapter. Two days' work once the Case Board data
   exists; the mystery must have memory (review finding, unresolved).
3. **Guild standing** — profile counters + notice lines ("The Chandlers
   remember."). Data: `standing` dict in profile (DEFAULT_PROFILE + law-7
   migration thought), quest rewards write it, story `when` conditions
   read it. No UI beyond notices this chapter.
4. **Favor-knots** — collectible debt tokens: profile array + Case Board
   display + one redemption story-beat type. (The Gentleman's economy —
   also plants Ch2 machinery.)
5. **Flashback scene type** — story screen variant: sepia tint via
   environment `image_tint` (exists), no choices, "Remembered Day" header.
   Cheap; needed for the kettle flashback and "It should hurt."
6. **Quest schema v2** — add `kind` (core/side), `guild`, `district`,
   `once` (non-repeatable core quests), `requires` (evidence/standing
   gates) to quests.json + validate + hub board honors gating. This is
   what makes "tackle quests in any order, everything still works" true —
   scenario specs per gate state are the test.

**Gate:** every Phase-1 system lands with (a) a unit test where logic is
pure, (b) a scenario spec exercising it, (c) a tour stop if it renders.

## Phase 2 — combat content, batch A (parallel with Phase 1 art)

- **Enemies 1–4** of Ch1's eight: wax-and-wick themed street tier (e.g.
  drips, wick-imps, a chandler's porter, the tallow hound). Sim row +
  three-loadouts verdict per enemy BEFORE any encounter wires them
  (law 8; the sim is 30 seconds — run it per enemy, not per batch).
- **Districts**: Wickrow + Shambles environments (cost mods, sunbeams,
  one stealth street each). Environment effects stay data-describable —
  if a new effect needs code, it also needs a validate() entry and a test.
- **Encounters** for L1–L2 (~5), single-enemy; the wisp_pair-style "two
  as one" trick is fine until multi-enemy ships (deferred, Ch2).

## Phase 3 — Leads 1 & 2, playable vertical slice

- **L1 (combat)**: the stub from the docket → Magpie Exchange scene
  (Brindle's pause — already scripted) → street fight → evidence #1 on
  the Case Board. **Introduce Bodkin here** (the-unraveler.md: he pulls
  Ash out of the L1 fight's aftermath; every line literally true).
- **L2 (heist)**: the ledger job — stealth chain into Wick's counting
  room, Alarm variant rules, evidence #2 (the buy-the-debts ledger).
- Both leads get full `when_outcome` variants (law 6) and a scenario spec
  (`ch1_L1_fresh`, `ch1_L2_loadout_swat`, etc.).
- **Gate: the slice ships to the closed test** (the Play 12-tester track —
  OWNER-ACTIONS §1) as "Chapter 1: First Threads." Real players hit the
  loadout/quest-order matrix while the back half is built.

## Phase 4 — combat content batch B + Leads 3 & 4

- **Enemies 5–8** incl. both bosses (the Wickhouse's kept thing; the
  captain-tier guild muscle). Sim gates as batch A; the boss that is
  MEANT to be lost/retreated (if any) follows the wraith pattern —
  mechanically true, achievement-framed.
- **L3 (was diplomacy → choice-scenes)**: the Lamplighters' hall —
  Sway-by-choices with the shift-boss; favor-knot payoff.
- **L4 (heist + ritual)**: the Wickhouse. First ritual minigame use
  (re-warding as cover); the "unpicked in her own stitch, backward"
  reveal beat.

## Phase 5 — Lead 5, side quests, chapter close

- **L5**: confrontation with Wick — combat with the guild-muscle boss,
  then the eliminating scene ("guilty of everything except the murder"),
  docket-to-Gravamen hook, **paid-unlock boundary lands here** at maximum
  curiosity (per chapters/01).
- **Side quests** (3 of the designed pool, per side-quests.md): the Milk
  Debt (introduces the Gentleman), the Pigeon Ballot (murder-night seed),
  Sootbeard's Blink (first hard Unraveler evidence). Mark the deferred
  side quests as deferred IN side-quests.md.
- **Endless-tail content**: the three prologue board quests stay; add one
  Wickrow patrol quest so the free tier's generated-cases seed exists.

## Phase 6 — hardening pass (1 week before the chapter ships)

- Full sim table refresh → balance-notes Pass 5 (incl. carryover-mode sim
  — still owed from the review).
- Tour extended to walk Ch1's golden path; screenshot-critic pass.
- Art audit run on the full Ch1 batch; owner spot-corrections.
- Save-migration test from a real prologue-era save file.
- Text budget pass: pick ONE law (recommend story-structure's ≤3 lines ×
  8–14 words) and trim; aphorism budget enforced per page.

## Art waves (owner, parallel throughout — manifest sequences them)

Wave 1 (needed by Phase 3): Wickrow + Shambles backdrops, Bodkin
portrait/sprite, 4 street enemies, L1/L2 scene art, evidence object art
(the stub, the ledger). Wave 2 (Phase 4): Wickhouse interior, bosses,
ritual diagram frames, L3/L4 scenes. Wave 3 (Phase 5): Wick portrait
scenes, chapter-close splash, Gravamen teaser. Run `art_audit.gd` per
wave; the manifest tracks approval.

## What is deliberately NOT in Chapter 1

Multi-enemy encounters, escort/survival modules, the Sway meter as a real
system, equipment/nine-pockets UI (pockets stay narrative until Ch2's
Last Parcel groundwork), difficulty bands, Curios, the rival witch
(introduced Ch2 per the-unraveler.md), any Mere-facing content beyond the
Wickhouse's kept thing.

## Standing rules for every step

- Docs first: a lead's beat script is written (and culprit-audited
  against the-unraveler.md) before its scenes are wired.
- Every fight: sim verdict before wiring; every screen: tour stop; every
  state-dependent bug: a scenario spec that reproduces it.
- Commit at each phase gate; push at session end (git rules).
