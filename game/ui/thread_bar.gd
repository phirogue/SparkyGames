class_name ThreadBar
extends Control
## Health as a fraying red thread. Drawn procedurally (twisted rope with
## fray at the tip, dashed "unstitched" remainder) — always visible, no
## texture-import surprises. Damage animates the unstitching.

const ROPE := Color("8a2f22")
const ROPE_DARK := Color("5e1f16")
const DASH := Color("2b232080")

var max_value := 20
var _shown := 1.0
var _target := 1.0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 26)


func set_health(value: int, p_max: int) -> void:
	max_value = maxi(p_max, 1)
	var new_target := clampf(float(value) / float(max_value), 0.0, 1.0)
	if is_equal_approx(new_target, _target):
		queue_redraw()
		return
	_target = new_target
	var tween := create_tween()
	tween.tween_method(_set_shown, _shown, _target, 0.35).set_trans(Tween.TRANS_CUBIC)


func _set_shown(value: float) -> void:
	_shown = value
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var h := size.y
	var mid := h / 2.0
	var rope_w := size.x * _shown
	var thickness := clampf(h * 0.42, 6.0, 12.0)
	if rope_w > 4.0:
		# The rope: a rounded bar with diagonal twist ticks.
		draw_line(Vector2(2, mid), Vector2(rope_w - 2, mid), ROPE, thickness)
		var x := 6.0
		while x < rope_w - 8.0:
			draw_line(Vector2(x, mid - thickness * 0.45),
				Vector2(x + 6, mid + thickness * 0.45), ROPE_DARK, 2.0)
			x += 13.0
	if _shown < 0.999:
		# Frayed tip: three splaying fibres.
		var tip := maxf(rope_w - 2, 2)
		draw_line(Vector2(tip, mid), Vector2(tip + 14, mid - 7), ROPE, 2.0)
		draw_line(Vector2(tip, mid), Vector2(tip + 17, mid + 1), ROPE, 2.0)
		draw_line(Vector2(tip, mid), Vector2(tip + 12, mid + 8), ROPE, 2.0)
		# The unstitched remainder.
		draw_dashed_line(Vector2(tip + 22, mid), Vector2(size.x - 2, mid), DASH, 2.0, 8.0)
		# End tick, like the mock's needle-stop.
		draw_line(Vector2(size.x - 3, mid - 6), Vector2(size.x - 3, mid + 6), DASH, 2.0)
