extends Control
## Story presenter: framed illustration on the parchment page, narration
## revealed one sentence per line with breathing room (owner rule: narration
## feel, not paragraphs). Optional choice buttons (max 3) after the last line.

signal finished(choice_index: int)

var lines: Array = []
var choices: Array = []
var heading: String = ""
var big_style := false
var image_id := ""
var art_desc := ""
var fallback_color := Color(0.2, 0.2, 0.24)

var _revealed := 0
var _first_visible := 0
var _line_labels: Array[Label] = []
var _lines_box: VBoxContainer
var _hint_label: Label
var _choice_box: VBoxContainer
var _tap_catcher: Button


func setup(config: Dictionary) -> void:
	lines = config.get("lines", [])
	choices = config.get("choices", [])
	assert(choices.size() <= 3, "max 3 choices on a story card (readability rule)")
	heading = config.get("heading", "")
	big_style = config.get("big", false)
	image_id = config.get("portrait", config.get("image", ""))
	art_desc = config.get("art_desc", "")
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

	# Everything lives INSIDE the stitched border of the page.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The page art's stitching insets are EMPIRICAL (law #5): 64/54/92.
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 54)
	margin.add_theme_constant_override("margin_bottom", 92)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	# Illustration in a thin ink frame at its TRUE 3:4 aspect, at a FIXED
	# size (owner rule 2026-08-01): the picture is the constant; text gets
	# whatever remains. Never let prose shrink the art.
	var art_center := CenterContainer.new()
	art_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art_center)
	var art_holder := PanelContainer.new()
	art_holder.custom_minimum_size = Vector2(510, 680)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = fallback_color
	frame_style.set_border_width_all(4)
	frame_style.border_color = UITheme.INK
	frame_style.set_corner_radius_all(4)
	art_holder.add_theme_stylebox_override("panel", frame_style)
	art_holder.clip_contents = true
	art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_center.add_child(art_holder)
	if image_id != "":
		art_holder.add_child(UITheme.art_or_placeholder(image_id,
			art_desc if art_desc != "" else "illustration pending"))

	if heading != "":
		var heading_label := Label.new()
		heading_label.text = heading
		heading_label.add_theme_font_override("font", UITheme.smallcaps_font())
		heading_label.add_theme_font_size_override("font_size", 32)
		heading_label.add_theme_color_override("font_color", UITheme.INK_SOFT)
		heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(heading_label)

	# Narration: one sentence per line, revealed gradually, air between lines.
	_lines_box = VBoxContainer.new()
	_lines_box.add_theme_constant_override("separation", 18)
	_lines_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lines_box.size_flags_stretch_ratio = 1.8
	_lines_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_lines_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_lines_box)
	for line in lines:
		var label := Label.new()
		label.text = String(line)
		label.add_theme_font_override("font",
			UITheme.display_font() if big_style else UITheme.italic_font())
		label.add_theme_font_size_override("font_size", 54 if big_style else 37)
		label.add_theme_color_override("font_color", UITheme.INK)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(1, 1, 1, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lines_box.add_child(label)
		_line_labels.append(label)

	_hint_label = Label.new()
	_hint_label.text = "—❋—  tap  —❋—"
	_hint_label.add_theme_font_override("font", UITheme.italic_font())
	_hint_label.add_theme_font_size_override("font_size", 24)
	_hint_label.add_theme_color_override("font_color", UITheme.INK_FADED)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_hint_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 12)
	_choice_box.visible = false
	box.add_child(_choice_box)
	for i in choices.size():
		var b := Button.new()
		b.text = String(choices[i])
		b.add_theme_font_size_override("font_size", 28)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 96)
		b.pressed.connect(func() -> void: finished.emit(i))
		_choice_box.add_child(b)

	_advance()  # reveal the first line immediately


func _advance() -> void:
	if _revealed < _line_labels.size():
		var label := _line_labels[_revealed]
		_revealed += 1
		var tween := create_tween()
		tween.tween_property(label, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
		_retire_overflow()
		if _revealed == _line_labels.size():
			_on_all_revealed()
	elif choices.is_empty():
		finished.emit(-1)


## Retire the oldest visible narration lines until what remains MEASURES
## inside the text zone (fixed art means text gets a fixed budget; a
## count cap can't see how far each line wraps — pixels can).
func _retire_overflow() -> void:
	var budget := 1280.0 - 54.0 - 92.0 - 680.0 - 40.0 - 60.0
	if heading != "":
		budget -= 50.0
	if not choices.is_empty():
		budget -= choices.size() * 108.0
	var line_font: Font = UITheme.display_font() if big_style else UITheme.italic_font()
	var line_size := 54 if big_style else 37
	while _first_visible < _revealed - 1:
		var total := 0.0
		for i in range(_first_visible, _revealed):
			total += UITheme.measure_text(
				_line_labels[i].text, line_font, line_size, 616.0).y + 18.0
		if total <= budget:
			break
		_line_labels[_first_visible].visible = false
		_first_visible += 1


func _on_all_revealed() -> void:
	if not choices.is_empty():
		_choice_box.visible = true
		_hint_label.visible = false
		_tap_catcher.disabled = true
