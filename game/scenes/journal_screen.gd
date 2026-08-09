extends Control
## The Casebook: Deeds (Ash's own journal of what he did), Knowledge (what he
## has observed — creatures and places, each opening as a full card), and
## Lessons (every rule the game has taught, replayable on demand).
## Knowledge-as-progression per the influences research (Blue Prince verdict).
##
## Owner 2026-08-09 pass: the Knowledge list carries a NAME and one short
## line only — the full text belongs to the card popup, which shows the whole
## image uncropped. Places are cards too, behind a creatures/places toggle.
## Lessons not yet met are not listed at all. Deeds reads as a journal in
## Ash's voice (the sentences live in story/interface.json chronicle_log).

signal closed
## Replay a lesson: game.gd owns the playing, because a practice lesson
## swaps screens and the Casebook must not be in the business of that.
signal replay_lesson(lesson_id: String)

var catalog: Catalog
var profile: Dictionary
## Which tab opens first. game.gd sets "lessons" when returning from a
## replayed lesson, so the player lands back where they were (owner
## 2026-08-09), not on Deeds.
var initial_tab := "deeds"

var _deeds_button: Button
var _knowledge_button: Button
var _lessons_button: Button
var _scroll: ScrollContainer
var _list: VBoxContainer
var _knowledge_kind := "creatures"
var _card_modal: Dictionary = {}
var _card_box: VBoxContainer

const CARD_PANEL_WIDTH := 620.0
const CARD_WRAP := CARD_PANEL_WIDTH - 32.0

## The selected tab plate: dark ink with cream text (owner 2026-08-09 — the
## old parchment-on-parchment selection read as the label "turning white"
## through the theme's pressed state). Hover always mirrors the resting
## state: mobile game, only clicks are registered.
const TAB_DARK := Color("3a3126")
const TAB_DARK_BORDER := Color("1a1710")
const TAB_CREAM := Color("e8e4d8")


func setup(p_catalog: Catalog, p_profile: Dictionary) -> void:
	catalog = p_catalog
	profile = p_profile


func _ready() -> void:
	var margin := UITheme.page_scaffold(self)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	box.add_child(header)
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
	var title := Label.new()
	title.text = "The Casebook"
	title.add_theme_font_override("font", UITheme.display_font())
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", UITheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	box.add_child(tabs)
	_deeds_button = _tab_button("Deeds", 96, _show_deeds)
	tabs.add_child(_deeds_button)
	_knowledge_button = _tab_button("Knowledge", 96, _show_knowledge)
	tabs.add_child(_knowledge_button)
	_lessons_button = _tab_button("Lessons", 96, _show_lessons)
	tabs.add_child(_lessons_button)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 18)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	_card_modal = UITheme.modal(self, CARD_PANEL_WIDTH)
	UITheme.modal_escape(_card_modal, _close_card)
	_card_box = _card_modal["box"]

	match initial_tab:
		"lessons": _show_lessons()
		"knowledge": _show_knowledge()
		_: _show_deeds()


func _tab_button(text: String, height: float, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", UITheme.smallcaps_font())
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(on_pressed)
	return button


## Paint one tab (or kind-toggle) as chosen or resting: dark plate + cream
## text when chosen, parchment + soft ink at rest — two signals, neither
## subtle, and every colour state pinned so nothing flashes white.
func _paint_toggle(button: Button, selected: bool) -> void:
	var text_color: Color = TAB_CREAM if selected else UITheme.INK_SOFT
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		button.add_theme_color_override(state, text_color)
	var plate := UITheme.panel_stylebox(8)
	if selected:
		plate.bg_color = TAB_DARK
		plate.border_color = TAB_DARK_BORDER
		plate.set_border_width_all(3)
	else:
		plate.bg_color = Color("efe0c2").darkened(0.08)
		plate.border_color = Color("4a3b2c") * Color(1, 1, 1, 0.35)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, plate)


func _select_tab(chosen: Button) -> void:
	for button in [_deeds_button, _knowledge_button, _lessons_button]:
		if button != null:
			_paint_toggle(button, button == chosen)


# ------------------------------------------------------------------- deeds

## Ash's own journal, newest first. The chronicle stores FACTS; the
## first-person sentences are made here, now, from story/interface.json —
## rewriting a line there re-reads the whole history.
##
## Saves written before v5 hold finished sentences with no facts behind them.
## Those are shown underneath rather than converted: guessing at the facts
## would be inventing a player's history, and a player's history is theirs.
func _show_deeds() -> void:
	_select_tab(_deeds_button)
	_clear()
	var chronicle := Chronicle.from_list(profile.get("chronicle", []))
	var entries := chronicle.describe(catalog)
	var legacy: Array = profile.get("journal", [])
	if entries.is_empty() and legacy.is_empty():
		_entry(Strings.line("codex.deeds_empty"), true)
		return
	for entry in entries:
		_entry(Strings.line(String(entry["key"]), entry["args"]))
	if legacy.is_empty():
		return
	_heading(Strings.line("codex.earlier"))
	for i in range(legacy.size() - 1, -1, -1):
		_entry(String(legacy[i]))


# --------------------------------------------------------------- knowledge

## Creatures or places, the player's choice (owner 2026-08-09). Both kinds
## list a name and ONE line; everything else waits in the card.
func _show_knowledge() -> void:
	_select_tab(_knowledge_button)
	_clear()
	var toggle := HBoxContainer.new()
	toggle.add_theme_constant_override("separation", 12)
	_list.add_child(toggle)
	var creatures := _tab_button(Strings.line("codex.explore_creatures"), 76,
		func() -> void:
			_knowledge_kind = "creatures"
			_show_knowledge())
	_paint_toggle(creatures, _knowledge_kind == "creatures")
	toggle.add_child(creatures)
	var places := _tab_button(Strings.line("codex.explore_places"), 76,
		func() -> void:
			_knowledge_kind = "places"
			_show_knowledge())
	_paint_toggle(places, _knowledge_kind == "places")
	toggle.add_child(places)
	var codex: Dictionary = profile.get("codex", {})
	if _knowledge_kind == "places":
		var place_ids: Array = codex.get("places", [])
		if place_ids.is_empty():
			_entry(Strings.line("codex.places_empty"), true)
		for place_id in place_ids:
			if catalog.environments.has(place_id):
				var place: Dictionary = catalog.environments[place_id]
				_list.add_child(_codex_row(String(place.get("image", "")),
					String(place["name"]), String(place.get("codex_line", "")),
					_show_place_card.bind(String(place_id))))
	else:
		var enemy_ids: Array = codex.get("enemies", [])
		if enemy_ids.is_empty():
			_entry(Strings.line("codex.creatures_empty"), true)
		for enemy_id in enemy_ids:
			if catalog.enemies.has(enemy_id):
				var enemy: Dictionary = catalog.enemies[enemy_id]
				_list.add_child(_codex_row(String(enemy.get("image", "")),
					String(enemy.get("display_name", enemy["name"])).replace("\n", " "),
					String(enemy.get("codex_line", "")),
					_show_creature_card.bind(String(enemy_id))))


## One thing observed: its picture, its name at reading size, one line under
## it. The row is the invitation; the card is the entry.
func _codex_row(art_id: String, name_text: String, line_text: String,
		on_tap: Callable) -> Control:
	var pad := 18.0
	var art_size := 110.0
	var wrap := float(UITheme.CONTENT_WIDTH) - pad * 2.0 - art_size - 44.0
	var height := UITheme.measure_text(name_text, UITheme.display_font(), 30, wrap).y \
		+ UITheme.measure_text(line_text, UITheme.italic_font(), 24, wrap).y \
		+ pad * 2.0 + 4.0
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, maxf(art_size + pad * 2.0, height))
	row.add_theme_stylebox_override("normal", UITheme.panel_stylebox(int(pad)))
	row.add_theme_stylebox_override("hover", UITheme.panel_stylebox(int(pad)))
	row.add_theme_stylebox_override("pressed", UITheme.panel_stylebox(int(pad)))
	row.pressed.connect(on_tap)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = pad
	line.offset_right = -pad
	line.offset_top = pad
	line.offset_bottom = -pad
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var art := UITheme.art_or_placeholder(art_id, name_text)
	art.custom_minimum_size = Vector2(art_size, art_size)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(art)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(text)
	text.add_child(UITheme.measured_label(name_text, 30, wrap,
		UITheme.display_font()))
	if line_text != "":
		text.add_child(UITheme.measured_label(line_text, 24, wrap,
			UITheme.italic_font(), UITheme.INK_SOFT))
	return row


# ------------------------------------------------------------------- cards

## The full creature card: the WHOLE picture (contained, never cropped —
## owner 2026-08-09), what it is, and what it does in a fight — read from the
## SAME intent data the battle screen telegraphs, so the Casebook can never
## describe a creature the game no longer has.
func _show_creature_card(enemy_id: String) -> void:
	var enemy: Dictionary = catalog.enemies[enemy_id]
	_clear_card()
	_card_art(String(enemy.get("image", "")), String(enemy["name"]), 440.0)
	_card_box.add_child(UITheme.measured_label(
		String(enemy.get("display_name", enemy["name"])).replace("\n", " "),
		38, CARD_WRAP, UITheme.display_font()))
	_card_box.add_child(UITheme.measured_label(
		String(enemy.get("codex", enemy.get("flavor", ""))), 26, CARD_WRAP,
		UITheme.italic_font(), UITheme.INK_SOFT))
	_card_box.add_child(UITheme.measured_label(
		Strings.line("codex.threads", [int(enemy.get("hp", 0))]), 26, CARD_WRAP,
		UITheme.smallcaps_font(), UITheme.ACCENT_WARM))
	for intent in enemy.get("intents", []):
		var target := String(intent.get("target", ""))
		var amount := int(intent.get("amount", 0))
		var what := Strings.line("codex.target." + target) if Strings.has(
			"codex.target." + target) else target
		var move := "%s — %s" % [String(intent.get("name", "?")),
			what if amount <= 0 else "%s, %d" % [what, amount]]
		_card_box.add_child(UITheme.measured_label("· " + move, 26, CARD_WRAP,
			UITheme.body_font(), UITheme.INK))
	_card_close_button()
	UITheme.open_modal(_card_modal["overlay"], _card_modal["panel"])


## A place card: the whole backdrop, what Ash makes of it, and the table
## rule it plays by (rule_text — the same line the battle header shows).
func _show_place_card(place_id: String) -> void:
	var place: Dictionary = catalog.environments[place_id]
	_clear_card()
	_card_art(String(place.get("image", "")), String(place["name"]), 380.0)
	_card_box.add_child(UITheme.measured_label(String(place["name"]), 38,
		CARD_WRAP, UITheme.display_font()))
	_card_box.add_child(UITheme.measured_label(String(place.get("codex", "")),
		26, CARD_WRAP, UITheme.italic_font(), UITheme.INK_SOFT))
	var rule := String(place.get("rule_text", ""))
	if rule != "":
		_card_box.add_child(UITheme.measured_label(rule, 26, CARD_WRAP,
			UITheme.smallcaps_font(), UITheme.ACCENT_WARM))
	_card_close_button()
	UITheme.open_modal(_card_modal["overlay"], _card_modal["panel"])


## The picture, CONTAINED: scaled to fit the frame whole, parchment showing
## around whatever the aspect leaves over — never cropped to fill.
func _card_art(art_id: String, description: String, height: float) -> void:
	var texture := UITheme.tex(art_id)
	if texture == null:
		var placeholder := UITheme.art_or_placeholder(art_id, description)
		placeholder.custom_minimum_size = Vector2(CARD_WRAP, height)
		_card_box.add_child(placeholder)
		return
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(CARD_WRAP, height)
	_card_box.add_child(art)


func _card_close_button() -> void:
	var close := UITheme.amber_button(Strings.line("codex.close"), 28,
		Vector2(260, 84))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close_card)
	_card_box.add_child(close)


func _clear_card() -> void:
	for child in _card_box.get_children():
		_card_box.remove_child(child)
		child.queue_free()


func _close_card() -> void:
	UITheme.close_modal(_card_modal["overlay"], _card_modal["panel"])


# ----------------------------------------------------------------- lessons

## Lessons already met, in teaching order. Ones not met yet are NOT listed
## (owner 2026-08-09) — the promise of more belongs to play, not to a grey
## row the player cannot open.
func _show_lessons() -> void:
	_select_tab(_lessons_button)
	_clear()
	_heading("Lessons")
	var taught: Array = profile.get("taught", [])
	var ids: Array = catalog.lessons.keys()
	ids.sort_custom(func(a, b) -> bool:
		var left := int(catalog.lessons[a].get("order", 0))
		var right := int(catalog.lessons[b].get("order", 0))
		return left < right)
	var met_any := false
	for lesson_id in ids:
		if not taught.has(lesson_id):
			continue
		met_any = true
		var lesson: Dictionary = catalog.lessons[lesson_id]
		# A PLAIN panel, not the sprigged note plate: that plate keeps printed
		# leaves in its outer 130px and a list row laid out to the rect ran
		# its title through them (owner tour, 2026-08-04).
		var pad := 22.0
		var wrap := float(UITheme.CONTENT_WIDTH) - pad * 2.0 - 32.0
		var title_text: String = String(lesson["name"])
		if String(lesson.get("kind", "")) == "practice":
			title_text += "  ·  practise"
		var blurb_text: String = String(lesson.get("blurb", ""))
		# Law 2: measured, not guessed. A two-line lesson name is normal.
		var height := UITheme.measure_text(title_text,
				UITheme.display_font(), 32, wrap).y \
			+ UITheme.measure_text(blurb_text,
				UITheme.italic_font(), 24, wrap).y + pad * 2.0 + 4.0
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, maxf(96.0, height))
		row.add_theme_stylebox_override("normal", UITheme.panel_stylebox(int(pad)))
		row.add_theme_stylebox_override("hover", UITheme.panel_stylebox(int(pad)))
		row.add_theme_stylebox_override("pressed", UITheme.panel_stylebox(int(pad)))
		row.pressed.connect(func() -> void: replay_lesson.emit(lesson_id))
		_list.add_child(row)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 2)
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		text.offset_left = pad
		text.offset_right = -pad
		text.offset_top = pad
		text.offset_bottom = -pad
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text)
		text.add_child(UITheme.measured_label(title_text, 32, wrap,
			UITheme.display_font()))
		text.add_child(UITheme.measured_label(blurb_text, 24, wrap,
			UITheme.italic_font(), UITheme.INK_SOFT))
	if not met_any:
		_entry(Strings.line("codex.lessons_empty"), true)


# ----------------------------------------------------------------- helpers

func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UITheme.smallcaps_font())
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", UITheme.INK_SOFT)
	_list.add_child(label)


func _entry(text: String, faded := false) -> void:
	var label := Label.new()
	label.text = "✎ " + text if not faded else text
	label.add_theme_font_override("font", UITheme.italic_font())
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color",
		UITheme.INK_FADED if faded else UITheme.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(label)


func _clear() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
