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
		"cases": _load_json(data_dir + "/case.json"),
		"guilds": _load_json(data_dir + "/guilds.json"),
		"favors": _load_json(data_dir + "/favors.json"),
		"stitch_charts": _load_json(data_dir + "/stitch_charts.json"),
		"testimonies": _load_json(data_dir + "/testimonies.json"),
		"wards": _load_json(data_dir + "/wards.json"),
		"lattices": _load_json(data_dir + "/lattices.json"),
		"crossings": _load_json(data_dir + "/crossings.json"),
	})


static func _load_json(path: String) -> Dictionary:
	# push_error, not assert: asserts compile out of release exports, and a
	# missing/corrupt bundled file on a phone must fail loudly and legibly
	# (game.gd surfaces catalog problems via Catalog.validate()), not
	# null-deref three calls later.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("missing data file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("malformed JSON (expected object): %s" % path)
		return {}
	return parsed
