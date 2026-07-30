# Balance Notes — Simulated Playtests

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
