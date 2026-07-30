# Music Prompts — for Ilovesong (copy-paste ready)

Soundtrack identity: **a music box that learned jazz manners** — small, warm,
slightly wry, a little sad. One consistent chamber palette across every
track so the game sounds like one place: **music box / celesta, pizzicato
strings, clarinet, harp, soft upright piano, brushed percussion**. No epic
orchestra, no synths, no drums bigger than a brush kit.

Rules for every generation:
- **Instrumental only** (no vocals — words fight the game's own text).
- **Loopable**: ask for a seamless loop or a track that ends the way it
  begins; 1.5–3 minutes is plenty.
- **Quiet dynamics**: this plays out of phone speakers under gameplay; no
  sudden loud peaks.
- Generate 2–3 takes per prompt, keep the one that feels like the *room* it
  belongs to. Save as `assets/incoming/music/<id>.mp3`.

---

## 1. `mus_title` — Title / main theme

> A gentle melancholy waltz for music box and pizzicato strings, with a warm clarinet melody entering later, storybook fairytale mood that is sad but comforting, quiet and intimate, slow 3/4 time, instrumental, seamless loop, soft dynamics throughout

## 2. `mus_mantel` — The Mantel (home hub, her cold parlor)

> A quiet cozy piece for solo music box and soft harp with long silences between phrases, intimate and wistful, like an empty room that used to be warm, very sparse and slow, instrumental, seamless loop, extremely gentle

## 3. `mus_prowl` — Rooftops & streets (exploration)

> A light sneaking theme for pizzicato strings, brushed percussion and clarinet, curious and confident like a cat trotting across rooftops at dusk, moderate walking tempo, playful but foggy nighttime mood, instrumental, seamless loop

## 4. `mus_combat` — Standard encounter

> A tense but playful chamber piece for fast pizzicato strings, staccato piano and clarinet, cat-and-mouse energy, clever rather than heavy, moderate-fast tempo with a steady pulse, minor key with witty accents, instrumental, seamless loop, no big drums

## 5. `mus_stealth` — The Back Gardens (stealth missions)

> A very quiet tiptoe theme for muted pizzicato strings and celesta with lots of space between notes, held-breath suspense, sneaky and delicate, slow tempo, tiny playful accents like careful paw steps, instrumental, seamless loop

## 6. `mus_hollow_court` — The Hollow Court (death's bureaucracy)

> A dry deadpan piece for harpsichord and low clarinet with a slow ticking rhythm like a stamping clock, solemn but faintly comical, bureaucratic afterlife waiting room mood, sparse and orderly, instrumental, seamless loop

## 7. `mus_elspeth` — Flashbacks / Elspeth's theme

> A warm tender theme for soft upright piano and harp with a gentle clarinet countermelody, golden afternoon light in a sewing room, loving and nostalgic with an undertow of grief, slow 3/4 time, instrumental, seamless loop

## 8. `mus_unpicked` — The Unpicked / boss danger

> An unsettling chamber piece where a music box melody slowly comes apart over dissonant sliding strings, beautiful and wrong, threads unraveling, quiet dread building without ever getting loud, slow tempo, instrumental, seamless loop

## 9. Stings (short one-shots, 2–6 seconds each)

- `sting_victory`: > A tiny triumphant flourish for pizzicato strings and celesta, quick and self-satisfied like a cat that meant to do that, two seconds, instrumental
- `sting_defeat`: > A soft falling phrase for clarinet and low piano, rueful but gentle, not tragic, three seconds, instrumental
- `sting_achievement`: > A bright little music box arpeggio, pleased and quick, two seconds, instrumental
- `sting_sunbeam`: > A single warm rising harp glissando with celesta shimmer, like sunlight landing on fur, two seconds, instrumental

---

## Integration notes (mine)

Priority order if credits are limited: **4 (combat) → 2 (mantel) → 3
(prowl) → stings → the rest.** Combat is 70% of play time. I'll handle
looping cleanup (trim/crossfade in Audacity), volume normalization, OGG
conversion for Godot, and wiring tracks to scenes. If Ilovesong offers a
"style reference" or continuation feature, reuse your favorite generated
track as the reference for all others — same trick as Kling's reference
images, same reason.
