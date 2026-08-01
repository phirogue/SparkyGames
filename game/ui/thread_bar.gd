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

## Generated art often floats in transparent padding; region-drawing uses
## the rope's real pixels (UITheme.content_region), not the empty canvas.
static func _content_region(tex: Texture2D, key: String) -> Rect2:
	return UITheme.content_region(tex, "thread_" + key)


func _ready() -> void:
	custom_minimum_size = Vector2(0, 26)
	# Nothing this bar draws may ever leave its rect (a wide fray texture
	# once shot the rope clean off the screen edge).
	clip_contents = true


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
	var segment := UITheme.tex("ui/ui_thread_segment")
	var fray := UITheme.tex("ui/ui_thread_fray")
	if segment != null and rope_w > 4.0:
		# The REAL rope art (owner requirement), content-cropped and tiled.
		var src := _content_region(segment, "segment")
		var tile_w: float = h * src.size.x / src.size.y
		var x := 0.0
		while x < rope_w:
			var w := minf(tile_w, rope_w - x)
			draw_texture_rect_region(segment, Rect2(x, 0, w, h),
				Rect2(src.position.x, src.position.y,
					src.size.x * (w / tile_w), src.size.y))
			x += tile_w
		var dash_start: float = rope_w + 8.0
		if fray != null and _shown < 0.999:
			var fray_src := _content_region(fray, "fray")
			var fray_h := h * 1.5
			# The fray art's aspect is whatever the generator felt like; cap
			# its width so the tip stays a tip and never leaves the bar.
			var fray_w: float = minf(fray_h * fray_src.size.x / fray_src.size.y, h * 2.5)
			# Tuck the fray a third of its width UNDER the rope's cut end so
			# the two textures read as one thread, not a butt joint.
			var fray_x := rope_w - fray_w * 0.35
			fray_w = minf(fray_w, size.x - fray_x)
			if fray_w > 2.0:
				draw_texture_rect_region(fray,
					Rect2(fray_x, mid - fray_h / 2.0, fray_w, fray_h), fray_src)
				dash_start = fray_x + fray_w + 6.0
		if _shown < 0.999:
			draw_dashed_line(Vector2(dash_start, mid), Vector2(size.x - 6, mid), DASH, 2.0, 8.0)
			draw_line(Vector2(size.x - 3, mid - 6), Vector2(size.x - 3, mid + 6), DASH, 2.0)
		return
	# Fallback: procedural rope if textures are missing.
	var thickness := clampf(h * 0.42, 6.0, 12.0)
	if rope_w > 4.0:
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
