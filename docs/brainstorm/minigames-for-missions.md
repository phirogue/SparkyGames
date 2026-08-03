# Minigames for missions — brainstorm (2026-08-03)

> **Decision record (2026-08-03, owner):** PROMOTED to
> `docs/design/minigames.md` (the committed spec — that doc governs):
> Patch the Ward, Testimony, Seam & Stitch (prototype-first), The
> Unpicking, and The Long Way Round (as "same deck, different actions").
> STILL PENDING owner thought: Pigeon Routes, Change-Ringing, Nine
> Pockets, and the Tier-3 flavor bites. The kill list below remains in
> force. This file stays as the record of the full field considered.

Candidate minigames for mission modules beyond combat. Constraints every
candidate must pass (from the laws + module cost model):

- **One thumb, portrait, 30–90 seconds.** Fits a 3–5 minute run as one
  beat, inside the storybook zone template.
- **Diegetic**: something a cat familiar could actually do. If the fantasy
  is "cat," the verb must be a cat verb (or a needlework verb Ash is
  learning). No abstract gem-boards floating over Hollowmere.
- **Failure is a story outcome, not a game-over** — same rule as combat's
  retreat (`when_outcome` variants required, law 6).
- **Reuses existing systems where possible** (energy cards, paws, Alarm,
  Casebook evidence) per missions-and-environments.md's "win-condition
  module + 1–3 special cards" cost model.
- **Deterministic under a seed** (tour/tests must drive it; law 13 escape
  paths apply).
- **Not clichéd on mobile.** The kill list at the bottom names what we
  will NOT build and why.

Scope tags: [S] ≤2 days, [M] ≈1 week, [L] multi-week system.

---

## Tier 1 — recommend building (Ch1–Ch2)

### 1. Patch the Ward — thread-patch quilting [M]
**Lineage:** Patchwork, Calico, The Isle of Cats (board games — the
latter two are literally cats-and-quilts; the mechanic is proven and
almost unknown on mobile).
**Play:** a torn ward is a grid with a ragged hole. Drag thread-patch
polyominoes into the gap. Each patch is paid in energy cards of its color
(the existing hand UI docks at the bottom, exactly like battle); Moonlight
patches fit any slot. You will not fill it perfectly — every leftover gap
carries a *lingering* effect into the next encounter (drafts: enemy +1
first hit; a snug patch: `warmed`).
**Where:** L3 re-warding the Lamplighters' hall; defensive prep before the
Wickhouse; repeatable "mending rounds" side missions (a wardkeeper economy
the city pays gleam for). Long-game: Ash's patches are *visibly clumsy*
early and neaten chapter by chapter — the player SEES Ash becoming the
Needle's heir.
**Why it's ours:** needlework is the magic system; the deck's colors
already exist; imperfect patching feeding combat modifiers links modules
instead of siloing them.

### 2. Testimony — press the witness [M]
**Lineage:** Ace Attorney (pressing), Case of the Golden Idol
(evidence-fits-claim deduction).
**Play:** a witness's statement appears as 2–4 stitched ribbon cards on
the page. Tap a ribbon to press it; or drag an evidence object from the
Casebook strip (Case Board data, already planned) onto the ribbon it
contradicts. Wrong presentations cost a whisker of standing, never a
game-over; the witness's patience is 3 paws.
**Where:** the diplomacy-lead replacement (Sway choice-scenes get teeth);
suspect eliminations (the mid-Ch3 "the third suspect breaks" beat NEEDS
this to be play, not cutscene); animal witnesses everywhere (Sootbeard's
blink, the pigeon ballot).
**Why it's ours:** it makes the Case Board a verb instead of a shelf —
the detective fantasy's missing piece. Cat twist: Ash cannot talk to
humans — human testimony is only reachable by pressing *animal* witnesses
about humans, which is why a cat detective sees what the Watch cannot.

### 3. The Appraisal — spot the forgery [S/M]
**Lineage:** Papers, Please (document inspection), pawnbroker sims;
subverts the dead "hidden object" genre by hiding ONE tell in ONE object.
**Play:** an evidence object fills the portrait zone (the art exists —
evidence objects are already commissioned per lead). Pinch/drag a
magnifying paw; find the one tell (a re-struck hallmark, a mirror-slanted
stitch, a seal pressed twice). Declare: true or forged. Brindle reacts;
being wrong is canon ("you vouched for it") and prices your gleam down.
**Where:** Magpie Exchange side missions; authenticating Case Board
evidence (a forged docket is ITSELF the clue — the seal-forgery thread
runs straight at the endgame per the-unraveler.md). One art asset per
puzzle, no new engine surface beyond a zoomable TextureRect.
**Why it's ours:** the mystery is literally about perfect forgery
(mirror-handed technique); teaching the player to *look closely at
stitching* is training them to solve the case.

### 4. Seam & Stitch — the ritual loop (upgrade of the planned module) [M]
**Lineage:** Slitherlink (draw one closed loop satisfying edge clues) —
deep, elegant, and virtually absent from mainstream mobile.
**Play:** a stitch chart on the page: dots, some numbered by how many of
their edges the seam must use. Drag to sew ONE closed thread that
satisfies the numbers. Small grids (4x4–6x6), calm, no timer; the thread
renders as actual stitching, pulled taut on completion with a satisfying
cinch.
**Where:** this IS the ritual module the Ch1 plan already commits to
(Wickhouse re-warding cover). The Ch3 payoff is built in: the final
lesson asks for the same chart *mirrored* — and the player's hand
discovers what mirror-stitching means before the story says it.
**Why it's ours:** a closed seam is the game's central image; Slitherlink's
one-loop rule maps to "a ward must close or it is nothing."

## Tier 2 — strong, hold for the chapter that needs them

### 5. Pigeon Routes — restring the gossip network [M]
**Lineage:** Mini Metro (minimal route-drawing), Hashi.
**Play:** a parchment map of roosts; drag thread routes between them with
a limited spool, around hawk skies and fog banks; every roost must join
one network. Completing it animates the pigeons returning street by street.
**Where:** Ch2 "The Quiet Roosts" spine — the pigeons' silence was bought,
and re-drawing the network IS drawing the money trail: the roost that
re-connects last is the one that was paid to go quiet. Puzzle solution =
plot revelation, no exposition needed.

### 6. The Unpicking — pull threads in safe order [M]
**Lineage:** pick-up-sticks/Mikado crossed with knot topology (Planarity).
**Play:** a lattice of crossing threads; only a thread with nothing
crossing OVER it may be pulled. Tap threads in a safe order to dismantle
the working; a wrong pull twangs the lattice and raises Alarm (existing
system). Later variants add threads that re-cross when others move.
**Where:** disarming hostile wards in heists; opening the Gentleman's
knot-contracts (Ch2); and the cold late-game beat where Ash must do to a
seam exactly what the Unraveler does — same minigame, new meaning. Doing
the killer's verb with your own paw is the kind of dread no cutscene buys.

### 7. Change-Ringing — the Ninth Bell [S/M]
**Lineage:** real campanology ("change ringing" — bell permutation
patterns), not Simon. Bells ring in rows; each row is a fixed permutation
of the last. Shown as a woven braid diagram (bell paths literally weave —
campanology diagrams already look like our thread art).
**Play:** watch two rows, then place the missing bell's position in the
next rows by tapping its slot in the braid. Reconstructing the pattern
reveals where the ninth bell SHOULD have rung from.
**Where:** Ch3 "The Ninth Bell" Horologists/Hollow Court lead — finding
the missing bell by the hole its absence leaves in the pattern is the
chapter's thesis in miniature (the whole mystery is a missing-thread
shape). One-chapter special; keep it small.

### 8. The Long Way Round — push-your-luck traversal [S]
**Lineage:** Can't Stop, The Quacks of Quedlinburg (push-your-luck), done
entirely with the EXISTING card system — no new board.
**Play:** a storm crossing dealt as footing draws from your energy deck:
each draw advances; drawing a color matching the posted "gust" slips you
(lose progress, take 1). Bank progress and rest (spend a paw) or push.
Spent cards stay spent into the next fight — the deck-as-stamina clock
made visceral.
**Where:** the survival/escort leads deferred from Ch1 — this makes them
shippable cheaply in Ch2 (garden storm crossing, rooftop chase). Because
it reuses cards/paws/spent, it is nearly free and teaches deck-thinning
strategy sideways.

### 9. Nine Pockets — moon-phased packing [M, needs equipment system]
**Lineage:** Patchwork-style packing meets Resident Evil attaché;
world-bible canon (nine shadow-pockets, moon-phased capacity).
**Play:** before a big mission, fit charm/tool polyominoes into the
pockets stitched in Ash's shadow — and the moon phase resizes tonight's
pockets. What you pack is what mission actions you can take.
**Where:** Ch2+, arrives WITH the equipment system (Last Parcel
groundwork). This is the equipment UI, not an extra — build once, it is
both inventory and minigame.

## Tier 3 — flavor-sized, opportunistic [all S]

- **Shelf Justice** (Untitled Goose Game energy): pick which ONE object
  to knock off a shelf for a distraction — weight/bounce preview, wrong
  object = Alarm. A heist special action, not a standalone mode.
- **The Overheard**: ear-to-the-wall eavesdropping; a conversation
  arrives as torn ribbon fragments and the player orders them; failure =
  incomplete (never false — fair-play rule). Guild-hall recon.
- **Paw Prints** (Court forms): the Hollow Court requires forms; a cat
  cannot write. Choose which clauses get the inked paw-stamp; the Clerk's
  reactions carry the comedy. A choice-scene garnish for Court visits.
- **Kneading/Purr cadence**: a generous, drifting tap-with-the-purr
  rhythm to calm a witness (Tansy). Rhythm Heaven-lite; keep optional and
  forgiving — this is a warmth beat, not a skill check.

## Kill list — rejected as clichéd or off-theme (keep for the record)

- **Match-3 / merge boards** — the definition of overdone; nothing about
  a cat or a seam matches three.
- **Hidden-object scenes** — gaslamp mobile's tiredest genre. The
  Appraisal (#3) deliberately inverts it: one object, one tell.
- **Pipe/wire connect for wards** — "connect the flow" is the stock
  puzzle for every magic-repair in mobile; Patch (#1) and Seam (#4) own
  that fantasy with better-fitting mechanics.
- **Sliding tiles / 15-puzzle / 2048 / bubble shooter / endless runner** —
  no diegetic reading, saturated.
- **Spot-the-difference** — absorbed into the Appraisal as a single-tell
  hunt; as a standalone genre it is worn out.
- **Timing/twitch QTEs for stealth** — the game is calm and tactical;
  twitch input punishes the commute player and breaks one-thumb comfort.
- **Wordle-likes / trivia** — Ash cannot read human words (a canon rule
  we should not break for a puzzle).

## If only three get built

1. **Testimony** (#2) — turns the Case Board into gameplay; the mystery
   needs it structurally by mid-Ch3.
2. **Patch the Ward** (#1) — the needlework fantasy as a system, feeding
   combat via lingering effects; quilting-with-cats has proven board-game
   charm and no mobile incumbent.
3. **Seam & Stitch** (#4) — already committed as the ritual module; the
   Slitherlink identity gives it depth and sets up the mirror reveal.

Everything here obeys the standing rule: modules ship with scenario specs
(`--scene scenario:...`), seeds, tour stops, and `when_outcome` prose for
success, partial, and walk-away.
