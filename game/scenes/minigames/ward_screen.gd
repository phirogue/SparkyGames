extends Control
## Patch the Ward prototype board — geometry only (minigames.md #3).
##
## The ward is a grid of squares: sound cloth pale, the tear dark. Patches sit
## on a rack below, each stamped with the humour that pays for it. Each
## placement takes an energy card out of the hand for real — the mend is paid
## from the same stamina the fighting uses, which is the module's whole reason
## to exist.
##
## DRAG AND DROP (owner 2026-08-09), not the old pick-then-tap: press a patch
## on the rack, carry it onto the cloth, let go. It lands where you dropped
## it. Patches may sit on top of each other and may hang over sound cloth —
## the rules stopped refusing sloppy placements, because the penalty is
## already the right one: only the squares still OPEN count against you.
##
## A tap still works as well as a drag. Tap a rack patch to pick it up, tap
## the cloth to lay it — the drag is the good way, but a modal interaction
## with exactly one way in is how players get stuck (law 7).

signal closed

## Board zone (720) split between the cloth and the rack beneath it.
const GRID_ZONE := 452.0
const PAW_ZONE := 42.0
const RACK_ZONE := 226.0
## How far a press may wander and still count as a tap rather than a drag.
const TAP_SLOP := 14.0

var state: WardState
var ward: Dictionary = {}
var coach_steps: Array = []
var coach_auto := false
var coach: Coach = null

var _status: Label
var _board: Control
var _canvas: WardBoard
var _help: Button
var _turn_button: Button
var _finish_button: Button
var _markers: Dictionary = {}
## The patch in the paw: picked up by pressing its rack tile, put down by
## releasing over the cloth. Also set by a plain tap, which is the fallback.
var _held := ""
var _rotation := 0
var _pointer := Vector2.ZERO
var _press_at := Vector2.ZERO
var _dragging := false
var _finished := false


func setup(catalog: Catalog, ward_data: Dictionary, hand: Array) -> void:
	ward = ward_data
	state = WardState.create(catalog, ward_data, hand)


func _ready() -> void:
	var shell := MinigameShell.build(self, String(ward.get("name", "")),
		func() -> void: closed.emit())
	_status = shell["status"]
	_board = shell["board"]
	_help = shell["help"]

	# The torn ward is CLOTH (owner 2026-08-11: boards at the battle's
	# standard): the frayed linen square fields the grid zone, and the drawn
	# cells read as damage on fabric rather than as a diagram.
	var linen := TextureRect.new()
	linen.texture = UITheme.tex("ui/ui_cloth_linen")
	linen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	linen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	linen.set_anchors_preset(Control.PRESET_TOP_WIDE)
	linen.set_offset(SIDE_BOTTOM, GRID_ZONE)
	linen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linen.visible = linen.texture != null
	_board.add_child(linen)

	_canvas = WardBoard.new()
	_canvas.screen = self
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.add_child(_canvas)
	for key in ["hole", "rack"]:
		var marker := MinigameShell.Marker.new()
		_board.add_child(marker)
		_markers[key] = marker

	var row := MinigameShell.action_row(shell["actions"])
	_turn_button = MinigameShell.aid_button(Strings.line("minigames.ward.turn"))
	_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_button.pressed.connect(func() -> void:
		_rotation = (_rotation + 1) % 4
		if coach != null:
			coach.notify("turn")
		_refresh())
	row.add_child(_turn_button)
	_finish_button = MinigameShell.leave_button(Strings.line("minigames.ward.finish"))
	_finish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_finish_button.pressed.connect(func() -> void:
		state.do_command({"type": "finish"})
		_finish())
	row.add_child(_finish_button)

	_help.pressed.connect(_start_tutorial)
	_help.visible = not coach_steps.is_empty()
	_refresh()
	if coach_auto:
		_start_tutorial()


func _start_tutorial() -> void:
	coach = MinigameShell.start_tutorial(self, coach_steps, _coach_target, coach)


func _coach_target(key: String) -> Control:
	match key:
		"turn": return _turn_button
		"finish": return _finish_button
		"board": return _board
		"board:hole": return _cover_marker("hole",
			Rect2(0, 0, _board.size.x, GRID_ZONE))
		"board:rack": return _cover_marker("rack",
			Rect2(0, GRID_ZONE + PAW_ZONE, _board.size.x, RACK_ZONE))
	return null


func _cover_marker(key: String, rect: Rect2) -> Control:
	var marker: MinigameShell.Marker = _markers[key]
	marker.cover(rect)
	return marker


# ------------------------------------------------------------------ pointer

func held_patch() -> String:
	return _held


func rotation() -> int:
	return _rotation


func pointer() -> Vector2:
	return _pointer


func dragging() -> bool:
	return _dragging


func on_press(point: Vector2) -> void:
	if Minigame.is_over(state.outcome):
		return
	_press_at = point
	_pointer = point
	var patch_id := _canvas.rack_patch_at(point)
	if patch_id != "":
		if state.placed.has(patch_id) or not state.can_afford(patch_id):
			return
		_held = patch_id
		_dragging = true
		_refresh()
		return
	# Pressing a laid patch lifts it. The cloth comes free; the card does not.
	var cell := _canvas.cell_at(point)
	if cell.x >= 0 and state.covered.has("%d,%d" % [cell.x, cell.y]):
		state.do_command({"type": "lift",
			"patch": String(state.covered["%d,%d" % [cell.x, cell.y]])})
		_refresh()


func on_motion(point: Vector2) -> void:
	if not _dragging:
		return
	_pointer = point
	_canvas.queue_redraw()


func on_release(point: Vector2) -> void:
	_pointer = point
	var was_dragging := _dragging
	_dragging = false
	if Minigame.is_over(state.outcome) or _held == "":
		_refresh()
		return
	# A press that never moved is a TAP: it picks the patch up and waits for a
	# second tap on the cloth, which is the old flow and still a valid one.
	if was_dragging and point.distance_to(_press_at) < TAP_SLOP \
			and _canvas.rack_patch_at(point) != "":
		_refresh()
		return
	_drop_at(point)


## The second tap of the tap-tap fallback, and the tour's way in.
func on_tap_cell(point: Vector2) -> void:
	if _held == "" or _dragging:
		return
	_drop_at(point)


func _drop_at(point: Vector2) -> void:
	var anchor := _canvas.anchor_for(_held, point, _rotation)
	if anchor.x >= 0 and state.fits(_held, anchor.x, anchor.y, _rotation):
		var result := state.do_command({"type": "place", "patch": _held,
			"row": anchor.x, "col": anchor.y, "rotation": _rotation})
		if result.get("ok", false):
			_held = ""
			if coach != null:
				coach.notify("board")
	_refresh()


func _refresh() -> void:
	var open: int = state.uncovered_cells().size()
	_status.text = Strings.line("minigames.ward.status_whole") if open == 0 \
		else Strings.line("minigames.ward.status", [open, state.hole.size()])
	_turn_button.disabled = _held == ""
	_canvas.queue_redraw()
	if Minigame.is_over(state.outcome):
		_finish()


func paw_line() -> String:
	var counts := {}
	for card_id in state.hand:
		var humour := String(state._catalog.energy_cards.get(card_id, {}).get("humour", ""))
		counts[humour] = int(counts.get(humour, 0)) + 1
	var parts: Array[String] = []
	for humour in Catalog.HUMOURS:
		parts.append("%s %d" % [Catalog.humour_name(humour), int(counts.get(humour, 0))])
	return Strings.line("minigames.ward.paw", [" · ".join(parts)])


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if coach != null and is_instance_valid(coach):
		coach.queue_free()
	MinigameShell.show_outcome(self, state.outcome, ward,
		func() -> void: closed.emit())


## The cloth, the paw line, the rack, and whatever is currently in the paw.
## One canvas for all of it, because a drag has to cross between them.
class WardBoard extends Control:
	const PATCH_COLOURS := ["#7a5233", "#3a5a7a", "#4a7a5a", "#7a4a6a", "#8a7a2a"]

	var screen
	var _step := 0.0
	var _origin := Vector2.ZERO
	var _rack_rects: Array[Rect2] = []
	var _rack_step := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if screen.held_patch() != "" and not screen.dragging() \
						and cell_at(event.position).x >= 0:
					screen.on_tap_cell(event.position)
				else:
					screen.on_press(event.position)
			else:
				screen.on_release(event.position)
		elif event is InputEventScreenTouch:
			if event.pressed:
				if screen.held_patch() != "" and not screen.dragging() \
						and cell_at(event.position).x >= 0:
					screen.on_tap_cell(event.position)
				else:
					screen.on_press(event.position)
			else:
				screen.on_release(event.position)
		elif event is InputEventMouseMotion or event is InputEventScreenDrag:
			screen.on_motion(event.position)

	# -------------------------------------------------------------- geometry

	## Grid cell under a point, as (row, col). (-1, -1) when off the cloth.
	func cell_at(point: Vector2) -> Vector2i:
		var state: WardState = screen.state
		if _step <= 0.0:
			return Vector2i(-1, -1)
		var local := point - _origin
		if local.x < 0.0 or local.y < 0.0:
			return Vector2i(-1, -1)
		var col := int(local.x / _step)
		var row := int(local.y / _step)
		if row < 0 or row >= state.height or col < 0 or col >= state.width:
			return Vector2i(-1, -1)
		return Vector2i(row, col)

	## Where a dropped patch's ORIGIN cell goes, so the shape lands centred
	## under the finger rather than hanging down and to the right of it.
	func anchor_for(patch_id: String, point: Vector2, rotation: int) -> Vector2i:
		var state: WardState = screen.state
		if _step <= 0.0 or patch_id == "":
			return Vector2i(-1, -1)
		var shape := WardState.rotate_shape(
			state.patch_def(patch_id).get("shape", []), rotation)
		var rows := 0
		var cols := 0
		for offset in shape:
			rows = maxi(rows, int(offset[0]))
			cols = maxi(cols, int(offset[1]))
		var local := point - _origin
		var col := int(floor(local.x / _step - cols * 0.5 + 0.5))
		var row := int(floor(local.y / _step - rows * 0.5 + 0.5))
		return Vector2i(row, col)

	## Which rack tile a point is over, or "".
	func rack_patch_at(point: Vector2) -> String:
		var state: WardState = screen.state
		for i in _rack_rects.size():
			if i < state.rack.size() and _rack_rects[i].has_point(point):
				return String(state.rack[i]["id"])
		return ""

	func _patch_colour(patch_id: String) -> Color:
		var state: WardState = screen.state
		for i in state.rack.size():
			if String(state.rack[i]["id"]) == patch_id:
				return Color(PATCH_COLOURS[i % PATCH_COLOURS.size()])
		return Color("7a5233")

	# ----------------------------------------------------------------- draw

	func _draw() -> void:
		var state: WardState = screen.state
		if state.width <= 0 or state.height <= 0:
			return
		_draw_cloth(state)
		_draw_paw()
		_draw_rack(state)
		_draw_held(state)

	func _draw_cloth(state: WardState) -> void:
		_step = minf(size.x / state.width, GRID_ZONE / state.height)
		var used := Vector2(_step * state.width, _step * state.height)
		_origin = Vector2((size.x - used.x) * 0.5, (GRID_ZONE - used.y) * 0.5)
		for row in state.height:
			for col in state.width:
				var key := "%d,%d" % [row, col]
				var rect := Rect2(_origin + Vector2(col * _step, row * _step),
					Vector2(_step - 3.0, _step - 3.0))
				if state.covered.has(key):
					draw_rect(rect, _patch_colour(String(state.covered[key])))
					draw_rect(rect, UITheme.INK, false, 2.0)
					# A patch sitting over sound cloth bought nothing, and says
					# so: no torn square underneath, no brass pin.
					if state.hole.has(key):
						draw_circle(rect.get_center(), _step * 0.10,
							MinigameShell.BRASS)
				elif state.hole.has(key):
					draw_rect(rect, MinigameShell.TORN)
					draw_rect(rect, Color("00000044"), false, 2.0)
				else:
					# Sound cloth is a translucent wash, so the LINEN behind
					# the grid shows its weave through every whole square —
					# the tear reads as damage on real fabric.
					draw_rect(rect, Color(MinigameShell.CLOTH, 0.35))
					MinigameShell.guide_line(self, rect.position,
						rect.position + Vector2(rect.size.x, 0), Color("00000018"))
					MinigameShell.guide_line(self, rect.position,
						rect.position + Vector2(0, rect.size.y), Color("00000018"))

	func _draw_paw() -> void:
		draw_string(UITheme.body_font(), Vector2(6.0, GRID_ZONE + 30.0),
			screen.paw_line(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, 24,
			UITheme.INK_SOFT)

	## The rack: each patch drawn as its true shape, stamped with the humour
	## that pays for it. Greyed when it is down or the paw cannot pay.
	func _draw_rack(state: WardState) -> void:
		_rack_rects.clear()
		var count: int = maxi(state.rack.size(), 1)
		var slot := size.x / float(count)
		var top := GRID_ZONE + PAW_ZONE
		_rack_step = minf(slot * 0.24, 26.0)
		for i in state.rack.size():
			var patch: Dictionary = state.rack[i]
			var patch_id := String(patch["id"])
			var rect := Rect2(i * slot + 4.0, top, slot - 8.0, RACK_ZONE - 8.0)
			_rack_rects.append(rect)
			var down: bool = state.placed.has(patch_id)
			var poor: bool = not state.can_afford(patch_id)
			var plate := Color("00000012") if not (down or poor) else Color("00000022")
			draw_rect(rect, plate)
			draw_rect(rect, UITheme.INK if screen.held_patch() == patch_id
				else Color("00000033"), false,
				4.0 if screen.held_patch() == patch_id else 1.5)
			var colour := _patch_colour(patch_id)
			if down or poor:
				colour = Color(colour, 0.28)
			_draw_shape(patch.get("shape", []), Vector2(
				rect.get_center().x, rect.position.y + 66.0), _rack_step,
				colour, true)
			var label := Catalog.humour_name(String(patch.get("humour", "")))
			if down:
				label = Strings.line("minigames.ward.rack_down", [label])
			elif poor:
				label = Strings.line("minigames.ward.rack_unaffordable", [label])
			# At the type floor and WRAPPED: "Guile (down)" is wider than a
			# rack slot, and draw_string would have quietly cropped it.
			draw_multiline_string(UITheme.body_font(),
				Vector2(rect.position.x + 4.0, rect.end.y - 54.0), label,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8.0,
				UITheme.TYPE_FLOOR, 2,
				UITheme.INK_SOFT if not (down or poor) else UITheme.INK_FADED)

	## The patch in the paw, snapped to the cloth under the finger. Amber
	## where it would close a torn square, grey where it would buy nothing,
	## red when it is hanging off the ward altogether.
	func _draw_held(state: WardState) -> void:
		var patch_id: String = screen.held_patch()
		if patch_id == "":
			return
		var point: Vector2 = screen.pointer()
		var rotation: int = screen.rotation()
		var anchor := anchor_for(patch_id, point, rotation)
		var shape := WardState.rotate_shape(
			state.patch_def(patch_id).get("shape", []), rotation)
		if anchor.x >= 0 and state.fits(patch_id, anchor.x, anchor.y, rotation):
			for offset in shape:
				var row: int = anchor.x + int(offset[0])
				var col: int = anchor.y + int(offset[1])
				var key := "%d,%d" % [row, col]
				var useful: bool = state.hole.has(key) and not state.covered.has(key)
				var rect := Rect2(_origin + Vector2(col * _step, row * _step),
					Vector2(_step - 3.0, _step - 3.0))
				draw_rect(rect, Color("e0913aaa") if useful else Color("6b574788"))
				draw_rect(rect, UITheme.INK, false, 3.0)
		elif screen.dragging():
			_draw_shape(shape, point, _step * 0.6, Color("8c2f2488"), false)

	## A polyomino drawn centred on `centre` at `cell` pixels a square.
	func _draw_shape(shape: Array, centre: Vector2, cell: float, colour: Color,
			outline: bool) -> void:
		var rows := 0
		var cols := 0
		for offset in shape:
			rows = maxi(rows, int(offset[0]))
			cols = maxi(cols, int(offset[1]))
		var origin := centre - Vector2((cols + 1) * cell, (rows + 1) * cell) * 0.5
		for offset in shape:
			var rect := Rect2(origin + Vector2(int(offset[1]) * cell,
				int(offset[0]) * cell), Vector2(cell - 2.0, cell - 2.0))
			draw_rect(rect, colour)
			if outline:
				draw_rect(rect, Color(UITheme.INK, colour.a), false, 2.0)
