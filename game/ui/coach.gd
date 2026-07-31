class_name Coach
extends Control
## Spotlight tutorial overlay (the standard mobile "coach mark" pattern):
## dims the screen except a cutout around one target control, shows one short
## instruction, and advances when the player performs that action. Steps with
## no target are tap-to-continue notes.
##
## steps: [{ "target": "skill:pounce", "text": "Tap Pounce." }, ...]
## The host screen provides target rects via a resolver callable and calls
## notify(key) when actions happen.

var steps: Array = []
var index := -1
var resolver: Callable          # (target_key: String) -> Control or null

var _dims: Array[ColorRect] = []
var _text_panel: PanelContainer
var _text_label: Label
var _skip: Button
var _tap_zone: Button

const DIM := Color(0.06, 0.05, 0.04, 0.72)


func _init(p_steps: Array, p_resolver: Callable) -> void:
	steps = p_steps
	resolver = p_resolver


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 4:
		var dim := ColorRect.new()
		dim.color = DIM
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(dim)
		_dims.append(dim)
	_tap_zone = Button.new()
	_tap_zone.flat = true
	_tap_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tap_zone.pressed.connect(force_advance)
	_tap_zone.visible = false
	add_child(_tap_zone)
	_text_panel = PanelContainer.new()
	_text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text_panel)
	_text_label = Label.new()
	_text_label.add_theme_font_override("font", UITheme.italic_font())
	_text_label.add_theme_font_size_override("font_size", 30)
	_text_label.add_theme_color_override("font_color", UITheme.INK)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(560, 0)
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_panel.add_child(_text_label)
	_skip = Button.new()
	_skip.text = "skip lesson"
	_skip.flat = true
	_skip.add_theme_font_size_override("font_size", 22)
	_skip.pressed.connect(_finish)
	add_child(_skip)
	force_advance()


func active() -> bool:
	return index < steps.size()


func current_target() -> String:
	if not active() or index < 0:
		return ""
	return String(steps[index].get("target", ""))


## The host reports a performed action; matching the current step advances.
func notify(action_key: String) -> void:
	if active() and index >= 0 and current_target() == action_key:
		force_advance()


func force_advance() -> void:
	index += 1
	if not active():
		_finish()
		return
	_tap_zone.visible = current_target() == ""
	_text_label.text = String(steps[index].get("text", ""))
	queue_redraw()


func _finish() -> void:
	index = steps.size()
	visible = false
	set_process(false)


func _process(_delta: float) -> void:
	if not active():
		return
	var full := get_rect()
	var hole := Rect2(full.size / 2.0, Vector2.ZERO)
	var target_key := current_target()
	if target_key != "":
		var target: Control = resolver.call(target_key)
		if target != null and is_instance_valid(target) and target.is_visible_in_tree():
			hole = target.get_global_rect().grow(8)
	# Four dim rects leave the hole tappable.
	_dims[0].position = Vector2.ZERO
	_dims[0].size = Vector2(full.size.x, hole.position.y)
	_dims[1].position = Vector2(0, hole.end.y)
	_dims[1].size = Vector2(full.size.x, maxf(full.size.y - hole.end.y, 0))
	_dims[2].position = Vector2(0, hole.position.y)
	_dims[2].size = Vector2(maxf(hole.position.x, 0), hole.size.y)
	_dims[3].position = Vector2(hole.end.x, hole.position.y)
	_dims[3].size = Vector2(maxf(full.size.x - hole.end.x, 0), hole.size.y)
	# Instruction sits above the hole when there's room, else below.
	var panel_size := _text_panel.get_combined_minimum_size()
	var x: float = clampf(hole.get_center().x - panel_size.x / 2.0, 16, full.size.x - panel_size.x - 16)
	var y: float = hole.position.y - panel_size.y - 18
	if y < 16 or current_target() == "":
		y = minf(hole.end.y + 18, full.size.y - panel_size.y - 16)
	_text_panel.position = Vector2(x, y)
	_skip.position = Vector2(full.size.x - _skip.size.x - 30, 34)
