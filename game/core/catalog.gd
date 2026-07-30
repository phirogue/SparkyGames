class_name Catalog
extends RefCounted
## Immutable content definitions, keyed by stable string id. Built from JSON
## by DataLoader (services layer); core never touches the filesystem.
##
## Humours (energy types): "ferocity", "guile", "shadow", "moonlight".

const HUMOURS: Array[String] = ["ferocity", "guile", "shadow", "moonlight"]

var energy_cards: Dictionary = {}   # id -> {id, humour, value}
var skills: Dictionary = {}         # id -> {id, name, cost, charges, effects, instinct}
var enemies: Dictionary = {}        # id -> {id, name, hp, intents}
var encounters: Dictionary = {}     # id -> {id, enemies, environment}

func _init(data: Dictionary = {}) -> void:
	energy_cards = data.get("energy_cards", {})
	skills = data.get("skills", {})
	enemies = data.get("enemies", {})
	encounters = data.get("encounters", {})

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
	for id in encounters:
		for enemy_id in encounters[id].get("enemies", []):
			if not enemies.has(enemy_id):
				problems.append("encounter '%s' references unknown enemy '%s'" % [id, enemy_id])
	return problems
