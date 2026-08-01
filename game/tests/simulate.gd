extends SceneTree
## Automated playtesting: bot strategies play CombatState over many seeds and
## report win/death/retreat rates, turns, and resources left.
##   godot --headless --path game -s tests/simulate.gd
## Deterministic core + seeded runs = reproducible balance data.

const RUNS_PER_CELL := 300
const TURN_CAP := 25

## Level-1 starter (owner calibration 2026-08-01): 15 cards, all value 1.
const STARTER_DECK := [
	"ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1",
	"guile_1", "guile_1", "guile_1",
	"shadow_1", "shadow_1", "shadow_1", "shadow_1",
	"moonlight_1", "moonlight_1", "moonlight_1",
]

## Tutorial-stage scenarios mirror what the player actually has at that
## point: 10 max HP at level 1, loadout max 4 with Scratch.
var scenarios := [
	{"name": "vole (stage 1)", "enemy": "the_vole", "skills": ["scratch", "pounce"], "hp": 10},
	{"name": "wisp (stage 1)", "enemy": "gutter_wisp", "skills": ["scratch", "pounce"], "hp": 10},
	{"name": "dog (stage 2)", "enemy": "chained_dog", "skills": ["scratch", "pounce", "slink"], "hp": 10},
	{"name": "wraith (stage 3)", "enemy": "rag_wraith", "skills": ["scratch", "slink", "purr", "loaf"], "hp": 10},
	{"name": "unpicked (boss)", "enemy": "the_unpicked", "skills": ["scratch", "slink", "purr", "loaf"], "hp": 10},
	{"name": "watch captain (quest)", "enemy": "garden_watch_captain", "skills": ["scratch", "pounce", "slink", "shelf_justice"], "hp": 12,
		"environment": {"stealth_threshold": 5, "cost_mod": {"ferocity": 1}}},
	{"name": "wisp pair (quest)", "enemy": "wisp_pair", "skills": ["scratch", "pounce", "slink", "purr"], "hp": 12},
]

var bots := ["brawler", "defender", "stalker", "random"]
var catalog: Catalog


func _initialize() -> void:
	catalog = DataLoader.load_catalog()
	print("bot playtests: %d runs per cell, turn cap %d" % [RUNS_PER_CELL, TURN_CAP])
	print("")
	print("%-24s %-9s %6s %6s %6s %7s %7s %7s" % [
		"scenario", "bot", "win%", "die%", "flee%", "turns", "hp_left", "deck"])
	for scenario in scenarios:
		for bot in bots:
			_run_cell(scenario, bot)
		print("")
	quit(0)


func _run_cell(scenario: Dictionary, bot: String) -> void:
	var wins := 0
	var deaths := 0
	var flees := 0
	var turn_sum := 0
	var hp_sum := 0
	var deck_sum := 0
	for i in RUNS_PER_CELL:
		var state := CombatState.create(catalog, 1000 + i * 7919, {
			"player_hp": scenario["hp"],
			"player_max_hp": scenario["hp"],
			"deck": STARTER_DECK,
			"skills": scenario["skills"].filter(func(s): return s != "scratch"),
			"enemy": scenario["enemy"],
			"environment": scenario.get("environment", {}),
		})
		_play(state, bot)
		match state.outcome:
			CombatState.Outcome.VICTORY:
				wins += 1
				hp_sum += state.player_hp
				deck_sum += state.deck.size()
			CombatState.Outcome.DEFEAT:
				deaths += 1
			CombatState.Outcome.RETREATED:
				flees += 1
		turn_sum += state.turn
	print("%-24s %-9s %5.0f%% %5.0f%% %5.0f%% %7.1f %7.1f %7.1f" % [
		scenario["name"], bot,
		100.0 * wins / RUNS_PER_CELL, 100.0 * deaths / RUNS_PER_CELL,
		100.0 * flees / RUNS_PER_CELL, float(turn_sum) / RUNS_PER_CELL,
		float(hp_sum) / maxi(wins, 1), float(deck_sum) / maxi(wins, 1)])


func _play(state: CombatState, bot: String) -> void:
	_choose_approach(state, bot)
	var stall := 0
	while state.outcome == CombatState.Outcome.ONGOING and state.turn <= TURN_CAP:
		var action := _decide(state, bot)
		var result := state.do_command(action)
		if not result["ok"]:
			stall += 1
			if stall > 2 or action["type"] == "end_turn":
				state.do_command({"type": "end_turn"})
				stall = 0
		else:
			stall = 0
	if state.outcome == CombatState.Outcome.ONGOING:
		state.do_command({"type": "slip_away"})  # cap reached = walked away


func _choose_approach(state: CombatState, bot: String) -> void:
	var pick := ""
	match bot:
		"brawler":
			pick = "ambush"
		"stalker":
			pick = "stalk"
		"defender":
			pick = "ward"
		"random":
			var modes := CombatState.APPROACHES.keys()
			pick = modes[state.rng.pick_index(modes.size())]
	if pick != "" and state.can_pay(state.effective_cost(CombatState.APPROACHES[pick]["cost"])):
		state.do_command({"type": "approach", "mode": pick})


func _decide(state: CombatState, bot: String) -> Dictionary:
	var intent := state.current_intent()
	var incoming := int(intent.get("amount", 0)) if intent["target"] == "health" else 0
	match bot:
		"random":
			var options: Array[Dictionary] = [{"type": "end_turn"}]
			for skill in _playable_skills(state):
				options.append({"type": "play_skill", "skill_id": skill})
			return options[state.rng.pick_index(options.size())]
		"brawler":
			var best := _best_damage_skill(state)
			if best != "":
				return {"type": "play_skill", "skill_id": best}
			return {"type": "end_turn"}
		"defender":
			# Block incoming damage first, heal when safe, then attack.
			if incoming > state.player_block:
				for skill in ["loaf", "slink"]:
					if _playable(state, skill):
						return {"type": "play_skill", "skill_id": skill}
			if state.player_hp <= int(state.player_max_hp * 0.6) and incoming == 0 \
					and _playable(state, "purr") and state.channel.is_empty():
				return {"type": "play_skill", "skill_id": "purr"}
			var best := _best_damage_skill(state)
			if best != "":
				return {"type": "play_skill", "skill_id": best}
			return {"type": "end_turn"}
		"stalker":
			# Fights while healthy, flees at the wise moment.
			if state.player_hp <= int(state.player_max_hp * 0.3):
				return {"type": "slip_away"}
			var best := _best_damage_skill(state)
			if best != "":
				return {"type": "play_skill", "skill_id": best}
			if incoming > state.player_block and _playable(state, "slink"):
				return {"type": "play_skill", "skill_id": "slink"}
			return {"type": "end_turn"}
	return {"type": "end_turn"}


func _playable_skills(state: CombatState) -> Array[String]:
	var playable: Array[String] = []
	for entry in state.skills:
		if _playable(state, entry["id"]):
			playable.append(entry["id"])
	if not state.instinct_used:
		playable.append("scratch")
	return playable


func _playable(state: CombatState, skill_id: String) -> bool:
	var def: Dictionary = catalog.skills.get(skill_id, {})
	if def.is_empty() or state.statuses.get("loafed", 0) > 0:
		return false
	if def.get("instinct", false):
		return not state.instinct_used
	var runtime := state.skill_state(skill_id)
	return not runtime.is_empty() and int(runtime.get("jammed_turns", 0)) == 0 \
		and int(runtime.get("charges_left", 0)) > 0 \
		and state.can_pay(state.effective_cost(def.get("cost", {})))


func _best_damage_skill(state: CombatState) -> String:
	var best := ""
	var best_damage := 0
	for skill_id in _playable_skills(state):
		var def: Dictionary = catalog.skills[skill_id]
		for effect in def.get("effects", []):
			if effect.get("type", "") == "damage" and int(effect["amount"]) > best_damage:
				best_damage = int(effect["amount"])
				best = skill_id
	return best
