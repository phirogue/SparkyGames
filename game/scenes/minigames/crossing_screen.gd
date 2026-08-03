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

signal closed

var state: CrossingState
var crossing: Dictionary = {}

var _status: Label
var _board: Control
var _catalog: Catalog
var _last_line := ""


func setup(catalog: Catalog, crossing_data: Dictionary, seed_value: int,
		config: Dictionary) -> void:
	_catalog = catalog
	crossing = crossing_data
	state = CrossingState.create(catalog, seed_value, crossing_data, config)


func _ready() -> void:
	var shell := MinigameShell.build(self, String(crossing.get("name", "A Crossing")),
		func() -> void: closed.emit())
	_status = shell["status"]
	_board = shell["board"]

	var canvas := CrossingBoard.new()
	canvas.screen = self
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.add_child(canvas)

	var press := UITheme.amber_button("Press On", 24, Vector2(0, 96))
	press.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	press.pressed.connect(_command.bind({"type": "press_on"}))
	shell["actions"].add_child(press)
	var peek := UITheme.dark_button("Pick the Line", 20, Vector2(0, 96))
	peek.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	peek.pressed.connect(_command.bind({"type": "pick_line"}))
	shell["actions"].add_child(peek)
	var shelter := UITheme.dark_button("Shelter", 20, Vector2(0, 96))
	shelter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelter.pressed.connect(_command.bind({"type": "shelter"}))
	shell["actions"].add_child(shelter)
	var away := UITheme.dark_button("Slip Away", 20, Vector2(0, 96))
	away.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	away.pressed.connect(_command.bind({"type": "slip_away"}))
	shell["actions"].add_child(away)

	_refresh()


func _command(command: Dictionary) -> void:
	if Minigame.is_over(state.outcome):
		return
	var result := state.do_command(command)
	if not result.get("ok", false):
		_last_line = String(result.get("error", ""))
	elif result.get("slipped", false):
		_last_line = "The gust takes it. %d back, and it stings." % int(result.get("lost", 0))
	elif command["type"] == "press_on":
		_last_line = "On, by %d." % int(result.get("gain", 0))
	elif command["type"] == "pick_line":
		_last_line = "The sky says: %s next." % Catalog.humour_name(
			String(result.get("next_gust", "")))
	elif command["type"] == "shelter":
		_last_line = "Sheltered. A card burned waiting."
	_refresh()


func last_line() -> String:
	return _last_line


func card_humour(card_id: String) -> String:
	return String(_catalog.energy_cards.get(card_id, {}).get("humour", ""))


func _refresh() -> void:
	_status.text = "%d of %d home   ·   sheltered %d   ·   gust: %s   ·   hp %d   ·   paw %d" % [
		state.progress, state.length, state.sheltered,
		Catalog.humour_name(state.gust), state.player_hp, state.hand.size()]
	for child in _board.get_children():
		child.queue_redraw()
	if Minigame.is_over(state.outcome):
		MinigameShell.show_outcome(self, state.outcome, crossing,
			func() -> void: closed.emit())


class CrossingBoard extends Control:
	var screen

	const HUMOUR_COLOURS := {
		"ferocity": "#a24a3a",
		"guile": "#8a7a2a",
		"shadow": "#3a4a6a",
		"mysticism": "#6a4a7a",
	}

	func _draw() -> void:
		var state: CrossingState = screen.state
		var top := 20.0

		# The route: one pip per step, filled to progress, brass to sheltered.
		var per_row := 17
		var pip_gap := (size.x - 40.0) / float(per_row)
		for i in state.length:
			var row := i / per_row
			var col := i % per_row
			var centre := Vector2(24.0 + col * pip_gap, top + row * 34.0)
			if i < state.sheltered:
				draw_circle(centre, 9.0, MinigameShell.BRASS)
			elif i < state.progress:
				draw_circle(centre, 9.0, MinigameShell.THREAD)
			else:
				draw_arc(centre, 9.0, 0, TAU, 20, Color("a99c82"), 2.0)
		var rows := ceili(float(state.length) / per_row)
		var cursor := top + rows * 34.0 + 24.0

		# The posted gust: a big plate in its humour's colour.
		var gust_rect := Rect2(20.0, cursor, size.x - 40.0, 86.0)
		draw_rect(gust_rect, Color(HUMOUR_COLOURS.get(state.gust, "#3a4a6a")))
		draw_rect(gust_rect, UITheme.INK, false, 3.0)
		var font := UITheme.display_font()
		var gust_text := "the gust owns  " + Catalog.humour_name(state.gust).to_upper()
		var text_width := font.get_string_size(gust_text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 28).x
		draw_string(font, Vector2(gust_rect.get_center().x - text_width * 0.5,
			gust_rect.position.y + 54.0), gust_text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 28, Color("f2e4c8"))
		cursor += 110.0

		# The paw. Cards the storm is reaching for get a ring.
		var card_width := 74.0
		var start_x := (size.x - state.hand.size() * (card_width + 8.0)) * 0.5
		for i in state.hand.size():
			var humour: String = screen.card_humour(state.hand[i])
			var rect := Rect2(start_x + i * (card_width + 8.0), cursor,
				card_width, 100.0)
			draw_rect(rect, Color(HUMOUR_COLOURS.get(humour, "#3a4a6a")))
			draw_rect(rect, UITheme.INK, false, 2.0)
			if humour == state.gust:
				draw_rect(rect.grow(5.0), MinigameShell.THREAD, false, 4.0)
			var initial := Catalog.humour_name(humour).substr(0, 1)
			draw_string(font, rect.position + Vector2(26.0, 62.0), initial,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("f2e4c8"))
		cursor += 118.0

		var line: String = screen.last_line()
		if line != "":
			draw_string(UITheme.italic_font(), Vector2(24.0, cursor), line,
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 48.0, 22, UITheme.INK)
