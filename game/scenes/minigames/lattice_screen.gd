extends Control
## The Unpicking board (minigames.md #4).
##
## Threads lie across the page in a real stack. Where two cross, the one on
## top is drawn over the other AND casts its shadow onto it — the same way a
## cord lying on a cord looks in a hand. That stack IS the puzzle: a thread
## with nothing crossing above it slides out.
##
## Owner 2026-08-13: "the minigame is trivial if the legal threads become red
## if they are legal… make it a better animation so the player need to
## determine (and can determine) dependencies without the strands turning
## different colors. Turning red is fine for the tutorial game."
##
## So colour is IDENTITY here, never legality: each thread keeps its own dyed
## shade so it can be followed across the page, and nothing on the board
## announces which one is free. Reading the stack is the whole game. The one
## exception is a lattice with `teach_free` in its data (the first one the
## player ever meets) and any board while the lesson is actually playing —
## there the free threads do wear brass and a warm tint, because a lesson that
## cannot point at an example teaches nothing.
##
## Feedback is motion instead: a freed thread SLIDES out along its own line
## with a hiss, and a trapped one twangs — it and everything lying across it
## shiver against each other, which is the answer to "why not that one?".

signal closed

const TAP_RADIUS := 30.0
## How long a freed thread takes to slide off the page, and how long a twang
## keeps shivering. Both are feedback, not delay: nothing waits on them.
const SLIDE_TIME := 0.34
const TWANG_TIME := 0.5
## The dyed shades the lattice is strung with. Identity only — which shade a
## thread gets never depends on whether it can be pulled.
const THREAD_DYES := ["#8c4a3a", "#4a6a7a", "#6a6a3a", "#7a5a8a", "#8a7a4a",
	"#3a6a5a", "#7a4a5a", "#5a5a7a"]

var state: LatticeState
var lattice: Dictionary = {}
var coach_steps: Array = []
var coach_auto := false
var coach: Coach = null

var _status: Label
var _board: Control
var _help: Button
var _alarm_row: MinigameShell.PipRow
var _flash: Array[String] = []
var _markers: Dictionary = {}
var _note := ""
var _finished := false
## Threads mid-slide: id -> how far out they are, 0 to 1. They are already
## gone from the rules; this is only the picture catching up.
var _sliding: Dictionary = {}
## How hard the lattice is still shivering after a refused pull, 1 down to 0.
var _twang := 0.0


func setup(lattice_data: Dictionary) -> void:
	lattice = lattice_data
	state = LatticeState.create(lattice_data)


func _ready() -> void:
	var shell := MinigameShell.build(self, String(lattice.get("name", "")),
		func() -> void: closed.emit())
	_status = shell["status"]
	_board = shell["board"]
	_help = shell["help"]

	# The working hangs on dark cloth (owner 2026-08-11): the same linen as
	# the ward's, modulated toward night so the threads read bright against
	# it — the Unpicking is the killer's verb, and its board is darker.
	var cloth := TextureRect.new()
	cloth.texture = UITheme.tex("ui/ui_cloth_linen")
	cloth.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cloth.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cloth.set_anchors_preset(Control.PRESET_FULL_RECT)
	cloth.clip_contents = true
	cloth.modulate = Color(0.62, 0.58, 0.66)
	cloth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloth.visible = cloth.texture != null
	_board.add_child(cloth)

	var canvas := LatticeBoard.new()
	canvas.screen = self
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.add_child(canvas)
	for key in ["free", "blocked"]:
		var marker := MinigameShell.Marker.new()
		_board.add_child(marker)
		_markers[key] = marker

	var row := MinigameShell.action_row(shell["actions"])
	_alarm_row = MinigameShell.PipRow.new()
	_alarm_row.custom_minimum_size = Vector2(220, MinigameShell.ACTION_HEIGHT)
	_alarm_row.fill_color = MinigameShell.THREAD
	row.add_child(_alarm_row)
	var give_up := MinigameShell.leave_button(Strings.line("minigames.lattice.leave"))
	give_up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	give_up.pressed.connect(func() -> void:
		state.do_command({"type": "give_up"})
		_finish())
	row.add_child(give_up)

	_help.pressed.connect(_start_tutorial)
	_help.visible = not coach_steps.is_empty()
	_refresh()
	if coach_auto:
		_start_tutorial()


func _start_tutorial() -> void:
	coach = MinigameShell.start_tutorial(self, coach_steps, _coach_target, coach)


func _coach_target(key: String) -> Control:
	match key:
		"board": return _board
		"board:alarm": return _alarm_row
		"board:free": return _thread_marker("free", true)
		"board:blocked": return _thread_marker("blocked", false)
	return null


## Points at a thread that is currently free (or currently trapped), so the
## lesson always spotlights a real example rather than a fixed thread id
## that may already be out of the lattice.
func _thread_marker(key: String, want_free: bool) -> Control:
	var marker: MinigameShell.Marker = _markers[key]
	for thread_id in state.remaining():
		if state.can_pull(thread_id) != want_free:
			continue
		var points := thread_points(thread_id)
		marker.cover(Rect2(points[0], Vector2.ZERO).expand(points[1]).grow(18.0))
		return marker
	return null


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


## A thread's dye, fixed by its place in the data. Identity, never legality:
## the same thread is the same colour whether it is trapped or loose, so
## following one across the page is possible and reading one is not free.
func thread_dye(thread_id: String) -> Color:
	var at := state.order.find(thread_id)
	if at < 0:
		at = 0
	return Color(THREAD_DYES[at % THREAD_DYES.size()])


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
	var thread_id := nearest_thread(point)
	if thread_id != "":
		pull_thread(thread_id)


## The one way a thread comes out, whoever asked — a tap, or the tour driving
## a named thread so it can photograph a twang without hoping a coordinate
## lands on the right line.
func pull_thread(thread_id: String) -> void:
	if Minigame.is_over(state.outcome) or not state.threads.has(thread_id):
		return
	var result := state.do_command({"type": "pull", "thread": thread_id})
	# A refused pull SHIVERS what is holding it down — the puzzle teaches
	# itself rather than making the player guess at an invisible rule.
	var pulled: bool = result.get("pulled", true)
	_flash.clear()
	if not pulled:
		for blocker in result.get("blocked_by", []):
			_flash.append(String(blocker))
		_flash.append(thread_id)
		_start_twang()
	else:
		_start_slide(thread_id)
	_note = Strings.line("minigames.lattice.free") if pulled \
		else Strings.line("minigames.lattice.twang")
	if pulled and coach != null:
		coach.notify("board")
	_refresh()


## A freed thread does not blink out of existence: it draws off the page along
## its own line, which is the one moment the player gets to see that it really
## was lying loose on top.
func _start_slide(thread_id: String) -> void:
	_sliding[thread_id] = 0.0
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void:
		_sliding[thread_id] = value
		_redraw_board(), 0.0, 1.0, SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_sliding.erase(thread_id)
		_redraw_board())


func _start_twang() -> void:
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void:
		_twang = value
		_redraw_board(), 1.0, 0.0, TWANG_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _redraw_board() -> void:
	for child in _board.get_children():
		child.queue_redraw()


func flashing() -> Array[String]:
	return _flash


func sliding() -> Dictionary:
	return _sliding


func twang() -> float:
	return _twang


## Whether the board may say out loud which threads are free. True only on
## the lattice the player meets first (`teach_free` in its data) and while a
## lesson is actually running — everywhere else, reading the stack is the
## game and colouring the answer in would be playing it for them.
func revealing_free() -> bool:
	return bool(lattice.get("teach_free", false)) \
		or (coach != null and is_instance_valid(coach))


func _refresh() -> void:
	var threshold := int(lattice.get("alarm_threshold", 0))
	_alarm_row.set_pips(state.alarm, maxi(threshold, 1))
	var parts: Array[String] = [Strings.line("minigames.lattice.status", [
		state.pulled.size(), state.order.size(), state.alarm, threshold])]
	if _note != "":
		parts.append(_note)
	if not state.trembling.is_empty():
		parts.append(Strings.line("minigames.lattice.status_shifted"))
	_status.text = "   ·   ".join(parts)
	for child in _board.get_children():
		child.queue_redraw()
	if Minigame.is_over(state.outcome):
		_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if coach != null and is_instance_valid(coach):
		coach.queue_free()
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

	const WIDTH := 11.0

	func _draw() -> void:
		var state: LatticeState = screen.state
		var sliding: Dictionary = screen.sliding()
		# Threads still on the page, PLUS the ones mid-slide (the rules let go
		# of those the moment they came free; the picture has not yet).
		var showing: Array[String] = state.remaining()
		for thread_id in sliding:
			if not showing.has(String(thread_id)):
				showing.append(String(thread_id))
		# Bottom of the stack first: a thread is drawn AFTER everything it
		# lies over, so the picture is a real stack and the crossing needs no
		# annotation. This replaces the drawn gaps, which said the same thing
		# in a language the player had to be taught.
		for thread_id in _stack_order(state, showing):
			_draw_thread(state, thread_id, sliding)
		# The pins the working is strung between: every thread, both ends, so
		# a pin is furniture and never a hint.
		for thread_id in showing:
			var points: Array = screen.thread_points(thread_id)
			var slide: float = float(sliding.get(thread_id, 0.0))
			if slide > 0.0:
				continue
			for end in [points[0], points[1]]:
				draw_circle(end, 7.0, Color("5a4a3a"))
				draw_circle(end + Vector2(-1.5, -1.5), 3.0, Color("a99c82"))

	## Painter's order: everything a thread lies over comes first.
	func _stack_order(state: LatticeState, showing: Array[String]) -> Array[String]:
		var ordered: Array[String] = []
		var seen := {}
		for thread_id in showing:
			_visit(state, thread_id, showing, seen, ordered)
		return ordered

	func _visit(state: LatticeState, thread_id: String, showing: Array[String],
			seen: Dictionary, ordered: Array[String]) -> void:
		if seen.has(thread_id):
			return
		seen[thread_id] = true   # marked BEFORE recursing: a cycle stops here
		for under in state._over.get(thread_id, {}):
			if showing.has(String(under)):
				_visit(state, String(under), showing, seen, ordered)
		ordered.append(thread_id)

	## One thread: its shadow on whatever it lies over, its own dyed cord, and
	## a sheen along the top of it. The shadow is what carries the over/under
	## reading — a cord with something across it is in shade there.
	func _draw_thread(state: LatticeState, thread_id: String,
			sliding: Dictionary) -> void:
		var points: Array = screen.thread_points(thread_id)
		var a: Vector2 = points[0]
		var b: Vector2 = points[1]
		var slide: float = float(sliding.get(thread_id, 0.0))
		if slide > 0.0:
			# Out along its own line, and off the page: the hiss, drawn.
			var run := (b - a)
			a += run * slide
			b += run * (1.0 + slide * 0.4)
		var colour: Color = screen.thread_dye(thread_id)
		var width := WIDTH
		var alpha := 1.0 - slide
		# A refused pull shivers the thread and everything lying across it,
		# perpendicular to its own run — the twang, and the only answer the
		# board ever gives to "why not that one?".
		var shake: float = screen.twang()
		if shake > 0.0 and screen.flashing().has(thread_id):
			var normal := (b - a).orthogonal().normalized()
			var swing := sin(shake * 34.0) * shake * 7.0
			a += normal * swing
			b += normal * swing
		if state.trembling.has(thread_id):
			colour = Color("2b6ea8")     # it just re-crossed: look again
		# The tutorial's exception (owner: "turning red is fine for the
		# tutorial game"): the first lattice, and any board mid-lesson, says
		# which threads are loose. Everywhere else the stack says it.
		if screen.revealing_free() and state.can_pull(thread_id):
			colour = MinigameShell.THREAD
			width = WIDTH + 2.0
		draw_line(a + Vector2(3.0, 4.0), b + Vector2(3.0, 4.0),
			Color(0.1, 0.07, 0.05, 0.42 * alpha), width + 5.0, true)
		draw_line(a, b, Color(colour, alpha), width, true)
		draw_line(a + Vector2(-1.0, -1.6), b + Vector2(-1.0, -1.6),
			Color(colour.lightened(0.34), 0.7 * alpha), width * 0.32, true)
		if screen.revealing_free() and state.can_pull(thread_id) and slide <= 0.0:
			draw_circle(a, 9.0, MinigameShell.BRASS)
