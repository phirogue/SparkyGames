class_name UITheme
extends RefCounted
## Builds the global storybook theme from the generated template kit
## (game/assets/ui/*) per docs/design/ui-style-guide.md. All screens inherit
## it from the game root; special styleboxes are exposed as helpers.

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


static func amber_stylebox(modulate := Color.WHITE) -> StyleBoxTexture:
	return stylebox("ui_btn_amber", 26, modulate)


static func dark_stylebox(modulate := Color.WHITE) -> StyleBoxTexture:
	return stylebox("ui_btn_dark", 22, modulate)


static func strip_stylebox() -> StyleBoxTexture:
	var box := stylebox("ui_strip", 14)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		box.set_content_margin(side, 8)
	return box


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = body_font()
	# 720-wide canvas ≈ 2x density: 30px ≈ 15sp, the mobile body-text
	# standard (see docs/research/2026-07-30-mobile-ui-research.md).
	theme.default_font_size = 30

	# Buttons: parchment 9-patch, pressed/hover as tint variants.
	theme.set_stylebox("normal", "Button", stylebox("ui_btn_parchment", 22))
	theme.set_stylebox("hover", "Button", stylebox("ui_btn_parchment", 22, Color(1.05, 1.02, 0.95)))
	theme.set_stylebox("pressed", "Button", stylebox("ui_btn_parchment", 22, Color(0.88, 0.84, 0.76)))
	theme.set_stylebox("disabled", "Button", stylebox("ui_btn_parchment", 22, Color(1, 1, 1, 0.5)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", INK_FADED)

	theme.set_stylebox("panel", "PanelContainer", stylebox("ui_panel", 24))
	theme.set_color("font_color", "Label", INK)
	theme.set_color("default_color", "RichTextLabel", INK)
	return theme
