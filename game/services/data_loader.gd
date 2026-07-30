class_name DataLoader
extends RefCounted
## The only place that reads content JSON from disk. Core stays pure: it
## receives a built Catalog and never touches FileAccess.

const DATA_DIR := "res://data"

static func load_catalog(data_dir: String = DATA_DIR) -> Catalog:
	return Catalog.new({
		"energy_cards": _load_json(data_dir + "/energy_cards.json"),
		"skills": _load_json(data_dir + "/skills.json"),
		"enemies": _load_json(data_dir + "/enemies.json"),
		"encounters": _load_json(data_dir + "/encounters.json"),
		"achievements": _load_json(data_dir + "/achievements.json"),
		"environments": _load_json(data_dir + "/environments.json"),
		"quests": _load_json(data_dir + "/quests.json"),
	})


static func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "missing data file: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert(parsed is Dictionary, "malformed JSON (expected object): %s" % path)
	return parsed
