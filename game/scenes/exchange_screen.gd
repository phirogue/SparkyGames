extends Control
## The Magpie Exchange — the market, and a conversation with Brindle rather
## than a table of prices. Her portrait says what she thinks of your purse;
## the shelf holds the goods with a wax seal for a price tag; choosing one
## opens a POPUP of what is on offer next to what you already hold, and a
## second tap shows any one thing close up before a coin moves (owner
## 2026-08-08: nothing is bought blind).
##
## Cutting cards is not sold here any more — re-spooling is free and lives on
## the loadout screen ("On the Prowl"). Brindle only ever sells.

signal closed
signal profile_changed

## FIXED zone template (law 12): heights + separations == CONTENT_HEIGHT.
## 96 + 300 + 480 + 192 = 1068, plus 3 x 12 separation = 1104.
const SEPARATION := 12
const ZONE_HEADER := 96
const ZONE_BRINDLE := 300
const ZONE_SHELF := 480
const ZONE_SPOOL := 192

const PORTRAIT_WIDTH := 208.0
const SHELF_COLUMNS := 2
const GOOD_WIDTH := (UITheme.CONTENT_WIDTH - SEPARATION) / SHELF_COLUMNS  # 285
const GOOD_HEIGHT := 216

# The per-humour vocabulary lives in UITheme.HUMOUR_* — one copy everywhere.

## THE SHELF IS DATA. What each good COSTS is a rule (data/rules.json
## `exchange`), what it is CALLED is writing (story/interface.json, keyed by
## mode — law 20), and this screen owns neither.
##
##   exchange.goods       [{mode, cost, seal}] — the shelf, in shelf order
##   exchange.max_hp_cap  the ceiling a tonic will not lift Ash past
##   exchange.tonic_hp    what one tonic adds
func _goods() -> Array: return catalog.rules.list("exchange.goods")
func _max_hp_cap() -> int: return catalog.rules.count("exchange.max_hp_cap")
func _tonic_hp() -> int: return catalog.rules.count("exchange.tonic_hp")


## What one good costs, by mode — and by humour. Moonlight is wild AND rare,
## so `exchange.humour_mult` prices it above the board rate (owner 2026-08-10:
## a flat price let a purse become an all-Moonlight deck). A mode with no
## shelf entry returns a price nobody can pay rather than a free good — a
## missing dial must never hand the player something for nothing.
func _cost(mode: String, humour: String = "") -> int:
	for good: Dictionary in _goods():
		if String(good.get("mode", "")) == mode:
			var base := int(good.get("cost", 0))
			if humour == "":
				return base
			var mult := float(catalog.rules.table("exchange.humour_mult") \
				.get(humour, 1.0))
			return int(ceil(base * mult))
	push_error("exchange: no good on the shelf for mode '%s'" % mode)
	return 999999


## Does this mode's price differ by humour? Decides whether the shelf says
## "6 gleam" or "from 6 gleam".
func _priced_by_humour(mode: String) -> bool:
	if mode == "tonic":
		return false
	for humour in catalog.rules.table("exchange.humour_mult"):
		if float(catalog.rules.table("exchange.humour_mult")[humour]) != 1.0:
			return true
	return false

var catalog: Catalog
var profile: Dictionary

var _gleam_label: Label
var _patter: Label
var _shelf: GridContainer
var _spool_strip: HBoxContainer
var _shop: Dictionary = {}
var _shop_box: VBoxContainer
var _shop_mode := ""
var _shop_card := ""
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
	_build_spool(column)
	_build_shop_modal()
	_build_confirm_modal()
	_refresh()
	# She speaks first. An empty speech panel next to a portrait reads as a
	# screen that failed to load, not as a shopkeeper waiting.
	_say(Strings.line("exchange.greeting"))


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
	# The purse is the number every decision on this page hangs off, so it is
	# drawn at battle-header scale, not caption scale (owner 2026-08-09).
	purse.add_child(UITheme.icon("ui/ui_button_pile", 88.0))
	_gleam_label = UITheme.measured_label("0", 46, 110.0, UITheme.display_font())
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
		"Brindle on her hoard")
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
	speech.add_child(UITheme.measured_label("Brindle", 34,
		_speech_wrap(), UITheme.display_font()))
	# Her voice at battle-text size (owner 2026-08-09: the patter was set like
	# a footnote and she is the whole top of the page).
	_patter = UITheme.measured_label("", 32, _speech_wrap(),
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


## What the player already holds, always in view while shopping (owner
## 2026-08-08): the spool count and each humour's share. Owner 2026-08-09:
## one LARGE spool, the humours on two lines, and the counts big — this
## strip is a gauge, and gauges are read, not squinted at.
func _build_spool(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_SPOOL)
	holder.add_theme_constant_override("separation", 6)
	column.add_child(holder)
	holder.add_child(UITheme.measured_label(Strings.line("exchange.spool_heading"),
		24, UITheme.CONTENT_WIDTH, UITheme.smallcaps_font(), UITheme.INK_SOFT))
	_spool_strip = HBoxContainer.new()
	_spool_strip.add_theme_constant_override("separation", 16)
	holder.add_child(_spool_strip)


func _refresh_spool() -> void:
	for child in _spool_strip.get_children():
		_spool_strip.remove_child(child)
		child.queue_free()
	var counts := {}
	for card_id in profile.get("deck", []):
		var humour := String(catalog.energy_cards[card_id]["humour"])
		counts[humour] = int(counts.get(humour, 0)) + 1
	var spool := VBoxContainer.new()
	spool.add_theme_constant_override("separation", 0)
	_spool_strip.add_child(spool)
	var icon := UITheme.icon("ui/ui_spool", 100.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spool.add_child(icon)
	var size_label := UITheme.measured_label(
		"%d" % profile.get("deck", []).size(), 38, 110.0, UITheme.display_font())
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spool.add_child(size_label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spool_strip.add_child(grid)
	# One LINE per humour, name and count both large and MEASURED (owner
	# 2026-08-10, same pass as the loadout's deck strip: stacked chips ran
	# their numbers through the surrounding box).
	for humour in Catalog.HUMOURS:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 8)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(chip)
		var glyph := UITheme.icon(String(UITheme.HUMOUR_GLYPH[humour]), 40.0)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(glyph)
		var count_text := "×%d" % int(counts.get(humour, 0))
		var count_width := UITheme.measure_text(count_text,
			UITheme.display_font(), 38, 140.0).x
		var name_text := Catalog.humour_name(humour)
		var chip_width := (UITheme.CONTENT_WIDTH - 110.0 - 16.0 - 14.0) / 2.0
		var name_budget := chip_width - 40.0 - 16.0 - count_width
		var name_size := 28
		var name_width := UITheme.measure_text(name_text,
			UITheme.smallcaps_font(), name_size, 300.0).x
		while name_size > UITheme.TYPE_FLOOR and name_width > name_budget:
			name_size -= 1
			name_width = UITheme.measure_text(name_text,
				UITheme.smallcaps_font(), name_size, 300.0).x
		var name_label := UITheme.measured_label(name_text, name_size,
			name_width, UITheme.smallcaps_font(), UITheme.INK_SOFT)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.size_flags_vertical = Control.SIZE_FILL
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_child(name_label)
		var count_label := UITheme.measured_label(count_text, 38, count_width,
			UITheme.display_font())
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.size_flags_vertical = Control.SIZE_FILL
		chip.add_child(count_label)


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
	# Battle-screen type scale (owner 2026-08-09): the shelf is read at arm's
	# length, and 20px flavour under a 26px name was footnote territory.
	var wrap := GOOD_WIDTH - 24
	var ink: Color = UITheme.INK if affordable else UITheme.INK_FADED
	box.add_child(UITheme.measured_label(Strings.lines("exchange.goods." + String(good["mode"]))[0], 30, wrap,
		UITheme.display_font(), ink))
	var price := HBoxContainer.new()
	price.add_theme_constant_override("separation", 6)
	box.add_child(price)
	var seal := UITheme.icon(String(good["seal"]), 54.0)
	seal.modulate = Color.WHITE if affordable else Color(1, 1, 1, 0.45)
	price.add_child(seal)
	var price_key := "exchange.popup.price_from" \
		if _priced_by_humour(String(good["mode"])) else "exchange.popup.price"
	var price_label := UITheme.measured_label(
		Strings.line(price_key, [cost]), 30, 160.0,
		UITheme.display_font(), UITheme.ACCENT_WARM if affordable else ink)
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.size_flags_vertical = Control.SIZE_FILL
	price.add_child(price_label)
	box.add_child(UITheme.measured_label(Strings.lines("exchange.goods." + String(good["mode"]))[1], 24, wrap,
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
	for good: Dictionary in _goods():
		_shelf.add_child(_good_card(good))
	_refresh_spool()


func _say(line: String) -> void:
	_patter.text = line
	_patter.custom_minimum_size = Vector2(_speech_wrap(),
		UITheme.measure_text(line, UITheme.italic_font(), 32, _speech_wrap()).y)


func _on_good_pressed(mode: String) -> void:
	_shop_mode = mode
	match mode:
		"plain":
			_say(Strings.line("exchange.patter.plain"))
			_shop_card = ""
		"add":
			_say(Strings.line("exchange.patter.add"))
			_shop_card = ""
		"rare":
			_say(Strings.line("exchange.patter.rare"))
			_shop_card = ""
		"tonic":
			# One item only, so the popup opens straight on the close-up.
			if int(profile["max_hp"]) >= _max_hp_cap():
				_say(Strings.line("exchange.patter.no_more_tonic"))
				_shop_mode = ""
				return
			_shop_card = "tonic"
	_refresh_shop()
	UITheme.open_modal(_shop["overlay"], _shop["panel"])


# ----------------------------------------------------------------- the shop

## The counter popup. One modal, two views: the LIST of what is on offer
## (each with what you already hold of it), and the CLOSE-UP of one thing
## with its full explanation and the buy button. Which cards a mode offers is
## content: value-2s for the shelf, value-3s for the good shelf.
func _build_shop_modal() -> void:
	_shop = UITheme.modal(self, 520.0)
	UITheme.modal_escape(_shop, _close_shop)
	_shop_box = _shop["box"]


## Which value a shelf mode sells: firsts, seconds or thirds. The VALUE is
## the whole difference between the goods, so the popup draws it as one
## glyph per point of worth (owner 2026-08-09: "a second is twice a plain
## card" was invisible when every card wore a single icon).
const MODE_VALUE := {"plain": 1, "add": 2, "rare": 3}


func _offered_cards() -> Array[String]:
	var value: int = MODE_VALUE.get(_shop_mode, 2)
	var out: Array[String] = []
	for humour in Catalog.HUMOURS:
		var card_id := "%s_%d" % [humour, value]
		if catalog.energy_cards.has(card_id):
			out.append(card_id)
	return out


## One glyph per point of worth, in the humour's own mark.
func _value_pips(humour: String, value: int, glyph_size: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _i in value:
		row.add_child(UITheme.icon(String(UITheme.HUMOUR_GLYPH[humour]), glyph_size))
	return row


func _owned_count(card_id: String) -> int:
	var pool: Array = profile.get("card_pool", profile.get("deck", []))
	return pool.count(card_id)


func _refresh_shop() -> void:
	for child in _shop_box.get_children():
		_shop_box.remove_child(child)
		child.queue_free()
	if _shop_card == "tonic":
		_build_tonic_detail()
	elif _shop_card != "":
		_build_card_detail(_shop_card)
	else:
		_build_offer_list()


func _build_offer_list() -> void:
	var wrap := 488.0
	var title := UITheme.measured_label(
		Strings.lines("exchange.goods." + _shop_mode)[0], 36, wrap,
		UITheme.display_font())
	_shop_box.add_child(title)
	_shop_box.add_child(UITheme.measured_label(
		Strings.line("exchange.popup.on_offer"), 26, wrap,
		UITheme.smallcaps_font(), UITheme.INK_SOFT))
	var row_index := 0
	for card_id in _offered_cards():
		var row := _offer_row(card_id)
		_shop_box.add_child(row)
		UITheme.settle(row, row_index * 0.05)
		row_index += 1


## One card on the counter: its worth drawn as pips, its NAME (the same name
## the battle and the spool use), what you hold of it, and the price large.
func _offer_row(card_id: String) -> Control:
	var def: Dictionary = catalog.energy_cards[card_id]
	var humour := String(def["humour"])
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UITheme.panel_stylebox(10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	# Three pips of reserved width always, so the names column lines up row
	# to row and a one-pip card is VISIBLY lighter than a three-pip one.
	var pips := _value_pips(humour, int(def["value"]), 36.0)
	pips.custom_minimum_size = Vector2(3 * 38.0, 40.0)
	pips.alignment = BoxContainer.ALIGNMENT_BEGIN
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(UITheme.measured_label(String(def["name"]), 30, 220.0,
		UITheme.display_font()))
	text.add_child(UITheme.measured_label(
		Strings.line("exchange.popup.worth", [int(def["value"]),
			Catalog.humour_name(humour)]), 22, 220.0,
		UITheme.body_font(), UITheme.INK_SOFT))
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 2)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(side)
	var price := UITheme.measured_label(
		Strings.line("exchange.popup.price", [_cost(_shop_mode, humour)]), 32, 140.0,
		UITheme.display_font(), UITheme.ACCENT_WARM)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	side.add_child(price)
	var owned := _owned_count(card_id)
	if owned > 0:
		var held := UITheme.measured_label(
			Strings.line("exchange.popup.you_hold", [owned]), 22, 140.0,
			UITheme.italic_font(), UITheme.INK_SOFT)
		held.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		side.add_child(held)
	UITheme.tap_layer(plate).pressed.connect(_show_card_detail.bind(card_id))
	return plate


func _show_card_detail(card_id: String) -> void:
	_shop_card = card_id
	_refresh_shop()
	UITheme.pulse(_shop["panel"], 1.03)


## The close-up: everything a coin-holder is owed before deciding. What the
## humour MEANS comes from the weft (story/world/weft.json) — the same words
## the Casebook teaches with, so the shop never invents lore.
func _build_card_detail(card_id: String) -> void:
	var def: Dictionary = catalog.energy_cards[card_id]
	var humour := String(def["humour"])
	var wrap := 488.0
	# Worth drawn, not implied: one big glyph per point, so a second reads as
	# TWO of something and a third as three (owner 2026-08-09).
	var pips := _value_pips(humour, int(def["value"]), 64.0)
	pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_shop_box.add_child(pips)
	var name_label := UITheme.measured_label(String(def["name"]), 40, wrap,
		UITheme.display_font())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_box.add_child(name_label)
	var worth := UITheme.measured_label(Strings.line("exchange.popup.worth",
		[int(def["value"]), Catalog.humour_name(humour)]), 30, wrap,
		UITheme.body_font())
	worth.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_box.add_child(worth)
	var nature := String(catalog.world.get("weft", {}).get("humours", {}) \
		.get(humour, {}).get("nature", ""))
	if nature != "":
		_shop_box.add_child(UITheme.measured_label(nature, 26, wrap,
			UITheme.italic_font(), UITheme.INK_SOFT))
	var owned := _owned_count(card_id)
	if owned > 0:
		var held := UITheme.measured_label(
			Strings.line("exchange.popup.you_hold", [owned]), 24, wrap,
			UITheme.italic_font(), UITheme.INK_SOFT)
		held.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_box.add_child(held)
	if humour == catalog.rules.text("combat.wild_humour") \
			and _cost(_shop_mode, humour) > _cost(_shop_mode):
		_say(Strings.line("exchange.patter.moon_dear"))
	_shop_box.add_child(_price_line(_cost(_shop_mode, humour)))
	_shop_box.add_child(_shop_buttons(_cost(_shop_mode, humour)))


func _build_tonic_detail() -> void:
	var wrap := 488.0
	var title := UITheme.measured_label(
		Strings.lines("exchange.goods.tonic")[0], 40, wrap,
		UITheme.display_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_box.add_child(title)
	_shop_box.add_child(UITheme.measured_label(
		Strings.lines("exchange.goods.tonic")[1], 26, wrap,
		UITheme.italic_font(), UITheme.INK_SOFT))
	_shop_box.add_child(UITheme.measured_label(
		Strings.line("exchange.popup.tonic_rule",
			[_tonic_hp(), _max_hp_cap(), int(profile["max_hp"])]), 30, wrap,
		UITheme.body_font()))
	_shop_box.add_child(_price_line(_cost("tonic")))
	_shop_box.add_child(_shop_buttons(_cost("tonic")))


## The price in huge letters (owner 2026-08-09): the one number the decision
## turns on, at the largest size on the panel.
func _price_line(cost: int) -> Control:
	var price := UITheme.measured_label(
		Strings.line("exchange.popup.price", [cost]), 52, 488.0,
		UITheme.display_font(), UITheme.ACCENT_WARM)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return price


## Back on the left, buy on the right — every close-up ends in the same two
## choices, and the buy button STATES the price so the decision and the cost
## are read in the same glance.
func _shop_buttons(cost: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var back := UITheme.dark_button(Strings.line("exchange.popup.back"), 26,
		Vector2(0, UITheme.BUTTON_HEIGHT))
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_shop_back)
	row.add_child(back)
	var buy := UITheme.amber_button(Strings.line("exchange.popup.buy", [cost]), 30)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.disabled = int(profile.get("gleam", 0)) < cost
	buy.pressed.connect(_buy_current)
	row.add_child(buy)
	return row


## Back means back one LEVEL: a card close-up returns to the list it came
## from; the tonic (which has no list) puts the whole popup down.
func _shop_back() -> void:
	if _shop_card == "tonic" or _shop_mode == "tonic":
		_close_shop()
		return
	_shop_card = ""
	_refresh_shop()


func _close_shop() -> void:
	_shop_card = ""
	_shop_mode = ""
	UITheme.close_modal(_shop["overlay"], _shop["panel"])


func _buy_current() -> void:
	if _shop_card == "tonic":
		_spend(_cost("tonic"), Strings.lines("exchange.goods.tonic")[0],
			func() -> void:
				profile["max_hp"] = int(profile["max_hp"]) + _tonic_hp()
				_say(Strings.line("exchange.patter.tonic")))
		return
	var card_id := _shop_card
	var mode := _shop_mode
	_spend(_cost(mode, String(catalog.energy_cards[card_id]["humour"])),
		String(catalog.energy_cards[card_id]["name"]),
		func() -> void:
			SaveService.grant_card(profile, card_id)
			_say(Strings.line("exchange.patter.bought_rare" if mode == "rare"
				else "exchange.patter.bought_card")))


## Every purchase goes through here: one place that checks the purse, one
## place that debits it, and the only place the "ask before spending" setting
## has to be honoured.
func _spend(cost: int, what: String, apply: Callable) -> void:
	if int(profile["gleam"]) < cost:
		SfxService.cue("ui_reject")
		_say(Strings.line("exchange.patter.broke"))
		_close_shop()
		return
	if bool(profile.get("settings", {}).get("ask_to_spend", false)):
		_pending = func() -> void: _commit(cost, apply)
		_confirm_body.text = Strings.line("exchange.popup.spend_body",
			[what, cost])
		_confirm_body.custom_minimum_size = Vector2(452.0, UITheme.measure_text(
			_confirm_body.text, UITheme.body_font(), 24, 452.0).y)
		UITheme.open_modal(_confirm["overlay"], _confirm["panel"])
		return
	_commit(cost, apply)


func _commit(cost: int, apply: Callable) -> void:
	# Checked HERE as well as at _spend: the confirm dialog leaves a window
	# (a double-tapped seal, a queued second purchase) between the check and
	# the debit, and a purse must never go negative through it.
	if int(profile["gleam"]) < cost:
		SfxService.cue("ui_reject")
		_say(Strings.line("exchange.patter.broke"))
		_close_shop()
		return
	profile["gleam"] = int(profile["gleam"]) - cost
	apply.call()
	_close_shop()
	profile_changed.emit()
	_refresh()
	# The receipt, felt AND heard: the purse thins and the spool takes the
	# winding. Coins are the one sound in the game that means money left.
	SfxService.cue("coins")
	UITheme.pulse(_gleam_label)
	UITheme.pulse(_spool_strip, 1.08)


# ----------------------------------------------------------------- confirm

func _build_confirm_modal() -> void:
	_confirm = UITheme.modal(self, 484.0)
	# Law 13: an escape path that is not a button — a dim-tap backs out.
	UITheme.modal_escape(_confirm, _close_confirm)
	var box: VBoxContainer = _confirm["box"]
	box.add_child(UITheme.measured_label(
		Strings.line("exchange.popup.spend_title"), 32, 452.0,
		UITheme.display_font()))
	_confirm_body = UITheme.measured_label("", 24, 452.0, UITheme.body_font())
	box.add_child(_confirm_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var no := UITheme.dark_button(Strings.line("exchange.popup.spend_no"), 24,
		Vector2(0, UITheme.BUTTON_HEIGHT))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(_close_confirm)
	row.add_child(no)
	var yes := UITheme.amber_button(Strings.line("exchange.popup.spend_yes"), 26)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(func() -> void:
		var pending := _pending
		_close_confirm()
		if pending.is_valid():
			pending.call())
	row.add_child(yes)


func _close_confirm() -> void:
	_pending = Callable()
	UITheme.close_modal(_confirm["overlay"], _confirm["panel"])
