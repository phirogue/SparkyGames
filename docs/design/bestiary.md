# Bestiary — every enemy's hand of tricks

**GENERATED FILE — do not hand-edit.** Rebuild with:

    godot --headless --path game -s tests/bestiary.gd

Source: `game/data/enemies.json`, `encounters.json`,
`environments.json`. Balance numbers live in
[balance-notes.md](balance-notes.md); this is the reference for what
each creature actually DOES on its turn.

## How to read an enemy

Enemies hold no energy deck — the deck is the player's clock. An
enemy's equivalent is its **intent cycle**: a fixed, repeating list of
moves, shown one turn ahead so every hit is answerable. The cycle IS
the strategy, which is why it is printed in order.

| Target | What it does | The player's answer |
|---|---|---|
| `health` | Damage, reduced by block | Block, or kill it first |
| `health` + `pierce` | Damage that **ignores block** | Out-damage it; turtling loses |
| `skills` + `jam` | Locks a skill for N turns | Spread the loadout; hold a second answer |
| `skills` + `burn` | Destroys a skill charge **permanently** | Spend charges before they are taken |
| `hand` | Steals energy from hand (or bank) | Play cards out; bank what matters |

From **turn 8** every enemy strike gains +2 per turn (the night
presses). No fight is meant to last past ~turn 10.

## Where they are fought

An environment bends every fight in it, so the same enemy is a
different problem in a different place.

| Place | Rule | Cost changes | Sunbeams | Alarm |
|---|---|---|---|---|
| The Back Gardens | Sleeping houses: Ferocity costs 1 more and raises the Alarm. | Ferocity +1 | - | spotted at 5 |
| The Hollow Court | No sun has ever reached this desk. | - | - | - |
| Needle Lane, Night | Deep fog: Shadow costs 1 less. | Shadow -1 | - | - |
| Needle Lane, Wrong | The lamps are out. The dark is deeper than it should be. | Shadow -1 | - | - |
| The Parlor | Her room remembers her: Mysticism costs 1 less. | Moonlight -1 | - | - |
| The Parlor, Before | Warm, and hers. | Moonlight -1 | turns 2, 4 | - |
| The Rooftops, Dusk | Last light: sunbeams on turns 2 and 4 return a spent card. | - | turns 2, 4 | - |
| The Shambles, After Hours | Everything is negotiable: Guile costs 1 less. | Guile -1 | turns 3 | - |

---

## The Dog (On a Chain)  <sub>`chained_dog`</sub>

> Wished to discuss territory. The meeting was declined.

**12 hp**  ·  **7 gleam**  ·  cycle of 3, repeating

Fought in: A Meeting Declined (Needle Lane, Night), The Usual Objection (Needle Lane, Night)

| Turn | Move | Target | Effect |
|---|---|---|---|
| 1 | **Bark** | `hand` | steals 1 energy from hand (bank if hand is empty) |
| 2 | **Lunge** | `health` | 4 damage, blockable |
| 3 | **Slaver** | `health` | 2 damage, blockable |

**Strategy:** Averages **2.0 damage a turn** over its cycle (biggest single hit 4). Takes roughly **4 turns to bring down** at 3 damage a turn. **Steals energy** — play cards out rather than holding a fat hand.

---

## The Garden Watch  <sub>`garden_watch`</sub>

> A goose. Nobody warned you about the goose.

**8 hp**  ·  **5 gleam**  ·  cycle of 3, repeating

Fought in: The First Garden (The Back Gardens)

| Turn | Move | Target | Effect |
|---|---|---|---|
| 1 | **Patrol** | `health` | 1 damage, blockable |
| 2 | **Sniff About** | `hand` | steals 1 energy from hand (bank if hand is empty) |
| 3 | **Peer Into Shadows** | `health` | 2 damage, blockable |

**Strategy:** Averages **1.0 damage a turn** over its cycle (biggest single hit 2). Takes roughly **3 turns to bring down** at 3 damage a turn. **Steals energy** — play cards out rather than holding a fat hand.

---

## Captain of the Watch  <sub>`garden_watch_captain`</sub>

> The goose has a chain of office. It is load-bearing.

**16 hp**  ·  **8 gleam**  ·  cycle of 3, repeating

Fought in: The Captain's Lawn (The Back Gardens)

| Turn | Move | Target | Effect |
|---|---|---|---|
| 1 | **Sniff About** | `hand` | steals 1 energy from hand (bank if hand is empty) |
| 2 | **Honk of Authority** | `skills / jam` | jams a random ready skill for 1 turn(s) |
| 3 | **Regulation Peck (past the guard)** | `health / pierce` | 3 damage, **ignores block** |

**Strategy:** Averages **1.0 damage a turn** over its cycle (biggest single hit 3). Takes roughly **6 turns to bring down** at 3 damage a turn. **Pierces** — blocking is not an answer here, and a defensive kit will lose the race. **Jams** — bring a second answer, or a jam lands on your only one. **Steals energy** — play cards out rather than holding a fat hand.

---

## Gutter-wisp  <sub>`gutter_wisp`</sub>

> Bottle-sized. Eats small lies. Wants what you're holding.

**6 hp**  ·  **4 gleam**  ·  cycle of 2, repeating

Fought in: The Vole Dispute (The Rooftops, Dusk), Something in the Gutter (The Rooftops, Dusk)

| Turn | Move | Target | Effect |
|---|---|---|---|
| 1 | **Flicker Bite** | `health` | 2 damage, blockable |
| 2 | **Covet** | `hand` | steals 1 energy from hand (bank if hand is empty) |

**Strategy:** Averages **1.0 damage a turn** over its cycle (biggest single hit 2). Takes roughly **2 turns to bring down** at 3 damage a turn. **Steals energy** — play cards out rather than holding a fat hand.

---

## Rag-wraith  <sub>`rag_wraith`</sub>

> Clothes whose owner is missing. Not dead. Missing.

**18 hp**  ·  **12 gleam**  ·  cycle of 3, repeating

Fought in: The Wrong Quiet (Needle Lane, Night)

| Turn | Move | Target | Effect |
|---|---|---|---|
| 1 | **Empty Sleeve** | `health` | 6 damage, blockable |
| 2 | **Unravel** | `skills / jam` | jams a random ready skill for 1 turn(s) |
| 3 | **Smother** | `health` | 3 damage, blockable |

**Strategy:** Averages **3.0 damage a turn** over its cycle (biggest single hit 6). Takes roughly **6 turns to bring down** at 3 damage a turn. **Jams** — bring a second answer, or a jam lands on your only one.

---

## The Empty Coat  <sub>`the_empty_coat`</sub>

> Out wearing someone's evening. It fits nobody. It tries everyone.

**14 hp**  ·  **9 gleam**  ·  cycle of 3, repeating

Fought in: The Coat Itself (Needle Lane, Night)

| Turn | Move | Target | Effect |
|---|---|---|---|
| 1 | **Cold Cuff** | `health` | 3 damage, blockable |
| 2 | **Deep Pockets** | `hand` | steals 1 energy from hand (bank if hand is empty) |
| 3 | **Wrap Tight** | `health` | 4 damage, blockable |

**Strategy:** Averages **2.3 damage a turn** over its cycle (biggest single hit 4). Takes roughly **5 turns to bring down** at 3 damage a turn. **Steals energy** — play cards out rather than holding a fat hand.

---

## The Unpicked  <sub>`the_unpicked`</sub>

> A shape wearing the room's unravelled threads. Prologue only: it is not meant to be beaten. Yet.

**60 hp**  ·  **0 gleam**  ·  cycle of 4, repeating

Fought in: The Parlor Window (The Parlor)

| Turn | Move | Target | Effect |
|---|---|---|---|
| 1 | **Pull a Thread** | `hand` | steals 1 energy from hand (bank if hand is empty) |
| 2 | **Snip** | `skills / burn` | burns 1 charge off a random ready skill, **permanently** |
| 3 | **The Hem Comes Loose** | `health` | 5 damage, blockable |
| 4 | **Wear the Room** | `health` | 6 damage, blockable |

**Strategy:** Averages **2.8 damage a turn** over its cycle (biggest single hit 6). Takes roughly **20 turns to bring down** at 3 damage a turn. **Burns charges permanently** — use a skill before it is taken, not after. **Steals energy** — play cards out rather than holding a fat hand.

---

## The Vole  <sub>`the_vole`</sub>

> It holds very still. It believes this is working.

**5 hp**  ·  **1 gleam**  ·  cycle of 2, repeating

Fought in: The Hunt (The Rooftops, Dusk)

| Turn | Move | Target | Effect |
|---|---|---|---|
| 1 | **Hold Very Still** | `health` | 0 damage, blockable |
| 2 | **Dart for Cover** | `hand` | steals 1 energy from hand (bank if hand is empty) |

**Strategy:** Averages **0.0 damage a turn** over its cycle (biggest single hit 0). Takes roughly **2 turns to bring down** at 3 damage a turn. **Steals energy** — play cards out rather than holding a fat hand.

---

## A Conspiracy of Wisps  <sub>`wisp_pair`</sub>

> Two wisps. One shared opinion about your belongings.

**12 hp**  ·  **6 gleam**  ·  cycle of 3, repeating

Fought in: Witnesses (The Shambles, After Hours), Their Little Friends (Needle Lane, Night)

| Turn | Move | Target | Effect |
|---|---|---|---|
| 1 | **Covet** | `hand` | steals 1 energy from hand (bank if hand is empty) |
| 2 | **Flicker Bites** | `health` | 3 damage, blockable |
| 3 | **Gang Up** | `health` | 2 damage, blockable |

**Strategy:** Averages **1.7 damage a turn** over its cycle (biggest single hit 3). Takes roughly **4 turns to bring down** at 3 damage a turn. **Steals energy** — play cards out rather than holding a fat hand.

---

