# Balance Notes — Simulated Playtests

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
