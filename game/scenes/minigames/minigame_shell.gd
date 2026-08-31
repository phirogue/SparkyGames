class_name MinigameShell
extends RefCounted
## The page furniture every mission minigame shares, so the five prototypes
## differ only where their RULES differ (docs/design/minigames.md).
##
## Deliberately geometric: dots, lines, boxes and type. No generated art, no
## new asset dependencies — the doc calls for drawn boards, and a prototype
## that waits on images cannot be felt this week.
##
## Zone template (law 6) for every module, summing with separations to
## UITheme.CONTENT_HEIGHT (1104):
##   header 96 + status 84 + board 720 + actions 168 = 1068, +3x12 = 1104
##
## The status band and the action row both grew at the owner's 2026-08-09
## pass: the running count was too small to read and the two buttons under a
## board were the same colour as each other, so nothing said which one ended
## the puzzle. Action buttons now come from `aid_button`/`leave_button`,
## which are deliberately NOT interchangeable.

const SEPARATION := 12
const ZONE_HEADER := 96
const ZONE_STATUS := 84
const ZONE_BOARD := 720
const ZONE_ACTIONS := 168
## A board with ONE verb under it does not need two rows' worth of plate.
## Testimony's "Let it lie" was "way too thick" (owner 2026-08-13), and the
## height it gives up goes straight to the board — `build` trades the two
## against each other so the template still sums to CONTENT_HEIGHT exactly
## (law 6), which is why this is a build argument and not a fourth ZONE_.
const ACTIONS_THIN := 108

const STATUS_FONT := 30
## Owner 2026-08-13: "the text for squint and leave it should be bigger". The
## verbs under a board are the two things a stuck player reads, so they now
## start at 42 and are FITTED down to whatever the button's share of the row
## actually holds (law 5 — never a guessed box). A one-verb row keeps 42; the
## ward's "Done mending" comes down a couple of steps and still reads bigger
## than the 34 it shipped at.
const ACTION_FONT := 42
const ACTION_HEIGHT := 112.0
## Two rows of verbs inside the same 168: 80 + 80 + one 8px separation.
const ACTION_HEIGHT_HALF := 80.0
const ACTION_FONT_HALF := 34
## Half the content width less the row separation: what one of two side-by-side
## action buttons really gets, which is what its type has to fit inside.
const ACTION_BUDGET_HALF := (UITheme.CONTENT_WIDTH - 10.0) / 2.0

## Guide lines on a drawn board. Godot's thin-line path dropped whole rows of
## 1px un-antialiased lines on the mobile renderer (the missing right and
## bottom edges of the stitch grid, owner 2026-08-09), so board guides are
## drawn through `guide_line` at a real width and never hand-rolled.
const INK_FAINT := Color("2b232055")
const GUIDE_WIDTH := 2.0

const THREAD := Color("8c2f24")
const BRASS := Color("b08d3f")
const CLOTH := Color("d8c9a8")
const TORN := Color("6b5747")
## A satisfied clue used to fade to light grey, which the owner could barely
## see. Answered clues now go green and get a ring; broken ones go red.
const DONE := Color("3f6b46")
const DONE_SOFT := Color("3f6b4644")

# The per-humour vocabulary lives in UITheme.HUMOUR_* — the copy that used to
# sit here claimed to be the battle screen's "shared verbatim" and had drifted
# on all four colours.


## Builds page + margin + the four zones. Returns
## {"header": HBox, "status": Label, "board": Control, "actions": VBox,
##  "help": Button}. The caller draws into `board`, adds rows of buttons to
## `actions` via `action_row`, and wires `help` with `start_tutorial`.
## `action_zone` shrinks the verb row and hands the difference to the board,
## so the two always add up to the same page (see ACTIONS_THIN).
static func build(root: Control, title: String, on_back: Callable,
		action_zone := ZONE_ACTIONS) -> Dictionary:
	var margin := UITheme.page_scaffold(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, ZONE_HEADER)
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var back := Button.new()
	back.custom_minimum_size = Vector2(96, 96)
	var arrow := UITheme.tex("ui/ui_arrow_back")
	if arrow != null:
		back.icon = arrow
		back.expand_icon = true
	else:
		back.text = "←"
	back.pressed.connect(on_back)
	header.add_child(back)
	# Title is FITTED, not sized: a two-word chart and "The Lamplighters' Hall
	# Ward" have to live in the same 96px band beside two 96px buttons.
	var title_box := Vector2(UITheme.CONTENT_WIDTH - 96 - 96 - 24, ZONE_HEADER)
	var title_label := UITheme.fitted_label(title, [38, 32, 27, 23], title_box,
		UITheme.display_font())
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	# "How do I play this?" — the owner's complaint about three of the five
	# modules was that nothing on the page answers it. Now something does,
	# on every board, forever, not only the first time.
	var help := UITheme.amber_button(Strings.line("minigames.help"), 40,
		Vector2(96, 96))
	header.add_child(help)

	var status := UITheme.measured_label("", STATUS_FONT, UITheme.CONTENT_WIDTH,
		UITheme.body_font(), UITheme.INK)
	status.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH, ZONE_STATUS)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(status)

	var board := Control.new()
	board.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH,
		ZONE_BOARD + ZONE_ACTIONS - action_zone)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(board)

	var actions := VBoxContainer.new()
	actions.custom_minimum_size = Vector2(0, action_zone)
	actions.add_theme_constant_override("separation", 8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(actions)

	return {"header": header, "status": status, "board": board,
		"actions": actions, "help": help, "title": title_label}


## One row of buttons inside the action zone. Crossings need two rows for
## four verbs; everything else uses one.
static func action_row(actions: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_child(row)
	return row


## The biggest size at or under `font_size` at which `text` fits `budget`
## pixels of button on one line. Measured at a wrap wide enough that nothing
## wraps, because a wrapped measurement reports the box, not the string, and
## that is exactly how a button label ends up cropped (law 5).
static func fit_font(text: String, budget: float, font_size: int) -> int:
	var size := font_size
	var room := budget - 32.0   # the plate's own content margins
	while size > UITheme.TYPE_FLOOR and UITheme.measure_text(
			text, UITheme.display_font(), size, 4000.0).x > room:
		size -= 1
	return size


## The HELPFUL action (Squint, Turn it, Read the Sky): amber, ink text.
## `height` only shrinks for a module that needs two rows of verbs — the
## action zone is a fixed 168 and two rows have to fit inside it (law 6).
## `budget` is the width this button will really get; the type is fitted to it.
static func aid_button(text: String, font_size := ACTION_FONT,
		height := ACTION_HEIGHT, budget := ACTION_BUDGET_HALF) -> Button:
	return UITheme.amber_button(text, fit_font(text, budget, font_size),
		Vector2(0, height))


## The action that ENDS the working (Leave it, Step back, Done mending):
## a deep red plate, unmistakably not the amber one beside it.
static func leave_button(text: String, font_size := ACTION_FONT,
		height := ACTION_HEIGHT, budget := ACTION_BUDGET_HALF) -> Button:
	var b := Button.new()
	b.text = text
	font_size = fit_font(text, budget, font_size)
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_override("font", UITheme.display_font())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _leave_stylebox())
	b.add_theme_stylebox_override("hover", _leave_stylebox(Color(1.15, 1.1, 1.1)))
	b.add_theme_stylebox_override("pressed", _leave_stylebox(Color(0.82, 0.78, 0.78)))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, Color("f6e8d4"))
	return b


static func _leave_stylebox(modulate := Color.WHITE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("7a2f26") * modulate
	box.set_border_width_all(3)
	box.border_color = Color("3d1a14")
	box.set_corner_radius_all(14)
	box.set_content_margin_all(14)
	return box


## Draw a board guide line. Never call draw_line directly for these: at width
## 1 with antialiasing off the renderer silently drops some of them, which is
## how a stitch grid shipped with no right-hand or bottom edge.
static func guide_line(canvas: CanvasItem, from: Vector2, to: Vector2,
		colour := INK_FAINT, width := GUIDE_WIDTH) -> void:
	canvas.draw_line(from, to, colour, width, true)


## Starts (or restarts) a module's tutorial over the live board. Steps are
## content — data/minigame_tutorials.json — so a writer can reword the
## teaching without opening a scene script (law 9).
static func start_tutorial(root: Control, steps: Array, resolver: Callable,
		previous: Coach = null) -> Coach:
	if previous != null and is_instance_valid(previous):
		previous.queue_free()
	if steps.is_empty():
		return null
	var coach := Coach.new(steps, resolver)
	root.add_child(coach)
	return coach


## The outcome card. Failure is a story outcome, never a game-over, so all
## three endings get the same treatment: what happened, the prose, one way on.
##
## Shown after a beat, not instantly: a seam that closes wants to be SEEN
## closing before a dialog covers it (owner: "when a legal solution is
## presented, nothing happens" — half of that was the check, half was that
## the reward for finishing was a grey overlay arriving in the same frame).
static func show_outcome(root: Control, outcome: int, data: Dictionary,
		on_done: Callable) -> void:
	var modal := UITheme.modal(root, 520.0)
	var box: VBoxContainer = modal["box"]
	var heading := UITheme.measured_label(
		_outcome_heading(outcome), 40, 488.0, UITheme.display_font())
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var prose := String(data.get("when_outcome", {}).get(
		Minigame.outcome_key(outcome), ""))
	if prose != "":
		var line := UITheme.measured_label(prose, 26, 488.0, UITheme.italic_font())
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(line)
	var onward := UITheme.amber_button(Strings.line("minigames.onward"), 32)
	onward.pressed.connect(on_done)
	box.add_child(onward)
	UITheme.open_modal(modal["overlay"], modal["panel"])


static func _outcome_heading(outcome: int) -> String:
	var key := Minigame.outcome_key(outcome)
	return "" if key == "" else Strings.line("minigames.outcome." + key)


## A one-thing-to-say card over a live board: the seam that answers every
## number and still is not one loop, and anything else the board can be
## RIGHT about and still not finished. Frees itself on dismissal, so a board
## may raise as many of these as the puzzle earns.
static func notice(root: Control, heading: String, body: String) -> void:
	var modal := UITheme.modal(root, 500.0)
	var overlay: Control = modal["overlay"]
	var panel: Control = modal["panel"]
	var box: VBoxContainer = modal["box"]
	var title := UITheme.measured_label(heading, 36, 468.0, UITheme.display_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var line := UITheme.measured_label(body, UITheme.TYPE_BODY, 468.0,
		UITheme.body_font(), UITheme.INK)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	var close := func() -> void:
		UITheme.close_modal(overlay, panel)
		overlay.queue_free()
	var onward := UITheme.amber_button(Strings.line("minigames.back_to_it"), 32)
	onward.pressed.connect(close)
	box.add_child(onward)
	# Law 7: a dim-tap gets out too, never the button alone.
	UITheme.modal_escape(modal, close)
	UITheme.open_modal(overlay, panel)


## The spool close-up, shared with the battle screen's (owner 2026-08-10:
## "I should be able to click on the spool to see how many of each energy I
## still have left"). A crossing is the same question with the storm asking
## it — "will I make it?" is a deck-contents question, and the owner asked
## for the answer here too (2026-08-13).
static func spool_popup(root: Control, catalog: Catalog, deck: Array,
		hand: Array) -> void:
	var modal := UITheme.modal(root, 560.0)
	var overlay: Control = modal["overlay"]
	var panel: Control = modal["panel"]
	var box: VBoxContainer = modal["box"]
	var wrap := 528.0
	var title := UITheme.measured_label(Strings.line("battle.spool.title"), 36,
		wrap, UITheme.display_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UITheme.measured_label(Strings.line("minigames.spool.blurb"),
		UITheme.TYPE_SUPPORT, wrap, UITheme.italic_font(), UITheme.INK_SOFT))
	for humour in Catalog.HUMOURS:
		box.add_child(_spool_row(catalog, String(humour), deck, hand))
	var total := UITheme.measured_label(
		Strings.line("minigames.spool.total", [deck.size(), hand.size()]),
		UITheme.TYPE_SUPPORT, wrap, UITheme.body_font(), UITheme.INK_SOFT)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(total)
	var close := func() -> void:
		UITheme.close_modal(overlay, panel)
		overlay.queue_free()
	var onward := UITheme.amber_button(Strings.line("minigames.back_to_it"), 32)
	onward.pressed.connect(close)
	box.add_child(onward)
	UITheme.modal_escape(modal, close)
	UITheme.open_modal(overlay, panel)


## One humour's row: how many are still wound on, and how many are in the paw
## right now. Both numbers, because on a crossing the paw is the thing that
## trips you and the spool is the thing that carries you.
static func _spool_row(catalog: Catalog, humour: String, deck: Array,
		hand: Array) -> Control:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UITheme.panel_stylebox(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	row.add_child(UITheme.icon(String(UITheme.HUMOUR_GLYPH.get(humour, "")), 44.0))
	var humour_colour: Color = UITheme.HUMOUR_COLORS.get(humour, UITheme.INK)
	var name_label := UITheme.measured_label(Catalog.humour_name(humour),
		UITheme.TYPE_BODY, 220.0, UITheme.display_font(), humour_colour)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_FILL
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var in_deck := _count_humour(catalog, deck, humour)
	var in_hand := _count_humour(catalog, hand, humour)
	var counts := UITheme.measured_label(
		Strings.line("minigames.spool.count", [in_deck, in_hand]),
		UITheme.TYPE_SUPPORT, 230.0, UITheme.body_font(),
		UITheme.INK if in_deck + in_hand > 0 else UITheme.INK_FADED)
	counts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	counts.size_flags_vertical = Control.SIZE_FILL
	counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(counts)
	return plate


static func _count_humour(catalog: Catalog, cards: Array, humour: String) -> int:
	var count := 0
	for card_id in cards:
		if String(catalog.energy_cards.get(card_id, {}).get("humour", "")) == humour:
			count += 1
	return count


## A pip row (patience, paws, alarm) drawn as filled and empty circles.
class PipRow extends Control:
	var filled := 0
	var total := 0
	var fill_color := Color("8c2f24")

	func set_pips(p_filled: int, p_total: int) -> void:
		filled = p_filled
		total = p_total
		queue_redraw()

	func _draw() -> void:
		for i in total:
			var centre := Vector2(14 + i * 34, size.y * 0.5)
			if i < filled:
				draw_circle(centre, 12.0, fill_color)
			else:
				draw_arc(centre, 12.0, 0, TAU, 24, Color("a99c82"), 2.5)


## An invisible rect over a DRAWN board feature, so the tutorial can point at
## a clue, a thread or a patch that is not a Control. Mouse-transparent: an
## action step's cutout has to reach the canvas underneath it.
class Marker extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Places the marker over `rect` in the coordinate space of its parent.
	func cover(rect: Rect2) -> void:
		position = rect.position
		size = rect.size
		visible = true
