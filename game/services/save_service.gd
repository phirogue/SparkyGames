class_name SaveService
extends RefCounted
## Persistent profile in user://. Versioned JSON, temp-file write with a
## rolling backup — per docs/design/tech-stack.md save rules.

const PROFILE_PATH := "user://profile.json"
const TEMP_PATH := "user://profile.tmp"
const BACKUP_PATH := "user://profile.bak"

const DEFAULT_PROFILE := {
	"schema_version": 2,
	"prologue_done": false,
	"gleam": 0,
	# Level-1 Ash (owner calibration 2026-08-01): 10 HP; growth comes as
	# mission rewards, never as visible numbers.
	"max_hp": 10,
	# Starter deck: 15 cards, ALL value 1 — potent 2s/3s are rewards, not
	# starting kit (owner rarity rule).
	"deck": [
		"ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1",
		"guile_1", "guile_1", "guile_1",
		"shadow_1", "shadow_1", "shadow_1", "shadow_1",
		"mysticism_1", "mysticism_1", "mysticism_1",
	],
	"skills": ["scratch"],
	"flags": {},
	"journal": [],
	"codex": { "enemies": [], "places": [] },
	"achievements": {},
	"settings": { "volume": 1.0 },
}

## Everything the prologue teaches; granted retroactively to saves that
## predate progressive skill unlocks.
const PROLOGUE_SKILLS := ["scratch", "pounce", "slink", "purr", "loaf"]


# Paths are parameters (defaulting to the real save) so tests can round-trip
# against scratch files without ever touching a player's profile.
static func load_profile(profile_path: String = PROFILE_PATH,
		backup_path: String = BACKUP_PATH) -> Dictionary:
	for path in [profile_path, backup_path]:
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var parsed: Variant = JSON.parse_string(file.get_as_text())
				if parsed is Dictionary and parsed.has("schema_version"):
					return _migrate(parsed)
	return DEFAULT_PROFILE.duplicate(true)


static func save_profile(profile: Dictionary,
		profile_path: String = PROFILE_PATH, temp_path: String = TEMP_PATH,
		backup_path: String = BACKUP_PATH) -> void:
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: cannot open temp save file")
		return
	file.store_string(JSON.stringify(profile, "\t"))
	file.close()
	var dir := DirAccess.open("user://")
	if FileAccess.file_exists(profile_path):
		var copy_err := dir.copy(profile_path, backup_path)
		if copy_err != OK:
			push_error("SaveService: backup copy failed (%d)" % copy_err)
	var rename_err := dir.rename(temp_path, profile_path)
	if rename_err != OK:
		push_error("SaveService: temp->profile rename failed (%d)" % rename_err)


static func _migrate(profile: Dictionary) -> Dictionary:
	# One-step migration chain; never delete old migrators (tech-stack rules).
	var merged := _deep_merge(DEFAULT_PROFILE.duplicate(true), profile)
	# Pre-skill-unlock saves: a finished prologue implies its skill grants.
	if merged["prologue_done"] and merged["skills"].size() <= 1:
		merged["skills"] = PROLOGUE_SKILLS.duplicate()
	# 2026-08-01 energy rename: moonlight became mysticism (the wild).
	var migrated_deck: Array = []
	for card_id in merged["deck"]:
		migrated_deck.append(String(card_id).replace("moonlight", "mysticism"))
	merged["deck"] = migrated_deck
	# v2 (2026-08-02): the level-1 recalibration. Old saves carried 20 HP
	# and potent starter cards into a 10-HP, all-1s world.
	if int(profile.get("schema_version", 1)) < 2:
		merged["max_hp"] = mini(int(merged["max_hp"]), 10)
		merged["deck"] = DEFAULT_PROFILE["deck"].duplicate()
		merged["schema_version"] = 2
	return merged


## Recursive merge: the save's values win, but NESTED dictionaries merge
## key-by-key instead of replacing the default wholesale. A shallow
## Dictionary.merge() meant any NEW nested default (a codex list, a settings
## key) would never reach existing saves — the law-7 failure mode.
static func _deep_merge(base: Dictionary, override: Dictionary) -> Dictionary:
	for key in override:
		if base.get(key) is Dictionary and override[key] is Dictionary:
			base[key] = _deep_merge(base[key], override[key])
		else:
			base[key] = override[key]
	return base
