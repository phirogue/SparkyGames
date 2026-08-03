extends SceneTree
## Writes docs/design/bestiary.md — every enemy's numbers, the actions they
## have to play, and the strategy those actions add up to.
##
##   godot --headless --path game -s tests/bestiary.gd
##
## GENERATED, never hand-edited: the point is that it cannot drift from
## enemies.json. Re-run it after any enemy change (the /simbalance skill and
## law 8 already say to re-run the sim; this is the same reflex).
##
## A note on "energy deck": enemies do not hold one. The player's deck is the
## game's clock and the enemy's pressure is its intent cycle — so what this
## file documents per enemy is the CYCLE, which is the enemy's equivalent,
## plus exactly which humours the player must find to answer it.

const OUT_PATH := "res://../docs/design/bestiary.md"

var catalog: Catalog


func _initialize() -> void:
	catalog = DataLoader.load_catalog()
	var lines: Array[String] = []
	lines.append("# Bestiary — every enemy's hand of tricks")
	lines.append("")
	lines.append("**GENERATED FILE — do not hand-edit.** Rebuild with:")
	lines.append("")
	lines.append("    godot --headless --path game -s tests/bestiary.gd")
	lines.append("")
	lines.append("Source: `game/data/enemies.json`, `encounters.json`,")
	lines.append("`environments.json`. Balance numbers live in")
	lines.append("[balance-notes.md](balance-notes.md); this is the reference for what")
	lines.append("each creature actually DOES on its turn.")
	lines.append("")
	lines.append("## How to read an enemy")
	lines.append("")
	lines.append("Enemies hold no energy deck — the deck is the player's clock. An")
	lines.append("enemy's equivalent is its **intent cycle**: a fixed, repeating list of")
	lines.append("moves, shown one turn ahead so every hit is answerable. The cycle IS")
	lines.append("the strategy, which is why it is printed in order.")
	lines.append("")
	lines.append("| Target | What it does | The player's answer |")
	lines.append("|---|---|---|")
	lines.append("| `health` | Damage, reduced by block | Block, or kill it first |")
	lines.append("| `health` + `pierce` | Damage that **ignores block** | Out-damage it; turtling loses |")
	lines.append("| `skills` + `jam` | Locks a skill for N turns | Spread the loadout; hold a second answer |")
	lines.append("| `skills` + `burn` | Destroys a skill charge **permanently** | Spend charges before they are taken |")
	lines.append("| `hand` | Steals energy from hand (or bank) | Play cards out; bank what matters |")
	lines.append("")
	lines.append("From **turn 8** every enemy strike gains +2 per turn (the night")
	lines.append("presses). No fight is meant to last past ~turn 10.")
	lines.append("")
	lines.append(_environment_section())
	lines.append("")
	lines.append("---")
	lines.append("")
	for enemy_id in _sorted(catalog.enemies.keys()):
		lines.append_array(_enemy_section(String(enemy_id)))
	var text := "\n".join(lines) + "\n"
	var path := ProjectSettings.globalize_path("res://") + "../docs/design/bestiary.md"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("cannot write %s" % path)
		quit(1)
		return
	file.store_string(text)
	file.close()
	print("wrote %s (%d enemies)" % [path, catalog.enemies.size()])
	quit(0)


func _sorted(keys: Array) -> Array:
	var out := keys.duplicate()
	out.sort()
	return out


func _environment_section() -> String:
	var lines: Array[String] = []
	lines.append("## Where they are fought")
	lines.append("")
	lines.append("An environment bends every fight in it, so the same enemy is a")
	lines.append("different problem in a different place.")
	lines.append("")
	lines.append("| Place | Rule | Cost changes | Sunbeams | Alarm |")
	lines.append("|---|---|---|---|---|")
	for environment_id in _sorted(catalog.environments.keys()):
		var environment: Dictionary = catalog.environments[environment_id]
		var mods: Array[String] = []
		for humour in environment.get("cost_mod", {}):
			var delta := int(environment["cost_mod"][humour])
			mods.append("%s %+d" % [Catalog.humour_name(String(humour)), delta])
		var beams: Array = environment.get("sunbeam_turns", [])
		var threshold := int(environment.get("stealth_threshold", 0))
		lines.append("| %s | %s | %s | %s | %s |" % [
			environment.get("name", environment_id),
			environment.get("rule_text", "-"),
			", ".join(mods) if not mods.is_empty() else "-",
			("turns " + ", ".join(beams.map(func(t): return str(int(t))))) if not beams.is_empty() else "-",
			("spotted at %d" % threshold) if threshold > 0 else "-",
		])
	return "\n".join(lines)


func _enemy_section(enemy_id: String) -> Array[String]:
	var enemy: Dictionary = catalog.enemies[enemy_id]
	var lines: Array[String] = []
	lines.append("## %s  <sub>`%s`</sub>" % [enemy.get("name", enemy_id), enemy_id])
	lines.append("")
	if String(enemy.get("flavor", "")) != "":
		lines.append("> %s" % enemy["flavor"])
		lines.append("")
	var intents: Array = enemy.get("intents", [])
	lines.append("**%d hp**  ·  **%d gleam**  ·  cycle of %d, repeating" % [
		int(enemy.get("hp", 0)), int(enemy.get("gleam", 0)), intents.size()])
	lines.append("")
	var places := _places_for(enemy_id)
	if not places.is_empty():
		lines.append("Fought in: %s" % ", ".join(places))
		lines.append("")
	lines.append("| Turn | Move | Target | Effect |")
	lines.append("|---|---|---|---|")
	for i in intents.size():
		var intent: Dictionary = intents[i]
		lines.append("| %d | **%s** | `%s%s` | %s |" % [
			i + 1, intent.get("name", "?"), intent.get("target", "?"),
			(" / " + String(intent["mode"])) if intent.has("mode") else "",
			_intent_effect(intent)])
	lines.append("")
	lines.append("**Strategy:** %s" % _strategy(enemy, intents))
	lines.append("")
	lines.append("---")
	lines.append("")
	return lines


func _intent_effect(intent: Dictionary) -> String:
	var amount := int(intent.get("amount", 0))
	match String(intent.get("target", "")):
		"health":
			if String(intent.get("mode", "")) == "pierce":
				return "%d damage, **ignores block**" % amount
			return "%d damage, blockable" % amount
		"skills":
			if String(intent.get("mode", "")) == "burn":
				return "burns 1 charge off a random ready skill, **permanently**"
			return "jams a random ready skill for %d turn(s)" % maxi(amount, 1)
		"hand":
			return "steals %d energy from hand (bank if hand is empty)" % amount
	return "-"


func _places_for(enemy_id: String) -> Array[String]:
	var places: Array[String] = []
	for encounter_id in _sorted(catalog.encounters.keys()):
		var encounter: Dictionary = catalog.encounters[encounter_id]
		if not encounter.get("enemies", []).has(enemy_id):
			continue
		var environment: Dictionary = catalog.environments.get(
			String(encounter.get("environment", "")), {})
		places.append("%s (%s)" % [encounter.get("name", encounter_id),
			environment.get("name", "?")])
	return places


## The cycle, read as a plan. Derived rather than authored so it can never
## contradict the numbers directly above it.
func _strategy(enemy: Dictionary, intents: Array) -> String:
	var damage := 0
	var biggest := 0
	var pierces := false
	var jams := false
	var burns := false
	var steals := false
	for intent in intents:
		match String(intent.get("target", "")):
			"health":
				damage += int(intent.get("amount", 0))
				biggest = maxi(biggest, int(intent.get("amount", 0)))
				if String(intent.get("mode", "")) == "pierce":
					pierces = true
			"skills":
				if String(intent.get("mode", "")) == "burn":
					burns = true
				else:
					jams = true
			"hand":
				steals = true
	var parts: Array[String] = []
	var per_turn := float(damage) / maxf(intents.size(), 1.0)
	parts.append("Averages **%.1f damage a turn** over its cycle (biggest single hit %d)" % [
		per_turn, biggest])
	var turns_to_kill := int(ceil(float(enemy.get("hp", 0)) / 3.0))
	parts.append("Takes roughly **%d turns to bring down** at 3 damage a turn" % turns_to_kill)
	if pierces:
		parts.append("**Pierces** — blocking is not an answer here, and a defensive kit will lose the race")
	if burns:
		parts.append("**Burns charges permanently** — use a skill before it is taken, not after")
	if jams:
		parts.append("**Jams** — bring a second answer, or a jam lands on your only one")
	if steals:
		parts.append("**Steals energy** — play cards out rather than holding a fat hand")
	if not pierces and not burns and not jams and not steals:
		parts.append("No tricks: a pure damage race, and the fight the block economy is tuned against")
	return ". ".join(parts) + "."
