# Difficulty & Progression — calibration doctrine (owner, 2026-08-01)

## How difficulty is measured

Every scenario is calibrated against the bot harness (`tests/simulate.gd`),
in this order:

1. **The random-player baseline.** A scenario's floor difficulty = the
   random bot's outcome. Tutorials must be near-safe even for random play;
   standard quests should punish random play visibly (30–70% win); hard
   quests should defeat it outright.
2. **Specialized-loadout requirement.** To make a scenario HARDER, don't
   inflate numbers — require a win via the RIGHT tactical loadout. The
   proof: tactic-bots diverge (2026-08-01 dog: brawler 22%, defender 94%
   — the fight teaches blocking by punishing its absence).
3. **The three-loadouts rule.** Every STANDARD quest must be beatable by
   at least three very different loadouts (e.g. aggression, defense,
   stealth). If only one bot archetype can win, the scenario is a puzzle
   with one answer — retune it or reclassify it.
   - Exceptions, by design: narrative overweight fights with a taught
     retreat (prologue wraith), and designed-unwinnable fights (the
     Unpicked). There, retreat/defeat ARE the intended outcomes.
   - Calibration TODO: watch captain currently has two strong answers
     (defender 98, stalker 95) and one weak (brawler 26) — needs a third
     path or acceptance as a stealth-lesson quest.

## Level: the hidden calibration ruler

Ash has a level, 1–20, that the PLAYER NEVER SEES. No XP bar, no level-up
toast — growth arrives as mission rewards (a skill, a potent card, a
tonic, an extra paw). The level is our internal unit for "how much kit
does the player have", used to calibrate encounters.

- **Level 1 (prologue):** 10 max HP · 15-card deck, all value-1 energy ·
  3 paws · 3-card opening hand · loadout of 4 abilities incl. Scratch.
- **Curve:** levels get harder and harder to reach (roughly: a level per
  core quest early, per 2–3 quests by Ch3). Main campaign + a few side
  quests ends Ch3 around **level 15**; level 20 requires deep guild play,
  achievements, and optional bosses.
- **Expected ceilings** (main-path player, few side quests):
  - **End Ch1 ≈ level 6:** ~14 HP · 18-card deck with two or three 2s ·
    3 paws · 6–7 owned skills (still 4 out) · opening hand 3.
  - **End Ch2 ≈ level 11:** ~18 HP · 20-card deck, first 3-value card ·
    4 paws · opening hand 4 · one combo-unlocked higher-tier action.
  - **End Ch3 ≈ level 15:** ~22 HP · 22-card deck · 4 paws · opening
    hand 4 · two higher-tier actions · one guild-exclusive skill.
- **Upgrade axes** (owner list): starting hand size, paw count, max HP,
  skill points (acquire/upgrade skills), deck size. All are config knobs
  already supported by `CombatState.create` (`opening_hand`, `paws`,
  `player_max_hp`, deck contents) — reward tables just set them.

## Rules of engagement for scenarios

- **Repeatable vs one-shot:** filler/spar quests repeat freely (hunting
  runs, sparring against ally friends to test loadouts — no story cost);
  core quests are one-shot; some scenarios knock Ash out (fail forward)
  instead of killing.
- **Lives are spent, never taken** (owner 2026-08-11,
  [death-and-lives.md](death-and-lives.md)). An ordinary defeat is a Court
  REFUSAL — satchel lost, filing fee, Grudge, no life spent. A life is spent
  only at authored `mortal` beats (and, later, player stakes), so the
  nine-life ledger is a story instrument, not a fail meter. Losing must
  still sting; tune `prowl.refusal_rate` if it stops stinging.
- **Merchant gating:** the Magpie Exchange (and later merchants) refuse
  service until Ash completes their introductory quest — standing before
  shopping.
- **Higher-tier actions unlock through play:** using certain skill combos
  in a fight (e.g. Slink→Pounce from hidden) unlocks upgraded actions —
  discovery as progression.

## Current calibrated table (2026-08-01, 10 HP, all-1 deck, 3-paw)

See balance-notes.md for the full table. Headlines: tutorials safe
(vole/wisp 100% for tactic bots), dog demands defense (22% vs 94%),
wraith is now a true retreat lesson (0% win, stalker flees 66–78%),
Unpicked remains the designed loss.
