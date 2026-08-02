# Critical Project Review — The Nine Lives of Ashcat

**Date:** 2026-08-02 · **Reviewers:** four personas (game editor, game developer,
game marketer, player) · **Scope:** entire repo — code, data, docs, the 130-shot
screenshot tour, git history. Contested findings were verified directly against
`game/data/*.json` and the scripts before inclusion.

**Project age context:** first commit 2026-07-29 — the whole thing is four days
old. 28 commits, 5,351 lines of GDScript, 36 docs, a prologue you can actually
play. Several findings below would be ordinary at this age; they're listed
because they become expensive at week eight.

This is a read-only history doc per project convention. Decisions made from it
belong in `docs/design/`.

---

## Executive summary

The premise-mechanics fusion (nine lives = the roguelite loop, the tutorial
death as the inciting incident), the prose voice, and the calibration culture
(8,400-fight sim passes, screenshot tours, engineering laws) are genuinely rare
assets. The pure-rules core is the right skeleton for the replay/PvP ambition.

The real risks are: **a launch-critical content gap** (Chapter 1 is designed
around five non-combat mission modules — diplomacy, ritual, survival, escort,
heist — none of which exist in code), **a narrative-design contradiction** that
poisons clue-writing (the killer is planned to be "chosen late, after
playtesting," which breaks the fair-play mystery rules the docs also commit
to), **balance blind spots** (defender/turtle play wins ≥99% of every winnable
fight; the sim never tests the carried-over decks real prowls actually use; one
repeatable quest is probably uncompletable), **ship-blocking engineering debt**
(720×1280-only layout, assert-stripped error handling, untested saves), and
**two off-repo clocks nobody has started** (Google Play's 12-tester/14-day
closed test; commercial-rights verification for the actual art pipeline).

None of this is fatal at day four. All of it is fatal at week eight if ignored.

---

## The Good

1. **Premise-mechanics fusion.** Death = spending one of nine lives; the
   unwinnable prologue boss makes the tutorial death the *inciting incident*
   of the murder mystery. The achievement even canonizes it: "Nine Minus One —
   Fall to the Unpicked. Everyone does, once. That is rather the point."
   Losing teaches Slip Away, and the sim proves the lesson is mechanical
   truth (0% win, all bots), not narration. This is the cleanest
   lore-mechanics fusion in the genre and the project's moat.
2. **The prose voice.** "Voles say what flowers cannot." "Murdered in her own
   parlor, between the kettle boiling and the kettle screaming, which any
   professional will tell you is no time at all." "I took the kettle off the
   fire. One paw. It took three tries. Nobody will ever know." Top-decile
   writing for game docs, and the shipped prologue keeps the promise.
3. **The storybook UI direction.** Stitched-page frame, serif ramp, thread HP
   bar (the fraying-thread UI *is* the needlework lore), watercolor scenes.
   The Approach modal (Stalk / Ambush / Walk In — "Spend nothing. A door is a
   door.") is flavor and mechanics in one tap.
4. **Pure-rules core done for real.** `combat_state.gd` is RefCounted, no
   Node/FileAccess/global RNG, single `do_command()` entry, hand-rolled
   Fisher-Yates in `CoreRng`. The separation is enforced, not aspirational.
5. **Verification culture nobody at this scale usually has.** ~40 unit tests,
   4 bot personas × 300 seeds × 7 scenarios per balance pass, a 130-shot tour
   with tap-budget failsafe, zone calibration tooling, versioned saves with
   rolling backup, and 13 hard-won engineering laws written down.
6. **The difficulty doctrine.** Random-player baselines, the three-loadouts
   rule, per-cell verdict tables in `balance-notes.md` — including honestly
   flagged open defects (watch captain "needs a third path"). Best-in-class
   practice; protect it.
7. **Research → decision traceability.** Monetization design (free complete
   Ch1 + $6.99 single unlock, no ads/gacha/timers, offline-pure entitlement
   caching) follows the project's own research, which is honest about premium
   mobile's revenue ceiling. The paywall is even narratively engineered ("at
   maximum curiosity").
8. **The energy clock.** Spent-is-spent, no reshuffle: fuel gauge, fight
   timer, and retreat motivation in one mechanic, sim-verified ("random play
   burns the deck"). The charge/overpay and bank systems convert flooded
   draws into agency.
9. **Canon-safety patterns.** `when_outcome` victory/retreat/defeat prose
   variants; ordered tutorial decks so coach promises are deterministic;
   "dying is canon." These each cost a review cycle and are now law.

## The Bad

1. **Chapter 1's critical path doesn't exist.** The launch product
   (`chapters/01-case-file-wax-and-wick.md`) builds its five leads on five
   non-combat mission modules — diplomacy (Sway meter), ritual
   pattern-matching, survival, escort, heist/Alarm. Only combat exists.
   This is the single biggest gap between plan and build.
2. **The killer-selection plan breaks the fair-play contract.**
   `story-direction.md` wants the Unraveler "chosen late, after playtesting
   which ally players trust most"; `story-structure.md` mandates fair clues
   that "never lie outright" — and clues are already being planted (Brindle's
   half-second pause, the silver thread). You cannot do both. Decide the
   culprit now, or accept bluffable early clues. Blocks all Ch1 prose.
3. **Defender/turtle dominance.** Pass-3 sims: the defensive bot wins
   99–100% of every winnable scenario (vs brawler's 39–68%). Loaf (block 6
   for 1 guile) is the efficiency outlier, and no enemy escalates, enrages,
   or otherwise punishes stalling. The current shipped meta is "turtle wins."
4. **The sim tests fights that don't happen.** Every simulation runs a fresh
   15-card deck at full HP; real prowls **carry over** HP, spent decks, and
   charges between encounters (`game.gd:360-426`). Every multi-encounter
   number in `balance-notes.md` is systematically optimistic, and nobody has
   measured the depleted-deck state players actually experience.
5. **`empty_coat` is probably uncompletable.** Its final encounter
   (`q_coat_wraith`) is a rag_wraith — 0% win for all four bots at level-1
   kit — and retreating resets the quest to encounter 0. No sim covers
   upgraded kits, so nobody knows how much shop investment (if any) makes a
   16-gleam repeatable quest finishable.
6. **Rules-engine payment bug.** `can_pay` sums card *values*; `_pay` spends
   whole cards greedily per-humour (`combat_state.gd:208-225` vs `538-566`) —
   a multi-humour cost paid with a value-2 wild can fire the skill while part
   of the cost goes unpaid. Unreachable with the value-1 starter deck; live
   the moment the shop's value-2 cards (`hub_screen.gd:206`) meet a
   multi-humour cost. Poisons future server-side validation too.
7. **Fixed 720×1280 calibration vs real phones.** The entire layout system
   (PAGE_MARGIN consts, CONTENT_HEIGHT=1104, exact-sum zone templates) is
   calibrated to 9:16; store devices are 19.5:9–20:9 and
   `stretch/aspect="expand"` (project.godot) will stretch the page art and
   strand ~450px outside the zone math. Biggest ship-to-store risk in code.
8. **The replay/PvP claim is scaffolding.** CommandLog records commands, but
   the battle seed (`Time.get_ticks_usec()`, battle.gd:196) is never stored,
   nothing serializes (seed, log), no replay reconstructor exists, and no
   test replays a fight to an identical end state. Meanwhile the prowl
   economy (carryover, refunds, PRESS_ON_MULT, TOLL_RATE) lives in the scene
   layer — outside core, outside the log, unreproducible and untested.
9. **Saves: untested and shallow-merged.** Zero SaveService tests; `_migrate`
   uses shallow `Dictionary.merge`, so new *nested* DEFAULT_PROFILE keys
   never reach existing saves — directly undermining law 7 on the platform
   (mobile) where save corruption hurts most.
10. **Post-prologue loadout overflow.** The player owns 5 skills after the
    prologue; core equips all of them, the battle UI clamps the tray to 4
    (battle.gd:1086), and enemy jam intents can target skills the player
    can't see. No loadout picker exists.
11. **Release builds strip the error handling.** JSON loading and
    unknown-effect guards are `assert`-based — compiled out of release
    exports. On-device, a malformed file is a silent crash; an unknown effect
    is a silent no-op.
12. **Dead and over-capped content.** Swat has no unlock path anywhere; all
    four value-3 energy cards ("Blood Up", "The Long Game", "New Moon",
    "Needle's Eye") are defined but unobtainable. Meanwhile the +2 HP tonic
    caps at 30 HP vs the difficulty doctrine's expected ~22 at end of Ch3,
    and infinitely repeatable quests fund grinding past every calibrated
    ceiling — a state no sim covers.
13. **Prototype-scale variety.** 6 obtainable skills, ~5 live enemies, 3
    repeatable quests, no in-run pickups (press-on is just a gleam
    multiplier), all encounters single-enemy (`enemies` arrays never exceed
    length 1 — wisp_pair is one 12 HP entity pretending to be two), and 23
    achievements that demand 50 wins / 200 energy against ~15 minutes of
    unique content.
14. **The mystery has no memory.** A case advances a couple of lines per
    3–5-minute run across many runs, and no recap/"previously on" mechanism
    is designed anywhere. A lapsed player re-entering mid-case has nothing.
    (The Casebook/journal exists; a case-so-far view does not.)
15. **The Moonlight→Mysticism rename is half-propagated.** The humour was
    renamed and redefined as a wild, but world-bible lore ("moonlight is
    thread that hasn't been used yet"), story-structure clue categories,
    chapters/01 district rules, and core-gameplay's own tables still say
    Moonlight — and no skill actually uses Mysticism, so the "reserved for
    very special actions" promise has zero instances.
16. **God objects where the next features land.** battle.gd is 1,351 lines,
    game.gd 671 (orchestration + settings + title + notices + economy).
    Approach effects, shop prices, toll/press-on rates, and environment
    effects are hardcoded strings in scripts — against the project's own
    data-driven law — and `Catalog.validate()` never actually runs in the
    shipped scene (it runs in dead-code main.gd and tests only).

## The Ugly

1. **The title screen says "The Nine Lives of of Ashcat."** A duplicated "of"
   baked into the AI-generated title art, on the first screen any player,
   reviewer, or featuring editor sees (`screenshots/02_title.png`).
2. **The designed loss is undermined by bugs.** Falling to the Unpicked is
   the story's best beat — and the defeat screen shows "**HP: -1/10**" under
   a modal whose only button is labeled "**…**"
   (`screenshots/118_battle_outcome_the_unpicked.png`). Players who miss the
   framing will read "broken," not "canon."
3. **Visible UI overflow in the current tour.** Hub bottom action buttons
   clipped by the page edge (`128_hub.png`); energy-card labels ("Ferocity",
   "Mysticism") half-hidden under card frames; the coach bubble occludes the
   environment rules text (`08_battle_open_the_vole.png`).
4. **A compliance rule pointing at a dead vendor.** README, CLAUDE.md,
   story-direction.md, and monetization hard rule #4 all say **Midjourney**;
   the actual pipeline is ChatGPT + Kling, whose commercial-rights tier is
   explicitly flagged *unverified* in `asset-pipeline.md`. The rights
   diligence for the real tools has never been done. Art manifest: 2 of 24
   assets approved.
5. **The flagship marketing line is untrue.** The marketing research scripts
   "I hand-drew every card in my cat detective game" — the art is
   AI-generated. Shipping that copy is a discoverable misrepresentation and
   a worse review-bomb scenario than the AI art itself.
6. **Two clocks that cannot both be true.** Roadmap: launch at week 8. The
   8-week pre-launch marketing checklist: not started. Google Play's
   12-tester/14-day closed test: not started (a hard gate on production
   access). The Play account itself ("Start this NOW," 2026-07-29): no
   evidence it exists.
7. **Publicly stale README.** "Phase 1 — Design," a `src/` folder that
   doesn't exist, Midjourney, and "nine(-thousand) lives" undercutting the
   world bible's exactly-nine tension.
8. **PowerShell round-trip artifacts in the data.** `enemies.json` and
   `encounters.json` carry `'` escapes and 20-space indentation from a
   ConvertTo-Json round trip — the exact failure mode law 4 exists to
   prevent, sitting in the two files it wasn't written about.

---

## Persona reviews

### 🖋 The Editor (creative director)

This is the rare pitch where I don't have to squint. A murdered witch's cat
spending nine lives to solve her murder; magic as needlework reaching all the
way into the UI (the HP bar frays); death as bureaucracy; the tutorial loss as
the inciting incident. The synthesis is distinctive even where the parts are
borrowed — Hollowmere is Ankh-Morpork by way of Neverwhere, and the docs know
it. And the cat's-eye discipline (humans named by function: the Fish-Giver,
the Loud Widow) is executed, not just claimed.

Two editorial dangers. First, **preciousness**: every proper noun is quirked —
Court of Whiskers, Magpie Exchange, Quiet Gentleman, Tatterstage — and the
prologue exceeds its own joke budget ("fish, buttons, gossip, gossip about
fish"). The world bible's rule against "dark/shadow/blood + noun" names shows
self-awareness about cliché but not about whimsy fatigue, which is the real
exposure. Enforce the joke-per-scene budget in edit, and give the Guild
antagonists a register that isn't the narrator's.

Second, and blocking: **you cannot choose the killer after playtesting and
also play fair.** Fair-play clues that "read differently in hindsight" must be
planted from Chapter 1 for a culprit who exists from Chapter 1. Decide the
Unraveler before another line of Ch1 prose. Related spine debt: the rival
witch listed among the four suspects appears in no chapter plan or guild
table; the Ninth Bell is both Ch3's title and a Ch2 side quest that resolves
the bell; a Chapter 4 side quest (the endgame pocket-mending payoff) is
homeless in a 3-chapter structure; and the nine shadow-pockets — the
equipment system, the death-cost fiction, *and* the emotional endgame — are
canon in the world bible and absent from every progression doc and data file.

Structurally, one run = one lead is the right atomic unit, and evidence-as-
objects keeps the text budget honest. But a mystery drip-fed two lines at a
time across dozens of runs needs a case-so-far recap screen, and none is
designed. And the docs have three different text-budget laws while the
shipped prologue violates all of them; pick one.

**Verdict:** exceptional premise, real voice, two blocking decisions (culprit
now; recap mechanism before Ch1), and a documentation corpus whose main debt
is that the owner's 08-01 decisions were never back-propagated —
Moonlight→Mysticism alone infects four docs.

### 🔧 The Developer

The architecture is better than most shipped mobile card games: genuinely
pure rules core, seeded RNG, command-pattern actions, data-driven content
with reference validation, versioned saves with backup fallback, and a
test/sim/tour loop most studios don't have. Day-four me is impressed.

Ship-blocking me is not. Three things would embarrass us on a store device:
the 720×1280-calibrated layout on 20:9 phones (decide the tall-screen
strategy *before* any more pixel calibration — every calibrated constant is
a migration liability); assert-stripped error handling turning malformed
JSON into undiagnosable release crashes; and the `can_pay`/`_pay` wild-card
divergence — a correctness bug in the one layer whose entire point is
correctness.

The replay/PvP story is currently a promise, not a property: seed never
persisted, log never serialized, no replay test, and the prowl economy
implemented in `game.gd` where no log can see it. Either wire a
record→replay→identical-state test now — it's cheap — or stop citing
replays as an architectural constraint. Relatedly: `Catalog.validate()`
never executes in the shipped scene (main.gd is dead code giving false
comfort), and the save layer — the most user-hostile place to have a bug on
mobile — has zero tests and a shallow merge that defeats law 7.

Debt is concentrated exactly where the next features land: battle.gd (1,351
lines) and game.gd (671) are God objects; `encounters[].enemies` is an array
of which only `[0]` is ever read; environment effects are engine-interpreted
magic strings; approach costs, shop prices, and toll rates are hardcoded
against the project's own law. Smaller but real: charging and auto-pay count
alarm differently for the same overpaid card; one test (`test_loaf_stuns_
self`) can silently pass by doing nothing; simulate.gd duplicates the
starter deck and can drift from DEFAULT_PROFILE.

**Verdict:** right skeleton, real tooling. Fix pay/aspect/saves/asserts,
wire the replay test, move the prowl economy into core, and stop letting
meta-rules leak into scenes before the codebase calcifies.

### 📣 The Marketer

The research is the best I've seen from a solo project — honest about the
premium-mobile ceiling (4–5 figures without featuring), correct that paid UA
is dead at ~$0.35/install LTV, smart about chapter releases as Apple
featuring re-nomination events. The $6.99 single unlock undercuts Balatro
and fits the offline architecture perfectly.

The problem is that *none of the execution has started*. No Play account
evidence, no closed test (a hard 14-day gate), no icon (which your own
research calls the single highest-leverage image and says must be
human-made), no privacy policy, no age rating (a murder-investigation game
with a body scene needs the IARC questionnaire answered thoughtfully), no
social presence, no press kit, no Steam page even though your research says
that's where this audience actually lives. For an organic-only strategy the
audience runway *is* the budget, and the balance is zero.

Two risks are existential. **Art:** 2 of 24 manifest assets approved, style
consistency unproven at the ~200-asset scale your differentiation claim
rests on, and commercial rights on the actual (Kling/ChatGPT) pipeline
explicitly unverified — an Apple 4.3 rejection or a rights takedown kills
the launch. **Copy:** "I hand-drew every card" is scripted in the outreach
plan and it is false; cat-content creators discovering that mid-campaign is
the worst possible discoverability event. Rebuild the angle on what's true —
the writing, the storybook design, the honest 3-minute premium hook.

Also unresolved: the free tier promises "endless/daily prowls" that no doc
designs; the $2.99 supporter pack is 4 lines of spec with no art manifest
entries; conversion past a deliberately generous free chapter has no
argument attached; and the SparkyGames/Ashcat brand split has no trademark
action despite AI art being uncopyrightable (trademark is the only IP moat
you get).

**Verdict:** best-in-class plan, zero execution. Start the Play clock and
the rights verification this week; purge "hand-drawn" from every draft.

### 🐈 The Player

I tapped through the whole tour. The first ten minutes are the best I've had
in a mobile card game in a while: the rooftop at dusk, "Voles say what
flowers cannot," the vole holding very still because it believes this is
working. The Stalk/Ambush/Walk In choice made me feel like a cat, not a
spreadsheet. And when the ghost in the parlor killed me, the game had the
nerve to make my death the point — "Everyone does, once. That is rather the
point" — and I *grinned*. That's the pitch, delivered.

Except the screen said I had "-1/10" health and offered me a button labeled
"…", which read less like "your death is canon" and more like "the game
broke." The difference between those two readings is the whole game, and
right now it's carried by a glitchy modal.

After the prologue: three errands on a board, same enemies each time. I
found the winning strategy in two runs — Loaf, block six, nap through
everything — and nothing ever punished me for it. One quest (the coat one)
ends in a fight I apparently cannot win at my level, and losing sent me back
to the start of the quest with nothing; I assumed it was bugged. The shop
buys real things (a card in, a card out, a tonic), which I like, but I hit
the interesting purchases fast and then gleam just… piles up. Buttons at the
bottom of my own mantel are cut off by the page edge; card names hide under
their frames. I love this cat. I love this city. I ran out of things to do
in it in an evening, and the title screen has a typo in it.

**Verdict:** first session 9/10, second session 4/10. I'd wishlist it on
the writing alone. I would not yet pay $6.99 — but I would come back and
check.

---

## Itemized lists

### 🔴 CHANGE (wrong as-is; fix before building new things)

| # | Item | Evidence |
|---|------|----------|
| C1 | Regenerate the title art — "of of" typo on the first screen | `screenshots/02_title.png` |
| C2 | Decide the Unraveler now (or accept bluffable early clues) — the choose-late plan breaks fair-play; blocks Ch1 prose | story-direction.md vs story-structure.md |
| C3 | Clamp HP at 0 and label the defeat button — the designed loss must read as canon, not a bug | shot 118 |
| C4 | Add anti-turtle pressure (escalation/enrage) and retune Loaf — defender ≥99% everywhere winnable | balance-notes.md Pass 3 |
| C5 | Make `empty_coat` completable (retune q_coat_wraith, or gate it, or don't reset progress on retreat) | encounters.json:82; 0% win table |
| C6 | Fix `can_pay`/`_pay` whole-card wild divergence + add multi-humour cost tests | combat_state.gd:208-225 vs 538-566 |
| C7 | Decide the tall-screen (19.5:9–20:9) strategy before any further pixel calibration | project.godot + UITheme consts |
| C8 | Fix UI overflow set: hub buttons clipped, card labels under frames, coach bubble over rules text | shots 128, 08 |
| C9 | Resolve loadout >4: build a picker or clamp at source | game.gd:362 vs battle.gd:1086 |
| C10 | Replace `assert`-based error paths with real handling for release builds; make `Catalog.validate()` run in the shipped scene | data_loader.gd:22, combat_state.gd:594, dead main.gd |
| C11 | Deep-merge `_migrate` + write SaveService round-trip/migration/backup tests | save_service.gd:64; law 7 |
| C12 | Purge "hand-drawn/hand-illustrated" from all marketing copy; rebuild the angle on what's true | marketing-research §2, §7 |
| C13 | One pass to fix the Midjourney→ChatGPT/Kling schism (README, CLAUDE.md, story-direction, monetization rule #4) and do the actual Kling/ChatGPT rights analysis | asset-pipeline.md flag |
| C14 | Finish the Moonlight→Mysticism rename: world-bible lore, clue categories, chapters/01 rules, core-gameplay tables — and give Mysticism at least one real skill | 4+ docs |
| C15 | Wire or cut dead content: Swat, all four value-3 energy cards | skills.json, energy_cards.json |
| C16 | Normalize the PowerShell-mangled JSON (`'`, deep indents) in enemies/encounters and stop the tool that did it | law 4 |
| C17 | Fix README staleness: phase, `src/`, Midjourney, nine(-thousand) | README vs world-bible |
| C18 | Fix journal_screen's hand-edited margins (52/52/44/48 → UITheme constants) — the one screen violating law 5 | journal_screen.gd:30-33 |

### 🟠 IMPROVE (right direction, needs work — priority order)

1. **Start the launch clocks now**: Play account, 12 testers, 14-day closed
   test — the longest-lead blocker; and verify Kling/ChatGPT commercial
   rights this week (existential).
2. **Scope Chapter 1's five mission modules honestly**: build the 2 cheapest
   (the "win-condition module + 1–3 special cards" costing in
   missions-and-environments.md is the right model), cut or combat-ify the
   rest, and pre-agree the cut list before week 3.
3. **Add a prowl-mode simulation** (carryover HP/deck/charges, upgraded
   kits, over-leveled grinder states) — every current multi-encounter number
   is optimistic; also give one bot Concentrate and Case usage.
4. **Wire and test replay**: persist the battle seed, serialize (seed, log),
   add a record→replay→identical-end-state test — cheap now, impossible
   after logs exist in the wild.
5. **Move the prowl economy into core** (a `RunState`): carryover, refunds,
   PRESS_ON_MULT, TOLL_RATE are scene-layer, unlogged, untested — the exact
   layer players grind against.
6. **Design the case-so-far recap screen** before Ch1 — the mystery
   currently has no memory across sessions.
7. **Add in-run variance**: make press-on offer real pickups (cards, charms
   for the nine shadow-pockets), not just a gleam multiplier; the pockets
   system is fully designed lore waiting to be the item system.
8. **Build multi-enemy support or flatten the schema** — `enemies[]` is a
   fiction today and the single biggest cheap variety win (wisp_pair is
   begging to be an actual pair).
9. **Data-drive the hardcoded rules**: approach effects, shop prices,
   toll/press-on rates, environment effect strings, PROLOGUE_SKILLS — per
   the project's own law — and extend `Catalog.validate()` to hard-indexed
   fields, achievement stat names, and reachability (dead skills/cards).
10. **Break up battle.gd (1,351) and game.gd (671)** before buffs and
    multi-enemy land in them.
11. **Reconcile the chapter math** (10 quests/chapter vs 5 leads + 5 sides),
    re-sync 00-prequel.md to the shipped prologue, resolve the Ninth Bell
    title collision and the homeless Ch4 side quest, restore or cut the
    rival-witch suspect, pick ONE text-budget law and trim the prologue to
    it.
12. **Spec or cut**: endless/daily prowls (promised in monetization.md,
    designed nowhere), the Fate deck (spec'd, absent), the supporter pack
    (4 lines, no manifest entries), difficulty bands' ship window.
13. **An aphorism/joke budget edit pass** on chapter drafts; a distinct
    voice register for the Guild of Wick and Tallow.
14. **Reconcile the tonic cap** (30) with the difficulty doctrine (~22 end
    of Ch3); author a `danger` field on encounters instead of hp/4 pips.
15. **Consolidate core-gameplay.md** — the v0.3 header supersedes half the
    body; a stranger implementing from the body builds the wrong game. Add
    "superseded by" pointers to the two brainstorm docs that recommend a
    different game.
16. **Create a Steam page** (free top-of-funnel where the audience lives)
    and start the icon commission — your research calls it the highest-
    leverage image and requires it be human-made.
17. **Settings depth**: music/SFX split, credits, privacy policy link, save
    management — the store checklist demands most of it anyway.
18. **Type the core** (`Array[String]` zones, an Outcome enum) and unify the
    alarm accounting between charge and auto-pay paths.

### 🟢 KEEP (working — protect these)

1. The nine-lives premise fusion and the designed-loss tutorial — the moat.
   Never admit a feature that doesn't serve it.
2. The prose voice and cat's-eye POV discipline (with the joke budget
   enforced).
3. The storybook UI direction, the thread HP bar, and the Approach decision
   point.
4. The pure-rules core + CoreRng + do_command architecture — finish wiring
   the replay claim it exists for.
5. Spent-is-spent energy as the fight clock. The law is correct; content
   must bend to it.
6. The charge/overpay + bank + paws economy — the game's best mechanical
   ideas; extend charge to more skills.
7. The verification culture: tests, 4-persona sims, screenshot tour,
   calibration tooling, the 13 laws, and the pass-over-pass balance
   methodology (8,400 fights/pass with per-cell verdicts).
8. `when_outcome` canon-safety variants — hard content rule for every
   future encounter.
9. The monetization shape: free complete Ch1 + $6.99 single unlock, no
   ads/gacha/timers, offline entitlement caching, chapters as featuring
   events, narratively-placed paywall.
10. Honest revenue expectations and research discipline — writing down
    what's true is the project's culture. This review exists because the
    repo made it possible.

---

## The one-paragraph verdict

A four-day-old project with the skeleton, voice, and verification culture of
something much older (complimentary). The moat — death as canon, prose that
earns its whimsy, a rules core built for replays — is real. What stands
between this and a launchable Chapter 1 is not inspiration: it's five
unbuilt mission modules, one unmade narrative decision (the killer), a
turtle-shaped hole in the balance, a layout that fits no modern phone, and
two off-repo clocks (Play closed test, art rights) that nobody has started.
Fix the math the sim can't currently see, start the clocks, tell the truth
in the marketing, and this is a real game.
