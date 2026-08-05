extends Control
## The Mantel — Elspeth's parlor, and the two taps between one prowl and the
## next. Built to reference/the mantle - v2.jpg: the room is a real place
## (bg_mantel_scene, generated empty for exactly this), quests are notes
## pinned to the chimney breast with a needle and a wax seal, and gleam is a
## pile of buttons rather than a number in a label.
##
## The shop and the loadout picker moved OUT to their own screens
## (exchange_screen.gd, loadout_screen.gd) — the Mantel's job is to be a
## room you cross, not a control panel. See docs/design/ui-screens.md.

signal quest_selected(quest_id: String)
signal profile_changed
signal replay_prologue
signal open_journal
signal open_case_board
signal open_exchange
signal open_loadout

## FIXED zone template (law 12): heights + separations == CONTENT_HEIGHT.
## 96 + 518 + 268 + 86 + 88 = 1056, plus 4 x 12 separation = 1104.
const SEPARATION := 12
const ZONE_HEADER := 96
const ZONE_BOARD := 518
const ZONE_DOORS := 268
const ZONE_STATUS := 86
const ZONE_FOOTER := 88

const NOTE_INSET := 10.0   # keeps a rotated note's corners off the stitching
const NOTE_WIDTH := UITheme.CONTENT_WIDTH - NOTE_INSET * 2
const NOTE_HEIGHT := 152.0
const NOTE_SEPARATION := 6
const NOTE_TILT := 1.4     # degrees; hand-pinned, not laid out
## Text is inset to the plate's INK DASHES, not to its rect. Measured off the
## texture (the dashes run 22px in from the top and 25 from the bottom, the
## sprigs hold the outer 120px): laid out to the rect, the quest name crossed
## the top dash and the board card fell out of the bottom of the note. Three
## notes at this height fill the board zone with 13px to spare.
const NOTE_PAD_TOP := 40.0
const NOTE_PAD_BOTTOM := 34.0
## The plate's printed leaf sprigs own the outer 120px of each end. Text that
## started at 34 ran through the left one; the seal now sits in that band
## instead, which is what it is for — a stamp on the corner of the paper.
const NOTE_PAD_LEFT := 124.0
## The plate is symmetric: there is a sprig at BOTH ends. Only the left pad
## allowed for one, so every board card ran its last words in behind the
## right-hand leaves (owner tour, 2026-08-04). Matching the pads costs wrap
## width, which the measured note height now absorbs.
const NOTE_PAD_RIGHT := 118.0
const NOTE_TITLE_SIZE := 24
const NOTE_BODY_SIZE := 18

const DOOR_COLUMNS := 2
const DOOR_WIDTH := (UITheme.CONTENT_WIDTH - SEPARATION) / DOOR_COLUMNS  # 285
const DOOR_HEIGHT := (ZONE_DOORS - SEPARATION) / 2.0                     # 144

## Text sits on a dark room here, not on parchment: the plates keep ink, the
## room's own labels go cream (they are lit by the lamps in the picture).
const ROOM_TEXT := Color("efe0c2")
const ROOM_TEXT_SOFT := Color("cbb894")

## The wax seal reads the quest's kind before a word is read: the case's own
## work is sealed red, a guild's blue, everything else gold.
const SEAL_CORE := "ui/ui_seal_red"
const SEAL_GUILD := "ui/ui_seal_blue"
const SEAL_SIDE := "ui/ui_seal_gold"

var catalog: Catalog
var profile: Dictionary
var tracker: AchievementTracker

var _gleam_label: Label
var _board: VBoxContainer
var _doors: GridContainer
var _status: HBoxContainer
var _purse: HBoxContainer
var _deed_label: Label
var _footer: HBoxContainer

## First-visit walkthrough of the room, using the same Coach the tutorial
## fights use. Steps come from story/prologue.json so the words stay content.
var coach_steps: Array = []
var coach: Coach = null


func setup(p_catalog: Catalog, p_profile: Dictionary, p_tracker: AchievementTracker,
		p_coach: Array = []) -> void:
	catalog = p_catalog
	profile = p_profile
	tracker = p_tracker
	coach_steps = p_coach


func _ready() -> void:
	# The room goes BETWEEN the stitched page and the content, so the page's
	# border still frames it and every plate still lands inside the margins.
	var margin := UITheme.page_scaffold(self, {"between": _room()})
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)
	_build_header(column)
	_build_board(column)
	_build_doors(column)
	_build_status(column)
	_build_footer(column)
	refresh()
	if not coach_steps.is_empty():
		coach = Coach.new(coach_steps, _coach_target)
		add_child(coach)


## Coach resolver: the room's parts, by name. An unknown key spotlights
## nothing, which the Coach reads as "this step is impossible" and lets any
## tap pass — so a step naming a door that is not open yet still advances.
func _coach_target(key: String) -> Control:
	match key:
		"board": return _board
		"note": return _board.get_child(0) if _board.get_child_count() > 0 else null
		"doors": return _doors
		"status": return _status
		"purse": return _purse
		"footer": return _footer
	return null


## The parlor itself: the empty-mantel illustration, dimmed and warmed so it
## reads as a room at night rather than competing with the notes pinned on it.
func _room() -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The picture is 3:4 and the hole is 582x1104, so COVER overflows it. A
	# TextureRect only clips when its PARENT clips, and the parent has to be
	# the margin box itself — clipping at the page would spill the overflow
	# across the stitching (law 3: read the geometry, don't hope).
	var window := Control.new()
	window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.offset_left = UITheme.PAGE_MARGIN_LEFT
	window.offset_top = UITheme.PAGE_MARGIN_TOP
	window.offset_right = -UITheme.PAGE_MARGIN_RIGHT
	window.offset_bottom = -UITheme.PAGE_MARGIN_BOTTOM
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(window)
	var art := UITheme.art_or_placeholder("bg_mantel_scene",
		"the parlor: bare mantel, cold hearth, two lamps")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.modulate = Color(0.72, 0.68, 0.62)
	window.add_child(art)
	return holder


# ------------------------------------------------------------------- zones

func _build_header(column: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, ZONE_HEADER)
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	var title := UITheme.measured_label("The Mantel", 48, 360.0,
		UITheme.display_font(), ROOM_TEXT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_FILL
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var purse := HBoxContainer.new()
	purse.add_theme_constant_override("separation", 4)
	purse.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(purse)
	_purse = purse
	purse.add_child(UITheme.icon("ui/ui_button_pile", 76.0))
	_gleam_label = UITheme.measured_label("0", 40, 110.0,
		UITheme.display_font(), ROOM_TEXT)
	_gleam_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gleam_label.size_flags_vertical = Control.SIZE_FILL
	purse.add_child(_gleam_label)


func _build_board(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_BOARD)
	holder.add_theme_constant_override("separation", 6)
	column.add_child(holder)
	holder.add_child(UITheme.measured_label("Pinned to the chimney breast", 24,
		UITheme.CONTENT_WIDTH, UITheme.smallcaps_font(), ROOM_TEXT_SOFT))
	# The board takes whatever the chapter puts on it, so it scrolls INSIDE
	# its zone rather than pushing the doors off the page (law 12).
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(scroll)
	_board = VBoxContainer.new()
	_board.add_theme_constant_override("separation", NOTE_SEPARATION)
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_board)


## The doors are EARNED, not furnished (owner rule 2026-08-04: the Mantel
## arrived fully appointed and read as a control panel). QuestGate.doors()
## owns which are open; a closed one is not drawn at all, so the room fills
## up as Ash learns the city. The grid is rebuilt on refresh() because
## finishing a prowl is exactly when a new door appears.
func _build_doors(column: VBoxContainer) -> void:
	_doors = GridContainer.new()
	_doors.custom_minimum_size = Vector2(0, ZONE_DOORS)
	_doors.columns = DOOR_COLUMNS
	_doors.add_theme_constant_override("h_separation", SEPARATION)
	_doors.add_theme_constant_override("v_separation", SEPARATION)
	column.add_child(_doors)


func _refresh_doors() -> void:
	_clear(_doors)
	var open := QuestGate.doors(profile)
	if open.get("case_board", false):
		_doors.add_child(_door("The Case Board", "Suspects, things, threads.",
			"ui/ui_needle_pin", func() -> void: open_case_board.emit()))
	if open.get("exchange", false):
		_doors.add_child(_door("The Magpie Exchange", "Brindle. Cards bought and cut.",
			"ui/ui_button_pile", func() -> void: open_exchange.emit()))
	if open.get("loadout", false):
		_doors.add_child(_door("On the Prowl", "What goes out with you.",
			"ui/ui_paw_full", func() -> void: open_loadout.emit()))
	if open.get("casebook", false):
		_doors.add_child(_door("The Casebook", "Deeds and knowledge.",
			"ui/ui_medallions", func() -> void: open_journal.emit()))


func _build_status(column: VBoxContainer) -> void:
	_status = HBoxContainer.new()
	_status.custom_minimum_size = Vector2(0, ZONE_STATUS)
	_status.add_theme_constant_override("separation", SEPARATION)
	column.add_child(_status)


func _build_footer(column: VBoxContainer) -> void:
	var footer := HBoxContainer.new()
	footer.custom_minimum_size = Vector2(0, ZONE_FOOTER)
	footer.add_theme_constant_override("separation", SEPARATION)
	column.add_child(footer)
	_footer = footer
	_deed_label = UITheme.measured_label("", 20, 300.0,
		UITheme.italic_font(), ROOM_TEXT_SOFT)
	_deed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_deed_label.size_flags_vertical = Control.SIZE_FILL
	_deed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_deed_label)
	var replay := UITheme.dark_button("Relive the worst night", 22,
		Vector2(260, 72))
	replay.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	replay.pressed.connect(func() -> void: replay_prologue.emit())
	footer.add_child(replay)


# ----------------------------------------------------------------- contents

func refresh() -> void:
	_gleam_label.text = "%d" % int(profile.get("gleam", 0))
	_clear(_board)
	# What is on the board is QuestGate's decision, not the hub's — one gating
	# rule that the tests and the scenario specs also call.
	var board := QuestGate.board(catalog, profile)
	if board.is_empty():
		_board.add_child(_bare_note())
	for quest: Dictionary in board:
		_board.add_child(_note(quest))
	_refresh_doors()
	_clear(_status)
	_status.add_child(_chip("ui/ui_heart_full", "%d" % int(profile["max_hp"]), "lives in him"))
	_status.add_child(_chip("ui/ui_spool", "%d" % profile["deck"].size(), "cards on the spool"))
	var visible_total := 0
	for id in catalog.achievements:
		if not catalog.achievements[id].get("hidden", false) or tracker.is_unlocked(id):
			visible_total += 1
	_status.add_child(_chip("ui/ui_medallions",
		"%d/%d" % [tracker.unlocked.size(), visible_total], "deeds recorded"))
	var journal: Array = profile.get("journal", [])
	_deed_label.text = String(journal.back()) if not journal.is_empty() \
		else "The thread runs out under the window."
	_deed_label.custom_minimum_size = Vector2(300.0, UITheme.measure_text(
		_deed_label.text, UITheme.italic_font(), 20, 300.0).y)


## A quest note: torn parchment, a brass needle through the top, a wax seal
## for its kind, and the board card in Elspeth's hand.
func _note(quest: Dictionary) -> Control:
	var quest_id := String(quest["id"])
	var note := Panel.new()
	# Law 2: the note is sized from the MEASURED text, not from a guess.
	# NOTE_HEIGHT is a floor, not a ceiling — pinned at exactly 152 the first
	# quest on the board lost the last line of its own board card, which is
	# the line that says what the job is. The board scrolls, so a tall note
	# costs nothing (law 12: this zone was built to take whatever is pinned).
	var wrap := NOTE_WIDTH - NOTE_PAD_LEFT - NOTE_PAD_RIGHT
	var text_height := UITheme.measure_text(String(quest["name"]),
			UITheme.display_font(), NOTE_TITLE_SIZE, wrap).y \
		+ UITheme.measure_text(String(quest.get("board_card", "")),
			UITheme.italic_font(), NOTE_BODY_SIZE, wrap).y + 2
	var height := maxf(NOTE_HEIGHT, text_height + NOTE_PAD_TOP + NOTE_PAD_BOTTOM)
	note.custom_minimum_size = Vector2(NOTE_WIDTH, height)
	note.add_theme_stylebox_override("panel", UITheme.row_stylebox())
	# Deterministic tilt: hand-pinned to look at, identical every launch to
	# test against. Two notes never share an angle because the id feeds it.
	note.pivot_offset = Vector2(NOTE_WIDTH, height) / 2.0
	note.rotation_degrees = NOTE_TILT * (1.0 if quest_id.hash() % 2 == 0 else -1.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = NOTE_PAD_LEFT
	box.offset_right = -NOTE_PAD_RIGHT
	box.offset_top = NOTE_PAD_TOP
	box.offset_bottom = -NOTE_PAD_BOTTOM
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(box)
	box.add_child(UITheme.measured_label(String(quest["name"]), NOTE_TITLE_SIZE,
		wrap, UITheme.display_font()))
	box.add_child(UITheme.measured_label(String(quest.get("board_card", "")),
		NOTE_BODY_SIZE, wrap, UITheme.italic_font(), UITheme.INK_SOFT))
	# The pin straddles the note's top edge in the clear band above the title
	# (NOTE_PAD_TOP). Hung lower, it landed across the first line of the name.
	var pin := UITheme.icon("ui/ui_needle_pin", 44.0)
	pin.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pin.offset_left = -22
	pin.offset_right = 22
	pin.offset_top = -12
	pin.offset_bottom = 32
	note.add_child(pin)
	var seal := UITheme.icon(_seal_for(quest), 68.0)
	seal.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	seal.offset_left = 28
	seal.offset_right = 96
	seal.offset_top = -34
	seal.offset_bottom = 34
	note.add_child(seal)
	UITheme.tap_layer(note).pressed.connect(
		func() -> void: quest_selected.emit(quest_id))
	return note


## An empty board still has to say something — a blank zone reads as a bug.
func _bare_note() -> Control:
	var note := Panel.new()
	note.custom_minimum_size = Vector2(NOTE_WIDTH, NOTE_HEIGHT)
	note.add_theme_stylebox_override("panel", UITheme.row_stylebox(
		Color(1, 1, 1, 0.6)))
	var label := UITheme.measured_label(
		"Nothing pinned tonight. The city is being quiet at you.", 24,
		NOTE_WIDTH - 68, UITheme.italic_font(), UITheme.INK_SOFT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 34
	label.offset_right = -34
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(label)
	return note


func _seal_for(quest: Dictionary) -> String:
	if String(quest.get("kind", "side")) == "core":
		return SEAL_CORE
	return SEAL_GUILD if String(quest.get("guild", "")) != "" else SEAL_SIDE


## A door out of the room: icon, name, and what is behind it.
func _door(name_text: String, blurb: String, icon_id: String,
		on_pressed: Callable) -> Control:
	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(DOOR_WIDTH, DOOR_HEIGHT)
	plate.add_theme_stylebox_override("panel", UITheme.panel_stylebox(10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	var icon := UITheme.icon(icon_id, 54.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var wrap := DOOR_WIDTH - 54 - 8 - 20
	text.add_child(UITheme.measured_label(name_text, 26, wrap,
		UITheme.display_font()))
	text.add_child(UITheme.measured_label(blurb, 19, wrap,
		UITheme.body_font(), UITheme.INK_SOFT))
	UITheme.tap_layer(plate).pressed.connect(on_pressed)
	return plate


## One reading off the mantel: an object, its number, and what it counts.
func _chip(icon_id: String, value: String, caption: String) -> Control:
	var chip := HBoxContainer.new()
	chip.custom_minimum_size = Vector2(0, ZONE_STATUS)
	chip.add_theme_constant_override("separation", 6)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := UITheme.icon(icon_id, 52.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_child(text)
	text.add_child(UITheme.measured_label(value, 30, 120.0,
		UITheme.display_font(), ROOM_TEXT))
	text.add_child(UITheme.measured_label(caption, 17, 120.0,
		UITheme.body_font(), ROOM_TEXT_SOFT))
	return chip


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
