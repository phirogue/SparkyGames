# Story Structure — the Case, the Guilds, the Three Chapters

Owner direction 2026-08-01. This is the layout of the whole game's story.
Scene scripts stay under the text laws (≤3 tap-lines per screen, 8–14
words a line); this doc is the map, not the prose.

## The four-card rule (owner 2026-08-18)

> "The game now has a bit too much text in the scenarios. Four text pieces
> max and then it should continue to the minigame. You can go more where
> absolutely necessary, but otherwise do a compression round."

**A player should tap through no more than four cards before the game gives
them something to do again.** Count what one playthrough actually sees between
two pieces of interaction — a fight, a minigame, a lesson, a notice, or a
choice, all of which reset the count. Branch variants (`when_flag`,
`when_outcome`, `when_attempt`, `when_minigame`) are mutually exclusive, so
only the branch that plays counts.

The 2026-08-18 compression round took the shipped content from 423 cards to
308, a 27% cut, and from 27 over-long runs to 18. What is left long is left
long on purpose, and the list is short: the prologue's death and its aftermath
(the kettle, the chair, the collar — the passage the whole game is built to
earn), Bodkin's introduction and his guest-right speech in `creditors`, and
Cardew at the wake. Anything else drifting over four is a bug.

**Compressing merges lines, which trades card count for card density — and
that is its own defect.** A single line that is too tall to fit the page
cannot be helped by `StoryScreen._retire_overflow()`, which always keeps one
line visible; it draws straight through the bottom of the page. A 258-character
card did exactly that and shipped, and was caught by reading a screenshot.
`tests/unit/test_story_cards_fit.gd` now measures every card and fails on any
that cannot fit alone.

## The spine: the game IS the case

The entire game is an investigation — Clue/Guess-Who by way of a cat.
Elspeth Vane was murdered; Ash builds the case. Clues are sprinkled
through every chapter, side quest, and guild story. Clues let the player
RULE OUT suspects and methods on a visible Case Board (a Casebook page):
suspect portraits with red thread, method cards, place cards.

**Clue categories** (each is something a cat plausibly notices):
- **Whereabouts** — who was where, when (the Lamplighters' cold kettle;
  the silent pigeons; a locked gate that shouldn't be).
- **Fabric** — threads, weaves, tears (a silver thread on a lamp-hook;
  a torn hem that matches a coat; the Unpicked's stolen stitching).
- **Scent** — what a nose knows (pipe smoke where no one smokes; pond
  water on a parlor rug; someone masked their smell — itself a clue).
- **Magic type** — every practitioner leans on a humour; residue tells
  (a ward burned out in Moonlight; claw-work done with Ferocity that no
  animal made; Guile-work that unpicked her defenses without force).

**Suspects:** at least THREE strong suspects stand until mid-Chapter 3.
Every chapter ends with the player able to eliminate at least one
suspect or method — and gain one. Red herrings must be fair: a clue that
misleads must read differently in hindsight, never lie outright.

**Endgame choice:** with the case built, the player chooses — present
the case to the authorities (the Hollow Court? the city? the guilds in
assembly), or take justice into his own paws. Both endings are earned by
HOW the case was built (which guilds trust Ash, which clues he holds).

## Chapters: 3 × ~10 core quests × ~10 minutes

Each core quest is a ~10-minute arc: brief, prowl (the 3–5 minute combat
run stays the atomic unit), resolution, clue. Chapters escalate one rule
at a time (escalation philosophy in core-gameplay.md).

- **Chapter 1 — Wax and Wick (free):** the Lamplighters' silence, the
  first suspects, learning the city. Ends: first suspect eliminated,
  first guild standing locked in.
- **Chapter 2 — The Quiet Roosts:** the pigeons' silence was bought; the
  guild cold war surfaces; the method narrows (fabric + magic clues).
- **Chapter 3 — The Ninth Bell:** the missing bell, the Hollow Court's
  interest, suspects fall to two, then one. Mid-Ch3: the third suspect
  breaks — played as a **Testimony** scene (minigames.md), not a cutscene.
  End: the case is presented — or settled. Ch3 is also where the nine-life
  ledger can genuinely reach nought: a cat who spends his ninth becomes a
  probationary **hearth-cat of the Court** and finishes the case from the
  night-side — an authored branch, not a fail state
  ([death-and-lives.md](death-and-lives.md)); day-side doors close,
  night-side doors open, and it feeds the nine-deaths ending.

**Story variety rule:** adjacent quests must differ in KIND, not just
place — a heist, then a diplomacy, then an escort, then a haunting.
Never two of the same shape in a row.

## The guilds

City factions with STANDING (hidden number, visible attitude), mutual
rivalries, and their own three-chapter stories. Ash's actions move
standing; guilds treat him accordingly (prices, doors, quest access,
clue access). Guild conflicts force choices — helping one closes another.

| Guild | Who | Wants | Feuds with |
|---|---|---|---|
| The Rats Under the Floor | rat syndicate | safe runs, grain law | Pigeon Post, cats generally |
| The Pigeon Post | messenger flock | the roosts safe again, gossip paid | Rats, Magpie Exchange |
| The Magpie Exchange | fence/merchants | shiny things, no questions | Pigeon Post (they talk) |
| The Lamplighters | human guild, half-vanished | their missing, the lamps lit | whoever silenced them |
| The Parlor Cats | territorial housecats | comfort, precedence, sunbeams | Ash (an independent) |
| The Hollow Court | death's clerks | paperwork in order | no one; everyone files eventually |

- Each guild carries one story ARC across all three chapters, and each
  arc holds at least one Case clue — you cannot finish the board without
  engaging some guilds (but never all; that's replay).
- Standing choices must be legible: the player should always know WHO
  they're pleasing and WHO they're crossing when they choose.

## Non-combat scenarios

Chases, diplomacy, hauntings, escorts reuse the SAME energy/skill engine
with scenario-specific action sets (owner rule): in a chase, Ferocity
buys bursts, Guile buys shortcuts, Shadow buys vanishing, Moonlight buys
nerve. The energy loadout you packed IS your personality in these scenes
— a Shadow-heavy cat talks (and runs) differently from a Ferocity-heavy
one, and some dialogue/route options gate on what you can pay.

## Where this lives in data

- Case board state: profile `flags` + a new `case` dict (suspects,
  eliminated, clues held) — schema when Ch1 implementation starts.
- Guild standing: profile `guilds: {id: standing}` with visible attitude
  tiers (wary / civil / warm / owed). Migration note: defaults merge.
- Quests: `quests.json` gains `guild`, `clue`, `kind` fields (validated).
