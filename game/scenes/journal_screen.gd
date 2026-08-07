extends Control
## The Casebook: Deeds (what you did, choices you made), Knowledge (what Ash
## has observed — creatures and places), and Lessons (every rule the game has
## ever taught, replayable on demand). Knowledge-as-progression per the
## influences research (Blue Prince verdict).
##
## LESSONS exist because a tutorial you can only ever see once is a tutorial
## you saw on the night you were not paying attention (owner rule
## 2026-08-04). Anything already met can be read again; anything with rules
## you learn with your paws re-opens the real screen on practice content.

signal closed
## Replay a lesson: game.gd owns the playing, because a practice lesson
## swaps screens and the Casebook must not be in the business of that.
signal replay_lesson(lesson_id: String)

var catalog: Catalog
var profile: Dictionary

var _deeds_button: Button
var _knowledge_button: Button
var _lessons_button: Button
var _scroll: ScrollContainer
var _list: VBoxContainer


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
	_deeds_button = Button.new()
	_deeds_button.text = "Deeds"
	_deeds_button.custom_minimum_size = Vector2(0, 96)
	_deeds_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deeds_button.pressed.connect(_show_deeds)
	tabs.add_child(_deeds_button)
	_knowledge_button = Button.new()
	_knowledge_button.text = "Knowledge"
	_knowledge_button.custom_minimum_size = Vector2(0, 96)
	_knowledge_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_knowledge_button.pressed.connect(_show_knowledge)
	tabs.add_child(_knowledge_button)
	_lessons_button = Button.new()
	_lessons_button.text = "Lessons"
	_lessons_button.custom_minimum_size = Vector2(0, 96)
	_lessons_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lessons_button.pressed.connect(_show_lessons)
	tabs.add_child(_lessons_button)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 18)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	_show_deeds()


## What Ash has done, newest first.
##
## The chronicle stores FACTS; the sentences are made here, now, from
## story/interface.json — which is why rewriting a line re-reads the whole
## history and why this screen is the layer that does it (core is not allowed
## to read the prose file).
##
## Saves written before v5 hold finished sentences with no facts behind them.
## Those are shown underneath rather than converted: guessing which enemy
## "Spent a life to the Chained Dog" referred to would be inventing a player's
## history, and a player's history is theirs.
func _show_deeds() -> void:
	_clear()
	var chronicle := Chronicle.from_list(profile.get("chronicle", []))
	var entries := chronicle.describe(catalog)
	var legacy: Array = profile.get("journal", [])
	if entries.is_empty() and legacy.is_empty():
		_entry("The pages are blank. For now.", true)
		return
	for entry in entries:
		_entry(Strings.line(String(entry["key"]), entry["args"]))
	if legacy.is_empty():
		return
	_heading("Earlier")
	for i in range(legacy.size() - 1, -1, -1):
		_entry(String(legacy[i]))


func _show_knowledge() -> void:
	_clear()
	var codex: Dictionary = profile.get("codex", {})
	_heading("Creatures")
	var enemies: Array = codex.get("enemies", [])
	if enemies.is_empty():
		_entry("Nothing observed yet. Observation is coming.", true)
	for enemy_id in enemies:
		if catalog.enemies.has(enemy_id):
			var enemy: Dictionary = catalog.enemies[enemy_id]
			_entry("%s — %s" % [enemy["name"], enemy.get("flavor", "")])
	_heading("Places")
	var places: Array = codex.get("places", [])
	if places.is_empty():
		_entry("Everywhere is still somewhere else.", true)
	for place_id in places:
		if catalog.environments.has(place_id):
			var place: Dictionary = catalog.environments[place_id]
			_entry("%s — %s" % [place["name"], place.get("rule_text", "")])


## Every lesson in the game, in teaching order. Ones already met are live;
## ones not met yet are listed but greyed — seeing that there IS a lesson
## about wards before you have met a ward is a promise, not a spoiler.
func _show_lessons() -> void:
	_clear()
	_heading("Lessons")
	var taught: Array = profile.get("taught", [])
	var ids: Array = catalog.lessons.keys()
	ids.sort_custom(func(a, b) -> bool:
		var left := int(catalog.lessons[a].get("order", 0))
		var right := int(catalog.lessons[b].get("order", 0))
		return left < right)
	for lesson_id in ids:
		var lesson: Dictionary = catalog.lessons[lesson_id]
		var met: bool = taught.has(lesson_id)
		# A PLAIN panel, not the sprigged note plate: that plate keeps printed
		# leaves in its outer 130px and a dashed rule 46px in, and a list row
		# laid out to the rect ran its title through both (owner tour,
		# 2026-08-04 — the same defect the Mantel's quest notes had).
		var pad := 22.0
		var wrap := float(UITheme.CONTENT_WIDTH) - pad * 2.0 - 32.0
		var title_text: String = String(lesson["name"])
		if String(lesson.get("kind", "")) == "practice" and met:
			title_text += "  ·  practise"
		var blurb_text: String = String(lesson.get("blurb", "")) if met else "Not yet met."
		# Law 2: measured, not guessed. A two-line lesson name is normal.
		var title_height := UITheme.measure_text(title_text,
			UITheme.display_font(), 28, wrap).y
		var blurb_height := UITheme.measure_text(blurb_text,
			UITheme.italic_font(), 20, wrap).y
		var height := title_height + blurb_height + pad * 2.0 + 4.0
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, maxf(96.0, height))
		row.disabled = not met
		row.add_theme_stylebox_override("normal", UITheme.panel_stylebox(int(pad)))
		row.add_theme_stylebox_override("hover", UITheme.panel_stylebox(int(pad)))
		row.add_theme_stylebox_override("pressed", UITheme.panel_stylebox(int(pad)))
		var faded := UITheme.panel_stylebox(int(pad))
		faded.bg_color = Color("efe0c2").darkened(0.06)
		faded.border_color = Color("4a3b2c") * Color(1, 1, 1, 0.4)
		row.add_theme_stylebox_override("disabled", faded)
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
		text.add_child(UITheme.measured_label(title_text, 28, wrap,
			UITheme.display_font(), UITheme.INK if met else UITheme.INK_FADED))
		text.add_child(UITheme.measured_label(blurb_text, 20, wrap,
			UITheme.italic_font(), UITheme.INK_SOFT))


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
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color",
		UITheme.INK_FADED if faded else UITheme.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(label)


func _clear() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
