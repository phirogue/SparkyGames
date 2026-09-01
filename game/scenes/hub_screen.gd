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
## 96 + 576 + 300 + 96 = 1068, plus 3 x 12 separation = 1104.
## The footer (latest deed, 20px type) is GONE — owner 2026-08-09: "way too
## small and serves no purpose"; its height went to the board and the status.
const SEPARATION := 12
const ZONE_HEADER := 96
const ZONE_BOARD := 576
const ZONE_DOORS := 300
const ZONE_STATUS := 96

const NOTE_INSET := 10.0   # keeps a rotated note's corners off the page edge
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
## The note carries the quest's NAME only, large (owner 2026-08-09: the
## board-card text was unreadably small pinned up; the popup owns it now).
const NOTE_TITLE_SIZE := 34

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

## The one-time chapter-close card (see _maybe_show_ending).
const EndingScreen := preload("res://scenes/ending_screen.gd")

var catalog: Catalog
var profile: Dictionary
var tracker: AchievementTracker

var _gleam_label: Label
var _board: VBoxContainer
var _doors: GridContainer
var _status: HBoxContainer
var _purse: HBoxContainer
var _note_modal: Dictionary = {}
var _note_box: VBoxContainer
var _ending: Control = null

## First-visit walkthrough of the room, using the same Coach the tutorial
## fights use. Steps come from story/prologue/interludes.json (mantel_coach)
## so the words stay content.
var coach_steps: Array = []
var coach: Coach = null


func setup(p_catalog: Catalog, p_profile: Dictionary, p_tracker: AchievementTracker,
		p_coach: Array = []) -> void:
	catalog = p_catalog
	profile = p_profile
	tracker = p_tracker
	coach_steps = p_coach


func _ready() -> void:
	# FULL-BLEED room (owner 2026-08-09): no stitched page, no parchment
	# border — the parlor is the whole screen. Content still lays out inside
	# the same calibrated margins, so every plate keeps its size and the zone
	# template stays honest.
	add_child(_room())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.name = "PageContent"
	margin.add_theme_constant_override("margin_left", UITheme.PAGE_MARGIN_LEFT)
	margin.add_theme_constant_override("margin_right", UITheme.PAGE_MARGIN_RIGHT)
	margin.add_theme_constant_override("margin_top", UITheme.PAGE_MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", UITheme.PAGE_MARGIN_BOTTOM)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)
	_build_header(column)
	_build_board(column)
	_build_doors(column)
	_build_status(column)
	_build_note_modal()
	refresh()
	if not coach_steps.is_empty():
		coach = Coach.new(coach_steps, _coach_target)
		add_child(coach)
	_maybe_show_ending()


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
	return null


## The parlor itself: the empty-mantel illustration stretched to the WHOLE
## screen (owner 2026-08-09), dimmed and warmed so it reads as a room at
## night rather than competing with the notes pinned on it. The clipping
## window is the full viewport now — COVER's overflow still needs a clipping
## parent (law 3: a TextureRect only clips when its parent clips).
func _room() -> Control:
	var window := Control.new()
	window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := UITheme.art_or_placeholder("bg_mantel_scene",
		"the parlor: bare mantel, cold hearth, two lamps")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.modulate = Color(0.72, 0.68, 0.62)
	window.add_child(art)
	return window


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
	# What each door is CALLED lives in story/interface.json (law 20) — the
	# same lines were duplicated here as literals until 2026-08-08, and the
	# copies drifted the day the Exchange stopped cutting cards.
	if open.get("case_board", false):
		_doors.add_child(_door(Strings.lines("mantel.doors.case_board")[0],
			Strings.lines("mantel.doors.case_board")[1],
			"ui/ui_needle_pin", func() -> void: open_case_board.emit()))
	if open.get("exchange", false):
		_doors.add_child(_door(Strings.lines("mantel.doors.exchange")[0],
			Strings.lines("mantel.doors.exchange")[1],
			"ui/ui_button_pile", func() -> void: open_exchange.emit()))
	if open.get("loadout", false):
		_doors.add_child(_door(Strings.lines("mantel.doors.loadout")[0],
			Strings.lines("mantel.doors.loadout")[1],
			"ui/ui_paw_full", func() -> void: open_loadout.emit()))
	if open.get("casebook", false):
		_doors.add_child(_door(Strings.lines("mantel.doors.casebook")[0],
			Strings.lines("mantel.doors.casebook")[1],
			"ui/ui_medallions", func() -> void: open_journal.emit()))


## The readouts sit on their OWN PLATE, not straight on the room (owner
## 2026-08-05: "the health, spool and deeds blend into the background image").
## Cream ink on a lamplit painting of a parlor is unreadable at any size —
## the numbers that tell you whether you can survive tonight cannot be a
## thing you squint for.
func _build_status(column: VBoxContainer) -> void:
	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(0, ZONE_STATUS)
	plate.add_theme_stylebox_override("panel", UITheme.panel_stylebox(6))
	column.add_child(plate)
	_status = HBoxContainer.new()
	_status.add_theme_constant_override("separation", SEPARATION)
	plate.add_child(_status)


# The footer (the latest deed at 20px) is gone — owner 2026-08-09. The
# chronicle already owns that history in the Casebook; the replay_prologue
# signal stays for the dev menu, which is where that belongs.


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
	# One word per chip (owner 2026-08-09 type pass): a caption that has to
	# wrap at readable size is a caption saying too much.
	_status.add_child(_chip("ui/ui_heart_full", "%d" % int(profile["max_hp"]),
		Strings.line("mantel.lives")))
	_status.add_child(_chip("ui/ui_spool", "%d" % profile["deck"].size(),
		Strings.line("mantel.spool")))
	var visible_total := 0
	for id in catalog.achievements:
		if not catalog.achievements[id].get("hidden", false) or tracker.is_unlocked(id):
			visible_total += 1
	# The deeds count answers taps (owner 2026-08-10: "I should have a way to
	# see my deeds") — straight to the Casebook, which opens on Deeds. Wrapped
	# in a PanelContainer so the tap layer stretches over the whole chip.
	var deeds_chip := _chip("ui/ui_medallions",
		"%d/%d" % [tracker.unlocked.size(), visible_total],
		Strings.line("mantel.deeds"))
	var deeds_wrap := PanelContainer.new()
	deeds_wrap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	deeds_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deeds_wrap.add_child(deeds_chip)
	UITheme.tap_layer(deeds_wrap).pressed.connect(
		func() -> void: open_journal.emit())
	_status.add_child(deeds_wrap)


## A quest note: torn parchment, a brass needle through the top, a wax seal
## for its kind, and the quest's NAME — nothing else. The board card waits in
## the popup, where it can be read at size (owner 2026-08-09).
func _note(quest: Dictionary) -> Control:
	var quest_id := String(quest["id"])
	var note := Panel.new()
	# Law 2: the note is sized from the MEASURED text, not from a guess.
	# NOTE_HEIGHT is a floor, not a ceiling — the board scrolls, so a tall
	# note costs nothing (law 12: this zone takes whatever is pinned).
	var wrap := NOTE_WIDTH - NOTE_PAD_LEFT - NOTE_PAD_RIGHT
	var text_height := UITheme.measure_text(String(quest["name"]),
		UITheme.display_font(), NOTE_TITLE_SIZE, wrap).y
	var height := maxf(NOTE_HEIGHT, text_height + NOTE_PAD_TOP + NOTE_PAD_BOTTOM)
	note.custom_minimum_size = Vector2(NOTE_WIDTH, height)
	note.add_theme_stylebox_override("panel", UITheme.row_stylebox())
	# Deterministic tilt: hand-pinned to look at, identical every launch to
	# test against. Two notes never share an angle because the id feeds it.
	note.pivot_offset = Vector2(NOTE_WIDTH, height) / 2.0
	note.rotation_degrees = NOTE_TILT * (1.0 if quest_id.hash() % 2 == 0 else -1.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = NOTE_PAD_LEFT
	box.offset_right = -NOTE_PAD_RIGHT
	box.offset_top = NOTE_PAD_TOP
	box.offset_bottom = -NOTE_PAD_BOTTOM
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(box)
	box.add_child(UITheme.measured_label(String(quest["name"]), NOTE_TITLE_SIZE,
		wrap, UITheme.display_font()))
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
	UITheme.tap_layer(note).pressed.connect(_open_note.bind(quest))
	return note


# ------------------------------------------------------------ the note, read

## Taking a note off the chimney breast to READ it (owner 2026-08-08): the
## quest's name, seal and board card open large, and the night only starts if
## Elspeth's cat decides it does. Backing out costs nothing — the board is a
## board of choices, not a row of triggers.
func _build_note_modal() -> void:
	_note_modal = UITheme.modal(self, 520.0)
	UITheme.modal_escape(_note_modal, _close_note)
	_note_box = _note_modal["box"]


func _open_note(quest: Dictionary) -> void:
	var quest_id := String(quest["id"])
	_clear(_note_box)
	var wrap := 488.0
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_note_box.add_child(head)
	var seal := UITheme.icon(_seal_for(quest), 68.0)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(seal)
	var name_label := UITheme.measured_label(String(quest["name"]), 32,
		wrap - 80.0, UITheme.display_font())
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_FILL
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	_note_box.add_child(UITheme.measured_label(
		String(quest.get("board_card", "")), 26, wrap, UITheme.italic_font(),
		UITheme.INK_SOFT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_note_box.add_child(row)
	var back := UITheme.dark_button(Strings.line("mantel.quest_note.back"), 24,
		Vector2(0, UITheme.BUTTON_HEIGHT))
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_close_note)
	row.add_child(back)
	var take := UITheme.amber_button(Strings.line("mantel.quest_note.take"), 26)
	take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	take.pressed.connect(func() -> void: quest_selected.emit(quest_id))
	row.add_child(take)
	UITheme.open_modal(_note_modal["overlay"], _note_modal["panel"])


func _close_note() -> void:
	UITheme.close_modal(_note_modal["overlay"], _note_modal["panel"])


## An empty board still has to say something — a blank zone reads as a bug.
## And a board emptied by FINISHING the chapter must not read as a quiet
## night: the closed-case line says the file is done and the city goes on.
func _bare_note() -> Control:
	var text := Strings.line("mantel.board_closed"
		if CaseState.case_closed(catalog, profile) else "mantel.board_empty")
	var wrap := NOTE_WIDTH - 68.0
	# Law 4: the closed-case line runs longer than the quiet-night one, so the
	# note grows to the measured text instead of clipping it (same sum as
	# _note above; the board scrolls, so height costs nothing).
	var height := maxf(NOTE_HEIGHT,
		UITheme.measure_text(text, UITheme.italic_font(), 24, wrap).y + 48.0)
	var note := Panel.new()
	note.custom_minimum_size = Vector2(NOTE_WIDTH, height)
	note.add_theme_stylebox_override("panel", UITheme.row_stylebox(
		Color(1, 1, 1, 0.6)))
	var label := UITheme.measured_label(text, 24, wrap,
		UITheme.italic_font(), UITheme.INK_SOFT)
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
	text.add_child(UITheme.measured_label(blurb, 22, wrap,
		UITheme.body_font(), UITheme.INK_SOFT))
	UITheme.tap_layer(plate).pressed.connect(on_pressed)
	return plate


## One reading off the mantel: an object, its number, and what it counts.
func _chip(icon_id: String, value: String, caption: String) -> Control:
	var chip := HBoxContainer.new()
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
	# INK, not the room's cream: this chip is on a parchment plate now.
	text.add_child(UITheme.measured_label(value, 34, 120.0,
		UITheme.display_font(), UITheme.INK))
	text.add_child(UITheme.measured_label(caption, 22, 120.0,
		UITheme.body_font(), UITheme.INK_SOFT))
	return chip


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


# ------------------------------------------------------------- chapter close

## The one-time chapter-close card (owner: every choice needs a consequence —
## a case that closes must SAY so). Shown by the Mantel because the Mantel is
## where a finished case lands the player; the card itself is a dumb page
## (ending_screen.gd). The flag is set the moment the card opens, and
## persisted through the same profile_changed channel every other hub change
## uses, so a quit mid-card cannot replay the ending forever.
func _maybe_show_ending() -> void:
	if _ending != null:
		return
	if bool(profile.get("ending_seen", false)):
		return
	if not CaseState.case_closed(catalog, profile):
		return
	profile["ending_seen"] = true
	profile_changed.emit()
	var ending: Control = EndingScreen.new()
	ending.setup(catalog)
	ending.closed.connect(_close_ending)
	add_child(ending)
	ending.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ending = ending


func _close_ending() -> void:
	if _ending == null:
		return
	_ending.queue_free()
	_ending = null
	# The card played the score's one non-looping track; the parlor takes its
	# own bed back on the way out.
	EndingScreen.play_screen_music(self, catalog, "hub")
