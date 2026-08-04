extends Control
## On the Prowl — what Ash carries out the door, built to
## assets/library/mockups/mock_loadout.png: framed skill cards for the slots,
## a bench of everything owned but left behind, and the deck read out in
## humour glyphs underneath.
##
## The screen edits profile["loadout"] only. Cards are bought and cut at the
## Magpie Exchange; the deck strip here is a readout, not a control.

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
		"What goes out with you — %d, and Scratch is always one" % SaveService.LOADOUT_SIZE,
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
	_bench_note = UITheme.measured_label("Left on the mantel", 24,
		UITheme.CONTENT_WIDTH, UITheme.smallcaps_font(), UITheme.INK_SOFT)
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


func _build_deck(column: VBoxContainer) -> void:
	var holder := HBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_DECK)
	holder.add_theme_constant_override("separation", 10)
	column.add_child(holder)
	var counts := {}
	for card_id in profile.get("deck", []):
		var humour: String = catalog.energy_cards[card_id]["humour"]
		counts[humour] = int(counts.get(humour, 0)) + 1
	var spool := VBoxContainer.new()
	spool.add_theme_constant_override("separation", 0)
	holder.add_child(spool)
	spool.add_child(UITheme.icon("ui/ui_spool", 56.0))
	var size_label := UITheme.measured_label(
		"%d" % profile.get("deck", []).size(), 26, 76.0, UITheme.display_font())
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spool.add_child(size_label)
	for humour in Catalog.HUMOURS:
		var chip := VBoxContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_constant_override("separation", 0)
		holder.add_child(chip)
		var glyph := UITheme.icon(String(HUMOUR_GLYPHS[humour]), 52.0)
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		chip.add_child(glyph)
		var label := UITheme.measured_label(
			"%s %d" % [Catalog.humour_name(humour), int(counts.get(humour, 0))],
			19, 112.0, UITheme.body_font(), HUMOUR_COLORS[humour])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(label)


func _build_confirm(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_CONFIRM)
	column.add_child(holder)
	var confirm := UITheme.amber_button("Confirm Loadout", 32)
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
			if not locked:
				UITheme.tap_layer(card.get_meta("frame")).pressed.connect(
					_on_slot_pressed.bind(skill_id))
			_slot_grid.add_child(card)
		else:
			_slot_grid.add_child(_empty_slot())
	var bench: Array[String] = []
	for skill_id in profile.get("skills", []):
		if skill_id != "scratch" and not carried.has(skill_id):
			bench.append(String(skill_id))
	_bench_note.text = "Left on the mantel" if not bench.is_empty() \
		else "Nothing left on the mantel — everything Ash knows is going with him."
	_bench_note.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH,
		UITheme.measure_text(_bench_note.text, UITheme.smallcaps_font(), 24,
			UITheme.CONTENT_WIDTH).y)
	for skill_id in bench:
		var card := _card(skill_id, BENCH_WIDTH, BENCH_HEIGHT, BENCH_ART_HEIGHT,
			19, false, false)
		UITheme.tap_layer(card.get_meta("frame")).pressed.connect(
			_on_bench_pressed.bind(skill_id))
		_bench_flow.add_child(card)


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
		caption += " (always)"
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
	var label := UITheme.measured_label("nothing chosen", 19, SLOT_WIDTH,
		UITheme.body_font(), UITheme.INK_FADED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(label)
	return card


# ------------------------------------------------------------------ edits

func _on_slot_pressed(skill_id: String) -> void:
	var picked := _picked()
	picked.erase(skill_id)
	_apply(picked)


func _on_bench_pressed(skill_id: String) -> void:
	var picked := _picked()
	if picked.has(skill_id):
		return
	picked.append(skill_id)
	# Full loadout: the oldest pick steps aside rather than the tap doing
	# nothing. A tap that silently refuses reads as a broken button.
	while picked.size() > SaveService.LOADOUT_SIZE - 1:
		picked.pop_front()
	_apply(picked)


## Materialize the current (possibly auto-derived) loadout as an editable list.
func _picked() -> Array:
	var picked: Array = SaveService.battle_loadout(profile)
	picked.erase("scratch")
	return picked


func _apply(picked: Array) -> void:
	profile["loadout"] = picked
	_refresh()


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
