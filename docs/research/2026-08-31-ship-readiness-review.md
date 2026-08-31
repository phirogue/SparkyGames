# Ship-Readiness Review — 2026-08-31

Six-track deep review of the full playthrough (prologue → end of Chapter 1),
run as: story critic, first-time-player critic, screenshot sweep (all 17
quests + prologue + minigames, shot 2026-08-31), chaos/economy rules attack,
completeness gap audit, and external market research. This doc is the dated
record; the punch lists below are the source for the fix plan.

**Framing asked for: review the game as a reviewer who would score it 7/10.**

---

## The review, as a 7/10 reviewer would write it

> *The Nine Lives of Ash* is the rare mobile card game with an actual idea:
> you equip the actions and draw the fuel, so the screen never drowns in card
> text, and every run truly fits in a sitting. The writing is far above genre
> norm — a witch's cat spending its nine lives to solve her murder, with a
> death bureaucracy that stamps REFUSED on your failures — and the difficulty
> curve is honest. But the chapter *stops* rather than ends, the early game
> leans on the same three wisps and the same three illustrations, a couple of
> mechanics are enforced but never explained, and once the story is done
> there is nothing to come back to. 7/10: a beautiful book with the last
> page missing.

Sub-scores a reviewer would hand out today:

| Axis | Score | Why |
|---|---|---|
| Core design | 9 | The energy-deck inversion solves the genre's #1 mobile complaint; approaches/paws/charging are real decisions |
| Story & writing | 8 | Prologue and the_carrying/the_wake are the high points; ending framing missing |
| Onboarding | 7 | First 10 minutes exemplary; stealth untaught, a few tooltips lie |
| Content volume | 5 | One chapter, 3 repeatable quests, no generated cases — fails the market's "8 hours" test |
| Polish | 6 | Type/layout discipline strong, but a black rectangle fronts every prowl wager |
| Ship readiness | 2 | No build pipeline, no store artifacts, no IAP, no cloud save |

---

## THE GOOD (protect these)

- **The inversion works.** Skills equipped, deck as fuel — market research
  confirms unreadable card text and 30–45-minute runs are the two loudest
  complaints against ported deckbuilders; this game structurally has neither.
  3–5 minute true runs are a *validated* niche (Pirates Outlaws "fast and
  breezy", Card Thief's top-10 week).
- **The first ten minutes ship.** The vole gift → wrong lamps → shut
  shutters hook lands; the vole fight teaches five concepts deterministically
  (`shuffle: false` + `opening_cards` wherever a promise is made); the
  refund window is safe.
- **The writing holds.** The clue chain (stub → docket → ledger → tally →
  backward seam → counterfoil) is clean and fair-play; `the_carrying` /
  `the_wake` are the emotional spine and are correctly load-bearing; Bodkin's
  literal-truth discipline is intact; retry variants are mostly excellent.
- **Balance is proven, not vibes.** 19,200-bot sim passes; the ladder reads
  76–95% careful shopless play at street tier, boss 77–79% shopless with
  face-tanking punished (32%); buyers feel their money; heal-stall bosses
  structurally banned.
- **Death is a feature.** Lives spent-never-taken, the Hollow Court, the
  REFUSED stamp, Grudges — nothing in the comp set has this.
- **The unsexy parts are done**: audio 15/15 tracks + 147 SFX with zero
  missing/orphans; a real settings screen (volumes, revert-to-checkpoint);
  AI disclosure already in credits AND settings footer; exactly one TODO in
  shipping code; kb_check 9/9; no orphaned content; save migrations tested
  to v8.
- **The market wants this shape.** Premium mobile is rebounding (+77%
  premium releases in 2025; Balatro ~$21M mobile). The decided model — free
  Chapter 1 + one $6.99 unlock, no ads — matches the best-performing
  acquisition pattern for unknowns (Slice & Dice, Night of the Full Moon).
  Cat + murder mystery is a real hook (Stray ~$57M month one; Little Kitty
  100K/48h) that no card-roguelite comparable owns.

## THE BAD (what holds it at 7)

1. **Chapter 1 stops instead of ending.** After `an_audience_of_wax` the
   board shows `mantel.board_empty` — "Nothing pinned tonight. The city is
   being quiet at you." — a lull string doubling as the end of the product.
   No ending screen exists (music.json maps `ending`, `mus_ending` exists,
   no scene implements it). Found independently by two review tracks.
2. **Content volume fails the genre's 7-vs-9 test.** Reviews in this genre
   hand out 7/10 for exactly this ("core gameplay is perfect but content
   chokes replayability" — Krumit's Tale). The monetization plan names
   generated cases as the free tier's replay engine; **they were never
   designed or built**. Only 3 of 17 quests are repeatable.
3. **Mechanics enforced but never stated** (the classic owner-review class):
   stealth/Alarm is the only mechanic whose first appearance teaches nothing
   (threshold and SPOTTED consequences unstated); Loaf's tooltip says the
   opposite of the code; Slip Away's half-satchel cost is announced *after*
   the tap; standing numbers are shown but never defined; turn-8 escalation
   never quantified; the refusal fee is "small" until it's 10%.
4. **Early Chapter 1 is wall-to-wall wisps.** Whichever starting job you
   take, fights 1–4 are gutter-wisps/wisp-pairs, several ending turn 1 with
   Pounce. The prologue's fights were each *about* something; these read as
   filler.
5. **Two quests break the 3–5 minute product constraint**: `creditors`
   (2 battles + lesson + lattice + ~13 cards) and `the_lamplighters_talk`
   (1 battle + 2 lessons + 2 minigames + ~14 cards) run 8–12 minutes for a
   first-timer, and defeat retries from the top.
6. **Promises without payoff**: favor-knots are granted (3) and taught
   ("untying one opens a door gleam cannot") but no `favor_redeem` step
   exists in the chapter (found by two tracks). Tansy moves into the house
   and is never seen again. `follow_the_thread` — the prologue's closing
   promise — is skippable, taking the Weft's only definition with it.
7. **Art repetition across the session**: the rooftops-at-dusk plate fronts
   5+ quests; the parlor armchair carries four different surfaces (case
   recap, two minigames, a battle). Legal per the 3-beat rule inside each
   quest; across a session it reads as a small deck of photographs. Two
   interiors are stand-ins (`bg_counting_house` renders on the *death
   court* backdrop — recognizable to any player who has died;
   `bg_wickhouse` on `bg_mereside`).
8. **Real economy exploits** (chaos track, evidence-grade):
   - Quest-level `grant_growth` is never applied — the **chapter finale's
     +2 max HP reward silently vanishes** (`quests.json:1441,1587` vs
     `game.gd:1853-1894`).
   - Energy laundering: charge a skill, win without firing — the fed card
     returns to the spool AND the power persists into the next fight.
   - Withdraw-farm: `once` quests reset on withdraw with full heal;
     slip-away banking makes the best ones an unbounded riskless gleam
     printer.
   - Force-quit mid-losing-fight dodges the refusal fee, the Toll, and a
     mortal life — death by swipe-up, in a game whose spine is death.

## THE UGLY (ship blockers — the store cannot receive this game today)

1. **No build pipeline exists.** No `export_presets.cfg`, no icon (the
   splash logo is itself a placeholder), no signing, no AndroidManifest, no
   boot splash config. Nothing produces an APK/AAB/ipa.
2. **The account/legal clock never started** (all owner-only): no Google
   Play account (the 12-testers-for-14-days gate is the longest pole and
   hasn't begun), no Apple enrollment, no Mac decision, **AI-tool commercial
   terms still unverified** (existential — wrong tier invalidates shipped
   assets), no privacy policy text or URL, no IARC rating.
3. **No IAP code** against a fully decided model (free Ch1 → $6.99 "The
   Full Nine Lives"), and nothing behind the paywall yet.
4. **No safe-area handling.** Every fixed-zone screen is laid to 720×1280
   with no notch/gesture-bar allowance (`SafeAreaContainer` has been a doc
   TODO since the mobile UI research). This will be found on the first real
   device.
5. **Save safety is the genre's #1 one-star generator** (StS iOS case
   study): no cloud save, reinstall = total loss, no app-pause handler.
   Checkpoint-only is a defensible design but is currently an *undocumented*
   risk, and it interacts with exploit 8d above.
6. **A probable softlock in the first crossing tutorial** (`crossing`
   step 4 waits on a `put` that may be impossible if no way was chosen at
   the no-wait step 3) — on `follow_the_thread`, one of the two starting
   jobs.
7. **Visual defects the owner flags on sight, in every quest**: the
   Press-On wager card renders a giant near-black rectangle (code passes
   `color`, never `image` — `game.gd` `_offer_press_on`); coach bubbles
   cross the page stitching (`coach.gd:213` clamps to window, not page
   margins); damage floaters draw over modal dialogs (`battle.gd:1917`,
   z_index 60).
8. **The Hollow Court shipped unphotographed** in today's tour set — the
   surface the repetition law names as most at risk has no screenshot.

---

## What would move 7 → 9 (market evidence)

- An **ending that ends** + visible replayable variety (generated cases) —
  content volume is the single most repeated 7/10 sentence in this genre.
- **Port-quality polish at the Wildfrost-2024 bar** — no clipped text, no
  black boxes, safe areas. "This is where 7/10 becomes 9/10 for free."
- **Save safety** — an export/import path at minimum before cloud save.
- Marketing: lead with **the cat and the murder**, not the deck mechanics;
  market a complete story that grows (Dawncaster playbook), never
  "Chapter 1 of 9"; disclose AI art loudly, once, in our own words, before
  anyone discovers it (non-disclosure discovered later = worst outcome;
  the ref-image consistency pipeline is the best defense against pile-ons).

---

## The fix plan

Ordered by (player-visible damage × cheapness). Sizes are rough.

### Phase 0 — same-day defects (code, each with a test)
1. Apply quest-level `grant_growth` in `_finish_quest` (or forbid it in
   `Catalog.validate()` and move the two uses to steps). Unit test.
2. Fix the crossing tutorial wait-step ordering (step 3 `wait: true` on
   `choose`, or step 4 satisfiable by `choose` OR `put`); verify with the
   tour.
3. Press-On wager: pass the environment's image id, kill the black
   rectangle. Re-shoot one quest.
4. Coach bubble clamp → `UITheme.PAGE_MARGIN_LEFT/RIGHT`; floater z-index
   below modals. Re-shoot prologue battle beats.
5. Loaf tooltip reword (`skill_rules.self_stun`); masked-intent tooltip
   variant; commit the ~676 lines already sitting uncommitted in the tree.

### Phase 1 — the ending and the untaught rules (1–2 sessions)
6. **Chapter-end beat**: one authored closing card after `an_audience_of_wax`
   (the Casebook closes the file), a board note replacing `board_empty`
   post-chapter, and an ending screen using `mus_ending`. This is the
   single highest review-score line item in the game.
7. Stealth lesson (alarm source, threshold, SPOTTED cost) at the first
   stealth fight; Slip Away confirmation dialog naming both costs before
   the tap; standing lesson at first standing change + board shows why a
   gated note is grey; quantify the turn-8 escalation and the filing fee.
8. Story structure fixes from the critic's table: gate `night_rounds` /
   `garden_route` on `the_carrying` (the body must not wait); require
   `follow_the_thread` before `the_carrying`; a `favor_redeem` beat or an
   honest "a knot keeps" lesson line; retry variants for
   `the_ward_that_failed` (Bodkin) and `empty_coat`; one Tansy line at the
   Mantel; the Gravamen gloss; the Tallowman fight's one-line cause;
   diegetic payers for the five unpaid rewards; the two doubled motifs.
9. Wisp monotony: swap one early encounter per starting path for the dog /
   the goose, or give one wisp fight a twist intent.
10. The two long quests: mid-quest checkpoint on defeat, or split — needs
    an owner call on which (product constraint says 3–5 min).

### Phase 2 — economy & rules hardening (1 session, mostly tests)
11. Withdraw-farm: mark quest attempted-tonight on withdraw (no same-night
    full-heal relaunch) or make `once` quests bank at half only once per
    night; add the economy bound test vs `night_rounds`.
12. Energy laundering: `_digest`'s returned card must exclude cards whose
    value persists as skill power (extract the carryover math into
    `core/` so it's testable); chaos harness two-encounter chain mode with
    the conservation invariant.
13. Force-quit: write an open-prowl marker at `_start_quest` and settle it
    on next launch (satchel spills, fees file). Scenario spec
    `mortal_last_breath.json`.
14. Chaos coverage: pass scripted-fight flags (`no_retreat`, `hp_floor`,
    `doom_turn`) into `build_config` + `cornered` persona; fuzz the
    shipped loadout shape (Scratch-in-tray, ≤5 skills) and worn/carryover
    configs; clamp `gleam >= 0` and tonic-vs-cap in `_migrate`; register
    `paws` in `DEFAULT_PROFILE` and actually pass it to battles; the
    standing/growth step-ordering invariant; the minigame-loss
    reachability invariant (keeps Ch2 honest).

### Phase 3 — the shipping layer (parallel: owner actions + code)
15. **Owner, this week (wall-clock is the enemy)**: Google Play account +
    start the 12-tester/14-day clock; Apple enrollment + Mac decision;
    verify Kling/AI-music commercial tiers and file dated terms in
    `docs/publishing/`; commission the app icon (human-made, per
    OWNER-ACTIONS §4); reserve name/domain/handles.
16. Code: `export_presets.cfg` for Android + iOS, icon/splash wired into
    `project.godot`, an unsigned build on a real phone; then the
    `SafeAreaContainer` pass (every fixed-zone screen).
17. Privacy policy drafted + hosted; IARC questionnaire; store listings
    with the AI disclosure in our own words.
18. ~~IAP: one non-consumable + restore flow~~ **Superseded same day by
    owner decision (2026-08-31): the game launches free with a donation tip
    jar; Chapter 2 is sold when ready.** Launch billing shrinks to consumable
    tip products (no restore flow, no entitlement gating); it may even slip
    to the first update if it threatens the date. Supporter Pack is cut.
    See `docs/design/monetization.md`.
19. Save safety: decide cloud save vs export/import for v1, write the
    decision down; app-pause checkpoint handler either way.

### Phase 4 — the content answer (the 7→9 work, can trail the beta)
20. **Design and build generated cases** — the monetization plan's replay
    engine and the review-score ceiling-raiser. A design doc first; the
    catalog/scenario infrastructure is already shaped for it.
21. Art: real `bg_counting_house` and `bg_wickhouse` plates (the death-court
    stand-in is the most player-noticeable art defect); second views for the
    rooftops and parlor plates; the cheap quality queue (tuxedo-cat regen,
    green lamp tint, crops, deckle edges, energy glyph audit).
22. Achievements gallery screen (tracker is done; only the list is
    missing); Play Games / Game Center decision.
23. Photograph the Hollow Court + defeat-variant story pages; add both to
    the standing tour.

### Explicitly trimmable (the review found little fat — a good sign)
- The Wickrow-polite joke doubled within a minute (keep step 1's).
- The "toes out, waiting" image used twice (keep the first).
- Nothing else: no quest is cuttable, no scene over-explains. The game's
  problem is a missing last page, not excess pages.
