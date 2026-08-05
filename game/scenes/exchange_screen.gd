extends Control
## The Magpie Exchange — the market, and a conversation with Brindle rather
## than a table of prices. His portrait says what he thinks of your purse;
## the shelf holds four goods with a wax seal for a price tag; choosing one
## opens its options in the strip underneath, so a whole transaction happens
## without leaving the page.
##
## The economy is unchanged from the version that lived inside the hub — the
## same four goods at the same four prices. What changed is that a good you
## cannot afford now LOOKS out of reach instead of failing silently on tap.

signal closed
signal profile_changed

## FIXED zone template (law 12): heights + separations == CONTENT_HEIGHT.
## 96 + 300 + 480 + 192 = 1068, plus 3 x 12 separation = 1104.
const SEPARATION := 12
const ZONE_HEADER := 96
const ZONE_BRINDLE := 300
const ZONE_SHELF := 480
const ZONE_DETAIL := 192

const PORTRAIT_WIDTH := 208.0
const SHELF_COLUMNS := 2
const GOOD_WIDTH := (UITheme.CONTENT_WIDTH - SEPARATION) / SHELF_COLUMNS  # 285
const GOOD_HEIGHT := 216

const ADD_CARD_COST := 12
const RARE_CARD_COST := 30
const REMOVE_CARD_COST := 15
const TONIC_COST := 25
const MAX_HP_CAP := 30
const DECK_FLOOR := 10   # he will not thin a deck past this

## The shelf: what each good COSTS is a rule, what it is CALLED is writing
## (law 20). Names and blurbs come from story/interface.json keyed by mode.
const GOODS := [
	{
		"mode": "add", "cost": ADD_CARD_COST,
		"seal": "ui/ui_seal_red",
	},
	{
		"mode": "rare", "cost": RARE_CARD_COST,
		"seal": "ui/ui_seal_gold",
	},
	{
		"mode": "remove", "cost": REMOVE_CARD_COST,
		"seal": "ui/ui_seal_blue",
	},
	{
		"mode": "tonic", "cost": TONIC_COST,
		"seal": "ui/ui_seal_red",
	},
]

var catalog: Catalog
var profile: Dictionary

var _gleam_label: Label
var _patter: Label
var _shelf: GridContainer
var _detail_flow: HFlowContainer
var _hint: Label
var _confirm: Dictionary = {}
var _confirm_body: Label
var _pending := Callable()


func setup(p_catalog: Catalog, p_profile: Dictionary) -> void:
	catalog = p_catalog
	profile = p_profile


func _ready() -> void:
	var margin := UITheme.page_scaffold(self)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)
	_build_header(column)
	_build_brindle(column)
	_build_shelf(column)
	_build_detail(column)
	_build_confirm_modal()
	_refresh()
	# He speaks first. An empty speech panel next to a portrait reads as a
	# screen that failed to load, not as a shopkeeper waiting.
	_say(Strings.line("exchange.greeting"))
	_rest()


# ------------------------------------------------------------------- zones

func _build_header(column: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, ZONE_HEADER)
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var back := Button.new()
	back.custom_minimum_size = Vector2(96, 96)
	var arrow := UITheme.tex("ui/ui_arrow_back")
	if arrow != null:
		back.icon = arrow
		back.expand_icon = true
	else:
		back.text = "←"
	back.pressed.connect(func() -> void: closed.emit())
	header.add_child(back)
	var title := UITheme.measured_label("The Magpie\nExchange", 34, 250.0,
		UITheme.display_font())
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_FILL
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var purse := HBoxContainer.new()
	purse.add_theme_constant_override("separation", 6)
	purse.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(purse)
	purse.add_child(UITheme.icon("ui/ui_button_pile", 64.0))
	_gleam_label = UITheme.measured_label("0", 36, 90.0, UITheme.display_font())
	_gleam_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gleam_label.size_flags_vertical = Control.SIZE_FILL
	purse.add_child(_gleam_label)


func _build_brindle(column: VBoxContainer) -> void:
	var band := HBoxContainer.new()
	band.custom_minimum_size = Vector2(0, ZONE_BRINDLE)
	band.add_theme_constant_override("separation", SEPARATION)
	column.add_child(band)
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(PORTRAIT_WIDTH, ZONE_BRINDLE)
	frame.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a2620")
	style.set_border_width_all(3)
	style.border_color = UITheme.INK
	style.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", style)
	band.add_child(frame)
	var art := UITheme.art_or_placeholder("npc_brindle_magpie",
		"Brindle on his hoard")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		art.set_offset(side, 4)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		art.set_offset(side, -4)
	frame.add_child(art)
	var speech := VBoxContainer.new()
	speech.add_theme_constant_override("separation", 8)
	speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band.add_child(speech)
	speech.add_child(UITheme.measured_label("Brindle", 30,
		_speech_wrap(), UITheme.display_font()))
	_patter = UITheme.measured_label("", 24, _speech_wrap(),
		UITheme.italic_font())
	speech.add_child(_patter)


func _build_shelf(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_SHELF)
	holder.add_theme_constant_override("separation", 6)
	column.add_child(holder)
	holder.add_child(UITheme.measured_label("On the shelf", 24,
		UITheme.CONTENT_WIDTH, UITheme.smallcaps_font(), UITheme.INK_SOFT))
	_shelf = GridContainer.new()
	_shelf.columns = SHELF_COLUMNS
	_shelf.add_theme_constant_override("h_separation", SEPARATION)
	_shelf.add_theme_constant_override("v_separation", SEPARATION)
	holder.add_child(_shelf)
	for good: Dictionary in GOODS:
		_shelf.add_child(_good_card(good))


func _build_detail(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_DETAIL)
	column.add_child(holder)
	# A deck can hold many distinct cards to cut, so the options scroll inside
	# the zone instead of growing it (law 12).
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(scroll)
	_detail_flow = HFlowContainer.new()
	_detail_flow.add_theme_constant_override("h_separation", 8)
	_detail_flow.add_theme_constant_override("v_separation", 8)
	_detail_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail_flow)


func _speech_wrap() -> float:
	return UITheme.CONTENT_WIDTH - PORTRAIT_WIDTH - SEPARATION


# ------------------------------------------------------------------- goods

## One plate on the shelf: name, price on a wax seal, one line of what it is.
## Unaffordable goods are faded and un-tappable — visibly out of reach.
func _good_card(good: Dictionary) -> Control:
	var cost := int(good["cost"])
	var affordable := int(profile.get("gleam", 0)) >= cost
	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(GOOD_WIDTH, GOOD_HEIGHT)
	var style := UITheme.panel_stylebox(12)
	if not affordable:
		style.bg_color = Color("e2d5b8")
		style.border_color = Color("a99c82")
	plate.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(box)
	var wrap := GOOD_WIDTH - 24
	var ink: Color = UITheme.INK if affordable else UITheme.INK_FADED
	box.add_child(UITheme.measured_label(Strings.lines("exchange.goods." + String(good["mode"]))[0], 26, wrap,
		UITheme.display_font(), ink))
	var price := HBoxContainer.new()
	price.add_theme_constant_override("separation", 4)
	box.add_child(price)
	var seal := UITheme.icon(String(good["seal"]), 46.0)
	seal.modulate = Color.WHITE if affordable else Color(1, 1, 1, 0.45)
	price.add_child(seal)
	var price_label := UITheme.measured_label("%d gleam" % cost, 24, 140.0,
		UITheme.body_font(), ink)
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.size_flags_vertical = Control.SIZE_FILL
	price.add_child(price_label)
	box.add_child(UITheme.measured_label(Strings.lines("exchange.goods." + String(good["mode"]))[1], 20, wrap,
		UITheme.italic_font(), UITheme.INK_SOFT if affordable else UITheme.INK_FADED))
	if affordable:
		UITheme.tap_layer(plate).pressed.connect(
			_on_good_pressed.bind(String(good["mode"])))
	return plate


# ------------------------------------------------------------------- flow

func _refresh() -> void:
	_gleam_label.text = "%d" % int(profile.get("gleam", 0))
	for child in _shelf.get_children():
		_shelf.remove_child(child)
		child.queue_free()
	for good: Dictionary in GOODS:
		_shelf.add_child(_good_card(good))


func _say(line: String) -> void:
	_patter.text = line
	_patter.custom_minimum_size = Vector2(_speech_wrap(),
		UITheme.measure_text(line, UITheme.italic_font(), 24, _speech_wrap()).y)


## Clearing the strip drops it back to its resting line. The zone is a fixed
## height, so it is either this or a hole in the page — and every path out of
## a purchase (bought, refused, cannot afford) lands here.
func _clear_detail() -> void:
	for child in _detail_flow.get_children():
		_detail_flow.remove_child(child)
		child.queue_free()
	_rest()


func _rest() -> void:
	_hint = UITheme.measured_label(
		"He waits. Tap a thing on the shelf and he will tell you about it.",
		22, UITheme.CONTENT_WIDTH, UITheme.italic_font(), UITheme.INK_SOFT)
	_detail_flow.add_child(_hint)


func _on_good_pressed(mode: String) -> void:
	_clear_detail()
	match mode:
		"add":
			_say(Strings.line("exchange.patter.add"))
			for humour in Catalog.HUMOURS:
				_option("%s 2" % Catalog.humour_name(humour),
					_on_add_card.bind(humour))
		"rare":
			# The only route to the value-3 cards (owner rarity rule): they are
			# rewards and purchases, never starting kit.
			_say(Strings.line("exchange.patter.rare"))
			for humour in Catalog.HUMOURS:
				var card_id := humour + "_3"
				_option("%s (%s)" % [String(catalog.energy_cards[card_id]["name"]),
					Catalog.humour_name(humour)], _on_add_rare.bind(card_id))
		"remove":
			if profile["deck"].size() <= DECK_FLOOR:
				_say(Strings.line("exchange.patter.too_thin"))
				return
			_say(Strings.line("exchange.patter.remove"))
			var seen := {}
			for card_id in profile["deck"]:
				if seen.has(card_id):
					continue
				seen[card_id] = true
				_option(String(catalog.energy_cards[card_id]["name"]),
					_on_remove.bind(String(card_id)))
		"tonic":
			if int(profile["max_hp"]) >= MAX_HP_CAP:
				_say(Strings.line("exchange.patter.no_more_tonic"))
				return
			_spend(TONIC_COST, "a tonic", func() -> void:
				profile["max_hp"] = int(profile["max_hp"]) + 2
				_say(Strings.line("exchange.patter.tonic")))


func _option(text: String, on_pressed: Callable) -> void:
	if _hint != null and is_instance_valid(_hint):
		_detail_flow.remove_child(_hint)
		_hint.queue_free()
		_hint = null
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 62)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(on_pressed)
	_detail_flow.add_child(button)


func _on_add_card(humour: String) -> void:
	_spend(ADD_CARD_COST, Catalog.humour_name(humour) + " 2", func() -> void:
		profile["deck"].append(humour + "_2")
		_say(Strings.line("exchange.patter.bought_card")))


func _on_add_rare(card_id: String) -> void:
	_spend(RARE_CARD_COST, String(catalog.energy_cards[card_id]["name"]),
		func() -> void:
			profile["deck"].append(card_id)
			_say(Strings.line("exchange.patter.bought_rare")))


func _on_remove(card_id: String) -> void:
	_spend(REMOVE_CARD_COST, "cutting " + String(catalog.energy_cards[card_id]["name"]),
		func() -> void:
			profile["deck"].erase(card_id)
			_say(Strings.line("exchange.patter.cut")))


## Every purchase goes through here: one place that checks the purse, one
## place that debits it, and the only place the "ask before spending" setting
## has to be honoured.
func _spend(cost: int, what: String, apply: Callable) -> void:
	if int(profile["gleam"]) < cost:
		_say(Strings.line("exchange.patter.broke"))
		_clear_detail()
		return
	if bool(profile.get("settings", {}).get("ask_to_spend", false)):
		_pending = func() -> void: _commit(cost, apply)
		_confirm_body.text = "%s, for %d gleam. He is already reaching for it." % [
			what.capitalize(), cost]
		_confirm_body.custom_minimum_size = Vector2(452.0, UITheme.measure_text(
			_confirm_body.text, UITheme.body_font(), 24, 452.0).y)
		_confirm["overlay"].visible = true
		return
	_commit(cost, apply)


func _commit(cost: int, apply: Callable) -> void:
	profile["gleam"] = int(profile["gleam"]) - cost
	apply.call()
	_clear_detail()
	profile_changed.emit()
	_refresh()


# ----------------------------------------------------------------- confirm

func _build_confirm_modal() -> void:
	_confirm = UITheme.modal(self, 484.0)
	var dim: Control = _confirm["overlay"]
	# Law 13: an escape path that is not a button. Dim-tap backs out, and the
	# catcher sits UNDER the panel so it never swallows the panel's own taps.
	var catcher := Button.new()
	catcher.flat = true
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.pressed.connect(_close_confirm)
	dim.add_child(catcher)
	dim.move_child(catcher, 0)
	var box: VBoxContainer = _confirm["box"]
	box.add_child(UITheme.measured_label("Spend it?", 32, 452.0,
		UITheme.display_font()))
	_confirm_body = UITheme.measured_label("", 24, 452.0, UITheme.body_font())
	box.add_child(_confirm_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var no := UITheme.dark_button("Not tonight", 24, Vector2(0, UITheme.BUTTON_HEIGHT))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(_close_confirm)
	row.add_child(no)
	var yes := UITheme.amber_button("Spend it", 26)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(func() -> void:
		var pending := _pending
		_close_confirm()
		if pending.is_valid():
			pending.call())
	row.add_child(yes)


func _close_confirm() -> void:
	_pending = Callable()
	_confirm["overlay"].visible = false
