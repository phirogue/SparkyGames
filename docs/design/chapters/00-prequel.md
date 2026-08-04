# Prologue — "Nine O'Clock Exactly"

The playable murder night. Doubles as the tutorial: every core mechanic is
taught *inside the story's worst evening*, so the tutorial is never skippable
filler — it's the reason you care. Total length ~12–15 minutes (three short
prowls + two scenes). Free, obviously; it's the hook.

Design intent: the player should finish the prologue knowing the whole game
loop (energy → skills → stealth → retreat → death → home) and *feeling* the
premise: the one person who was hers is gone, and the city did it.

> **AS SHIPPED — 2026-08-03 (owner: "the length of the prologue should be
> about the typical length of a mission").** The ~12–15 minute target above is
> superseded. A mission is 2–3 encounters and a handful of story cards, so the
> prologue is now **four fights** — vole, gutter-wisp, rag-wraith, the
> Unpicked — across ~14 story pages, which is one mission's shape.
>
> - **The chained dog lost its fight and kept its joke.** It is a line in the
>   Needle-Lane-Wrong beat now ("The dog at Number Twelve does not even bark.
>   We agree to disagree, and I go on."), not a fifth encounter. Guile and
>   Loaf are taught in that same beat alongside Moonlight and Purr, so the
>   wraith fight is the one where the full five-wide tray is on screen.
> - **One deck for the whole night.** The vole fight lays down all 21 cards,
>   ordered Ferocity→Shadow→Guile→Moonlight (decks draw from the back), and
>   nothing is ever added again. Each later fight names its `opening_cards`
>   so the beat that teaches a humour deals that humour. The spool therefore
>   only goes DOWN: 18 → 17 → 16 → 13 in a measured playthrough. Handing out
>   fresh energy per beat — plus a `refresh_spent` scene — used to make it
>   read 5 at the vole and 9 at the wisp, which taught the wrong lesson about
>   the one resource the run is built on.
> - **The wisp wants what a wisp would want.** It eats small lies and covets
>   bright things, so it is no longer "interested in the vole" — it comes for
>   the lie Ash told two scenes earlier about not chasing the silver thread.
> - **The Unpicked has no Slip Away button.** The encounter carries
>   `no_retreat`, so the room the story says he cannot leave is a room he
>   cannot leave.
> - **Rules are not narration.** Lines authored as `{text, rule: true}`
>   render in smallcaps accent instead of Ash's italic voice, so "New tonight:
>   SHADOW" reads as the game talking and not as another of his asides.
>
> **Second pass, 2026-08-04:**
>
> - **The wraith gets an entrance.** It used to appear in a coach bubble with
>   no story warning it was there at all. It now has its own page — the fog
>   that turns out to have sleeves, every cut thread on the street running
>   toward it — and the fight cannot kill (`hp_floor: 1`); past turn 4 the
>   game stops hinting and insists on the exit.
> - **The Unpicked ends on turn 6** (`doom_turn`), and its Slip Away button
>   stays and refuses: reaching for the door and finding the room has no
>   outside is the beat. Its first hint now teaches that Moonlight is wild.
> - **The Hollow Court is a scene, not a paragraph.** First death plays three
>   pages — the corridor before anyone speaks, the Clerk (with a line Ash
>   gets to choose), and a plain statement of what dying costs. Later deaths
>   keep the short form, because by then he does know the place.
> - **Ash wakes up on his own card** before he finds Elspeth. The death and
>   the discovery were sharing a page, which made the worst beat in the
>   prologue into a scene transition.
> - The "Nine Minus One" achievement no longer tells the player that everyone
>   dies here and that is rather the point.

---

## Prowl 1 — "The Long Way Home" *(teaches: turns, energy, skills, sunbeams)*

Dusk rooftops over Thimblefield. Ash is heading home carrying a gift for
Elspeth (a vole, thoughtfully dead). Everything is warm and ordinary — the
one stretch of the game where nothing is wrong yet.

- **Encounter 1:** a gutter-wisp wants the vole. Tutorial fight: draw energy
  cards, tap **Pounce** (Ferocity), tap **Swat** (free instinct). 2 turns.
- **Sunbeam beat:** a sunbeam tile on the next roof. Prompt: end turn in it.
  (+1 energy back — and Ash visibly enjoys it. Tone established: dignity,
  warmth, small pleasures.)
- **Encounter 2:** two wisps; teaches multi-enemy targeting and the intent
  telegraphs (one aims at Health, one at Hand — tooltip moment: "It wants
  what you're holding.").
- **Story beat (2 lines):** the ninth bell doesn't ring, because there isn't
  one. Ash notes the kettle will be on. *"She puts it on when the lamps go
  up. I am punctual. She is predictable. The arrangement works."*

## Prowl 2 — "The Wrong Quiet" *(teaches: stealth, alarm, Slip Away)*

Street level. Too quiet — no pigeons, and the lamps on Needle Lane are lit
*wrong* (Lamplighters never miss). First **stealth mission**: cross three
gardens without filling the Alarm meter. Shadow energy introduced.

- **Encounter (avoidable):** a dog on a chain. Fighting works; slipping past
  in shadow is cheaper. Either teaches the Alarm trade-off.
- **The lesson that matters:** the path home is blocked by a rag-wraith far
  above tutorial strength (visibly — its omen row is all paw-prints). The
  game offers **Slip Away** prominently. Taking it reroutes Ash over the
  fence, *loses nothing*, and the narrator approves: *"A cat does not lose
  fights. A cat declines them."* (Players who insist on fighting get flattened
  to 1 HP and rerouted anyway — same lesson, more bruises, no death yet.)
- **Story beat (1 line + art):** Elspeth's window is dark. The kettle-whistle
  is screaming somewhere inside. It does not stop.

## Prowl 3 — "The Parlor Window" *(teaches: death, the Toll — scripted)*

The front door is shut (a door has never once been an obstacle; it is,
however, always an insult). In through the loose pane in the workroom window.

Inside: threads everywhere are *cut* — the wards hang like torn hems (art
does the horror; zero text). In the parlor doorway stands the **Unpicked** —
a shape wearing the room's unravelled threads, still holding one silver
thread that leads to Elspeth's chair.

- **Scripted fight, unwinnable by design but generous:** the Unpicked's
  intents alternate Health/Skills/Hand so the player uses everything they've
  learned; it heals from its own unravelling. When Ash's HP reaches 0 —
  **the first life is spent.** No fail screen. The screen goes to thread-
  silver.
- Design guard: the fight must feel *mysterious*, not cheap — the Unpicked
  never big-hits; Ash is worn down while it finishes its work and leaves.

## Interlude — the Hollow Court *(teaches: what dying is)*

Intake desk, under the city. Queue of one. The **Clerk** looks up.

> CLERK: "Name?" — ASH: *(is a cat)* — CLERK: "...Vane's familiar. Nine
> allotted, one spent. First visit is complimentary. Do try to make the
> others interesting."

One form gets stamped (the stamp is a paw-print; the Clerk pretends not to
notice). Toll waived, mechanics tooltip: *next time it won't be.* Ash walks
back up the stairs into his own body. This 40-second scene carries the whole
death system: dying is bureaucracy, canon, and mildly embarrassing.

## Scene — "The Kettle"

The parlor, at last. The kettle screaming on the stove. Elspeth in her chair,
thread-silver light gone out of her hands. No wounds the day-side would ever
find. **No text at all for six seconds** — Ash crosses the room, headbutts
her still hand once. Nothing.

Then: the severed familiar-thread at Ash's chest isn't quite severed — one
strand, thin as spite, runs out under the window and away into the city.

Ash takes the kettle off the fire. (One paw. It takes three tries. Nobody
will ever know.) He takes his collar from her sewing table.

**Title card: THE NINE LIVES OF ASHCAT.**

Hub unlocks: the parlor is now home base — quest board (the Mantel), the
first case file opens: [Case File I — Wax & Wick](01-case-file-wax-and-wick.md).

---

## Mechanics taught, in order

turns/energy → skills & instinct → sunbeam recovery → intents (3 targets) →
stealth/Alarm → **Slip Away** (retreat is wisdom) → death & the Toll → hub.
Deliberately NOT taught yet (Chapter 1's job): shop/Gleam, favor-knots,
loadout editing, push-your-luck Press On, catnap/flashbacks.

## Asset needs (prequel manifest, ~16 images)

Rooftop dusk backdrop; Needle Lane night backdrop; parlor interior (warm
flashback variant + cold present variant); Hollow Court intake; Ash canonical
reference sheet; Elspeth (chair scene + one warm portrait for later reuse);
the Unpicked; gutter-wisp; rag-wraith; dog; the Clerk; 4 skill icons (Pounce,
Swat, Slink, Purr); collar close-up; kettle scene.
