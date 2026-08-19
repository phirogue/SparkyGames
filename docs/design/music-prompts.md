# Music Prompts — for iLoveSong.ai (copy-paste ready)

Soundtrack identity: **a music box that learned jazz manners** — small, warm,
slightly wry, a little sad. One chamber palette across every track so the game
sounds like one place: **music box / celesta, pizzicato strings, clarinet,
harp, soft upright piano, brushed percussion**. No epic orchestra, no synths,
no drums bigger than a brush kit.

The score is the room the player is standing in. Ash's music does not change
because the fight got harder; it changes because he walked somewhere else.

---

## Driving iLoveSong

The site's generator has three controls that matter here:

| Control | Set it to | Why |
|---|---|---|
| **Instrumental** | **ON, every single time** | Words fight the game's own text, and every screen is text. |
| **Lyrics** | leave empty | Instrumental mode; nothing to fill in. |
| **Style Of Music** | the prompt below, verbatim | The field takes ~1000 characters. Every prompt here fits with room to spare. |
| Length | ~2 minutes for beds, shortest available for stings | We fold the take into a loop afterwards, so length past ~2:30 is wasted credit. |
| Music Persona / Extend | see below | This is how the eight tracks end up sounding like one score. |

**The consistency trick — do this before generating the bulk.** Generate
`mus_prowl` first (the most characteristic track: it has the tempo, the
pizzicato and the clarinet all in one). Take the keeper, save it as a **Music
Persona** / style reference, and generate everything else with that persona
applied. Same reasoning as `--ref` in the art pipeline (CLAUDE.md, art rule 4):
words let a thing drift, a reference does not. If the persona feature is
paywalled or unavailable, fall back to pasting the same prompt skeleton and
changing only the mood clause.

**Two takes per prompt, then stop.** Keep the one that sounds like the *room*
it belongs to, delete the other. A third take is usually credit spent on a
decision you already made.

**If the model drifts** (it will drift toward big and cinematic), append this
tail to the Style field:

> avoid: vocals, choir, drum kit, epic orchestra, cinematic strings, synth pads, EDM, risers, big crescendos, loud ending

---

## The tracks

Priority order if credits are limited. **Tier 1 is five tracks and covers the
game** — combat is most of the play time, and the Hollow Court is seen after
*every* death, which makes it the track a player hears most often per minute of
its own length (law 15: repeated content must vary, and repeated *music* wears
out fastest of all).

| Tier | Track | Where it plays |
|---|---|---|
| **1** | `mus_combat` | every standard encounter — wisps, the dog, rag-wraiths |
| **1** | `mus_prowl` | rooftops and streets: `rooftop_dusk`, `needle_lane`, travel beats |
| **1** | `mus_mantel` | the hub, `parlor_cold` — her house, after |
| **1** | `mus_hollow_court` | `hollow_court`, after every death |
| **1** | `mus_title` | splash and title card |
| **2** | `mus_stealth` | `back_gardens`, the Unpicking heists |
| **2** | `mus_needlework` | Seam & Stitch, Patch the Ward, the lattice |
| **2** | `mus_elspeth` | `parlor_warm`, flashbacks, the wake |
| **2** | `mus_unpicked` | The Unpicked, `needle_lane_wrong` |
| **3** | `mus_tallowman` | `guildhall`, `wickhouse`, the Chapter 1 finale |
| **3** | `mus_testimony` | Testimony scenes and the case board |
| **3** | `mus_shambles` | `shambles_market`, the Exchange, guild dealings |
| **3** | `mus_mereside` | `mereside_edge`, the Drowned |
| **3** | `mus_chase` | chases and escorts (non-combat scenarios) |
| **3** | `mus_ending` | the case presented; the nine-deaths ending |
| **2** | stings ×6 | victory, retreat, a life spent, a clue, an achievement, a sunbeam |

The Long Way Round (the crossing minigame) reuses `mus_prowl`. Journal and
settings play whatever the screen behind them was playing.

---

### 1. `mus_prowl` — rooftops and streets *(generate this one first)*

> Instrumental chamber piece for pizzicato strings, clarinet, celesta and brushed percussion. A cat trotting along wet rooftops at dusk — curious, unhurried, quietly pleased with itself. Moderate walking tempo, light swing, minor key with warm major turns. Small room, close mics, soft tape hiss, quiet dynamics throughout. No vocals, no drum kit, no orchestra, no synths, no big ending.

### 2. `mus_combat` — standard encounter

> Instrumental chamber piece for fast pizzicato strings, staccato upright piano, clarinet and brushed snare. Cat-and-mouse: clever rather than heavy, quick footwork, a steady pulse you could stalk to. Moderate-fast tempo, minor key with witty accents and sudden little stops. Small room, close mics, restrained dynamics — this plays under gameplay on a phone speaker. No vocals, no drum kit, no orchestra, no synths, no crescendo.

### 3. `mus_mantel` — the Mantel (her parlor, cold)

> Instrumental piece for solo music box and soft harp, with long silences between phrases and one distant clarinet line. An empty room that used to be warm; someone's things still where they left them. Very sparse, very slow, almost no rhythm. Small room, close mics, low volume, a little tape hiss. No vocals, no percussion, no orchestra, no synths, no build.

### 4. `mus_hollow_court` — the Hollow Court

> Instrumental piece for harpsichord and low clarinet over a slow ticking pulse like a rubber stamp finding a page. Death's filing office: solemn, orderly, faintly comical, endlessly patient. Slow steady tempo, dry staccato, sparse. Small room, close mics, quiet. Deadpan rather than spooky. No vocals, no drum kit, no orchestra, no synths, no horror stingers.

### 5. `mus_title` — title and main theme

> Instrumental melancholy waltz for music box and pizzicato strings, a warm clarinet melody entering after the first turn, harp underneath. Storybook fairytale mood: sad but comforting, the way a good sad book is. Slow 3/4, minor key resolving warm. Small room, close mics, soft dynamics. No vocals, no drum kit, no orchestra, no synths, no fanfare.

### 6. `mus_stealth` — the Back Gardens, and heists

> Instrumental piece for muted pizzicato strings and celesta with a great deal of space between the notes. Held breath, careful paws, one twig-snap of a pizzicato and then stillness again. Very slow, very quiet, no steady beat — suspense that stays playful rather than frightening. Small room, close mics, extremely low dynamics. No vocals, no drums, no orchestra, no synths, no swell.

### 7. `mus_needlework` — the needlework minigames

> Instrumental piece for harp, celesta and soft upright piano, a small repeating figure that turns over and over like careful handwork. Concentration: patient, tidy, gently satisfying, a hand steady on fine work. Slow-moderate tempo, soft steady pulse, warm major key with wistful turns. Small room, close mics, low volume, unobtrusive — this plays under a puzzle. No vocals, no drums, no orchestra, no synths, no melody that demands attention.

### 8. `mus_elspeth` — flashbacks, the warm parlor

> Instrumental theme for soft upright piano and harp with a gentle clarinet countermelody. Golden afternoon light in a sewing room; someone humming while they work, remembered rather than heard. Loving and nostalgic with an undertow of grief. Slow 3/4, warm major key that keeps touching a minor chord. Small room, close mics, tender dynamics. No vocals, no drums, no orchestra, no synths, no swell.

### 9. `mus_unpicked` — the Unpicked

> Instrumental piece in which a pretty music box melody slowly comes apart over dissonant sliding strings and detuned celesta. Beautiful and wrong: threads pulling loose, the tune losing pieces of itself while it plays. Slow, quiet dread that never becomes loud. Small room, close mics, restrained throughout. No vocals, no drums, no orchestra, no synths, no jump scares, no crescendo.

### 10. `mus_tallowman` — the Chandlers' Guildhall, the Wickhouse

> Instrumental piece for low clarinet, harpsichord and bowed double bass with a slow processional tread and small bell-like celesta accents. Candle-wax formality: a rich guild room, warm light, something rendered in the back. Slow, heavy-footed, minor key, ceremonial but private. Small room, close mics, controlled dynamics. No vocals, no drum kit, no orchestra, no synths, no fanfare.

### 11. `mus_testimony` — testimony and the case board

> Instrumental piece for pizzicato strings, brushed cymbal and clarinet with long thinking pauses between short phrases. Listening hard to someone who is lying: attentive, patient, a small figure recurring whenever the thought comes back. Slow-moderate, sparse, minor key, unresolved. Small room, close mics, quiet. No vocals, no drum kit, no orchestra, no synths, no resolution at the end.

### 12. `mus_shambles` — the market after hours, the Exchange

> Instrumental piece for clarinet, pizzicato strings, soft piano and brushes with a light gossipy swing. A market packing up in the dark: bargaining, cheerful mischief, coins changing hands, nobody entirely honest. Moderate tempo, warm minor key with jaunty turns. Small room, close mics, easy dynamics. No vocals, no drum kit, no orchestra, no synths, no big band.

### 13. `mus_mereside` — the fog, the water

> Instrumental piece for bowed vibraphone, harp harmonics, low clarinet and a distant music box, with wide space and slow drift. Cold fog on still water; something under it that used to be a person. Very slow, no steady pulse, quiet and hollow. Small room, close mics, restrained. No vocals, no drums, no orchestra, no synth pads, no crescendo.

### 14. `mus_chase` — chases and escorts

> Instrumental piece for hurried pizzicato strings, staccato piano and brushed snare, driving forward without ever getting loud. A small fast animal going somewhere with purpose, corners taken at speed. Fast tempo, insistent steady pulse, minor key, breathless but light on its feet. Small room, close mics, controlled dynamics. No vocals, no drum kit, no orchestra, no synths, no cinematic build.

### 15. `mus_ending` — the case presented

> Instrumental piece for music box, harp, clarinet and pizzicato strings that gathers the game's main waltz theme up and finishes it properly. Grief that has been put in order at last; warm, tired, quietly earned. Slow 3/4, minor key resolving to a settled major. Small room, close mics, soft dynamics, a real ending rather than a fade. No vocals, no drum kit, no orchestra, no synths, no triumphant fanfare.

---

## Stings (one-shots, 2–5 seconds)

Same instrument palette, same persona. Ask for the shortest length the tool
allows and we trim the tail.

- `sting_victory` — > Instrumental two-second flourish for pizzicato strings and celesta, quick and self-satisfied like a cat that meant to do that. Small room, close mics, no vocals, no drums, no orchestra.
- `sting_retreat` — > Instrumental three-second falling phrase for clarinet and low piano, rueful and gentle, not tragic — a dignified exit. Small room, close mics, no vocals, no drums, no orchestra.
- `sting_life_spent` — > Instrumental three-second phrase for music box and a single struck bell, one note stopping short as if a thread were cut. Quiet, cold, final. Small room, close mics, no vocals, no drums, no orchestra.
- `sting_clue` — > Instrumental two-second rising figure for celesta and harp, a small bright click of understanding. Curious rather than triumphant. Small room, close mics, no vocals, no drums, no orchestra.
- `sting_achievement` — > Instrumental two-second music box arpeggio, pleased and quick. Small room, close mics, no vocals, no drums, no orchestra.
- `sting_sunbeam` — > Instrumental two-second warm harp glissando with celesta shimmer, like sunlight landing on fur. Small room, close mics, no vocals, no drums, no orchestra.

---

## What to hand back, and in what shape

**Drop the downloads here, named exactly like this:**

```
assets/incoming/music/mus_combat.wav        <- one keeper per track id
assets/incoming/music/sting_victory.wav
```

`assets/incoming/` is gitignored — it is the audition area, the same one the
sound effects use. Nothing there is in the game.

| | |
|---|---|
| **File name** | the track id above, exactly. `mus_combat.wav`. Two takes you can't choose between: `mus_combat_take1.wav`, `mus_combat_take2.wav` — the converter reads the id off the front and handles both. |
| **Container** | **WAV if the plan offers it**, otherwise MP3 at the highest bitrate available. WAV is lossless, and the game's file gets encoded exactly once instead of twice. |
| **Length** | ~1:30–2:30 for beds. Longer is fine but costs credits and build size for material nobody hears. |
| **Do NOT** | fade in/out, trim, normalise, or "master" it in the tool. Hand over the raw take — every one of those steps happens in the conversion, and doing them twice fights the loop fold. |

That is all that is needed. Looping, levels, sample rate, channel count and the
engine format are the converter's job.

### What the game actually needs (what the converter produces)

| Property | Value | Why |
|---|---|---|
| Format | **Ogg Vorbis** (`.ogg`) | Godot imports it natively. An MP3 carries encoder padding at both ends, which puts an audible tick in every loop — a track that loops every two minutes for a whole session. |
| Sample rate | 48 kHz stereo | Matches the sfx pipeline; phones resample anything else anyway. |
| Bitrate | VBR q3 (~112 kbps) beds, q4 stings | ~1 MB per minute. The game ships offline, so every megabyte is a download the player waits for. |
| Loudness | **−18 LUFS** beds, **−14 LUFS** stings | Music sits *under* the effects; `sfx-shortlist.md` puts those at −3 dBFS peak. |
| True peak | −3 dBTP | Headroom so the score plus a claw hit plus a UI tap does not clip a phone speaker. |
| Loop | tail folded back over the head | An AI take *ends*; it does not loop. See below. |

---

## Getting there on Windows, for free

**ffmpeg is already installed on this machine** — `C:\Users\yurim\Packages\ffmpeg\bin\ffmpeg.exe`,
already on PATH. Nothing to install, nothing to pay for.

### The whole job is one command

```powershell
python tools/wire_music.py            # assets/incoming/music -> assets/library/music (.ogg)
```

It reads every take in `assets/incoming/music/`, folds it into a loop,
normalises it, encodes it, and prints a table of what changed:

```
track                        in s  out s  xfade  LUFS in  -> target      KB
mus_combat.ogg              124.0  118.0    4.0    -12.4      -18.0     1620
```

Other flags:

```powershell
python tools/wire_music.py --measure          # report the raw takes, write nothing
python tools/wire_music.py --only mus_combat  # one track
python tools/wire_music.py --loop 8           # override the crossfade length
python tools/wire_music.py --wire             # library -> game/assets/music + Godot import
```

Per-track crossfade lengths live in the `TRACKS` table at the top of the
script, so a track that needs a longer fold gets it permanently rather than by
remembering a flag.

### The loop fold, since it is the one non-obvious step

A generated take has a beginning and an ending, so playing it on repeat gives
a silence, then a restart — the seam you notice for the rest of the session.
The fix takes the last N seconds and crossfades them back over the *first* N
seconds. The track then begins and ends on the same musical material, so the
splice from end to start is inaudible. The file gets N seconds shorter; that
is the whole cost.

By hand, if you ever want it outside the script (N = 6 here):

```powershell
ffmpeg -ss 6 -i take.wav -ar 48000 -ac 2 body.wav
ffmpeg -t 6 -i take.wav -ar 48000 -ac 2 head.wav
ffmpeg -i body.wav -i head.wav -filter_complex "[0][1]acrossfade=d=6:c1=tri:c2=tri" looped.wav
```

(Three runs, not one clever filter graph — feeding both crossfade inputs from
a single `asplit` stalls ffmpeg and silently writes an empty file. Learned the
hard way; the script's comment says so too.)

**Listen to every folded track on repeat before wiring it.** A crossfade can
smear a beat or double a note if the fold lands mid-phrase; the fix is a
different `--loop` value, usually one that matches a bar. This is law 1 with
ears instead of eyes — the converter measures, it does not listen.

### When you want to place the loop point by ear instead

Free, and worth having for exactly this: **Audacity**.

```powershell
winget install Audacity.Audacity
```

The useful thing it does is *find the number*: open the take, set the timeline
to seconds, and look for the bar line the fold should land on — the crossfade
sounds best when its length equals a whole number of bars. Read that length off
the selection and hand it to the converter as `--loop <seconds>`. The script
still does the work; Audacity just answers the question the script cannot.

For a take that needs real surgery (a bad ending, a stray count-in), trim it in
Audacity, export **WAV** back into `assets/incoming/music/`, and re-run the
converter — it treats the trimmed file as an ordinary take.

If ffmpeg ever needs reinstalling on another machine:

```powershell
winget install Gyan.FFmpeg          # or: winget install ffmpeg
```

Both are free; the Gyan build is the one already installed here.

---

## Before spending money on this

**Check what the plan grants.** The game ships commercially on iOS and Google
Play, so the generated tracks need commercial-use rights and, ideally, no
attribution requirement — the same policy the sound effects follow
(`sfx-shortlist.md` is CC0-only for exactly this reason). Free tiers on music
generators commonly grant personal use only. Confirm before generating fifteen
tracks, not after.

**The credit goes in the about screen.** `docs/design/ai-transparency.md` is the
standing decision: the game says plainly that its art, music and code lean on
AI. Generated music is named as generated music. Not a selling point, not
hidden.

---

## Integration notes

- Nothing plays audio yet. `settings_screen.gd` already has the **Music** and
  **Sound Effects** toggles and a five-step volume slider, and the profile
  already stores `music`, `sfx` and `volume` — the wiring reads those.
- `--wire` copies the accepted tracks into `game/assets/music/` and runs the
  Godot import pass, which is law 23: a file the engine never imported shows up
  as nothing at all.
- Looping is set on the stream in code (`AudioStreamOggVorbis.loop = true`),
  not in the `.import` — one place, next to the fade-between-tracks logic, when
  that lands.
- Track-to-screen mapping belongs in data, not in scene scripts (law 11), so
  the environment table above becomes a field on `environments.json` rather
  than a `match` statement.
