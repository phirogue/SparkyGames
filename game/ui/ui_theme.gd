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


## The transparent opening inside a frame texture's opaque border, in the
## texture's own pixel coordinates. Scanned once from the alpha channel
## through the frame's centre (law: never trust generated textures'
## geometry — the portrait frame's painted wood floats in transparent
## padding AND encloses a hole, and both have to be measured, not guessed).
static func frame_aperture(id: String) -> Rect2:
	var cache_key := "aperture:" + id
	if _cache.has(cache_key):
		return _cache[cache_key]
	var texture := tex(id)
	if texture == null:
		return Rect2()
	var img := texture.get_image()
	var region := content_region(texture, id)
	var cx := int(region.position.x + region.size.x / 2.0)
	var cy := int(region.position.y + region.size.y / 2.0)
	var x0 := cx
	while x0 - 1 > region.position.x and img.get_pixel(x0 - 1, cy).a <= 0.2:
		x0 -= 1
	var x1 := cx
	while x1 + 1 < region.end.x - 1 and img.get_pixel(x1 + 1, cy).a <= 0.2:
		x1 += 1
	var y0 := cy
	while y0 - 1 > region.position.y and img.get_pixel(cx, y0 - 1).a <= 0.2:
		y0 -= 1
	var y1 := cy
	while y1 + 1 < region.end.y - 1 and img.get_pixel(cx, y1 + 1).a <= 0.2:
		y1 += 1
	var aperture := Rect2(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	# A texture with no real hole (or an opaque centre) is not a frame;
	# fall back to a window 12% inside the opaque bounds.
	if aperture.size.x < region.size.x * 0.2 or aperture.size.y < region.size.y * 0.2:
		aperture = region.grow_individual(
			-region.size.x * 0.12, -region.size.y * 0.12,
			-region.size.x * 0.12, -region.size.y * 0.12)
	_cache[cache_key] = aperture
	return aperture


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
	# ANCHORS AND OFFSETS, not anchors alone (engineering law 9, paid for a
	# second time on 2026-08-05). With anchors only, the container keeps its
	# own rect and a MarginContainer sizes itself to its content's MINIMUM —
	# so one long rule line in the battle header grew the page to 820x1282 in
	# a 720x1280 window and pushed every zone off the right edge. Pinned to
	# the viewport, the page is the page and content has to fit it.
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.name = "PageContent"
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


## The torn-parchment plate behind a settings row / a pinned note. 9-patched
## so the torn silhouette repeats along the edges instead of being squashed:
## the master is 720x238 and the row it fills is 582x120, which stretched
## flat would leave squat corner sprigs (law 3 — read the geometry first).
##
## The margins are MEASURED off the shipped texture, not guessed: the ink
## dashes run at y=22 and y=213, and the leaf sprigs occupy x<120 and x>600.
## Cutting the corners at 130/46 keeps both sprigs whole inside the fixed
## corner patches, so the tiled middle is plain parchment and its seam is
## invisible. At 96 the cut fell through the sprigs and the seam showed.
const ROW_DASH_INSET := 24   # ink border inside the plate; text clears it
static func row_stylebox(modulate := Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = tex("ui/ui_settings_row")
	box.set_texture_margin(SIDE_LEFT, 130)
	box.set_texture_margin(SIDE_RIGHT, 130)
	box.set_texture_margin(SIDE_TOP, 46)
	box.set_texture_margin(SIDE_BOTTOM, 46)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.set_content_margin(SIDE_LEFT, 26)
	box.set_content_margin(SIDE_RIGHT, 26)
	box.set_content_margin(SIDE_TOP, 12)
	box.set_content_margin(SIDE_BOTTOM, 12)
	box.modulate_color = modulate
	return box


## An icon drawn at its OPAQUE size inside a fixed box: generated glyphs float
## in their own padding, so the raw texture in a 64px box renders a 30px bell
## (law 3). Cropped first, then fitted.
static func icon(id: String, box_size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = cropped_tex(id)
	rect.custom_minimum_size = Vector2(box_size, box_size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## A transparent, full-rect Button laid over a control so the WHOLE thing is
## the tap target (mobile floor) instead of a hotspot inside it. The parent
## must not be a Container, which would lay the button out as another child.
static func tap_layer(over: Control) -> Button:
	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	over.add_child(button)
	return button


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


## Every modal in the game opens and closes with the same pop (battle had it
## first; owner asked for the rest of the book to feel as alive). The seq
## metadata guards the close callback against a re-open mid-tween — the same
## race battle.gd pays for with _modal_seq.
static func open_modal(overlay: Control, panel: Control) -> void:
	overlay.set_meta("modal_seq", int(overlay.get_meta("modal_seq", 0)) + 1)
	overlay.visible = true
	overlay.modulate.a = 0.0
	panel.scale = Vector2(0.8, 0.8)
	var tree := overlay.get_tree()
	if tree != null:
		await tree.process_frame
	if not overlay.visible:
		return  # closed before it finished appearing
	panel.pivot_offset = panel.size / 2.0
	var tween := overlay.create_tween().set_parallel()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.16)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func close_modal(overlay: Control, panel: Control) -> void:
	if not overlay.visible:
		return
	overlay.set_meta("modal_seq", int(overlay.get_meta("modal_seq", 0)) + 1)
	var seq := int(overlay.get_meta("modal_seq", 0))
	panel.pivot_offset = panel.size / 2.0
	var tween := overlay.create_tween().set_parallel()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.12)
	tween.tween_property(panel, "scale", Vector2(0.85, 0.85), 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		if int(overlay.get_meta("modal_seq", 0)) != seq:
			return  # re-opened mid-close; leave it alone
		overlay.visible = false
		overlay.modulate.a = 1.0
		panel.scale = Vector2.ONE)


## Law 13: every modal needs an escape path that is not a button. A tap on
## the dim (anywhere off the panel) closes. Wired through gui_input on the
## overlay itself so it works whether the tap lands on the dim directly or
## falls through the centering container above it.
static func modal_escape(parts: Dictionary, on_close: Callable) -> void:
	var dim: Control = parts["overlay"]
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			dim.accept_event()
			on_close.call())


## A quick attention pulse — the purse when it pays out, a count the moment
## it changes. Motion is the receipt for a tap that altered a number.
static func pulse(control: Control, strength := 1.18) -> void:
	control.pivot_offset = control.size / 2.0
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * strength, 0.11) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.17) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Fade-in entrance for a control that was just (re)built, so a card landing
## in a new row reads as having MOVED rather than the page blinking. Fades
## modulate only — containers own positions and fight position tweens.
static func settle(control: Control, delay := 0.0) -> void:
	control.modulate.a = 0.0
	var tween := control.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(control, "modulate:a", 1.0, 0.22)


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
## The biggest size from `sizes` (largest first) at which `text` fits inside
## `box` when wrapped to box.x. Falls back to the smallest offered.
##
## This is step 3 of the owner's calibration method (law 5) as a function:
## pick the type size from the box, before placement, instead of setting a
## size and hoping. It exists because a plain Label reports its minimum width
## as the whole unwrapped string, so one long location name — "The Shambles,
## After Hours" — silently grew the battle page from 720 to 820 pixels wide
## and shoved every zone off the right edge of the book (owner, 2026-08-05).
static func fit_font_size(text: String, use_font: Font, sizes: Array,
		box: Vector2) -> int:
	for size in sizes:
		if measure_text(text, use_font, int(size), box.x).y <= box.y:
			return int(size)
	return int(sizes[sizes.size() - 1])


## A label pinned to a box: wrapped to box.x, at the largest of `sizes` that
## fits box.y. Never reports a minimum width larger than the box it was given,
## which is the property that keeps a page from being pushed off the screen.
static func fitted_label(text: String, sizes: Array, box: Vector2,
		use_font: Font = null, color := INK) -> Label:
	var font: Font = use_font if use_font != null else body_font()
	var size := fit_font_size(text, font, sizes, box)
	var label := measured_label(text, size, box.x, font, color)
	label.custom_minimum_size = Vector2(box.x,
		minf(label.custom_minimum_size.y, box.y))
	return label


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
