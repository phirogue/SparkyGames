extends Control
## Developer Mode — jump to any part of the game without playing to it.
##
##   godot --path game -- --scene dev
##
## Everything here is built FROM the catalog and the story file, so it can
## never go stale: add a story scene, an encounter, a quest or a puzzle and
## it appears in this list on the next launch with no code change.
##
## Dev mode is a throwaway world — nothing here reads or writes the real
## save, so jumping anywhere and quitting costs the player nothing.

signal jump(spec: String)

const SEPARATION := 10

var catalog: Catalog
var story: Dictionary = {}

var _list: VBoxContainer


func setup(p_catalog: Catalog, p_story: Dictionary) -> void:
	catalog = p_catalog
	story = p_story


func _ready() -> void:
	var margin := UITheme.page_scaffold(self)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)

	var title := UITheme.measured_label("Developer Mode", 42,
		UITheme.CONTENT_WIDTH, UITheme.display_font())
	column.add_child(title)
	var note := UITheme.measured_label(
		Strings.line("dev.blurb"),
		20, UITheme.CONTENT_WIDTH, UITheme.italic_font(), UITheme.INK_SOFT)
	column.add_child(note)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_build()


func _build() -> void:
	_heading("Screens")
	_entry("The Mantel (hub)", "hub")
	_entry("The Case Board", "case")
	_entry("The Magpie Exchange (with 60 gleam)", "exchange")
	_entry("On the Prowl (loadout, with every skill)", "loadout")
	_entry("Settings", "settings")
	_entry("The Casebook", "journal")
	_entry("The 'previously on' recap", "recap")
	_entry("Title card", "title")

	# Story beats, named from the scene data itself: the first line of each
	# scene is its own best label, so the list reads like the script.
	_heading("Story — the prologue, beat by beat")
	var scenes: Array = story.get("scenes", [])
	for i in scenes.size():
		var scene: Dictionary = scenes[i]
		_entry("%02d  %s" % [i, _scene_label(scene)], "story:%d" % i)

	_heading("Fights")
	for encounter_id in catalog.encounters:
		var encounter: Dictionary = catalog.encounters[encounter_id]
		var enemy_id: String = encounter.get("enemies", [""])[0]
		var enemy: Dictionary = catalog.enemies.get(enemy_id, {})
		_entry("%s  —  %s, %d hp" % [encounter.get("name", encounter_id),
			enemy.get("name", enemy_id), int(enemy.get("hp", 0))],
			"battle:%s" % encounter_id)

	_heading("Prowls")
	for quest_id in catalog.quests:
		var quest: Dictionary = catalog.quests[quest_id]
		_entry("%s  —  %d encounters" % [quest.get("name", quest_id),
			quest.get("encounters", []).size()], "quest:%s" % quest_id)

	_heading("Minigames — Seam & Stitch")
	for chart_id in catalog.stitch_charts:
		var chart: Dictionary = catalog.stitch_charts[chart_id]
		_entry("%s  —  %dx%d%s" % [chart.get("name", chart_id),
			int(chart.get("width", 0)), int(chart.get("height", 0)),
			", mirrored" if bool(chart.get("mirrored", false)) else ""],
			"stitch:%s" % chart_id)

	_heading("Minigames — Testimony")
	for testimony_id in catalog.testimonies:
		var testimony: Dictionary = catalog.testimonies[testimony_id]
		_entry("%s  —  %s" % [testimony.get("name", testimony_id),
			testimony.get("witness", {}).get("name", "?")],
			"testimony:%s" % testimony_id)

	_heading("Minigames — Patch the Ward")
	for ward_id in catalog.wards:
		var ward: Dictionary = catalog.wards[ward_id]
		_entry("%s  —  %d torn cells" % [ward.get("name", ward_id),
			ward.get("hole", []).size()], "ward:%s" % ward_id)

	_heading("Minigames — The Unpicking")
	for lattice_id in catalog.lattices:
		var lattice: Dictionary = catalog.lattices[lattice_id]
		_entry("%s  —  %d threads" % [lattice.get("name", lattice_id),
			lattice.get("threads", []).size()], "lattice:%s" % lattice_id)

	_heading("Minigames — The Long Way Round")
	for crossing_id in catalog.crossings:
		var crossing: Dictionary = catalog.crossings[crossing_id]
		_entry("%s  —  %d steps" % [crossing.get("name", crossing_id),
			int(crossing.get("length", 0))], "crossing:%s" % crossing_id)

	_heading("Player states (scenario specs)")
	for scenario_name in _scenario_names():
		_entry(scenario_name, "scenario:%s" % scenario_name)


## The first line of a story scene, trimmed — a scene's own words label it
## better than any id, and they cannot drift out of sync with the script.
func _scene_label(scene: Dictionary) -> String:
	var kind := String(scene.get("type", "story"))
	var lines: Array = scene.get("lines", [])
	var text := String(lines[0]) if not lines.is_empty() else ""
	if text.length() > 52:
		text = text.substr(0, 49) + "..."
	if text.is_empty():
		match kind:
			"battle": text = "fight: %s" % scene.get("encounter", "?")
			"title": text = "the title card"
			"hollow_court_if_died": text = "the Hollow Court, if he died"
			_: text = kind
	var marks := ""
	if scene.has("choices"):
		marks += "  [choice]"
	if kind == "battle":
		marks += "  [fight]"
	if kind == "flashback":
		marks += "  [flashback]"
	return text + marks


func _scenario_names() -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open("res://tests/scenarios")
	if dir == null:
		return names
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			names.append(file_name.get_basename())
	names.sort()
	return names


func _heading(text: String) -> void:
	var label := UITheme.measured_label(text, 26, UITheme.CONTENT_WIDTH,
		UITheme.smallcaps_font(), UITheme.ACCENT_WARM)
	label.custom_minimum_size.y += 14
	_list.add_child(label)


func _entry(label: String, spec: String) -> void:
	var button := Button.new()
	button.text = label
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 20)
	button.custom_minimum_size = Vector2(0, 60)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = spec
	button.pressed.connect(func() -> void: jump.emit(spec))
	_list.add_child(button)
