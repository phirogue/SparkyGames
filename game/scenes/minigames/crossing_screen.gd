extends Control
## The Long Way Round — the crossing board at the battle screen's standard
## (owner 2026-08-11: "work out the ui and the animations in a similar way to
## the battle screen"). The design contract is unchanged (minigames.md #5):
## same deck, same paws, same spent pile — only the opponent is weather.
##
## The page mirrors the fight it is a sibling of:
##   - the OPPONENT is the crossing itself: the environment's own backdrop,
##     unframed (owner 2026-08-13: "the location card here doesn't need a
##     border"), breathing the battle's ambient breath;
##   - the WAY AHEAD plate and the next-obstacle chip sit beside it exactly
##     where the enemy's name plate and intent chip sit in a fight — reading
##     ahead is an intent read, and an unread street says so;
##   - the ROUTE is one straight stitched thread across the page (owner: "do
##     not make the path loop back on itself"): red stitches are ground made,
##     brass knots are ground banked, open holes are the road ahead, with Ash
##     (ui_token_ash) walking pip to pip toward a lit window;
##   - the HAND is the battle's own card chips, and a card the obstacle will
##     take wears its glyph and flutters — the gamble is readable first.
##
## What a humour on the plate MEANS was the owner's first question about this
## module (2026-08-13: "what does it mean for the gust to control a specific
## energy"). It is no longer abstract weather: the plate names the thing in
## the road — a chained dog, a crowd, a wall — and says what getting past it
## costs. Press on carrying that cost and the obstacle takes it off you along
## with your ground; shelter and you go the long way round for one card.
##
## Feedback is the battle's vocabulary: floats for ground gained and lost,
## the red wash when it bites, a card seen leaving the spool for the paw,
## settle/pulse on plates that changed.
## Nothing below reads or writes rules state beyond do_command/take_events.

signal closed

## Board geometry (the shell's 720-tall board, 582 wide). Bands are named so
## the tutorial can point at them and the layout never guesses (law 4):
## vignette 0..308, route 320..452, hand 464..604, said 616..720.
const VIGNETTE_SIZE := Vector2(348.0, 308.0)
## The obstacle plate takes the taller share of the right-hand column: it has
## a name AND a price to say, and at 186 the price was clipped mid-sentence
## ("Keeping out of sight costs" — and then nothing).
const GUST_RECT := Rect2(360.0, 0.0, 222.0, 214.0)
const NEXT_RECT := Rect2(360.0, 226.0, 222.0, 82.0)
const ROUTE_RECT := Rect2(0.0, 320.0, 582.0, 132.0)
const HAND_BAND := Vector2(464.0, 604.0)
const SAID_TOP := 616.0
## 94 wide cropped "Moonlight" on its own card face; the humour name is the
## one word a chip must never lose.
const CARD_SIZE := Vector2(104.0, 132.0)

## Colours and glyphs come from MinigameShell.HUMOUR_* — the battle screen's
## own vocabulary, shared verbatim so a card is the same card everywhere.
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
	# The spool answers taps, exactly as it does in a fight (owner 2026-08-13:
	# "you should be able to see your deck contents to be able to gauge the
	# probability of making it"). Whether to press on IS a deck question.
	var spool_wrap := PanelContainer.new()
	spool_wrap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	row.add_child(spool_wrap)
	_chips["spool"] = _status_chip(spool_wrap, "ui/ui_spool")
	UITheme.tap_layer(spool_wrap).pressed.connect(func() -> void:
		MinigameShell.spool_popup(self, _catalog, state.deck, state.hand))
	_divider(row)
	_chips["paws"] = _status_chip(row, "ui/ui_paw_full")


func _status_chip(parent: Container, icon_id: String) -> Label:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 6)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	# The crossing itself. Unframed (owner 2026-08-13): a place is not a
	# portrait, and the wood frame around it read as a card of a card.
	var environment: Dictionary = _catalog.environments.get(
		String(crossing.get("environment", "")), {})
	_vignette_art = _vignette(String(environment.get("image", "")),
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


## The place, plain: the environment's art filling the vignette rect, clipped
## to it and nothing else. It carried the battle's wood portrait frame until
## the owner asked for the border off (2026-08-13) — a portrait frame says
## "here is a character", and the crossing's opponent is a street.
func _vignette(image_id: String, description: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = VIGNETTE_SIZE
	holder.size = VIGNETTE_SIZE
	holder.clip_contents = true
	var art := UITheme.art_or_placeholder(image_id, description)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(art)
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
	var gust_before := state.gust
	# The card Press On is about to take off the spool, so it can be SEEN
	# coming (owner 2026-08-13: "there should be an animation showing the next
	# card being drawn"). Read before the command, because after it the top of
	# the deck is a different card.
	var incoming := "" if state.deck.is_empty() else String(state.deck.back())
	var result := state.do_command(command)
	if not result.get("ok", false):
		_say(String(result.get("error", "")))
		return
	if coach != null:
		coach.notify(key)
	match String(command.get("type", "")):
		"press_on":
			if incoming != "":
				_anim_draw(incoming)
			if result.get("slipped", false):
				_say(Strings.line("minigames.crossing.slipped",
					[Catalog.humour_name(gust_before),
					int(result.get("lost", 0))]))
				_anim_slip(hand_before, progress_before,
					int(result.get("lost", 0)))
			else:
				_say(Strings.line("minigames.crossing.gained",
					[int(result.get("gain", 0))]))
				_anim_advance(int(result.get("gain", 0)))
		"pick_line":
			var next_humour := String(result.get("next_gust", ""))
			_say(Strings.line("minigames.crossing.peeked",
				[_obstacle(next_humour, state.turn + 1),
				Catalog.humour_name(next_humour)]))
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


## What is standing in the road, and what getting past it costs.
##
## The humour used to be posted bare — "the gust owns FEROCITY" — and the
## owner's question was the right one: what does that MEAN? So the plate now
## names a thing (a chained dog, a crowd, a wall) and prices it in the humour
## that gets you past. Which obstacle a humour wears varies by turn, because
## the same dog on every plate is one photograph with captions (law 15).
func _refresh_gust() -> void:
	if _gust_shown == _obstacle_key(state.gust, state.turn):
		return
	_gust_shown = _obstacle_key(state.gust, state.turn)
	for child in _gust_plate.get_children():
		_gust_plate.remove_child(child)
		child.queue_free()
	var style := StyleBoxFlat.new()
	style.bg_color = MinigameShell.HUMOUR_COLOURS.get(state.gust, Color("3a4a6a"))
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
	# Title row: the humour's own glyph beside the heading, so the plate wears
	# its colour AND its mark without spending a line of the plate on it.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_row)
	var glyph := UITheme.icon(
		String(MinigameShell.HUMOUR_GLYPH.get(state.gust, "")), 30.0)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(glyph)
	var title := UITheme.measured_label(
		Strings.line("minigames.crossing.ahead_title"), 22, plate_wrap - 40.0,
		UITheme.smallcaps_font(), PARCHMENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)
	# The obstacle itself, given the biggest type on the plate — it is the
	# thing the player is deciding about. Both of these are FITTED to a real
	# box (law 5): the price used to be sized by a guess and clipped.
	var obstacle_label := UITheme.fitted_label(_obstacle(state.gust, state.turn),
		[30, 28, 26, 24, 22], Vector2(plate_wrap, 88.0),
		UITheme.display_font(), PARCHMENT)
	obstacle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(obstacle_label)
	var cost_label := UITheme.fitted_label(
		Strings.line("minigames.crossing.cost." + state.gust,
			[Catalog.humour_name(state.gust).to_upper()]),
		[26, 24, 22], Vector2(plate_wrap, 62.0), UITheme.body_font(), PARCHMENT)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cost_label)
	if _booted:
		UITheme.settle(_gust_plate)


## Which obstacle this humour wears on this turn. Deterministic (no RNG — that
## stream belongs to the rules) and stable within a turn, so the plate does
## not change its mind between two refreshes.
func _obstacle(humour: String, turn: int) -> String:
	var options := Strings.lines("minigames.crossing.obstacle." + humour)
	if options.is_empty():
		return Catalog.humour_name(humour)
	return String(options[turn % options.size()])


func _obstacle_key(humour: String, turn: int) -> String:
	return "%s/%d" % [humour, turn]


func _refresh_next() -> void:
	# The intent chip's sibling: what stands in the road AFTER this one, read
	# or unread, and how it gets read.
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
	# The chip says only what it has room to say: which humour the NEXT thing
	# in the road wants. What that thing IS gets said in full by Read Ahead's
	# own line under the board, where there is room for a sentence.
	var text := Strings.line("minigames.crossing.next_reads",
		[Catalog.humour_name(shown)]) if shown != "" \
		else Strings.line("minigames.crossing.next_unread")
	var label := UITheme.fitted_label(text, [26, 24, 22],
		Vector2(NEXT_RECT.size.x - 24.0, NEXT_RECT.size.y - 20.0),
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
	glyph.texture = UITheme.tex(String(MinigameShell.HUMOUR_GLYPH.get(humour, "")))
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


## A card comes off the spool, face up, and lands in the paw. Press On draws
## before it moves you, and the owner could not see that happening — the hand
## simply had one more card in it the next time they looked.
func _anim_draw(card_id: String) -> void:
	if not _booted or not _catalog.energy_cards.has(card_id):
		return
	var ghost := _card_chip(card_id, false)
	ghost.z_index = 58
	ghost.scale = Vector2(0.6, 0.6)
	ghost.pivot_offset = CARD_SIZE / 2.0
	add_child(ghost)
	var spool: Label = _chips["spool"]
	ghost.global_position = spool.global_position - CARD_SIZE * 0.3
	var land := _hand_layer.global_position + Vector2(
		(_hand_layer.size.x - CARD_SIZE.x) * 0.5, 0.0)
	var fly := ghost.create_tween().set_parallel()
	fly.tween_property(ghost, "global_position", land, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fly.tween_property(ghost, "scale", Vector2.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fly.chain().tween_property(ghost, "modulate:a", 0.0, 0.1)
	fly.chain().tween_callback(ghost.queue_free)


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


## The route: one straight thread stitched across the page, left to right,
## Ash's end to the lamp's. Red stitches are ground made, brass knots are
## ground banked, open holes are the road ahead.
##
## It used to serpentine back on itself once a crossing ran past seventeen
## pips, which read as a maze rather than as a way home (owner 2026-08-13:
## "don't make the path loop back on itself, make it a straight line, just
## add more pips where you need to"). So the line is straight and the PIPS
## close up to fit — and the crossings themselves were shortened, because a
## route long enough to need two rows was also long enough to eat a whole
## night's deck.
class RouteCanvas extends Control:
	const MARGIN_LEFT := 56.0    # room for Ash, standing before the first pip
	const MARGIN_RIGHT := 62.0   # room for the lamp, past the last one

	var screen


	func _pip_count() -> int:
		return maxi(screen.state.length, 1)


	## Space between two pips. Shrinks to fit however many the crossing asks
	## for, so a long route crowds its pips instead of folding the road.
	func gap() -> float:
		return (size.x - MARGIN_LEFT - MARGIN_RIGHT) \
			/ float(maxi(_pip_count() - 1, 1))


	## Pips never touch: a pip is at most a third of the space it has.
	func pip_radius() -> float:
		return clampf(gap() * 0.3, 4.0, 10.0)


	func pip_center(i: int) -> Vector2:
		# A stitched line is not a ruled one — the thread rides a hair up and
		# down as real running stitch does. Never enough to read as a bend.
		return Vector2(MARGIN_LEFT + float(i) * gap(),
			size.y * 0.5 + sin(float(i) * 0.9) * 4.0)


	## Where Ash stands: before the first pip at the start, then on the pip
	## he has just made.
	func token_home(progress: int) -> Vector2:
		if progress <= 0:
			return pip_center(0) + Vector2(-34.0, -14.0)
		return pip_center(mini(progress, _pip_count()) - 1) + Vector2(0.0, -18.0)


	func lamp_home() -> Vector2:
		return pip_center(_pip_count() - 1) + Vector2(38.0, -18.0)


	func _draw() -> void:
		var state: CrossingState = screen.state
		var radius := pip_radius()
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
				draw_circle(centre, radius, MinigameShell.BRASS)
				draw_arc(centre, radius, 0, TAU, 22, Color("6b5427"), 2.0)
			elif i < state.progress:
				draw_circle(centre, radius * 0.8, MinigameShell.THREAD)
			else:
				draw_arc(centre, radius * 0.7, 0, TAU, 20, Color("a99c82"), 2.5)
