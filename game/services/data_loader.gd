class_name DataLoader
extends RefCounted
## The only place that reads content JSON from disk. Core stays pure: it
## receives a built Catalog and never touches FileAccess.

const DATA_DIR := "res://data"
const WORLD_DIR := "res://story/world"

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
		"lessons": _load_json(data_dir + "/lessons.json").get("lessons", {}),
		# The tuning dials. Unlike the content files this one is a nested
		# config rather than an id->record map, and every key has a shipped
		# default in Rules.DEFAULTS — so a missing or half-written rules.json
		# degrades to the shipped balance instead of to an unplayable game.
		"rules": _load_json(data_dir + "/rules.json"),
		# Worldbuilding the game itself reads. Canon that content REFERENCES by
		# id (districts, the humours' meaning, the factions) has to be checkable
		# against the ids that reference it — prose in a design doc cannot be.
		"world": _load_world(),
	})


## story/world/*.json, merged into one dictionary keyed by filename stem.
## Missing entirely is not fatal: the world is reference material, and a game
## that cannot show a district's blurb is still a game.
static func _load_world(world_dir: String = WORLD_DIR) -> Dictionary:
	var world := {}
	for file_name in DirAccess.get_files_at(world_dir):
		var name := String(file_name).trim_suffix(".remap")
		if not name.ends_with(".json") or name == "index.json":
			continue
		world[name.trim_suffix(".json")] = _load_json("%s/%s" % [world_dir, name])
	return world


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
	# Keys starting with "_" are notes to whoever edits the file next, not
	# content. JSON has no comments and these files carry real design
	# reasoning that belongs beside the data — but a flat id->record file
	# turns a stray "_notes" into a phantom record, which is exactly how the
	# Chapter 1 board came up empty (an Array where a quest was expected took
	# the whole catalog down with it). Stripped once, here, for every file.
	var content := {}
	for key in parsed:
		if not String(key).begins_with("_"):
			content[key] = parsed[key]
	return content
