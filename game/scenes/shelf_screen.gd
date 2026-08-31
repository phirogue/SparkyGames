extends Control
## The shelf: three books, and what is written in each.
##
## One screen, two errands. Opening a book and choosing where to put a new one
## are the same list of the same three plates, so they are the same screen with
## a `mode` on it — a second, nearly-identical page would have drifted from
## this one by the third edit.
##
## This screen also owns HOW A BOOK DESCRIBES ITSELF (`where_line` below), and
## the start screen borrows it for the line under Continue. One answer to
## "where is this game up to", in one place.
##
## The facts come from SaveService.shelf() — counts and ids, never sentences.
## The words are all here, out of story/interface.json (law 20).

signal chose(slot: int)
signal closed

## FIXED zone template (law 12): heights + separations == CONTENT_HEIGHT.
## 96 + 80 + 780 + 112 = 1068, plus 3 x 12 separation = 1104.
const SEPARATION := 12
const ZONE_HEADER := 96
const ZONE_BLURB := 80
const ZONE_BOOKS := 780
const ZONE_FOOTER := 112

## 3 x 252 + 2 x 12 = 780 exactly.
const BOOK_HEIGHT := 252
const BOOK_SEPARATION := 12

## A DRAWN plate, not the torn settings-row art (law 22: never trust
## generated textures' geometry). ui_settings_row is 9-patched with 130px
## fixed corners and its leaf sprigs live inside them, so on a 582-wide plate
## the sprigs own the left 130px and the right 130px — and vertically they run
## most of the plate's height. A settings row fits because it puts an ICON in
## that zone and one short name after it. Four lines of a book's history do
## not: the first pass put "Book 1" and the date straight through two sprigs
## (caught in the tour, 2026-08-30). Drawn parchment has no decoration to
## collide with and hands the whole width back.
const ROW_INSET := 28.0
const LINE_SEPARATION := 6

## What the plate is asked to hold, measured before anything is placed (law 5).
const TEXT_WIDTH := UITheme.CONTENT_WIDTH - 2.0 * ROW_INSET   # 526

var catalog: Catalog
var mode := "load"      # "load" (open a book) or "new" (choose where to write)
var shelf: Array = []   # SaveService.shelf()

var _modal: Dictionary = {}
var _pending_slot := 0


func setup(p_catalog: Catalog, p_shelf: Array, p_mode: String) -> void:
	catalog = p_catalog
	shelf = p_shelf
	mode = p_mode


func _ready() -> void:
	var margin := UITheme.page_scaffold(self)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)
	_build_header(column)
	_build_blurb(column)
	_build_books(column)
	_build_footer(column)
	_build_overwrite_modal()


# ------------------------------------------------------------------- zones

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
	var title := UITheme.measured_label(
		Strings.line("shelf.new_heading" if mode == "new" else "shelf.load_heading"),
		UITheme.TYPE_TITLE, UITheme.CONTENT_WIDTH - 112, UITheme.display_font())
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_FILL
	header.add_child(title)


func _build_blurb(column: VBoxContainer) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, ZONE_BLURB)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(holder)
	# "Three books. Open one." over three books with nothing in them is the
	# page telling the player to do something it will not let them do.
	var key := "shelf.new_blurb"
	if mode != "new":
		key = "shelf.load_blurb" if _any_book() else "shelf.load_blurb_empty"
	var blurb := UITheme.measured_label(Strings.line(key),
		UITheme.TYPE_SUPPORT, UITheme.CONTENT_WIDTH, UITheme.italic_font(),
		UITheme.INK_SOFT)
	blurb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(blurb)


func _build_books(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_BOOKS)
	holder.add_theme_constant_override("separation", BOOK_SEPARATION)
	column.add_child(holder)
	for summary: Dictionary in shelf:
		holder.add_child(_book_plate(summary))


func _build_footer(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_FOOTER)
	column.add_child(holder)
	var back := UITheme.amber_button(Strings.line("shelf.back"), UITheme.TYPE_BODY)
	back.size_flags_vertical = Control.SIZE_SHRINK_END
	back.pressed.connect(func() -> void: closed.emit())
	holder.add_child(back)


# ------------------------------------------------------------------- plates

## One book. The WHOLE plate is the tap target (mobile floor), and an empty
## book is still tappable in "new" mode and dead in "load" mode — a plate that
## looks the same and does nothing is the defect this fork exists to avoid.
func _book_plate(summary: Dictionary) -> Control:
	var used: bool = bool(summary["used"])
	var live := used or mode == "new"
	var plate := Panel.new()
	plate.custom_minimum_size = Vector2(0, BOOK_HEIGHT)
	var face := UITheme.panel_stylebox(int(ROW_INSET))
	if not live:
		# An unopenable book is a closed one: the same plate, gone to shadow.
		face.bg_color = Color("d8ccb0")
		face.border_color = Color("8a7a63")
	plate.add_theme_stylebox_override("panel", face)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", LINE_SEPARATION)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = ROW_INSET
	body.offset_right = -ROW_INSET
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(body)

	body.add_child(UITheme.measured_label(
		Strings.line("shelf.book", [int(summary["slot"])]),
		UITheme.TYPE_HEADING, TEXT_WIDTH, UITheme.display_font(),
		UITheme.INK if live else UITheme.INK_SOFT))
	body.add_child(UITheme.measured_label(where_line(catalog, summary),
		UITheme.TYPE_BODY, TEXT_WIDTH, UITheme.body_font(), UITheme.INK_SOFT))
	# The ledger only appears once there IS one. A book still in the prologue
	# has banked nothing, walked nowhere and spent no lives, and three zeros
	# in a row read as a broken readout rather than as a young game.
	if used and bool(summary["prologue_done"]):
		body.add_child(UITheme.measured_label(Strings.line("shelf.detail", [
			int(summary["gleam"]), int(summary["quests_done"]),
			int(summary["lives_spent"])]),
			UITheme.TYPE_SUPPORT, TEXT_WIDTH, UITheme.smallcaps_font(),
			UITheme.INK_SOFT))
		# INK_SOFT, not INK_FADED: at 22px a half-alpha line is a smudge,
		# and this is the line that tells two books apart.
		body.add_child(UITheme.measured_label(_written_line(summary),
			UITheme.TYPE_FLOOR, TEXT_WIDTH, UITheme.italic_font(),
			UITheme.INK_SOFT))

	if live:
		UITheme.tap_layer(plate).pressed.connect(
			_on_book_pressed.bind(int(summary["slot"]), used))
	return plate


func _any_book() -> bool:
	for summary: Dictionary in shelf:
		if bool(summary["used"]):
			return true
	return false


## Where a book is up to, in one line. Static and catalog-driven so the start
## screen can say the same thing about the same book without a second version
## of this decision drifting out of step with this one.
static func where_line(p_catalog: Catalog, summary: Dictionary) -> String:
	if not bool(summary["used"]):
		return Strings.line("shelf.empty_detail")
	if not bool(summary["prologue_done"]):
		return Strings.line("shelf.in_prologue")
	var case_id := String(summary.get("case", ""))
	if p_catalog != null and p_catalog.cases.has(case_id):
		return String(p_catalog.cases[case_id]["name"])
	return Strings.line("shelf.no_case")


## The hour a book was written, in the reader's own clock. A save from before
## the game recorded the hour says so rather than claiming a date it does not
## know (law 7 — an old save implies nothing about when it was written).
static func _written_line(summary: Dictionary) -> String:
	var stamp := int(summary.get("saved_at", 0))
	if stamp <= 0:
		return Strings.line("shelf.saved_unknown")
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var when := Time.get_datetime_dict_from_unix_time(stamp + bias)
	var months: Array = Strings.lines("shelf.months")
	var month_index: int = clampi(int(when["month"]) - 1, 0, months.size() - 1)
	return Strings.line("shelf.saved", [Strings.line("shelf.date", [
		months[month_index], int(when["day"]),
		int(when["hour"]), int(when["minute"])])])


# -------------------------------------------------------------------- taps

func _on_book_pressed(slot: int, used: bool) -> void:
	# Starting a new game ON TOP of an old one is the only destructive tap in
	# the game, so it is the only one that asks first.
	if mode == "new" and used:
		_pending_slot = slot
		_open_overwrite(slot)
		return
	chose.emit(slot)


func _build_overwrite_modal() -> void:
	_modal = UITheme.modal(self)
	var box: VBoxContainer = _modal["box"]
	var heading := UITheme.measured_label("", UITheme.TYPE_HEADING, 480.0,
		UITheme.display_font())
	heading.name = "OverwriteHeading"
	box.add_child(heading)
	box.add_child(UITheme.measured_label(Strings.line("shelf.overwrite_body"),
		UITheme.TYPE_SUPPORT, 480.0, UITheme.body_font(), UITheme.INK_SOFT))
	var confirm := UITheme.amber_button(
		Strings.line("shelf.overwrite_confirm"), UITheme.TYPE_BODY)
	confirm.pressed.connect(func() -> void:
		_close_overwrite()
		chose.emit(_pending_slot))
	box.add_child(confirm)
	var cancel := UITheme.dark_button(
		Strings.line("shelf.overwrite_cancel"), UITheme.TYPE_SUPPORT)
	cancel.pressed.connect(_close_overwrite)
	box.add_child(cancel)
	# Law 13: a tap off the panel is the escape that is not a button.
	UITheme.modal_escape(_modal, _close_overwrite)


func _open_overwrite(slot: int) -> void:
	var heading: Label = _modal["panel"].find_child("OverwriteHeading", true, false)
	heading.text = Strings.line("shelf.overwrite_heading", [slot])
	UITheme.open_modal(_modal["overlay"], _modal["panel"])


func _close_overwrite() -> void:
	UITheme.close_modal(_modal["overlay"], _modal["panel"])
