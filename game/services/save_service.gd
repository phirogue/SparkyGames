class_name SaveService
extends RefCounted
## Persistent profile in user://. Versioned JSON, temp-file write with a
## rolling backup — per docs/design/tech-stack.md save rules.

const PROFILE_PATH := "user://profile.json"
const TEMP_PATH := "user://profile.tmp"
const BACKUP_PATH := "user://profile.bak"

const DEFAULT_PROFILE := {
	"schema_version": 4,
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
	# The player's chosen prowl loadout (non-Scratch skills, LOADOUT_SIZE - 1
	# of them). Empty means "auto": the first owned. Edited at the Mantel.
	"loadout": [],
	"flags": {},
	# Lessons already delivered (data/lessons.json). A lesson plays ONCE, at
	# the moment it first matters; the Casebook replays any of them on demand
	# forever after (owner rule 2026-08-04).
	"taught": [],
	"journal": [],
	"codex": { "enemies": [], "places": [] },
	"achievements": {},
	# Options (see scenes/settings_screen.gd). Old saves merge against these,
	# so a profile written before the settings page existed comes up with
	# sound on and the lamps normal (law 7).
	"settings": {
		"volume": 1.0,
		"sfx": true,
		"music": true,
		"lamps_low": false,     # the reading-in-the-dark dim overlay
		"ask_to_spend": false,  # confirm purchases at the Magpie Exchange
	},
	# --- chapter spine (v3, Chapter 1) ---
	# The open case and what has been proved. "active" points at a case id in
	# data/case.json; the prologue ends by pointing the thread into the city,
	# so Wax & Wick is open from the moment the Mantel is.
	"case": { "active": "wax_and_wick", "evidence": [], "leads_done": [] },
	# Guild standing: id -> int, negative means they remember and not fondly.
	"standing": {},
	# Favor-knots owed TO Ash (world-bible.md) — spending one unties it.
	"favors": [],
	# Quest ids completed at least once; what makes `once` quests stay done.
	"quests_done": [],
}

## Everything the prologue teaches; granted retroactively to saves that
## predate progressive skill unlocks.
const PROLOGUE_SKILLS := ["scratch", "pounce", "slink", "purr", "loaf"]

## The loadout law lives in core (Catalog.LOADOUT_SIZE) because it is a rule;
## this alias is the door every scene already knocks on. Raising it means
## re-checking battle.gd's tray width budget.
const LOADOUT_SIZE := Catalog.LOADOUT_SIZE


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
	# v3 (2026-08-03): the chapter spine (case / standing / favors /
	# quests_done). The deep merge supplies the new keys themselves; what the
	# migration owes is the law-7 question "what does an old save IMPLY?" —
	# a finished prologue implies the case is open, because the prologue's
	# last line already points the thread into the city. The guard also
	# repairs a save that stored an emptied "active" (no case = a Case Board
	# the player could never open again).
	if merged["prologue_done"] and String(merged["case"]["active"]).is_empty():
		merged["case"]["active"] = DEFAULT_PROFILE["case"]["active"]
	if int(profile.get("schema_version", 1)) < 3:
		merged["schema_version"] = 3
	# v4 (2026-08-04): lessons. Law 7 -- what does an old save IMPLY? A player
	# who has already finished the prologue has been taught the fight rules by
	# the coach and has been living at the Mantel; re-teaching them the basics
	# on their next launch would be the game forgetting who they are. Every
	# lesson stays available in the Casebook either way.
	if int(profile.get("schema_version", 1)) < 4:
		if merged["prologue_done"]:
			for lesson_id in IMPLIED_BY_PROLOGUE:
				if not merged["taught"].has(lesson_id):
					merged["taught"].append(lesson_id)
		merged["schema_version"] = 4
	return merged


## Lessons a finished prologue has effectively already delivered -- the ones
## the in-fight coach and the Mantel walkthrough already cover. Kept beside
## the migration that uses it so the two cannot drift apart.
const IMPLIED_BY_PROLOGUE := ["growing_stronger"]


## The skills that enter a battle (loadout law: LOADOUT_SIZE out at a time,
## Scratch included). The player's chosen loadout wins, filtered to what they
## still own; empty/invalid falls back to the first owned. Pure and static so
## tests can pin it without a scene tree.
static func battle_loadout(profile: Dictionary) -> Array:
	var owned: Array = profile.get("skills", [])
	var room := LOADOUT_SIZE - 1  # Scratch always holds the first slot
	var picked: Array = []
	for skill_id in profile.get("loadout", []):
		if picked.size() >= room:
			break
		if skill_id != "scratch" and owned.has(skill_id) and not picked.has(skill_id):
			picked.append(skill_id)
	if picked.is_empty():
		for skill_id in owned:
			if picked.size() >= room:
				break
			if skill_id != "scratch":
				picked.append(skill_id)
	return ["scratch"] + picked


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
