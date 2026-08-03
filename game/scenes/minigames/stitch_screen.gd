extends Control
## Seam & Stitch prototype board — geometry only, no art (minigames.md #1).
##
## Dots, clue numbers and thread. Tap an edge to sew it; tap it again to
## unpick. The seam draws as a real line between dots and goes taut (thicker,
## brass-pinned) the moment it closes.
##
## Mirror mode flips the CLUES horizontally, not the grid: the player sews
## the seam they see while reading numbers written the other way round. That
## is the Ch3 payoff, and it costs one boolean here.

signal closed

const TAP_RADIUS := 34.0   # generous: fingers, not mice

var state: StitchState
var chart: Dictionary = {}

var _board: Control
var _status: Label
var _origin := Vector2.ZERO
var _step := 0.0


func setup(chart_data: Dictionary) -> void:
	chart = chart_data
	state = StitchState.create(chart_data)


func _ready() -> void:
	var shell := MinigameShell.build(self, String(chart.get("name", "A Stitch Chart")),
		func() -> void: closed.emit())
	_status = shell["status"]
	_board = shell["board"]

	var canvas := StitchBoard.new()
	canvas.screen = self
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.add_child(canvas)

	var squint := UITheme.dark_button("Squint", 24, Vector2(180, 96))
	squint.pressed.connect(_on_squint)
	shell["actions"].add_child(squint)
	var give_up := UITheme.dark_button("Leave it", 24, Vector2(180, 96))
	give_up.pressed.connect(func() -> void:
		state.do_command({"type": "give_up"})
		_finish())
	shell["actions"].add_child(give_up)

	_refresh()


## Board geometry: the largest square cell that fits the zone, centred.
func _layout(board_size: Vector2) -> void:
	var cols := state.width
	var rows := state.height
	if cols <= 0 or rows <= 0:
		return
	_step = minf(board_size.x / (cols + 1.0), board_size.y / (rows + 1.0))
	var used := Vector2(_step * cols, _step * rows)
	_origin = (board_size - used) * 0.5


func dot_position(row: int, col: int) -> Vector2:
	return _origin + Vector2(col * _step, row * _step)


## Clue numbers read mirrored in mirror mode: column c is shown where column
## (width-1-c) sits. The seam itself is untouched — that is the whole trick.
func clue_at(row: int, col: int) -> Variant:
	var source_col := (state.width - 1 - col) if state.mirrored else col
	var key := "%d,%d" % [row, source_col]
	return state.clues.get(key, null)


func edge_midpoint(edge_id: String) -> Vector2:
	var dots := state.edge_dots(edge_id)
	var a := String(dots[0]).split(",")
	var b := String(dots[1]).split(",")
	return (dot_position(int(a[0]), int(a[1]))
		+ dot_position(int(b[0]), int(b[1]))) * 0.5


func nearest_edge(point: Vector2) -> String:
	var best := ""
	var best_distance := TAP_RADIUS
	for edge_id in state.all_edges():
		var distance := point.distance_to(edge_midpoint(edge_id))
		if distance < best_distance:
			best_distance = distance
			best = edge_id
	return best


func on_board_tap(point: Vector2) -> void:
	if Minigame.is_over(state.outcome):
		return
	var edge_id := nearest_edge(point)
	if edge_id == "":
		return
	state.do_command({"type": "unpick" if state.sewn.has(edge_id) else "sew",
		"edge": edge_id})
	_refresh()


func _on_squint() -> void:
	if Minigame.is_over(state.outcome):
		return
	var result := state.do_command({"type": "squint"})
	if result.get("clean", false):
		_status.text = "Nothing sewn is wrong. Yet."
	_refresh()


func _refresh() -> void:
	var total: int = state.clues.size()
	_status.text = "%d of %d clues answered   ·   squints left: %d%s" % [
		state.clues_satisfied(), total, state.paws,
		"   ·   the numbers read backward" if state.mirrored else ""]
	queue_redraw()
	for child in _board.get_children():
		child.queue_redraw()
	if Minigame.is_over(state.outcome):
		_finish()


func _finish() -> void:
	MinigameShell.show_outcome(self, state.outcome, chart,
		func() -> void: closed.emit())


## The drawn board. Dots, clues, thread — and the taut seam when it closes.
class StitchBoard extends Control:
	var screen

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			screen.on_board_tap(event.position)
		elif event is InputEventScreenTouch and event.pressed:
			screen.on_board_tap(event.position)

	func _draw() -> void:
		var state: StitchState = screen.state
		screen._layout(size)
		var closed_seam := state.outcome == Minigame.Outcome.SUCCESS

		# Unsewn edges: faint guides, so the board reads as a grid of choices.
		for edge_id in state.all_edges():
			if state.sewn.has(edge_id):
				continue
			var dots := state.edge_dots(edge_id)
			draw_line(_dot(dots[0]), _dot(dots[1]), MinigameShell.INK_FAINT, 1.0)

		# Clue numbers, with the ones that are over-sewn marked.
		for row in state.height:
			for col in state.width:
				var clue = screen.clue_at(row, col)
				if clue == null:
					continue
				var centre: Vector2 = (screen.dot_position(row, col)
					+ screen.dot_position(row + 1, col + 1)) * 0.5
				var font := UITheme.display_font()
				var text := str(int(clue))
				var text_size := font.get_string_size(text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
				var colour := UITheme.INK
				if screen.state.clue_broken(row, col):
					colour = MinigameShell.THREAD
				elif screen.state.clue_satisfied(row, col):
					colour = Color("6b5747aa")
				draw_string(font, centre + Vector2(-text_size.x * 0.5, text_size.y * 0.35),
					text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, colour)

		# The thread itself.
		for edge_id in state.sewn:
			var dots := state.edge_dots(String(edge_id))
			var width := 9.0 if closed_seam else 7.0
			var colour := MinigameShell.THREAD
			if String(edge_id) == state.squint_hint:
				colour = Color("2b6ea8")   # the squint's callout, unmistakable
			draw_line(_dot(dots[0]), _dot(dots[1]), colour, width, true)

		# Dots last, on top of the thread, brass once the seam is closed.
		for row in state.height + 1:
			for col in state.width + 1:
				var centre: Vector2 = screen.dot_position(row, col)
				draw_circle(centre, 5.0,
					MinigameShell.BRASS if closed_seam else UITheme.INK)

	func _dot(key: String) -> Vector2:
		var parts := key.split(",")
		return screen.dot_position(int(parts[0]), int(parts[1]))
