extends Control
## Studio splash: SparkyGames logo (black-box placeholder until generated),
## auto-advances after a beat, tap to skip.

signal finished

const HOLD_SECONDS := 2.0


func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("14110e")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var tap := Button.new()
	tap.flat = true
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap.pressed.connect(func() -> void: finished.emit())
	add_child(tap)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	var logo_holder := Control.new()
	logo_holder.custom_minimum_size = Vector2(320, 320)
	logo_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(logo_holder)
	var logo := UITheme.art_or_placeholder("ui/logo_sparkygames", "SparkyGames logo")
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo_holder.add_child(logo)

	var name_label := Label.new()
	name_label.text = "SparkyGames"
	name_label.add_theme_font_override("font", UITheme.display_font())
	name_label.add_theme_font_size_override("font_size", 56)
	name_label.add_theme_color_override("font_color", Color("e8c48a"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	var presents := Label.new()
	presents.text = "presents"
	presents.add_theme_font_override("font", UITheme.italic_font())
	presents.add_theme_font_size_override("font_size", 28)
	presents.add_theme_color_override("font_color", Color("8f8577"))
	presents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	presents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(presents)

	# Gentle ember-glow breathing on the logo (programmatic life rule).
	var tween := create_tween().set_loops()
	tween.tween_property(logo_holder, "modulate", Color(1.12, 1.08, 1.0), 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(logo_holder, "modulate", Color(0.92, 0.9, 0.86), 1.1).set_trans(Tween.TRANS_SINE)

	get_tree().create_timer(HOLD_SECONDS).timeout.connect(func() -> void:
		if is_inside_tree():
			finished.emit())
