class_name CombatState
extends RefCounted
## One encounter, fully deterministic from (catalog, seed, commands).
## Pure rules: no Nodes, no rendering, no filesystem. The scene layer renders
## this state and forwards player intents as commands.
##
## Core loop (see docs/design/core-gameplay.md):
## - The deck is ENERGY, not actions. Spent energy never reshuffles: the deck
##   is the fuel gauge and the run timer in one.
## - Skills are the equipped loadout with limited charges per adventure.
## - Enemy intents are telegraphed and target HEALTH, SKILLS, or HAND.

enum Outcome { ONGOING, VICTORY, DEFEAT, RETREATED }

const HAND_LIMIT := 5
const BANK_LIMIT := 2

var catalog: Catalog
var rng: CoreRng
var log: CommandLog

# --- Player ---
var player_hp: int
var player_max_hp: int
var player_block: int = 0
var deck: Array = []      # energy card ids; draw from the back
var hand: Array = []
var banked: Array = []    # face-down saved cards (combo fuel, capped, raidable)
var spent: Array = []     # gone for the adventure — no reshuffle
var skills: Array = []    # {id, charges_left, jammed_turns}
var statuses: Dictionary = {}          # e.g. {"loafed": 1}
var channel: Dictionary = {}           # active purr: {heal_per_turn, turns_left}
var instinct_used: bool = false        # free instinct is once per turn
var sharpened: bool = false            # lingering: next damage effect +1, once
## Encounter telemetry consumed by AchievementTracker.record_encounter().
var flags: Dictionary = {
	"damage_taken": 0,     # total hp lost to enemy attacks
	"energy_paid": 0,      # cards spent paying skill costs
	"hand_lost": 0,        # cards stolen by hand attacks
	"purr_completed": false,
	"skills_used": {},     # skill_id -> times played
	"killing_skill": "",   # skill that landed the final blow
}

# --- Enemy ---
var enemy_id: String
var enemy_hp: int
var enemy_max_hp: int
var _intent_index: int = 0

var turn: int = 1
var outcome: int = Outcome.ONGOING

# --- Environment (see data/environments.json) ---
var cost_mod: Dictionary = {}       # humour -> +/- cost adjustment
var sunbeam_turns: Array = []       # player turns on which a sunbeam appears
var stealth_threshold: int = 0      # >0 makes this a stealth encounter
var alarm: int = 0
var spotted: bool = false
## Informational events for the UI layer ("sunbeam", "spotted"). Drained via
## take_events(); core behavior never depends on them.
var _events: Array[String] = []


static func create(p_catalog: Catalog, seed_value: int, config: Dictionary) -> CombatState:
	var state := CombatState.new()
	state.catalog = p_catalog
	state.rng = CoreRng.new(seed_value)
	state.log = CommandLog.new()
	state.player_max_hp = int(config.get("player_max_hp", config.get("player_hp", 20)))
	state.player_hp = int(config.get("player_hp", state.player_max_hp))
	state.deck = Array(config.get("deck", [])).duplicate()
	# Mid-run continuation: a later encounter in the same prowl passes the
	# surviving charge counts so skills stay spent across fights.
	var charge_overrides: Dictionary = config.get("skill_charges", {})
	for skill_id in config.get("skills", []):
		var def: Dictionary = p_catalog.skills[skill_id]
		state.skills.append({
			"id": skill_id,
			"charges_left": int(charge_overrides.get(skill_id, def.get("charges", 0))),
			"jammed_turns": 0,
		})
	state.enemy_id = String(config.get("enemy", ""))
	var enemy_def: Dictionary = p_catalog.enemies[state.enemy_id]
	state.enemy_max_hp = int(enemy_def["hp"])
	state.enemy_hp = state.enemy_max_hp
	var environment: Dictionary = config.get("environment", {})
	state.cost_mod = environment.get("cost_mod", {})
	state.sunbeam_turns = environment.get("sunbeam_turns", [])
	state.stealth_threshold = int(environment.get("stealth_threshold", 0))
	# Lingering effects carried in from the previous encounter of this prowl.
	for lingering in config.get("lingering", []):
		match lingering:
			"warmed":  # a finished purr keeps its warmth
				state.player_hp = mini(state.player_hp + 2, state.player_max_hp)
				state._events.append("warmed")
			"sharpened":  # a flawless fight leaves the claws keen
				state.sharpened = true
				state._events.append("sharpened")
	if config.get("shuffle", true):
		state.rng.shuffle(state.deck)
	state._draw_up_to_limit()
	return state


## Lingering effects this encounter passes to the NEXT one in the prowl.
func lingering_out() -> Array[String]:
	var lingering: Array[String] = []
	if flags["purr_completed"]:
		lingering.append("warmed")
	if outcome == Outcome.VICTORY and int(flags["damage_taken"]) == 0:
		lingering.append("sharpened")
	return lingering


## UI-facing event queue; returns and clears pending events.
func take_events() -> Array[String]:
	var events := _events.duplicate()
	_events.clear()
	return events


## Environment-adjusted cost of a skill (never below zero per humour).
func effective_cost(cost: Dictionary) -> Dictionary:
	var adjusted := {}
	for humour in cost:
		var value: int = int(cost[humour]) + int(cost_mod.get(humour, 0))
		if value > 0:
			adjusted[humour] = value
	return adjusted


## The enemy's telegraphed next move: {target: "health"|"skills"|"hand", amount, name}.
func current_intent() -> Dictionary:
	var intents: Array = catalog.enemies[enemy_id]["intents"]
	return intents[_intent_index % intents.size()]


func skill_state(skill_id: String) -> Dictionary:
	for s in skills:
		if s["id"] == skill_id:
			return s
	return {}


## Can the cost be paid from hand + banked right now?
func can_pay(cost: Dictionary) -> bool:
	for humour in cost:
		var available := 0
		for card_id in hand + banked:
			var card: Dictionary = catalog.energy_cards[card_id]
			if card["humour"] == humour:
				available += int(card["value"])
		if available < int(cost[humour]):
			return false
	return true


## Entry point for ALL player actions. Returns {ok: bool, error: String}.
func do_command(command: Dictionary) -> Dictionary:
	if outcome != Outcome.ONGOING:
		return _fail("encounter is over")
	var result: Dictionary
	match command.get("type", ""):
		"play_skill":
			result = _cmd_play_skill(String(command.get("skill_id", "")))
		"bank":
			result = _cmd_bank(int(command.get("hand_index", -1)))
		"end_turn":
			result = _cmd_end_turn()
		"slip_away":
			outcome = Outcome.RETREATED
			result = {"ok": true, "error": ""}
		_:
			result = _fail("unknown command '%s'" % command.get("type", ""))
	if result["ok"]:
		log.record(turn, command)
	return result


# ------------------------------------------------------------------ commands

func _cmd_play_skill(skill_id: String) -> Dictionary:
	if statuses.get("loafed", 0) > 0:
		return _fail("loafed: all paws are committed")
	if not catalog.skills.has(skill_id):
		return _fail("unknown skill '%s'" % skill_id)
	var def: Dictionary = catalog.skills[skill_id]
	var is_instinct: bool = def.get("instinct", false)
	var state := skill_state(skill_id)
	if is_instinct:
		if instinct_used:
			return _fail("Scratch has made its point this turn")
	else:
		if state.is_empty():
			return _fail("skill '%s' is not equipped" % skill_id)
		if state["jammed_turns"] > 0:
			return _fail("skill '%s' is jammed" % skill_id)
		if state["charges_left"] <= 0:
			return _fail("skill '%s' has no charges left" % skill_id)
	var cost: Dictionary = effective_cost(def.get("cost", {}))
	if not can_pay(cost):
		return _fail("not enough energy for '%s'" % skill_id)
	_pay(cost)
	if stealth_threshold > 0 and not spotted and cost.has("ferocity"):
		alarm += int(cost["ferocity"])  # loud cards raise the alarm
		if alarm >= stealth_threshold:
			spotted = true
			_events.append("spotted")
	if is_instinct:
		instinct_used = true
	else:
		state["charges_left"] -= 1
	var used: Dictionary = flags["skills_used"]
	used[skill_id] = int(used.get(skill_id, 0)) + 1
	_apply_effects(def.get("effects", []))
	_check_end()
	if outcome == Outcome.VICTORY and flags["killing_skill"] == "":
		flags["killing_skill"] = skill_id
	return {"ok": true, "error": ""}


func _cmd_bank(hand_index: int) -> Dictionary:
	if hand_index < 0 or hand_index >= hand.size():
		return _fail("no card at hand index %d" % hand_index)
	if banked.size() >= BANK_LIMIT:
		return _fail("bank is full")
	banked.append(hand[hand_index])
	hand.remove_at(hand_index)
	return {"ok": true, "error": ""}


func _cmd_end_turn() -> Dictionary:
	_enemy_act()
	if outcome != Outcome.ONGOING:
		return {"ok": true, "error": ""}
	# --- start of next player turn ---
	turn += 1
	player_block = 0
	instinct_used = false
	for s in skills:
		if s["jammed_turns"] > 0:
			s["jammed_turns"] -= 1
	if statuses.get("loafed", 0) > 0:
		statuses["loafed"] -= 1
	if not channel.is_empty():
		player_hp = mini(player_hp + int(channel["heal_per_turn"]), player_max_hp)
		channel["turns_left"] -= 1
		if channel["turns_left"] <= 0:
			channel = {}
			flags["purr_completed"] = true
	_draw_up_to_limit()
	if sunbeam_turns.has(turn) and not spent.is_empty():
		# A patch of sun: one spent card returns to the bottom of the deck —
		# the fuel gauge ticks back up.
		var index := rng.pick_index(spent.size())
		deck.push_front(spent[index])
		spent.remove_at(index)
		_events.append("sunbeam")
	return {"ok": true, "error": ""}


# ------------------------------------------------------------------ internals

func _pay(cost: Dictionary) -> void:
	# Auto-payment: largest cards first (fewest cards spent; overpay is wasted).
	# Hand pays before bank so saved combos survive when possible.
	for humour in cost:
		var remaining := int(cost[humour])
		for pool: Array in [hand, banked]:
			if remaining <= 0:
				break
			var candidates: Array = []
			for i in pool.size():
				var card: Dictionary = catalog.energy_cards[pool[i]]
				if card["humour"] == humour:
					candidates.append({"index": i, "value": int(card["value"])})
			candidates.sort_custom(func(a, b): return a["value"] > b["value"])
			var to_remove: Array = []
			for c in candidates:
				if remaining <= 0:
					break
				remaining -= c["value"]
				to_remove.append(c["index"])
			to_remove.sort()
			to_remove.reverse()
			for i in to_remove:
				spent.append(pool[i])
				pool.remove_at(i)
				flags["energy_paid"] = int(flags["energy_paid"]) + 1


func _apply_effects(effects: Array) -> void:
	for effect in effects:
		match effect.get("type", ""):
			"damage":
				var amount := int(effect["amount"])
				if sharpened:
					amount += 1
					sharpened = false
					_events.append("sharpened_strike")
				enemy_hp -= amount
			"block":
				player_block += int(effect["amount"])
			"heal":
				player_hp = mini(player_hp + int(effect["amount"]), player_max_hp)
			"channel_heal":  # Purr: heals over time, broken by taking damage
				channel = {
					"heal_per_turn": int(effect["amount"]),
					"turns_left": int(effect.get("turns", 2)),
				}
			"draw":
				for i in int(effect["amount"]):
					_draw_one()
			"self_stun":  # Loaf: committed, cannot act next turn
				statuses["loafed"] = int(effect.get("turns", 1))
			_:
				assert(false, "unknown effect type '%s'" % effect.get("type", ""))


func _enemy_act() -> void:
	var intent := current_intent()
	_intent_index += 1
	if spotted:
		# A spotted cat has no tricks left to fear but teeth: every intent
		# becomes a straightforward, harder hit.
		intent = {
			"name": String(intent["name"]) + "!",
			"target": "health",
			"amount": maxi(int(intent.get("amount", 2)) + 1, 3),
		}
	match intent["target"]:
		"health":
			var damage := maxi(int(intent["amount"]) - player_block, 0)
			player_hp -= damage
			flags["damage_taken"] = int(flags["damage_taken"]) + damage
			if damage > 0 and not channel.is_empty():
				channel = {}  # a purr you can't finish
		"skills":
			var targets: Array = skills.filter(
				func(s): return s["charges_left"] > 0 and s["jammed_turns"] == 0)
			if not targets.is_empty():
				var victim: Dictionary = targets[rng.pick_index(targets.size())]
				if intent.get("mode", "jam") == "burn":
					victim["charges_left"] -= 1
				else:
					victim["jammed_turns"] = int(intent.get("amount", 1))
		"hand":
			for i in int(intent["amount"]):
				var pool: Array = hand if not hand.is_empty() else banked
				if pool.is_empty():
					break
				var index := rng.pick_index(pool.size())
				spent.append(pool[index])
				pool.remove_at(index)
				flags["hand_lost"] = int(flags["hand_lost"]) + 1
	_check_end()


func _draw_up_to_limit() -> void:
	while hand.size() < HAND_LIMIT and not deck.is_empty():
		_draw_one()


func _draw_one() -> void:
	if deck.is_empty() or hand.size() >= HAND_LIMIT:
		return  # NO reshuffle: an empty deck is an exhausted cat
	hand.append(deck.pop_back())


func _check_end() -> void:
	if enemy_hp <= 0:
		outcome = Outcome.VICTORY
	elif player_hp <= 0:
		outcome = Outcome.DEFEAT


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
