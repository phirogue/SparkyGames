extends Control
## Seam & Stitch prototype board — geometry only, no art (minigames.md #1).
##
## Dots, clue numbers and thread. Tap an edge to sew it; tap it again to
## unpick. The seam draws as a real line between dots and goes taut (thicker,
## brass-pinned) the moment it closes.
##
## Mirror mode flips the CLUES horizontally, not the grid: the player sews
## the seam they see while reading numbers written the other way round. The
## number's COLOUR follows the square it truly belongs to, not the square it
## sits over — that is the trick, and getting it the other way round is why
## the owner reported the mirror chart as making no sense (2026-08-09).
##
## Everything on this page grew at that same pass: the clue numbers scale off
## the cell instead of sitting at a fixed 30px, the guide lines are drawn
## through MinigameShell.guide_line (a 1px un-antialiased line lost the whole
## right-hand column and bottom row on the mobile renderer), a satisfied clue
## goes green with a ring instead of fading to a grey nobody could see, and
## Squint says something useful for its paw.

signal closed

const TAP_RADIUS := 34.0   # generous: fingers, not mice
## The mirror rule is a banner across the top of the board, not a footnote in
## the status line: it changes how every number on the page is read.
const BANNER_HEIGHT := 92.0

var state: StitchState
var chart: Dictionary = {}
## Set by game.gd from data/minigame_tutorials.json before the screen enters
## the tree. Empty means the "?" button hides itself.
var coach_steps: Array = []
var coach_auto := false
var coach: Coach = null

var _board: Control
var _status: Label
var _squint_button: Button
var _help: Button
var _markers: Dictionary = {}      # tutorial target key -> MinigameShell.Marker
var _note := ""                    # what Squint last said, in words
var _origin := Vector2.ZERO
var _step := 0.0
var _finished := false


func setup(chart_data: Dictionary) -> void:
	chart = chart_data
	state = StitchState.create(chart_data)


func _ready() -> void:
	var shell := MinigameShell.build(self, String(chart.get("name", "")),
		func() -> void: closed.emit())
	_status = shell["status"]
	_board = shell["board"]
	_help = shell["help"]

	var canvas := StitchBoard.new()
	canvas.screen = self
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.add_child(canvas)
	for key in ["clue", "mirror"]:
		var marker := MinigameShell.Marker.new()
		_board.add_child(marker)
		_markers[key] = marker

	var row := MinigameShell.action_row(shell["actions"])
	_squint_button = MinigameShell.aid_button("")
	_squint_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_squint_button.pressed.connect(_on_squint)
	row.add_child(_squint_button)
	var give_up := MinigameShell.leave_button(Strings.line("minigames.stitch.leave"))
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


## Buttons resolve to themselves; board features to an invisible marker laid
## over the drawn thing, positioned fresh each time so it follows the layout.
func _coach_target(key: String) -> Control:
	match key:
		"squint": return _squint_button
		"board": return _board
		"board:clue": return _place_clue_marker()
		"board:mirror": return _place_mirror_marker()
	return null


func _place_clue_marker() -> Control:
	var marker: MinigameShell.Marker = _markers["clue"]
	var cell := _first_clue_cell()
	marker.cover(Rect2(dot_position(cell.x, cell.y),
		Vector2(_step, _step)).grow(6.0))
	return marker


func _place_mirror_marker() -> Control:
	var marker: MinigameShell.Marker = _markers["mirror"]
	marker.cover(Rect2(0, 0, _board.size.x, BANNER_HEIGHT))
	return marker


func _first_clue_cell() -> Vector2i:
	for row in state.height:
		for col in state.width:
			if clue_at(row, col) != null:
				return Vector2i(row, col)
	return Vector2i(0, 0)


## Board geometry: the largest square cell that fits the zone, centred under
## the mirror banner when there is one.
func _layout(board_size: Vector2) -> void:
	var cols := state.width
	var rows := state.height
	if cols <= 0 or rows <= 0:
		return
	var top := BANNER_HEIGHT if state.mirrored else 0.0
	var usable := Vector2(board_size.x, board_size.y - top)
	# A third of a cell of margin, not a whole one: the clue numbers scale off
	# the cell, so every pixel the grid gives up is type the owner asked to
	# make bigger. A 4x4 goes from 115px cells to 134.
	_step = minf(usable.x / (cols + 0.3), usable.y / (rows + 0.3))
	var used := Vector2(_step * cols, _step * rows)
	_origin = Vector2((usable.x - used.x) * 0.5,
		top + (usable.y - used.y) * 0.5)


func dot_position(row: int, col: int) -> Vector2:
	return _origin + Vector2(col * _step, row * _step)


## Which CELL a clue drawn at (row, col) really constrains. On a mirror chart
## the numbers are pinned on backward, so the one at the far left belongs to
## the square at the far right — and its colour has to follow it there.
func clue_source_col(col: int) -> int:
	return (state.width - 1 - col) if state.mirrored else col


func clue_at(row: int, col: int) -> Variant:
	return state.clues.get("%d,%d" % [row, clue_source_col(col)], null)


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
	var sewing := not state.sewn.has(edge_id)
	var result := state.do_command({"type": "unpick" if not sewing else "sew",
		"edge": edge_id})
	if result.get("ok", false):
		_note = ""
		if coach != null:
			coach.notify("board")
	_refresh()


func _on_squint() -> void:
	if Minigame.is_over(state.outcome):
		return
	var result := state.do_command({"type": "squint"})
	if not result.get("ok", false):
		_note = Strings.line("minigames.stitch.squint_none")
	elif result.get("clean", false):
		_note = Strings.line("minigames.stitch.squint_clean")
	elif String(result.get("wrong", "")) != "" and String(result.get("sew", "")) != "":
		_note = Strings.line("minigames.stitch.squint_both")
	elif String(result.get("wrong", "")) != "":
		_note = Strings.line("minigames.stitch.squint_wrong")
	else:
		_note = Strings.line("minigames.stitch.squint_sew")
	_refresh()


func note() -> String:
	return _note


func _refresh() -> void:
	var total: int = state.clues.size()
	# A closed seam has no advice left worth reading. (Mid-puzzle, the note is
	# cleared by the move that acts on it — see on_board_tap.)
	if state.outcome == Minigame.Outcome.SUCCESS:
		_note = ""
	var headline := Strings.line("minigames.stitch.status_done") \
		if state.outcome == Minigame.Outcome.SUCCESS \
		else Strings.line("minigames.stitch.status",
			[state.clues_satisfied(), total])
	_status.text = headline if _note == "" else "%s   ·   %s" % [headline, _note]
	_squint_button.text = Strings.line("minigames.stitch.squint", [state.paws]) \
		if state.paws > 0 else Strings.line("minigames.stitch.squint_spent")
	_squint_button.disabled = state.paws < 1
	queue_redraw()
	for child in _board.get_children():
		child.queue_redraw()
	if Minigame.is_over(state.outcome):
		_finish()


## The outcome card waits a beat. A seam that closes has to be SEEN closing:
## the reward for solving it used to be a grey overlay in the same frame,
## which reads as "nothing happened".
func _finish() -> void:
	if _finished:
		return
	_finished = true
	if coach != null and is_instance_valid(coach):
		coach.queue_free()
	if state.outcome == Minigame.Outcome.SUCCESS:
		await get_tree().create_timer(0.75).timeout
		if not is_instance_valid(self):
			return
	MinigameShell.show_outcome(self, state.outcome, chart,
		func() -> void: closed.emit())


## The drawn board. Dots, clues, thread — and the taut seam when it closes.
class StitchBoard extends Control:
	## Inner classes do not see the outer script's constants, so the banner's
	## geometry is declared once here and read back by the screen's _layout.
	const BANNER := 92.0
	const BANNER_FONT := 22

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
		var step: float = screen._step
		var closed_seam := state.outcome == Minigame.Outcome.SUCCESS

		if state.mirrored:
			_draw_mirror_banner()

		# Unsewn edges: guides, so the board reads as a grid of choices. Drawn
		# through the shell at a real width — see MinigameShell.guide_line.
		for edge_id in state.all_edges():
			if state.sewn.has(edge_id):
				continue
			var dots := state.edge_dots(edge_id)
			MinigameShell.guide_line(self, _dot(dots[0]), _dot(dots[1]))

		# Squint's answer, under everything else so the thread stays readable:
		# the gap the seam runs through, drawn as a fat blue ghost.
		if state.squint_sew != "":
			var hint_dots := state.edge_dots(state.squint_sew)
			draw_line(_dot(hint_dots[0]), _dot(hint_dots[1]),
				Color("2b6ea855"), 16.0, true)

		# Clue numbers. Size comes off the cell, not a constant, so a 2x2 hoop
		# and a 6x6 sampler both read at arm's length.
		var font := UITheme.display_font()
		var clue_size := int(clampf(step * 0.42, 28.0, 58.0))
		for row in state.height:
			for col in state.width:
				var clue: Variant = screen.clue_at(row, col)
				if clue == null:
					continue
				var source_col: int = screen.clue_source_col(col)
				var centre: Vector2 = (screen.dot_position(row, col)
					+ screen.dot_position(row + 1, col + 1)) * 0.5
				var colour := UITheme.INK
				if state.clue_broken(row, source_col):
					colour = MinigameShell.THREAD
					draw_arc(centre, step * 0.30, 0, TAU, 28,
						MinigameShell.THREAD, 3.0, true)
				elif state.clue_satisfied(row, source_col):
					colour = MinigameShell.DONE
					# Filled halo AND a ring: the old fade-to-grey was, in the
					# owner's words, barely noticeable.
					draw_circle(centre, step * 0.30, MinigameShell.DONE_SOFT)
					draw_arc(centre, step * 0.30, 0, TAU, 28,
						MinigameShell.DONE, 3.0, true)
				var text := str(int(clue))
				var text_size := font.get_string_size(text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, clue_size)
				draw_string(font,
					centre + Vector2(-text_size.x * 0.5, text_size.y * 0.35),
					text, HORIZONTAL_ALIGNMENT_LEFT, -1, clue_size, colour)

		# The thread itself.
		for edge_id in state.sewn:
			var dots := state.edge_dots(String(edge_id))
			var width := 11.0 if closed_seam else 8.0
			var colour := MinigameShell.THREAD
			if String(edge_id) == state.squint_wrong:
				colour = Color("2b6ea8")   # the squint's callout, unmistakable
			draw_line(_dot(dots[0]), _dot(dots[1]), colour, width, true)
		# A stitch Squint says to take out gets crossed, not merely tinted.
		if state.squint_wrong != "":
			var centre: Vector2 = screen.edge_midpoint(state.squint_wrong)
			var arm := step * 0.16
			draw_line(centre - Vector2(arm, arm), centre + Vector2(arm, arm),
				Color("2b6ea8"), 5.0, true)
			draw_line(centre - Vector2(arm, -arm), centre + Vector2(arm, -arm),
				Color("2b6ea8"), 5.0, true)

		# Dots last, on top of the thread, brass once the seam is closed.
		for row in state.height + 1:
			for col in state.width + 1:
				draw_circle(screen.dot_position(row, col), 6.0,
					MinigameShell.BRASS if closed_seam else UITheme.INK)

	## The mirror rule, said on the page every second it applies.
	func _draw_mirror_banner() -> void:
		var text := Strings.line("minigames.stitch.mirror_banner")
		var font := UITheme.body_font()
		var box := Rect2(0, 0, size.x, BANNER - 12.0)
		draw_rect(box, Color("2b6ea81a"))
		draw_rect(box, Color("2b6ea8"), false, 2.0)
		draw_multiline_string(font, Vector2(14.0, 32.0), text,
			HORIZONTAL_ALIGNMENT_CENTER, size.x - 28.0, BANNER_FONT, -1,
			Color("1f4f7a"))
		# The axis the numbers are reflected in, drawn so the rule is visible
		# and not only stated.
		var mid := size.x * 0.5
		draw_dashed_line(Vector2(mid, BANNER - 6.0), Vector2(mid, size.y),
			Color("2b6ea833"), 2.0, 12.0)

	func _dot(key: String) -> Vector2:
		var parts := key.split(",")
		return screen.dot_position(int(parts[0]), int(parts[1]))
