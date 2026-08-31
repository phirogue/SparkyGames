extends Control
## The Long Way Home — the decision-point board (minigames.md #5).
##
## OWNER 2026-08-13: "rather than the gust dynamic, it might be better for the
## character to continuously choose the energy in their hand to play based on
## the marked effects described. Eg: rushing forward requires so much energy,
## going around takes x amount. If not enough energy is put on a chosen path
## there is a chance for a consequence. And here, it would be cool for the
## location image to change as Ash comes to a new decision point."
##
## So the page is one thing in the road at a time:
##
##   - the PICTURE of it, full width, which changes at every point (the
##     owner's ask, and the reason a crossing reads as a journey rather than
##     as a progress bar);
##   - the WAYS past it, one plate each, priced in an energy and an amount,
##     with what you have put on it counted against what it wants;
##   - the PAW, the battle's own card chips. Tap a card to put it on the
##     chosen way, tap it again on the way to take it back. Cards that are
##     no use on this way are dimmed rather than hidden — the page keeps its
##     shape, and "I have nothing for this" is itself a reading.
##
## Pay in full and you are past it clean. Pay short and the board says the
## odds BEFORE you commit, because an informed gamble is the house rule.
##
## Feedback is the battle's vocabulary: the red wash when the shortfall
## bites, floats for what it cost, settle/pulse on plates that changed.
## Nothing below reads or writes rules state beyond do_command/take_events.

signal closed

## Board geometry (the shell's 720-tall board, 582 wide):
## picture 0..330, ways 342..532, paw 544..662, said 674..720.
##
## The picture zone grew from 250 to 330 on 2026-08-16 (owner: "adjust the
## layout so to show the full picture of the location, at the moment its
## cropped"). The crossing backdrops are drawn 3:2; a 582x250 window is
## 2.33:1, so filling it threw away 36% of every picture's height and the
## gate read as a band of railings rather than as a gate. The art is now
## fitted WHOLE inside the zone (see _refresh_picture) and the zone is deep
## enough that the fit costs only a narrow mount either side.
##
## The 80px came off the other three zones, which had room: the way plates
## were 77 tall for a glyph and two short labels, and the said-line was
## budgeted for two lines of 26 it never uses. Zone heights must still sum
## with their separations to the board height exactly (law 6):
##   302 + 12 + 172 + 12 + 174 + 12 + 36 = 720.
##
## The paw took 56 on 2026-08-30 (owner: "the energy cards ... are too small to
## fit the name of the energy type on them"). "Moonlight" is 94px at the type
## floor and the card's printed face is UITheme.CARD_NAME_BAND of its width, so
## the card has to be 140 across; it was 96, which is why only "Guile" ever
## really fitted. The 56 came from all three of the other zones rather than out
## of the picture alone: the ways were budgeted 58 a plate for a 44px glyph,
## and the said-line had 46 for one line of 26. The picture still shows WHOLE,
## which was the 2026-08-16 complaint — 453x302 where it was 495x330.
const PICTURE_RECT := Rect2(0.0, 0.0, 582.0, 302.0)
const NAME_BAND_HEIGHT := 56.0
## The caption steps down this scale until it fits the picture it is on; the
## floor is TYPE_SUPPORT, never below it (law 29).
const CAPTION_SIZES := [32, 30, 28, 26]
const WAYS_TOP := 314.0
const WAYS_HEIGHT := 172.0
const WAY_SEPARATION := 8.0
const PAW_BAND := Vector2(498.0, 672.0)
const SAID_TOP := 684.0
## Sized FROM the measurement, not chosen: the widest humour name at
## UITheme.TYPE_FLOOR must fit inside the card art's printed face
## (UITheme.CARD_NAME_BAND). "Moonlight" is 94px at 22, so the face needs 102
## with breathing room, so the card is 140.
##
## The height is 13% short of the art's own proportions. A card drawn 140 wide
## and true would be 197 tall and would have taken another 23px out of the
## picture; at this size the stretch is not visible, while a name lying across
## the card's border ink very much was.
## tests/unit/test_typography.gd fails if these two drift apart again.
const CARD_SIZE := Vector2(140.0, 174.0)
## Height of the name's own line, so it can be centred on the printed band
## rather than hung off the card's bottom edge.
const NAME_LINE := 30.0
## How far up from the card's bottom the band's middle sits. The art measures
## 0.857..0.936, so the geometric centre is 0.1035 up — but a line box carries
## its baseline low, so type centred on that number sits ON the band's lower
## rule. 0.118 puts the letters where the eye reads the middle.
const NAME_BAND_UP := 0.118
## The mount the fitted picture sits on, so the margins either side of a
## 3:2 picture in a wider window read as a deliberate frame, not a gap.
const MOUNT := Color(0.10, 0.09, 0.08, 1.0)

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
var _picture: Control
var _picture_art: Control
var _picture_shown := ""           # which point the picture is of
var _name_band: ColorRect
var _name_plate: Label
var _ways_box: VBoxContainer
var _paw_layer: Control
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

	# Three verbs, two rows: GO is the commit, and the other two are the ways
	# out of committing.
	var top := MinigameShell.action_row(shell["actions"])
	_add_verb(top, "go", "minigames.crossing.go", {"type": "go"}, true,
		UITheme.CONTENT_WIDTH)
	var bottom := MinigameShell.action_row(shell["actions"])
	_add_verb(bottom, "peek", "minigames.crossing.peek",
		{"type": "read_ahead"}, true)
	_add_verb(bottom, "away", "minigames.crossing.away",
		{"type": "turn_back"}, false)

	# The battle's red wash, for the moment a shortfall bites.
	_flash = ColorRect.new()
	_flash.color = Color(0.55, 0.1, 0.06, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.z_index = 50
	add_child(_flash)

	_help.pressed.connect(_start_tutorial)
	_help.visible = not coach_steps.is_empty()
	_refresh()
	await get_tree().process_frame
	_booted = true
	if coach_auto:
		_start_tutorial()


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
	# The spool answers taps, exactly as it does in a fight (owner 2026-08-13:
	# "you should be able to see your deck contents to be able to gauge the
	# probability of making it"). Whether you can afford the road IS a deck
	# question, and now it is the only question.
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
	# The thing in the road, full width and unframed: a place is not a
	# portrait (owner: "the location card here doesn't need a border").
	# The mount fills the whole zone; the picture is fitted onto it whole.
	var mount := ColorRect.new()
	mount.color = MOUNT
	mount.position = PICTURE_RECT.position
	mount.size = PICTURE_RECT.size
	mount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(mount)

	_picture = Control.new()
	_picture.position = PICTURE_RECT.position
	_picture.size = PICTURE_RECT.size
	_picture.clip_contents = true
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_picture)
	# Its name sits ON the picture, on a dark band, the way the battle names
	# its opponent — the thing in the road IS the opponent here. The band is
	# resized to the fitted picture's width in _fit_picture, so it never runs
	# out over the mount.
	_name_band = ColorRect.new()
	_name_band.color = Color(0.08, 0.07, 0.06, 0.72)
	_name_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.add_child(_name_band)
	_name_plate = UITheme.measured_label("", 32, PICTURE_RECT.size.x - 28.0,
		UITheme.display_font(), PARCHMENT)
	_name_plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_plate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_band.add_child(_name_plate)
	_fit_picture(PICTURE_RECT.size)

	_ways_box = VBoxContainer.new()
	_ways_box.position = Vector2(0.0, WAYS_TOP)
	_ways_box.size = Vector2(UITheme.CONTENT_WIDTH, WAYS_HEIGHT)
	_ways_box.add_theme_constant_override("separation", int(WAY_SEPARATION))
	_board.add_child(_ways_box)

	# Cards get their OWN layer (law 25: rebuildable content never shares a
	# container with siblings something keeps a handle on).
	_paw_layer = Control.new()
	_paw_layer.position = Vector2(0.0, PAW_BAND.x)
	_paw_layer.size = Vector2(UITheme.CONTENT_WIDTH, PAW_BAND.y - PAW_BAND.x)
	_board.add_child(_paw_layer)

	_said = UITheme.measured_label("", 26, UITheme.CONTENT_WIDTH - 48.0,
		UITheme.italic_font(), UITheme.INK)
	_said.position = Vector2(24.0, SAID_TOP)
	_said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board.add_child(_said)

	for key in ["picture", "ways", "paw"]:
		var marker := MinigameShell.Marker.new()
		_board.add_child(marker)
		_markers[key] = marker


func _add_verb(row: HBoxContainer, key: String, string_key: String,
		command: Dictionary, aid: bool,
		budget := MinigameShell.ACTION_BUDGET_HALF) -> void:
	var button: Button = MinigameShell.aid_button(Strings.line(string_key),
			MinigameShell.ACTION_FONT_HALF, MinigameShell.ACTION_HEIGHT_HALF,
			budget) \
		if aid else MinigameShell.leave_button(Strings.line(string_key),
			MinigameShell.ACTION_FONT_HALF, MinigameShell.ACTION_HEIGHT_HALF,
			budget)
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
		"board:picture": return _cover("picture", PICTURE_RECT)
		"board:ways": return _cover("ways",
			Rect2(0.0, WAYS_TOP, UITheme.CONTENT_WIDTH, WAYS_HEIGHT))
		"board:paw": return _cover("paw",
			Rect2(0.0, PAW_BAND.x, UITheme.CONTENT_WIDTH, PAW_BAND.y - PAW_BAND.x))
	return null


func _cover(key: String, rect: Rect2) -> Control:
	var marker: MinigameShell.Marker = _markers[key]
	marker.cover(rect)
	return marker


# ------------------------------------------------------------------ commands

func _command(command: Dictionary, key: String) -> void:
	if Minigame.is_over(state.outcome):
		return
	var hp_before := state.player_hp
	# The card moving on will deal him, read BEFORE the command — afterwards
	# the top of the spool is a different card.
	var incoming := "" if state.deck.is_empty() else String(state.deck.back())
	var result := state.do_command(command)
	if not result.get("ok", false):
		_say(String(result.get("error", "")))
		return
	if coach != null:
		coach.notify(key)
	match String(command.get("type", "")):
		"go":
			# Moving on deals one card back into the paw, and the owner asked
			# to SEE that happen (2026-08-13) — the hand simply having one more
			# card in it the next time you look is not feedback.
			if incoming != "" and state.hand.has(incoming):
				_anim_draw(incoming)
			if result.get("bitten", false):
				_say(Strings.line("minigames.crossing.bitten",
					[int(result.get("hurt", 0))]))
				_anim_bite(hp_before - state.player_hp)
			elif int(result.get("short", 0)) > 0:
				_say(Strings.line("minigames.crossing.scraped"))
			else:
				_say(Strings.line("minigames.crossing.clean"))
		"read_ahead":
			_say(Strings.line("minigames.crossing.read",
				[String(state.next_point().get("name", ""))]))
	_refresh()


func _say(line: String) -> void:
	_said.text = line
	_said.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH - 48.0,
		UITheme.measure_text(line, UITheme.italic_font(), 26,
			UITheme.CONTENT_WIDTH - 48.0).y)


# ------------------------------------------------------------------- refresh

func _refresh() -> void:
	_chips["hp"].text = str(state.player_hp)
	_chips["home"].text = "%d/%d" % [state.at, state.length()]
	_chips["spool"].text = str(state.deck.size())
	_chips["paws"].text = str(state.paws)
	_refresh_picture()
	_refresh_ways()
	_refresh_paw()
	_refresh_go()
	# A verb that can do nothing right now is DIM, never gone (the battle's
	# rule for unplayable cards) — the page keeps its shape.
	_buttons["go"].disabled = state.chosen == ""
	_buttons["peek"].disabled = state.paws < 1 or state.revealed \
		or state.next_point().is_empty()
	if Minigame.is_over(state.outcome):
		_finish()


## GO says what it is about to cost. Under-paying is allowed — no board here
## is a wall — but the odds are on the button BEFORE the commit, because an
## informed gamble is the house rule and a hidden one is a coin toss.
func _refresh_go() -> void:
	var button: Button = _buttons["go"]
	var short := state.shortfall()
	if state.chosen == "":
		button.text = Strings.line("minigames.crossing.go")
		return
	if short <= 0:
		button.text = Strings.line("minigames.crossing.go_clean")
		return
	# Words, not a percentage: a number out of a hundred is not something the
	# book's voice says, and the bands are what a player actually decides on.
	var odds := state.risk()
	var band := "long" if odds < 0.4 else ("even" if odds < 0.7 else "bad")
	button.text = Strings.line("minigames.crossing.go_short." + band, [short])


## Lay the picture holder out for a picture of this shape: the WHOLE image,
## scaled to fit inside the zone and centred on the mount, with the name band
## across the bottom of the picture itself rather than of the zone.
##
## The default art helper covers its box (crops to fill), which is right for
## a backdrop that has to reach the page edges and wrong for this: the thing
## in the road is a picture OF somewhere, and half a gate is not a gate.
func _fit_picture(art_size: Vector2) -> void:
	var fitted := PICTURE_RECT.size
	if art_size.x > 0.0 and art_size.y > 0.0:
		var scale: float = minf(PICTURE_RECT.size.x / art_size.x,
			PICTURE_RECT.size.y / art_size.y)
		fitted = (art_size * scale).floor()
	_picture.position = PICTURE_RECT.position \
		+ ((PICTURE_RECT.size - fitted) * 0.5).floor()
	_picture.size = fitted
	_name_band.position = Vector2(0.0, fitted.y - NAME_BAND_HEIGHT)
	_name_band.size = Vector2(fitted.x, NAME_BAND_HEIGHT)
	_name_plate.position = Vector2(14.0, 0.0)
	_fit_caption(maxf(fitted.x - 28.0, 1.0))


## The caption, RE-measured for the picture it is actually sitting on.
##
## Law 5, collected 2026-08-30: the plate was measured once at the whole
## zone's width (554) and then had its rect set to the FITTED picture's width.
## A measured_label's wrap width is its minimum width, so it kept the 554 it
## was measured at, and the picture's clip took the end off the caption —
## "Black water, and one plank" rendered as "Black water, and one plan". The
## card growing shrank the picture and made a defect that had been latent
## since the fit was introduced finally visible.
##
## Sized down the type scale rather than wrapped: the band is one line tall,
## so a second line would be clipped exactly like the first overflow was.
func _fit_caption(width: float) -> void:
	var size := UITheme.fit_font_size(_name_plate.text, UITheme.display_font(),
		CAPTION_SIZES, Vector2(width, NAME_BAND_HEIGHT))
	_name_plate.add_theme_font_size_override("font_size", size)
	_name_plate.custom_minimum_size = Vector2(width, NAME_BAND_HEIGHT)
	_name_plate.size = Vector2(width, NAME_BAND_HEIGHT)


## The picture changes at every point (owner 2026-08-13). It cross-fades
## rather than cutting, so arriving somewhere new reads as travel.
func _refresh_picture() -> void:
	var point := state.point()
	var point_id := String(point.get("id", ""))
	if _picture_shown == point_id:
		return
	_picture_shown = point_id
	var previous := _picture_art
	var image_id := String(point.get("image", ""))
	var texture := UITheme.tex(image_id)
	_fit_picture(Vector2(texture.get_size()) if texture != null \
		else PICTURE_RECT.size)
	var art := UITheme.art_or_placeholder(image_id,
		String(point.get("name", "the road")))
	# The holder is already the picture's own shape, so the art fills it and
	# nothing is thrown away.
	if art is TextureRect:
		art.stretch_mode = TextureRect.STRETCH_SCALE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.add_child(art)
	_picture.move_child(art, 0)
	_picture_art = art
	_name_plate.text = String(point.get("name", ""))
	# Re-fit for the new words: _fit_picture runs before the text is set on
	# the first point, so measuring only there would size the caption against
	# an empty string.
	_fit_caption(_name_plate.size.x)
	if previous != null and is_instance_valid(previous):
		if _booted:
			var fade := previous.create_tween()
			fade.tween_property(previous, "modulate:a", 0.0, 0.3)
			fade.tween_callback(previous.queue_free)
			UITheme.settle(art)
		else:
			previous.queue_free()


## One plate per way past this thing: what it is called, what energy it wants
## and how much, and what is on it so far. The chosen one wears amber.
func _refresh_ways() -> void:
	for child in _ways_box.get_children():
		_ways_box.remove_child(child)
		child.queue_free()
	var ways := state.ways()
	if ways.is_empty():
		return
	var height := (WAYS_HEIGHT - WAY_SEPARATION * float(ways.size() - 1)) \
		/ float(ways.size())
	for entry in ways:
		var way: Dictionary = entry
		_ways_box.add_child(_way_plate(way, height))


func _way_plate(way: Dictionary, height: float) -> Control:
	var way_id := String(way.get("id", ""))
	var humour := String(way.get("humour", "any"))
	var chosen: bool = state.chosen == way_id
	var plate := Button.new()
	plate.custom_minimum_size = Vector2(0, height)
	plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tint: Color = MinigameShell.HUMOUR_COLOURS.get(humour, Color("6b5747"))
	for style_state in ["normal", "hover", "pressed", "focus"]:
		plate.add_theme_stylebox_override(style_state,
			UITheme.amber_stylebox() if chosen else UITheme.panel_stylebox(10))
	plate.pressed.connect(func() -> void:
		_command({"type": "choose", "way": way_id}, "choose"))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.offset_left = 14
	row.offset_right = -14
	plate.add_child(row)

	var glyph_id := String(MinigameShell.HUMOUR_GLYPH.get(humour, ""))
	if glyph_id != "":
		var glyph := UITheme.icon(glyph_id, 46.0)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)

	var label := UITheme.fitted_label(String(way.get("label", "")),
		[30, 28, 26, 24, 22], Vector2(260.0, height - 16.0),
		UITheme.display_font(), UITheme.INK)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	# The price, and what is on it. A chosen way counts up as cards go on, so
	# "am I there yet" never needs arithmetic.
	var cost := int(way.get("cost", 0))
	var price := Strings.line("minigames.crossing.price",
		[state.paid_worth(), cost, _energy_name(humour)]) if chosen \
		else Strings.line("minigames.crossing.price_idle",
			[cost, _energy_name(humour)])
	var price_label := UITheme.fitted_label(price, [26, 24, 22],
		Vector2(190.0, height - 16.0), UITheme.body_font(),
		MinigameShell.DONE if chosen and state.shortfall() == 0 else tint)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.size_flags_vertical = Control.SIZE_FILL
	row.add_child(price_label)
	if chosen:
		plate.tooltip_text = ""
	return plate


func _energy_name(humour: String) -> String:
	return Strings.line("minigames.crossing.any_energy") if humour == "any" \
		else Catalog.humour_name(humour)


## The paw. Tap a card to put it on the chosen way; tap one already on the
## way to take it back. A card that is no use on this way is DIMMED, not
## hidden — "I have nothing for this" is a reading the player needs.
func _refresh_paw() -> void:
	for child in _paw_layer.get_children():
		_paw_layer.remove_child(child)
		child.queue_free()
	var humour := String(state.way(state.chosen).get("humour", "any")) \
		if state.chosen != "" else ""
	var cards: Array = []
	for card_id in state.paid:
		cards.append({"card": String(card_id), "on_way": true})
	for card_id in state.hand:
		cards.append({"card": String(card_id), "on_way": false})
	var n := cards.size()
	if n == 0:
		return
	var step: float = CARD_SIZE.x + 8.0
	if n > 1:
		step = minf(step, (UITheme.CONTENT_WIDTH - 24.0 - CARD_SIZE.x) / float(n - 1))
	var total := step * float(n - 1) + CARD_SIZE.x
	var start_x := (UITheme.CONTENT_WIDTH - total) / 2.0
	for i in n:
		var card_id: String = cards[i]["card"]
		var on_way: bool = cards[i]["on_way"]
		# With no way chosen yet there is nothing for a card to be useless
		# AGAINST, so nothing dims — a whole paw greyed out before the player
		# has picked anything reads as "you have nothing", which is a lie.
		var useful: bool = humour == "" \
			or state.worth_toward(card_id, humour) > 0
		var chip := _card_chip(card_id, on_way, useful)
		chip.position = Vector2(start_x + step * float(i),
			0.0 if on_way else 18.0)
		_paw_layer.add_child(chip)


## The battle screen's energy-card chip: humour frame, glyph, worth, name.
## A card already on the way is lifted and ringed; one that is no use on this
## way is dimmed.
func _card_chip(card_id: String, on_way: bool, useful: bool) -> Control:
	var card: Dictionary = _catalog.energy_cards[card_id]
	var humour := String(card["humour"])
	var chip := Control.new()
	chip.custom_minimum_size = CARD_SIZE
	chip.size = CARD_SIZE
	chip.set_meta("card_id", card_id)
	var frame := TextureRect.new()
	frame.texture = UITheme.tex(String(HUMOUR_FRAME.get(humour, "")))
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(frame)
	var glyph := TextureRect.new()
	glyph.texture = UITheme.tex(String(MinigameShell.HUMOUR_GLYPH.get(humour, "")))
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The insets are FRACTIONS of the card, not the pixel values they were
	# before: the card grew from 96x118 to 140x174 on 2026-08-30 and fixed
	# offsets would have left the glyph rattling in a corner of it.
	glyph.set_offset(SIDE_LEFT, CARD_SIZE.x * 0.16)
	glyph.set_offset(SIDE_RIGHT, -CARD_SIZE.x * 0.16)
	glyph.set_offset(SIDE_TOP, CARD_SIZE.y * 0.17)
	glyph.set_offset(SIDE_BOTTOM, -CARD_SIZE.y * 0.34)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(glyph)
	var value := Label.new()
	value.text = str(int(card["value"]))
	value.add_theme_font_override("font", UITheme.display_font())
	value.add_theme_font_size_override("font_size", 30)
	value.add_theme_color_override("font_color", UITheme.INK)
	value.position = Vector2(CARD_SIZE.x * 0.13, CARD_SIZE.y * 0.06)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(value)
	var name_label := Label.new()
	name_label.text = Catalog.humour_name(humour)
	name_label.add_theme_font_size_override("font_size", UITheme.TYPE_FLOOR)
	name_label.add_theme_color_override("font_color", UITheme.INK)
	# Pinned to the card's printed FACE, not to the card's rect. The whole
	# defect was a name as wide as the card, lying across the border ink at
	# both ends; the label is now inset to UITheme.CARD_NAME_BAND and the card
	# is sized so the widest humour name fits inside that.
	var inset := CARD_SIZE.x * (1.0 - UITheme.CARD_NAME_BAND) * 0.5
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.set_offset(SIDE_LEFT, inset)
	name_label.set_offset(SIDE_RIGHT, -inset)
	# Centred on the art's ruled band, whose middle measures 0.897 down the
	# card. The band is only 8% of the card tall, so 22px type sits ACROSS it
	# rather than inside it — as it always has, on every screen that draws
	# these cards. Centring is what makes that read as deliberate.
	name_label.set_offset(SIDE_TOP, -CARD_SIZE.y * NAME_BAND_UP - NAME_LINE * 0.5)
	name_label.set_offset(SIDE_BOTTOM, -CARD_SIZE.y * NAME_BAND_UP + NAME_LINE * 0.5)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(name_label)
	if on_way:
		var ring := Panel.new()
		var ring_style := StyleBoxFlat.new()
		ring_style.bg_color = Color(0, 0, 0, 0)
		ring_style.set_border_width_all(5)
		ring_style.border_color = Color("e0913a")
		ring_style.set_corner_radius_all(10)
		ring.add_theme_stylebox_override("panel", ring_style)
		ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(ring)
	elif not useful:
		chip.modulate = Color(1, 1, 1, 0.42)
	# The whole card is the tap target (mobile floor), not a hotspot in it.
	UITheme.tap_layer(chip).pressed.connect(func() -> void:
		if on_way:
			_command({"type": "take_back", "card": card_id}, "take_back")
		else:
			_command({"type": "put", "card": card_id}, "put"))
	return chip


# ---------------------------------------------------------------- animations

## A card comes off the spool, face up, and lands in the paw.
func _anim_draw(card_id: String) -> void:
	if not _booted or not _catalog.energy_cards.has(card_id):
		return
	var ghost := _card_chip(card_id, false, true)
	ghost.z_index = 58
	ghost.scale = Vector2(0.6, 0.6)
	ghost.pivot_offset = CARD_SIZE / 2.0
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ghost)
	var spool: Label = _chips["spool"]
	ghost.global_position = spool.global_position - CARD_SIZE * 0.3
	var land := _paw_layer.global_position + Vector2(
		(_paw_layer.size.x - CARD_SIZE.x) * 0.5, 18.0)
	var fly := ghost.create_tween().set_parallel()
	fly.tween_property(ghost, "global_position", land, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fly.tween_property(ghost, "scale", Vector2.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fly.chain().tween_property(ghost, "modulate:a", 0.0, 0.1)
	fly.chain().tween_callback(ghost.queue_free)


func _anim_bite(hurt: int) -> void:
	if not _booted:
		return
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.3, 0.12)
	tween.tween_property(_flash, "color:a", 0.0, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hurt > 0:
		_float_text("-%d" % hurt, MinigameShell.THREAD,
			_chips["hp"].global_position + Vector2(0.0, -20.0))


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
	# A crossing that ends wants to be SEEN ending (owner rule: the reward for
	# finishing must not be a dialog in the same frame).
	await get_tree().create_timer(0.7 if _booted else 0.0).timeout
	MinigameShell.show_outcome(self, state.outcome, crossing,
		func() -> void: closed.emit())
