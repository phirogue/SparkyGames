# Story Direction — DECIDED: *The Nine Lives of Ashcat*

Owner decision (2026-07-29): Pitch 2 from
[story-concepts.md](../brainstorm/story-concepts.md) is the game.
Working title: **The Nine Lives of Ashcat**.

## Premise

**Elspeth Vane** — witch, seamstress of wards, known to the city as *the
Needle of Hollowmere* — is dead. Murdered in her own parlor, between the
kettle boiling and the kettle screaming, which any professional will tell you
is no time at all.

**Ash** was her familiar. A familiar bound to a great witch inherits her
unfinished magic, paid out the only way cat-magic pays: in **lives**. Nine
lives, again and again, each one short. Ash intends to spend them finding out
who killed her — and why the city's shadows have started coming loose at the
seams ever since.

## Tone: wry, a little cute, completely sincere

The voice is a cat's voice: dry, self-satisfied, easily distracted, secretly
heartbroken. Rules of the voice:

1. **Ash is never the joke.** The world is ridiculous; Ash is dignified. Comedy
   comes from him narrating absurd things flatly ("The dog wished to discuss
   territory. I declined the meeting.") and from his priorities (mid-murder-
   investigation, a sunbeam is still a sunbeam).
2. **Cute on the surface, sharp underneath.** Purring heals, rugs get
   scratched, boxes must be sat in — and the grief is real. The cuteness makes
   the sad beats land harder, Ghibli-style.
3. **Cat puns live in flavor text and NPC dialogue, never in UI/rules text.**
   Budget: roughly one per scene; they should feel like the *world's* humor
   (shop names, book titles, gravestones: "PawnBroker — All Claws Final"), not
   the writer waving.
4. **Cat's-eye perspective throughout.** Humans are known by smell and
   function before names (the Fish-Giver, the Loud Widow, the Boy Who Blinks
   Correctly). Doors are a personal affront. Water is a conspiracy. Being
   *carried* is an indignity Ash tolerates from exactly one person, and she is
   dead — a running motif that pays off in a late flashback.
5. **Nobody explains the world in paragraphs.** Lore arrives in one-liners,
   shop signs, and what NPCs assume you already know.

## Structure: a murder investigation in case files

- **Chapters = case files.** Each chapter is one suspect/thread: a district,
  a cast, 6–10 quests (main leads + side quests), a chapter-boss confrontation
  and a revelation that reframes the case. Chapter 1 is the free chapter and
  a complete story ([monetization.md](monetization.md)).
- **One run = one lead.** Every prowl is framed as following a scent, a
  witness, a stolen ledger. Win or lose, the case moves (Hades cadence): the
  quest board updates, someone new leaves a note, a suspect gets nervous.
- **Retreat and death are canon.** Slipping away is a cat deciding the fight
  is beneath him. Dying spends a life — NPCs notice ("You smell of the Toll
  again"), some doors only open to a cat who has died the right way, and the
  Hollow Court's clerk greets Ash by name with increasing familiarity. The
  cost design lives in [core-gameplay.md](core-gameplay.md).
- **Endings.** The final chapter's accusation is the player's: evidence
  gathered across chapters unlocks endings (justice, vengeance, mercy, and
  one ending only reachable by a cat who has died all nine canonical deaths).
  Post-launch: new **case files** (episodic mysteries) continue the model —
  the murder resolves, the city never runs out of trouble.

### The mystery spine (proposal — spoilers)

Elspeth wasn't killed for what she had. She was killed for what she *held
together*. Her wards were one stitch in the **Hush** — the old binding that
keeps Hollowmere's night-side politely separate from its day-side. Someone is
**unpicking the city**, seam by seam, and her murder was merely the first
thread pulled. Chapter suspects (each guilty of *something*, only one of the
murder): the Chandlers' Guildmaster who bought her debts; the rival witch who
inherited her Circuit seat; the Quiet Gentleman, a fixer who brokers in
favors; and the thing under the mere that she was paid, long ago, to sew
shut. The true Unraveler should be someone the player has *helped* — chosen
late, after playtesting which ally players trust most.

## Flashbacks: the Remembered Days (owner request)

Catnaps in dangerous places yield **dream-fragments**; enough fragments stitch
a **Remembered Day** — a playable flashback run with **Elspeth alive**.

- Mechanically distinct: Elspeth fights beside you (her hexes as bonus
  skills, Moonlight-rich energy), the palette warms, and the narrator drops
  his guard.
- Each flashback answers one question about her past — how she bound the
  mere, why the Circuit feared her, where Ash actually came from (he was her
  ninth stray; the first eight went on to lives he pretends not to envy) —
  and quietly plants evidence for the present-day case.
- The last flashback is the morning of the murder, playable only near the
  end. It contains no combat. It should hurt.

## Allies (discovered, not assigned)

Allies are found through side quests and become town fixtures: vendors,
informants, co-conspirators, and PvP-era seconds. Core roster sketch:

| Ally | Who they are | What they offer |
|---|---|---|
| **Brindle** | Magpie fence who runs the Exchange; appraises everything by gleam, including feelings | Shop; appraisal of evidence; comic relief with a debt to Elspeth he never mentions |
| **The Understudy** | Theater ghost who can only quote lines from plays; surprisingly precise | Disguise/diplomacy training (Guile skills); Chapter 2 witness |
| **Sootbeard** | Gargoyle who has watched one street for 300 years and has *opinions* | Stakeout intel; a rooftop fast-travel network, carried in his fists (the indignity!) |
| **Mirri** | Ratcatcher's daughter who negotiates with rats instead of catching them; the rats respect the arrangement | Diplomacy quest-line; the rat-kingdom's spy network |
| **The Clerk of the Hollow Court** | Death's mid-level bureaucrat; finds Ash's repeat visits professionally irregular and personally delightful | Death-side lore; the "nine canonical deaths" ending thread |
| **Tansy** | A kitten who has decided she is Ash's apprentice. Ash has issued no such appointment | Grows across chapters; late-game playable? (post-launch class candidate) |

## What the story teaches the design (constraints)

- **Hard text budgets (phone-first, owner rule):** quest-board card ≤ 20
  words; mid-run interstitial ≤ 2 lines, 1 tap to skip; payoff scene ≤ 6
  short exchanges; card flavor ≤ 1 line. Nothing scrolls except the optional
  codex.
- **Show, don't write:** story lands through Midjourney scene art, character
  expressions, item icons, and *mechanics as narrative* (a jammed skill, a
  spilled satchel, a warm sunbeam say more than a paragraph). A player who
  skips every line must still be able to follow the case from images and the
  quest board.
- Story beats never repeat verbatim on retry (rotating alternate lines).
- Wins and losses both advance the case — but *differently*, so outcomes feel
  authored, not padded.
