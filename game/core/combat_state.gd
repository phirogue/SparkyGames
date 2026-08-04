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
## Paw action points (owner mechanic 2026-08-01): every energy card PLACED
## — fed onto a skill, or banked — costs one paw. Free skills, discards and
## slipping away cost none. Paws refill at the start of each turn.
const DEFAULT_PAWS := 3
## Battles open with a small hand (owner rule 2026-08-01): 3 cards, then
## the end-of-turn draw refills toward HAND_LIMIT as before.
const OPENING_HAND := 3

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
var paw_limit: int = DEFAULT_PAWS      # energy placements allowed per turn
var paws_left: int = DEFAULT_PAWS

# --- The Approach (how Ash enters the fight; owner concept 2026-07-30) ---
## Locked once any other command is taken. Initiative emerges from the
## choice: stalk = you act from hiding, ambush = you strike first but anger
## it, case = you learn, ward = you prepare, walk in = free.
##
## Approach prices are FLAT — the environment's cost_mod does not touch them
## (owner rule 2026-08-03). How you go in is about you, not about the alley,
## and a discount here made the chooser quote a price the player could not
## predict: "Stalk" cost 2 Shadow on the roof and 1 in the fog.
const APPROACHES := {
	"stalk": {"cost": {"shadow": 2}, "name": "Stalk"},
	"ambush": {"cost": {"ferocity": 2}, "name": "Ambush"},
	"case": {"cost": {"guile": 2}, "name": "Case It"},
	"ward": {"cost": {"mysticism": 2}, "name": "Ward"},
}
var approach := ""                     # chosen mode, "" until locked
var approach_locked: bool = false
var hidden: bool = false               # stalk: enemy's first act is wasted
var _enemy_enraged: bool = false       # ambush: enemy's first hit +2
var _case_watched: bool = false        # case: it studied you back (+1 first hit)
var _ward_holds: bool = false          # ward: block survives the next turn-over
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
## Some fights have no back door (owner rule 2026-08-03). The Unpicked is the
## first: the prologue's whole point is that Ash cannot walk away from that
## room, and a Slip Away button there was a lie told by the UI.
var no_retreat: bool = false
## Scripted fights that must not kill you (owner rule 2026-08-04). The
## rag-wraith is a lesson about declining a fight, and a lesson you can fail
## to death is a lesson nobody hears. Damage stops here instead of at zero.
var hp_floor: int = 0
## The turn this fight ENDS, decided (owner rule 2026-08-04: "a maximum of 6
## moves... so that the player is not struggling for too long"). The Unpicked
## cannot be beaten and should not be ground against; on this turn it simply
## finishes what it came to do.
var doom_turn: int = 0

## Human-readable record of what each action actually DID — damage rolled,
## block soaked, cards lifted. The chronicle reads from here, so the log can
## say "Empty Sleeve: 6 damage (3 blocked)" instead of "Empty Sleeve.".
## Informational only: nothing in the rules reads it back (same contract as
## _events), so it cannot desync core behaviour.
var _journal: Array[String] = []


## Drains the mechanical record since the last call.
func take_journal() -> Array[String]:
	var out := _journal.duplicate()
	_journal.clear()
	return out


## Apply damage to Ash, honouring the survivable-fight floor. Returns what was
## actually lost, so callers report the true number.
func _hurt(amount: int) -> int:
	var lost := maxi(mini(amount, player_hp - hp_floor), 0)
	player_hp -= lost
	flags["damage_taken"] = int(flags["damage_taken"]) + lost
	return lost

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
			"free_used": false,  # cost-free plays are once per turn
			"powered": {},  # humour -> energy fed onto the card (owner rule:
			                # skills fire only once fully powered)
		})
	state.paw_limit = int(config.get("paws", DEFAULT_PAWS))
	state.paws_left = state.paw_limit
	state.no_retreat = bool(config.get("no_retreat", false))
	state.hp_floor = int(config.get("hp_floor", 0))
	state.doom_turn = int(config.get("doom_turn", 0))
	state.enemy_id = String(config.get("enemy", ""))
	var enemy_def: Dictionary = p_catalog.enemies[state.enemy_id]
	state.enemy_max_hp = int(enemy_def["hp"])
	state.enemy_hp = state.enemy_max_hp
	var environment: Dictionary = config.get("environment", {})
	state.cost_mod = environment.get("cost_mod", {})
	state.sunbeam_turns = environment.get("sunbeam_turns", [])
	state.stealth_threshold = int(environment.get("stealth_threshold", 0))
	if config.get("start_hidden", false):
		# Story-granted surprise: the enemy hasn't registered you yet.
		state.hidden = true
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
	# Scripted openers (tutorial rule): a scene may name the exact cards the
	# fight starts with, pulled out of the deck wherever they sit. This is
	# what lets the prologue run on ONE deck that only ever shrinks — the
	# alternative was handing out a fresh pile of energy before each fight,
	# which made the spool jump UP mid-night (owner defect list). Named cards
	# the deck no longer holds are simply skipped; the normal draw fills in.
	for card_id in config.get("opening_cards", []):
		if state.hand.size() >= HAND_LIMIT:
			break
		var index := state.deck.rfind(card_id)  # nearest the top of the deck
		if index >= 0:
			state.hand.append(state.deck[index])
			state.deck.remove_at(index)
	var opening := mini(int(config.get("opening_hand", OPENING_HAND)), HAND_LIMIT)
	while state.hand.size() < opening and not state.deck.is_empty():
		state._draw_one()
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


## Cost still unpaid after the energy already fed onto the card.
func remaining_cost(skill_id: String) -> Dictionary:
	var def: Dictionary = catalog.skills.get(skill_id, {})
	var cost := effective_cost(def.get("cost", {}))
	var powered: Dictionary = skill_state(skill_id).get("powered", {})
	var remaining := {}
	for humour in cost:
		var short: int = int(cost[humour]) - int(powered.get(humour, 0))
		if short > 0:
			remaining[humour] = short
	return remaining


## Fully powered and ready to fire?
func skill_powered(skill_id: String) -> bool:
	return remaining_cost(skill_id).is_empty()


## Mysticism is WILD (owner rule 2026-08-01): it can pay any energy cost.
## A cost keyed "mysticism" is the reverse — only true mysticism pays it
## (reserved for the very special actions of later chapters).
const WILD_HUMOUR := "mysticism"


## Can the cost be paid from hand + banked right now? Specific energy pays
## first; mysticism covers any shortfall. Cards are atomic — a single wild
## can only ever cover ONE humour's shortfall — so this asks the same
## card-level planner that _pay() executes, and the two can never disagree.
func can_pay(cost: Dictionary) -> bool:
	return _payment_plan(cost)["covered"]


## Entry point for ALL player actions. Returns {ok: bool, error: String}.
func do_command(command: Dictionary) -> Dictionary:
	if outcome != Outcome.ONGOING:
		return _fail("encounter is over")
	var result: Dictionary
	# Acting closes the window for a clever entrance — but only a real act
	# does. Locking BEFORE the command was validated meant a fumbled tap (a
	# skill you can't afford, a mis-swiped card index) silently cost you your
	# ambush, and left rejected commands mutating state, which nothing else
	# in here does. Found by the chaos harness; see tests/chaos_play.gd.
	var kind := String(command.get("type", ""))
	var locks_approach := ["play_skill", "charge_skill", "bank", "discard",
		"concentrate", "end_turn"].has(kind)
	match kind:
		"approach":
			result = _cmd_approach(String(command.get("mode", "")))
		"play_skill":
			result = _cmd_play_skill(String(command.get("skill_id", "")))
		"charge_skill":
			result = _cmd_charge_skill(String(command.get("skill_id", "")),
				String(command.get("source", "hand")), int(command.get("index", -1)))
		"bank":
			result = _cmd_bank(int(command.get("hand_index", -1)))
		"discard":
			result = _cmd_discard(int(command.get("hand_index", -1)))
		"concentrate":
			result = _cmd_concentrate(String(command.get("humour", "")))
		"end_turn":
			result = _cmd_end_turn()
		"slip_away":
			result = _cmd_slip_away()
		_:
			result = _fail("unknown command '%s'" % command.get("type", ""))
	if result["ok"]:
		if locks_approach:
			approach_locked = true
		log.record(turn, command)
	return result


func can_approach() -> bool:
	return not approach_locked and turn == 1


func _cmd_approach(mode: String) -> Dictionary:
	if not can_approach():
		return _fail("the moment for a clever entrance has passed")
	if not APPROACHES.has(mode):
		return _fail("unknown approach '%s'" % mode)
	var cost: Dictionary = APPROACHES[mode]["cost"]
	if not can_pay(cost):
		return _fail("not enough energy to %s" % mode)
	_pay(cost)
	approach = mode
	approach_locked = true
	match mode:
		"stalk":
			hidden = true
			sharpened = true
			_events.append("approach_stalk")
		"ambush":
			enemy_hp -= 3
			_enemy_enraged = true
			_events.append("approach_ambush")
			_check_end()
		"case":
			for i in 2:
				if not deck.is_empty():
					hand.append(deck.pop_back())  # study allows over-draw
			# Every approach has a price (owner rule): the moment spent
			# studying is a moment given — it studies you back.
			_case_watched = true
			_events.append("approach_case")
		"ward":
			player_block += 4
			_ward_holds = true
			_events.append("approach_ward")
	return {"ok": true, "error": ""}


# ------------------------------------------------------------------ commands

## Feed one energy card onto a skill (owner mechanic 2026-08-01): skills are
## powered a card at a time and only fire once fully powered. The card is
## spent immediately; power on the card persists across turns until the
## skill is used.
func _cmd_charge_skill(skill_id: String, source: String, index: int) -> Dictionary:
	if statuses.get("loafed", 0) > 0:
		return _fail("loafed: all paws are committed")
	if not catalog.skills.has(skill_id):
		return _fail("unknown skill '%s'" % skill_id)
	var def: Dictionary = catalog.skills[skill_id]
	if def.get("instinct", false):
		return _fail("instincts need no powering")
	var s := skill_state(skill_id)
	if s.is_empty():
		return _fail("skill '%s' is not equipped" % skill_id)
	if s["jammed_turns"] > 0:
		return _fail("skill '%s' is jammed" % skill_id)
	if s["charges_left"] <= 0:
		return _fail("skill '%s' has no charges left" % skill_id)
	if source != "hand" and source != "bank":
		return _fail("unknown energy source '%s'" % source)
	var pool: Array = hand if source == "hand" else banked
	if index < 0 or index >= pool.size():
		return _fail("no card at %s index %d" % [source, index])
	var card: Dictionary = catalog.energy_cards[pool[index]]
	var humour := String(card["humour"])
	var remaining := remaining_cost(skill_id)
	# A wild (mysticism) card powers whatever the skill still needs.
	var target_humour := humour
	if not remaining.has(target_humour):
		if humour == WILD_HUMOUR and not remaining.is_empty():
			target_humour = remaining.keys()[0]
		else:
			return _fail("'%s' has no use for %s" % [def["name"], humour])
	if paws_left < 1:
		return _fail("no paws left this turn")
	paws_left -= 1
	var powered: Dictionary = s["powered"]
	powered[target_humour] = int(powered.get(target_humour, 0)) + int(card["value"])
	spent.append(pool[index])
	pool.remove_at(index)
	flags["energy_paid"] = int(flags["energy_paid"]) + 1
	if stealth_threshold > 0 and not spotted and humour == "ferocity":
		alarm += int(card["value"])  # loud energy is loud however it's spent
		if alarm >= stealth_threshold:
			spotted = true
			_events.append("spotted")
	return {"ok": true, "error": ""}


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
	# Anything that costs nothing (instinct, or discounted to free by the
	# environment) is once per turn — free never means spam.
	if cost.is_empty() and not is_instinct and state.get("free_used", false):
		return _fail("'%s' needs a breath between free uses" % skill_id)
	# Power already fed onto the card counts first; any remainder is paid
	# from hand/bank in one go (equivalent to charging it fully right now)
	# — so the auto-payment consumes one paw per card it places.
	var remaining := remaining_cost(skill_id) if not is_instinct else cost
	if not can_pay(remaining):
		return _fail("not enough energy for '%s'" % skill_id)
	var cards_needed := _pay_card_count(remaining)
	if cards_needed > paws_left:
		return _fail("not enough paws for '%s' this turn" % skill_id)
	paws_left -= cards_needed
	_pay(remaining)
	if not is_instinct:
		state["powered"] = {}  # the stored energy discharges into the strike
	if cost.is_empty() and not is_instinct:
		state["free_used"] = true
	if stealth_threshold > 0 and not spotted and remaining.has("ferocity"):
		alarm += int(remaining["ferocity"])  # loud cards raise the alarm
		if alarm >= stealth_threshold:
			spotted = true
			_events.append("spotted")
	if is_instinct:
		instinct_used = true
	else:
		state["charges_left"] -= 1
	var used: Dictionary = flags["skills_used"]
	used[skill_id] = int(used.get(skill_id, 0)) + 1
	_journal.append("Ash: %s." % def["name"])
	_apply_effects(def.get("effects", []))
	_check_end()
	if outcome == Outcome.VICTORY and flags["killing_skill"] == "":
		flags["killing_skill"] = skill_id
	return {"ok": true, "error": ""}


## Retreat is never free (owner rule 2026-08-02, sharpened 2026-08-03): the
## night gets one last word. Turning your back plays out the enemy's WHOLE
## telegraphed move — not only the ones that target health, which is why
## slipping away from a thief or an unraveller used to cost exactly nothing.
## Block still counts, and from hiding you exit clean.
func _cmd_slip_away() -> Dictionary:
	if no_retreat:
		return _fail("there is no slipping away from this one")
	if not hidden:
		_events.append("parting_shot")
	_enemy_act()
	if outcome != Outcome.ONGOING:
		return {"ok": true, "error": ""}
	outcome = Outcome.DEFEAT if player_hp <= 0 else Outcome.RETREATED
	return {"ok": true, "error": ""}


func _cmd_bank(hand_index: int) -> Dictionary:
	if hand_index < 0 or hand_index >= hand.size():
		return _fail("no card at hand index %d" % hand_index)
	if banked.size() >= BANK_LIMIT:
		return _fail("bank is full")
	if paws_left < 1:
		return _fail("no paws left this turn")
	paws_left -= 1
	banked.append(hand[hand_index])
	hand.remove_at(hand_index)
	return {"ok": true, "error": ""}


## Toss energy you don't want (owner mechanic 2026-08-01). Free — but the
## card is GONE until the long rest at home, like all spent energy.
func _cmd_discard(hand_index: int) -> Dictionary:
	if hand_index < 0 or hand_index >= hand.size():
		return _fail("no card at hand index %d" % hand_index)
	spent.append(hand[hand_index])
	hand.remove_at(hand_index)
	return {"ok": true, "error": ""}


## Concentrate (owner mechanic 2026-08-01): give up the whole turn to will
## one spent energy back. The chosen humour's best spent card goes to the
## top of the deck, then the enemy acts — this IS your turn.
func _cmd_concentrate(humour: String) -> Dictionary:
	if statuses.get("loafed", 0) > 0:
		return _fail("loafed: all paws are committed")
	var best_index := -1
	var best_value := -1
	for i in spent.size():
		var card: Dictionary = catalog.energy_cards[spent[i]]
		if card["humour"] == humour and int(card["value"]) > best_value:
			best_index = i
			best_value = int(card["value"])
	if best_index < 0:
		return _fail("no spent %s to will back" % humour)
	deck.push_back(spent[best_index])  # top of the deck: first draw next turn
	spent.remove_at(best_index)
	_events.append("concentrated")
	return _cmd_end_turn()


func _cmd_end_turn() -> Dictionary:
	_enemy_act()
	# A scripted fight ends when the script says so, not when the grind does.
	if outcome == Outcome.ONGOING and doom_turn > 0 and turn >= doom_turn:
		player_hp = 0
		outcome = Outcome.DEFEAT
		_events.append("undone")
		_journal.append("It finishes what it came to do.")
	if outcome != Outcome.ONGOING:
		return {"ok": true, "error": ""}
	# --- start of next player turn ---
	turn += 1
	paws_left = paw_limit
	if turn == 8:
		_events.append("night_presses")
	if _ward_holds:
		_ward_holds = false  # a stitched ward outlasts the moment
	else:
		player_block = 0
	instinct_used = false
	for s in skills:
		s["free_used"] = false
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
	# ONE energy recovers per turn (owner rule 2026-08-01) — the hand grows
	# slowly; the opening three plus one a turn is the whole allowance.
	_draw_one()
	if sunbeam_turns.has(turn) and not spent.is_empty():
		# A patch of sun: one spent card returns to the bottom of the deck —
		# the fuel gauge ticks back up.
		var index := rng.pick_index(spent.size())
		deck.push_front(spent[index])
		spent.remove_at(index)
		_events.append("sunbeam")
	return {"ok": true, "error": ""}


# ------------------------------------------------------------------ internals

## How many cards _pay() would consume for this cost — shares the planner,
## so paw checks can run before anything mutates.
func _pay_card_count(cost: Dictionary) -> int:
	return _payment_plan(cost)["count"]


func _pay(cost: Dictionary) -> void:
	var plan := _payment_plan(cost)
	var by_pool := {"hand": [], "banked": []}
	for pick: Dictionary in plan["picks"]:
		by_pool[pick["pool"]].append(pick["index"])
	for pool_name in by_pool:
		var pool: Array = hand if pool_name == "hand" else banked
		var indices: Array = by_pool[pool_name]
		indices.sort()
		indices.reverse()
		for i in indices:
			spent.append(pool[i])
			pool.remove_at(i)
			flags["energy_paid"] = int(flags["energy_paid"]) + 1


## Plan which cards would pay a cost, without mutating anything. Specific
## humours pay with their own cards first (largest first, hand before bank,
## so the fewest cards are spent and saved combos survive); wilds then cover
## the remaining shortfalls, biggest shortfall first so discrete wild cards
## are not wasted on small gaps. A cost keyed WILD_HUMOUR only accepts true
## wilds. Returns {covered: bool, count: int, picks: [{pool, index}]}.
func _payment_plan(cost: Dictionary) -> Dictionary:
	var used := {"hand": {}, "banked": {}}
	var picks: Array = []
	var shortfalls: Array = []
	for humour in cost:
		var remaining := int(cost[humour])
		if humour != WILD_HUMOUR:
			remaining = _plan_spend(String(humour), remaining, used, picks)
		if remaining > 0:
			shortfalls.append(remaining)
	shortfalls.sort()
	shortfalls.reverse()
	var covered := true
	for shortfall: int in shortfalls:
		if _plan_spend(WILD_HUMOUR, shortfall, used, picks) > 0:
			covered = false
	return {"covered": covered, "count": picks.size(), "picks": picks}


## Greedily mark unused cards of one humour against `remaining`, recording
## picks; returns what is still owed after every matching card is considered.
func _plan_spend(humour: String, remaining: int, used: Dictionary,
		picks: Array) -> int:
	for pool_name in ["hand", "banked"]:
		if remaining <= 0:
			break
		var pool: Array = hand if pool_name == "hand" else banked
		var candidates: Array = []
		for i in pool.size():
			if used[pool_name].has(i):
				continue
			var card: Dictionary = catalog.energy_cards[pool[i]]
			if card["humour"] == humour:
				candidates.append({"index": i, "value": int(card["value"])})
		candidates.sort_custom(func(a, b): return a["value"] > b["value"])
		for c: Dictionary in candidates:
			if remaining <= 0:
				break
			remaining -= c["value"]
			used[pool_name][c["index"]] = true
			picks.append({"pool": pool_name, "index": c["index"]})
	return maxi(remaining, 0)


func _apply_effects(effects: Array) -> void:
	for effect in effects:
		match effect.get("type", ""):
			"damage":
				var amount := int(effect["amount"])
				if sharpened:
					amount += 1
					sharpened = false
					_events.append("sharpened_strike")
				amount = mini(amount, maxi(enemy_hp, 0))
				enemy_hp -= amount
				_journal.append("  %d damage." % amount)
			"block":
				player_block += int(effect["amount"])
				_journal.append("  Guard +%d (now %d)." % [
					int(effect["amount"]), player_block])
			"heal":
				var before := player_hp
				player_hp = mini(player_hp + int(effect["amount"]), player_max_hp)
				_journal.append("  Heal %d (now %d)." % [player_hp - before, player_hp])
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
				# Not an assert: asserts vanish in release builds and would
				# turn a typo'd content effect into a silent no-op on-device.
				push_error("unknown effect type '%s'" % effect.get("type", ""))


func _enemy_act() -> void:
	if hidden:
		# Stalked: its first move plays out against an empty shadow.
		hidden = false
		_intent_index += 1
		_events.append("hidden_wasted")
		return
	var rage_bonus := 2 if _enemy_enraged else 0
	_enemy_enraged = false
	if _case_watched:
		rage_bonus += 1
		_case_watched = false
	# The night presses (pacing rule 2026-08-02): from turn 8 every enemy
	# strike hits harder — fights END by ~turn 10, one way or the other.
	rage_bonus += maxi(turn - 7, 0) * 2
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
	var name := String(intent["name"])
	match intent["target"]:
		"health":
			# mode "pierce": the hit ignores block entirely — the anti-turtle
			# tool (2026-08-03). Turtling must have a counter somewhere or
			# the defender line wins everything (sim pass 4).
			var swing := int(intent["amount"]) + rage_bonus
			var blocked := 0 if intent.get("mode", "") == "pierce" else mini(player_block, swing)
			var lost := _hurt(swing - blocked)
			_journal.append("%s: %s — %d damage%s" % [
				catalog.enemies[enemy_id]["name"], name, lost,
				" (%d blocked)" % blocked if blocked > 0 else ""])
			if lost > 0 and not channel.is_empty():
				channel = {}  # a purr you can't finish
				_journal.append("The purr breaks.")
		"skills":
			var targets: Array = skills.filter(
				func(s): return s["charges_left"] > 0 and s["jammed_turns"] == 0)
			if targets.is_empty():
				_journal.append("%s: %s — nothing left to unpick." % [
					catalog.enemies[enemy_id]["name"], name])
			else:
				var victim: Dictionary = targets[rng.pick_index(targets.size())]
				var victim_name := String(catalog.skills[victim["id"]]["name"])
				if intent.get("mode", "jam") == "burn":
					victim["charges_left"] -= 1
					_journal.append("%s: %s — burns a use of %s." % [
						catalog.enemies[enemy_id]["name"], name, victim_name])
				else:
					victim["jammed_turns"] = int(intent.get("amount", 1))
					_journal.append("%s: %s — jams %s for %d." % [
						catalog.enemies[enemy_id]["name"], name, victim_name,
						int(intent.get("amount", 1))])
		"hand":
			# Loafed is the ONE guard against theft (owner rule 2026-08-03):
			# block soaks damage, but nothing used to answer a thief, so a
			# hand-attacker was strictly unanswerable. A cat folded over its
			# own paws has nothing loose to take.
			if statuses.get("loafed", 0) > 0:
				_events.append("loaf_guarded")
				_journal.append("%s: %s — finds nothing loose to take." % [
					catalog.enemies[enemy_id]["name"], name])
			else:
				var taken: Array[String] = []
				for i in int(intent["amount"]):
					var pool: Array = hand if not hand.is_empty() else banked
					if pool.is_empty():
						break
					var index := rng.pick_index(pool.size())
					taken.append(String(catalog.energy_cards[pool[index]]["name"]))
					spent.append(pool[index])
					pool.remove_at(index)
					flags["hand_lost"] = int(flags["hand_lost"]) + 1
				_journal.append("%s: %s — takes %s." % [
					catalog.enemies[enemy_id]["name"], name,
					", ".join(taken) if not taken.is_empty() else "nothing (empty paws)"])
	_check_end()


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
