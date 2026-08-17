# SFX Shortlist

The sound-effect counterpart to [`music-prompts.md`](music-prompts.md). That
doc covers the score; this one covers the one-shots.

**No source library is in this repo.** They live outside the repo and outside
OneDrive, so they neither bloat git nor sync to the cloud.

The pipeline for a sound, mirroring how art moves through the project:

```
~\assets\<library>\      the three source libraries, outside the repo entirely
        ↓                tools/stage_sfx.py — curate, rename, convert
assets/incoming/sfx/     candidates awaiting audition  [gitignored]
        ↓                the owner listens and deletes
assets/library/sfx/      accepted — the sounds the game uses  [tracked]
        ↓                tools/wire_sfx.py — loudness pass, import
game/assets/sfx/         wired into the game  [tracked]
```

287 candidates are sitting at the `incoming` step now; see
`assets/incoming/sfx/MANIFEST.md` for the per-file reference table.

| Library | Where | Size | Licence | Fetch with |
|---|---|---|---|---|
| Kenney (5 packs) | `~\assets\kenney-audio\` | 420 files, 8.8 MB | **CC0** — public domain | `python tools/fetch_kenney.py` |
| Sonniss #GameAudioGDC 2026 (31 libraries) | `~\assets\sonniss-gdc2026\` | 89 files, 850 MB | royalty-free, no attribution | `python tools/fetch_sonniss.py` |
| Freesound (22 queries) | `~\assets\freesound\` | 148 files, 14.7 MB | **CC0 only**, per-file verified | `python tools/fetch_freesound.py` |

Together: commercial use, no attribution, nothing to track through to the store
listing. We credit Kenney and Sonniss in the about screen anyway, because it
costs nothing and it is true.

**Formats differ and it matters.** Kenney ships Ogg Vorbis at game-ready
lengths — no transcode. Sonniss ships 96 kHz (music boxes: 192 kHz) 24-bit WAV
masters: 850 MB holds only 23 minutes of audio, and every file needs
downsampling to 48 kHz and trimming before it goes near a phone.

> ### ⚠ Sonniss forbids AI training — read this before using `--ref` on anything
>
> The bundled EULA (`License - GDC Game Audio.pdf`, p. 3) prohibits using these
> sounds "for the purpose of developing, training, or enhancing artificial
> intelligence technologies", including "technologies capable of generating
> sound effects… in a similar style or genre".
>
> Shipping them in the game is fine — that is exactly what the licence grants.
> **Feeding one to an audio model is not.** The art pipeline's habit is to
> generate FROM a reference (`tools/genart.py --ref`); the audio equivalent —
> handing a Sonniss WAV to ElevenLabs audio-to-audio or Stable Audio — would
> breach this. Generate audio from text prompts only, or from our own
> recordings. Kenney CC0 and Freesound CC0 carry no such restriction.

---

## What I could and could not check

I measured every file: duration, peak dBFS, mean dBFS (ffprobe + `volumedetect`).
Those numbers are real and appear in the tables below.

**I have not heard any of these files.** The picks below come from filenames,
the measurements, and Kenney's naming conventions — not from listening. Law 1
says see it before you say it's done; the audio equivalent has not happened
yet. **Every row marked `[ear]` needs an audition before it is wired.** The
tightest audition loop is to wire the whole shortlist behind a dev-menu
soundboard and play through it once.

---

## The frame: this game is a book

The strongest thing in these packs for *Ash* specifically is that
`kenney_rpg-audio` contains real book foley — and the entire UI is a book with
dashed stitching down the page. Page turns are not a metaphor here; they are
the interaction.

| Event | File(s) | sec | Why |
|---|---|---|---|
| Advance a story beat | `rpg-audio/bookFlip1.ogg`, `bookFlip2`, `bookFlip3` | 0.23–0.77 | Three variants — law 15. Cycle, never repeat consecutively. |
| Open the book (title → game, journal open) | `rpg-audio/bookOpen.ogg` | 0.15 | Quietest file in the pack (mean −33.6 dB); may need a lift. `[ear]` |
| Close the book (quit to title, journal close) | `rpg-audio/bookClose.ogg` | 0.23 | |
| Journal page scroll | `interface/scroll_001…005.ogg` | 1.00 | All exactly 1.0s — likely a continuous scroll loop, not a one-shot. Verify. `[ear]` |
| Choice committed | `interface/confirmation_001.ogg` | 0.29 | |

---

## Core UI — every screen

| Event | File(s) | sec | Note |
|---|---|---|---|
| Button tap | `ui-audio/click1…click5.ogg` | 0.03–0.09 | Five variants. Shortest set in the whole library; correct for a tap. |
| Focus / highlight moves | `ui-audio/rollover1…rollover6.ogg` | 0.06–0.23 | Six variants, quiet (mean −21.8 dB). |
| Settings toggle | `interface/toggle_001…004.ogg` | 0.07–0.14 | Pairs with the existing `ui_icon_sound` / `ui_icon_music` toggles. |
| Back | `interface/back_001…004.ogg` | 0.06–0.09 | |
| Modal opens | `interface/maximize_003.ogg` | 0.19–0.53 | Nine to choose from. `[ear]` |
| Modal closes | `interface/minimize_003.ogg` | 0.19–0.53 | Pick the index that matches the maximize you chose. `[ear]` |
| **Rejected command** | `interface/error_003.ogg` | 0.10–0.53 | Law 19's chief invariant is that a rejected command changes nothing — but it must still *say* so. Currently the game rejects silently. **Avoid `error_002`, it peaks at 0.0 dBFS.** |
| Purchase confirmed | `interface/confirmation_002.ogg` | 0.29–0.54 | |

---

## Battle

| Event | File(s) | sec | Why |
|---|---|---|---|
| Ash claws | `interface/scratch_001…005.ogg` | 0.12–0.33 | Named for UI scratch, but five short claw-textured hits in a game about a cat is the single luckiest find in the library. `[ear]` |
| Ash pounces (soft hit) | `impact/impactSoft_medium_000…004.ogg` | 0.12–0.18 | Loudest mean in the impact pack (−14.3 dB); a paw landing, not a punch. |
| Enemy hits Ash | `impact/impactPunch_medium_000…004.ogg` | 0.41–0.54 | Heavier and longer — reads as *taken*, not *dealt*. |
| Heavy blow lands | `impact/impactSoft_heavy_000…004.ogg` | 0.50–0.57 | For the Unpicked and boss beats. |
| Blocked / guarded | `impact/impactPlate_light_000…004.ogg` | 0.49–0.66 | Metallic deflection. `[ear]` |
| Charge a card onto a skill | `interface/pluck_001.ogg`, `pluck_002.ogg` | 0.10–0.17 | A plucked string, for spending off the spool. Thematically exact. **`pluck_001` peaks at 0.0 dBFS** — use `pluck_002` or normalise. |
| Play a skill | `rpg-audio/cloth1…cloth4.ogg` | 0.38–0.66 | Cloth swish; four variants. |
| Concentrate | `interface/bong_001.ogg` | 0.12 | Single file, no variants — thin if concentrating is frequent. `[ear]` |
| End turn | `interface/switch_001…007.ogg` | 0.50–0.62 | Longest UI family; a deliberate, weighty action. |
| Slip away / retreat | `rpg-audio/cloth3.ogg` + `impact/footstep_carpet_000…004.ogg` | 0.14–0.66 | Layer: the cloth, then two soft paw steps receding. |
| Victory | `music-jingles/Pizzicato jingles/jingles_PIZZI**??**.ogg` | 0.46–1.32 | See below. |
| Defeat | `music-jingles/Pizzicato jingles/jingles_PIZZI**??**.ogg` | 0.46–1.32 | See below. |

### The jingles — the one real stroke of luck

`music-prompts.md` fixes the soundtrack palette as *"music box / celesta,
**pizzicato strings**, clarinet, harp"* and asks for four stings:
`sting_victory`, `sting_defeat`, `sting_achievement`, `sting_sunbeam`.

The Music Jingles pack contains a **Pizzicato** folder — 17 jingles,
0.46–1.32s, mean −15.8 dB. That is the declared instrument, at the declared
length, for the exact four cues the doc asks for, at zero cost and zero API
calls.

**This is the highest-value item in the shortlist and the one I can least
verify.** Which of the 17 is triumphant and which is rueful cannot be read off
a waveform. Audition all 17, pick four, and if they hold, the four sting
generations come off the ElevenLabs budget entirely.

The other four jingle folders are **rejected**: `8-Bit`/NES (wrong century),
`Steel` (steel drum), `Sax` (jazz-adjacent, but the palette says clarinet, and
sax will fight the score), `Hit` (orchestral stabs — the doc explicitly says no
epic orchestra).

---

## Minigames

| Minigame | Event | File(s) |
|---|---|---|
| **Stitch** | needle through fabric | `rpg-audio/cloth1…4.ogg` |
| **Stitch** | edge locked in | `interface/pluck_002.ogg` |
| **Lattice** | pull a thread | `interface/pluck_001/002.ogg` `[ear]` |
| **Lattice** | thread resolves | `interface/glass_002.ogg` (0.11–0.69) `[ear]` |
| **Ward** | pick up a patch | `rpg-audio/handleSmallLeather.ogg` |
| **Ward** | rotate | `interface/toggle_002.ogg` |
| **Ward** | patch placed | `interface/drop_001…004.ogg` |
| **Ward** | patch settles | `rpg-audio/clothBelt.ogg`, `clothBelt2.ogg` |
| **Testimony** | ribbon chosen | `interface/select_003.ogg` `[ear]` — family spans 0.04–1.94s, wildly uneven; check the index |
| **Testimony** | contradiction found | `interface/question_001…004.ogg` (0.33–0.49) |
| **Crossing** | paw step on tile | `impact/footstep_wood_000…004.ogg` (0.25) |
| **Crossing** | soft landing | `impact/footstep_carpet_000…004.ogg` (0.14) |
| **Crossing** | slip / lose footing | `impact/impactTin_medium_000…004.ogg` (0.13–0.21) `[ear]` |

---

## Hub, Mantel, Exchange

| Event | File(s) | Why |
|---|---|---|
| Gleam spent / purse handled | `rpg-audio/handleCoins.ogg`, `handleCoins2.ogg` | **Both peak at 0.0 dBFS.** Normalise before use. |
| Equip to the tray | `rpg-audio/beltHandle1.ogg`, `beltHandle2.ogg` | Leather-and-buckle; the tray is worn, not carried. |
| Enter a location | `rpg-audio/doorOpen_1.ogg` | Peaks at 0.0 dBFS. |
| Leave a location | `rpg-audio/doorClose_1.ogg` | Peaks at 0.0 dBFS. |

## The Hollow Court

`music-prompts.md` describes it as *"harpsichord and low clarinet with a slow
ticking rhythm like a stamping clock, bureaucratic afterlife waiting room."*
The foley should serve that, and law 15 bites hardest here — the player sees
this room after **every** death.

| Event | File(s) | Why |
|---|---|---|
| The ledger stamped | `rpg-audio/bookPlace1…3.ogg` (0.26–0.35) | A book set down on a desk. Three variants for the repetition law. All three peak at 0.0 dBFS. |
| The clock | `interface/tick_001/002/004.ogg` (0.02–0.06) | Note there is **no `tick_003`** in the pack. |
| The Court's door | `rpg-audio/creak1…3.ogg` (0.34–0.83) | Three variants, quiet (mean −24.5 dB). |

---

## Defect found while measuring: 43 files peak at or above −0.1 dBFS

Ten percent of the library is mastered to full scale, almost all of it in
`kenney_rpg-audio` — every `bookPlace`, every `doorClose`/`doorOpen`,
`bookClose`, `chop`, `handleCoins`, most `footstep`s, plus `pluck_001` and
`error_002` in the interface pack.

Played over the score through a phone speaker, these will clip and stick out.
`music-prompts.md` already sets the rule — *"quiet dynamics… no sudden loud
peaks"* — so the whole shortlist wants one normalisation pass on the way from
`assets/library/sfx/` into `game/assets/sfx/`, targeting roughly **−3 dBFS
peak** with the UI taps a few dB below the impacts. That is an ffmpeg one-liner
in the wiring script, not hand work. It is deliberately *not* applied to the
`incoming` candidates — those are judged as they are.

Some files also carry an extreme crest factor — `bookFlip1` measures −33.0 dB
mean against a 0.0 dB peak — meaning a near-silent body with one loud transient.
Peak normalisation alone will leave those inaudible on a phone. They need
loudness normalisation (`loudnorm`), not peak.

---

---

# Sonniss #GameAudioGDC 2026 — 31 libraries, 89 files

Where Kenney gives short game-ready one-shots, Sonniss gives professional
masters: long, unedited, 96 kHz. These are the *texture* layer — the things a
stylised UI pack cannot supply.

The bundle is five zips totalling 7.5 GB. `tools/fetch_sonniss.py` never
downloads them: it reads each archive's central directory over an HTTP range
request, then range-fetches only the members of the chosen libraries. 850 MB
transferred instead of 7.5 GB. `--list` prints all 125 libraries if you want to
revise the selection.

## The strong picks

| Library | Files | What it gives the game |
|---|---|---|
| **Sonic Bat - Music Boxes** | 4 | 192 kHz music box, incl. `Music Box C Wind Up`. This is literally the instrument [`music-prompts.md`](music-prompts.md) names first. The wind-up belongs on the title screen. |
| **344 Audio - Antique Books** | 3 | `Slow Page Turns`, `Flicking Through Pages`, `Pile Of Antique Books Falling Over`. Real book foley for a book-shaped UI. |
| **344 Audio - Antique Clocks** | 2 | Two long ticking recordings — `Crooked Antique Clock` and `You're Running Late`. The Hollow Court's "stamping clock", already recorded. |
| **344 Audio - Antique Typewriter** | 3 | Carriage movement, paper movements, space key. Death's bureaucracy has a sound and this is it. |
| **344 Audio - Casino Cards** | 3 | Shuffling, dealing, `Pick Up Multiple Cards At Once`. It is a card game. |
| **Epic Stock Media - Fantasy Game 2** | 4 | `Inventory Open Flip Cloth Canvas Bag` (the tray), `Tarot Deck Heavy Shuffle`, a magic-light spell. |
| **344 Audio - Antique Small Metals** | 3 | `Antique Measuring Tape` — a tailor's tape, for a game about stitching — plus a tinkering lock. |
| **InMotionAudio - Velcro** | 2 | `VelcroRip29` (0.4s) is the closest thing anywhere to **a thread snapping**. |
| **InMotionAudio - Foley T-Shirt** / **Washing Basket** | 5 | Cloth movement and pats. The stitch and ward minigames. |
| **InMotionAudio - Sinister Textures 5** | 3 | `Cladding_NailScratch19`, `Cladding_Scratch06` — claws on a wall. |
| **InMotionAudio - Sinister Textures 4** | 2 | Long eerie noise-box hits for the Unpicked. |
| **Cinematic Sound Design** (6 packs) | 18 | `Interface Plucks Happy`, `Button Arp Twinkle`, `Accept Glassy Snap`, `Deny Muted`, `Ting Coins`, `Coin Flip`, two page turns. Tuned and gentle — closer to the score's palette than Kenney's clicks. |
| **CB_Sounddesign - Organic UI** | 4 | Kalimba and xylophone UI tones. Tuned percussion, same family as a music box. |
| **Epic Stock Media - Board Game** | 4 | Card flip/toss, `UI Button Analog Vintage Double Click`, wooden pieces. |
| **344 Audio - Dog Vocalisations** | 2 | Barks, and `Dog Shuffle, Grunt, Movement, Lying Down` — for `en_chained_dog`, whose whole character is being chained. |
| **InMotionAudio - Chimney Wind** | 1 | 115s of wind in a chimney. Rooftops and cold interiors. |
| **Jake Fielding - Interior Wind Rain and Storms** | 3 | Rain on window, hail on window, interior thunder. The Mantel, heard from inside. |
| **Sonic Bat - Stormy Night Ambience** | 1 | 122s `City Block Square Storm`. The Crossing. |
| **Ivo Vicic - Campfire** | 2 | Crackling hearth, and `Putting Out Fire` — a candle going out reads as a death. |
| **Ivo Vicic - Church Bells** | 2 | Near and far. The city has a clock tower now. |
| **344 Audio - Antique Luggage** / **Instrument Case** | 6 | Leather, buckles, latches, handles. The tray. |

## Two picks that missed — my error, recorded so it isn't repeated

Both were chosen from library names without a track listing, which is exactly
the failure mode the name-based selection invites.

- **Epic Stock Media - Strange Game Ambient Loops 3** (4 files, 125 MB) —
  "strange" turned out to mean *sci-fi*: factory machinery, a ship reactor, a
  synth forest. Only `Shimmer Loop Small Bell Metal Taps` (44s) is usable, and
  that one is genuinely good for the Court. **125 MB for one file.**
- **SoundBits - Vox Bestiae - Source Elements** (4 files, 2.4 MB) — "beast
  voices" means *monster* voices: an aquatic gurgle, an ethereal entity, a
  humanoid exhale, an insectoid tremble. No real animals. Cheap miss, but it
  means **the cat gap is completely unfilled** by Sonniss.

`344 Audio - Ghostly Presences Vol. 1` is a third question mark: 199 MB in a
single 96 kHz file called `Evil Spell Ambience`. It may be perfect for the
Hollow Court or it may be far too horror-movie for a deadpan afterlife waiting
room. Audition before keeping — it is 23% of the download on its own.

---

# Freesound — 148 CC0 files, 14.7 MB

`tools/fetch_freesound.py`, 22 queries in five groups. Every result is checked
against the CC0 licence URL individually, not just filtered in the query, and
each is recorded in `provenance.json` (id, uploader, duration, source URL) so
any sound can be traced back years from now.

All 148 are Ogg Vorbis previews, 13.7 minutes total.

## The cat, at last

37 files. Across Kenney and Sonniss there was not one; this is the whole reason
the API key mattered.

| Cue | Files | Note |
|---|---|---|
| **The chirrup** | `668820…668825_Cat trill 1–6` (0.32–1.22s) | Six clean variants of the exact noise Ash makes. `850103_Chatter and Trill` and `850104_Cat trills shortly` are the same idea but **8 kHz** — unusable, ignore them. |
| Hiss | `146960…146963_catHisses`, `819958`, `826834` (0.81–3.28s) | Six variants, all quiet (−10 to −19 dB). |
| Purr | `337200`, `575933`, `779220`, `509524` (2.78–9.18s) | `509524` is −34.4 dB mean; needs a big lift or drop it. |
| Meow | `817884`, `814893`, `448018`, `730100`, `534268` (0.39–3.83s) | |
| Growl / fight | `146967`, `146968`, `146972_catAttack`, `647307_cat fight` | For the alley enemies as much as for Ash. |
| **`828246_ANMLCat_angry hungry meow collar jingles`** | 2.92s | A cat meowing *with a collar jingling*. Ash takes the red neckerchief in `sc_collar`; this is a post-collar Ash sound and nothing else in three libraries is that specific. |

## The other four groups

**`thread` (44 files) — the best surprise after the cat.**
`807957_Sewer Stitcher Fixer`, `807958_Sewing Stitching Fixing Quick`,
`807959_Sewn Stitched Fixed Fast` are literal stitching recordings — the
Stitch minigame's core sound, which I had assumed would have to be generated.
`138096…138098_tang1/tang2/tangcomplete` (0.10–0.35s) are plucked wire: a
thread snapping, shorter and cleaner than the Sonniss Velcro. Plus eight
`Leather Belt Stretching` takes for tension, four cloth rips, two Velcro pulls,
and `554238_Cord String Pull`.

**`roof` (24 files).** `689998_Pigeon, Flies Away, Flapping Wings` and
`808001_Homing Pigeon Cooing` — the rooftops have residents now. Five
`bird_flapping` variants, six wind gusts including two 24s whipping storms.

**`room` (34 files).** Three `362622/3/4_Stamp` variants at 0.54–0.64s plus
`450064/450066_CheckPress_STAMP` — the Court's one gesture, in enough variants
to satisfy law 15. Seven wood creaks. `826338_Candle flame flickers, blown out`
for a death. And `675054_S11-22 Courtroom pre-trial murmuring` — a *courtroom*
murmur, for a court, which is luckier than the query deserved.

**`beast` (9 files).** Four rat squeaks, four crow/raven calls.

## What the queries got wrong

The `room tone` query was too generic and dragged in junk that should be
deleted rather than auditioned: `576093_Scifi_Room_Ambience`,
`784207_13 Inch Sharp Linytron TV`, `729330_Spacious Bar Ambience`,
`441625_Ambient Synth Lead`, `189023_air conditioner 2`,
`411914_Laundry Room Ambience`. Roughly 8 of 34 `room` files are unusable.
The lesson is in the tool's comment: keep Freesound queries to one or two
words, but a *generic* two-word query is its own failure mode.

Also junk: `248254_Pecked eyeball`, `660765_Loading a Ballista`,
`839918_White-winged Parakeets`.

**Quality caveats.** Six files sit below 44.1 kHz (two cat trills at 8 kHz —
discard). 22 files peak at or above −0.1 dBFS, the same clipping problem the
Kenney packs have. And token auth reaches previews, not originals: these are
lossy re-encodes. Fine for auditioning and, at phone-speaker scale, usually
fine to ship — but re-fetch a signature sound by hand if it matters.

---

## What none of the three libraries have

657 files across three libraries. Sonniss closed the ambience gaps — wind,
rain, hearth, city bells. Freesound closed the animal and stitching gaps —
the cat, pigeons, rats, crows, literal sewing, and the Court's stamp.

What is left has to be **generated**, because no stock library will carry it —
these are specific to this game:

- **The Unpicked unravelling** — a thread coming apart *as a voice*. The boss's
  signature, and nothing recorded sounds like it.
- **The Hollow Court's own room tone** — a bureaucratic afterlife that is
  deadpan rather than haunted. `Ghostly Presences` may be too horror for it.

Rough cost at ElevenLabs rates: **a handful of effects, well under $1**, plus
the $5/mo tier needed for the commercial licence. Note the Sonniss AI clause
above — generate from text prompts, never with a Sonniss file as reference.

---

## Next steps

Sourcing and staging are done — 657 source files across three libraries, 287
candidates staged in `assets/incoming/sfx/`, all commercially clear. Everything
below is selection and wiring.

1. **The owner auditions `assets/incoming/sfx/`** and deletes what does not
   belong. The known junk was already excluded at the staging step, so
   everything present is at least plausible. Priorities while listening:
   the 17 pizzicato jingles (four become the stings, and nothing else can
   replace them), `court/ghost_ambience` (likely too horror), and the eight
   long beds.
2. `python tools/stage_sfx.py --manifest` to make the reference table match
   what survived.
3. Promote survivors from `assets/incoming/sfx/` to `assets/library/sfx/` —
   that folder is tracked, and the move is what makes a sound part of the
   game's canon.
4. Write `tools/wire_sfx.py` for `assets/library/sfx/` → `game/assets/sfx/`,
   mirroring `tools/wire_assets.py`. It has to do more than copy: trim the
   Sonniss beds to the useful moment, and run one `loudnorm` pass across the
   lot — 27 staged files still clip and eight are near-inaudible.
5. Then `godot --headless --path game --import` (law 23) before anything can
   see them.
6. Wire the rejected-command sound first — it fixes a real silence law 19 cares
   about.

Nothing here has been **heard**. The measurements are real; the judgements are
name-and-number deep. Build the dev-menu soundboard before trusting any of it.
