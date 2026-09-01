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
	"mysticism_1", "mysticism_1", "mysticism_1",
]

## What the opening arc leaves in the spool: the starter fifteen plus
## sharpen_the_claws' growth cards (ferocity_2, shadow_1).
const BACKHALF_DECK := [
	"ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1",
	"guile_1", "guile_1", "guile_1",
	"shadow_1", "shadow_1", "shadow_1", "shadow_1",
	"mysticism_1", "mysticism_1", "mysticism_1",
	"ferocity_2", "shadow_1",
]

## …and the Wickhouse adds Her Stitching (the l4 growth) before the boss.
const WICKHOUSE_DECK := [
	"ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1",
	"guile_1", "guile_1", "guile_1",
	"shadow_1", "shadow_1", "shadow_1", "shadow_1",
	"mysticism_1", "mysticism_1", "mysticism_1",
	"ferocity_2", "shadow_1", "mysticism_2",
]

## FOCUSED BUYER BUILDS (owner direction 2026-08-08): players concentrate
## their gleam, they do not spread it. The gleam model (balance-notes Pass 5)
## says a core-only player banks ~90 spendable by the Drowned and ~160 by the
## boss; prices are 12 a second, 30 a third, 25 a tonic (rules.json), and
## re-spooling at home is free down to the 10-card floor. So the reference
## focused build is: three seconds + one third of YOUR humour + one tonic,
## spool thinned to 10 around it. Claw feeds Pounce/Swat; Moonlight is wild
## and feeds everything — but Wickrow's ward-light taxes it +1, which is the
## district rule doing its job against the obvious best build.
const CLAW_FOCUS_DECK := [
	"ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1",
	"ferocity_2", "ferocity_2", "ferocity_2", "ferocity_3",
	"shadow_1", "shadow_1",
]
const MOON_FOCUS_DECK := [
	"mysticism_1", "mysticism_1", "mysticism_1",
	"mysticism_2", "mysticism_2", "mysticism_2", "mysticism_3",
	"shadow_1", "shadow_1", "ferocity_1",
]

## Tutorial-stage scenarios mirror what the player actually has at that
## point: 10 max HP at level 1, loadout max 4 with Scratch.
var scenarios := [
	{"name": "vole (stage 1)", "enemy": "the_vole", "skills": ["scratch", "pounce"], "hp": 10},
	{"name": "wisp (stage 1)", "enemy": "gutter_wisp", "skills": ["scratch", "pounce"], "hp": 10},
	{"name": "dog (stage 2)", "enemy": "chained_dog", "skills": ["scratch", "pounce", "slink"], "hp": 10},
	# Ships with a damage floor: the wraith is a lesson about declining a
	# fight, so it cannot kill. The prologue also forces the exit on turn 5.
	{"name": "wraith (stage 3)", "enemy": "rag_wraith", "skills": ["scratch", "pounce", "slink", "purr", "loaf"], "hp": 10,
		"hp_floor": 1, "withdraw_after": 4},
	{"name": "unpicked (boss)", "enemy": "the_unpicked", "skills": ["scratch", "pounce", "slink", "purr", "loaf"], "hp": 10,
		"no_retreat": true, "doom_turn": 6},
	{"name": "watch captain (quest)", "enemy": "garden_watch_captain", "skills": ["scratch", "pounce", "slink", "shelf_justice"], "hp": 12,
		"environment": {"stealth_threshold": 5, "cost_mod": {"ferocity": 1}}},
	{"name": "wisp pair (quest)", "enemy": "wisp_pair", "skills": ["scratch", "pounce", "slink", "purr"], "hp": 12},
	# The coat assumes the garden route came first: Swat (its unlock) is the
	# cheap sustained damage that makes aggressive kits viable here.
	{"name": "empty coat (quest)", "enemy": "the_empty_coat", "skills": ["scratch", "swat", "slink", "purr"], "hp": 12},
	# ------------------------------------------------------------ Chapter 1 back half
	# The back half arrives after the whole opening arc (law 21: test the
	# fight that ships): +2 max hp and two growth cards from sharpen_the_claws,
	# a full five-wide tray. Wickrow fights carry the ward-light rule
	# (Moonlight +1 / Guile -1); Mereside carries the fog (Shadow -1).
	{"name": "tallow hound (ch1)", "enemy": "tallow_hound",
		"skills": ["scratch", "pounce", "swat", "slink", "purr"], "hp": 12,
		"deck": BACKHALF_DECK, "environment": {"cost_mod": {"mysticism": 1, "guile": -1}}},
	{"name": "candle golem (ch1)", "enemy": "candle_golem",
		"skills": ["scratch", "pounce", "swat", "slink", "purr"], "hp": 12,
		"deck": BACKHALF_DECK, "environment": {"cost_mod": {"mysticism": 1, "guile": -1}}},
	{"name": "the drowned (no buys)", "enemy": "the_drowned",
		"skills": ["scratch", "pounce", "swat", "slink", "purr"], "hp": 12,
		"deck": BACKHALF_DECK, "environment": {"cost_mod": {"shadow": -1}}},
	{"name": "the drowned (claw)", "enemy": "the_drowned",
		"skills": ["scratch", "pounce", "swat", "slink", "purr"], "hp": 14,
		"deck": CLAW_FOCUS_DECK, "environment": {"cost_mod": {"shadow": -1}}},
	{"name": "the drowned (moon)", "enemy": "the_drowned",
		"skills": ["scratch", "pounce", "swat", "slink", "purr"], "hp": 14,
		"deck": MOON_FOCUS_DECK, "environment": {"cost_mod": {"shadow": -1}}},
	# The boss three ways: the floor (no purchases, the case-file's "beatable
	# with no side quests" check), and the two focused buyers.
	{"name": "tallowman (no buys)", "enemy": "the_tallowman",
		"skills": ["scratch", "pounce", "swat", "slink", "shelf_justice"], "hp": 12,
		"deck": WICKHOUSE_DECK, "environment": {"cost_mod": {"mysticism": 1, "guile": -1}}},
	{"name": "tallowman (claw)", "enemy": "the_tallowman",
		"skills": ["scratch", "pounce", "swat", "slink", "shelf_justice"], "hp": 14,
		"deck": CLAW_FOCUS_DECK, "environment": {"cost_mod": {"mysticism": 1, "guile": -1}}},
	{"name": "tallowman (moon)", "enemy": "the_tallowman",
		"skills": ["scratch", "pounce", "swat", "slink", "shelf_justice"], "hp": 14,
		"deck": MOON_FOCUS_DECK, "environment": {"cost_mod": {"mysticism": 1, "guile": -1}}},
	# ------------------------------------------------- Chapter 1's full roster
	# The rows above are the ladder as it was BUILT, on the seven-card roster,
	# and they stay so the history stays comparable. These are the same fights
	# played by somebody who took what the chapter actually teaches — still
	# four chosen actions plus Scratch, because the tray did not get wider,
	# only the shelf it is picked from (rules.json combat.loadout_size).
	#
	# Each row is the SAME tray as the matching row above with exactly ONE
	# card swapped for the specialist the new roster offers against that
	# enemy. That is the question worth asking — does the card earn a slot? —
	# and it is the only comparison the rows above can answer.
	#
	# A tray built ENTIRELY of the new specialists was simmed first and lost
	# every run: Bite has one charge and Rake has two, so four of them
	# together carry eleven damage against a boss with twenty-four and a mend.
	# That is the roster working as designed (they are answers, not engines),
	# and it is why none of them replaces the damage engine below.
	{"name": "candle golem (tray)", "enemy": "candle_golem",
		"skills": ["scratch", "pounce", "swat", "bite_down"], "hp": 12,
		"deck": BACKHALF_DECK, "environment": {"cost_mod": {"mysticism": 1, "guile": -1}}},
	{"name": "the drowned (tray)", "enemy": "the_drowned",
		"skills": ["scratch", "pounce", "swat", "bite_down"], "hp": 12,
		"deck": BACKHALF_DECK, "environment": {"cost_mod": {"shadow": -1}}},
	{"name": "tallowman (tray)", "enemy": "the_tallowman",
		"skills": ["scratch", "pounce", "swat", "unknot"], "hp": 14,
		"deck": CLAW_FOCUS_DECK, "environment": {"cost_mod": {"mysticism": 1, "guile": -1}}},
	{"name": "tallowman (her tray)", "enemy": "the_tallowman",
		"skills": ["scratch", "pounce", "swat", "her_thread"], "hp": 14,
		"deck": MOON_FOCUS_DECK, "environment": {"cost_mod": {"mysticism": 1, "guile": -1}}},
]

var bots := ["brawler", "defender", "stalker", "random"]
var catalog: Catalog


func _initialize() -> void:
	catalog = DataLoader.load_catalog()
	print("bot playtests: %d runs per cell, turn cap %d" % [RUNS_PER_CELL, TURN_CAP])
	print("")
	print("%-24s %-9s %6s %6s %6s %7s %7s %7s" % [
		"scenario", "bot", "win%", "die%", "flee%", "turns", "hp_left", "deck"])
	var results := {}
	for scenario in scenarios:
		for bot in bots:
			results["%s|%s" % [scenario["name"], bot]] = _run_cell(scenario, bot)
		print("")
	var violations := _check_targets(results)
	if not violations.is_empty():
		print("BALANCE GATE FAILED (%d):" % violations.size())
		for violation in violations:
			print("  FAIL  %s" % violation)
		quit(1)
		return
	print("balance gate: all targets hold.")
	quit(0)


## The balance GATE (2026-08-31): the targets that used to live only as prose
## in .claude/skills/simbalance/SKILL.md, encoded so a tuning change that
## breaks the design fails `verify full` instead of waiting for a human to
## notice. Bounds are deliberately LOOSER than the prose targets: this trips
## on breakage — a tutorial that stopped being winnable, a story fight that
## became winnable, an elite that folds to random play — not on drift a
## designer should still eyeball in the printed table.
func _check_targets(results: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	# Tutorials teach; a bot that cannot win one means the lesson is a wall.
	for scenario_name in ["vole (stage 1)", "wisp (stage 1)"]:
		for bot in bots:
			var cell: Dictionary = results["%s|%s" % [scenario_name, bot]]
			if cell["win"] < 90.0:
				violations.append("%s: %s wins %.0f%% (tutorials are ~100%%)"
					% [scenario_name, bot, cell["win"]])
	# The wraith and the Unpicked are story beats, not fights. The Unpicked is
	# STRICTLY unwinnable (60 hp, doom turn 6) — one win means the script
	# broke. The wraith is merely far above Ash's weight: a brawler lands a
	# freak kill ~1 in 300, and 03_the_wrong_lamps carries the when_outcome
	# victory line for exactly that night (law 17) — so the gate allows the
	# freak and trips only when the fight becomes genuinely winnable.
	for bot in bots:
		var wraith: Dictionary = results["wraith (stage 3)|%s" % bot]
		if wraith["win"] > 2.0:
			violations.append("wraith (stage 3): %s wins %.1f%% (a lesson in "
				% [bot, wraith["win"]] + "declining a fight must stay unwinnable)")
		var unpicked: Dictionary = results["unpicked (boss)|%s" % bot]
		if unpicked["win"] > 0.0:
			violations.append("unpicked (boss): %s wins %.1f%% (this fight cannot be won)"
				% [bot, unpicked["win"]])
	# The dog punishes careless play — random must actually get hurt.
	var dog_random: Dictionary = results["dog (stage 2)|random"]
	if dog_random["die"] < 5.0:
		violations.append(
			"dog (stage 2): random dies %.0f%% (careless play must be punished)"
			% dog_random["die"])
	# Quest elites: skilled play wins them. If the best bot cannot, nobody can.
	for scenario_name in ["watch captain (quest)", "wisp pair (quest)",
			"empty coat (quest)"]:
		var best := _best_skilled(results, scenario_name)
		if best < 60.0:
			violations.append("%s: best skilled bot wins %.0f%% (target 75-100%%)"
				% [scenario_name, best])
	# The boss floor: the case file promises the Tallowman is beatable with no
	# side quests at all (2026-08-31 baseline: stalker 99%).
	if _best_skilled(results, "tallowman (no buys)") < 60.0:
		violations.append("tallowman (no buys): best skilled bot wins %.0f%% "
			% _best_skilled(results, "tallowman (no buys)")
			+ "(the boss must be beatable without purchases)")
	# A build the Exchange sells must beat the fights it was bought for
	# (2026-08-31 baseline: 100% across the board).
	for scenario_name in ["the drowned (claw)", "the drowned (moon)",
			"tallowman (claw)", "tallowman (moon)"]:
		var best := _best_skilled(results, scenario_name)
		if best < 80.0:
			violations.append("%s: best skilled bot wins %.0f%% "
				% [scenario_name, best]
				+ "(a purchased build must carry its fight)")
	return violations


func _best_skilled(results: Dictionary, scenario_name: String) -> float:
	var best := 0.0
	for bot in ["brawler", "defender", "stalker"]:
		best = maxf(best, float(results["%s|%s" % [scenario_name, bot]]["win"]))
	return best


func _run_cell(scenario: Dictionary, bot: String) -> Dictionary:
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
			"deck": scenario.get("deck", STARTER_DECK),
			"skills": scenario["skills"].filter(func(s): return s != "scratch"),
			"enemy": scenario["enemy"],
			"environment": scenario.get("environment", {}),
			# The boss has no back door; a flee% for it would be fiction.
			"no_retreat": scenario.get("no_retreat", false),
			# Scripted fights ship with a damage floor and/or a fixed ending;
			# simming them without those measures a fight nobody plays.
			"hp_floor": scenario.get("hp_floor", 0),
			"doom_turn": scenario.get("doom_turn", 0),
		})
		_play(state, bot, int(scenario.get("withdraw_after", 0)))
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
	var cell := {
		"win": 100.0 * wins / RUNS_PER_CELL,
		"die": 100.0 * deaths / RUNS_PER_CELL,
		"flee": 100.0 * flees / RUNS_PER_CELL,
	}
	print("%-24s %-9s %5.0f%% %5.0f%% %5.0f%% %7.1f %7.1f %7.1f" % [
		scenario["name"], bot, cell["win"], cell["die"], cell["flee"],
		float(turn_sum) / RUNS_PER_CELL,
		float(hp_sum) / maxi(wins, 1), float(deck_sum) / maxi(wins, 1)])
	return cell


func _play(state: CombatState, bot: String, withdraw_after := 0) -> void:
	_choose_approach(state, bot)
	var stall := 0
	# Scene-level forced withdrawal (battle.gd's `withdraw_after`): once the
	# scripted turn passes, the only button on screen is Slip Away. Without
	# modelling it the sim reports a fight nobody can reach — an hp_floor
	# wraith left to grind for 25 turns is a 100% win that never happens.
	var cap: int = TURN_CAP if withdraw_after <= 0 else withdraw_after
	while state.outcome == CombatState.Outcome.ONGOING and state.turn <= cap:
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
			var modes := state.approaches.keys()
			pick = modes[state.rng.pick_index(modes.size())]
	if pick != "" and state.can_pay_approach(pick):
		state.do_command({"type": "approach", "mode": pick})


func _decide(state: CombatState, bot: String) -> Dictionary:
	var intent := state.current_intent()
	var incoming := int(intent.get("amount", 0)) \
		if intent.get("target", "") == "health" else 0
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
			# Unknot leads: a jammed tray is a defender with nothing to play,
			# and it is the only card that answers that.
			if _jammed(state) and _playable(state, "unknot"):
				return {"type": "play_skill", "skill_id": "unknot"}
			if incoming > state.player_block:
				# Shade before Loaf before Slink: the guard that
				# survives the turn-over is worth more than the bigger one
				# that costs a turn of paws.
				for skill in ["long_shadow", "loaf", "slink"]:
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
				# Vanish before the door: leaving from hiding costs no parting
				# shot, so the stalker's own card is checked before the exit.
				if _playable(state, "vanish") and not state.hidden:
					return {"type": "play_skill", "skill_id": "vanish"}
				return {"type": "slip_away"}
			var best := _best_damage_skill(state)
			if best != "":
				return {"type": "play_skill", "skill_id": best}
			if incoming > state.player_block:
				for skill in ["long_shadow", "slink"]:
					if _playable(state, skill):
						return {"type": "play_skill", "skill_id": skill}
			return {"type": "end_turn"}
	return {"type": "end_turn"}


## Is anything in the tray tangled? Unknot's whole reason for being in a
## loadout, and the one condition under which a defender should lead with it.
func _jammed(state: CombatState) -> bool:
	for entry in state.skills:
		if int(entry.get("jammed_turns", 0)) > 0:
			return true
	return false


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
	if def.is_empty() or state.statuses.get("loafed", 0) > 0 \
			or not state.channel.is_empty():
		return false
	if def.get("instinct", false):
		return not state.instinct_used
	var runtime := state.skill_state(skill_id)
	if runtime.is_empty() or int(runtime.get("jammed_turns", 0)) > 0 \
			or int(runtime.get("charges_left", 0)) <= 0:
		return false
	var owing := state.remaining_cost(skill_id)
	# PAWS, not just energy. Bite costs three Ferocity, which is three
	# card placements against a budget of three — so "can I afford it?" and
	# "can I afford it THIS turn?" are now different questions, and a bot that
	# only asks the first one spends its turn being rejected.
	return state.can_pay(owing) and state.paws_needed(skill_id) <= state.paws_left


## The hardest hit available RIGHT NOW, scored through the enemy's guard
## rather than off the card face. Raw damage was the same question until a
## pierce card existed: with a guard of 4 up, Bite's 5 lands 5 and
## Pounce's 4 lands nothing — and with no guard up, spending Bite's one
## charge to out-hit Pounce by one is a bot throwing its answer away before
## the question is asked. Ties go to the cheaper card for the same reason.
func _best_damage_skill(state: CombatState) -> String:
	var best := ""
	var best_landed := 0
	var best_paws := 99
	for skill_id in _playable_skills(state):
		var def: Dictionary = catalog.skills[skill_id]
		var landed := 0
		var guard := state.enemy_block
		for effect in def.get("effects", []):
			if effect.get("type", "") != "damage":
				continue
			var amount := int(effect["amount"])
			if effect.get("mode", "") == "pierce":
				landed += amount
			else:
				var turned := mini(guard, amount)
				guard -= turned
				landed += amount - turned
		if landed <= 0:
			continue
		var paws := state.paws_needed(skill_id)
		if landed > best_landed or (landed == best_landed and paws < best_paws):
			best_landed = landed
			best_paws = paws
			best = skill_id
	return best
