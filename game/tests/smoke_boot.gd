extends SceneTree
## Boot smoke test: load the real game scene and verify the active screen
## fills the viewport. Guards against the zero-size tap-target regression
## (2026-07-30: screens parented to the flow root had 0x0 rects, so taps
## never registered). Run: godot --headless --path game -s tests/smoke_boot.gd

func _initialize() -> void:
	var scene: Control = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var frames := [0]
	process_frame.connect(func() -> void:
		frames[0] += 1
		if frames[0] >= 5:
			var screen: Control = scene.current_screen
			var ok: bool = screen != null and screen.size.x > 100 and screen.size.y > 100
			print("game size: %s  screen size: %s  -> %s" % [
				scene.size, screen.size if screen != null else Vector2.ZERO,
				"OK" if ok else "BROKEN",
			])
			if screen != null:
				print("anchors L%s T%s R%s B%s  offsets L%s T%s R%s B%s  layout_mode=%s" % [
					screen.anchor_left, screen.anchor_top, screen.anchor_right,
					screen.anchor_bottom, screen.offset_left, screen.offset_top,
					screen.offset_right, screen.offset_bottom,
					screen.get("layout_mode"),
				])
			quit(0 if ok else 1))
