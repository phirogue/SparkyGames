extends Control
## The Unpicking prototype board — geometry only (minigames.md #4).
##
## Threads are straight lines across the page; where two cross, the one that
## lies OVER is drawn unbroken and the one beneath is drawn with a gap. That
## single visual IS the puzzle: a thread you can see all the way along has
## nothing on top of it, so it can be pulled.
##
## Tap a thread to pull it. A blocked pull twangs — the blockers flash and
## the Alarm climbs — but it is never rejected, because learning which
## thread is trapped is how the puzzle is played.

signal closed

const TAP_RADIUS := 30.0
## Half-width of the break drawn in an under-thread. This is the ONLY thing
## telling the player which thread is trapped, so it is deliberately wider
## than looks tidy — at 9px the over/under barely read on a phone.
const GAP := 14.0

var state: LatticeState
var lattice: Dictionary = {}

var _status: Label
var _board: Control
var _alarm_row: MinigameShell.PipRow
var _flash: Array[String] = []


func setup(lattice_data: Dictionary) -> void:
	lattice = lattice_data
	state = LatticeState.create(lattice_data)


func _ready() -> void:
	var shell := MinigameShell.build(self, String(lattice.get("name", "A Working")),
		func() -> void: closed.emit())
	_status = shell["status"]
	_board = shell["board"]

	var canvas := LatticeBoard.new()
	canvas.screen = self
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.add_child(canvas)

	_alarm_row = MinigameShell.PipRow.new()
	_alarm_row.custom_minimum_size = Vector2(200, 96)
	_alarm_row.fill_color = MinigameShell.THREAD
	shell["actions"].add_child(_alarm_row)
	var give_up := UITheme.dark_button("Step back", 24, Vector2(200, 96))
	give_up.pressed.connect(func() -> void:
		state.do_command({"type": "give_up"})
		_finish())
	shell["actions"].add_child(give_up)

	_refresh()


## Thread endpoints come from the data as grid coordinates in a 0..3 box;
## the board maps that box onto the zone with a margin.
func thread_points(thread_id: String) -> Array[Vector2]:
	var path: Array = state.threads[thread_id].get("path", [])
	var points: Array[Vector2] = []
	var board_size := _board.size
	var inset := 40.0
	for point in path:
		var u := float(point[1]) / 3.0
		var v := float(point[0]) / 3.0
		points.append(Vector2(
			inset + u * (board_size.x - inset * 2.0),
			inset + v * (board_size.y - inset * 2.0)))
	while points.size() < 2:
		points.append(Vector2(inset, inset))
	return points


func nearest_thread(point: Vector2) -> String:
	var best := ""
	var best_distance := TAP_RADIUS
	for thread_id in state.remaining():
		var points := thread_points(thread_id)
		var distance := _distance_to_segment(point, points[0], points[1])
		if distance < best_distance:
			best_distance = distance
			best = thread_id
	return best


static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared <= 0.0:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_to(a + ab * t)


func on_board_tap(point: Vector2) -> void:
	if Minigame.is_over(state.outcome):
		return
	var thread_id := nearest_thread(point)
	if thread_id == "":
		return
	var result := state.do_command({"type": "pull", "thread": thread_id})
	# A refused pull flashes what is holding it down — the puzzle teaches
	# itself rather than making the player guess at an invisible rule.
	_flash = result.get("blocked_by", []) if not result.get("pulled", true) else []
	_refresh()


func flashing() -> Array[String]:
	return _flash


func _refresh() -> void:
	var threshold := int(lattice.get("alarm_threshold", 0))
	_alarm_row.set_pips(state.alarm, maxi(threshold, 1))
	_status.text = "%d of %d threads out   ·   alarm %d/%d%s" % [
		state.pulled.size(), state.order.size(), state.alarm, threshold,
		"   ·   something shifted" if not state.trembling.is_empty() else ""]
	for child in _board.get_children():
		child.queue_redraw()
	if Minigame.is_over(state.outcome):
		_finish()


func _finish() -> void:
	MinigameShell.show_outcome(self, state.outcome, lattice,
		func() -> void: closed.emit())


class LatticeBoard extends Control:
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
		var state: LatticeState = screen.state
		var remaining := state.remaining()
		var flashing: Array = screen.flashing()
		for thread_id in remaining:
			var points: Array = screen.thread_points(thread_id)
			var a: Vector2 = points[0]
			var b: Vector2 = points[1]
			var free := state.can_pull(thread_id)
			var colour := MinigameShell.THREAD if free else Color("6b5747")
			if flashing.has(thread_id):
				colour = Color("c2884a")     # this is what is holding it down
			if state.trembling.has(thread_id):
				colour = Color("2b6ea8")     # it just re-crossed: look again
			var width := 8.0 if free else 6.0
			# Break the line wherever another remaining thread lies OVER it.
			var breaks: Array[Vector2] = []
			for other in remaining:
				if other == thread_id:
					continue
				if not state._over.get(other, {}).has(thread_id):
					continue
				var other_points: Array = screen.thread_points(other)
				var crossing = _intersection(a, b, other_points[0], other_points[1])
				if crossing != null:
					breaks.append(crossing)
			if breaks.is_empty():
				draw_line(a, b, colour, width, true)
			else:
				_draw_broken(a, b, breaks, colour, width)
			# A pull-ready thread gets a brass tag at its head.
			if free:
				draw_circle(a, 9.0, MinigameShell.BRASS)

	## Draws a-to-b but skipping a gap around each crossing point, which is
	## how "this one is underneath" reads without any art.
	func _draw_broken(a: Vector2, b: Vector2, breaks: Array[Vector2],
			colour: Color, width: float) -> void:
		var direction := (b - a).normalized()
		var total := a.distance_to(b)
		var stops: Array[float] = []
		for point in breaks:
			stops.append(a.distance_to(point))
		stops.sort()
		var cursor := 0.0
		for stop in stops:
			var segment_end := maxf(cursor, stop - GAP)
			if segment_end > cursor:
				draw_line(a + direction * cursor, a + direction * segment_end,
					colour, width, true)
			cursor = minf(total, stop + GAP)
		if cursor < total:
			draw_line(a + direction * cursor, b, colour, width, true)

	## Segment intersection, or null when they do not cross.
	static func _intersection(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2):
		var d1 := p2 - p1
		var d2 := p4 - p3
		var denominator := d1.cross(d2)
		if absf(denominator) < 0.0001:
			return null
		var t := (p3 - p1).cross(d2) / denominator
		var u := (p3 - p1).cross(d1) / denominator
		if t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0:
			return null
		return p1 + d1 * t
