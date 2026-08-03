extends Control
## Patch the Ward prototype board — geometry only (minigames.md #3).
##
## The ward is a grid of squares: sound cloth pale, the tear dark. Patches sit
## on a rack below, each stamped with the humour that pays for it. Pick a
## patch, tap a torn cell to lay it; Turn rotates. Each placement takes an
## energy card out of the hand for real — the mend is paid from the same
## stamina the fighting uses, which is the module's whole reason to exist.

signal closed

var state: WardState
var ward: Dictionary = {}

var _status: Label
var _board: Control
var _rack_row: HBoxContainer
var _selected := ""
var _rotation := 0
var _hand_label: Label


func setup(catalog: Catalog, ward_data: Dictionary, hand: Array) -> void:
	ward = ward_data
	state = WardState.create(catalog, ward_data, hand)


func _ready() -> void:
	var shell := MinigameShell.build(self, String(ward.get("name", "A Torn Ward")),
		func() -> void: closed.emit())
	_status = shell["status"]
	_board = shell["board"]

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	_board.add_child(column)

	var canvas := WardBoard.new()
	canvas.screen = self
	canvas.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH, 470)
	column.add_child(canvas)

	_hand_label = UITheme.measured_label("", 22, UITheme.CONTENT_WIDTH,
		UITheme.body_font(), UITheme.INK_SOFT)
	column.add_child(_hand_label)

	_rack_row = HBoxContainer.new()
	_rack_row.add_theme_constant_override("separation", 8)
	column.add_child(_rack_row)

	var turn := UITheme.dark_button("Turn it", 24, Vector2(170, 96))
	turn.pressed.connect(func() -> void:
		_rotation = (_rotation + 1) % 4
		_refresh())
	shell["actions"].add_child(turn)
	var finish := UITheme.amber_button("Done mending", 24, Vector2(230, 96))
	finish.pressed.connect(func() -> void:
		state.do_command({"type": "finish"})
		_finish())
	shell["actions"].add_child(finish)

	_build_rack()
	_refresh()


func _build_rack() -> void:
	for child in _rack_row.get_children():
		_rack_row.remove_child(child)
		child.queue_free()
	for patch in state.rack:
		var patch_id := String(patch["id"])
		var chip := Button.new()
		chip.toggle_mode = true
		chip.custom_minimum_size = Vector2(0, 74)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_size_override("font_size", 18)
		chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var down: bool = state.placed.has(patch_id)
		chip.disabled = down or not state.can_afford(patch_id)
		chip.button_pressed = _selected == patch_id
		chip.text = "%s\n%s%s" % [
			_shape_glyph(patch.get("shape", [])),
			Catalog.humour_name(String(patch.get("humour", ""))),
			"  (down)" if down else ""]
		chip.pressed.connect(func() -> void:
			_selected = patch_id
			_refresh())
		_rack_row.add_child(chip)


## A tiny ASCII footprint so the rack reads without art.
static func _shape_glyph(shape: Array) -> String:
	var rows := {}
	var max_row := 0
	var max_col := 0
	for offset in shape:
		max_row = maxi(max_row, int(offset[0]))
		max_col = maxi(max_col, int(offset[1]))
		rows["%d,%d" % [int(offset[0]), int(offset[1])]] = true
	var glyph := ""
	for r in max_row + 1:
		for c in max_col + 1:
			glyph += "■" if rows.has("%d,%d" % [r, c]) else " "
		if r < max_row:
			glyph += "\n"
	return glyph


func selected_patch() -> String:
	return _selected


func rotation() -> int:
	return _rotation


func on_cell_tap(row: int, col: int) -> void:
	if Minigame.is_over(state.outcome) or _selected == "":
		return
	state.do_command({"type": "place", "patch": _selected,
		"row": row, "col": col, "rotation": _rotation})
	_refresh()


func _refresh() -> void:
	var open: int = state.uncovered_cells().size()
	_status.text = "%d of %d torn cells still open   ·   %d cards left in paw" % [
		open, state.hole.size(), state.hand.size()]
	# Counts, not a list: a 15-card paw spelled out wrapped to three lines and
	# shoved the rack off the zone. What the player needs is "can I pay?".
	var counts := {}
	for card_id in state.hand:
		var humour := String(state._catalog.energy_cards.get(card_id, {}).get("humour", ""))
		counts[humour] = int(counts.get(humour, 0)) + 1
	var parts: Array[String] = []
	for humour in Catalog.HUMOURS:
		parts.append("%s %d" % [Catalog.humour_name(humour), int(counts.get(humour, 0))])
	_hand_label.text = "Paw: " + " · ".join(parts)
	_build_rack()
	for child in _board.get_children():
		for grandchild in child.get_children():
			if grandchild is Control:
				grandchild.queue_redraw()
	if Minigame.is_over(state.outcome):
		_finish()


func _finish() -> void:
	MinigameShell.show_outcome(self, state.outcome, ward,
		func() -> void: closed.emit())


class WardBoard extends Control:
	var screen
	var _step := 0.0
	var _origin := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var pressed: bool = (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
		if not pressed or _step <= 0.0:
			return
		var local: Vector2 = event.position - _origin
		var col := int(local.x / _step)
		var row := int(local.y / _step)
		var state: WardState = screen.state
		if row >= 0 and row < state.height and col >= 0 and col < state.width:
			screen.on_cell_tap(row, col)

	func _draw() -> void:
		var state: WardState = screen.state
		if state.width <= 0 or state.height <= 0:
			return
		_step = minf(size.x / state.width, size.y / state.height)
		var used := Vector2(_step * state.width, _step * state.height)
		_origin = (size - used) * 0.5
		var preview: String = screen.selected_patch()
		var preview_cells := {}
		# Colour-code each laid patch so the quilt reads as separate pieces.
		var patch_colours := ["#7a5233", "#3a5a7a", "#4a7a5a", "#7a4a6a", "#8a7a2a"]
		var colour_by_patch := {}
		var index := 0
		for patch in state.rack:
			colour_by_patch[String(patch["id"])] = Color(patch_colours[index % patch_colours.size()])
			index += 1
		for row in state.height:
			for col in state.width:
				var key := "%d,%d" % [row, col]
				var rect := Rect2(_origin + Vector2(col * _step, row * _step),
					Vector2(_step - 3.0, _step - 3.0))
				if state.covered.has(key):
					draw_rect(rect, colour_by_patch.get(state.covered[key], Color("7a5233")))
					draw_rect(rect, UITheme.INK, false, 2.0)
				elif state.hole.has(key):
					draw_rect(rect, MinigameShell.TORN)
				else:
					draw_rect(rect, MinigameShell.CLOTH)
					draw_rect(rect, Color("00000018"), false, 1.0)
		# Ghost of where the chosen patch would land, at the rotation shown.
		if preview != "":
			for row in state.height:
				for col in state.width:
					if not state.fits(preview, row, col, screen.rotation()):
						continue
					for cell in state.footprint(preview, row, col, screen.rotation()):
						preview_cells[cell] = true
					break
				if not preview_cells.is_empty():
					break
			for key in preview_cells:
				var parts := String(key).split(",")
				var rect := Rect2(_origin + Vector2(int(parts[1]) * _step,
					int(parts[0]) * _step), Vector2(_step - 3.0, _step - 3.0))
				draw_rect(rect, Color("e0913a55"))
