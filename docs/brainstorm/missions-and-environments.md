# Mission Variety & Environmental Effects

> **Decision note (2026-08-03):** Chapter 1 ships **combat + heist/Alarm +
> ritual** only. Diplomacy becomes choice-scenes; survival and escort are
> deferred to Ch2+. The menu below is still the long-term ambition — the
> shipping cut list lives in
> [chapter1-build-plan.md](../design/chapter1-build-plan.md) Phase 0.
> (This doc predates the no-PvP decision; PvP is out permanently.)

Owner request: vary *what you do* in a run (stealth, hack & slash, diplomacy,
escort, …) and make the *environment* an active gameplay force. Both ideas
attack the same risk — that 3–5 minute runs blur together — and both have
strong precedents.

## Why this matters for a short-run game

In a 45-minute roguelite, variety comes from within the run (many encounters,
branching maps). In a 3–5 minute game, variety must come from *between* runs:
each run should feel like a different *kind* of task in a different *place*.
Mission types × environments is a multiplication table of run flavors that
reuses the same card engine.

## Mission types (the "quest verb")

Each quest on the quest board has a verb that changes the run's win condition
and scoring — the card engine stays the same, the goal changes. Precedents:
Gloomhaven scenario objectives, Card Thief (pure stealth as a card game),
Marvel Snap locations, Slay the Spire events.

| Mission type | Win condition twist | How cards feel different |
|---|---|---|
| **Hack & slash** (baseline) | Defeat all foes before your deck/turns run out | Pure combat value |
| **Stealth** | Reach the goal keeping the **Alarm meter** below threshold; loud cards raise it, subtle cards don't | High-power cards become risky; weak/quiet cards get a role |
| **Diplomacy** | Fill a **Resolve/Sway meter** instead of dealing damage; "attacks" become arguments, "block" becomes composure | Same numbers, reskinned as a battle of wits — cheap to build, huge for story |
| **Escort** | A **Ward** (NPC card on your side) must survive; enemies target it | Defensive/redirect cards shine; introduces protect-the-ally tension |
| **Heist** | Grab N **treasure cards** shuffled into the encounter and *escape* — you choose when to run (push-your-luck hook) | Greed vs safety every turn |
| **Survival / Hold the line** | Survive X turns of escalating waves; no kill requirement | Stall/sustain archetypes get their moment |
| **Hunt** | One elite foe with phases/telegraphed big attacks | Boss-puzzle feel; burst timing matters |
| **Ritual / Race** | Complete a card-combo objective (e.g., play 3 flame cards in one turn) before the timer | Combo archetypes; puzzle-like |
| **Rescue** | Reverse-escort: fight *to* the captive, then escort out — two-phase run | Mid-run gear shift |

Design rules:
- Every mission type must be explainable in **one line** on the quest card.
- All types share one card engine — a mission type is a *win-condition module +
  1–3 special cards/rows*, not a new game mode. Target cost: small.
- Class × mission synergy creates strategy at the quest board: a stealthy class
  breezes a stealth mission; bringing the wrong class is playable but hard mode.
  (Choosing *who* to send on *what* is itself a fun decision — very Gloomhaven.)
- Launch scope suggestion: 4 types (hack & slash, stealth, escort, diplomacy),
  add others post-launch as quest-line unlocks with story framing.

## Environmental changes & effects

Marvel Snap's *locations* are the proof: one revealed modifier per zone
multiplies variety at almost zero content cost. For us, environments come in
three layers:

1. **Region skin + rule (per quest):** the quest's location sets art backdrop
   and one persistent rule for the whole run. Examples:
   - *Embermarsh* — fire cards cost 1 less, but water foes resist them
   - *The Long Dark* — your light dims each turn; unplayed cards "freeze"
   - *Sunken Library* — first card played each turn is silenced (whisper rule —
     pairs with stealth missions)
2. **Weather/omen (per run, drawn at start):** a run-wide modifier drawn from a
   small pool, so the same quest replays differently: *Blood Moon* (all damage
   +1), *Thick Fog* (enemy intents hidden), *Pilgrim's Wind* (draw +1 first
   turn). This is the cheap replayability engine for repeatable quests.
3. **Turn events (mid-encounter beats):** on a known turn, something happens —
   reinforcements, a bridge collapses splitting the lanes, the tide comes in
   and floods the bottom lane. Telegraphed one turn ahead so it creates
   planning, not chaos.

Design rules:
- Environment effects must be **visible as a card/banner** on the board (tap to
  read) — no hidden modifiers.
- Effects should *bend* strategy, not invalidate decks (Snap's lesson: the fun
  locations change how you play; the hated ones say "you don't get to play").
- Environments are also **story delivery**: the region rule *is* worldbuilding
  ("cards freeze in the Long Dark" teaches the setting mechanically).
- Midjourney fit: regions need 1 backdrop + 1 icon each; weather needs an icon
  each. ~8–12 backdrops covers a launch world map — very affordable.

## How it plugs into the run structure

```
Quest board (between runs)
  └─ pick quest → defines: mission type + region rule + story stakes
       └─ run start → draw weather/omen
            └─ encounters 1..3 → region rule + weather active; turn events fire
                 └─ resolution scene → story beat, rewards, next quests unlock
```

Variety math at launch: 4 mission types × ~8 regions × ~6 weathers ≈ 190
distinct run flavors before counting classes, decks, or quest scripting.

## Open questions

1. Do mission types need separate tutorial quests, or is one-line onboarding
   enough? (Lean: teach each type via its first story quest.)
2. Should weather be player-influenceable (e.g., a class that changes weather)?
   Fun, but adds balance surface.
3. PvP interaction: mission types are PvE constructs; PvP would use the
   baseline duel + environments only (environments are PvP-safe, mission types
   mostly aren't — escort/stealth vs a human needs its own design pass).
