extends Control
## Settings — the storybook page version of the options menu, built to
## assets/library/mockups/mock_settings.png: torn parchment row plates, a felt
## toggle with a bone button on each, and loudness counted in paw prints
## instead of a slider (information becomes objects — ui-style-guide).
##
## It is an OVERLAY, not a screen: game.gd parks it on the settings
## CanvasLayer so it is reachable from anywhere (owner rule) WITHOUT swapping
## out what is underneath. Swapping mid-battle would destroy the combat state.
##
## The screen owns no behaviour: every change goes out as `setting_changed`
## and game.gd applies it (audio buses, the lamp dim) and saves. See
## docs/design/ui-screens.md.

signal closed
signal setting_changed(key: String, value: Variant)

## FIXED zone template (law 12): heights + separations == CONTENT_HEIGHT.
## 96 + 656 + 126 + 190 = 1068, plus 3 x 12 separation = 1104.
const SEPARATION := 12
const ZONE_HEADER := 96
const ZONE_ROWS := 656
const ZONE_LOUDNESS := 126
const ZONE_FOOTER := 190

## 5 x 120 + 4 x 14 = 656 exactly.
const ROW_HEIGHT := 120
const ROW_SEPARATION := 14

## Width budget for a row, measured rather than guessed (law 2). The plate is
## CONTENT_WIDTH wide; the dashed border inside the torn art eats ROW_INSET a
## side, leaving 502. icon 72 + name 190 + toggle 132 + word 58 + 3 x 10
## separation = 482, with 20px of slack. The first cut of these numbers came
## to exactly 502 and the ON/OFF word was squeezed to one letter wide.
const ROW_INSET := 40.0
const ICON_BOX := 72.0
const TOGGLE_SIZE := Vector2(132, 58)
const VALUE_WIDTH := 58.0
const NAME_WRAP := 190.0
const ROW_ITEM_SEPARATION := 10

const VOLUME_STEPS := 5
const PAW_SIZE := 74.0

## The toggle rows, in the order the mockup has them. `icon` is an asset id;
## every one of these already existed in the library.
const TOGGLE_ROWS := [
	{"key": "sfx", "name": "Sound Effects", "icon": "ui/ui_icon_sound"},
	{"key": "music", "name": "Music", "icon": "ui/ui_icon_music"},
	{"key": "lamps_low", "name": "Lamps Low", "icon": "ui/ui_icon_brightness"},
	{"key": "ask_to_spend", "name": "Ask to Spend", "icon": "ui/ui_seal_gold"},
]

var settings: Dictionary = {}

var _toggle_art: Dictionary = {}   # key -> TextureRect
var _toggle_word: Dictionary = {}  # key -> Label
var _paws: Array[TextureRect] = []


func setup(p_settings: Dictionary) -> void:
	settings = p_settings


func _ready() -> void:
	# On a CanvasLayer the game root's theme does not propagate down, so the
	# page has to carry it or every label falls back to the engine font.
	if theme == null:
		theme = UITheme.build()
	var margin := UITheme.page_scaffold(self)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)
	_build_header(column)
	_build_rows(column)
	_build_loudness(column)
	_build_footer(column)


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
	var title := UITheme.measured_label("Settings", 46,
		UITheme.CONTENT_WIDTH - 112, UITheme.display_font())
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_FILL
	header.add_child(title)


func _build_rows(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_ROWS)
	holder.add_theme_constant_override("separation", ROW_SEPARATION)
	column.add_child(holder)
	for row: Dictionary in TOGGLE_ROWS:
		holder.add_child(_toggle_row(String(row["key"]), String(row["name"]),
			String(row["icon"])))
	# The fifth row is a VALUE, not a switch. There is exactly one language;
	# a switch that cannot switch is a lie, so it shows what it is instead.
	holder.add_child(_value_row("Language", "ui/ui_icon_language", "English"))


func _build_loudness(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_LOUDNESS)
	holder.add_theme_constant_override("separation", 6)
	column.add_child(holder)
	holder.add_child(UITheme.measured_label("Loudness", 28,
		UITheme.CONTENT_WIDTH, UITheme.smallcaps_font(), UITheme.INK_SOFT))
	var paws := HBoxContainer.new()
	paws.add_theme_constant_override("separation", 18)
	paws.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_child(paws)
	# Loudness in paw prints: five steps is enough choice for a phone, and it
	# is a far bigger tap target than a slider grabber.
	for step in VOLUME_STEPS:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(PAW_SIZE, PAW_SIZE)
		slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		paws.add_child(slot)
		var paw := UITheme.icon("ui/ui_paw_full", PAW_SIZE)
		paw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(paw)
		_paws.append(paw)
		UITheme.tap_layer(slot).pressed.connect(_on_volume_step.bind(step + 1))
	_refresh_paws()


func _build_footer(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_FOOTER)
	holder.add_theme_constant_override("separation", 8)
	column.add_child(holder)
	# The credits screen does not exist yet and this is where a player looks:
	# the disclosure lives here until it does (docs/design/ai-transparency.md).
	holder.add_child(UITheme.measured_label(
		"Art, music and code on this game were made with AI assistance. Every line, picture and decision was chosen by a person.",
		20, UITheme.CONTENT_WIDTH, UITheme.italic_font(), UITheme.INK_SOFT))
	var version := UITheme.measured_label(
		"The Nine Lives of Ashcat — Chapter One", 20, UITheme.CONTENT_WIDTH,
		UITheme.body_font(), UITheme.INK_FADED)
	holder.add_child(version)
	var back := UITheme.amber_button("Back to the night", 30)
	back.size_flags_vertical = Control.SIZE_SHRINK_END
	back.pressed.connect(func() -> void: closed.emit())
	holder.add_child(back)


# -------------------------------------------------------------------- rows

## One settings row: torn plate, cropped icon, name, felt toggle. The whole
## plate is the tap target, not just the switch.
func _toggle_row(key: String, name_text: String, icon_id: String) -> Control:
	var plate := _plate(name_text, icon_id)
	var body: HBoxContainer = plate.get_meta("body")
	# The word goes BEFORE the switch: at the far right it landed on the
	# plate's corner sprig and read as ink over leaves. The switch is opaque
	# felt, so it is the one that can afford to sit on the decoration.
	var word := UITheme.measured_label("", 26, VALUE_WIDTH,
		UITheme.smallcaps_font())
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.size_flags_vertical = Control.SIZE_FILL
	body.add_child(word)
	_toggle_word[key] = word
	var art := TextureRect.new()
	art.custom_minimum_size = TOGGLE_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(art)
	_toggle_art[key] = art
	_refresh_toggle(key)
	UITheme.tap_layer(plate).pressed.connect(_on_toggle.bind(key))
	return plate


## A row that reports a value it cannot change (see _build_rows).
func _value_row(name_text: String, icon_id: String, value: String) -> Control:
	var plate := _plate(name_text, icon_id)
	var body: HBoxContainer = plate.get_meta("body")
	var label := UITheme.measured_label(value, 28, TOGGLE_SIZE.x,
		UITheme.body_font(), UITheme.INK_SOFT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	body.add_child(label)
	# Holds the value clear of the plate's corner sprig, where the toggle rows
	# put their switch. Rows have to line up down the page.
	var gutter := Control.new()
	gutter.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(gutter)
	return plate


## Shared plate: the torn row art with an icon and a name already in it. The
## caller adds whatever sits on the right into `body`.
func _plate(name_text: String, icon_id: String) -> Panel:
	var plate := Panel.new()
	plate.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	plate.add_theme_stylebox_override("panel", UITheme.row_stylebox())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", ROW_ITEM_SEPARATION)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = ROW_INSET
	body.offset_right = -ROW_INSET
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(body)
	body.add_child(UITheme.icon(icon_id, ICON_BOX))
	var label := UITheme.measured_label(name_text, 30, NAME_WRAP,
		UITheme.display_font())
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(label)
	plate.set_meta("body", body)
	return plate


# ----------------------------------------------------------------- changes

func _on_toggle(key: String) -> void:
	var now := not _is_on(key)
	settings[key] = now
	_refresh_toggle(key)
	setting_changed.emit(key, now)


func _on_volume_step(step: int) -> void:
	var value := float(step) / float(VOLUME_STEPS)
	# Tapping the paw you are already on turns it off — otherwise silence is
	# unreachable, since the first paw is 1/5 and not 0.
	if is_equal_approx(float(settings.get("volume", 1.0)), value):
		value = 0.0
	settings["volume"] = value
	_refresh_paws()
	setting_changed.emit("volume", value)


func _is_on(key: String) -> bool:
	return bool(settings.get(key, true))


func _refresh_toggle(key: String) -> void:
	var on := _is_on(key)
	var art: TextureRect = _toggle_art[key]
	art.texture = UITheme.cropped_tex(
		"ui/ui_toggle_on" if on else "ui/ui_toggle_off")
	var word: Label = _toggle_word[key]
	word.text = "ON" if on else "OFF"
	word.add_theme_color_override("font_color",
		Color("4a6a34") if on else Color("8a5a3a"))


func _refresh_paws() -> void:
	var lit := int(round(float(settings.get("volume", 1.0)) * VOLUME_STEPS))
	for i in _paws.size():
		_paws[i].texture = UITheme.cropped_tex(
			"ui/ui_paw_full" if i < lit else "ui/ui_paw_empty")
