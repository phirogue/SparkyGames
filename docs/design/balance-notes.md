# Balance Notes — Simulated Playtests

## Pass 8 — Chapter 1's back half, priced against the economy (2026-08-08)

The four new fights (tallow hound, candle-golem, the Drowned, the
Tallowman) are the first content tuned **from the player's purse
outward** (owner direction): model what a player has banked by each
fight, price what a FOCUSED buyer owns (players concentrate purchases,
they do not spread), and sim those buildouts — not just the starter kit.

**The gleam model** (no deaths, no press-on declines; toll and spills
only lower it):
- Opening arc, core only: ~89 banked by the_wake (fights + reward_bonus).
- By the Drowned: ~130 core-only; ~180–220 with a side-quest pass.
- By the Tallowman: ~160 core-only; ~240+ with sides.

**The reference focused build** at Magpie prices (second 12, third 30,
tonic 25, free re-spool to the 10-card floor): three seconds + one third
of your humour + one tonic ≈ 91 gleam — affordable core-only by the
boss, mid-back-half with one side pass. Simmed as `claw` (feeds
Pounce/Swat) and `moon` (wild — and taxed +1 by Wickrow's ward-light,
which is the district rule doing its job against the obvious best buy).

| Scenario | brawler | defender | stalker | random |
|---|---|---|---|---|
| Tallow hound (no buys) | 33% | 76% | 95% | 15% |
| Candle-golem (no buys) | 26% | 86% | 77% | 14% |
| Drowned (no buys) | 33% | 63% | 98% | 8% |
| Drowned (claw / moon) | 100 / 100 | 100 / 100 | 100 / 100 | 69 / 17 |
| **Tallowman** (no buys) | 32% | 77% | 79% | 3% |
| **Tallowman** (claw) | 100% | 100% | 81% (19 flee) | 7% |
| **Tallowman** (moon) | 100% | 91% | 100% | 8% |

Read:
- **The chapter is a ladder**: street tier ~76–95% for careful shopless
  play, the Drowned demands either care or purchases, and the boss is
  beatable shopless with good play (77–79%) while face-tanking it fails
  (32%) — headroom preserved for Ch2–3, which should assume the focused
  2s/3s deck as the entry state, not the starter fifteen.
- **Buyers feel their money**: both focused builds close the boss in
  ~6–8 turns and walk out with the spool nearly dry (~1 card left) — the
  finale drains the night's whole resource, as it should.
- **Retuned during the pass**: Drowned 18→16 hp, Cold Hands 5→4 (was
  best-bot 34%, a mid-quest wall). Tallowman 32→24 hp, Warm Regards
  5→4, **Reform 4→2** — at heal 4 the cautious lines stalled to the turn
  cap (defender 0% *with a purchased deck*): a heal that out-paces
  patient damage is a 10-turn slug, which is the owner's stated not-fun.
  Rule kept from it: **a boss's heal must lose to patient damage**; its
  threat lives in the pierce/jam/hand pressure, not in undoing progress.
- **No price moved.** The curve reaches the reference build on core-only
  gleam by the boss; the plain-card good (Pass 7) already covers the
  early-game sink. If Ch2 wants a tighter market, raise enemy gleam
  slower rather than re-pricing the goods.

---

## Pass 5 — the purr commitment + banking removed (2026-08-08)

Changes this pass (owner battle review):
- **Purr holds Ash still**: while the channel runs, `play_skill` (Scratch
  included), `charge_skill` and `concentrate` are refused. Damage still
  breaks it; discard and Slip Away stay open.
- **Banking removed** ("what's the point of banking a card if it can be
  stolen") — hand-attacks steal from the hand only; Loaf remains the answer.

| Scenario | brawler | defender | stalker | random |
|---|---|---|---|---|
| Vole | 100% | 100% | 100% | 100% |
| Wisp | 100% | 100% | 100% | 95% |
| Dog | 39% | 97% | 54% (33% flee) | 11% |
| Wraith | 0% (100% flee) | 0% (100% flee) | 0% (98% flee) | 0% (100% flee) |
| Unpicked | 0% | 0% | 0% | 0% |
| Watch Captain | 84% | 52% | 81% | 7% |
| Wisp Pair | 97% | 89% | 99% | 15% |
| Empty Coat | 28% | **57%** | 85% | 2% |

Read:
- **The purr now has a price and the table shows exactly where**: the two
  fights where the defender liked to purr mid-fight moved — Empty Coat
  99 → 57, Wisp Pair 100 → 89 — while every fight where purring was already
  suicidal (dog 97, captain 52) is untouched. That is the intended shape: a
  heal that costs your turns is a commitment, not a free stat.
- **Coat's best line is now the stalker (85)**, with the defender a real but
  no longer dominant 57. Two viable paths remain; brawler face-first stays
  a bad plan (28). No retune needed.
- **Banking's removal moved nothing measurable** — the bots barely banked
  (it was a paw for no upside, which is why the owner cut it). It shows up
  as a rules simplification, not a balance change.
- Tutorial floors (vole/wisp 100%) and the wraith's flee-lesson
  (`withdraw_after` — every bot walks) are intact.

---

## Pass 4 — anti-turtle + the coat quest made real (2026-08-03)

Changes this pass (from the 2026-08-02 critical review):
- **Payment engine fix**: `can_pay`/`_pay` now share one card-level planner
  (a wild can no longer promise value across two humours) — no measurable
  effect at level 1, load-bearing once `_2`/`_3` cards circulate.
- **Pierce** (new intent mode): a health hit that ignores block — THE
  anti-turtle tool. Watch Captain's Regulation Peck is now pierce 3
  (was blockable 4).
- **Loaf** block 6 → **5** (efficiency outlier trim).
- **`empty_coat` quest is now completable**: its finale was the prologue's
  rag_wraith (0% win for every bot — a repeatable quest nobody could
  finish). New finale enemy **The Empty Coat** (14 hp, Cold Cuff 3 /
  Deep Pockets card-steal / Wrap Tight 4, no jam).
- **Swat wired**: garden_route's reward (was unobtainable). **Value-3
  cards wired**: Magpie "rare card" tier, 30 gleam (were unobtainable).

| Scenario | brawler | defender | stalker | random |
|---|---|---|---|---|
| Vole | 100% | 100% | 100% | 100% |
| Wisp | 100% | 100% | 100% | 95% |
| Dog | 39% | 97% | 54% (33% flee) | 11% |
| Wraith | 0% | 0% | 0%, 50% flee | 0% |
| Unpicked | 0% | 0% | 0%, 31% flee | 0% |
| Watch Captain | 68% | **52%** | 81% | 6% |
| Wisp Pair | 97% | 100% | 99% | 23% |
| Empty Coat (new) | 28% | 99% | 85% | 7% |

Read:
- **The captain is the first true anti-turtle fight**: pierce dropped
  defender 97 → 52 while brawler (68) and stalker (81) stand — three
  loadouts, three genuinely different odds. The doctrine's open TODO
  ("captain needs a third path") is closed.
- **Empty Coat**: two strong paths (defender 99, stalker 85) and one
  reckless one (brawler 28 — charging a coat face-first is supposed to be
  a bad plan; its sim kit assumes garden-first, so Swat is in the bar).
  Completable, hardest board quest, fitting its 16-gleam bonus.
- **Defender still rules the non-pierce map** (dog 97, pair 100, coat 99).
  One counter-fight exists now; whether every LATE-chapter elite needs a
  pierce/burn tool is the open question for pass 5 — decide when Ch1
  enemies land, not by nerfing the prologue.
- Loaf 6→5 alone moved nothing measurable — the block economy was not the
  lever; unavoidable damage was.
- Random baselines on quests fell (captain 6%, coat 7%): quest elites now
  clearly demand a kit and a plan. Tutorial floor unchanged.

---

## Pass 3 — draw-1 economy + mysticism wilds (2026-08-01, later)

Changes: exactly ONE card drawn per turn (opening 3 stays); moonlight
renamed MYSTICISM and made WILD (pays any cost; costs keyed "mysticism"
demand the real thing); purr recosted to guile 1; vole hp 5.
*(2026-08-02 update: the rename is reversed — the player-facing name is
**Moonlight** again; `mysticism` stays as the internal data id. The wild
mechanic is unchanged.)*

| Scenario | brawler | defender | stalker | random |
|---|---|---|---|---|
| Vole | 100% | 100% | 100% | 100% |
| Wisp | 100% | 100% | 100% | 95% |
| Dog | 39% | 99% | 54% (40% flee) | 11% |
| Wraith | 0% | 0% | 0%, 80% flee | 0% |
| Unpicked | 0% | 0% | 0%, 61% flee | 0% |
| Watch Captain | 68% | 100% | 99% | 34% |
| Wisp Pair | 97% | 100% | 99% | 52% |

The slow-draw economy IMPROVED the doctrine fit: tutorials safe, the dog
gives three differentiated answers, the watch captain approaches the
three-loadouts rule (brawler now viable at 68%), and random-player
baselines are clearly punished on quests without being hopeless. Wraith
remains the intended retreat lesson.

---

## Pass 2 — level-1 calibration (2026-08-01)

Owner recalibration: **10 max HP**, 15-card all-value-1 starter deck,
3-card opening hand, 3 paws, loadout capped at 4 abilities incl. Scratch.
Doctrine now in difficulty-and-progression.md (random baseline, wins via
specialized loadouts, three-loadouts rule for standard quests).

| Scenario | brawler | defender | stalker | random | Verdict |
|---|---|---|---|---|---|
| Vole (tutorial) | 100% | 100% | 100% | 100% | ✔ safe (hp 3→5 so Pounce alone can't finish — Scratch is taught) |
| Wisp (tutorial) | 100% | 100% | 100% | 84% | ✔ tactic bots safe; pure-random deaths are shuffled-deck artifacts — the real tutorial deck is ordered+coached |
| Dog (stage 2) | 22% | 94% | 74% (23% flee) | 22% | ✔ first true lesson: block or bleed. Specialized-loadout doctrine in action |
| Wraith (stage 3) | 0% | 0% | 0%, 66% flee | 0% | ✔ NOW A TRUE RETREAT LESSON: "you do not have to win this" is honest. Retreat banks progress; death shows the Hollow Court |
| Unpicked (boss) | 0% | 0% | 0%, 45% flee | 0% | ✔ designed loss, unchanged |
| Watch Captain (quest, 12hp) | 26% | 98% | 95% | 29% | ⚠ two strong answers, not three — needs a third path or reclassify as stealth lesson |
| Wisp Pair (quest, 12hp) | 68% | 100% | 96% | 71% | ✔ healthy spread |

Notes: the wraith stopped being tankable when the 4-slot loadout forced a
choice between Loaf and Pounce at 10 HP — no kit both survives 6-damage
sleeves and deals 18 damage from a 15×1 deck. Accepted as the prologue's
retreat lesson (its coach literally teaches Slip Away). Revisit if Ch1
rewards make a return match winnable — that's a satisfying loop.

---

*2026-07-30. Data from `game/tests/simulate.gd`: 4 bot strategies × 7
scenarios × 300 seeded runs each (8,400 full fights per pass). Run it any
time with:*
`godot --headless --path game -s tests/simulate.gd`

## The bots

- **brawler** — ambush approach, always plays the biggest damage skill.
- **defender** — wards, blocks incoming damage, purrs when safe, then attacks.
- **stalker** — stalk approach, attacks while healthy, slips away below 30% HP.
- **random** — random legal actions (the "confused new player" floor).

## Results after tuning pass 1 (2026-07-30)

| Scenario | brawler | defender | stalker | random | Verdict |
|---|---|---|---|---|---|
| Vole (tutorial) | 100% | 100% | 100% | 100% | ✔ safe teaching fight |
| Wisp (tutorial) | 100% | 100% | 100% | 100% | ✔ safe; random still loses ~4 HP |
| Dog (stage 2) | 91% | 100% | 98% | 85% | ✔ punishes carelessness ~10-15% |
| Wraith (stage 3) | **2%** | 94% | 25% win / 75% flee | 27% | ✔ the intended puzzle: aggression dies, defense wins, fleeing is honorable |
| Unpicked (boss) | 0% (dies T7) | 0% (dies T13) | 0%, 45% escape | 0% | ✔ scripted loss; pacing fixed (was T11–18) |
| Watch Captain (quest) | 100% | 100% | 99% | 91% | ⚠ still soft — revisit with real stealth pressure post-prologue |
| Wisp Pair (quest) | 100% | 100% | 100% | 100% | ⚠ early filler; fine for now |

## Tuning changes applied (pass 1)

- Rag-wraith *Empty Sleeve* 5 → **6** (defender win 98% → 94%; brawler stays dead)
- Unpicked *Hem Comes Loose* 3 → **5**, *Wear the Room* 4 → **6** (scripted
  death lands turns 7–13 instead of 11–18)
- Watch Captain HP 11 → **16**, *Regulation Peck* 3 → **4**
- Wisp Pair HP 10 → **12**

## Reading the design out of the data

1. **Multiple win paths exist** where intended: the wraith can be out-tanked,
   out-healed, or declined — and pure aggression is correctly fatal there
   while being optimal in tutorials. Strategy choice matters by stage 3.
2. **The energy clock works**: random play burns the deck (0.7–3.6 cards left
   vs 5–10 for skilled play) — waste is its own punishment, invisible but real.
3. **The retreat lesson is mechanical truth**, not just narration: the stalker
   bot banks progress on the wraith 75% of the time and escapes the boss 45%
   of the time.
4. **Known softness:** quest elites need their own pass once loadouts/long
   rests are in — bots don't yet feel alarm pressure (being spotted makes the
   goose hit harder, but it dies too fast to capitalize). Candidate fix:
   spotted also drains 1 energy per turn ("running loud costs wind").

## Open questions for the next pass

- Should defender's wraith line be harder than 94%? (Lean: yes — add the
  wraith's jam intent one slot earlier so purr discipline is tested.)
- Bot gap to humans: bots don't bank cards or use Case; add a "combo" bot
  before trusting mid-game numbers.
- Re-run this after EVERY content change — it's 30 seconds of CI-able truth.


## Pass 5 — the 2026-08-03 defect-review rules (re-simmed)

Four rules changed at once; the table above was re-run after all of them.

| change | why | what the sim says |
|---|---|---|
| Loadout 4 -> 5 abilities out | owner: "fit 5 actions on the battle screen" | no measurable swing in the prologue (the kits there are 2-5 wide anyway); quest cells unchanged because the sim's kits were already 4 |
| Approach costs ignore `cost_mod` | the chooser quoted a price it did not charge | stalker line unchanged outside Needle Lane; on fog maps Stalk now genuinely costs 2 Shadow, which is the tutorial's whole "your hand goes three to one" beat |
| Slipping away eats the enemy's WHOLE telegraphed move | retreat from a thief or an unraveller used to cost literally nothing | wraith stalker flee% holds at 50%, so retreat is still a real out, not a trap |
| `no_retreat` encounters | the Unpicked is not meant to be walked out of | **unpicked flee% 31% -> 0%, death 69% -> 100%** across every bot. The locked door is mechanical truth now, not a story claim the UI contradicted |
| Loaf guards the hand from theft | block answered damage; NOTHING answered theft, so hand-attackers were unanswerable | defender lines hold; the change is a new answer rather than a new number, so it should show up as build diversity in a later pass, not here |

Prologue deck note: the prologue now runs on ONE ordered 21-card deck laid
down at the vole fight, with each later fight naming its `opening_cards`.
Measured spool across a playthrough: **18 -> 17 -> 16 -> 13**, monotonically
down. Before this it read 5 at the vole and 9 at the wisp, because each beat
handed out a fresh pile of energy on top of a `refresh_spent` scene.


## Pass 6 — scripted fights, simmed as they actually ship

The prologue's last two encounters are authored beats, not balance problems,
and the sim was quietly lying about both because it built its own configs.
It now carries `hp_floor`, `doom_turn` and the scene-level `withdraw_after`.

| scenario | before | after | what it means |
|---|---|---|---|
| wraith | 0% win / 100% death (stalker 50/50) | **0% win / 0% death / 100% flee, ~5 turns, every bot** | The wraith cannot kill (`hp_floor: 1`) and the scene insists on the exit once turn 4 passes. Nobody dies to the lesson about declining a fight, and nobody grinds it down either — 18 HP is out of reach inside four turns |
| unpicked | 100% death, 4-9 turns | **100% death, <=6 turns, every bot** | `doom_turn: 6` ends it on schedule instead of letting the player spend nine turns losing |

Worth writing down: with only `hp_floor` and no forced exit, the wraith
became a **100% win at ~12 turns** for the brawler — an unkillable enemy is a
free win given enough turns. The damage floor and the scripted withdrawal are
one mechanic in two halves; neither ships without the other.


## Pass 7 — the cut stops being a gleam sink (owner, 2026-08-08)

The Magpie's "Cut a card" good (15 gleam) is gone. Cutting is now free
selection at the loadout's Spool popup: the profile keeps everything owned in
`card_pool` (schema v6), the deck is the wound-on subset, and the only rule
is `exchange.deck_floor` (10) — unchanged, and now enforced where the editing
happens instead of at the counter.

What this does to the economy:

- **Gleam loses one sink.** The remaining sinks are Add a card (12), the
  good shelf (30) and tonics (25). The cut sink priced *undoing a purchase*,
  which punished experimentation twice — the owner judged the deck a loadout
  decision, not a transaction. No combat number moved, so no sim delta is
  expected; the fuzzer and sim were run to confirm no rules regression.
- **Deck thinning is free at the floor.** A player can now run the 10-card
  spool from the moment they own 10 cards. Watch this: if thin-deck cycling
  proves dominant in later chapters, the lever is `exchange.deck_floor`
  (raise it), not re-pricing the cut.
- **New dial `exchange.tonic_hp` (2)** — was a hardcoded `+2` in the shop
  screen; the close-up popup now states it from the dial.
- **Plain value-1 cards now sold** (owner 2026-08-09): new good `plain` at
  **6 gleam**, priced at half a second — a second is exactly two firsts of
  worth, so the premium on the 2s (12) and 3s (30) is convenience-per-draw,
  not raw worth. Gives the early game a sink smaller than the 12-gleam
  entry step. No combat number moved.
