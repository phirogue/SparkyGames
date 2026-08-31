extends Control
## Credits — who made it, and the AI disclosure the policy owes a player
## (docs/design/ai-transparency.md: "disclosed in the credits and in
## store-listing fine print. A plain statement, not buried, not shouted").
##
## Until this screen existed the disclosure lived in the settings footer at
## 22px, which is where a player looks for it only by accident. It stays on
## the settings page as a one-liner and says the whole of it here.
##
## Every word comes out of story/interface.json's `credits` block, sections
## and all — crediting a new collaborator is an edit to that file and to
## nothing else.

signal closed

## FIXED zone template (law 12): heights + separations == CONTENT_HEIGHT.
## 96 + 880 + 104 = 1080, plus 2 x 12 separation = 1104.
const SEPARATION := 12
const ZONE_HEADER := 96
const ZONE_ROLL := 880
const ZONE_FOOTER := 104

## The roll scrolls, so its content may be taller than its zone — but never
## WIDER than the page, which is why every label is measured to this.
const ROLL_WIDTH := UITheme.CONTENT_WIDTH - 24.0
const ROLE_SEPARATION := 4
const BLOCK_SEPARATION := 22


func _ready() -> void:
	var margin := UITheme.page_scaffold(self)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)
	_build_header(column)
	_build_roll(column)
	_build_footer(column)


func _build_header(column: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, ZONE_HEADER)
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	var back := Button.new()
	back.custom_minimum_size = Vector2(96, 96)
	var arrow := UITheme.tex("ui/ui_arrow_back")
	if arrow != null:
		back.icon = arrow
		back.expand_icon = true
	else:
		back.text = "<"
	back.pressed.connect(func() -> void: closed.emit())
	header.add_child(back)
	var title := UITheme.measured_label(Strings.line("credits.heading"),
		UITheme.TYPE_TITLE, UITheme.CONTENT_WIDTH - 112, UITheme.display_font())
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_FILL
	header.add_child(title)


func _build_roll(column: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, ZONE_ROLL)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var roll := VBoxContainer.new()
	roll.add_theme_constant_override("separation", BLOCK_SEPARATION)
	roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(roll)

	roll.add_child(_line("credits.subheading", UITheme.TYPE_HEADING,
		UITheme.display_font(), UITheme.INK))

	# Sections are DATA: role plus the names under it. The screen renders
	# whatever the file holds and knows none of the roles by name.
	for section: Dictionary in Strings.section("credits").get("sections", []):
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", ROLE_SEPARATION)
		roll.add_child(block)
		block.add_child(UITheme.measured_label(String(section.get("role", "")),
			UITheme.TYPE_SUPPORT, ROLL_WIDTH, UITheme.smallcaps_font(),
			UITheme.ACCENT_WARM))
		for name_line in section.get("lines", []):
			block.add_child(UITheme.measured_label(String(name_line),
				UITheme.TYPE_BODY, ROLL_WIDTH, UITheme.body_font()))

	var disclosure := VBoxContainer.new()
	disclosure.add_theme_constant_override("separation", ROLE_SEPARATION)
	roll.add_child(disclosure)
	disclosure.add_child(_line("credits.disclosure_heading", UITheme.TYPE_SUPPORT,
		UITheme.smallcaps_font(), UITheme.ACCENT_WARM))
	for paragraph in Strings.lines("credits.disclosure"):
		disclosure.add_child(UITheme.measured_label(paragraph,
			UITheme.TYPE_SUPPORT, ROLL_WIDTH, UITheme.body_font(),
			UITheme.INK_SOFT))

	roll.add_child(_line("credits.closing", UITheme.TYPE_SUPPORT,
		UITheme.italic_font(), UITheme.INK_SOFT))


func _build_footer(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_FOOTER)
	column.add_child(holder)
	var back := UITheme.amber_button(Strings.line("credits.back"),
		UITheme.TYPE_BODY)
	back.size_flags_vertical = Control.SIZE_SHRINK_END
	back.pressed.connect(func() -> void: closed.emit())
	holder.add_child(back)


func _line(key: String, size: int, use_font: FontFile, color: Color) -> Label:
	return UITheme.measured_label(Strings.line(key), size, ROLL_WIDTH,
		use_font, color)
