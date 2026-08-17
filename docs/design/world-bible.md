# World Bible — Hollowmere

Consistency reference. Most of this is **never stated in-game** (phone-first,
low-text); it exists so every shop sign, card, and one-liner agrees with every
other. Scope: launch content draws on ~20% of this; the rest is backdrop.

> **Upstream source, since 2026-08-16.** `novel/story-bible/` is authoritative
> for story, character, motive and timeline; this file is the game's working
> reference and defers to it. The novel's sixth edition closed three holes and
> hardened several facts this doc had left soft — they are gathered under
> [What the novel settled](#what-the-novel-settled-2026-08-16) below, and the
> machine-readable copy the game reads at runtime is in
> `game/story/world/index.json` under `canon_anchors`.

## The city

**Hollowmere**: a fog-buttoned city wrapped around a black lake (the Mere),
gaslamp-era comforts, chimney forests, canals, too many stairs, exactly the
right number of rooftops. Built on seven older cities the way a cat sits on
yesterday's newspaper — deliberately and without apology.

**The Hush**: the old binding that keeps Hollowmere's two sides separate —
the **day-side** (merchants, laundry, taxes) and the **night-side** (ghosts,
guilds of the impossible, the polite bureaucracy of death). The Hush is not a
wall; it is a *seam*, sewn by generations of witches. Day-siders don't see the
night-side because they've stopped noticing, the way adults stop noticing
ceilings. **Cats, children, drunks, and the recently bereaved** see both
sides. Cats are, by ancient arrangement, the seam's unpaid inspectors — which
every cat considers exactly the right amount of pay for exactly the right
amount of work.

Since Elspeth's murder, the seam is loosening: shadows arrive before their
owners, dreams leak into laundry, and the Mere has begun to *hope*.

## The magic system: the Weft

The world has an underlay — the **Weft** — threads of intention running
through everything, visible to almost no one. Magic is **needlework**:

- **Witches stitch.** A ward is a hem. A curse is a knot tied in someone
  else's thread. A binding is a seam. Great workings take years and are
  maintained, not cast — magic here is *labor*, which is why witches are paid
  like plumbers and respected like surgeons.
- **Cats see the threads.** You've watched a cat stare at an empty corner:
  it's reading the stitching. Ash's skills are a cat's four natures (Ferocity,
  Guile, Shadow) plus **Moonlight** — Elspeth's unfinished magic, which he
  spends but cannot yet make. Moonlight is literal: the moon is the world's
  needle's-eye, and moonlight is thread that hasn't been used yet. Thread
  that hasn't been used can still become any stitch — which is why Moonlight
  can be spent in place of any other humour.
- **Costs are real.** Thread pulled must come from somewhere: memory, warmth,
  years, luck. Every named working states its price. (Design rule: any magic
  shown in-game must have a visible cost — it keeps writing honest and makes
  mechanics-as-narrative easy.)
- **The dead are loose threads**; ghosts are stitches that haven't been tied
  off. The Hollow Court exists to do the tying.

## How a cat carries and pays (owner request)

**Carrying — the Shadow-Stitched Pockets.** Elspeth's last finished working:
she sewed **nine pockets into Ash's shadow**, one for each life. Anything Ash
can pick up in his mouth (or knock into his shadow off a table — see
mechanics) slides into a pocket, carried weightless wherever his shadow goes.

- Nine pockets = **equipment/inventory slots**. The UI *is* the fiction: the
  inventory screen is Ash's shadow on a moonlit wall, items glinting inside.
- Pockets are **moon-phased**: one or two are always "in shadow" and
  unreachable that run — rotating scarcity keeps loadouts a decision.
- Losing a life tears a pocket (the Toll's fee has a *place* it comes from).
  End-game thread: what happens when all nine pockets have been torn and
  re-sewn — whose stitching repairs them, if the Needle is dead?
- A cat can't dress himself and would not choose to. All "equipment" is
  pocket-carried charms, tokens, and relics — except **collar charms**
  (2 slots): Elspeth's collar is the one thing Ash wears, and he permits
  precisely two charms on it. Sentiment, not fashion.

**Paying — Gleam and Favors.** Hollowmere's night-side runs a two-tier
economy that happens to be perfectly cat-shaped:

- **Gleam** (run currency): shine is value. Buttons, ring-pulls, lost
  earrings, a well-kept fishbone — appraised by the **Magpie Exchange**,
  whose vaults are nests and whose exchange rate is mood-based but
  scrupulously fair. Cats are naturally rich: the city is *covered* in
  unattended shiny things, if you're small, patient, and morally flexible.
- **Favors** (meta currency): the night-side's real money. A favor owed is a
  **knot tied in your thread** — visible to anyone who can see the Weft, so
  nobody welches. Ash *earns* favor-knots by solving people's problems
  (quests) and spends them where money means nothing: guild doors, Court
  paperwork, a gargoyle's attention. The Quiet Gentleman got rich collecting
  these; Ash collecting them makes him, structurally, a rival. He is aware.
  He finds it fitting.
- **Cat-society trade** (flavor, quest items): secrets seen through windows,
  first-sit rights on warm chairs, gifts (dead, thoughtful). The **Court of
  Whiskers** settles disputes in these denominations.

## The major powers (needs & wants)

| Power | What they are | Want | Need (true, often unstated) |
|---|---|---|---|
| **The Witches' Circuit** | Nine seats of working witches who maintain the Hush; one seat now empty | Elspeth's estate settled quietly, her wards inherited | A new Needle before the seam fails — and none of them can sew like she could |
| **The Chandlers' Guild** | Monopoly on light: candles that hold memories, lanterns that keep promises | To sell "bottled day" to a frightened city | The dark to stay frightening; their fortune depends on the Hush *weakening but never breaking* |
| **The Hollow Court** | Death's civil service, under the city; clerks, dockets, the Toll | Balanced ledgers; every loose thread tied off on schedule | Elspeth's death recorded *correctly* — and her file is wrong, which terrifies them |
| **The Quiet Gentleman** | A fixer who owns favors the way banks own houses; no one remembers meeting him first | Every debt in Hollowmere to route through him | No debt to ever be *settled* — settlement is the one thing that starves him |
| **The Court of Whiskers** | Cat parliament; convenes on rooftops at the wrong hour on purpose | Feline neutrality in all mortal matters | The Hush intact — cats made the old arrangement, and its terms name them |
| **The Mere** | Not a drowned *thing* — the city's oldest **creditor**, sewn shut by Elspeth's greatest seam | The tithe it is owed, and the account reopened | Someone on the surface to keep pulling threads. It has found someone |

Minor guilds (texture, quest hooks): the **Ratcatchers' Union** (officially
pest control; actually diplomats), the **Locksmiths' Fellowship** (keep
secrets *in escrow*), the **Lamplighters** (Chandlers' street-level rivals,
know every alley), the **Horological Society** (clockmakers who owe the Court
time, literally), the **Undertakers' Circle** (day-side face of the Hollow
Court, mostly unaware of it).

## Creatures of the night-side (launch bestiary directions)

- **Gutter-wisps** — bottle-sized lights that eat small lies; swarm foes.
- **Memory-moths** — drawn to grief; each carries one stolen memory on its
  wings. Killing one destroys the memory; catching one returns it.
- **Rag-wraiths** — clothes whose owners are missing (not dead — *missing*);
  they attack the well-dressed. The seam-loosening is making more.
- **The rat-kingdoms** — organized, literate, unionized. Not monsters:
  a faction. Fighting rats is a diplomatic incident; Mirri disapproves.
- **Chimney gargoyles** — territorial civic monuments. Hire on as escorts if
  properly flattered (they are *enormously* susceptible to flattery).
- **The Drowned** — the Mere's patient people, dry-footed on wet streets.
  Never fast. Always arriving.
- **Hearth-cats of the Court** — spectral cats in the Hollow Court's employ.
  Professional courtesy applies to Ash. Mostly.
- **Dust-bunnies** — literal. Under beds. Militant.

## Society & daily texture

Day-side Hollowmere worries about fish prices, the fog schedule, and the
Lamplighter strike. Night-side Hollowmere worries about the seam. The genius
of the setting for a low-text phone game: **both sides share the same
streets**, so every environment is two backdrops (day/night variants) and
every district rule reads instantly (fog = Shadow cheaper; Chandlers' ward =
Moonlight dearer).

Districts (launch: first two; the rest post-launch): **Wickrow** (Chandlers'
district, Chapter 1), **the Shambles** (market maze, Magpie Exchange),
**Gravamen** (Court-adjacent, undertakers), **the Mereside** (drowned
terraces), **Thimblefield** (witches' row, Elspeth's parlor — hub/home).

## What the novel settled (2026-08-16)

Six facts that content written before this date got wrong, or left open and
then contradicted. All are now enforced in `game/story/world/index.json`.

**1. Ash is fifteen, and fifteen is old.** Before the murder he had privately
retired: stiff on cold mornings, thinking before he jumps where he used to
simply jump, employed to be somewhere warm at the correct time. The case is
the last thing he will ever do. Write him **economical**, not feeble — he
takes the long way and calls it professionalism, he goes round by the wall at
gaps he used to clear, and a shoulder he tears does not come back. His nine
lives stop being a videogame allowance and become **a retirement he is
spending**, which is also why Bodkin, older still and down to one, reads as
Ash's near future rather than as a monster.

**2. The Circuit is nine seats holding one rope.** When a seat goes out, the
load comes onto the other eight and they feel it in their wrists. Cardew felt
Elspeth go at dusk, in her own kitchen, with a pan in her hand — that is how
the witches knew to come, and they came at **first light** rather than at once
because you do not walk Needle Lane in the dark while something is still
unpicking it. Eight seats now, seven of them working themselves hollow
holding what one woman held. **Cardew is small, grey and folded**, like
something kept a long time in a drawer; her knees cost her when she kneels and
she pays without comment. She does not make maxims — she stops.

**3. The shutters.** Elspeth never closed her shutters in fifteen years. On
the last evening she closed them, set out a beeswax candle she had kept forty
years unburned, and put the kettle on **for two**. This is why an hour of
candlelight on an inhabited lane went unseen. Ash reads the closed shutters in
Ch1 as the intruder shutting the lane out, is pleased with the deduction, and
is wrong. Everything about that hour re-reads once you know she was expecting
someone she did not want seen.

**4. The tithe and the ninth bell.** The city was built on the Mere because
the Mere was the wealth, and it paid the water a tithe: the first of
everything. Nine bells; the ninth rung slow the morning after the water had
collected, one stroke for each thing taken. About a hundred years ago, in a
plague season, the city pawned the ninth bell to the Hollow Court as
collateral and never redeemed it. The docket is still open. Since that night
the city's nights run one hour short, nobody in Hollowmere has dreamed a dream
to the end, and nobody finds it strange.

**5. Nobody investigates, and that absence is the story.** The day-side sees
an old woman dead in a chair behind a door locked from the inside with nothing
taken, and writes *heart, most like, at her age*. The night-side has no
constabulary: the Circuit mends, the Court of Whiskers serves papers, the
Hollow Court files the dead and says so, the Magpie sells what it knows to
whoever is buying. **None of them owns a killing.** Never write an institution
stepping in — the missing court is the same absence that produced the murder.

**6. The pale does not refill.** The Moonlight in Ash is hers, put into him out
of her own evenings. What a cat has of his own comes back with meat and sleep;
that does not. He feels it go when he spends it and there is less every time.
Narration describes it as a cold weight under the ribs going out of him —
never as a resource he is managing. (The card economy is the game's business;
the prose keeps out of it.)

### The voice, while we are here

Ash is **an old cat writing a report about the worst year of his life**. He is
precise because precision is the only dignity available to him. He is funny
only when accuracy happens to be funny, and **he never reaches**. Three named
failure modes, all of which shipped at least once and have now been cut:

- **The unearned aphorism** — a *because* clause that does not explain the
  clause before it ("the tide is the only thing that has never been bribed").
- **The joke that is not a joke** — a line whose only job is to sound dry, and
  which characterises Ash as somebody the rest of the story does not bear out
  ("Ash: one. The weather: nothing.").
- **The gratuitous dark image** — reaching past the mild elements of a picture
  for a shiver the sentence did not need.

When he is moved he gets **shorter**, not more ornate. "It took three tries.
Nobody will ever know."

### Show it; do not also explain it (novel 7th edition, 2026-08-16)

The owner's next note on the novel — *"a tendency of telling things, rather
than showing them, a lot of exposition dumps"* — applies to the game's prose
word for word, and the game had the same habit for the same reason. The
diagnosis is not "too much summary" in the abstract. It is **redundancy**: the
scene that would replace the dump is usually already on the page a beat later,
and the summary in front of it spends the surprise before the scene can earn
it. The edit is nearly always a deletion, not a rewrite.

The test: **does a scene elsewhere already do this work?** If yes, the summary
goes. If no, it stays and earns its place. Five shapes to hunt:

- **The definition before the experience.** A thing named and glossed before
  the reader has met it, and then the meeting summarised. Detection: a colon
  introducing an apposition; "they have a name"; anything that would sit
  comfortably in a glossary. Let the thing act first.
- **Tell, then show the same thing.** A paragraph of assertions followed by
  the scene that proves them. Look at the paragraph immediately *before* any
  good concrete beat — the dump is usually sitting right on top of it.
- **The curriculum vitae.** A character introduced by résumé instead of
  behaviour. Name, and one action; the rest waits for a scene that needs it.
- **The scene that announces itself.** Telling the player what a beat is about
  to accomplish. Also a future-telling breach.
- **The gloss on a landed image.** One figure, then a clause explaining how to
  take it.

Applied to the game 2026-08-16: the prologue's "Fifteen. It means…" paragraph
(the vole hunt, the gap at Cooper's and the sitting-afterward already
dramatise all three claims), the Weft systematics (now personal — *she
stitches with it; I have only ever been able to look*), the gutter-wisp
glossary, the night-side institutional roster in `the_carrying` (Cardew says
it at the wake, at cost), and the tide-rite explained in `the_wake` before the
rite then happens in full.

**What this does NOT touch.** Ash is a detective keeping a file, and summary
is his voice, not a defect in it: him weighing, judging or refusing to decide;
case-status reasoning where the reasoning *is* the action; the Clerk. And it
does not touch the game's own teaching surfaces — notice cards, coach steps,
`rule: true` cards and `lessons.json` exist precisely so that the rules get
stated somewhere that is not the narration. A rule in a lesson is in its right
home; the same rule in a story line is a dump.

`python tools/prose_telling.py` ranks the novel's paragraphs for a human to
judge. It is a heuristic, not a verdict.

## Consistency rules for all content

1. Magic is sewing; costs are visible; nothing is "just magical."
2. Cats are never comic relief *to the world* — the world takes cats
   seriously; only the player sees the joke.
3. The Hush frays gradually across chapters: background art and district
   rules should measurably worsen (more wisps, earlier fog, bolder Drowned).
4. Every power wants something from Ash *because he's a cat* (seam
   inspector, nine-lived, sees the Weft) — never despite it.
5. Nothing in the world is named "dark," "shadow," or "blood" + noun. We are
   better than that.
6. No mechanics exposition in narrative voice, and no future-telling. The
   narration reports what happened; notice cards and coach lines carry the
   rules. A sentence that names a stat is a sentence in the wrong file.
