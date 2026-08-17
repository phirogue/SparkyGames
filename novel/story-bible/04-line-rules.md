# Story bible 5: the line-level rules

The operational checklist. Apply to every sentence of every chapter.

---

## The one test

**Does this sentence tell me something true about the case, the world, or a
person?**

If it only makes the prose sound good, it goes — however good it sounds.

---

## The four defects, with the owner's own examples

### D1. The unearned aphorism

> "They gave her to the tide at the turn of the evening, because the tide is
> the only thing in Hollowmere that has never been bribed."

Shape of wisdom, no content. Nobody bribes tides. No corruption theme pays it
off. It stops a funeral to admire itself.

**Detection:** a "because" clause that does not explain; an "X is the only Y
that Z" construction; any sentence that would survive being moved to a
different chapter unchanged.

**Repair:** state the custom plainly and let the funeral be sad. *"They gave
her to the tide at the turn of the evening. That is the custom here."*

### D2. The joke that is not a joke

> "...has worked for fifteen years, which is longer than any dog on this street
> has lasted, and I have seen off three."

Not funny; makes Ash a boaster in his ninth sentence; contradicted by every
later page.

**Detection:** a punchline you would not say aloud to a friend; dryness
performed rather than earned; Ash scoring points.

**Repair:** cut, or replace with something the character would actually notice.
Fifteen years should now register as *age*, not as a scoreboard.

### D3. The gratuitous dark image

> "wound around wrists and doorposts and the necks of sleeping children"

The sentence needs "threads are on everything." It reaches for babies' throats
for a shiver.

**Detection:** the darkest element in an image doing work the mild elements
already did.

**Repair:** *"out of windows, along gutters, wound around wrists and doorposts
and gateposts."* Nothing is lost but the leer.

### D4. Stated game mechanics

Delete as systems, keep as sensation. See spine doc. Specifically:
- the four named strengths as a set — **gone**
- "a cat's natures are a purse" — **gone**
- "Ash: one. The weather: nothing." — **gone**
- nine shadow-pockets counted as nine slots — **gone** (the pockets stay, the
  arithmetic goes)
- "banked shine" defined as currency — **gone**
- the pale survives, but experientially: something of hers he carries, that he
  feels go, and that there is less of each time. Never a stat.
- the red feeling survives as instinct. Never one of four categories.

### D5. The exposition dump

> Fifteen. It means I am stiff in the mornings until the sun gets into me, it
> means I take the stairs and not the banister, and it means I retired some
> while ago without telling anybody.

Every claim in it is dramatised within two pages: the waiting on the roof, the
gap at Cooper's gone round, the sitting longer than the work deserved. The
summary is placed *in front of* its own evidence, so the scene has nothing left
to earn.

The book's version of this defect is almost always **redundancy, not
ignorance** — the scene that would replace the dump is usually already written,
a paragraph or two later. So the edit is nearly always a deletion.

Five shapes, all seen in the manuscript:

1. **Definition before experience.** "A gutter-wisp: a swallowed lantern of a
   thing" — creature glossed at length, then the fight waved off in a clause.
   Worst case: "It has the shape of a person who is not in it" followed by
   "Rag-wraiths: clothes whose owners are missing," which is the same sentence
   with the poetry removed.
2. **Tell, then show.** As above.
3. **The curriculum vitae.** A character introduced by résumé. Elspeth got six
   facts and a magic system before she had done one thing.
4. **The chapter that announces itself.** "A suspect enters the file in this
   chapter" — also a future-telling breach.
5. **The charter recital.** An institution's rules read out, when a member of
   it says the same thing better elsewhere (the Circuit's charter in ch8, when
   Cardew gives it in ch1 as "one rope between the nine of us").

**Detection:** `python tools/prose_telling.py` ranks candidates and flags frame
breaks. It is a heuristic, not a verdict.

**The one test:** *does a scene elsewhere already do this work?* If yes, the
summary goes. If no, it stays and earns its place. Summary is not the defect —
this is a noir, and Ash keeps a file. Reasoning, weighing and refusing to
decide all stay.

---

## Standing prohibitions

- **No future-telling.** "the whole last chapter of this book stands on it",
  "that should tell you most of what the later chapters will cost" — narration
  reports what happened, never what the book will do.
- **No motif twice.** A phrase is said once. If it must recur, it recurs as a
  plant and its payoff, and nothing in between.
- **No narratorial throat-clearing** beyond the handful already allowed
  book-wide: "I want that noted", "the file does not care", "I record the
  unfairness", "write that down and let it stand".
- **One figure per paragraph.** Delete the second and third; do not paraphrase
  them into something plainer.
- **No image plus gloss.** If an image lands, the clause explaining how to take
  it goes.
- **Em-dashes** at or under five per thousand words.
- **Supporting cast do not aphorise.** Merrow, Cardew and Tansy in particular.
  Epigram belongs to Ash, the Clerk, Brindle, the Gentleman and Bodkin.

---

## Ash's age — apply everywhere

Fifteen is old. From now on it shows:
- He is stiff in the cold and unhurried by preference.
- He weighs a jump he would once have taken.
- Physical work costs him and the cost persists into the next scene.
- He had privately retired before the murder. This case is the last thing he
  will do.
- Do **not** make him feeble or pitiable. Make him economical, and quietly
  aware he is not what he was.

---

## Dialogue test

If a line could move to another character's mouth without loss, it is wrong.
Check every line against the character sheet:

- **Bodkin** never lies, never elaborates, gives things once.
- **The Clerk** speaks to the paper, never to the person.
- **Cardew** leaves sentences unfinished.
- **Merrow** is procedural and least witty when strongest.
- **Tansy** is concrete and literal, never clever.
- **The Gentleman** reads like a document, never like a wit.

---

## What must never be touched

The kettle in all four beats and "It took three tries." The Clerk's dialogue.
The shroud-seam. Bodkin's name-giving and guest-right. "You fight like a
housecat. — I was one. — Were." The mirror-stitch kinship passage. "Spent is
spent" through the ninth stroke. Fenn's lamp and Merrow's bill. The epilogue
from "She always came to the window" to the end.
