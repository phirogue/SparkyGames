extends Control
## On the Prowl — what Ash carries out the door.
##
## Owner 2026-08-09 pass: the action cards LOOK like the battle tray's —
## same 132x162 ink-bordered card, whole image (never cropped), cost drawn
## as coloured bubbles, uses as ×N — fanned in one row exactly like a fight,
## with the bench below in the same dress. The deck strip got the Exchange's
## big-spool treatment and opens THE SPOOL editor; every card opens LARGE
## before it moves; and when the tray is full the PLAYER chooses what steps
## aside, not the list.
##
## The screen edits profile["loadout"] and profile["deck"] only; the
## collection (profile["card_pool"]) only ever grows, at the Exchange and in
## rewards.

signal closed

## FIXED zone template (law 12): heights + separations == CONTENT_HEIGHT.
## 96 + 236 + 400 + 228 + 96 = 1056, plus 4 x 12 separation = 1104.
const SEPARATION := 12
const ZONE_HEADER := 96
const ZONE_SLOTS := 236
const ZONE_BENCH := 400
const ZONE_DECK := 228
const ZONE_CONFIRM := 96

## Battle parity (owner 2026-08-09): the same card footprint the fight uses.
const SKILL_CARD_SIZE := Vector2(132, 162)
const BENCH_SEPARATION := 10

# The per-humour vocabulary lives in UITheme.HUMOUR_* — one copy everywhere.

var catalog: Catalog
var profile: Dictionary

var _slot_fan: Control
var _bench_flow: HFlowContainer
var _bench_note: Label
var _deck_plate: Panel
var _deck_strip: HBoxContainer
var _skill_modal: Dictionary = {}
var _skill_box: VBoxContainer
var _skill_shown := ""
var _spool_modal: Dictionary = {}
var _spool_box: VBoxContainer
var _spool_rows: VBoxContainer
var _spool_count: Label
## The card that just changed homes; its rebuilt plate settles in visibly so
## the move reads as a move, not as the page blinking.
var _just_moved := ""


## Drawn energy bubbles: one filled circle per point of cost, the humour's
## glyph riding inside in parchment. A close copy of battle.gd's CostPips —
## kept local because battle's version tracks live powering mid-fight and
## battle.gd is its own moving workshop; here every bubble is always full.
class Pips extends Control:
	var total := 0
	var color := Color.BLACK
	var radius := 9.0
	var glyph: Texture2D = null
	func _init(p_total: int, p_color: Color, p_radius := 9.0,
			p_glyph: Texture2D = null) -> void:
		total = p_total
		color = p_color
		radius = p_radius
		glyph = p_glyph
		custom_minimum_size = Vector2(
			total * (radius * 2.0 + 8.0), radius * 2.0 + 6.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var step := radius * 2.0 + 8.0
		var start_x := (size.x - (step * total - 8.0)) / 2.0 + radius
		var cy := size.y / 2.0
		for i in total:
			var c := Vector2(start_x + step * i, cy)
			draw_circle(c, radius, color)
			if glyph != null:
				var g := radius * 1.3
				draw_texture_rect(glyph,
					Rect2(c - Vector2(g, g) / 2.0, Vector2(g, g)), false,
					UITheme.PARCHMENT)
			draw_arc(c, radius, 0.0, TAU, 24, color, 2.0, true)


func _deck_floor() -> int: return catalog.rules.count("exchange.deck_floor")


func setup(p_catalog: Catalog, p_profile: Dictionary) -> void:
	catalog = p_catalog
	profile = p_profile


func _ready() -> void:
	var margin := UITheme.page_scaffold(self)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)
	_build_header(column)
	_build_slots(column)
	_build_bench(column)
	_build_deck(column)
	_build_confirm(column)
	_build_skill_modal()
	_build_spool_modal()
	_refresh()


# ------------------------------------------------------------------- zones

func _build_header(column: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, ZONE_HEADER)
	header.add_theme_constant_override("separation", 16)
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
	var title := UITheme.measured_label("On the Prowl", 44,
		UITheme.CONTENT_WIDTH - 112, UITheme.display_font())
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_FILL
	header.add_child(title)


func _build_slots(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_SLOTS)
	holder.add_theme_constant_override("separation", 6)
	column.add_child(holder)
	holder.add_child(UITheme.measured_label(
		Strings.line("loadout.slots_heading", [SaveService.LOADOUT_SIZE]),
		24, UITheme.CONTENT_WIDTH, UITheme.smallcaps_font(), UITheme.INK_SOFT))
	# The hand, fanned the way the fight fans it (owner 2026-08-09): a plain
	# Control so the cards can overlap; the fan math mirrors battle.gd's.
	_slot_fan = Control.new()
	_slot_fan.custom_minimum_size = Vector2(0, SKILL_CARD_SIZE.y + 10.0)
	holder.add_child(_slot_fan)


func _build_bench(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_BENCH)
	holder.add_theme_constant_override("separation", 6)
	column.add_child(holder)
	_bench_note = UITheme.measured_label(Strings.line("loadout.bench_heading"),
		24, UITheme.CONTENT_WIDTH, UITheme.smallcaps_font(), UITheme.INK_SOFT)
	holder.add_child(_bench_note)
	# Owned skills only grow, so the bench scrolls INSIDE its zone rather than
	# pushing the deck strip and the button off the page (law 12).
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(scroll)
	_bench_flow = HFlowContainer.new()
	_bench_flow.add_theme_constant_override("h_separation", BENCH_SEPARATION)
	_bench_flow.add_theme_constant_override("v_separation", BENCH_SEPARATION)
	_bench_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_bench_flow)


## The deck strip, in the Exchange's dress: one LARGE spool with the count
## under it, the four humours in a 2x2 grid with big ×counts, and the whole
## plate tappable — it IS the door to the editor. The Re-spool button sits in
## the heading row where it fits inside the page (owner 2026-08-09: it used
## to hang past the dashed border).
func _build_deck(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_DECK)
	holder.add_theme_constant_override("separation", 6)
	column.add_child(holder)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	holder.add_child(heading)
	var label := UITheme.measured_label(Strings.line("loadout.deck_heading"),
		24, 380.0, UITheme.smallcaps_font(), UITheme.INK_SOFT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	var respool := UITheme.amber_button(Strings.line("loadout.respool"), 24,
		Vector2(170, 64))
	respool.pressed.connect(_open_spool)
	heading.add_child(respool)
	_deck_plate = Panel.new()
	_deck_plate.custom_minimum_size = Vector2(0, 150)
	_deck_plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := UITheme.panel_stylebox(8)
	style.bg_color = Color("f4e7cd")
	_deck_plate.add_theme_stylebox_override("panel", style)
	holder.add_child(_deck_plate)
	_deck_strip = HBoxContainer.new()
	_deck_strip.add_theme_constant_override("separation", 16)
	_deck_strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		_deck_strip.set_offset(side, 10)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		_deck_strip.set_offset(side, -10)
	_deck_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_plate.add_child(_deck_strip)
	UITheme.tap_layer(_deck_plate).pressed.connect(_open_spool)


## Geometry of the deck strip's humour grid, derived from the page contract:
## plate inner width, minus the spool block and separations, split two ways.
const DECK_CHIP_GLYPH := 36.0
const DECK_SPOOL_BLOCK := 74.0
const DECK_CHIP_WIDTH := (UITheme.CONTENT_WIDTH - 20.0 - DECK_SPOOL_BLOCK \
	- 16.0 - 12.0) / 2.0


func _refresh_deck() -> void:
	_clear(_deck_strip)
	var counts := {}
	for card_id in profile.get("deck", []):
		var humour: String = catalog.energy_cards[card_id]["humour"]
		counts[humour] = int(counts.get(humour, 0)) + 1
	var spool := VBoxContainer.new()
	spool.add_theme_constant_override("separation", 0)
	spool.alignment = BoxContainer.ALIGNMENT_CENTER
	_deck_strip.add_child(spool)
	var icon := UITheme.icon("ui/ui_spool", 64.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spool.add_child(icon)
	var size_label := UITheme.measured_label(
		"%d" % profile.get("deck", []).size(), 34, DECK_SPOOL_BLOCK,
		UITheme.display_font())
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spool.add_child(size_label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_deck_strip.add_child(grid)
	# One LINE per humour (owner 2026-08-10: the stacked name-over-count chip
	# ran its numbers through the plate border, and name and count were both
	# too small). Everything is measured into DECK_CHIP_WIDTH — the name
	# starts at 28 and only shrinks if the measurement says it must (law 4).
	for humour in Catalog.HUMOURS:
		grid.add_child(_deck_chip(String(humour),
			"×%d" % int(counts.get(humour, 0))))


func _deck_chip(humour: String, count_text: String) -> Control:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 8)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var glyph := UITheme.icon(String(UITheme.HUMOUR_GLYPH[humour]), DECK_CHIP_GLYPH)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(glyph)
	var count_width := UITheme.measure_text(count_text,
		UITheme.display_font(), 38, 140.0).x
	var name_text := Catalog.humour_name(humour)
	var name_budget := DECK_CHIP_WIDTH - DECK_CHIP_GLYPH - 16.0 - count_width
	var name_size := 28
	var name_width := UITheme.measure_text(name_text,
		UITheme.smallcaps_font(), name_size, 300.0).x
	while name_size > UITheme.TYPE_FLOOR and name_width > name_budget:
		name_size -= 1
		name_width = UITheme.measure_text(name_text,
			UITheme.smallcaps_font(), name_size, 300.0).x
	var name_label := UITheme.measured_label(name_text, name_size, name_width,
		UITheme.smallcaps_font(), UITheme.INK_SOFT)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_FILL
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_child(name_label)
	var count_label := UITheme.measured_label(count_text, 38, count_width,
		UITheme.display_font(), UITheme.HUMOUR_COLORS[humour])
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.size_flags_vertical = Control.SIZE_FILL
	chip.add_child(count_label)
	return chip


func _build_confirm(column: VBoxContainer) -> void:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_CONFIRM)
	column.add_child(holder)
	# 84 inside a 96 zone: the button clears the page's bottom dashes instead
	# of sitting on them (owner 2026-08-09).
	var confirm := UITheme.amber_button(Strings.line("loadout.confirm"), 32,
		Vector2(UITheme.CONTENT_WIDTH - 24, 84))
	confirm.pressed.connect(func() -> void: closed.emit())
	holder.add_child(confirm)


# ------------------------------------------------------------------- cards

func _refresh() -> void:
	_clear(_slot_fan)
	_clear(_bench_flow)
	var carried := SaveService.battle_loadout(profile)
	var n := SaveService.LOADOUT_SIZE
	# Battle's fan math: full step when it fits, compressed overlap when not.
	var step := minf(SKILL_CARD_SIZE.x + 8.0,
		(UITheme.CONTENT_WIDTH - SKILL_CARD_SIZE.x) / float(n - 1))
	var total_width := step * float(n - 1) + SKILL_CARD_SIZE.x
	var x0 := (UITheme.CONTENT_WIDTH - total_width) / 2.0
	for i in n:
		var card: Control
		if i < carried.size():
			var skill_id := String(carried[i])
			card = _skill_card(skill_id, skill_id == "scratch", true)
			if skill_id == _just_moved:
				UITheme.settle(card)
		else:
			card = _empty_card()
		card.position = Vector2(x0 + step * float(i), 5.0)
		_slot_fan.add_child(card)
	var bench: Array[String] = []
	for skill_id in profile.get("skills", []):
		if skill_id != "scratch" and not carried.has(skill_id):
			bench.append(String(skill_id))
	_bench_note.text = Strings.line("loadout.bench_heading") \
		if not bench.is_empty() else Strings.line("loadout.bench_empty")
	_bench_note.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH,
		UITheme.measure_text(_bench_note.text, UITheme.smallcaps_font(), 24,
			UITheme.CONTENT_WIDTH).y)
	for skill_id in bench:
		var card := _skill_card(skill_id, false, false)
		_bench_flow.add_child(card)
		if skill_id == _just_moved:
			UITheme.settle(card)
	_just_moved = ""
	_refresh_deck()


## A battle-look action card (mirrors battle.gd's _skill_button): ink-border
## plate, the WHOLE picture, the cost as coloured bubbles, uses as ×N, name
## across the bottom. Carried cards wear the warm border; bench cards the
## plain one — the two states still read apart at a glance.
func _skill_card(skill_id: String, locked: bool, carried: bool) -> Button:
	var def: Dictionary = catalog.skills.get(skill_id, {})
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = SKILL_CARD_SIZE
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("f4e7cd")
	card_style.set_border_width_all(3)
	card_style.border_color = UITheme.ACCENT_WARM if carried else UITheme.INK
	card_style.set_corner_radius_all(14)
	card_style.set_content_margin_all(0)
	card.add_theme_stylebox_override("panel", card_style)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(card)
	var art := TextureRect.new()
	art.texture = UITheme.tex("sk_" + skill_id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# KEEP_ASPECT, never cropped (owner 2026-08-09: "large enough to fit the
	# full image") — the art is a subject on parchment, so fitting it leaves
	# parchment margins, not letterbox bars.
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.set_offset(SIDE_LEFT, 6)
	art.set_offset(SIDE_RIGHT, -6)
	art.set_offset(SIDE_TOP, 6)
	art.set_offset(SIDE_BOTTOM, -58)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)
	# The cost band: bubbles for a costed card, a word for a free one.
	var cost: Dictionary = def.get("cost", {})
	if def.get("instinct", false) or cost.is_empty():
		var band := Label.new()
		band.text = Strings.line("skill_rules.free")
		band.add_theme_font_size_override("font_size", 24)
		band.add_theme_color_override("font_color", UITheme.INK_SOFT)
		band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		band.set_offset(SIDE_TOP, -58)
		band.set_offset(SIDE_BOTTOM, -32)
		band.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(band)
	else:
		var pips := _cost_bubbles(cost, 9.0)
		pips.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		pips.set_offset(SIDE_TOP, -58)
		pips.set_offset(SIDE_BOTTOM, -32)
		b.add_child(pips)
	if not def.get("instinct", false):
		var uses := Label.new()
		uses.text = "×%d" % int(def.get("charges", 0))
		uses.add_theme_font_override("font", UITheme.display_font())
		uses.add_theme_font_size_override("font_size", 32)
		uses.add_theme_color_override("font_color", UITheme.INK)
		uses.set_anchors_preset(Control.PRESET_TOP_LEFT)
		uses.set_offset(SIDE_LEFT, 8)
		uses.set_offset(SIDE_RIGHT, 62)
		uses.set_offset(SIDE_TOP, 2)
		uses.set_offset(SIDE_BOTTOM, 34)
		uses.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(uses)
	var name_label := Label.new()
	name_label.text = String(def.get("name", skill_id))
	name_label.add_theme_font_override("font", UITheme.smallcaps_font())
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", UITheme.INK)
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.set_offset(SIDE_TOP, -32)
	name_label.set_offset(SIDE_BOTTOM, -6)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_label)
	if locked:
		# Scratch's padlock is a word: the (always) tag lives in the popup;
		# on the card the warm border and no bench twin already say it stays.
		pass
	b.pressed.connect(_open_skill.bind(skill_id))
	return b


## The cost of a skill as bubbles, one per point, in each humour's colour
## with its glyph inside (owner 2026-08-09).
func _cost_bubbles(cost: Dictionary, radius: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for humour in cost:
		row.add_child(Pips.new(int(cost[humour]),
			UITheme.HUMOUR_COLORS.get(humour, UITheme.INK_SOFT), radius,
			UITheme.cropped_tex(String(UITheme.HUMOUR_GLYPH.get(humour, "")))))
	return row


## The visible gap where a skill could go: the player can count what they
## are not carrying without doing arithmetic.
func _empty_card() -> Control:
	var frame := Panel.new()
	frame.custom_minimum_size = SKILL_CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e6d7b6")
	style.set_border_width_all(3)
	style.border_color = Color("a99c82")
	style.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", style)
	var mark := UITheme.measured_label("—", 44, SKILL_CARD_SIZE.x,
		UITheme.display_font(), Color("a99c82"))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(mark)
	return frame


# --------------------------------------------------------- skill close-up

## The close-up popup, LARGE (owner 2026-08-09): the whole picture, the cost
## as big bubbles beside its words, uses, what it does, and the decision —
## all before a card moves anywhere.
const SKILL_PANEL_WIDTH := 640.0
const SKILL_WRAP := SKILL_PANEL_WIDTH - 32.0


func _build_skill_modal() -> void:
	_skill_modal = UITheme.modal(self, SKILL_PANEL_WIDTH)
	UITheme.modal_escape(_skill_modal, _close_skill)
	_skill_box = _skill_modal["box"]


func _open_skill(skill_id: String) -> void:
	_skill_shown = skill_id
	_refresh_skill()
	UITheme.open_modal(_skill_modal["overlay"], _skill_modal["panel"])


func _refresh_skill() -> void:
	_clear(_skill_box)
	var skill_id := _skill_shown
	var def: Dictionary = catalog.skills.get(skill_id, {})
	var carried := SaveService.battle_loadout(profile).has(skill_id)
	var locked := skill_id == "scratch"
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(SKILL_WRAP, 300.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4e7cd")
	style.set_border_width_all(3)
	style.border_color = UITheme.ACCENT_WARM if carried else Color("a99c82")
	style.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", style)
	_skill_box.add_child(frame)
	var art := TextureRect.new()
	art.texture = UITheme.tex("sk_" + skill_id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# The whole image, contained — the close-up exists to SEE the card.
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		art.set_offset(side, 5)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		art.set_offset(side, -5)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)
	var name_label := UITheme.measured_label(String(def.get("name", skill_id)),
		40, SKILL_WRAP, UITheme.display_font())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_box.add_child(name_label)
	# The cost twice over: bubbles for the eye, words for certainty.
	var cost: Dictionary = def.get("cost", {})
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 12)
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_skill_box.add_child(cost_row)
	if not cost.is_empty() and not def.get("instinct", false):
		var bubbles := _cost_bubbles(cost, 16.0)
		bubbles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cost_row.add_child(bubbles)
	var cost_label := UITheme.measured_label(SkillText.cost_line(def), 28,
		420.0, UITheme.body_font())
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.size_flags_vertical = Control.SIZE_FILL
	cost_row.add_child(cost_label)
	_skill_box.add_child(UITheme.measured_label(SkillText.charges_line(def),
		28, SKILL_WRAP, UITheme.body_font(), UITheme.INK_SOFT))
	var effects := SkillText.effect_summary(def)
	if effects != "":
		_skill_box.add_child(UITheme.measured_label(effects, 30, SKILL_WRAP,
			UITheme.body_font()))
	var flavor := String(def.get("flavor", ""))
	if flavor != "":
		_skill_box.add_child(UITheme.measured_label(flavor, 26, SKILL_WRAP,
			UITheme.italic_font(), UITheme.INK_SOFT))
	if locked:
		_skill_box.add_child(UITheme.measured_label(
			Strings.line("loadout.skill.always"), 26, SKILL_WRAP,
			UITheme.italic_font(), UITheme.ACCENT_WARM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_skill_box.add_child(row)
	if locked:
		var back := UITheme.dark_button(Strings.line("loadout.skill.keep"), 26,
			Vector2(0, UITheme.BUTTON_HEIGHT))
		back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		back.pressed.connect(_close_skill)
		row.add_child(back)
	elif carried:
		var down := UITheme.dark_button(Strings.line("loadout.skill.put_down"),
			26, Vector2(0, UITheme.BUTTON_HEIGHT))
		down.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		down.pressed.connect(func() -> void:
			_unequip(skill_id)
			_close_skill())
		row.add_child(down)
		var keep := UITheme.amber_button(Strings.line("loadout.skill.keep"), 30)
		keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keep.pressed.connect(_close_skill)
		row.add_child(keep)
	else:
		var leave := UITheme.dark_button(Strings.line("loadout.skill.leave"),
			26, Vector2(0, UITheme.BUTTON_HEIGHT))
		leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		leave.pressed.connect(_close_skill)
		row.add_child(leave)
		var take := UITheme.amber_button(Strings.line("loadout.skill.take"), 30)
		take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		take.pressed.connect(func() -> void: _equip(skill_id))
		row.add_child(take)


func _close_skill() -> void:
	_skill_shown = ""
	UITheme.close_modal(_skill_modal["overlay"], _skill_modal["panel"])


# ------------------------------------------------------------------ edits

func _unequip(skill_id: String) -> void:
	var picked := _picked()
	picked.erase(skill_id)
	_just_moved = skill_id
	_apply(picked)


## Taking a card along. With room, it just goes. With a FULL tray, the
## player chooses what steps aside (owner 2026-08-09) — the popup turns into
## that choice instead of the oldest pick silently leaving.
func _equip(skill_id: String) -> void:
	var picked := _picked()
	if picked.has(skill_id):
		_close_skill()
		return
	if picked.size() < SaveService.LOADOUT_SIZE - 1:
		picked.append(skill_id)
		_just_moved = skill_id
		_apply(picked)
		_close_skill()
		return
	_show_swap_choice(skill_id)


## The tray is full: which of the carried cards does `incoming` replace?
## Every current pick is offered; Scratch is not, because Scratch stays.
func _show_swap_choice(incoming: String) -> void:
	_clear(_skill_box)
	_skill_box.add_child(UITheme.measured_label(
		Strings.line("loadout.swap_title"), 34, SKILL_WRAP,
		UITheme.display_font()))
	var incoming_def: Dictionary = catalog.skills.get(incoming, {})
	_skill_box.add_child(UITheme.measured_label(
		Strings.line("loadout.swap_blurb",
			[String(incoming_def.get("name", incoming))]), 26, SKILL_WRAP,
		UITheme.italic_font(), UITheme.INK_SOFT))
	var picked := _picked()
	for i in picked.size():
		var out_id := String(picked[i])
		var def: Dictionary = catalog.skills.get(out_id, {})
		var plate := PanelContainer.new()
		plate.add_theme_stylebox_override("panel", UITheme.panel_stylebox(10))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(line)
		var art := TextureRect.new()
		art.texture = UITheme.tex("sk_" + out_id)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(84, 76)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(art)
		var name_label := UITheme.measured_label(
			String(def.get("name", out_id)), 30, 380.0, UITheme.display_font())
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.size_flags_vertical = Control.SIZE_FILL
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		UITheme.tap_layer(plate).pressed.connect(_apply_swap.bind(i, incoming))
		_skill_box.add_child(plate)
	var back := UITheme.dark_button(Strings.line("loadout.skill.leave"), 26,
		Vector2(0, UITheme.BUTTON_HEIGHT))
	back.pressed.connect(_close_skill)
	_skill_box.add_child(back)


func _apply_swap(index: int, incoming: String) -> void:
	var picked := _picked()
	if index >= 0 and index < picked.size():
		picked[index] = incoming
	_just_moved = incoming
	_apply(picked)
	_close_skill()


## Materialize the current (possibly auto-derived) loadout as an editable list.
func _picked() -> Array:
	var picked: Array = SaveService.battle_loadout(profile)
	picked.erase("scratch")
	return picked


func _apply(picked: Array) -> void:
	profile["loadout"] = picked
	_refresh()


# --------------------------------------------------------------- the spool

## The Spool: every energy card OWNED, with how many are wound on to go out
## — the per-value counts the deck chips can only hint at. Winding is free
## (owner 2026-08-08); the only rule is the floor.
func _build_spool_modal() -> void:
	_spool_modal = UITheme.modal(self, 560.0)
	UITheme.modal_escape(_spool_modal, _close_spool)
	_spool_box = _spool_modal["box"]
	var wrap := 528.0
	_spool_box.add_child(UITheme.measured_label(
		Strings.line("loadout.spool.title"), 34, wrap, UITheme.display_font()))
	_spool_box.add_child(UITheme.measured_label(
		Strings.line("loadout.spool.blurb"), 24, wrap,
		UITheme.italic_font(), UITheme.INK_SOFT))
	_spool_count = UITheme.measured_label("", 26, wrap, UITheme.body_font())
	_spool_box.add_child(_spool_count)
	# Twelve card kinds at most, but a phone screen holds eight rows: the
	# rows scroll inside a fixed window instead of growing the panel off the
	# page (law 12 applies to modals too).
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(wrap, 540.0)
	_spool_box.add_child(scroll)
	_spool_rows = VBoxContainer.new()
	_spool_rows.add_theme_constant_override("separation", 8)
	_spool_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_spool_rows)
	var done := UITheme.amber_button(Strings.line("loadout.spool.done"), 28)
	done.pressed.connect(_close_spool)
	_spool_box.add_child(done)


func _open_spool() -> void:
	_refresh_spool()
	UITheme.open_modal(_spool_modal["overlay"], _spool_modal["panel"])


func _close_spool() -> void:
	UITheme.close_modal(_spool_modal["overlay"], _spool_modal["panel"])


## The collection, as counts per card id. Defensive about card_pool because
## hand-written scenario specs predate it — the deck is always covered.
func _pool_counts() -> Dictionary:
	var pool: Array = SaveService._pool_covering(
		profile.get("card_pool", []), profile.get("deck", []))
	var counts := {}
	for card_id in pool:
		counts[card_id] = int(counts.get(card_id, 0)) + 1
	return counts


func _deck_counts() -> Dictionary:
	var counts := {}
	for card_id in profile.get("deck", []):
		counts[card_id] = int(counts.get(card_id, 0)) + 1
	return counts


func _refresh_spool() -> void:
	var deck_size: int = profile.get("deck", []).size()
	var pool_total := 0
	var pool := _pool_counts()
	for card_id in pool:
		pool_total += int(pool[card_id])
	_spool_count.text = Strings.line("loadout.spool.count",
		[deck_size, pool_total - deck_size])
	if deck_size <= _deck_floor():
		_spool_count.text += "  " + Strings.line("loadout.spool.floor",
			[_deck_floor()])
	_clear(_spool_rows)
	var deck := _deck_counts()
	# Shelf order: the four humours as the game always lists them, thinnest
	# card first — the same order the Exchange sells them in.
	for humour in Catalog.HUMOURS:
		for value in [1, 2, 3]:
			var card_id := "%s_%d" % [String(humour), value]
			if int(pool.get(card_id, 0)) < 1:
				continue
			_spool_rows.add_child(_spool_row(card_id,
				int(deck.get(card_id, 0)), int(pool.get(card_id, 0))))


## One kind of card: its worth as bubbles, its NAME (the name it is called
## everywhere), and the wind-on / wind-off steppers with the counts between.
func _spool_row(card_id: String, in_deck: int, owned: int) -> Control:
	var def: Dictionary = catalog.energy_cards[card_id]
	var humour := String(def["humour"])
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UITheme.panel_stylebox(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	plate.add_child(row)
	var pips := Pips.new(int(def["value"]),
		UITheme.HUMOUR_COLORS.get(humour, UITheme.INK_SOFT), 10.0,
		UITheme.cropped_tex(String(UITheme.HUMOUR_GLYPH[humour])))
	pips.custom_minimum_size.x = 3 * 28.0
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UITheme.measured_label(String(def["name"]), 26, 180.0,
		UITheme.display_font()))
	text.add_child(UITheme.measured_label(
		"%s %d" % [Catalog.humour_name(humour), int(def["value"])], 22, 180.0,
		UITheme.body_font(), UITheme.HUMOUR_COLORS[humour]))
	var minus := UITheme.dark_button("-", 30, Vector2(72, 72))
	minus.disabled = in_deck < 1 \
		or profile.get("deck", []).size() <= _deck_floor()
	minus.pressed.connect(_wind_off.bind(card_id))
	row.add_child(minus)
	var count := UITheme.measured_label("%d/%d" % [in_deck, owned], 26, 80.0,
		UITheme.display_font())
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.size_flags_vertical = Control.SIZE_FILL
	row.add_child(count)
	var plus := UITheme.amber_button("+", 30, Vector2(72, 72))
	plus.disabled = in_deck >= owned
	plus.pressed.connect(_wind_on.bind(card_id))
	row.add_child(plus)
	return plate


func _wind_on(card_id: String) -> void:
	var deck := _deck_counts()
	var pool := _pool_counts()
	if int(deck.get(card_id, 0)) >= int(pool.get(card_id, 0)):
		return
	profile["deck"].append(card_id)
	_after_wind()


func _wind_off(card_id: String) -> void:
	if profile.get("deck", []).size() <= _deck_floor():
		return
	if not profile.get("deck", []).has(card_id):
		return
	profile["deck"].erase(card_id)
	_after_wind()


func _after_wind() -> void:
	# The pool never changes here — winding is selection, not spending.
	profile["card_pool"] = SaveService._pool_covering(
		profile.get("card_pool", []), profile.get("deck", []))
	_refresh_spool()
	_refresh_deck()
	UITheme.pulse(_spool_count, 1.06)


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
