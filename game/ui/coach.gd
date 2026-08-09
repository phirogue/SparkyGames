class_name Coach
extends Control
## Spotlight tutorial overlay (the standard mobile "coach mark" pattern):
## dims the screen except a cutout around one target control, shows one short
## instruction, and moves on. The host screen provides target rects via a
## resolver callable and calls notify(key) when actions happen.
##
## steps: [
##   { "target": "hp",            "text": "The heart. Guard it." },
##   { "target": "skill:pounce",  "text": "Tap POUNCE.", "wait": true },
## ]
##
## Two kinds of step, and the difference is the whole design (owner defect
## list 2026-08-03):
##
## - A NOTE (no "wait") is read, not done. Tapping ANYWHERE advances it,
##   including on the highlighted thing itself — the cutout is covered by an
##   invisible catcher, so the spotlit control cannot fire underneath. Before
##   this, taps landed in a dead zone exactly where the eye had been sent.
## - An ACTION ("wait": true) advances only when the player performs it. The
##   cutout is a genuine hole so the target really is tappable, and taps on
##   the dim are ignored — otherwise "Tap POUNCE" could be tapped past, and
##   the lesson carried on explaining Scratch over an open Pounce card.
##
## Nobody gets stuck (engineering law 13): an action step whose target is
## missing, hidden or disabled falls back to advancing on any tap, and Skip
## is always there.

var steps: Array = []
var index := -1
var resolver: Callable          # (target_key: String) -> Control or null
## Optional (step: Dictionary) -> String. Lets the host pick the wording from
## the CURRENT state instead of a line written once for all states — the wisp
## lesson said "two Shadow went on the entrance" to a player who had walked
## in and spent nothing (owner 2026-08-05). Unset means "use step.text".
var text_resolver: Callable = Callable()

var _dims: Array[ColorRect] = []
var _hole_catcher: ColorRect
var _text_panel: Panel
var _text_label: Label
var _skip: Button

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
		dim.gui_input.connect(_on_dim_input)
		add_child(dim)
		_dims.append(dim)
	# Invisible catcher over the cutout. Present for notes (so the spotlight
	# is tappable but inert), removed for action steps (so the target is
	# genuinely reachable through the hole).
	_hole_catcher = ColorRect.new()
	_hole_catcher.color = Color(1, 1, 1, 0)
	_hole_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_hole_catcher.gui_input.connect(_on_dim_input)
	add_child(_hole_catcher)
	# Bubble drawn with EXPLICIT geometry (no container sizing): a Panel and
	# a Label whose rects are both set from measured text every step.
	_text_panel = Panel.new()
	var bubble := StyleBoxFlat.new()
	bubble.bg_color = Color("f6ead0")
	bubble.set_border_width_all(3)
	bubble.border_color = Color("4a3b2c")
	bubble.set_corner_radius_all(12)
	_text_panel.add_theme_stylebox_override("panel", bubble)
	_text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text_panel)
	_text_label = Label.new()
	_text_label.add_theme_font_override("font", UITheme.italic_font())
	_text_label.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	_text_label.add_theme_color_override("font_color", UITheme.INK)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_panel.add_child(_text_label)
	# Skip is a REAL button (owner fix: the flat text was barely visible).
	_skip = Button.new()
	_skip.text = "Skip lesson"
	_skip.custom_minimum_size = Vector2(190, 56)
	_skip.add_theme_font_override("font", UITheme.display_font())
	_skip.add_theme_font_size_override("font_size", 24)
	_skip.add_theme_stylebox_override("normal", UITheme.amber_stylebox())
	_skip.add_theme_stylebox_override("hover", UITheme.amber_stylebox())
	_skip.add_theme_stylebox_override("pressed", UITheme.amber_stylebox(Color(0.85, 0.8, 0.75)))
	_skip.add_theme_color_override("font_color", UITheme.INK)
	_skip.pressed.connect(_finish)
	add_child(_skip)
	force_advance()


func _on_dim_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if tapped and _tap_advances():
		force_advance()


## Does a tap on the overlay move the lesson on? Always for a note; for an
## action only when the action cannot actually be taken — the escape hatch
## that keeps an impossible step from becoming a wall.
func _tap_advances() -> bool:
	if not waits_for_action():
		return true
	var target: Control = _current_control()
	if target == null:
		return true
	return target is BaseButton and target.disabled


func waits_for_action() -> bool:
	return active() and index >= 0 and bool(steps[index].get("wait", false))


func _current_control() -> Control:
	var key := current_target()
	if key == "":
		return null
	var target: Variant = resolver.call(key)
	if target is Control and is_instance_valid(target) and target.is_visible_in_tree():
		return target
	return null


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


const TEXT_FONT_SIZE := 30
const TEXT_MAX_WIDTH := 560.0
const TEXT_PADDING := Vector2(48, 36)

var _bubble_size := Vector2.ZERO

func force_advance() -> void:
	index += 1
	if not active():
		_finish()
		return
	_hole_catcher.visible = not waits_for_action()
	var text := String(steps[index].get("text", ""))
	if text_resolver.is_valid():
		var chosen: Variant = text_resolver.call(steps[index])
		if chosen is String and not String(chosen).is_empty():
			text = String(chosen)
	_text_label.text = text
	# Size the LABEL from measured text; the panel then derives its own size
	# from label + stylebox margins (no double-counted padding).
	# CRITICAL: the label's wrap width must EQUAL the measured width, or the
	# label re-wraps and gains lines the measurement never saw. Both rects
	# are set explicitly — containers get no vote.
	var measured := UITheme.measure_text(text, UITheme.italic_font(),
		TEXT_FONT_SIZE, TEXT_MAX_WIDTH)
	_bubble_size = Vector2(TEXT_MAX_WIDTH, measured.y + 8) + TEXT_PADDING
	_text_label.position = TEXT_PADDING / 2.0
	_text_label.size = Vector2(TEXT_MAX_WIDTH, measured.y + 8)
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
	var target := _current_control()
	if target != null:
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
	_hole_catcher.position = hole.position
	_hole_catcher.size = hole.size
	# Instruction sits above the hole when there's room, else below.
	# Explicit geometry pinned every frame — no layout drift possible.
	var panel_size := _bubble_size
	_text_panel.size = panel_size
	var x: float = clampf(hole.get_center().x - panel_size.x / 2.0, 16, full.size.x - panel_size.x - 16)
	var y: float = hole.position.y - panel_size.y - 18
	if y < 16 or current_target() == "":
		y = minf(hole.end.y + 18, full.size.y - panel_size.y - 16)
	_text_panel.position = Vector2(x, y)
	# Skip lives top-right, but must never sit ON the spotlit target, on the
	# header's rule card, or ON THE INSTRUCTION ITSELF. It is drawn last, so
	# anything it overlaps it hides — and it hid the bubble it exists to let
	# you escape (owner 2026-08-04). Try top-right, then bottom-right, then
	# whichever of the two is merely least bad.
	var bubble := Rect2(_text_panel.position, panel_size).grow(8)
	var top := Vector2(full.size.x - _skip.size.x - 24, 12)
	var bottom := Vector2(top.x, full.size.y - _skip.size.y - 12)
	_skip.position = top if _skip_is_clear(top, hole, bubble) \
		else (bottom if _skip_is_clear(bottom, hole, bubble) else _skip_least_bad(
			top, bottom, hole, bubble))


func _skip_rect(at: Vector2) -> Rect2:
	return Rect2(at, _skip.size).grow(8)


func _skip_is_clear(at: Vector2, hole: Rect2, bubble: Rect2) -> bool:
	var rect := _skip_rect(at)
	# The top band also carries the header's rule card, which a hole reaching
	# up there means the lesson is currently talking about.
	if at.y < 100.0 and hole.position.y < rect.end.y:
		return false
	return not rect.intersects(hole) and not rect.intersects(bubble)


## Both corners are occupied: keep the bubble readable and let the button
## take the overlap with the spotlight instead. The instruction is the thing
## the player has to be able to read.
func _skip_least_bad(top: Vector2, bottom: Vector2, _hole: Rect2,
		bubble: Rect2) -> Vector2:
	return top if not _skip_rect(top).intersects(bubble) else bottom
