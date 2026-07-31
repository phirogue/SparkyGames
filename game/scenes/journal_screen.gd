extends Control
## The Casebook: Deeds (what you did, choices you made) and Knowledge (what
## Ash has observed — creatures and places). Knowledge-as-progression per the
## influences research (Blue Prince verdict).

signal closed

var catalog: Catalog
var profile: Dictionary

var _deeds_button: Button
var _knowledge_button: Button
var _scroll: ScrollContainer
var _list: VBoxContainer


func setup(p_catalog: Catalog, p_profile: Dictionary) -> void:
	catalog = p_catalog
	profile = p_profile


func _ready() -> void:
	var page := Panel.new()
	page.add_theme_stylebox_override("panel", UITheme.page_stylebox())
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 52)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)
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

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 18)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	_show_deeds()


func _show_deeds() -> void:
	_clear()
	var journal: Array = profile.get("journal", [])
	if journal.is_empty():
		_entry("The pages are blank. For now.", true)
	for i in range(journal.size() - 1, -1, -1):
		_entry(String(journal[i]))


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
