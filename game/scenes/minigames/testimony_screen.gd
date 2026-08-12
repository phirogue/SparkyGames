extends Control
## Testimony board, at the battle screen's standard (owner 2026-08-11).
##
## The witness is the opponent, so the witness gets the opponent's treatment:
## their portrait in the battle's wood frame at the top of the board, with
## what they just said beside it — the reply reads as coming FROM someone.
## Statements are stitched ribbon bands (ui_ribbon_band); a new ribbon
## settles in the way a drawn card does, and spent patience pulses the pips
## it came off.
##
## Tap a ribbon to PRESS it. To PRESENT, pick an evidence chip from the strip
## along the bottom first, then tap the ribbon it contradicts. A ribbon only
## shows its loose thread once the player actually holds the evidence that
## disproves it — the fair-play rule, drawn.

signal closed

## The witness band across the top of the board: the framed portrait plus
## the reply beside it.
const WITNESS_BAND := 196.0
const PORTRAIT_SIZE := Vector2(158.0, 188.0)

var state: TestimonyState
var testimony: Dictionary = {}
var coach_steps: Array = []
var coach_auto := false
var coach: Coach = null

var _board: Control
var _help: Button
var _markers: Dictionary = {}
var _scroll: ScrollContainer
var _finished := false
var _status: Label
var _ribbon_box: VBoxContainer
var _evidence_row: HFlowContainer
var _patience_row: MinigameShell.PipRow
var _said: Label
var _selected_evidence := ""
var _catalog: Catalog
## Last-refresh snapshots, so feedback can tell what CHANGED (the battle's
## hand-diff pattern): a new ribbon settles, spent patience pulses.
var _prev_visible: Array = []
var _prev_patience := -1


func setup(catalog: Catalog, testimony_data: Dictionary, held: Array) -> void:
	_catalog = catalog
	testimony = testimony_data
	state = TestimonyState.create(testimony_data, held)


func _ready() -> void:
	var witness_name := String(testimony.get("witness", {}).get("name", "A Witness"))
	var shell := MinigameShell.build(self, witness_name,
		func() -> void: closed.emit())
	_status = shell["status"]
	_board = shell["board"]
	_help = shell["help"]

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	shell["board"].add_child(column)

	# The witness, framed the way the battle frames its opponent, with their
	# last reply beside the portrait — an answer comes from a face.
	var witness_row := HBoxContainer.new()
	witness_row.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH, WITNESS_BAND)
	witness_row.add_theme_constant_override("separation", 12)
	column.add_child(witness_row)
	var portrait := _framed_witness(
		String(testimony.get("witness", {}).get("art", "")), witness_name)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	witness_row.add_child(portrait)
	_said = UITheme.measured_label("", 24, _said_wrap(),
		UITheme.italic_font(), UITheme.INK_SOFT)
	_said.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_said.size_flags_vertical = Control.SIZE_FILL
	_said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	witness_row.add_child(_said)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH, 320)
	column.add_child(scroll)
	_scroll = scroll
	_ribbon_box = VBoxContainer.new()
	_ribbon_box.add_theme_constant_override("separation", 10)
	_ribbon_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_ribbon_box)

	var strip_title := UITheme.measured_label(
		Strings.line("minigames.testimony.casebook"),
		UITheme.TYPE_FLOOR, UITheme.CONTENT_WIDTH, UITheme.smallcaps_font(),
		UITheme.INK_SOFT)
	column.add_child(strip_title)
	_evidence_row = HFlowContainer.new()
	_evidence_row.add_theme_constant_override("h_separation", 6)
	_evidence_row.add_theme_constant_override("v_separation", 6)
	column.add_child(_evidence_row)

	var row := MinigameShell.action_row(shell["actions"])
	_patience_row = MinigameShell.PipRow.new()
	_patience_row.custom_minimum_size = Vector2(200, MinigameShell.ACTION_HEIGHT)
	row.add_child(_patience_row)
	var leave := MinigameShell.leave_button(Strings.line("minigames.testimony.leave"))
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func() -> void:
		state.do_command({"type": "leave"})
		_finish())
	row.add_child(leave)

	for key in ["ribbons", "casebook", "patience"]:
		var marker := MinigameShell.Marker.new()
		_board.add_child(marker)
		_markers[key] = marker

	_help.pressed.connect(_start_tutorial)
	_help.visible = not coach_steps.is_empty()
	_refresh()
	if coach_auto:
		_start_tutorial()


func _said_wrap() -> float:
	return UITheme.CONTENT_WIDTH - PORTRAIT_SIZE.x - 12.0


## The battle's framed portrait, on the witness: art windowed to the frame's
## MEASURED aperture (law 22 — the frame's geometry is never trusted).
func _framed_witness(image_id: String, description: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = PORTRAIT_SIZE
	holder.size = PORTRAIT_SIZE
	var art := UITheme.art_or_placeholder(image_id, description)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	var frame := UITheme.tex("ui/ui_frame_portrait")
	if frame != null:
		var opaque := UITheme.content_region(frame, "ui/ui_frame_portrait")
		var aperture := UITheme.frame_aperture("ui/ui_frame_portrait")
		var sx := PORTRAIT_SIZE.x / opaque.size.x
		var sy := PORTRAIT_SIZE.y / opaque.size.y
		var tuck := 4.0
		art.set_offset(SIDE_LEFT, (aperture.position.x - opaque.position.x) * sx - tuck)
		art.set_offset(SIDE_TOP, (aperture.position.y - opaque.position.y) * sy - tuck)
		art.set_offset(SIDE_RIGHT, -(opaque.end.x - aperture.end.x) * sx + tuck)
		art.set_offset(SIDE_BOTTOM, -(opaque.end.y - aperture.end.y) * sy + tuck)
	if art is TextureRect:
		art.clip_contents = true
	holder.add_child(art)
	if frame != null:
		var frame_rect := TextureRect.new()
		frame_rect.texture = UITheme.cropped_tex("ui/ui_frame_portrait")
		frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_rect.stretch_mode = TextureRect.STRETCH_SCALE
		frame_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(frame_rect)
	return holder


## A ribbon's dress: the stitched fabric band, stretched by its margins so a
## two-line statement and a one-liner wear the same cloth.
func _ribbon_stylebox() -> StyleBox:
	var texture := UITheme.tex("ui/ui_ribbon_band")
	if texture == null:
		return UITheme.panel_stylebox(10)
	var box := StyleBoxTexture.new()
	box.texture = texture
	# Wide side margins keep the frayed ends and the stitched corners from
	# stretching; the middle of the band tiles the weave.
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		box.set_texture_margin(side, 48)
		box.set_content_margin(side, 30)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		box.set_texture_margin(side, 34)
		box.set_content_margin(side, 20)
	return box


func _start_tutorial() -> void:
	coach = MinigameShell.start_tutorial(self, coach_steps, _coach_target, coach)


func _coach_target(key: String) -> Control:
	match key:
		"board": return _board
		"board:patience": return _patience_row
		"board:ribbons": return _cover("ribbons", _scroll)
		"board:casebook": return _cover("casebook", _evidence_row)
	return null


## Points at a live container by copying its rect — the marker is a child of
## the board, so a container that scrolls or reflows stays covered.
func _cover(key: String, over: Control) -> Control:
	var marker: MinigameShell.Marker = _markers[key]
	marker.cover(Rect2(over.global_position - _board.global_position,
		over.size).grow(6.0))
	return marker


func _refresh() -> void:
	_status.text = Strings.line("minigames.testimony.status",
		[state.visible.size(), state.patience])
	# Spent patience pulses the pips it came off — the cost is FELT, not
	# only recounted (the battle's rule for numbers that change).
	if state.patience < _prev_patience:
		UITheme.pulse(_patience_row, 1.25)
	_prev_patience = state.patience
	_patience_row.set_pips(state.patience, int(testimony.get("patience", 3)))

	for child in _ribbon_box.get_children():
		_ribbon_box.remove_child(child)
		child.queue_free()
	for ribbon_id in state.visible:
		var ribbon: Dictionary = state.ribbons[ribbon_id]
		var plate := Button.new()
		plate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		plate.add_theme_font_size_override("font_size", 24)
		plate.add_theme_color_override("font_color", UITheme.INK)
		plate.add_theme_color_override("font_hover_color", UITheme.INK)
		plate.add_theme_color_override("font_pressed_color", UITheme.INK)
		# The statement wears cloth: the stitched ribbon band, stretched by
		# its margins so long and short statements wear the same weave.
		for style_state in ["normal", "hover", "pressed", "focus"]:
			plate.add_theme_stylebox_override(style_state, _ribbon_stylebox())
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var marks := ""
		if state.is_shimmering(ribbon_id):
			marks += "  ❋"                      # a thread that will not hold
		if state.pressed.has(ribbon_id):
			marks += "  (pressed)"
		plate.text = String(ribbon.get("text", "")) + marks
		plate.custom_minimum_size = Vector2(0, UITheme.measure_text(
			plate.text, UITheme.body_font(), 24,
			UITheme.CONTENT_WIDTH - 72).y + 48)
		plate.pressed.connect(_on_ribbon.bind(ribbon_id))
		_ribbon_box.add_child(plate)
		# A statement the witness just added settles in like a drawn card.
		if not _prev_visible.has(ribbon_id) and not _prev_visible.is_empty():
			UITheme.settle(plate)
	_prev_visible = state.visible.duplicate()

	for child in _evidence_row.get_children():
		_evidence_row.remove_child(child)
		child.queue_free()
	for evidence_id in state.held_evidence():
		var chip := Button.new()
		chip.toggle_mode = true
		chip.button_pressed = _selected_evidence == evidence_id
		chip.custom_minimum_size = Vector2(0, 52)
		chip.add_theme_font_size_override("font_size", 22)
		chip.text = _evidence_name(String(evidence_id))
		chip.pressed.connect(func() -> void:
			_selected_evidence = "" if _selected_evidence == evidence_id else String(evidence_id)
			_refresh())
		_evidence_row.add_child(chip)

	if Minigame.is_over(state.outcome):
		_finish()


func _evidence_name(evidence_id: String) -> String:
	for case_id in _catalog.cases:
		for entry in _catalog.cases[case_id].get("evidence", []):
			if String(entry["id"]) == evidence_id:
				return String(entry["name"])
	return evidence_id


func _on_ribbon(ribbon_id: String) -> void:
	if Minigame.is_over(state.outcome):
		return
	var result: Dictionary
	if _selected_evidence != "":
		result = state.do_command({"type": "present", "ribbon": ribbon_id,
			"evidence": _selected_evidence})
		_selected_evidence = ""
	else:
		result = state.do_command({"type": "press", "ribbon": ribbon_id})
	var said := String(result.get("said", ""))
	_said.text = said if said != "" else String(result.get("error", ""))
	_said.custom_minimum_size = Vector2(_said_wrap(), UITheme.measure_text(
		_said.text, UITheme.italic_font(), 24, _said_wrap()).y)
	_refresh()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if coach != null and is_instance_valid(coach):
		coach.queue_free()
	MinigameShell.show_outcome(self, state.outcome, testimony,
		func() -> void: closed.emit())
