# Image Requests — Prologue Gaps (ChatGPT, copy-paste ready)

*2026-07-30. Everything below is a nice-to-have — the prologue is fully
playable with current art. Listed in priority order. Since ChatGPT can do
same-scene variants, several of these are "generate A, then ask for variant
B in the same conversation" — that's the whole trick.*

**Style context (paste first, or attach an existing scene image and say
"match this"):**

> Hand-drawn storybook illustration style: ink linework with muted watercolor
> washes, warm amber light against blue-grey fog, cozy-gothic children's book
> aesthetic, high resolution. No text in the image.

## 1. The parlor pair (warm → cold) — replaces our engine tint

**`bg_parlor_warm`** (3:4):
> A cozy witch's parlor interior: a worn armchair by a small iron stove with a copper kettle gently steaming, walls hung with embroidery hoops and spools of faintly glowing silver thread, herbs drying from the beams, a saucer of milk by the hearth, warm golden lamplight, lived-in and loved.

**`bg_parlor_cold`** (same conversation, immediately after):
> Now the exact same room, but tonight everything is wrong: the stove cold and dark, the lamp out, thin blue moonlight through the window as the only light, and every thread and thin line hanging on the walls has been cut and dangles loose like torn hems. Same furniture, same layout, same style — only the light and the cut threads have changed.

## 2. The murder-night reveal scene

**`sc_threads_cut`** (3:4):
> Interior of a dark workroom at night seen from a cat's low viewpoint: walls covered in embroidery hoops and pinned threads where every single thread has been freshly cut, the loose ends hanging and gently drifting, thin blue moonlight, and through a doorway at the far end a tall shape woven of glowing silver threads stands with its back turned, mid-work. Quiet dread, storybook style.

## 3. Needle Lane gone wrong (variant of our existing street)

Attach `assets/incoming/bg_needle_lane.png`, then:
> Take this same foggy gaslamp street and make it subtly wrong: all the street lamps unlit except one at the far end, no birds anywhere, one window in the distance glowing faintly cold blue instead of warm amber. Same street, same style, same composition — only the light has changed.
> *(save as `bg_needle_lane_wrong` — used for the "wrong quiet" beats)*

## 4. The route-home decision art (one per branch)

**`sc_lamplighters_hall`** (3:4):
> The interior of a lamplighters' guild hall at night, abandoned mid-shift: ladders racked on the wall, long lighting-poles in their stands, a kettle gone cold on a small stove, one silver thread caught glinting on a brass lamp-hook in the foreground. Nobody there. Storybook ink and watercolor.

**`sc_over_the_fences`** (3:4):
> A black cat with a red neckerchief in full sprint leaping between fence tops and garden walls at night, motion-blurred fog, rooftops and a dark window ahead, urgency and grace. Storybook ink and watercolor. *(attach ref_ash.png as reference)*

## 5. The Hunt opener

**`sc_vole_stalk`** (3:4, attach ref_ash.png):
> A black cat with a red neckerchief pressed low against rooftop tiles at dusk, pupils wide, hindquarters raised in the pre-pounce wiggle, stalking a small unaware vole near a chimney pot a short distance away, warm last light. Storybook ink and watercolor.

## 6. UI stragglers (ChatGPT, transparent background attempts)

- **`ui_medallions`** — six small round achievement medallions in one image,
  same rim style: laurel medal, crescent moon, pocket watch, shield, trophy
  cup, quill pen; bronze-toned ink and watercolor. *(I'll split them apart.)*
- **`ui_ash_head`** — a tiny emblem of the black cat's face with the red
  neckerchief, front view, chunky enough to read at 32 pixels.

## Background note

Backgrounds don't need transparency (I remove/crop programmatically), and
generate everything at whatever high resolution ChatGPT gives — I downscale
on import, hi-res sources stay archived in `assets/incoming/`.
