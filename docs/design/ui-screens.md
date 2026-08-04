# The other screens — Settings, the Mantel, the Exchange, the Loadout

*2026-08-04. The battle screen and the story page were built to the mockups;
the rest of the game was still default parchment buttons stacked in a
ScrollContainer. This doc is the design and the layout contract for the four
screens that carry everything between prowls.*

Direction is unchanged from [ui-style-guide.md](ui-style-guide.md): **the UI
is a storybook page, and information becomes objects.** Nothing here is a
widget if it can be a thing pinned to something.

## What already existed (reuse before generating — art library rule 1)

Every screen below is built from art that was already in the library. **No new
generation was needed.** The audit:

| Need | Asset used | Where it was |
|---|---|---|
| The hub as a *place* | `bg_mantel_scene` — bare mantel, empty hearth, two lit lamps | library, generated for exactly this and never wired |
| The shopkeeper | `npc_brindle_magpie` — Brindle on his hoard of buttons and keys | library, unwired |
| Settings row plate | `ui_settings_row` | library/ui, keyed, unwired |
| Toggle | `ui_toggle_on` / `ui_toggle_off` (felt pill + bone button) | library/ui, unwired |
| Settings icons | `ui_icon_sound`, `ui_icon_music`, `ui_icon_brightness`, `ui_icon_language` | library/ui, unwired |
| Gleam | `ui_button_pile` | already shipped |
| Deck | `ui_spool` | already shipped |
| Pinned quest notes | `ui_needle_pin` + `ui_seal_red/blue/gold` | already shipped |
| Skill cards | `ui_frame_skill` | already shipped |
| Humour glyphs | `energy_claw / eye / shade / moon` | already shipped |
| Achievements | `ui_medallions` | already shipped |

The mockups `mock_settings.png` and `mock_loadout.png` are the acceptance
tests for two of the four; the Mantel's is `reference/` mantel v2; the
Exchange had no mockup and is designed here from the same vocabulary.

## Settings — an overlay, not a screen

**It stays a `CanvasLayer` overlay** (owner rule: settings reachable from
*any* screen). Swapping the screen out mid-battle would destroy the combat
state, so the settings page is drawn full-page *on top* of whatever is
running, and closing it reveals the game exactly as it was.

Zone template (582x1104 content, 12px separation):

| Zone | Height | Contents |
|---|---|---|
| header | 96 | back arrow, "Settings" in display face |
| rows | 656 | 5 row plates (`ui_settings_row`), each icon + name + toggle |
| loudness | 126 | the master slider, drawn as a thread between two spools |
| footer | 190 | AI-transparency line, version, "Back to the night" |

The five rows, and what each one **actually does** — a settings toggle that
does nothing is a lie the player finds out about:

1. **Sound Effects** — mutes the `SFX` audio bus.
2. **Music** — mutes the `Music` audio bus.
3. **Lamps Low** — a dimming overlay on the top canvas layer, for reading in
   the dark (this is the honest version of a "brightness" control: an app
   cannot change the panel's backlight). It sits *above* the settings page so
   the effect is visible while the switch is being looked at.
4. **Ask to Spend** — a confirmation before any purchase at the Exchange. Off
   by default; on for anyone who has fat-fingered 30 gleam once.
5. **Language — English** — an inert *value* row, not a toggle: there is one
   language, and a fake language switch is worse than an honest dead end.

Buses `Music` and `SFX` are created at boot so the toggles are wired to the
real thing from the day audio ships, not retrofitted later.

Transparency line, per [ai-transparency.md](ai-transparency.md): the credits
are not shipped yet, and Settings is where a player looks. One plain line, no
apology, no boast.

## The Mantel — a place, not a menu

The hub was a scroll of eleven identical buttons. It becomes the room:
`bg_mantel_scene` behind the page, dimmed and warmed, with everything pinned
on top of it. **The shop and the loadout picker move out to their own
screens** — the Mantel's job is to be the two taps between a prowl and the
next prowl, not to hold every control in the game.

| Zone | Height | Contents |
|---|---|---|
| header | 96 | "The Mantel", gleam pile + count |
| board | 518 | "Pinned to the chimney breast" — three notes, seal-coded |
| doors | 268 | 2x2: the Case Board, the Magpie Exchange, On the Prowl, the Casebook |
| status | 86 | HP heart, deck spool, achievement medallions — each with its number |
| footer | 88 | the latest deed, and the replay-the-prologue thread |

Quest notes are `QuestNote`-style plates: parchment, a brass needle pin
through the top, a wax seal whose colour reads the quest's kind (red = the
case's own leads, blue = standing work, gold = a favour owed). Each note takes
±1.5° of rotation from a hash of its id, so the board looks pinned by a paw
and not by a layout engine — and so it looks the *same* every launch.

The board zone scrolls internally when there are more notes than fit. Zone
heights never move (law 12).

## The Magpie Exchange — the market

Brindle is a **character**, and the shop screen is a conversation with him,
not a table of SKUs. His portrait sits at the top with whatever he is saying
right now; the goods are four plates on the shelf below; a price is a wax seal
with a number on it. Buying opens the choice strip underneath (which humour,
which card to cut) instead of a new screen — the whole transaction stays on
one page.

| Zone | Height | Contents |
|---|---|---|
| header | 96 | back arrow, "The Magpie Exchange", gleam count |
| brindle | 300 | portrait + his current line (his voice reacts to what you can afford) |
| shelf | 480 | 2x2 goods: Add a card 12, The good shelf 30, Cut a card 15, Tonic 25 |
| detail | 192 | the chosen good's options, or his refusal |

Prices come from the same constants the hub used, unchanged — this is a
re-presentation of the existing economy, not a rebalance. Goods the player
cannot afford are visibly *out of reach* (faded plate, seal greyed) rather
than silently failing on tap, which is what the old four-button row did.

## The Loadout — "On the prowl"

Built to `mock_loadout.png`. Scratch is permanent and shown as such (a fixed
first slot with no swap), the other three slots are the picked skills, and the
bench below holds everything owned but not carried. Tapping a bench card puts
it in the first empty slot; tapping a slot returns it to the bench.

| Zone | Height | Contents |
|---|---|---|
| header | 96 | back arrow, "On the prowl" |
| slots | 460 | 2x2 framed skill cards — the four Ash actually carries |
| bench | 300 | owned-but-not-carried skills, as smaller cards |
| deck | 104 | deck size and the four humour glyphs with counts |
| confirm | 96 | "Confirm Loadout" (amber) |

The deck strip is read-only here — cards are bought and cut at the Exchange.
It is on this screen because "what am I taking" is one question, and the
answer is skills *and* deck.

## What the build turned up (kept, because it will happen again)

- **`game/assets/ui/ui_paw_full.png` was a ghost** — 0% of it was opaque above
  alpha 128. The hand keying pass that trimmed it had eaten the paw, and it
  had been drawn invisibly everywhere it was used since. The library master is
  a clean black paw print, so the fix was to wire it through
  `tools/wire_assets.py` (new `UI_KEYED` allowlist) instead of by hand. Law 3
  says read the geometry of generated art; the corollary is to read the
  *processed* file too, because the process is what broke it.
- **Nine-patch margins are measured, not guessed.** The row plate's ink dashes
  run 22px in from the top and 25 from the bottom, and its leaf sprigs own the
  outer 120px of each end. Margins of 96/40 cut through the sprigs, so the
  tiled middle showed a visible seam; 130/46 keeps each sprig whole inside a
  fixed corner. Text insets come off the same measurements — laid out to the
  plate's *rect*, the quest name crossed the dashes and the board card fell
  out of the bottom of the note.
- **A row's width budget has to be computed before it is written.** The first
  settings row came to exactly the available 502px, and the ON/OFF word was
  squeezed to one letter wide. There is now 20px of slack and a comment
  showing the arithmetic.
- **Zone templates are tested, not remembered** — `tests/unit/test_layout.gd`
  reads the `ZONE_*` constants off every screen script and fails if they and
  their separations do not come to `UITheme.CONTENT_HEIGHT`, and if
  `tests/calibrate.gd`'s zone maps disagree with the screens they describe.

## Rules this design is bound by

- Every zone template above is mirrored in `tests/calibrate.gd`'s `ZONE_MAPS`
  and asserted by the screen's `ZONE_*` constants summing to
  `UITheme.CONTENT_HEIGHT` (law 12).
- Every text box measures itself with `UITheme.measure_text` at the same wrap
  width the label uses (law 2).
- Textures are read for opaque geometry before they are drawn into a box —
  the settings icons are cropped through `UITheme.cropped_tex` (law 3).
- New profile keys (`settings.sfx`, `settings.music`, `settings.lamps_low`,
  `settings.big_text`) are added to `DEFAULT_PROFILE`; old saves merge against
  defaults and come up with sound on, lamps normal (law 7).
