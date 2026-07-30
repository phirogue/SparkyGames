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
	theme.default_font_size = 18

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
