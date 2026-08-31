# Saves, the shelf, and the cover — DECIDED (2026-08-30)

*Owner ask: "a new start screen where the player can choose to continue their
game, start a new game, see credits, or load a different prior game. Integrate
a save option in the game, but only to revert to latest position — the player
should not have an option to save and then try something and then load if it
didn't succeed."*

---

## The one rule everything else follows

**The player never chooses when the game is written.**

That single constraint is the design. It is what makes a night in the city a
night rather than an experiment, and it is what the owner ask is protecting:
save-scumming is not "a save button plus discipline", it is a save button. So
there isn't one, and there is not going to be one.

What the player gets instead is two doors, both on the settings page:

| The player asks | They get | What it cannot do |
|---|---|---|
| **Turn back the page** | the last checkpoint, restored | undo anything the game already wrote down |
| **Close the book** | back to the shelf, place kept | stamp a new save on the way out |

`Close the book` deliberately does **not** write. The last checkpoint *is* the
saved position; writing a fresh one on the way out would be a save button
wearing a coat.

### Why "turn back the page" is not save-scumming

Reverting can only ever throw away the *unfinished night*, because everything
with a consequence is committed at the moment it happens:

- a quest attempt is counted **at the door** (`_start_quest`), so a retried
  quest still plays its `when_attempt` beats and the people in it still
  remember — the world remembers retries (law 30)
- a spent life, the Toll, and the Court's filing fee are written **before**
  the desk scene plays (`_prowl_death`, `_prowl_refusal`)
- a purchase, a granted skill, a found piece of evidence: written on the spot
- the prologue writes its beat index on every page turn

So the honest description of the button, which is also what it says on the
page: *back to the Mantel as the book last left you; tonight's satchel and
tonight's ground are gone; what the city already wrote down stays written.*

Reverting is therefore roughly "slip away, forfeiting everything" — a move the
game already has a priced version of. It exists for the player who has made a
mess of a night, not for the player who wants to re-roll a fight.

### What revert does NOT restore

**Settings.** The lamps and the loudness are not progress, and a player who
turned the music off two minutes ago must not have it come back on because
they turned back a page. `SaveService.restore_checkpoint` owns that rule and
`tests/unit/test_shelf.gd` pins it.

---

## The shelf: three books

One file per book — `user://book_1.json`, `book_2`, `book_3` — each written
with the same versioned, temp-write-plus-rolling-backup mechanism the single
profile always used. A slot is only a naming convention for three paths.

- **`saved_at`** (v7) is stamped inside `save_slot`, not at the call sites: a
  checkpoint that forgot to record its hour would make the shelf lie about
  which book is the most recent, and `Continue` opens the most recent.
- **`prologue_index`** (v7) is the beat the book is open at. The prologue is
  the longest unskippable stretch in the game; coming back to the first card
  after quitting halfway is the game forgetting an hour of reading.
- **Erasing takes the backup too.** Leaving the `.bak` behind would let a
  later failed parse resurrect the erased game — handing the player a
  stranger's save at the worst possible moment.
- **The pre-shelf save is adopted**, once, into book 1 (`adopt_legacy_save`),
  stamped from the old file's modified time rather than "now". A player who
  updates into this build must not meet an empty shelf; that reads as the
  update having eaten their game. The old file is left where it is — an
  adoption that half-worked must not be the thing that loses a save.

`SaveService.shelf()` returns **facts** — counts, ids, an hour — never
sentences. The words are in `story/interface.json` (law 20), and
`shelf_screen.gd` owns the one answer to "where is this game up to" so the
cover and the shelf can never disagree about the same book.

### The throwaway shelf

Tour and component runs point `SaveService.shelf_prefix` at
`user://dev_book_` and never touch the real one. They open books, start books
and **erase** books; against the real prefix any one of those would delete
somebody's game. The tour additionally *wipes* its throwaway shelf at boot, so
its shots of a first launch are shots of a first launch and not of whatever a
`--scene shelf` run seeded earlier.

Conversely, `--scene shelf`, `--scene start` and `--scene settings` all **seed**
that shelf, because a dev launch arrives equipped (owner 2026-08-05) and a
page whose entire content is the saves on it proves nothing when empty.

---

## The cover — the start screen

Replaces the tap-anywhere title card. That card had exactly one route out of
it, which meant a returning player and a first-time player were sent down the
same corridor, and a second game could not be started at all.

| Zone | Height | Contents |
|---|---|---|
| title | 602 | the painted title poster |
| menu | 438 | 4 x 96 buttons, 18 separation |
| footer | 44 | what Continue would open, named |

- **Continue** opens the most recently written book. It is disabled, not
  hidden, on an empty shelf: greyed out it teaches a first-time player that
  the game keeps their place, hidden it makes the menu change shape between
  the first launch and the second.
- **A New Book / Another Book** both go to the shelf, which is one screen with
  a `mode` on it. Writing over an occupied book is the only destructive tap in
  the game and the only one that asks first.
- **The line under the menu** exists because "Continue" with nothing named
  after it is a button the player has to press to find out what it does.
- The cover uses `page_scaffold`'s `backdrop` option: the calibrated margins
  and the page guard, without the stitched parchment around the poster. The
  backdrop is **pure black**, sampled from the poster's own border — at
  `0d0b09` the poster rendered as a visibly lighter rectangle sitting *on* the
  cover instead of being it.

## Credits

The AI disclosure's proper home ([ai-transparency.md](ai-transparency.md):
"disclosed in the credits… a plain statement, not buried, not shouted").
Until this screen existed it lived in the settings footer at 22px, which is
where a player finds it only by accident. It stays there as one line and says
the whole of it here.

Every word — roles included — is `story/interface.json`'s `credits` block.
Crediting a collaborator is an edit to that file and to nothing else.

---

## Two layout defects this build paid for

Both were caught by reading the tour's shots (law 1), and both are the same
mistake in different costumes: **content placed into a box nobody measured
against the art already in it.**

1. **The settings row's right-hand word landed on the plate's corner sprig**
   and read as ink over leaves — the same defect the ON/OFF word was moved
   for, re-committed by the next person to add a row. The Book row is now
   built *from* `_value_row` rather than beside it, so the two right-hand
   words cannot drift apart again.
2. **A sentence in that slot wrapped out the bottom of a 101px plate** and
   across the Loudness heading. The row says one word; the explanation lives
   in the panel, which has room for it.

And one on the shelf: `ui_settings_row` is 9-patched with 130px fixed corners,
so on a 582-wide plate its leaf sprigs own the left and right 130px and run
most of the plate's height. A settings row fits because it puts an *icon*
there and one short name after it; four lines of a book's history do not. The
book plates are drawn parchment (law 22 — never trust generated textures'
geometry).
