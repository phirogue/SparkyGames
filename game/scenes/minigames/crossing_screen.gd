extends Control
## The Long Way Round prototype board — geometry only (minigames.md #5).
##
## The owner's contract is reuse: same hand, same paws, same spent pile. So
## the page keeps the battle skeleton and swaps two things — the opponent
## becomes a route track, and the action row becomes the four crossing verbs.
##
## The gust is a posted humour. Cards in the paw that match it are the ones
## the storm is reaching for, and they are drawn ringed, so pressing on is an
## informed gamble rather than a coin toss.
##
## Which nobody could have deduced: the owner reported the module as making
## no sense (2026-08-09). It now teaches itself over its own board from
## data/minigame_tutorials.json, the four verbs sit in two labelled rows big
## enough to read, and the track says what red and brass mean.

signal closed

var state: CrossingState
var crossing: Dictionary = {}
var coach_steps: Array = []
var coach_auto := false
var coach: Coach = null

var _status: Label
var _board: Control
var _help: Button
var _catalog: Catalog
var _buttons: Dictionary = {}      # verb -> Button
var _markers: Dictionary = {}
var _last_line := ""
var _finished := false


func setup(catalog: Catalog, crossing_data: Dictionary, seed_value: int,
		config: Dictionary) -> void:
	_catalog = catalog
	crossing = crossing_data
	state = CrossingState.create(catalog, seed_value, crossing_data, config)


func _ready() -> void:
	var shell := MinigameShell.build(self, String(crossing.get("name", "")),
		func() -> void: closed.emit())
	_status = shell["status"]
	_board = shell["board"]
	_help = shell["help"]

	var canvas := CrossingBoard.new()
	canvas.screen = self
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.add_child(canvas)
	for key in ["track", "gust", "paw"]:
		var marker := MinigameShell.Marker.new()
		_board.add_child(marker)
		_markers[key] = marker

	# Four verbs, two rows: the action zone is a fixed 168 (law 6) and four
	# buttons across one row left no room for a word anybody could read.
	var top := MinigameShell.action_row(shell["actions"])
	_add_verb(top, "press", "minigames.crossing.press", {"type": "press_on"}, true)
	_add_verb(top, "shelter", "minigames.crossing.shelter", {"type": "shelter"}, true)
	var bottom := MinigameShell.action_row(shell["actions"])
	_add_verb(bottom, "peek", "minigames.crossing.peek", {"type": "pick_line"}, true)
	_add_verb(bottom, "away", "minigames.crossing.away", {"type": "slip_away"}, false)

	_help.pressed.connect(_start_tutorial)
	_help.visible = not coach_steps.is_empty()
	_refresh()
	if coach_auto:
		_start_tutorial()


func _add_verb(row: HBoxContainer, key: String, string_key: String,
		command: Dictionary, aid: bool) -> void:
	var button: Button = MinigameShell.aid_button(Strings.line(string_key),
			MinigameShell.ACTION_FONT_HALF, MinigameShell.ACTION_HEIGHT_HALF) \
		if aid else MinigameShell.leave_button(Strings.line(string_key),
			MinigameShell.ACTION_FONT_HALF, MinigameShell.ACTION_HEIGHT_HALF)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_command.bind(command, key))
	row.add_child(button)
	_buttons[key] = button


func _start_tutorial() -> void:
	coach = MinigameShell.start_tutorial(self, coach_steps, _coach_target, coach)


func _coach_target(key: String) -> Control:
	if _buttons.has(key):
		return _buttons[key]
	match key:
		"board": return _board
		"board:track": return _cover("track", CrossingBoard.TRACK_BAND)
		"board:gust": return _cover("gust", CrossingBoard.GUST_BAND)
		"board:paw": return _cover("paw", CrossingBoard.PAW_BAND)
	return null


func _cover(key: String, band: Vector2) -> Control:
	var marker: MinigameShell.Marker = _markers[key]
	marker.cover(Rect2(0, band.x, _board.size.x, band.y - band.x))
	return marker


func _command(command: Dictionary, key: String) -> void:
	if Minigame.is_over(state.outcome):
		return
	var result := state.do_command(command)
	if not result.get("ok", false):
		_last_line = String(result.get("error", ""))
	elif result.get("slipped", false):
		_last_line = Strings.line("minigames.crossing.slipped",
			[int(result.get("lost", 0))])
	elif command["type"] == "press_on":
		_last_line = Strings.line("minigames.crossing.gained",
			[int(result.get("gain", 0))])
	elif command["type"] == "pick_line":
		_last_line = Strings.line("minigames.crossing.peeked",
			[Catalog.humour_name(String(result.get("next_gust", "")))])
	elif command["type"] == "shelter":
		_last_line = Strings.line("minigames.crossing.sheltered")
	if result.get("ok", false) and coach != null:
		coach.notify(key)
	_refresh()


func last_line() -> String:
	return _last_line


func card_humour(card_id: String) -> String:
	return String(_catalog.energy_cards.get(card_id, {}).get("humour", ""))


func _refresh() -> void:
	# The gust is a plate the size of a hand in the middle of the board; it
	# does not also need to be in the status line, which wrapped and left
	# "hp" dangling on a line of its own.
	_status.text = Strings.line("minigames.crossing.status", [
		state.progress, state.length, state.sheltered, state.player_hp])
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
	MinigameShell.show_outcome(self, state.outcome, crossing,
		func() -> void: closed.emit())


class CrossingBoard extends Control:
	## Fixed bands down the board, so the tutorial can point at each of them
	## and the drawing never has to guess where the last thing ended. They
	## fill the whole 720: the first pass drew everything at half size and
	## left the bottom half of the page bare.
	const TRACK_BAND := Vector2(10.0, 196.0)
	const GUST_BAND := Vector2(212.0, 336.0)
	const PAW_BAND := Vector2(356.0, 540.0)
	const SAID_TOP := 578.0
	const PIP_RADIUS := 13.0
	const PIP_ROW := 42.0

	const HUMOUR_COLOURS := {
		"ferocity": "#a24a3a",
		"guile": "#8a7a2a",
		"shadow": "#3a4a6a",
		"mysticism": "#6a4a7a",
	}

	var screen

	func _draw() -> void:
		var state: CrossingState = screen.state
		var font := UITheme.display_font()

		# The route: one pip per step, filled to progress, brass to sheltered.
		var per_row := 17
		var pip_gap := (size.x - 40.0) / float(per_row)
		for i in state.length:
			var row: int = i / per_row
			var col: int = i % per_row
			var centre := Vector2(26.0 + col * pip_gap,
				TRACK_BAND.x + 26.0 + row * PIP_ROW)
			if i < state.sheltered:
				draw_circle(centre, PIP_RADIUS, MinigameShell.BRASS)
			elif i < state.progress:
				draw_circle(centre, PIP_RADIUS, MinigameShell.THREAD)
			else:
				draw_arc(centre, PIP_RADIUS, 0, TAU, 22, Color("a99c82"), 2.5)

		# The posted gust: a big plate in its humour's colour.
		var gust_rect := Rect2(20.0, GUST_BAND.x, size.x - 40.0,
			GUST_BAND.y - GUST_BAND.x)
		draw_rect(gust_rect, Color(HUMOUR_COLOURS.get(state.gust, "#3a4a6a")))
		draw_rect(gust_rect, UITheme.INK, false, 3.0)
		var gust_text := Strings.line("minigames.crossing.gust_plate",
			[Catalog.humour_name(state.gust).to_upper()])
		var text_width := font.get_string_size(gust_text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 30).x
		draw_string(font, Vector2(gust_rect.get_center().x - text_width * 0.5,
			gust_rect.get_center().y + 11.0), gust_text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 30, Color("f2e4c8"))

		# The paw. Cards the storm is reaching for get a ring. Card width is
		# derived from how many are held, so a fat paw shrinks to fit instead
		# of running off both edges of the page.
		var held: int = maxi(state.hand.size(), 1)
		var card_width: float = minf(104.0, (size.x - 24.0) / held - 8.0)
		var card_height: float = PAW_BAND.y - PAW_BAND.x
		var start_x := (size.x - state.hand.size() * (card_width + 8.0)) * 0.5
		for i in state.hand.size():
			var humour: String = screen.card_humour(state.hand[i])
			var rect := Rect2(start_x + i * (card_width + 8.0), PAW_BAND.x,
				card_width, card_height)
			draw_rect(rect, Color(HUMOUR_COLOURS.get(humour, "#3a4a6a")))
			draw_rect(rect, UITheme.INK, false, 2.0)
			if humour == state.gust:
				draw_rect(rect.grow(5.0), MinigameShell.THREAD, false, 5.0)
			var initial := Catalog.humour_name(humour).substr(0, 1)
			var glyph := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 44)
			draw_string(font, rect.get_center() + Vector2(-glyph.x * 0.5, 16.0),
				initial, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color("f2e4c8"))

		var line: String = screen.last_line()
		if line != "":
			draw_multiline_string(UITheme.italic_font(), Vector2(24.0, SAID_TOP),
				line, HORIZONTAL_ALIGNMENT_LEFT, size.x - 48.0, 26, -1,
				UITheme.INK)
