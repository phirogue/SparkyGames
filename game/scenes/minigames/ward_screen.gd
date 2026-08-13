extends Control
## Patch the Ward — the quilting board (minigames.md #3).
##
## The ward is a grid of squares: sound cloth pale, the tear dark. Patches sit
## on a rack below, each stamped with the humour that pays for it. Each
## placement takes an energy card out of the hand for real — the mend is paid
## from the same stamina the fighting uses, which is the module's whole reason
## to exist. Lifting a patch hands its card straight back (owner 2026-08-13):
## a patch you took off is a patch you did not play.
##
## The cloth is QUILTED, not coloured in: every patch is cut from one of four
## weaves and stitched down with running stitch, so a mend reads as pieced
## work. The rack tile is where a patch turns — animated, in its own picture,
## because a rotation that only exists under the finger cannot be gauged.
## Between cloth and rack runs the energy strip: the spool and each humour's
## count, so the price of a patch is on the page beside the patch.
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

## Board zone (720) split between the cloth, the energy strip and the rack.
## The strip grew from a line of drawn text to a real row of glyphs at the
## owner's 2026-08-13 pass: "add the picture of the spool and the energies
## like its done in the other uis so its clear that playing a patch costs
## energy". 452 + 56 + 212 = 720 exactly (law 6).
const GRID_ZONE := 452.0
const PAW_ZONE := 56.0
const RACK_ZONE := 212.0
## How far a press may wander and still count as a tap rather than a drag.
const TAP_SLOP := 14.0
## How long a quarter-turn takes to swing through, in the rack tile where the
## patch actually lives — the owner could not tell a turned patch from an
## untouched one, because nothing on the page ever moved.
const TURN_SPIN := 0.18

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
## Degrees still to swing through on the current quarter-turn (negative,
## easing to 0), so the patch is SEEN turning where its picture is.
var _turn_spin := 0.0
var _energy_chips: Dictionary = {}   # "spool" / humour -> Label


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
	_build_energy_strip()
	for key in ["hole", "rack"]:
		var marker := MinigameShell.Marker.new()
		_board.add_child(marker)
		_markers[key] = marker

	var row := MinigameShell.action_row(shell["actions"])
	_turn_button = MinigameShell.aid_button(Strings.line("minigames.ward.turn"))
	_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_button.pressed.connect(_on_turn)
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


## The energy strip: the spool and what is wound on it, by humour, drawn the
## way the battle screen draws the same reading. It sits directly under the
## cloth and directly over the rack, so the sentence the page makes is
## "this much energy — these patches — that is what they cost".
func _build_energy_strip() -> void:
	var strip := HBoxContainer.new()
	strip.position = Vector2(0.0, GRID_ZONE)
	strip.size = Vector2(UITheme.CONTENT_WIDTH, PAW_ZONE)
	strip.add_theme_constant_override("separation", 6)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(strip)
	_energy_chips["spool"] = _energy_chip(strip, "ui/ui_spool", 44.0, UITheme.INK)
	for humour in Catalog.HUMOURS:
		var colour: Color = MinigameShell.HUMOUR_COLOURS.get(humour, UITheme.INK)
		_energy_chips[humour] = _energy_chip(strip,
			String(MinigameShell.HUMOUR_GLYPH.get(humour, "")), 38.0, colour)


func _energy_chip(parent: Container, icon_id: String, box: float,
		colour: Color) -> Label:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 4)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(chip)
	chip.add_child(UITheme.icon(icon_id, box))
	var label := Label.new()
	label.add_theme_font_override("font", UITheme.display_font())
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", colour)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(label)
	return label


## A quarter-turn, SEEN: the swing runs in the rack tile where the patch's own
## picture lives, because a rotation that only exists under the finger is a
## rotation the owner could not gauge (2026-08-13).
func _on_turn() -> void:
	if _held == "":
		return
	_rotation = (_rotation + 1) % 4
	if coach != null:
		coach.notify("turn")
	var tween := create_tween()
	tween.tween_method(_set_turn_spin, -90.0, 0.0, TURN_SPIN) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_refresh()


func _set_turn_spin(degrees: float) -> void:
	_turn_spin = degrees
	_canvas.queue_redraw()


func turn_spin() -> float:
	return _turn_spin


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
	# Pressing a laid patch lifts it — cloth and card both come back.
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
	_refresh_energy()
	_canvas.queue_redraw()
	if Minigame.is_over(state.outcome):
		_finish()


## What is left to sew with. Faded to nothing when a humour has run out —
## knowing a colour is gone is the reading that changes which patch you reach
## for (the battle's spool rule, on the ward's rack).
func _refresh_energy() -> void:
	var counts := {}
	for card_id in state.hand:
		var humour := String(state._catalog.energy_cards.get(card_id, {}).get("humour", ""))
		counts[humour] = int(counts.get(humour, 0)) + 1
	_energy_chips["spool"].text = str(state.hand.size())
	for humour in Catalog.HUMOURS:
		var count: int = int(counts.get(humour, 0))
		var label: Label = _energy_chips[humour]
		label.text = str(count)
		var colour: Color = MinigameShell.HUMOUR_COLOURS.get(humour, UITheme.INK)
		label.add_theme_color_override("font_color",
			colour if count > 0 else UITheme.INK_FADED)
		label.get_parent().modulate.a = 1.0 if count > 0 else 0.45


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
	## How many weaves the scrap bag holds (see _draw_quilt_cell).
	const WEAVES := 4

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


	## Which of the weaves this patch is cut from. Owner 2026-08-13: "the
	## pieces should be textured as pieces of a quilt" — a quilt is scraps,
	## and scraps do not all have the same weave, so the pattern is part of a
	## patch's identity along with its colour.
	func _patch_weave(patch_id: String) -> int:
		var state: WardState = screen.state
		for i in state.rack.size():
			if String(state.rack[i]["id"]) == patch_id:
				return i % WEAVES
		return 0

	# ----------------------------------------------------------------- draw

	func _draw() -> void:
		var state: WardState = screen.state
		if state.width <= 0 or state.height <= 0:
			return
		_draw_cloth(state)
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
					var patch_id := String(state.covered[key])
					_draw_quilt_cell(rect, _patch_colour(patch_id),
						_patch_weave(patch_id), 1.0)
					# The seam where this square meets a square of ANOTHER
					# patch: the stitching that says these are separate pieces.
					_draw_patch_seams(state, row, col, rect, patch_id)
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

	## The rack: each patch drawn as its true shape in its own cloth, stamped
	## with the humour glyph that pays for it — the same glyph the energy strip
	## above it counts, so "this patch costs one of those" is one glance.
	## Greyed when it is down or the paw cannot pay.
	##
	## The patch in the paw turns HERE, in its own picture, with the swing
	## animated (owner 2026-08-13). Under the finger a rotation is guesswork;
	## in the tile it is a fact.
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
			var held: bool = screen.held_patch() == patch_id
			var plate := Color("00000012") if not (down or poor) else Color("00000022")
			draw_rect(rect, plate)
			draw_rect(rect, UITheme.INK if held else Color("00000033"), false,
				4.0 if held else 1.5)
			var alpha := 0.28 if (down or poor) else 1.0
			# The rack shows the patch as it will LAND: the live rotation while
			# it is in the paw, its filed shape otherwise.
			var shape: Array = patch.get("shape", [])
			var spin := 0.0
			if held:
				shape = WardState.rotate_shape(shape, screen.rotation())
				spin = deg_to_rad(screen.turn_spin())
			var centre := Vector2(rect.get_center().x, rect.position.y + 62.0)
			draw_set_transform(centre, spin, Vector2.ONE)
			_draw_quilt_shape(shape, Vector2.ZERO, _rack_step,
				_patch_colour(patch_id), i % WEAVES, alpha)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_draw_humour_stamp(String(patch.get("humour", "")),
				Vector2(rect.get_center().x, rect.end.y - 74.0), alpha)
			var label := Catalog.humour_name(String(patch.get("humour", "")))
			if down:
				label = Strings.line("minigames.ward.rack_down", [label])
			elif poor:
				label = Strings.line("minigames.ward.rack_unaffordable", [label])
			# At the type floor and WRAPPED: "Guile (down)" is wider than a
			# rack slot, and draw_string would have quietly cropped it.
			draw_multiline_string(UITheme.body_font(),
				Vector2(rect.position.x + 4.0, rect.end.y - 40.0), label,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8.0,
				UITheme.TYPE_FLOOR, 2,
				UITheme.INK_SOFT if not (down or poor) else UITheme.INK_FADED)

	## The humour glyph a patch is paid with, drawn at its opaque size — the
	## rack's half of "playing a patch costs energy".
	func _draw_humour_stamp(humour: String, centre: Vector2, alpha: float) -> void:
		var glyph := UITheme.cropped_tex(
			String(MinigameShell.HUMOUR_GLYPH.get(humour, "")))
		if glyph == null:
			return
		var box := 34.0
		var scale := minf(box / glyph.get_width(), box / glyph.get_height())
		var used := Vector2(glyph.get_width(), glyph.get_height()) * scale
		var tint: Color = MinigameShell.HUMOUR_COLOURS.get(humour, UITheme.INK)
		draw_texture_rect(glyph, Rect2(centre - used * 0.5, used), false,
			Color(tint, alpha))

	## The patch in the paw, snapped to the cloth under the finger. Its own
	## cloth where it would close a torn square, washed out where it would buy
	## nothing, and carried as a loose scrap while it is still in the air.
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
			var colour := _patch_colour(patch_id)
			var weave := _patch_weave(patch_id)
			for offset in shape:
				var row: int = anchor.x + int(offset[0])
				var col: int = anchor.y + int(offset[1])
				var key := "%d,%d" % [row, col]
				var useful: bool = state.hole.has(key) and not state.covered.has(key)
				var rect := Rect2(_origin + Vector2(col * _step, row * _step),
					Vector2(_step - 3.0, _step - 3.0))
				_draw_quilt_cell(rect, colour, weave, 0.85 if useful else 0.4)
				draw_rect(rect, Color("e0913a") if useful else Color("6b5747"),
					false, 3.0)
		elif screen.dragging():
			_draw_quilt_shape(shape, point, _step * 0.6,
				_patch_colour(patch_id), _patch_weave(patch_id), 0.6)

	## A polyomino of quilt cloth, centred on `centre` at `cell` pixels a
	## square, with running stitch around its outer edge.
	func _draw_quilt_shape(shape: Array, centre: Vector2, cell: float,
			colour: Color, weave: int, alpha: float) -> void:
		var rows := 0
		var cols := 0
		for offset in shape:
			rows = maxi(rows, int(offset[0]))
			cols = maxi(cols, int(offset[1]))
		var origin := centre - Vector2((cols + 1) * cell, (rows + 1) * cell) * 0.5
		var filled := {}
		for offset in shape:
			filled["%d,%d" % [int(offset[0]), int(offset[1])]] = true
		for offset in shape:
			var at := origin + Vector2(int(offset[1]) * cell, int(offset[0]) * cell)
			_draw_quilt_cell(Rect2(at, Vector2(cell, cell)), colour, weave, alpha)
		# Stitch only the silhouette: an outline around every square would read
		# as a grid of tiles, not as one pieced patch.
		for offset in shape:
			var r := int(offset[0])
			var c := int(offset[1])
			var at := origin + Vector2(c * cell, r * cell)
			if not filled.has("%d,%d" % [r - 1, c]):
				_running_stitch(at, at + Vector2(cell, 0.0), alpha)
			if not filled.has("%d,%d" % [r + 1, c]):
				_running_stitch(at + Vector2(0.0, cell),
					at + Vector2(cell, cell), alpha)
			if not filled.has("%d,%d" % [r, c - 1]):
				_running_stitch(at, at + Vector2(0.0, cell), alpha)
			if not filled.has("%d,%d" % [r, c + 1]):
				_running_stitch(at + Vector2(cell, 0.0),
					at + Vector2(cell, cell), alpha)

	## One square of quilt: dyed cloth with its weave showing through. Four
	## weaves, so a rack of five patches reads as five different scraps rather
	## than as five colours of the same plastic.
	func _draw_quilt_cell(rect: Rect2, colour: Color, weave: int,
			alpha: float) -> void:
		draw_rect(rect, Color(colour, alpha))
		var light := Color(colour.lightened(0.26), alpha * 0.75)
		var dark := Color(colour.darkened(0.34), alpha * 0.55)
		var step := rect.size.x / 4.0
		match weave % WEAVES:
			0:   # plain weave: the warp showing through the weft
				for i in range(1, 4):
					draw_line(rect.position + Vector2(i * step, 0.0),
						rect.position + Vector2(i * step, rect.size.y), dark, 1.5)
				draw_line(rect.position + Vector2(0.0, rect.size.y * 0.5),
					rect.position + Vector2(rect.size.x, rect.size.y * 0.5),
					light, 1.5)
			1:   # twill: the diagonal rib, kept INSIDE the square (a diagonal
				# drawn corner to corner across the whole cell overhangs the
				# patch and reads as stray thread — it did, in the first shot)
				for i in range(1, 4):
					var run := rect.size.x * 0.25 * float(i)
					draw_line(rect.position + Vector2(0.0, run),
						rect.position + Vector2(run, 0.0), light, 1.5)
					draw_line(rect.end - Vector2(0.0, run),
						rect.end - Vector2(run, 0.0), light, 1.5)
			2:   # gingham: checks, the cheapest cloth in any scrap bag
				draw_rect(Rect2(rect.position, rect.size * 0.5), light)
				draw_rect(Rect2(rect.get_center(), rect.size * 0.5), light)
			3:   # sprigged: a print, dotted
				for i in 2:
					for j in 2:
						draw_circle(rect.position + Vector2(
							(i + 0.5) * rect.size.x * 0.5,
							(j + 0.5) * rect.size.y * 0.5),
							maxf(rect.size.x * 0.07, 1.2), light)

	## Running stitch along one edge — dashes, the way a needle actually goes.
	func _running_stitch(from: Vector2, to: Vector2, alpha: float) -> void:
		draw_dashed_line(from, to, Color(0.16, 0.12, 0.09, alpha), 2.0, 5.0)

	## The seam between two DIFFERENT patches laid side by side on the cloth:
	## stitched, so a stack reads as pieced work instead of one flat colour.
	func _draw_patch_seams(state: WardState, row: int, col: int, rect: Rect2,
			patch_id: String) -> void:
		var neighbours := [[-1, 0], [1, 0], [0, -1], [0, 1]]
		for step in neighbours:
			var key := "%d,%d" % [row + int(step[0]), col + int(step[1])]
			if String(state.covered.get(key, "")) == patch_id:
				continue
			if int(step[0]) == -1:
				_running_stitch(rect.position,
					rect.position + Vector2(rect.size.x, 0.0), 1.0)
			elif int(step[0]) == 1:
				_running_stitch(rect.position + Vector2(0.0, rect.size.y),
					rect.end, 1.0)
			elif int(step[1]) == -1:
				_running_stitch(rect.position,
					rect.position + Vector2(0.0, rect.size.y), 1.0)
			else:
				_running_stitch(rect.position + Vector2(rect.size.x, 0.0),
					rect.end, 1.0)
