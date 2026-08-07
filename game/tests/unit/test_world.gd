extends TestCase
## The worldbuilding files, and the story split.
##
## Hollowmere's canon used to live only in docs/design/world-bible.md — prose,
## invisible to every tool. That is fine for a setting nobody has to agree
## with, and this is not one: quests name districts, guilds carry standing, and
## the fourth humour has a data id that must never reach a player's eyes.
##
## So the parts of the world content REFERENCES are data now, and these tests
## are what make that worth doing: a district renamed in one place and not the
## other fails here rather than shipping as a quest that belongs to nowhere.

const STORY_DIR := "res://story/prologue"


func _catalog() -> Catalog:
	return DataLoader.load_catalog()


# ------------------------------------------------------------------- the world

func test_the_world_files_load() -> void:
	var world := _catalog().world
	for part in ["city", "weft", "factions"]:
		assert_true(world.has(part), "story/world/%s.json is loaded" % part)


func test_districts_agree_with_the_code() -> void:
	var districts: Dictionary = _catalog().world.get("city", {}).get("districts", {})
	assert_eq(districts.size(), Catalog.DISTRICTS.size(),
		"every district the code knows has an entry, and no more")
	for district_id in Catalog.DISTRICTS:
		assert_true(districts.has(district_id),
			"district '%s' is described in world/city.json" % district_id)
		assert_true(not String(districts.get(district_id, {}).get("name", "")).is_empty(),
			"district '%s' has a display name" % district_id)


func test_every_humour_is_described_and_named_correctly() -> void:
	var humours: Dictionary = _catalog().world.get("weft", {}).get("humours", {})
	for humour_id in Catalog.HUMOURS:
		assert_true(humours.has(humour_id),
			"humour '%s' is described in world/weft.json" % humour_id)
		assert_eq(String(humours.get(humour_id, {}).get("name", "")),
			Catalog.humour_name(humour_id),
			"world/weft.json calls '%s' what the player is shown" % humour_id)


## The Moonlight trap from a new direction. world/weft.json is where a writer
## would go to look up what the fourth humour is called, so it is the last
## place that should say "Mysticism" — and it necessarily mentions the data id
## in its own warning field, so only the player-facing fields are checked.
func test_the_world_never_shows_the_player_the_data_id() -> void:
	var world := _catalog().world
	for part in world:
		_no_data_id(world[part], "world/%s.json" % part)


func _no_data_id(node: Variant, where: String) -> void:
	const PLAYER_FACING := ["name", "blurb", "display_name", "rule_text"]
	if node is Dictionary:
		for key in node:
			if PLAYER_FACING.has(String(key)) and node[key] is String:
				assert_true(not String(node[key]).to_lower().contains("mysticism"),
					"%s shows the player 'Mysticism' in a %s field — it is Moonlight"
						% [where, key])
			_no_data_id(node[key], where)
	elif node is Array:
		for item in node:
			_no_data_id(item, where)


func test_factions_are_backed_by_real_guilds() -> void:
	var catalog := _catalog()
	var factions: Dictionary = catalog.world.get("factions", {}).get("factions", {})
	assert_true(not factions.is_empty(), "world/factions.json describes somebody")
	for faction_id in factions:
		assert_true(catalog.guilds.has(String(faction_id)),
			"faction '%s' is a guild the game can grant standing with" % faction_id)
		var district := String(factions[faction_id].get("district", ""))
		assert_true(district.is_empty() or Catalog.DISTRICTS.has(district),
			"faction '%s' is based in a real district (got '%s')" % [faction_id, district])


## The validator has to actually reject a mismatch, or it is decoration.
func test_a_mismatched_world_is_rejected() -> void:
	var broken := Catalog.new({
		"guilds": {"chandlers": {"name": "The Chandlers", "neutral_line": "-"}},
		"world": {
			"city": {"districts": {"atlantis": {"name": "Atlantis"}}},
			"weft": {"humours": {"ferocity": {"name": "Rage"}}},
			"factions": {"factions": {"nobody": {"name": "Nobody"}}},
		},
	})
	var joined := "\n".join(broken.validate())
	assert_true(joined.contains("atlantis"), "an invented district is caught")
	assert_true(joined.contains("thimblefield"), "a missing real district is caught")
	assert_true(joined.contains("Rage") or joined.contains("ferocity"),
		"a humour called the wrong thing is caught")
	assert_true(joined.contains("nobody"), "a faction with no guild behind it is caught")


# ------------------------------------------------------------- the story split

## The prologue is five arc files plus an index. Assembling it must produce one
## continuous book — an arc silently dropped would read as a story with an act
## cut out of it, and nothing else would complain.
func test_the_prologue_assembles_from_its_arcs() -> void:
	var story := StoryLoader.load_prologue(STORY_DIR)
	assert_true(not story.is_empty(), "story/prologue/ assembles")
	assert_true(Array(story.get("scenes", [])).size() >= 30,
		"the whole prologue is present, not one arc of it")
	for key in ["hollow_court_first", "hollow_court_repeat", "mantel_coach",
			"unpicked_won"]:
		assert_true(story.has(key), "interludes.json contributes '%s'" % key)


## Every arc named by the index must exist. A typo here is a hole in the middle
## of the story that only appears when a player walks into it.
func test_every_arc_the_index_names_exists() -> void:
	var index := _read(STORY_DIR + "/index.json")
	var arcs: Array = index.get("arcs", [])
	assert_true(arcs.size() >= 2, "the index names the arcs")
	for arc_file in arcs:
		var arc := _read("%s/%s" % [STORY_DIR, String(arc_file)])
		assert_true(not arc.is_empty(), "arc '%s' exists and parses" % arc_file)
		assert_true(not Array(arc.get("scenes", [])).is_empty(),
			"arc '%s' has scenes in it" % arc_file)
		assert_true(not String(arc.get("_arc", "")).is_empty(),
			"arc '%s' says what it is called" % arc_file)


## A missing arc must fail loudly rather than quietly playing a shorter game.
func test_a_missing_arc_is_not_silently_skipped() -> void:
	assert_true(StoryLoader.load_prologue("res://story/does_not_exist").is_empty(),
		"an unreadable story directory yields nothing, not a partial book")


## Scene indices are what `--scene story:<n>` takes, so being able to say where
## index 19 actually IS keeps a bug report legible after the split.
func test_a_scene_index_can_be_located_in_its_arc() -> void:
	var where := StoryLoader.locate(STORY_DIR, 0)
	assert_true(not where.is_empty(), "scene 0 is somewhere")
	assert_eq(int(where.get("beat", -1)), 0, "scene 0 is the first beat of its arc")
	var late := StoryLoader.locate(STORY_DIR, 30)
	assert_true(not late.is_empty(), "a late scene is located too")
	assert_true(not String(late.get("title", "")).is_empty(),
		"the location names an arc a person can open")


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
