extends SceneTree
## Page-boundary calibration (owner method 2026-08-01): draw a black
## rectangle at the given margins over the page art, screenshot it, and
## tune until it sits snugly INSIDE the dotted stitch lines. The winning
## numbers become UITheme.PAGE_* constants.
##   godot --path game -s tests/calibrate.gd -- <left> <top> <right> <bottom>
## Output: screenshots/calibrate.png

## Zone maps (owner method, step 2): colored boxes divide the calibrated
## content area BEFORE real widgets go in — one map per screen type, kept
## in sync with each screen's layout contract.
##   godot --path game -s tests/calibrate.gd -- zones battle|story|choice|hub
const ZONE_MAPS := {
	# Keep in sync with battle.gd's ZONE_* constants (law 12). Heights sum to
	# 1086; the six 3px separations make up CONTENT_HEIGHT's remaining 18.
	"battle": [
		["A header", 98, Color("c2884a")],
		["B opponent", 396, Color("a24a3a")],
		["C chronicle", 150, Color("7a6a4a")],
		["D status", 56, Color("4a7a5a")],
		["E hand", 140, Color("4a5a8a")],
		["F skills (5 x 107)", 150, Color("6a4a7a")],
		["G buttons", 96, Color("8a7a2a")],
	],
	"story": [
		["art (fixed)", 680, Color("a24a3a")],
		["heading", 50, Color("c2884a")],
		["narration", 264, Color("4a5a8a")],
		["tap hint", 40, Color("7a6a4a")],
	],
	"choice": [
		["art (fixed)", 680, Color("a24a3a")],
		["heading", 50, Color("c2884a")],
		["narration", 132, Color("4a5a8a")],
		["choices x2", 216, Color("8a7a2a")],
	],
	"hub": [
		["title+intro", 240, Color("c2884a")],
		["scroll (quests, shop, casebook)", 858, Color("4a7a5a")],
	],
	# Keep in sync with case_board_screen.gd's ZONE_* constants.
	"case": [
		["header (back + title)", 96, Color("c2884a")],
		["question + aphorism", 140, Color("7a6a4a")],
		["suspects (3 cards)", 290, Color("a24a3a")],
		["evidence grid (3 x 2)", 416, Color("4a5a8a")],
		["footer (lead, knots, notice)", 114, Color("4a7a5a")],
	],
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var page := Panel.new()
	page.add_theme_stylebox_override("panel", UITheme.page_stylebox())
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	if args.has("zones"):
		var which := "battle"
		var zi := args.find("zones")
		if zi + 1 < args.size() and ZONE_MAPS.has(args[zi + 1]):
			which = args[zi + 1]
		_build_zone_map(page, which)
		print("calibrate: '%s' zone map at PAGE_MARGIN_* boundaries" % which)
	else:
		var l := int(args[0]) if args.size() > 0 else UITheme.PAGE_MARGIN_LEFT
		var t := int(args[1]) if args.size() > 1 else UITheme.PAGE_MARGIN_TOP
		var r := int(args[2]) if args.size() > 2 else UITheme.PAGE_MARGIN_RIGHT
		var b := int(args[3]) if args.size() > 3 else UITheme.PAGE_MARGIN_BOTTOM
		var rect := ColorRect.new()
		rect.color = Color.BLACK
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.offset_left = l
		rect.offset_top = t
		rect.offset_right = -r
		rect.offset_bottom = -b
		page.add_child(rect)
		print("calibrate margins: l=%d t=%d r=%d b=%d" % [l, t, r, b])
	create_timer(0.6).timeout.connect(_shoot)


func _build_zone_map(page: Control, which: String) -> void:
	var y := float(UITheme.PAGE_MARGIN_TOP)
	for zone: Array in ZONE_MAPS[which]:
		var rect := ColorRect.new()
		rect.color = zone[2]
		rect.position = Vector2(UITheme.PAGE_MARGIN_LEFT, y)
		rect.size = Vector2(UITheme.CONTENT_WIDTH, zone[1])
		page.add_child(rect)
		var tag := Label.new()
		tag.text = "%s  %dpx" % [zone[0], zone[1]]
		tag.add_theme_font_size_override("font_size", 22)
		tag.add_theme_color_override("font_color", Color.WHITE)
		tag.position = rect.position + Vector2(10, 4)
		page.add_child(tag)
		y += zone[1] + 6.0
	var used := y - 6.0 - UITheme.PAGE_MARGIN_TOP
	print("zones used %dpx of %dpx content height" % [int(used), UITheme.CONTENT_HEIGHT])


func _shoot() -> void:
	var img := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://") + "../screenshots/calibrate.png"
	img.save_png(path)
	print("saved: ", path)
	quit(0)
