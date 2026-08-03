class_name Catalog
extends RefCounted
## Immutable content definitions, keyed by stable string id. Built from JSON
## by DataLoader (services layer); core never touches the filesystem.
##
## Humours (energy types): "ferocity", "guile", "shadow", "mysticism".

const HUMOURS: Array[String] = ["ferocity", "guile", "shadow", "mysticism"]

## Player-facing humour names. The fourth humour's DATA id stays "mysticism"
## (save-file stability) but its name is Moonlight again (owner, 2026-08-02).
## All UI goes through humour_name() — never .capitalize() on a humour id.
const HUMOUR_NAMES := {
	"ferocity": "Ferocity",
	"guile": "Guile",
	"shadow": "Shadow",
	"mysticism": "Moonlight",
}

static func humour_name(humour: String) -> String:
	return HUMOUR_NAMES.get(humour, String(humour).capitalize())

## The city's districts. Quests name one; a typo here would silently orphan
## a quest from its region rules, so the canon list (world-bible.md) is a
## const the validator checks against.
const DISTRICTS: Array[String] = [
	"thimblefield", "wickrow", "shambles", "gravamen", "mereside",
]

## Quest kinds: "core" quests are the case's spine, "side" is everything else.
const QUEST_KINDS: Array[String] = ["core", "side"]

## A lead's recap line shares one story page with two other lines and a
## fixed-size illustration. Measured against the story screen's text budget:
## ~70 characters is two wrapped lines at 37px, which fits; more does not.
const RECAP_LINE_MAX := 70

var energy_cards: Dictionary = {}   # id -> {id, humour, value}
var skills: Dictionary = {}         # id -> {id, name, cost, charges, effects, instinct}
var enemies: Dictionary = {}        # id -> {id, name, hp, intents}
var encounters: Dictionary = {}     # id -> {id, enemies, environment}
var achievements: Dictionary = {}   # id -> {id, name, description, stat, threshold, hidden}
var environments: Dictionary = {}   # id -> {id, name, color, cost_mod, sunbeam_turns, stealth_threshold}
var quests: Dictionary = {}         # id -> {id, name, board_card, encounters, kind, guild, district, once, requires}
var cases: Dictionary = {}          # id -> {id, name, question, suspects, evidence, leads}
var guilds: Dictionary = {}         # id -> {id, name, neutral_line, notices}
var favors: Dictionary = {}         # id -> {id, name, guild, flavor, redeem_lines}

func _init(data: Dictionary = {}) -> void:
	energy_cards = data.get("energy_cards", {})
	skills = data.get("skills", {})
	enemies = data.get("enemies", {})
	encounters = data.get("encounters", {})
	achievements = data.get("achievements", {})
	environments = data.get("environments", {})
	quests = data.get("quests", {})
	cases = data.get("cases", {})
	guilds = data.get("guilds", {})
	favors = data.get("favors", {})


## Every evidence id defined by any case — quest gates reference these
## across files, so the cross-file check needs one flat set.
func evidence_ids() -> Dictionary:
	var ids := {}
	for case_id in cases:
		for entry in cases[case_id].get("evidence", []):
			ids[String(entry.get("id", ""))] = true
	return ids


func _lead_exists(lead_id: String) -> bool:
	for case_id in cases:
		for lead in cases[case_id].get("leads", []):
			if String(lead.get("id", "")) == lead_id:
				return true
	return false

## Returns a list of problems; empty list means the catalog is coherent.
func validate() -> Array[String]:
	var problems: Array[String] = []
	for id in energy_cards:
		var card: Dictionary = energy_cards[id]
		if not HUMOURS.has(card.get("humour", "")):
			problems.append("energy card '%s' has unknown humour '%s'" % [id, card.get("humour", "")])
		if int(card.get("value", 0)) < 1:
			problems.append("energy card '%s' has non-positive value" % id)
	for id in skills:
		var skill: Dictionary = skills[id]
		for humour in skill.get("cost", {}):
			if not HUMOURS.has(humour):
				problems.append("skill '%s' cost uses unknown humour '%s'" % [id, humour])
		if not skill.get("instinct", false) and int(skill.get("charges", 0)) < 1:
			problems.append("skill '%s' has no charges and is not an instinct" % id)
	for id in enemies:
		var enemy: Dictionary = enemies[id]
		if int(enemy.get("hp", 0)) < 1:
			problems.append("enemy '%s' has non-positive hp" % id)
		var intents: Array = enemy.get("intents", [])
		if intents.is_empty():
			problems.append("enemy '%s' has no intents" % id)
		for intent in intents:
			if not ["health", "skills", "hand"].has(intent.get("target", "")):
				problems.append("enemy '%s' intent targets unknown '%s'" % [id, intent.get("target", "")])
			var mode := String(intent.get("mode", ""))
			var legal_modes: Array = ["pierce"] if intent.get("target") == "health" \
				else ["jam", "burn"] if intent.get("target") == "skills" else []
			if mode != "" and not legal_modes.has(mode):
				problems.append("enemy '%s' intent '%s' has unknown mode '%s' for target '%s'" % [
					id, intent.get("name", "?"), mode, intent.get("target", "")])
	for id in encounters:
		for enemy_id in encounters[id].get("enemies", []):
			if not enemies.has(enemy_id):
				problems.append("encounter '%s' references unknown enemy '%s'" % [id, enemy_id])
		var environment_id: String = encounters[id].get("environment", "")
		if not environments.is_empty() and not environments.has(environment_id):
			problems.append("encounter '%s' references unknown environment '%s'" % [id, environment_id])
	for id in quests:
		var quest: Dictionary = quests[id]
		if quest.get("encounters", []).is_empty():
			problems.append("quest '%s' has no encounters" % id)
		for encounter_id in quest.get("encounters", []):
			if not encounters.has(encounter_id):
				problems.append("quest '%s' references unknown encounter '%s'" % [id, encounter_id])
		if String(quest.get("board_card", "")).is_empty():
			problems.append("quest '%s' has no board card text" % id)
		problems.append_array(_validate_quest_v2(id, quest))
	for id in achievements:
		var achievement: Dictionary = achievements[id]
		if String(achievement.get("name", "")).is_empty():
			problems.append("achievement '%s' has no name" % id)
		if String(achievement.get("description", "")).is_empty():
			problems.append("achievement '%s' has no description" % id)
		if String(achievement.get("stat", "")).is_empty():
			problems.append("achievement '%s' watches no stat" % id)
		if int(achievement.get("threshold", 0)) < 1:
			problems.append("achievement '%s' has a non-positive threshold" % id)
	problems.append_array(_validate_cases())
	problems.append_array(_validate_guilds())
	problems.append_array(_validate_favors())
	return problems


## Quest schema v2 (chapter1-build-plan Phase 1): kind/guild/district/once/
## requires. Gating is only trustworthy if the ids it names are real, so
## every reference is checked across files here rather than failing silently
## as a quest that can never appear on the board.
func _validate_quest_v2(id: String, quest: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var kind := String(quest.get("kind", ""))
	if not QUEST_KINDS.has(kind):
		problems.append("quest '%s' has unknown kind '%s'" % [id, kind])
	var district := String(quest.get("district", ""))
	if not DISTRICTS.has(district):
		problems.append("quest '%s' is in unknown district '%s'" % [id, district])
	var guild := String(quest.get("guild", ""))
	if guild != "" and not guilds.has(guild):
		problems.append("quest '%s' belongs to unknown guild '%s'" % [id, guild])
	for guild_id in quest.get("standing", {}):
		if not guilds.has(guild_id):
			problems.append("quest '%s' rewards standing with unknown guild '%s'" % [id, guild_id])
	if quest.has("grant_favor") and not favors.has(String(quest["grant_favor"])):
		problems.append("quest '%s' grants unknown favor '%s'" % [id, quest["grant_favor"]])
	var known_evidence := evidence_ids()
	for evidence_id in quest.get("grant_evidence", []):
		if not known_evidence.has(String(evidence_id)):
			problems.append("quest '%s' grants unknown evidence '%s'" % [id, evidence_id])
	if quest.has("lead") and not _lead_exists(String(quest["lead"])):
		problems.append("quest '%s' completes unknown lead '%s'" % [id, quest["lead"]])
	var requires: Dictionary = quest.get("requires", {})
	for evidence_id in requires.get("evidence", []):
		if not known_evidence.has(String(evidence_id)):
			problems.append("quest '%s' requires unknown evidence '%s'" % [id, evidence_id])
	for guild_id in requires.get("standing", {}):
		if not guilds.has(guild_id):
			problems.append("quest '%s' requires standing with unknown guild '%s'" % [id, guild_id])
	return problems


## The case file: every thread on the Case Board must have both ends. A lead
## pointing at evidence that does not exist is a lead the player can never
## finish, and it would render as a permanently empty pinned card.
func _validate_cases() -> Array[String]:
	var problems: Array[String] = []
	for case_id in cases:
		var case_def: Dictionary = cases[case_id]
		if String(case_def.get("question", "")).is_empty():
			problems.append("case '%s' has no question" % case_id)
		var evidence_by_id := {}
		for entry in case_def.get("evidence", []):
			evidence_by_id[String(entry.get("id", ""))] = entry
		var suspect_ids := {}
		for suspect in case_def.get("suspects", []):
			suspect_ids[String(suspect.get("id", ""))] = true
			if String(suspect.get("name", "")).is_empty():
				problems.append("case '%s' has a nameless suspect" % case_id)
		var lead_ids := {}
		for lead in case_def.get("leads", []):
			lead_ids[String(lead.get("id", ""))] = true
		for suspect in case_def.get("suspects", []):
			var by := String(suspect.get("revealed_by", "start"))
			if by != "start" and not evidence_by_id.has(by):
				problems.append("case '%s' suspect '%s' is revealed by unknown evidence '%s'" % [
					case_id, suspect.get("id", "?"), by])
		for entry in case_def.get("evidence", []):
			var entry_id := String(entry.get("id", ""))
			if String(entry.get("name", "")).is_empty():
				problems.append("case '%s' evidence '%s' has no name" % [case_id, entry_id])
			if String(entry.get("note", "")).is_empty():
				problems.append("case '%s' evidence '%s' has no note text" % [case_id, entry_id])
			if not lead_ids.has(String(entry.get("lead", ""))):
				problems.append("case '%s' evidence '%s' comes from unknown lead '%s'" % [
					case_id, entry_id, entry.get("lead", "")])
			for suspect_id in entry.get("implicates", []):
				if not suspect_ids.has(String(suspect_id)):
					problems.append("case '%s' evidence '%s' implicates unknown suspect '%s'" % [
						case_id, entry_id, suspect_id])
		for lead in case_def.get("leads", []):
			var lead_id := String(lead.get("id", ""))
			if String(lead.get("board_card", "")).is_empty():
				problems.append("case '%s' lead '%s' has no board card text" % [case_id, lead_id])
			# The recap card's text budget is fixed and the story screen
			# silently retires whatever overflows it, so an over-long recap
			# line does not look like a bug — it looks like a missing line.
			var recap := String(lead.get("recap_line", ""))
			if recap.is_empty():
				problems.append("case '%s' lead '%s' has no recap line" % [case_id, lead_id])
			elif recap.length() > RECAP_LINE_MAX:
				problems.append("case '%s' lead '%s' recap line is %d chars (max %d)" % [
					case_id, lead_id, recap.length(), RECAP_LINE_MAX])
			if not evidence_by_id.has(String(lead.get("evidence", ""))):
				problems.append("case '%s' lead '%s' yields unknown evidence '%s'" % [
					case_id, lead_id, lead.get("evidence", "")])
			for needed in lead.get("requires", []):
				if not evidence_by_id.has(String(needed)):
					problems.append("case '%s' lead '%s' requires unknown evidence '%s'" % [
						case_id, lead_id, needed])
	return problems


func _validate_guilds() -> Array[String]:
	var problems: Array[String] = []
	for id in guilds:
		var guild: Dictionary = guilds[id]
		if String(guild.get("name", "")).is_empty():
			problems.append("guild '%s' has no name" % id)
		if String(guild.get("neutral_line", "")).is_empty():
			problems.append("guild '%s' has no neutral line" % id)
		var seen := {}
		for notice in guild.get("notices", []):
			var at := int(notice.get("at", 0))
			if at == 0:
				problems.append("guild '%s' has a notice at neutral (0) — it would never fire" % id)
			if seen.has(at):
				problems.append("guild '%s' has two notices at %d" % [id, at])
			seen[at] = true
			if String(notice.get("text", "")).is_empty():
				problems.append("guild '%s' has an empty notice at %d" % [id, at])
	return problems


func _validate_favors() -> Array[String]:
	var problems: Array[String] = []
	for id in favors:
		var favor: Dictionary = favors[id]
		if String(favor.get("name", "")).is_empty():
			problems.append("favor '%s' has no name" % id)
		var guild := String(favor.get("guild", ""))
		if guild != "" and not guilds.has(guild):
			problems.append("favor '%s' is owed by unknown guild '%s'" % [id, guild])
		if favor.get("redeem_lines", []).is_empty():
			problems.append("favor '%s' has no redemption lines" % id)
	return problems
