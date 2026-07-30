class_name SaveService
extends RefCounted
## Persistent profile in user://. Versioned JSON, temp-file write with a
## rolling backup — per docs/design/tech-stack.md save rules.

const PROFILE_PATH := "user://profile.json"
const TEMP_PATH := "user://profile.tmp"
const BACKUP_PATH := "user://profile.bak"

const DEFAULT_PROFILE := {
	"schema_version": 1,
	"prologue_done": false,
	"gleam": 0,
	"max_hp": 20,
	"deck": [
		"ferocity_1", "ferocity_1", "ferocity_2", "ferocity_2", "ferocity_3",
		"guile_1", "guile_1", "guile_2", "guile_2",
		"shadow_1", "shadow_1", "shadow_2", "shadow_3",
		"moonlight_1", "moonlight_1", "moonlight_2",
	],
	"achievements": {},
}


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
	# v1 is current — nothing to do yet.
	var merged := DEFAULT_PROFILE.duplicate(true)
	merged.merge(profile, true)
	return merged
