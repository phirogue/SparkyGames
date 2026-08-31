extends Control
## Settings — the storybook page version of the options menu, built to
## assets/library/mockups/mock_settings.png: torn parchment row plates, a felt
## toggle with a bone button on each, and loudness counted in paw prints
## instead of a slider (information becomes objects — ui-style-guide).
##
## It is an OVERLAY, not a screen: game.gd parks it on the settings
## CanvasLayer so it is reachable from anywhere (owner rule) WITHOUT swapping
## out what is underneath. Swapping mid-battle would destroy the combat state.
##
## The screen owns no behaviour: every change goes out as `setting_changed`
## and game.gd applies it (audio buses, the lamp dim) and saves. See
## docs/design/ui-screens.md.

signal closed
signal setting_changed(key: String, value: Variant)
## The two things a player may do to their save. Neither is a "save" button:
## the game writes the book at its own checkpoints, so the player can turn
## back to the last one or close the book, and cannot stamp a save of their
## own to roll back to (see story/interface.json "book").
signal revert_requested
signal close_book_requested

## FIXED zone template (law 12): heights + separations == CONTENT_HEIGHT.
## 96 + 656 + 126 + 190 = 1068, plus 3 x 12 separation = 1104.
const SEPARATION := 12
const ZONE_HEADER := 96
const ZONE_ROWS := 656
const ZONE_LOUDNESS := 126
const ZONE_FOOTER := 190

## 5 x 120 + 4 x 14 = 656 exactly. The book row arrived on 2026-08-30 and was
## briefly paid for out of the ROW HEIGHT (six rows at 101), because law 12
## says new content goes INTO an existing zone and ZONE_ROWS is the same 656
## it has always been. The owner then cut the Language row the next day —
## "this game will be English only for now" — so the page is back at five rows
## and at the geometry it was calibrated against.
const ROW_HEIGHT := 120
const ROW_SEPARATION := 14

## Width budget for a row, measured rather than guessed (law 2). The plate is
## CONTENT_WIDTH wide; the dashed border inside the torn art eats ROW_INSET a
## side, leaving 502. icon 72 + name 190 + toggle 132 + word 58 + 3 x 10
## separation = 482, with 20px of slack. The first cut of these numbers came
## to exactly 502 and the ON/OFF word was squeezed to one letter wide.
const ROW_INSET := 40.0
const ICON_BOX := 72.0
const TOGGLE_SIZE := Vector2(132, 58)
const VALUE_WIDTH := 58.0
const NAME_WRAP := 190.0
const ROW_ITEM_SEPARATION := 10

const VOLUME_STEPS := 5
const PAW_SIZE := 74.0

## Modal geometry. UITheme.modal's panel is 560 wide by default and the
## parchment stylebox eats 16 a side; text measured to anything wider than
## this wraps to a width the panel never had (law 5).
const MODAL_TEXT_WIDTH := 480.0
## Every confirm body is written as this many lines, so the panel is the same
## height whichever action opened it.
const CONFIRM_BODY_LINES := 2

## The toggle rows, in the order the mockup has them. `icon` is an asset id;
## every one of these already existed in the library.
const TOGGLE_ROWS := [
	{"key": "sfx", "name": "Sound Effects", "icon": "ui/ui_icon_sound"},
	{"key": "music", "name": "Music", "icon": "ui/ui_icon_music"},
	{"key": "lamps_low", "name": "Lamps Low", "icon": "ui/ui_icon_brightness"},
	{"key": "ask_to_spend", "name": "Ask to Spend", "icon": "ui/ui_seal_gold"},
]

var settings: Dictionary = {}
## Whether there is a real book behind this session. A tour or a component
## run is a throwaway world with nothing written down, and offering to turn
## back a page that was never written would be the page lying.
var book_live := true

var _toggle_art: Dictionary = {}   # key -> TextureRect
var _toggle_word: Dictionary = {}  # key -> Label
var _paws: Array[TextureRect] = []
var _book: Dictionary = {}      # the book panel
var _book_note: Label           # the panel's one paragraph, which changes
var _book_actions: Array[Button] = []
var _confirm: Dictionary = {}   # the shared "are you sure" panel
var _pending := ""              # which action the confirm panel is asking about


func setup(p_settings: Dictionary, p_book_live: bool = true) -> void:
	settings = p_settings
	book_live = p_book_live


func _ready() -> void:
	# On a CanvasLayer the game root's theme does not propagate down, so the
	# page has to carry it or every label falls back to the engine font.
	if theme == null:
		theme = UITheme.build()
	var margin := UITheme.page_scaffold(self)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)
	_build_header(column)
	_build_rows(column)
	_build_loudness(column)
	_build_footer(column)
	_build_book_panel()
	_build_confirm_panel()


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
		back.text = "←"
	back.pressed.connect(func() -> void: closed.emit())
	header.add_child(back)
	var title := UITheme.measured_label("Settings", 46,
		UITheme.CONTENT_WIDTH - 112, UITheme.display_font())
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_FILL
	header.add_child(title)


func _build_rows(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_ROWS)
	holder.add_theme_constant_override("separation", ROW_SEPARATION)
	column.add_child(holder)
	for row: Dictionary in TOGGLE_ROWS:
		holder.add_child(_toggle_row(String(row["key"]), String(row["name"]),
			String(row["icon"])))
	# The fifth is an ACTION, not a switch: it opens the book panel rather than
	# changing anything itself, because both things it offers are worth a
	# second tap.
	#
	# There WAS a Language row here, an inert value showing "English". The
	# owner cut it on 2026-08-31 — "this game will be English only for now" —
	# and a row that reports a choice nobody has is furniture. _value_row
	# stays: the book row is built from it.
	holder.add_child(_book_row())


func _build_loudness(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_LOUDNESS)
	holder.add_theme_constant_override("separation", 6)
	column.add_child(holder)
	holder.add_child(UITheme.measured_label("Loudness", 28,
		UITheme.CONTENT_WIDTH, UITheme.smallcaps_font(), UITheme.INK_SOFT))
	var paws := HBoxContainer.new()
	paws.add_theme_constant_override("separation", 18)
	paws.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_child(paws)
	# Loudness in paw prints: five steps is enough choice for a phone, and it
	# is a far bigger tap target than a slider grabber.
	for step in VOLUME_STEPS:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(PAW_SIZE, PAW_SIZE)
		slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		paws.add_child(slot)
		var paw := UITheme.icon("ui/ui_paw_full", PAW_SIZE)
		paw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(paw)
		_paws.append(paw)
		UITheme.tap_layer(slot).pressed.connect(_on_volume_step.bind(step + 1))
	_refresh_paws()


func _build_footer(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_FOOTER)
	holder.add_theme_constant_override("separation", 8)
	column.add_child(holder)
	# The one-line version of the disclosure. The whole of it, and the roll
	# it belongs under, is on the credits screen now — but this page is where
	# a player looks first, and the policy says the statement is not to be
	# buried (docs/design/ai-transparency.md).
	holder.add_child(UITheme.measured_label(
		Strings.line("settings.ai_disclosure"),
		22, UITheme.CONTENT_WIDTH, UITheme.italic_font(), UITheme.INK_SOFT))
	var version := UITheme.measured_label(
		"The Nine Lives of Ash — Chapter One", 22, UITheme.CONTENT_WIDTH,
		UITheme.body_font(), UITheme.INK_FADED)
	holder.add_child(version)
	var back := UITheme.amber_button("Back to the night", 30)
	back.size_flags_vertical = Control.SIZE_SHRINK_END
	back.pressed.connect(func() -> void: closed.emit())
	holder.add_child(back)


# -------------------------------------------------------------------- rows

## One settings row: torn plate, cropped icon, name, felt toggle. The whole
## plate is the tap target, not just the switch.
func _toggle_row(key: String, name_text: String, icon_id: String) -> Control:
	var plate := _plate(name_text, icon_id)
	var body: HBoxContainer = plate.get_meta("body")
	# The word goes BEFORE the switch: at the far right it landed on the
	# plate's corner sprig and read as ink over leaves. The switch is opaque
	# felt, so it is the one that can afford to sit on the decoration.
	var word := UITheme.measured_label("", 26, VALUE_WIDTH,
		UITheme.smallcaps_font())
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.size_flags_vertical = Control.SIZE_FILL
	body.add_child(word)
	_toggle_word[key] = word
	var art := TextureRect.new()
	art.custom_minimum_size = TOGGLE_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(art)
	_toggle_art[key] = art
	_refresh_toggle(key)
	UITheme.tap_layer(plate).pressed.connect(_on_toggle.bind(key))
	return plate


## A row that reports a value it cannot change (see _build_rows).
func _value_row(name_text: String, icon_id: String, value: String) -> Control:
	var plate := _plate(name_text, icon_id)
	var body: HBoxContainer = plate.get_meta("body")
	var label := UITheme.measured_label(value, 28, TOGGLE_SIZE.x,
		UITheme.body_font(), UITheme.INK_SOFT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	body.add_child(label)
	# Holds the value clear of the plate's corner sprig, where the toggle rows
	# put their switch. Rows have to line up down the page.
	var gutter := Control.new()
	gutter.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(gutter)
	return plate


## Shared plate: the torn row art with an icon and a name already in it. The
## caller adds whatever sits on the right into `body`.
func _plate(name_text: String, icon_id: String) -> Panel:
	var plate := Panel.new()
	plate.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	plate.add_theme_stylebox_override("panel", UITheme.row_stylebox())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", ROW_ITEM_SEPARATION)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = ROW_INSET
	body.offset_right = -ROW_INSET
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(body)
	body.add_child(UITheme.icon(icon_id, ICON_BOX))
	var label := UITheme.measured_label(name_text, 30, NAME_WRAP,
		UITheme.display_font())
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(label)
	plate.set_meta("body", body)
	return plate


# -------------------------------------------------------------------- book

## The book row: _value_row's shape — icon, name, one word, then the gutter
## that holds the word clear of the plate's corner sprig — with a tap layer
## over the whole plate. Built FROM _value_row rather than beside it, which is
## also why _value_row survives its only other caller (the Language row) being
## cut: the gutter is a measurement, and re-deriving it here would be the same
## measurement written twice.
##
## Twice-learnt, both times here: a word at the far right lands ON the sprig
## and reads as ink over leaves (the switch is opaque felt and is the only
## thing that can afford to sit there), and a SENTENCE in this slot wraps out
## the bottom of a 101px plate and across the Loudness heading. One word, in
## the gutter's lane.
func _book_row() -> Control:
	var plate := _value_row(Strings.line("book.heading"), "ui/ui_seal_red",
		Strings.line("book.row_action"))
	# The row opens the panel even with no book behind it. A dead plate tells
	# the player nothing; the panel can say WHY there is nothing to turn back
	# to, which is the only useful thing to say about a throwaway copy.
	UITheme.tap_layer(plate).pressed.connect(func() -> void:
		UITheme.open_modal(_book["overlay"], _book["panel"]))
	return plate


## What the player may do to their save, said plainly. There is no save
## button here and there is not going to be one: the point of the design is
## that the player does not choose the moment, so a night cannot be tried,
## judged, and rolled back.
func _build_book_panel() -> void:
	_book = UITheme.modal(self)
	var box: VBoxContainer = _book["box"]
	box.add_child(UITheme.measured_label(Strings.line("book.heading"),
		UITheme.TYPE_HEADING, MODAL_TEXT_WIDTH, UITheme.display_font()))
	_book_note = UITheme.measured_label(Strings.line("book.kept"),
		UITheme.TYPE_SUPPORT, MODAL_TEXT_WIDTH, UITheme.body_font(),
		UITheme.INK_SOFT)
	box.add_child(_book_note)
	var revert := UITheme.amber_button(Strings.line("book.revert"),
		UITheme.TYPE_BODY)
	revert.pressed.connect(_ask.bind("revert"))
	box.add_child(revert)
	_book_actions.append(revert)
	var close_book := UITheme.amber_button(Strings.line("book.close"),
		UITheme.TYPE_BODY)
	close_book.pressed.connect(_ask.bind("close"))
	box.add_child(close_book)
	_book_actions.append(close_book)
	_refresh_book()
	var stay := UITheme.dark_button(Strings.line("book.revert_cancel"),
		UITheme.TYPE_SUPPORT)
	stay.pressed.connect(func() -> void:
		UITheme.close_modal(_book["overlay"], _book["panel"]))
	box.add_child(stay)
	UITheme.modal_escape(_book, func() -> void:
		UITheme.close_modal(_book["overlay"], _book["panel"]))


## One confirm panel, relabelled for whichever action asked for it. Both
## actions throw away work in progress, and both say exactly what goes.
func _build_confirm_panel() -> void:
	_confirm = UITheme.modal(self)
	var box: VBoxContainer = _confirm["box"]
	var heading := UITheme.measured_label("", UITheme.TYPE_HEADING,
		MODAL_TEXT_WIDTH, UITheme.display_font())
	heading.name = "ConfirmHeading"
	box.add_child(heading)
	for i in CONFIRM_BODY_LINES:
		var line := UITheme.measured_label("", UITheme.TYPE_SUPPORT,
			MODAL_TEXT_WIDTH, UITheme.body_font(), UITheme.INK_SOFT)
		line.name = "ConfirmBody%d" % i
		box.add_child(line)
	var yes := UITheme.amber_button("", UITheme.TYPE_BODY)
	yes.name = "ConfirmYes"
	yes.pressed.connect(_confirmed)
	box.add_child(yes)
	var no := UITheme.dark_button(Strings.line("book.revert_cancel"),
		UITheme.TYPE_SUPPORT)
	no.pressed.connect(_dismiss_confirm)
	box.add_child(no)
	UITheme.modal_escape(_confirm, _dismiss_confirm)


## Whether there is a book behind this session, told from the outside.
## game.gd knows (it owns `active_slot`); this page only draws the answer.
## Called whenever a book is opened, started, reverted or closed.
func set_book_live(live: bool) -> void:
	if book_live == live:
		return
	book_live = live
	_refresh_book()


## The note is REMEASURED, not just retexted. Reserving the taller of the two
## paragraphs kept the panel a fixed height but left a hand's width of gap
## under the short one; the panel is a modal that pops fresh on every open, so
## a different height between two separate openings costs nothing (law 5 is
## about a box smaller than its text, and this is the other direction).
func _refresh_book() -> void:
	if _book_note == null:
		return
	var text := Strings.line("book.kept" if book_live else "book.unavailable")
	_book_note.text = text
	_book_note.custom_minimum_size = Vector2(MODAL_TEXT_WIDTH,
		UITheme.measure_text(text, UITheme.body_font(), UITheme.TYPE_SUPPORT,
			MODAL_TEXT_WIDTH).y)
	for button in _book_actions:
		button.disabled = not book_live


func _ask(action: String) -> void:
	_pending = action
	UITheme.close_modal(_book["overlay"], _book["panel"])
	var panel: Control = _confirm["panel"]
	var heading: Label = panel.find_child("ConfirmHeading", true, false)
	heading.text = Strings.line("book.%s_heading" % action)
	# The body is a BLOCK of lines: what happens, then what does not unhappen.
	# Fixed slots rather than built rows, so the panel never changes height
	# between the two actions (law 5 -- a container that resizes under a modal
	# is the too-small-bubble bug in another costume).
	var body: Array = Strings.lines("book.%s_body" % action)
	for i in CONFIRM_BODY_LINES:
		var line: Label = panel.find_child("ConfirmBody%d" % i, true, false)
		line.text = String(body[i]) if i < body.size() else ""
	var yes: Button = panel.find_child("ConfirmYes", true, false)
	yes.text = Strings.line("book.%s_confirm" % action)
	UITheme.open_modal(_confirm["overlay"], panel)


func _dismiss_confirm() -> void:
	UITheme.close_modal(_confirm["overlay"], _confirm["panel"])


func _confirmed() -> void:
	_dismiss_confirm()
	# The settings page closes itself on the way out: whatever happens next
	# swaps the screen underneath, and an overlay left visible over a fresh
	# Mantel would read as the game having ignored the tap.
	closed.emit()
	if _pending == "revert":
		revert_requested.emit()
	else:
		close_book_requested.emit()


# ----------------------------------------------------------------- changes

func _on_toggle(key: String) -> void:
	var now := not _is_on(key)
	settings[key] = now
	_refresh_toggle(key)
	setting_changed.emit(key, now)


func _on_volume_step(step: int) -> void:
	var value := float(step) / float(VOLUME_STEPS)
	# Tapping the paw you are already on turns it off — otherwise silence is
	# unreachable, since the first paw is 1/5 and not 0.
	if is_equal_approx(float(settings.get("volume", 1.0)), value):
		value = 0.0
	settings["volume"] = value
	_refresh_paws()
	setting_changed.emit("volume", value)


func _is_on(key: String) -> bool:
	return bool(settings.get(key, true))


func _refresh_toggle(key: String) -> void:
	var on := _is_on(key)
	var art: TextureRect = _toggle_art[key]
	art.texture = UITheme.cropped_tex(
		"ui/ui_toggle_on" if on else "ui/ui_toggle_off")
	var word: Label = _toggle_word[key]
	word.text = "ON" if on else "OFF"
	word.add_theme_color_override("font_color",
		Color("4a6a34") if on else Color("8a5a3a"))


func _refresh_paws() -> void:
	var lit := int(round(float(settings.get("volume", 1.0)) * VOLUME_STEPS))
	for i in _paws.size():
		_paws[i].texture = UITheme.cropped_tex(
			"ui/ui_paw_full" if i < lit else "ui/ui_paw_empty")
