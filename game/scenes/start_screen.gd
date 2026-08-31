extends Control
## The start screen — the cover of the book, and the four ways in.
##
## Replaced the tap-anywhere title card (2026-08-30). That card had exactly
## one route out of it, which meant a player with a game in progress and a
## player who had never launched before were sent down the same corridor, and
## a second game could not be started at all.
##
## Four choices, and a line under them that says what Continue would open —
## because "Continue" with nothing named after it is a button the player has
## to press to find out what it does.
##
## The cover is NOT a page of the story: it uses page_scaffold's backdrop
## option, so it keeps the calibrated margins (and the page guard) without the
## stitched parchment around the title poster.

signal chose(action: String)   # "continue" | "new" | "load" | "credits"

const ShelfScreen := preload("res://scenes/shelf_screen.gd")

## FIXED zone template (law 12): heights + separations == CONTENT_HEIGHT.
## 602 + 438 + 44 = 1084, plus 2 x 10 separation = 1104.
const SEPARATION := 10
const ZONE_TITLE := 602
const ZONE_MENU := 438
const ZONE_FOOTER := 44

## 4 x 96 + 3 x 18 = 438 exactly. 96 is UITheme.BUTTON_HEIGHT, the mobile
## tap floor — the menu is budgeted from it rather than the other way round.
const MENU_SEPARATION := 18

## Cover ink: the poster is painted on near-black, so the type on the cover
## is the parchment colour rather than the page's ink.
const COVER_INK := Color("e8dcc0")
const COVER_INK_SOFT := Color("8f8577")

var catalog: Catalog
var shelf: Array = []
var latest_slot := -1


func setup(p_catalog: Catalog, p_shelf: Array, p_latest: int) -> void:
	catalog = p_catalog
	shelf = p_shelf
	latest_slot = p_latest


func _ready() -> void:
	var margin := UITheme.page_scaffold(self, {"backdrop": UITheme.COVER})
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)
	_build_title(column)
	_build_menu(column)
	_build_footer(column)


# ------------------------------------------------------------------- zones

func _build_title(column: VBoxContainer) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, ZONE_TITLE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(holder)
	var art := UITheme.tex("ui/logo_ashcat_title")
	if art != null:
		var poster := TextureRect.new()
		poster.texture = art
		poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# The poster is painted 2:3 on its own black, so letterboxing it into
		# the zone shows as nothing at all against the cover. Stretching it to
		# fill would squash the lettering, which is the one thing on this
		# screen nobody may misread.
		poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(poster)
		return
	# No poster in the build: the title is typeset live rather than leaving
	# the cover blank (the art is wired by script and can be absent in a
	# freshly cloned tree).
	var typeset := VBoxContainer.new()
	typeset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	typeset.alignment = BoxContainer.ALIGNMENT_CENTER
	typeset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(typeset)
	var name_label := UITheme.measured_label(Strings.line("title.name"), 56,
		UITheme.CONTENT_WIDTH, UITheme.display_font(), COVER_INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	typeset.add_child(name_label)


func _build_menu(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_MENU)
	holder.add_theme_constant_override("separation", MENU_SEPARATION)
	column.add_child(holder)
	var has_save := latest_slot > 0
	# Continue is DISABLED rather than hidden on an empty shelf. Greyed out it
	# teaches a first-time player that the game keeps their place; hidden, the
	# menu silently changes shape between the first launch and the second.
	holder.add_child(_menu_button("start.continue", "continue", has_save, true))
	holder.add_child(_menu_button("start.new", "new", true, not has_save))
	holder.add_child(_menu_button("start.load", "load", _any_book(), false))
	holder.add_child(_menu_button("start.credits", "credits", true, false))


func _build_footer(column: VBoxContainer) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, ZONE_FOOTER)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(holder)
	# TYPE_SUPPORT, not the floor: this is the only line on the cover that
	# tells the player anything, and it is what Continue means.
	var line := UITheme.measured_label(_resume_line(), UITheme.TYPE_SUPPORT,
		UITheme.CONTENT_WIDTH, UITheme.italic_font(), COVER_INK_SOFT)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)


# ------------------------------------------------------------------ pieces

## `primary` picks the amber plate: exactly one button on the cover is the
## one to press, and which one it is depends on whether there is a game to
## come back to.
func _menu_button(key: String, action: String, enabled: bool,
		primary: bool) -> Button:
	var text := Strings.line(key)
	var button: Button = UITheme.amber_button(text, UITheme.TYPE_BODY) \
		if primary else UITheme.dark_button(text, UITheme.TYPE_BODY,
			Vector2(0, UITheme.BUTTON_HEIGHT))
	button.disabled = not enabled
	button.pressed.connect(func() -> void: chose.emit(action))
	return button


func _any_book() -> bool:
	for summary: Dictionary in shelf:
		if bool(summary["used"]):
			return true
	return false


## What Continue would open, named. The shelf screen owns how a book describes
## itself, so the cover and the shelf never disagree about the same book.
func _resume_line() -> String:
	if latest_slot <= 0:
		return Strings.line("start.empty_shelf")
	for summary: Dictionary in shelf:
		if int(summary["slot"]) != latest_slot:
			continue
		if not bool(summary["prologue_done"]):
			return Strings.line("start.resume_unread", [latest_slot])
		return Strings.line("start.resume",
			[latest_slot, ShelfScreen.where_line(catalog, summary)])
	return Strings.line("start.empty_shelf")
