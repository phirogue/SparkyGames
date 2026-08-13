extends Control
## Patch the Ward — the quilting board (minigames.md #3).
##
## OWNER 2026-08-13: "treat it as another card game. Each new card drawn has a
## shape on it, the shape corresponds to the energy type. Player can choose to
## draw more cards winding down the deck or leave early with parts not
## covered." So there is no rack of patches waiting. There is a tear, and
## there is your spool.
##
## The page says that in three bands: the CLOTH, the spool and what is still
## wound on it, and the PAW — one card, drawn, with the cloth it cuts drawn on
## its face. DRAW takes the next card and spends it; DRAG lays what it cut;
## TURN IT swings the piece in its own picture; DONE MENDING stops, and every
## square still open follows you into the next fight.
##
## The cloth is QUILTED, not coloured in: every patch is cut from one of four
## weaves and stitched down with running stitch, so a mend reads as pieced
## work. Lifting a laid patch picks it back up into the paw — free, because
## the card went at the draw, which is where the decision was.

signal closed

## Board zone (720) split between the cloth, the spool strip and the paw.
## 452 + 56 + 212 = 720 exactly (law 6).
const GRID_ZONE := 452.0
const PAW_ZONE := 56.0
const CARD_ZONE := 212.0
## How far a press may wander and still count as a tap rather than a drag.
const TAP_SLOP := 14.0
## How long a quarter-turn takes to swing through, in the card face where the
## patch actually lives — the owner could not tell a turned patch from an
## untouched one, because nothing on the page ever moved.
const TURN_SPIN := 0.18
## The drawn card's face, centred in the card zone.
const CARD_SIZE := Vector2(196.0, 196.0)

var state: WardState
var ward: Dictionary = {}
var coach_steps: Array = []
var coach_auto := false
var coach: Coach = null

var _status: Label
var _board: Control
var _canvas: WardBoard
var _help: Button
var _draw_button: Button
var _turn_button: Button
var _finish_button: Button
var _markers: Dictionary = {}
var _rotation := 0
var _pointer := Vector2.ZERO
var _press_at := Vector2.ZERO
var _dragging := false
var _finished := false
## Degrees still to swing through on the current quarter-turn (negative,
## easing to 0), so the patch is SEEN turning where its picture is.
var _turn_spin := 0.0
var _energy_chips: Dictionary = {}   # "spool" / humour -> Label


func setup(catalog: Catalog, ward_data: Dictionary, deck: Array) -> void:
	ward = ward_data
	state = WardState.create(catalog, ward_data, deck)


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
	for key in ["hole", "card"]:
		var marker := MinigameShell.Marker.new()
		_board.add_child(marker)
		_markers[key] = marker

	# Three verbs, two rows: drawing and turning are the moves you make over
	# and over, and stopping is the one you make once.
	var top := MinigameShell.action_row(shell["actions"])
	_draw_button = MinigameShell.aid_button("", MinigameShell.ACTION_FONT_HALF,
		MinigameShell.ACTION_HEIGHT_HALF)
	_draw_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_draw_button.pressed.connect(_on_draw)
	top.add_child(_draw_button)
	_turn_button = MinigameShell.aid_button(Strings.line("minigames.ward.turn"),
		MinigameShell.ACTION_FONT_HALF, MinigameShell.ACTION_HEIGHT_HALF)
	_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_button.pressed.connect(_on_turn)
	top.add_child(_turn_button)
	var bottom := MinigameShell.action_row(shell["actions"])
	_finish_button = MinigameShell.leave_button(
		Strings.line("minigames.ward.finish"), MinigameShell.ACTION_FONT_HALF,
		MinigameShell.ACTION_HEIGHT_HALF, UITheme.CONTENT_WIDTH)
	_finish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_finish_button.pressed.connect(func() -> void:
		state.do_command({"type": "finish"})
		_finish())
	bottom.add_child(_finish_button)

	_help.pressed.connect(_start_tutorial)
	_help.visible = not coach_steps.is_empty()
	_refresh()
	if coach_auto:
		_start_tutorial()


## The spool strip: what is still wound on, by humour, drawn the way the
## battle screen draws the same reading. It sits between the cloth and the
## card, so the sentence the page makes is "this much left — this is what the
## next one cut — that is what it cost".
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


## One more card off the spool. This is the whole wager: it mends more and it
## leaves less for whatever is after this doorway.
func _on_draw() -> void:
	if not state.can_draw():
		return
	var result := state.do_command({"type": "draw"})
	if result.get("ok", false):
		_rotation = 0
		if coach != null:
			coach.notify("draw")
		UITheme.pulse(_energy_chips["spool"].get_parent(), 1.2)
	_refresh()


## A quarter-turn, SEEN: the swing runs on the card face where the patch's own
## picture lives, because a rotation that only exists under the finger cannot
## be gauged (owner 2026-08-13).
func _on_turn() -> void:
	if state.drawn == "":
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
		"draw": return _draw_button
		"turn": return _turn_button
		"finish": return _finish_button
		"board": return _board
		"board:hole": return _cover_marker("hole",
			Rect2(0, 0, _board.size.x, GRID_ZONE))
		"board:card": return _cover_marker("card",
			Rect2(0, GRID_ZONE + PAW_ZONE, _board.size.x, CARD_ZONE))
	return null


func _cover_marker(key: String, rect: Rect2) -> Control:
	var marker: MinigameShell.Marker = _markers[key]
	marker.cover(rect)
	return marker


# ------------------------------------------------------------------ pointer

func held_patch() -> String:
	return state.drawn


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
	# Pressing the drawn card picks the cloth up to carry it.
	if state.drawn != "" and _canvas.card_rect().has_point(point):
		_dragging = true
		_refresh()
		return
	# Pressing a laid patch lifts it back into the paw — free, and only when
	# the paw is empty, which the rules enforce.
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
	if Minigame.is_over(state.outcome) or state.drawn == "":
		_refresh()
		return
	# A press that never moved is a TAP: it holds the cloth up and waits for a
	# second tap on the ward, because a modal interaction with exactly one way
	# in is how players get stuck (law 7).
	if was_dragging and point.distance_to(_press_at) < TAP_SLOP \
			and _canvas.card_rect().has_point(point):
		_refresh()
		return
	_drop_at(point)


## The second tap of the tap-tap fallback, and the tour's way in.
func on_tap_cell(point: Vector2) -> void:
	if state.drawn == "" or _dragging:
		return
	_drop_at(point)


func _drop_at(point: Vector2) -> void:
	var anchor := _canvas.anchor_for(state.drawn, point, _rotation)
	if anchor.x >= 0 and state.fits(state.drawn, anchor.x, anchor.y, _rotation):
		var result := state.do_command({"type": "place", "row": anchor.x,
			"col": anchor.y, "rotation": _rotation})
		if result.get("ok", false) and coach != null:
			coach.notify("board")
	_refresh()


func _refresh() -> void:
	var open: int = state.uncovered_cells().size()
	_status.text = Strings.line("minigames.ward.status_whole") if open == 0 \
		else Strings.line("minigames.ward.status", [open, state.hole.size()])
	_draw_button.text = Strings.line("minigames.ward.draw", [state.deck.size()]) \
		if state.can_draw() \
		else Strings.line("minigames.ward.draw_spent") if state.deck.is_empty() \
		else Strings.line("minigames.ward.draw_paw_full")
	_draw_button.disabled = not state.can_draw()
	_turn_button.disabled = state.drawn == ""
	_refresh_energy()
	_canvas.queue_redraw()
	if Minigame.is_over(state.outcome):
		_finish()


## What is left to mend with. Faded to nothing when a humour has run out —
## knowing a colour is gone is the reading that changes whether you draw
## again (the battle's spool rule, on the ward's cloth).
func _refresh_energy() -> void:
	var counts := {}
	for card_id in state.deck:
		var humour: String = state.humour_of(String(card_id))
		counts[humour] = int(counts.get(humour, 0)) + 1
	_energy_chips["spool"].text = str(state.deck.size())
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


## The cloth, the spool strip, the drawn card, and whatever is in the paw.
## One canvas for all of it, because a drag has to cross between them.
class WardBoard extends Control:
	## How many weaves the scrap bag holds (see _draw_quilt_cell).
	const WEAVES := 4

	var screen
	var _step := 0.0
	var _origin := Vector2.ZERO

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
	func anchor_for(card_id: String, point: Vector2, rotation: int) -> Vector2i:
		var state: WardState = screen.state
		if _step <= 0.0 or card_id == "":
			return Vector2i(-1, -1)
		var shape := WardState.rotate_shape(state.shape_of(card_id), rotation)
		var rows := 0
		var cols := 0
		for offset in shape:
			rows = maxi(rows, int(offset[0]))
			cols = maxi(cols, int(offset[1]))
		var local := point - _origin
		var col := int(floor(local.x / _step - cols * 0.5 + 0.5))
		var row := int(floor(local.y / _step - rows * 0.5 + 0.5))
		return Vector2i(row, col)

	## The drawn card's face, centred in the card zone.
	func card_rect() -> Rect2:
		return Rect2(Vector2((size.x - CARD_SIZE.x) * 0.5,
			GRID_ZONE + PAW_ZONE + (CARD_ZONE - CARD_SIZE.y) * 0.5), CARD_SIZE)

	## Which weave a card's cloth is cut from — the humour picks it, so the
	## same energy always looks like the same bolt.
	func _weave_of(card_id: String) -> int:
		return maxi(Catalog.HUMOURS.find(screen.state.humour_of(card_id)), 0) % WEAVES

	func _colour_of(card_id: String) -> Color:
		var humour: String = screen.state.humour_of(card_id)
		var base: Color = MinigameShell.HUMOUR_COLOURS.get(humour, Color("7a5233"))
		return base

	# ----------------------------------------------------------------- draw

	func _draw() -> void:
		var state: WardState = screen.state
		if state.width <= 0 or state.height <= 0:
			return
		_draw_cloth(state)
		_draw_card(state)
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
					var patch_key := String(state.covered[key])
					var card := String(state.placed[patch_key]["card"])
					_draw_quilt_cell(rect, _colour_of(card), _weave_of(card), 1.0)
					# The seam where this square meets a square of ANOTHER
					# patch: the stitching that says these are separate pieces.
					_draw_patch_seams(state, row, col, rect, patch_key)
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

	## The card in the paw: an energy card face with the cloth it cut drawn on
	## it, its humour named, and its worth in the corner. This is the whole of
	## the owner's "each new card drawn has a shape on it".
	func _draw_card(state: WardState) -> void:
		var rect := card_rect()
		if state.drawn == "":
			# An empty paw still shows the plate, so the page keeps its shape
			# and the DRAW button has somewhere to point.
			draw_rect(rect, Color("00000010"))
			draw_rect(rect, Color("00000030"), false, 2.0)
			var prompt := Strings.line("minigames.ward.paw_empty") \
				if not state.deck.is_empty() \
				else Strings.line("minigames.ward.spool_bare")
			# Measured, not guessed: at three lines this plate cropped its own
			# sentence mid-word (law 5).
			var wrap := rect.size.x - 28.0
			var box := UITheme.measure_text(prompt, UITheme.body_font(),
				UITheme.TYPE_SUPPORT, wrap)
			draw_multiline_string(UITheme.body_font(),
				rect.position + Vector2(14.0, (rect.size.y - box.y) * 0.5 + 22.0),
				prompt, HORIZONTAL_ALIGNMENT_CENTER, wrap,
				UITheme.TYPE_SUPPORT, -1, UITheme.INK_FADED)
			return
		var card: Dictionary = screen.state._catalog.energy_cards.get(state.drawn, {})
		var humour := String(card.get("humour", ""))
		var tint: Color = MinigameShell.HUMOUR_COLOURS.get(humour, UITheme.INK)
		draw_rect(rect, Color("f2e4c8"))
		draw_rect(rect, tint, false, 4.0)
		# The cloth this card cuts, at the ward's own cell size where it fits,
		# so what is on the card is exactly what will land on the cloth.
		var shape := WardState.rotate_shape(state.shape_of(state.drawn),
			screen.rotation())
		var rows := 1
		var cols := 1
		for offset in shape:
			rows = maxi(rows, int(offset[0]) + 1)
			cols = maxi(cols, int(offset[1]) + 1)
		var cell := minf(minf(_step, (rect.size.x - 48.0) / float(cols)),
			(rect.size.y - 88.0) / float(rows))
		draw_set_transform(rect.get_center() + Vector2(0.0, -8.0),
			deg_to_rad(screen.turn_spin()), Vector2.ONE)
		_draw_quilt_shape(shape, Vector2.ZERO, cell, _colour_of(state.drawn),
			_weave_of(state.drawn), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var worth := int(card.get("value", 0))
		draw_string(UITheme.display_font(), rect.position + Vector2(14.0, 36.0),
			str(worth), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UITheme.INK)
		draw_string(UITheme.body_font(),
			rect.position + Vector2(0.0, rect.size.y - 18.0),
			Catalog.humour_name(humour), HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x, UITheme.TYPE_SUPPORT, tint)

	## The cloth in the paw, snapped to the ward under the finger. Its own
	## weave where it would close a torn square, washed out where it would buy
	## nothing, and carried as a loose scrap while it is still in the air.
	func _draw_held(state: WardState) -> void:
		var card_id: String = state.drawn
		if card_id == "" or not screen.dragging():
			return
		var point: Vector2 = screen.pointer()
		var rotation: int = screen.rotation()
		var anchor := anchor_for(card_id, point, rotation)
		var shape := WardState.rotate_shape(state.shape_of(card_id), rotation)
		if anchor.x >= 0 and state.fits(card_id, anchor.x, anchor.y, rotation):
			var colour := _colour_of(card_id)
			var weave := _weave_of(card_id)
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
		else:
			_draw_quilt_shape(shape, point, _step * 0.6, _colour_of(card_id),
				_weave_of(card_id), 0.6)

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
	## weaves, one per humour, so the cloth a card cuts is recognisable as
	## that card's before you read anything.
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
			patch_key: String) -> void:
		for step in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
			var key := "%d,%d" % [row + int(step[0]), col + int(step[1])]
			if String(state.covered.get(key, "")) == patch_key:
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
