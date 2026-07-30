extends Control
## Minimal story presenter: one line at a time on a colored backdrop, tap
## anywhere to advance. Optionally ends with choice buttons instead of a
## final tap. Low-text rules live in docs/design/story-direction.md.

signal finished(choice_index: int)

var lines: Array = []
var choices: Array = []       # button labels shown after the last line ([] = tap to finish)
var backdrop_color: Color = Color(0.15, 0.15, 0.18)
var accent_color: Color = Color(0.9, 0.85, 0.75)
var heading: String = ""
var big_style := false        # title-card mode

var _line_index := 0
var _line_label: Label
var _heading_label: Label
var _hint_label: Label
var _choice_row: HBoxContainer
var _tap_catcher: Button


var image_id := ""
var image_tint := Color.WHITE
var portrait_id := ""


func setup(config: Dictionary) -> void:
	lines = config.get("lines", [])
	choices = config.get("choices", [])
	heading = config.get("heading", "")
	big_style = config.get("big", false)
	image_id = config.get("image", "")
	portrait_id = config.get("portrait", "")
	if config.has("image_tint"):
		image_tint = Color(String(config["image_tint"]))
	if config.has("color"):
		backdrop_color = Color(String(config["color"])).darkened(0.35)
	if config.has("accent"):
		accent_color = Color(String(config["accent"]))


static func _art(id: String) -> Texture2D:
	var path := "res://assets/%s.png" % id
	if id != "" and ResourceLoader.exists(path):
		return load(path)
	return null


func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = backdrop_color
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var art := _art(image_id)
	if art != null:
		var art_rect := TextureRect.new()
		art_rect.texture = art
		art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_rect.modulate = image_tint.darkened(0.35)  # keep text readable
		add_child(art_rect)

	_tap_catcher = Button.new()
	_tap_catcher.flat = true
	_tap_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tap_catcher.pressed.connect(_advance)
	add_child(_tap_catcher)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 60)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 30)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	_heading_label = Label.new()
	_heading_label.add_theme_font_size_override("font_size", 18)
	_heading_label.modulate = accent_color
	_heading_label.text = heading
	_heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_heading_label)

	var portrait := _art(portrait_id)
	if portrait != null:
		var portrait_rect := TextureRect.new()
		portrait_rect.texture = portrait
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.custom_minimum_size = Vector2(0, 340)
		portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(portrait_rect)

	_line_label = Label.new()
	_line_label.add_theme_font_size_override("font_size", 40 if big_style else 24)
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line_label.custom_minimum_size = Vector2(0, 200)
	_line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_line_label)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.modulate = Color(1, 1, 1, 0.45)
	_hint_label.text = "tap"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_hint_label)

	_choice_row = HBoxContainer.new()
	_choice_row.add_theme_constant_override("separation", 16)
	_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_row.visible = false
	box.add_child(_choice_row)
	for i in choices.size():
		var b := Button.new()
		b.text = String(choices[i])
		b.custom_minimum_size = Vector2(190, 64)
		b.pressed.connect(func() -> void: finished.emit(i))
		_choice_row.add_child(b)

	_show_line()


func _show_line() -> void:
	if _line_index < lines.size():
		_line_label.text = String(lines[_line_index])
	var at_end := _line_index >= lines.size() - 1
	if at_end and not choices.is_empty():
		_choice_row.visible = true
		_hint_label.visible = false
		_tap_catcher.disabled = true


func _advance() -> void:
	if _line_index < lines.size() - 1:
		_line_index += 1
		_show_line()
	elif choices.is_empty():
		finished.emit(-1)
