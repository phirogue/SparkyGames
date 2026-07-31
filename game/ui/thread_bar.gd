class_name ThreadBar
extends Control
## Health as a fraying red thread (per the battle mockup): the remaining
## fraction is drawn as tiled thread texture ending in a frayed tip; the lost
## portion is a dashed "unstitched" line. Damage animates the unstitching.

var max_value := 20
var _shown := 1.0     # displayed fraction, tweened
var _target := 1.0

@onready var _segment: Texture2D = UITheme.tex("ui/ui_thread_segment")
@onready var _fray: Texture2D = UITheme.tex("ui/ui_thread_fray")


func _ready() -> void:
	custom_minimum_size = Vector2(0, 28)
	# draw_texture_rect(tile=true) silently stretches unless repeat is on.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func set_health(value: int, p_max: int) -> void:
	max_value = maxi(p_max, 1)
	var new_target := clampf(float(value) / float(max_value), 0.0, 1.0)
	if is_equal_approx(new_target, _target):
		queue_redraw()  # layout may have changed even if the value didn't
		return
	_target = new_target
	var tween := create_tween()
	tween.tween_method(_set_shown, _shown, _target, 0.35).set_trans(Tween.TRANS_CUBIC)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _set_shown(value: float) -> void:
	_shown = value
	queue_redraw()


func _draw() -> void:
	var height := size.y
	var thread_width := size.x * _shown
	if _segment != null and thread_width > 2.0:
		# Manual tiling scaled to bar height — robust across repeat flags.
		var tile_w: float = height * _segment.get_width() / float(_segment.get_height())
		var x := 0.0
		while x < thread_width:
			var w: float = minf(tile_w, thread_width - x)
			draw_texture_rect_region(_segment,
				Rect2(x, 0, w, height),
				Rect2(0, 0, _segment.get_width() * (w / tile_w), _segment.get_height()))
			x += tile_w
	elif thread_width > 2.0:
		draw_rect(Rect2(0, height * 0.3, thread_width, height * 0.4), Color("a03828"))
	if _fray != null and _shown < 0.999 and thread_width > 2.0:
		var fray_h := height * 1.4
		var fray_w := fray_h * _fray.get_width() / float(_fray.get_height())
		draw_texture_rect(_fray, Rect2(thread_width - 2, (height - fray_h) / 2.0, fray_w, fray_h), false)
	if _shown < 0.999:
		var y := height / 2.0
		draw_dashed_line(Vector2(thread_width + 8, y), Vector2(size.x, y),
			UITheme.INK_FADED, 2.0, 8.0)
