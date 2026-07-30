extends Control
## Story presenter per reference/story screen.png: framed illustration on the
## parchment page, one line of narration below, tap to advance. Optional
## choice buttons for decisions.

signal finished(choice_index: int)

var lines: Array = []
var choices: Array = []
var heading: String = ""
var big_style := false
var image_id := ""        # illustration (portrait beats environment image)
var fallback_color := Color(0.2, 0.2, 0.24)

var _line_index := 0
var _line_label: Label
var _hint_label: Label
var _choice_box: VBoxContainer
var _tap_catcher: Button


func setup(config: Dictionary) -> void:
	lines = config.get("lines", [])
	choices = config.get("choices", [])
	heading = config.get("heading", "")
	big_style = config.get("big", false)
	image_id = config.get("portrait", config.get("image", ""))
	if config.has("color"):
		fallback_color = Color(String(config["color"])).darkened(0.2)


func _ready() -> void:
	var page := Panel.new()
	page.add_theme_stylebox_override("panel", UITheme.page_stylebox())
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	_tap_catcher = Button.new()
	_tap_catcher.flat = true
	_tap_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tap_catcher.pressed.connect(_advance)
	add_child(_tap_catcher)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	# The illustration, in a thin ink frame
	var art_holder := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = fallback_color
	frame_style.set_border_width_all(3)
	frame_style.border_color = UITheme.INK
	frame_style.set_corner_radius_all(4)
	art_holder.add_theme_stylebox_override("panel", frame_style)
	art_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_holder.size_flags_stretch_ratio = 3.0
	art_holder.clip_contents = true
	art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art_holder)
	var art := UITheme.tex(image_id)
	if art != null:
		var art_rect := TextureRect.new()
		art_rect.texture = art
		art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_holder.add_child(art_rect)

	var heading_label := Label.new()
	heading_label.text = heading
	heading_label.add_theme_font_override("font", UITheme.smallcaps_font())
	heading_label.add_theme_font_size_override("font_size", 20)
	heading_label.add_theme_color_override("font_color", UITheme.INK_SOFT)
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading_label.visible = heading != ""
	box.add_child(heading_label)

	_line_label = Label.new()
	_line_label.add_theme_font_override("font",
		UITheme.display_font() if big_style else UITheme.italic_font())
	_line_label.add_theme_font_size_override("font_size", 34 if big_style else 24)
	_line_label.add_theme_color_override("font_color", UITheme.INK)
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_line_label.size_flags_stretch_ratio = 1.4
	_line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_line_label)

	_hint_label = Label.new()
	_hint_label.text = "—❋—  tap to continue  —❋—"
	_hint_label.add_theme_font_override("font", UITheme.italic_font())
	_hint_label.add_theme_font_size_override("font_size", 15)
	_hint_label.add_theme_color_override("font_color", UITheme.INK_FADED)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_hint_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 10)
	_choice_box.visible = false
	box.add_child(_choice_box)
	for i in choices.size():
		var b := Button.new()
		b.text = String(choices[i])
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 58)
		b.pressed.connect(func() -> void: finished.emit(i))
		_choice_box.add_child(b)

	_show_line()


func _show_line() -> void:
	if _line_index < lines.size():
		_line_label.text = String(lines[_line_index])
	var at_end := _line_index >= lines.size() - 1
	if at_end and not choices.is_empty():
		_choice_box.visible = true
		_hint_label.visible = false
		_tap_catcher.disabled = true


func _advance() -> void:
	if _line_index < lines.size() - 1:
		_line_index += 1
		_show_line()
	elif choices.is_empty():
		finished.emit(-1)
