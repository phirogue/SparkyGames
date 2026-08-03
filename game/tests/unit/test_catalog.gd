extends TestCase
## Content sanity: the shipped JSON must always validate.

func test_shipped_content_is_valid() -> void:
	var catalog := DataLoader.load_catalog()
	var problems := catalog.validate()
	assert_eq(problems.size(), 0, "catalog problems: %s" % str(problems))
	assert_true(catalog.energy_cards.size() >= 12, "expected the 12 starter energy cards")
	assert_true(catalog.skills.has("scratch"), "instinct 'scratch' must exist")
	assert_true(catalog.enemies.has("the_unpicked"), "prologue boss must exist")

func test_validation_catches_bad_content() -> void:
	var bad := Catalog.new({
		"energy_cards": {"x": {"id": "x", "humour": "cheese", "value": 0}},
		"skills": {"s": {"id": "s", "cost": {"cheese": 1}, "charges": 0}},
		"enemies": {"e": {"id": "e", "hp": 0, "intents": []}},
		"encounters": {"q": {"id": "q", "enemies": ["ghost_of_nobody"]}},
	})
	var problems := bad.validate()
	assert_true(problems.size() >= 6, "expected >=6 problems, got %d: %s" % [problems.size(), str(problems)])

## Every scenario spec must reference content that exists. A typo here is a
## launcher in play/apps/ that boots to a crash, which nobody notices until
## they reach for that part mid-playtest.
func test_scenario_specs_reference_real_content() -> void:
	var catalog := DataLoader.load_catalog()
	var dir := DirAccess.open("res://tests/scenarios")
	assert_true(dir != null, "tests/scenarios must be readable")
	if dir == null:
		return
	var checked := 0
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		checked += 1
		var path := "res://tests/scenarios/" + file_name
		var file := FileAccess.open(path, FileAccess.READ)
		var spec: Variant = null if file == null else JSON.parse_string(file.get_as_text())
		assert_true(spec is Dictionary, "%s must parse as an object" % file_name)
		if not (spec is Dictionary):
			continue
		var profile: Dictionary = spec.get("profile", {})
		for skill_id in profile.get("skills", []):
			assert_true(catalog.skills.has(skill_id),
				"%s owns unknown skill '%s'" % [file_name, skill_id])
		for skill_id in profile.get("loadout", []):
			assert_true(profile.get("skills", []).has(skill_id),
				"%s puts unowned '%s' in the loadout" % [file_name, skill_id])
		for card_id in profile.get("deck", []):
			assert_true(catalog.energy_cards.has(card_id),
				"%s has unknown energy card '%s'" % [file_name, card_id])
		for card_id in spec.get("carryover", {}).get("deck", []):
			assert_true(catalog.energy_cards.has(card_id),
				"%s carries unknown energy card '%s'" % [file_name, card_id])
		for evidence_id in profile.get("case", {}).get("evidence", []):
			assert_true(catalog.evidence_ids().has(evidence_id),
				"%s holds unknown evidence '%s'" % [file_name, evidence_id])
		for favor_id in profile.get("favors", []):
			assert_true(catalog.favors.has(favor_id),
				"%s holds unknown favor '%s'" % [file_name, favor_id])
		for guild_id in profile.get("standing", {}):
			assert_true(catalog.guilds.has(guild_id),
				"%s has standing with unknown guild '%s'" % [file_name, guild_id])
		var launch := String(spec.get("launch", "hub"))
		var parts := launch.split(":")
		match parts[0]:
			"battle":
				assert_true(catalog.encounters.has(parts[1]),
					"%s launches unknown encounter '%s'" % [file_name, parts[1]])
			"quest":
				assert_true(catalog.quests.has(parts[1]),
					"%s launches unknown quest '%s'" % [file_name, parts[1]])
			"hub", "title", "journal", "case", "recap", "story":
				pass
			_:
				assert_true(false, "%s has unknown launch '%s'" % [file_name, launch])
		for scene in spec.get("story", []):
			var environment_id := String(scene.get("environment", ""))
			if environment_id != "":
				assert_true(catalog.environments.has(environment_id),
					"%s scene uses unknown environment '%s'" % [file_name, environment_id])
			for favor_id in scene.get("grant_favor", []):
				assert_true(catalog.favors.has(favor_id),
					"%s scene grants unknown favor '%s'" % [file_name, favor_id])
			if scene.has("favor"):
				assert_true(catalog.favors.has(String(scene["favor"])),
					"%s scene redeems unknown favor '%s'" % [file_name, scene["favor"]])
			for evidence_id in scene.get("grant_evidence", []):
				assert_true(catalog.evidence_ids().has(evidence_id),
					"%s scene grants unknown evidence '%s'" % [file_name, evidence_id])
	assert_true(checked >= 8, "expected the shipped scenario specs, saw %d" % checked)
