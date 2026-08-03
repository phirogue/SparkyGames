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

var energy_cards: Dictionary = {}   # id -> {id, humour, value}
var skills: Dictionary = {}         # id -> {id, name, cost, charges, effects, instinct}
var enemies: Dictionary = {}        # id -> {id, name, hp, intents}
var encounters: Dictionary = {}     # id -> {id, enemies, environment}
var achievements: Dictionary = {}   # id -> {id, name, description, stat, threshold, hidden}
var environments: Dictionary = {}   # id -> {id, name, color, cost_mod, sunbeam_turns, stealth_threshold}
var quests: Dictionary = {}         # id -> {id, name, board_card, encounters, reward_bonus, repeatable}

func _init(data: Dictionary = {}) -> void:
	energy_cards = data.get("energy_cards", {})
	skills = data.get("skills", {})
	enemies = data.get("enemies", {})
	encounters = data.get("encounters", {})
	achievements = data.get("achievements", {})
	environments = data.get("environments", {})
	quests = data.get("quests", {})

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
	return problems
