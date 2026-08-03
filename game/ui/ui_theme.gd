class_name UITheme
extends RefCounted
## Builds the global storybook theme from the generated template kit
## (game/assets/ui/*) per docs/design/ui-style-guide.md. All screens inherit
## it from the game root; special styleboxes are exposed as helpers.

## Stitch-boundary margins, MEASURED with tests/calibrate.gd (owner method,
## 2026-08-01): a black rectangle at these insets sits snugly inside the
## page art's dotted lines with the dashes fully visible. Every screen's
## content margin comes from here — never from guessed numbers.
const PAGE_MARGIN_LEFT := 68
const PAGE_MARGIN_TOP := 40
const PAGE_MARGIN_RIGHT := 76  # +6 over the dash line: boxes never touch it
const PAGE_MARGIN_BOTTOM := 136
## Content area inside the stitching on the 720x1280 canvas.
const CONTENT_WIDTH := 720 - PAGE_MARGIN_LEFT - PAGE_MARGIN_RIGHT  # 582
const CONTENT_HEIGHT := 1280 - PAGE_MARGIN_TOP - PAGE_MARGIN_BOTTOM  # 1104

const INK := Color("2b2320")
const INK_SOFT := Color("6b5747")
const INK_FADED := Color("2b232080")
const ACCENT_WARM := Color("9c5a28")
const PARCHMENT := Color("f2e4c8")

static var _cache: Dictionary = {}


static func tex(id: String) -> Texture2D:
	var path := "res://assets/%s.png" % id
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func font(file: String) -> FontFile:
	var path := "res://assets/fonts/%s" % file
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func display_font() -> FontFile:
	return font("IMFellEnglish-Regular.ttf")


static func italic_font() -> FontFile:
	return font("IMFellEnglish-Italic.ttf")


static func smallcaps_font() -> FontFile:
	return font("IMFellEnglishSC-Regular.ttf")


static func body_font() -> FontFile:
	return font("Alegreya.ttf")


## Measures wrapped text so panels can size themselves from content instead
## of guessed constants (reusable: coach boxes, tooltips, toasts).
static func measure_text(text: String, text_font: Font, font_size: int,
		max_width: float) -> Vector2:
	if text_font == null:
		text_font = ThemeDB.fallback_font
	var size := text_font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size)
	return Vector2(minf(size.x, max_width), size.y)


## Art slot filler: the real image when it exists, else a black box with
## white text describing the missing image (owner rule — placeholders make
## gaps visible instead of invisible).
static func art_or_placeholder(id: String, description: String) -> Control:
	var art := tex(id)
	if art != null:
		var rect := TextureRect.new()
		rect.texture = art
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return rect
	var holder := Panel.new()
	var black := StyleBoxFlat.new()
	black.bg_color = Color.BLACK
	holder.add_theme_stylebox_override("panel", black)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "[ %s ]\n%s" % [id, description]
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		label.set_offset(side, 14)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		label.set_offset(side, -14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)
	return holder


## Opaque-content bounds of a texture (alpha > 0.2), cached. Generated art
## floats in transparent padding; anything that must fill its box (icons,
## tiled strips) draws from this region, not the raw canvas.
static func content_region(texture: Texture2D, key: String) -> Rect2:
	var cache_key := "region:" + key
	if _cache.has(cache_key):
		return _cache[cache_key]
	var img := texture.get_image()
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := -1
	var max_y := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.2:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	var region := Rect2(0, 0, img.get_width(), img.get_height())
	if max_x >= 0:
		region = Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	_cache[cache_key] = region
	return region


## The texture cropped to its opaque content, so a 56px icon box shows a
## 56px glyph instead of a glyph drowning in its own padding.
static func cropped_tex(id: String) -> Texture2D:
	var source := tex(id)
	if source == null:
		return null
	var cache_key := "crop:" + id
	if not _cache.has(cache_key):
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = content_region(source, id)
		_cache[cache_key] = atlas
	return _cache[cache_key]


static func stylebox(id: String, margin: int, modulate := Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = tex("ui/" + id)
	box.set_texture_margin_all(margin)
	box.set_content_margin_all(margin * 0.8)
	box.modulate_color = modulate
	return box


static func page_stylebox() -> StyleBoxTexture:
	var box := stylebox("ui_page", 34)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		box.set_content_margin(side, 30)
	box.set_content_margin(SIDE_TOP, 26)
	box.set_content_margin(SIDE_BOTTOM, 22)
	return box


## The bare stitched page every screen sits on. ONE place — change the page
## here and every screen in the game follows.
static func page_panel(root: Control) -> Panel:
	var page := Panel.new()
	page.add_theme_stylebox_override("panel", page_stylebox())
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	return page


## Full page scaffold: stitched page + the calibrated margin container
## (law 5: screens read the constants, never hand-edit margins). Screens
## build their content INSIDE the returned margin. Options:
##   "between":       Control inserted between page and margin (tap catchers
##                    that must sit under the content).
##   "ignore_mouse":  margin lets input fall through to what's beneath.
static func page_scaffold(root: Control, opts: Dictionary = {}) -> MarginContainer:
	page_panel(root)
	if opts.get("between") is Control:
		root.add_child(opts["between"])
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", PAGE_MARGIN_LEFT)
	margin.add_theme_constant_override("margin_right", PAGE_MARGIN_RIGHT)
	margin.add_theme_constant_override("margin_top", PAGE_MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", PAGE_MARGIN_BOTTOM)
	if opts.get("ignore_mouse", false):
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	return margin


## Buttons are DRAWN, not textured: the generated button art carries
## transparent padding that makes textured styleboxes render smaller than
## the button rect (text escaping its box). Flat boxes always encase.
static func amber_stylebox(modulate := Color.WHITE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("e0913a") * modulate
	box.set_border_width_all(3)
	box.border_color = Color("5e3a1a")
	box.set_corner_radius_all(14)
	box.set_content_margin_all(14)
	return box


static func dark_stylebox(modulate := Color.WHITE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("2e3446") * modulate
	box.set_border_width_all(3)
	box.border_color = Color("1a1d28")
	box.set_corner_radius_all(12)
	box.set_content_margin_all(12)
	return box


static func parchment_button_stylebox(modulate := Color.WHITE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f0e2c4") * modulate
	box.set_border_width_all(3)
	box.border_color = Color("4a3b2c")
	box.set_corner_radius_all(12)
	box.set_content_margin(SIDE_LEFT, 18)
	box.set_content_margin(SIDE_RIGHT, 18)
	box.set_content_margin(SIDE_TOP, 12)
	box.set_content_margin(SIDE_BOTTOM, 12)
	return box


## Parchment plate for panels and dialogs — DRAWN, like the buttons. The
## textured ui_panel carries transparent padding, so as a theme default it
## rendered smaller than every panel's rect (contents visibly "escaping"
## their box: outcome dialog, approach chooser, rule card, skill popup).
static func panel_stylebox(margin := 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("efe0c2")
	box.set_border_width_all(2)
	box.border_color = Color("4a3b2c")
	box.set_corner_radius_all(12)
	box.set_content_margin_all(margin)
	return box


static func strip_stylebox() -> StyleBoxTexture:
	var box := stylebox("ui_strip", 14)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		box.set_content_margin(side, 8)
	return box


# ---- Reusable widget builders (modularity rule, owner 2026-08-02) ------
# Every screen builds dialogs and buttons from THESE, never from local
# one-off styles: one code path, standardized sizes, no drift.

## Standard dim color for every modal overlay in the game.
const MODAL_DIM := Color(0.08, 0.07, 0.06, 0.72)
## Standard tap-target height for primary buttons (mobile floor).
const BUTTON_HEIGHT := 96.0


## Full-screen dim + centered parchment panel + content VBox.
## Returns {"overlay": ColorRect, "panel": PanelContainer, "box": VBoxContainer};
## toggle visibility via the overlay. Parent is usually the screen root.
static func modal(parent: Control, panel_min_width := 560.0,
		separation := 14) -> Dictionary:
	var dim := ColorRect.new()
	dim.color = MODAL_DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(panel_min_width, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	panel.add_child(box)
	return {"overlay": dim, "panel": panel, "box": box}


## Primary (amber) action button with standard tap height and ink text.
static func amber_button(text: String, font_size := 30,
		min_size := Vector2(0, BUTTON_HEIGHT)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", display_font())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", amber_stylebox())
	b.add_theme_stylebox_override("hover", amber_stylebox(Color(1.08, 1.05, 1.0)))
	b.add_theme_stylebox_override("pressed", amber_stylebox(Color(0.85, 0.8, 0.75)))
	b.add_theme_color_override("font_color", INK)
	# Disabled reads unmistakably inactive (grey plate, faded label).
	var off := StyleBoxFlat.new()
	off.bg_color = Color("cfc4ab")
	off.set_border_width_all(3)
	off.border_color = Color("a99c82")
	off.set_corner_radius_all(14)
	off.set_content_margin_all(14)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_color_override("font_disabled_color", INK_FADED)
	return b


## Secondary (dark) button for destructive or dismissive actions.
static func dark_button(text: String, font_size := 26,
		min_size := Vector2(150, BUTTON_HEIGHT)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", dark_stylebox())
	b.add_theme_stylebox_override("hover", dark_stylebox(Color(1.2, 1.2, 1.2)))
	b.add_theme_stylebox_override("pressed", dark_stylebox(Color(0.8, 0.8, 0.8)))
	b.add_theme_color_override("font_color", Color("e8e4d8"))
	b.add_theme_color_override("font_hover_color", Color("e8e4d8"))
	b.add_theme_color_override("font_pressed_color", Color("e8e4d8"))
	return b


## Label whose min size is pinned to its measured wrap (law #2 in one call).
static func measured_label(text: String, font_size: int, wrap: float,
		use_font: Font = null, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	if use_font != null:
		label.add_theme_font_override("font", use_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(wrap, measure_text(
		text, use_font if use_font != null else body_font(),
		font_size, wrap).y)
	return label


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = body_font()
	# 720-wide canvas ≈ 2x density: 30px ≈ 15sp, the mobile body-text
	# standard (see docs/research/2026-07-30-mobile-ui-research.md).
	theme.default_font_size = 30

	# Buttons: drawn parchment (see parchment_button_stylebox note).
	theme.set_stylebox("normal", "Button", parchment_button_stylebox())
	theme.set_stylebox("hover", "Button", parchment_button_stylebox(Color(1.05, 1.02, 0.95)))
	theme.set_stylebox("pressed", "Button", parchment_button_stylebox(Color(0.88, 0.84, 0.76)))
	var disabled_box := parchment_button_stylebox()
	disabled_box.bg_color.a = 0.5
	theme.set_stylebox("disabled", "Button", disabled_box)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", INK_FADED)

	theme.set_stylebox("panel", "PanelContainer", panel_stylebox())
	theme.set_color("font_color", "Label", INK)
	theme.set_color("default_color", "RichTextLabel", INK)
	return theme
