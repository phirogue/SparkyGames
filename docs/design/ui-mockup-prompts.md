# UI Look & Feel — ChatGPT Mockup Prompts

> **SUPERSEDED 2026-08-06** by [ui-template-prompts.md](ui-template-prompts.md).
> Written when the in-game UI was grey placeholder buttons; it no longer is.
> Index: [ART-INDEX.md](ART-INDEX.md).


*2026-07-30. The current in-game UI is functional placeholder (grey buttons,
colored panels). These prompts generate visual mockups in ChatGPT to choose a
UI direction. Workflow: generate 3–4 takes per prompt, steer with follow-ups
("less cluttered", "bigger cards", "darker"), then drop the winning image in
`assets/incoming/ui-reference.png` — the game theme (panels, fonts, colors,
frames) is all code and will be rebuilt to match it.*

## 1. Battle screen (the main one)

> Design a high-fidelity UI mockup image of a mobile card game battle screen, 9:16 portrait orientation, for a cozy-gothic storybook game called "The Nine Lives of Ashcat" — you play a black cat detective in a foggy gaslamp city. The entire interface should look like an illustrated storybook: aged cream parchment panels, hand-drawn ink linework frames, muted watercolor washes in charcoal grey and warm amber, decorative thread-stitch borders on the panels (the game's magic system is sewing), and small wax-seal style buttons. Layout from top to bottom: (1) a narrow location banner reading "Needle Lane, Night" with a small rule note "Deep fog: Shadow costs 1 less"; (2) an enemy area showing a framed ink-and-watercolor portrait of a ghost made of empty floating clothes, its name "Rag-wraith", a health bar drawn as a fraying red thread being unstitched, and a telegraphed intent banner with a small icon reading "Next: Empty Sleeve — 5 damage"; (3) a thin parchment strip with one line of story log text in a handwritten-style font; (4) the player status row: a small black cat emblem, hearts or paw prints for health, a shield icon for block, and a wooden spool icon with a number for remaining deck; (5) the player's hand: five small energy cards fanned slightly, each card showing a simple glyph and color — a red claw (Ferocity), a green half-closed cat eye (Guile), black smoke (Shadow), a silver moon through a needle's eye (Moonlight); (6) a skill bar of four larger illustrated ability buttons with names like "Pounce" and "Slink", each with small charge pips; (7) at the bottom, a large warm "End Turn" button and a smaller "Slip Away" button that looks like a cat vanishing into shadow. Everything must be readable at phone size, with clear visual hierarchy, warm lamplight accents against cool fog blues, and no photorealism — it should feel like playing inside a hand-illustrated children's book with teeth.

## 2. The Mantel (hub screen)

> Design a UI mockup image of a mobile game hub screen, 9:16 portrait, storybook ink-and-watercolor style, for a cozy-gothic cat detective game. The scene is a witch's cold parlor at night: the top half shows a stone mantelpiece with quest cards pinned to it like handwritten notes and letters, each note showing a short quest title such as "Night Rounds" and "The Garden Route" with a small wax seal; below the mantel, a small shop area labeled "The Magpie Exchange" with three parchment buttons showing a card being added, a card being removed, and a small potion bottle; a counter of "Gleam" currency drawn as a small pile of shiny buttons and trinkets with a number; at the bottom a soft banner listing achievements. Aged cream parchment panels, ink linework, thread-stitch borders, warm candlelight accents against cool blue shadows, readable at phone size, hand-illustrated children's book feeling, slightly melancholy but warm, no photorealism.

## 3. Story screen

> Design a UI mockup image of a mobile game story moment screen, 9:16 portrait, storybook ink-and-watercolor style. A large hand-illustrated scene fills the top two thirds: a black cat with a red neckerchief trotting across foggy rooftops at dusk carrying a vole. The bottom third is a simple aged parchment panel with a single line of narration in an elegant handwritten-style font: "She puts the kettle on when the lamps go up." and a small "tap to continue" hint. Minimal interface, generous margins, ink linework frame around the illustration with thread-stitch corner details, warm amber dusk light against blue-grey fog, hand-illustrated children's book feeling, no photorealism.

## What happens after a direction is chosen

The winning mockup drives a real Godot theme: StyleBoxFlat/StyleBoxTexture
panels, a parchment palette, storybook display font + readable UI font
(Google Fonts, OFL), card frames, and button styles. The mockup is a
*reference*, not an asset — everything is rebuilt cleanly in-engine, so it
stays crisp at every screen size.
