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


static func load_profile() -> Dictionary:
	for path in [PROFILE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var parsed: Variant = JSON.parse_string(file.get_as_text())
				if parsed is Dictionary and parsed.has("schema_version"):
					return _migrate(parsed)
	return DEFAULT_PROFILE.duplicate(true)


static func save_profile(profile: Dictionary) -> void:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: cannot open temp save file")
		return
	file.store_string(JSON.stringify(profile, "\t"))
	file.close()
	var dir := DirAccess.open("user://")
	if FileAccess.file_exists(PROFILE_PATH):
		dir.copy(PROFILE_PATH, BACKUP_PATH)
	dir.rename(TEMP_PATH, PROFILE_PATH)


static func _migrate(profile: Dictionary) -> Dictionary:
	# One-step migration chain; never delete old migrators (tech-stack rules).
	var merged := DEFAULT_PROFILE.duplicate(true)
	merged.merge(profile, true)
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
