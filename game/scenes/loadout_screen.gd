extends Control
## On the Prowl — what Ash carries out the door, built to
## assets/library/mockups/mock_loadout.png: framed skill cards for the slots,
## a bench of everything owned but left behind, and the deck read out in
## humour glyphs underneath.
##
## Two close-ups hang off the page (owner 2026-08-08):
##   - tap any skill card and it opens LARGE — art, cost, uses, what it does
##     — before deciding to take it along or set it down. A tap never moves
##     a card sight-unseen any more.
##   - the deck strip opens THE SPOOL, where the energy cards that go out are
##     wound on and off for free from everything owned (profile["card_pool"]).
##     Cutting stopped being a Magpie purchase the same day.
##
## The screen edits profile["loadout"] and profile["deck"] only; the
## collection itself only ever grows, at the Exchange and in rewards.

signal closed

## FIXED zone template (law 12): heights + separations == CONTENT_HEIGHT.
## 96 + 460 + 300 + 104 + 96 = 1056, plus 4 x 12 separation = 1104.
const SEPARATION := 12
const ZONE_HEADER := 96
const ZONE_SLOTS := 460
const ZONE_BENCH := 300
const ZONE_DECK := 104
const ZONE_CONFIRM := 96

const SLOT_COLUMNS := 3
const SLOT_WIDTH := (UITheme.CONTENT_WIDTH - (SLOT_COLUMNS - 1) * SEPARATION) / SLOT_COLUMNS  # 186
const SLOT_HEIGHT := 205
const SLOT_ART_HEIGHT := 138

const BENCH_COLUMNS := 4
const BENCH_SEPARATION := 10
const BENCH_WIDTH := (UITheme.CONTENT_WIDTH - (BENCH_COLUMNS - 1) * BENCH_SEPARATION) / BENCH_COLUMNS  # 138
const BENCH_HEIGHT := 124
const BENCH_ART_HEIGHT := 76

## Same mapping the battle screen uses — one vocabulary of colour per humour.
const HUMOUR_COLORS := {
	"ferocity": Color("a24a3a"),
	"guile": Color("4a7a5a"),
	"shadow": Color("3a3a42"),
	"mysticism": Color("5a6a9a"),
}
const HUMOUR_GLYPHS := {
	"ferocity": "energy_claw",
	"guile": "energy_eye",
	"shadow": "energy_shade",
	"mysticism": "energy_moon",
}

var catalog: Catalog
var profile: Dictionary

var _slot_grid: GridContainer
var _bench_flow: HFlowContainer
var _bench_note: Label
var _deck_strip: HBoxContainer
var _skill_modal: Dictionary = {}
var _skill_box: VBoxContainer
var _skill_shown := ""
var _spool_modal: Dictionary = {}
var _spool_box: VBoxContainer
var _spool_rows: VBoxContainer
var _spool_count: Label
## The card that just changed homes; its rebuilt plate settles in visibly so
## the move reads as a move, not as the page blinking (owner: animations).
var _just_moved := ""


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
	_slot_grid = GridContainer.new()
	_slot_grid.columns = SLOT_COLUMNS
	_slot_grid.add_theme_constant_override("h_separation", SEPARATION)
	_slot_grid.add_theme_constant_override("v_separation", SEPARATION)
	holder.add_child(_slot_grid)


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


## The deck strip: a live readout of what is wound on, and the door to
## changing it. The counts rebuild on every edit, so they live in their own
## strip container (law 25: rebuildable content gets its own child layer).
func _build_deck(column: VBoxContainer) -> void:
	var holder := HBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_DECK)
	holder.add_theme_constant_override("separation", 10)
	column.add_child(holder)
	_deck_strip = HBoxContainer.new()
	_deck_strip.add_theme_constant_override("separation", 10)
	_deck_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(_deck_strip)
	var respool := UITheme.amber_button(Strings.line("loadout.respool"), 24,
		Vector2(150, UITheme.BUTTON_HEIGHT))
	respool.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	respool.pressed.connect(_open_spool)
	holder.add_child(respool)


func _refresh_deck() -> void:
	_clear(_deck_strip)
	var counts := {}
	for card_id in profile.get("deck", []):
		var humour: String = catalog.energy_cards[card_id]["humour"]
		counts[humour] = int(counts.get(humour, 0)) + 1
	var spool := VBoxContainer.new()
	spool.add_theme_constant_override("separation", 0)
	_deck_strip.add_child(spool)
	spool.add_child(UITheme.icon("ui/ui_spool", 56.0))
	var size_label := UITheme.measured_label(
		"%d" % profile.get("deck", []).size(), 26, 76.0, UITheme.display_font())
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spool.add_child(size_label)
	for humour in Catalog.HUMOURS:
		var chip := VBoxContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_constant_override("separation", 0)
		_deck_strip.add_child(chip)
		var glyph := UITheme.icon(String(HUMOUR_GLYPHS[humour]), 52.0)
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		chip.add_child(glyph)
		# Count only — "Moonlight 4" wrapped into the Re-spool button at this
		# width (tour 2026-08-08). The names live one tap away in the Spool.
		var label := UITheme.measured_label(
			"×%d" % int(counts.get(humour, 0)),
			24, 90.0, UITheme.display_font(), HUMOUR_COLORS[humour])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(label)


func _build_confirm(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_CONFIRM)
	column.add_child(holder)
	var confirm := UITheme.amber_button(Strings.line("loadout.confirm"), 32)
	confirm.pressed.connect(func() -> void: closed.emit())
	holder.add_child(confirm)


# ------------------------------------------------------------------- cards

func _refresh() -> void:
	_clear(_slot_grid)
	_clear(_bench_flow)
	var carried := SaveService.battle_loadout(profile)
	for i in SaveService.LOADOUT_SIZE:
		if i < carried.size():
			var skill_id := String(carried[i])
			var locked := skill_id == "scratch"
			var card := _card(skill_id, SLOT_WIDTH, SLOT_HEIGHT, SLOT_ART_HEIGHT,
				22, true, locked)
			UITheme.tap_layer(card.get_meta("frame")).pressed.connect(
				_open_skill.bind(skill_id))
			_slot_grid.add_child(card)
			if skill_id == _just_moved:
				UITheme.settle(card)
		else:
			_slot_grid.add_child(_empty_slot())
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
		var card := _card(skill_id, BENCH_WIDTH, BENCH_HEIGHT, BENCH_ART_HEIGHT,
			19, false, false)
		UITheme.tap_layer(card.get_meta("frame")).pressed.connect(
			_open_skill.bind(skill_id))
		_bench_flow.add_child(card)
		if skill_id == _just_moved:
			UITheme.settle(card)
	_just_moved = ""
	_refresh_deck()


## A skill card: art in an ink-bordered plate with the name across the bottom.
## `carried` cards get the gilt corner frame from the mockup; the bench keeps
## the plain plate so the two rows read as different states at a glance.
func _card(skill_id: String, width: float, height: float, art_height: float,
		font_size: int, carried: bool, locked: bool) -> Control:
	var def: Dictionary = catalog.skills.get(skill_id, {})
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(width, height)
	card.add_theme_constant_override("separation", 4)
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(width, art_height)
	frame.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4e7cd") if carried else Color("e4d5b4")
	style.set_border_width_all(3)
	style.border_color = UITheme.ACCENT_WARM if carried else Color("a99c82")
	style.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", style)
	card.add_child(frame)
	var art := TextureRect.new()
	art.texture = UITheme.tex("sk_" + skill_id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		art.set_offset(side, 5)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		art.set_offset(side, -5)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)
	if carried:
		# The mockup's gilt corners, drawn over the art rather than as a
		# stretched 9-patch: the generated frame is a fixed-aspect painting and
		# stretching it to a 186x138 hole warps the corner scrollwork (law 3).
		var gilt := TextureRect.new()
		gilt.texture = UITheme.cropped_tex("ui/ui_frame_skill")
		gilt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gilt.stretch_mode = TextureRect.STRETCH_SCALE
		gilt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gilt.modulate = Color(1, 1, 1, 0.9)
		gilt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(gilt)
	# Scratch cannot be put down. It says so in the caption: laid over the art
	# the word was invisible against a pale corner of the painting.
	var caption := String(def.get("name", skill_id))
	if locked:
		caption += Strings.line("loadout.always_tag")
	var name_label := UITheme.measured_label(caption,
		font_size, width, UITheme.body_font())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)
	card.set_meta("frame", frame)
	return card


## The visible gap where a skill could go: the player can count what they are
## not carrying without doing arithmetic.
func _empty_slot() -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
	card.add_theme_constant_override("separation", 4)
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_ART_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d8c9a8")
	style.set_border_width_all(3)
	style.border_color = Color("a99c82")
	style.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", style)
	card.add_child(frame)
	var mark := UITheme.measured_label("—", 44, SLOT_WIDTH,
		UITheme.display_font(), Color("a99c82"))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(mark)
	var label := UITheme.measured_label(Strings.line("loadout.empty_slot"),
		19, SLOT_WIDTH, UITheme.body_font(), UITheme.INK_FADED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(label)
	return card


# --------------------------------------------------------- skill close-up

## The close-up popup: art large, what it costs, how many uses it carries,
## what it DOES, and the decision — all before a card moves anywhere.
func _build_skill_modal() -> void:
	_skill_modal = UITheme.modal(self, 560.0)
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
	var wrap := 528.0
	var carried := SaveService.battle_loadout(profile).has(skill_id)
	var locked := skill_id == "scratch"
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(wrap, 240.0)
	frame.clip_contents = true
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
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		art.set_offset(side, 5)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		art.set_offset(side, -5)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)
	var title := "%s — %s" % [String(def.get("name", skill_id)),
		SkillText.cost_line(def)]
	_skill_box.add_child(UITheme.measured_label(title, 32, wrap,
		UITheme.display_font()))
	_skill_box.add_child(UITheme.measured_label(SkillText.charges_line(def),
		24, wrap, UITheme.body_font(), UITheme.INK_SOFT))
	var effects := SkillText.effect_summary(def)
	if effects != "":
		_skill_box.add_child(UITheme.measured_label(effects, 26, wrap,
			UITheme.body_font()))
	var flavor := String(def.get("flavor", ""))
	if flavor != "":
		_skill_box.add_child(UITheme.measured_label(flavor, 22, wrap,
			UITheme.italic_font(), UITheme.INK_SOFT))
	if locked:
		_skill_box.add_child(UITheme.measured_label(
			Strings.line("loadout.skill.always"), 22, wrap,
			UITheme.italic_font(), UITheme.ACCENT_WARM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_skill_box.add_child(row)
	if locked:
		var back := UITheme.dark_button(Strings.line("loadout.skill.keep"), 24,
			Vector2(0, UITheme.BUTTON_HEIGHT))
		back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		back.pressed.connect(_close_skill)
		row.add_child(back)
	elif carried:
		var down := UITheme.dark_button(Strings.line("loadout.skill.put_down"),
			24, Vector2(0, UITheme.BUTTON_HEIGHT))
		down.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		down.pressed.connect(func() -> void:
			_unequip(skill_id)
			_close_skill())
		row.add_child(down)
		var keep := UITheme.amber_button(Strings.line("loadout.skill.keep"), 26)
		keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keep.pressed.connect(_close_skill)
		row.add_child(keep)
	else:
		var leave := UITheme.dark_button(Strings.line("loadout.skill.leave"),
			24, Vector2(0, UITheme.BUTTON_HEIGHT))
		leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		leave.pressed.connect(_close_skill)
		row.add_child(leave)
		var take := UITheme.amber_button(Strings.line("loadout.skill.take"), 26)
		take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		take.pressed.connect(func() -> void:
			_equip(skill_id)
			_close_skill())
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


func _equip(skill_id: String) -> void:
	var picked := _picked()
	if picked.has(skill_id):
		return
	picked.append(skill_id)
	# Full loadout: the oldest pick steps aside rather than the tap doing
	# nothing. A tap that silently refuses reads as a broken button.
	while picked.size() > SaveService.LOADOUT_SIZE - 1:
		picked.pop_front()
	_just_moved = skill_id
	_apply(picked)


## Materialize the current (possibly auto-derived) loadout as an editable list.
func _picked() -> Array:
	var picked: Array = SaveService.battle_loadout(profile)
	picked.erase("scratch")
	return picked


func _apply(picked: Array) -> void:
	profile["loadout"] = picked
	_refresh()


# --------------------------------------------------------------- the spool

## The Spool: every energy card OWNED, with how many are wound on to go out.
## Winding on and off is free (owner 2026-08-08); the only rule is the floor
## — a spool thinner than exchange.deck_floor stops being a fuel gauge.
func _build_spool_modal() -> void:
	_spool_modal = UITheme.modal(self, 560.0)
	UITheme.modal_escape(_spool_modal, _close_spool)
	_spool_box = _spool_modal["box"]
	var wrap := 528.0
	_spool_box.add_child(UITheme.measured_label(
		Strings.line("loadout.spool.title"), 32, wrap, UITheme.display_font()))
	_spool_box.add_child(UITheme.measured_label(
		Strings.line("loadout.spool.blurb"), 21, wrap,
		UITheme.italic_font(), UITheme.INK_SOFT))
	_spool_count = UITheme.measured_label("", 23, wrap, UITheme.body_font())
	_spool_box.add_child(_spool_count)
	# Twelve card kinds at most, but a phone screen holds eight rows: the
	# rows scroll inside a fixed window instead of growing the panel off the
	# page (law 12 applies to modals too).
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(wrap, 560.0)
	_spool_box.add_child(scroll)
	_spool_rows = VBoxContainer.new()
	_spool_rows.add_theme_constant_override("separation", 8)
	_spool_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_spool_rows)
	var done := UITheme.amber_button(Strings.line("loadout.spool.done"), 26)
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


## One kind of card: glyph, NAME (the name it is called everywhere), and the
## wind-on / wind-off steppers with the in-deck count between them.
func _spool_row(card_id: String, in_deck: int, owned: int) -> Control:
	var def: Dictionary = catalog.energy_cards[card_id]
	var humour := String(def["humour"])
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UITheme.panel_stylebox(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	plate.add_child(row)
	var glyph := UITheme.icon(String(HUMOUR_GLYPHS[humour]), 40.0)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UITheme.measured_label(String(def["name"]), 23, 200.0,
		UITheme.display_font()))
	text.add_child(UITheme.measured_label(
		"%s %d" % [Catalog.humour_name(humour), int(def["value"])], 17, 200.0,
		UITheme.body_font(), HUMOUR_COLORS[humour]))
	var minus := UITheme.dark_button("-", 30, Vector2(72, 72))
	minus.disabled = in_deck < 1 \
		or profile.get("deck", []).size() <= _deck_floor()
	minus.pressed.connect(_wind_off.bind(card_id))
	row.add_child(minus)
	var count := UITheme.measured_label("%d/%d" % [in_deck, owned], 24, 76.0,
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


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
