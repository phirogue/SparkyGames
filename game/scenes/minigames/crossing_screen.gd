extends Control
## The Long Way Round — the crossing board at the battle screen's standard
## (owner 2026-08-11: "work out the ui and the animations in a similar way to
## the battle screen"). The design contract is unchanged (minigames.md #5):
## same deck, same paws, same spent pile — only the opponent is weather.
##
## The page mirrors the fight it is a sibling of:
##   - the OPPONENT is the crossing itself: the environment's own backdrop in
##     the battle's wood frame, breathing the battle's ambient breath;
##   - the GUST plate and the NEXT-gust chip sit beside it exactly where the
##     enemy's name plate and intent chip sit in a fight — the peek is an
##     intent read, and an unread sky says so;
##   - the ROUTE is a stitched thread across the page: red stitches are
##     ground made, brass knots are ground banked, open holes are the road
##     ahead, with Ash himself (ui_token_ash) walking pip to pip and a lit
##     window (ui_icon_home_lamp) at the end of it;
##   - the HAND is the battle's own card chips (humour frame, glyph, worth),
##     and a card the storm is reaching for wears the gust swirl and
##     flutters — the gamble is readable before it is taken.
##
## Feedback is the battle's vocabulary: floats for ground gained and lost,
## the red wash when the gust bites, settle/pulse on plates that changed.
## Nothing below reads or writes rules state beyond do_command/take_events.

signal closed

## Board geometry (the shell's 720-tall board, 582 wide). Bands are named so
## the tutorial can point at them and the layout never guesses (law 4):
## vignette 0..308, route 320..452, hand 464..604, said 616..720.
const VIGNETTE_SIZE := Vector2(348.0, 308.0)
const GUST_RECT := Rect2(360.0, 0.0, 222.0, 186.0)
const NEXT_RECT := Rect2(360.0, 198.0, 222.0, 110.0)
const ROUTE_RECT := Rect2(0.0, 320.0, 582.0, 132.0)
const HAND_BAND := Vector2(464.0, 604.0)
const SAID_TOP := 616.0
const CARD_SIZE := Vector2(94.0, 128.0)

## The battle screen's own per-humour vocabulary, shared verbatim.
const HUMOUR_COLOURS := {
	"ferocity": Color("a24a3a"),
	"guile": Color("6a6a2a"),
	"shadow": Color("3a4a6a"),
	"mysticism": Color("6a4a7a"),
}
const HUMOUR_GLYPH := {
	"ferocity": "energy_claw",
	"guile": "energy_eye",
	"shadow": "energy_shade",
	"mysticism": "energy_moon",
}
const HUMOUR_FRAME := {
	"ferocity": "ui/ui_frame_card_red",
	"guile": "ui/ui_frame_card_green",
	"shadow": "ui/ui_frame_card_black",
	"mysticism": "ui/ui_frame_card_blue",
}
const PARCHMENT := Color("f2e4c8")

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
var _finished := false
var _booted := false

var _chips: Dictionary = {}        # key -> value Label
var _vignette_art: Control
var _gust_plate: PanelContainer
var _gust_shown := ""              # humour the plate currently wears
var _next_chip: PanelContainer
var _next_shown := "?"             # so the chip only settles when it changes
var _route: RouteCanvas
var _token: TextureRect
var _lamp: TextureRect
var _hand_layer: Control
var _said: Label
var _flash: ColorRect


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
	_build_status_chips()
	_build_board()

	# Four verbs, two rows: the action zone is a fixed 168 (law 6) and four
	# buttons across one row left no room for a word anybody could read.
	var top := MinigameShell.action_row(shell["actions"])
	_add_verb(top, "press", "minigames.crossing.press", {"type": "press_on"}, true)
	_add_verb(top, "shelter", "minigames.crossing.shelter", {"type": "shelter"}, true)
	var bottom := MinigameShell.action_row(shell["actions"])
	_add_verb(bottom, "peek", "minigames.crossing.peek", {"type": "pick_line"}, true)
	_add_verb(bottom, "away", "minigames.crossing.away", {"type": "slip_away"}, false)

	# The battle's red wash, for the moment the gust bites.
	_flash = ColorRect.new()
	_flash.color = Color(0.55, 0.1, 0.06, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.z_index = 50
	add_child(_flash)

	_help.pressed.connect(_start_tutorial)
	_help.visible = not coach_steps.is_empty()
	_refresh()
	_start_ambient()
	if coach_auto:
		_start_tutorial()
	await get_tree().process_frame
	_booted = true


## The battle's status strip in place of the shell's one-line label: an icon
## and a number per reading, big enough to read at arm's length.
func _build_status_chips() -> void:
	_status.visible = false
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH, MinigameShell.ZONE_STATUS)
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var column := _status.get_parent()
	column.add_child(row)
	column.move_child(row, _status.get_index())
	_chips["hp"] = _status_chip(row, "ui/ui_heart_full")
	_divider(row)
	_chips["home"] = _status_chip(row, "ui/ui_token_ash")
	_divider(row)
	_chips["safe"] = _status_chip(row, "ui/ui_seal_gold")
	_divider(row)
	_chips["spool"] = _status_chip(row, "ui/ui_spool")
	_divider(row)
	_chips["paws"] = _status_chip(row, "ui/ui_paw_full")


func _status_chip(parent: Container, icon_id: String) -> Label:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 6)
	parent.add_child(chip)
	var icon := TextureRect.new()
	icon.texture = UITheme.cropped_tex(icon_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(40, 40)
	chip.add_child(icon)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", UITheme.INK)
	chip.add_child(label)
	return label


func _divider(parent: Container) -> void:
	var divider := Label.new()
	divider.text = "|"
	divider.add_theme_font_size_override("font_size", 28)
	divider.add_theme_color_override("font_color", UITheme.INK_FADED)
	parent.add_child(divider)


func _build_board() -> void:
	# The crossing itself, framed like the opponent it is: the environment's
	# own backdrop in the battle's wood frame.
	var environment: Dictionary = _catalog.environments.get(
		String(crossing.get("environment", "")), {})
	_vignette_art = _framed_vignette(String(environment.get("image", "")),
		String(environment.get("name", "the crossing")))
	_vignette_art.position = Vector2.ZERO
	_board.add_child(_vignette_art)

	_gust_plate = PanelContainer.new()
	_gust_plate.position = GUST_RECT.position
	_gust_plate.size = GUST_RECT.size
	_board.add_child(_gust_plate)

	_next_chip = PanelContainer.new()
	_next_chip.position = NEXT_RECT.position
	_next_chip.size = NEXT_RECT.size
	_board.add_child(_next_chip)

	_route = RouteCanvas.new()
	_route.screen = self
	_route.position = ROUTE_RECT.position
	_route.size = ROUTE_RECT.size
	_board.add_child(_route)
	_lamp = TextureRect.new()
	_lamp.texture = UITheme.cropped_tex("ui/ui_icon_home_lamp")
	_lamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lamp.custom_minimum_size = Vector2(44, 44)
	_lamp.size = Vector2(44, 44)
	_lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route.add_child(_lamp)
	_token = TextureRect.new()
	_token.texture = UITheme.cropped_tex("ui/ui_token_ash")
	_token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_token.custom_minimum_size = Vector2(52, 44)
	_token.size = Vector2(52, 44)
	_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route.add_child(_token)

	# Cards get their OWN layer (law 25: rebuildable content never shares a
	# container with siblings something keeps a handle on).
	_hand_layer = Control.new()
	_hand_layer.position = Vector2(0.0, HAND_BAND.x)
	_hand_layer.size = Vector2(UITheme.CONTENT_WIDTH, HAND_BAND.y - HAND_BAND.x)
	_hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_hand_layer)

	_said = UITheme.measured_label("", 26, UITheme.CONTENT_WIDTH - 48.0,
		UITheme.italic_font(), UITheme.INK)
	_said.position = Vector2(24.0, SAID_TOP)
	_said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board.add_child(_said)

	for key in ["track", "gust", "paw"]:
		var marker := MinigameShell.Marker.new()
		_board.add_child(marker)
		_markers[key] = marker


## The battle's framed portrait, at the vignette's size: art windowed to the
## frame's MEASURED aperture (law 22 — the frame floats in transparent
## padding and its geometry is never trusted).
func _framed_vignette(image_id: String, description: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = VIGNETTE_SIZE
	holder.size = VIGNETTE_SIZE
	var art := UITheme.art_or_placeholder(image_id, description)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	var frame := UITheme.tex("ui/ui_frame_portrait")
	if frame != null:
		var opaque := UITheme.content_region(frame, "ui/ui_frame_portrait")
		var aperture := UITheme.frame_aperture("ui/ui_frame_portrait")
		var sx := VIGNETTE_SIZE.x / opaque.size.x
		var sy := VIGNETTE_SIZE.y / opaque.size.y
		var tuck := 6.0
		art.set_offset(SIDE_LEFT, (aperture.position.x - opaque.position.x) * sx - tuck)
		art.set_offset(SIDE_TOP, (aperture.position.y - opaque.position.y) * sy - tuck)
		art.set_offset(SIDE_RIGHT, -(opaque.end.x - aperture.end.x) * sx + tuck)
		art.set_offset(SIDE_BOTTOM, -(opaque.end.y - aperture.end.y) * sy + tuck)
	if art is TextureRect:
		art.clip_contents = true
	holder.add_child(art)
	if frame != null:
		var frame_rect := TextureRect.new()
		frame_rect.texture = UITheme.cropped_tex("ui/ui_frame_portrait")
		frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_rect.stretch_mode = TextureRect.STRETCH_SCALE
		frame_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(frame_rect)
	return holder


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
		"board:track": return _cover("track", ROUTE_RECT)
		"board:gust": return _cover("gust", GUST_RECT)
		"board:paw": return _cover("paw",
			Rect2(0.0, HAND_BAND.x, _board.size.x, HAND_BAND.y - HAND_BAND.x))
	return null


func _cover(key: String, rect: Rect2) -> Control:
	var marker: MinigameShell.Marker = _markers[key]
	marker.cover(rect)
	return marker


# ------------------------------------------------------------------ commands

func _command(command: Dictionary, key: String) -> void:
	if Minigame.is_over(state.outcome):
		return
	var hand_before: Array = state.hand.duplicate()
	var progress_before := state.progress
	var result := state.do_command(command)
	if not result.get("ok", false):
		_say(String(result.get("error", "")))
		return
	if coach != null:
		coach.notify(key)
	match String(command.get("type", "")):
		"press_on":
			if result.get("slipped", false):
				_say(Strings.line("minigames.crossing.slipped",
					[int(result.get("lost", 0))]))
				_anim_slip(hand_before, progress_before,
					int(result.get("lost", 0)))
			else:
				_say(Strings.line("minigames.crossing.gained",
					[int(result.get("gain", 0))]))
				_anim_advance(int(result.get("gain", 0)))
		"pick_line":
			_say(Strings.line("minigames.crossing.peeked",
				[Catalog.humour_name(String(result.get("next_gust", "")))]))
		"shelter":
			_say(Strings.line("minigames.crossing.sheltered"))
			_anim_shelter()
	for event in state.take_events():
		if event == "night_presses":
			_say(Strings.line("minigames.crossing.night_note"))
	_refresh()


func _say(line: String) -> void:
	_said.text = line
	_said.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH - 48.0,
		UITheme.measure_text(line, UITheme.italic_font(), 26,
			UITheme.CONTENT_WIDTH - 48.0).y)


func card_humour(card_id: String) -> String:
	return String(_catalog.energy_cards.get(card_id, {}).get("humour", ""))


# ------------------------------------------------------------------- refresh

func _refresh() -> void:
	_chips["hp"].text = str(state.player_hp)
	_chips["home"].text = "%d/%d" % [state.progress, state.length]
	_chips["safe"].text = str(state.sheltered)
	_chips["spool"].text = str(state.deck.size())
	_chips["paws"].text = str(state.paws)
	_refresh_gust()
	_refresh_next()
	_refresh_hand()
	_route.queue_redraw()
	_place_lamp()
	if not _token_tweening:
		_place_token(false)
	# A verb that can do nothing right now is DIM, never gone (the battle's
	# rule for unplayable cards) — the page keeps its shape.
	_buttons["press"].disabled = state.hand.is_empty() and state.deck.is_empty()
	_buttons["shelter"].disabled = state.hand.is_empty()
	_buttons["peek"].disabled = state.paws < 1 or state.peeked
	if Minigame.is_over(state.outcome):
		_finish()


func _refresh_gust() -> void:
	if _gust_shown == state.gust:
		return
	_gust_shown = state.gust
	for child in _gust_plate.get_children():
		_gust_plate.remove_child(child)
		child.queue_free()
	var style := StyleBoxFlat.new()
	style.bg_color = HUMOUR_COLOURS.get(state.gust, Color("3a4a6a"))
	style.set_border_width_all(3)
	style.border_color = UITheme.INK
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	_gust_plate.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gust_plate.add_child(box)
	var plate_wrap := GUST_RECT.size.x - 20.0
	var title := UITheme.measured_label(
		Strings.line("minigames.crossing.gust_title"), 22, plate_wrap,
		UITheme.smallcaps_font(), PARCHMENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var swirl := UITheme.icon("ui/ui_gust_swirl", 62.0)
	swirl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	swirl.modulate = PARCHMENT
	box.add_child(swirl)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_row)
	var glyph := UITheme.icon(String(HUMOUR_GLYPH.get(state.gust, "")), 38.0)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(glyph)
	# Fitted BY MEASURED WIDTH, not by fitted_label: a single unbreakable
	# word measures as one line but renders wrapped (the law-5 class), so
	# FEROCITY came out "FEROCIT / Y". Width cannot lie.
	var name_text := Catalog.humour_name(state.gust).to_upper()
	var name_budget := GUST_RECT.size.x - 20.0 - 46.0
	var name_size := 32
	while name_size > UITheme.TYPE_FLOOR and UITheme.measure_text(
			name_text, UITheme.display_font(), name_size, 500.0).x > name_budget:
		name_size -= 1
	var name_label := UITheme.measured_label(name_text, name_size, name_budget,
		UITheme.display_font(), PARCHMENT)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_FILL
	name_row.add_child(name_label)
	if _booted:
		UITheme.settle(_gust_plate)


func _refresh_next() -> void:
	# The intent chip's sibling: what the sky does NEXT, read or unread.
	var shown := state.next_gust if state.peeked else ""
	if _next_shown == shown:
		return
	_next_shown = shown
	for child in _next_chip.get_children():
		_next_chip.remove_child(child)
		child.queue_free()
	_next_chip.add_theme_stylebox_override("panel", UITheme.panel_stylebox(10))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_chip.add_child(box)
	var text := Strings.line("minigames.crossing.next_reads",
		[Catalog.humour_name(shown)]) if shown != "" \
		else Strings.line("minigames.crossing.next_unread")
	var label := UITheme.measured_label(text, 24, NEXT_RECT.size.x - 24.0,
		UITheme.body_font(), UITheme.INK if shown != "" else UITheme.INK_SOFT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	if _booted and shown != "":
		UITheme.settle(_next_chip)


func _refresh_hand() -> void:
	for child in _hand_layer.get_children():
		_hand_layer.remove_child(child)
		child.queue_free()
	var n := state.hand.size()
	if n == 0:
		return
	var step: float = CARD_SIZE.x + 8.0
	if n > 1:
		step = minf(step, (UITheme.CONTENT_WIDTH - 24.0 - CARD_SIZE.x) / float(n - 1))
	var total := step * float(n - 1) + CARD_SIZE.x
	var start_x := (UITheme.CONTENT_WIDTH - total) / 2.0
	var centre := (n - 1) / 2.0
	for i in n:
		var exposed := card_humour(state.hand[i]) == state.gust
		var chip := _card_chip(String(state.hand[i]), exposed)
		var offset := i - centre
		chip.position = Vector2(start_x + step * float(i),
			2.0 + 1.6 * absf(offset) * absf(offset))
		chip.rotation_degrees = offset * 2.0
		chip.pivot_offset = CARD_SIZE / 2.0
		_hand_layer.add_child(chip)
		if exposed and _booted:
			_flutter(chip, i)


## The battle screen's energy-card chip: humour frame, glyph, worth, name.
## A card the storm is reaching for wears the gust swirl and a thread ring.
func _card_chip(card_id: String, exposed: bool) -> Control:
	var card: Dictionary = _catalog.energy_cards[card_id]
	var humour := String(card["humour"])
	var chip := Control.new()
	chip.custom_minimum_size = CARD_SIZE
	chip.size = CARD_SIZE
	chip.set_meta("card_id", card_id)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := TextureRect.new()
	frame.texture = UITheme.tex(String(HUMOUR_FRAME.get(humour, "")))
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	chip.add_child(frame)
	var glyph := TextureRect.new()
	glyph.texture = UITheme.tex(String(HUMOUR_GLYPH.get(humour, "")))
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.set_offset(SIDE_LEFT, 20)
	glyph.set_offset(SIDE_RIGHT, -20)
	glyph.set_offset(SIDE_TOP, 24)
	glyph.set_offset(SIDE_BOTTOM, -44)
	chip.add_child(glyph)
	var value := Label.new()
	value.text = str(int(card["value"]))
	value.add_theme_font_override("font", UITheme.display_font())
	value.add_theme_font_size_override("font_size", 30)
	value.add_theme_color_override("font_color", UITheme.INK)
	value.position = Vector2(14, 8)
	chip.add_child(value)
	var name_label := Label.new()
	name_label.text = Catalog.humour_name(humour)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", UITheme.INK)
	# The battle card's raised band: on the parchment, not on the deckle edge.
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.set_offset(SIDE_TOP, -46)
	name_label.set_offset(SIDE_BOTTOM, -26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(name_label)
	if exposed:
		var ring := Panel.new()
		var ring_style := StyleBoxFlat.new()
		ring_style.bg_color = Color(0, 0, 0, 0)
		ring_style.set_border_width_all(5)
		ring_style.border_color = MinigameShell.THREAD
		ring_style.set_corner_radius_all(10)
		ring.add_theme_stylebox_override("panel", ring_style)
		ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(ring)
		var swirl := UITheme.icon("ui/ui_gust_swirl", 36.0)
		swirl.position = Vector2(CARD_SIZE.x - 40.0, 4.0)
		swirl.size = Vector2(36, 36)
		chip.add_child(swirl)
	return chip


## A card the storm wants shivers in the wind. Phase comes from the index so
## the fan does not flutter in lockstep — and nothing here draws from the
## game's RNG (that stream belongs to the rules).
func _flutter(chip: Control, index: int) -> void:
	var base := chip.rotation_degrees
	var tween := chip.create_tween().set_loops()
	tween.tween_interval(0.13 * float(index % 3))
	tween.tween_property(chip, "rotation_degrees", base + 2.2, 0.42) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(chip, "rotation_degrees", base - 2.2, 0.42) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(chip, "rotation_degrees", base, 0.3)


# ------------------------------------------------------------------ the route

var _token_tweening := false


func _place_token(animate: bool) -> void:
	var target := _route.token_home(state.progress) - _token.size / 2.0
	if not animate:
		_token.position = target
		return
	_token_tweening = true
	var tween := _token.create_tween()
	tween.tween_property(_token, "position", target, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _token_tweening = false)


func _place_lamp() -> void:
	_lamp.position = _route.lamp_home() - _lamp.size / 2.0


# ---------------------------------------------------------------- animations

func _start_ambient() -> void:
	# The battle's breath, on the crossing instead of the creature.
	var tween := create_tween().set_loops()
	tween.tween_property(_vignette_art, "modulate",
		Color(1.06, 1.06, 1.06), 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_vignette_art, "modulate",
		Color(0.92, 0.92, 0.92), 1.1).set_trans(Tween.TRANS_SINE)


func _anim_advance(gain: int) -> void:
	if not _booted:
		return
	_place_token(true)
	_float_text("+%d" % gain, MinigameShell.DONE,
		_route.global_position + _route.token_home(state.progress) + Vector2(-10, -46))


func _anim_slip(hand_before: Array, progress_before: int, lost: int) -> void:
	if not _booted:
		return
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.3, 0.12)
	tween.tween_property(_flash, "color:a", 0.0, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_place_token(true)
	_float_text("-%d" % lost, MinigameShell.THREAD,
		_route.global_position + _route.token_home(progress_before) + Vector2(-10, -46))
	# The storm carries off what it caught: ghost the cards that left the
	# hand, up and away with the gust's own spin.
	var taken := hand_before.duplicate()
	for card_id in state.hand:
		var at := taken.find(card_id)
		if at >= 0:
			taken.remove_at(at)
	for node in _hand_layer.get_children():
		var card_id: String = node.get_meta("card_id", "")
		var at := taken.find(card_id)
		if at < 0:
			continue
		taken.remove_at(at)
		var ghost: Control = node
		var from := ghost.global_position
		_hand_layer.remove_child(ghost)
		add_child(ghost)
		ghost.global_position = from
		ghost.z_index = 55
		var fly := ghost.create_tween().set_parallel()
		fly.tween_property(ghost, "position",
			ghost.position + Vector2(120.0, -180.0), 0.7) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		fly.tween_property(ghost, "rotation_degrees", 40.0, 0.7)
		fly.tween_property(ghost, "modulate:a", 0.0, 0.7)
		fly.chain().tween_callback(ghost.queue_free)


func _anim_shelter() -> void:
	if not _booted:
		return
	UITheme.pulse(_route, 1.03)


func _float_text(text: String, color: Color, at_global: Vector2,
		font_size := 44) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UITheme.display_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.z_index = 60
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.global_position = at_global
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 56.0, 1.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if coach != null and is_instance_valid(coach):
		coach.queue_free()
	# A crossing that ends wants to be SEEN ending — the token reaches the
	# lamp (or the ground gives way) before the card arrives (owner rule:
	# the reward for finishing must not be a dialog in the same frame).
	if state.outcome == Minigame.Outcome.SUCCESS and _booted:
		UITheme.pulse(_lamp, 1.4)
	await get_tree().create_timer(0.7 if _booted else 0.0).timeout
	MinigameShell.show_outcome(self, state.outcome, crossing,
		func() -> void: closed.emit())


## The route: a thread stitched across the page, serpentine when the crossing
## is long. Red stitches are ground made, brass knots are ground banked, open
## holes are the road ahead. The token and the lamp ask it where they stand.
class RouteCanvas extends Control:
	const PER_ROW := 17
	const ROW_HEIGHT := 44.0
	const MARGIN_X := 34.0

	var screen


	func _pip_count() -> int:
		return screen.state.length


	func pip_center(i: int) -> Vector2:
		var rows := int(ceil(float(_pip_count()) / float(PER_ROW)))
		var row := i / PER_ROW
		var col := i % PER_ROW
		if row % 2 == 1:
			col = PER_ROW - 1 - col  # serpentine: the thread doubles back
		var in_row := mini(_pip_count() - row * PER_ROW, PER_ROW)
		var gap := (size.x - MARGIN_X * 2.0) / float(maxi(PER_ROW - 1, 1))
		var top := (size.y - float(rows - 1) * ROW_HEIGHT) / 2.0
		return Vector2(MARGIN_X + float(col) * gap,
			top + float(row) * ROW_HEIGHT + sin(float(i) * 0.9) * 7.0)


	## Where Ash stands: before the first pip at the start, then on the pip
	## he has just made.
	func token_home(progress: int) -> Vector2:
		if progress <= 0:
			return pip_center(0) + Vector2(-30.0, -16.0)
		return pip_center(mini(progress, _pip_count()) - 1) + Vector2(0.0, -18.0)


	func lamp_home() -> Vector2:
		var last := pip_center(_pip_count() - 1)
		var rows := int(ceil(float(_pip_count()) / float(PER_ROW)))
		var direction := 1.0 if rows % 2 == 1 else -1.0
		return last + Vector2(30.0 * direction, -22.0)


	func _draw() -> void:
		var state: CrossingState = screen.state
		# The thread first, pip to pip: made ground in thread-red, the road
		# ahead as faint guide (drawn through guide_line, law: never 1px).
		for i in range(1, state.length):
			var from := pip_center(i - 1)
			var to := pip_center(i)
			if i <= state.progress:
				draw_line(from, to, MinigameShell.THREAD, 4.0, true)
			else:
				MinigameShell.guide_line(self, from, to)
		for i in state.length:
			var centre := pip_center(i)
			if i < state.sheltered:
				draw_circle(centre, 10.0, MinigameShell.BRASS)
				draw_arc(centre, 10.0, 0, TAU, 22, Color("6b5427"), 2.0)
			elif i < state.progress:
				draw_circle(centre, 8.0, MinigameShell.THREAD)
			else:
				draw_arc(centre, 7.0, 0, TAU, 20, Color("a99c82"), 2.5)
