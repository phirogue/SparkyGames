class_name ChaosPlay
extends RefCounted
## Irregular-play harness: plays combat the way real players actually do
## when they are lost, bored, greedy, or actively trying to break the game,
## and checks the rules never break with them.
##
## This is NOT the balance sim. simulate.gd asks "is this fight fair?" with
## bots that play sensibly. ChaosPlay asks "can this fight be put into a
## state it should not be in?" — and it plays badly on purpose to find out.
##
## Every command, legal or not, is checked against invariants that must hold
## no matter what the player does:
##
##   1. A REJECTED command changes nothing. This is the big one: half-applied
##      actions are how "I got a free card" bugs happen.
##   2. Energy is conserved. deck + hand + banked + spent never changes count.
##      Nothing in the rules creates or destroys an energy card mid-fight.
##   3. Spent is spent. The deck only grows on the two commands allowed to
##      return energy (concentrate, and end_turn's sunbeam) — CLAUDE.md's
##      "energy never reshuffles" law, enforced instead of remembered.
##   4. Bounds hold: hp <= max, block/alarm/paws never negative, paws never
##      exceed the limit, the bank never exceeds BANK_LIMIT.
##   5. A finished encounter is finished. No command is accepted afterwards.
##   6. The run terminates. No sequence of commands may spin forever.
##   7. The log replays. Same seed + same commands = the same final state,
##      which is what makes a bug report reproducible at all.
##
## Usage: game/tests/fuzz.gd (full sweep) and tests/unit/test_chaos.gd (a
## small deterministic slice that runs with every commit).

const TURN_CAP := 30
const COMMAND_CAP := 400
## After this many rejections in a row a persona is force-ended, so a bot
## that refuses to ever end its turn still terminates (invariant 6 is about
## the RULES not looping, not about the bot being sensible).
const STALL_LIMIT := 12

## Ways to play badly. Each is a real player pathology, not random noise.
const PERSONAS: Array[String] = [
	"random_legal",      # taps anything legal, forever
	"chaos_illegal",     # sends malformed and illegal commands too
	"hoarder",           # banks and charges everything, never fires
	"discarder",         # throws the whole hand away every turn
	"overcharger",       # keeps feeding a skill that is already powered
	"concentrator",      # gives up every single turn to will energy back
	"slipper",           # slips away at arbitrary moments, including turn 1
	"instinct_only",     # scratch and nothing else, forever
	"approach_spammer",  # tries every entrance, repeatedly, then dawdles
	"pacifist",          # ends turn and never acts: dies to the night pressing
]

## Every humour plus junk, so concentrate is asked for things that cannot
## exist as well as things that can.
const JUNK_HUMOURS: Array[String] = ["cheese", "", "Ferocity", "moonlight"]

var catalog: Catalog
var violations: Array[String] = []

var _label := ""
var _card_total := 0
## The bot's OWN randomness. It must never draw from state.rng: the game's
## stream is what shuffles the deck and picks the enemy's targets, so a bot
## sipping from it would shift every later roll and the replay check would
## fail on the harness rather than on the game.
var _rng: CoreRng


func _init(p_catalog: Catalog) -> void:
	catalog = p_catalog


## Plays one encounter with one persona at one seed. Returns a summary;
## anything wrong lands in `violations` (which accumulates across calls, so
## one harness instance can sweep a whole matrix and report once).
func play(encounter_id: String, persona: String, seed_value: int,
		skills: Array = []) -> Dictionary:
	_label = "%s / %s / seed %d" % [encounter_id, persona, seed_value]
	var config := build_config(encounter_id, skills)
	var state := CombatState.create(catalog, seed_value, config)
	# Derived from the run seed so a reported seed reproduces the bot's
	# choices too, but a stream of its own so the game's rolls are untouched.
	_rng = CoreRng.new(seed_value * 31 + 17)
	_card_total = _count_cards(state)
	var commands := 0
	var rejected := 0
	var stall := 0
	while state.outcome == CombatState.Outcome.ONGOING:
		if commands >= COMMAND_CAP:
			_violation("run did not terminate within %d commands" % COMMAND_CAP)
			break
		if state.turn > TURN_CAP:
			# Not a violation by itself — the night presses should have ended
			# this. It IS a violation if it happens with a sensible persona.
			state.do_command({"type": "slip_away"})
			break
		var command := _next_command(state, persona, stall)
		var before := _snapshot(state)
		var deck_before: int = state.deck.size()
		var result := state.do_command(command)
		commands += 1
		if result["ok"]:
			stall = 0
			_check_accepted(state, command, deck_before)
		else:
			rejected += 1
			stall += 1
			_check_rejected(state, command, before, result)
			if stall >= STALL_LIMIT:
				state.do_command({"type": "end_turn"})
				stall = 0
	_check_finished(state)
	_check_replay(state, config, seed_value)
	return {
		"outcome": state.outcome,
		"turns": state.turn,
		"commands": commands,
		"rejected": rejected,
		"violations": violations.size(),
	}


## The combat config for an encounter id, with a loadout wide enough that
## jam and burn intents have something to bite. Shared with fuzz.gd so the
## full sweep and the committed slice test the same thing.
func build_config(encounter_id: String, skills: Array = []) -> Dictionary:
	var encounter: Dictionary = catalog.encounters[encounter_id]
	var environment: Dictionary = catalog.environments.get(
		String(encounter.get("environment", "")), {})
	var kit: Array = skills if not skills.is_empty() \
		else ["pounce", "slink", "purr"]
	return {
		"player_hp": 10,
		"player_max_hp": 10,
		"deck": SaveService.DEFAULT_PROFILE["deck"].duplicate(),
		"skills": kit,
		"enemy": encounter["enemies"][0],
		"environment": environment,
	}


# -------------------------------------------------------------- invariants

## The fields a rejected command must leave exactly as it found them. Built
## in a fixed order so two snapshots of the same state stringify identically.
func _snapshot(state: CombatState) -> String:
	return JSON.stringify({
		"hp": state.player_hp, "block": state.player_block,
		"deck": state.deck, "hand": state.hand, "banked": state.banked,
		"spent": state.spent, "skills": state.skills,
		"statuses": state.statuses, "channel": state.channel,
		"instinct": state.instinct_used, "sharpened": state.sharpened,
		"paws": state.paws_left, "enemy_hp": state.enemy_hp,
		"turn": state.turn, "outcome": state.outcome,
		"alarm": state.alarm, "spotted": state.spotted,
		"hidden": state.hidden, "approach": state.approach,
		"locked": state.approach_locked,
	})


func _count_cards(state: CombatState) -> int:
	return state.deck.size() + state.hand.size() + state.banked.size() \
		+ state.spent.size()


func _check_accepted(state: CombatState, command: Dictionary,
		deck_before: int) -> void:
	var kind := String(command.get("type", ""))
	if _count_cards(state) != _card_total:
		_violation("'%s' changed the energy count: %d, was %d" % [
			kind, _count_cards(state), _card_total])
	if state.deck.size() > deck_before and kind != "concentrate" \
			and kind != "end_turn":
		_violation("'%s' put energy back into the deck — spent is spent" % kind)
	if state.player_hp > state.player_max_hp:
		_violation("hp %d over max %d after '%s'" % [
			state.player_hp, state.player_max_hp, kind])
	if state.player_block < 0:
		_violation("negative block (%d) after '%s'" % [state.player_block, kind])
	if state.paws_left < 0 or state.paws_left > state.paw_limit:
		_violation("paws %d outside 0..%d after '%s'" % [
			state.paws_left, state.paw_limit, kind])
	if state.banked.size() > state.bank_limit:
		_violation("bank holds %d, limit is %d" % [
			state.banked.size(), state.bank_limit])
	if state.alarm < 0:
		_violation("negative alarm (%d) after '%s'" % [state.alarm, kind])
	if state.enemy_hp > state.enemy_max_hp:
		_violation("enemy hp %d over max %d after '%s'" % [
			state.enemy_hp, state.enemy_max_hp, kind])
	if state.outcome == CombatState.Outcome.ONGOING and state.player_hp <= 0:
		_violation("player at %d hp but the encounter is still running" % state.player_hp)
	for entry in state.skills:
		if int(entry["charges_left"]) < 0:
			_violation("skill '%s' has %d charges after '%s'" % [
				entry["id"], entry["charges_left"], kind])


func _check_rejected(state: CombatState, command: Dictionary,
		before: String, result: Dictionary) -> void:
	if _snapshot(state) != before:
		_violation("rejected '%s' changed the state anyway (%s)" % [
			command.get("type", "?"), result.get("error", "")])
	if String(result.get("error", "")).is_empty():
		_violation("'%s' was rejected without saying why" % command.get("type", "?"))


## Once it is over it is over: nothing may be accepted, and the loser must
## actually be at zero rather than merely flagged.
func _check_finished(state: CombatState) -> void:
	if state.outcome == CombatState.Outcome.ONGOING:
		_violation("encounter never finished")
		return
	for command in [{"type": "end_turn"}, {"type": "slip_away"},
			{"type": "play_skill", "skill_id": "scratch"}]:
		var before := _snapshot(state)
		if state.do_command(command)["ok"]:
			_violation("'%s' was accepted after the encounter ended" % command["type"])
		if _snapshot(state) != before:
			_violation("a post-encounter '%s' changed the state" % command["type"])
	if state.outcome == CombatState.Outcome.DEFEAT and state.player_hp > 0:
		_violation("defeat recorded with %d hp left" % state.player_hp)
	if state.outcome == CombatState.Outcome.VICTORY and state.enemy_hp > 0:
		_violation("victory recorded with the enemy on %d hp" % state.enemy_hp)


## The seed plus the command log must reproduce the run exactly. Without
## this, "it only happened once" bug reports are unfixable.
func _check_replay(state: CombatState, config: Dictionary,
		seed_value: int) -> void:
	var replay := CombatState.create(catalog, seed_value, config)
	for entry in state.log.entries:
		if replay.outcome != CombatState.Outcome.ONGOING:
			break
		replay.do_command(entry)
	if _snapshot(replay) != _snapshot(state):
		_violation("replaying the command log did not reproduce the run")


func _violation(message: String) -> void:
	violations.append("%s: %s" % [_label, message])


# ---------------------------------------------------------------- personas

func _next_command(state: CombatState, persona: String, stall: int) -> Dictionary:
	# Whatever the persona wants, a bot stuck against the rules eventually
	# does the one thing that is always allowed.
	if stall >= STALL_LIMIT - 1:
		return {"type": "end_turn"}
	match persona:
		"random_legal":
			var options := _legal_commands(state)
			return options[_rng.pick_index(options.size())]
		"chaos_illegal":
			if _rng.pick_index(2) == 0:
				return _illegal_command(state)
			var options := _legal_commands(state)
			return options[_rng.pick_index(options.size())]
		"hoarder":
			# Never fires anything: banks, charges, and hoards until the
			# night presses kill him. Exercises full banks and over-charge.
			if state.banked.size() < state.bank_limit and not state.hand.is_empty():
				return {"type": "bank", "hand_index": 0}
			if not state.hand.is_empty() and not state.skills.is_empty():
				return {"type": "charge_skill",
					"skill_id": state.skills[0]["id"], "source": "hand", "index": 0}
			return {"type": "end_turn"}
		"discarder":
			if not state.hand.is_empty():
				return {"type": "discard", "hand_index": 0}
			return {"type": "end_turn"}
		"overcharger":
			# Keeps feeding one skill past full power, from either pool.
			if state.skills.is_empty():
				return {"type": "end_turn"}
			var source := "hand" if not state.hand.is_empty() else "bank"
			var pool: Array = state.hand if source == "hand" else state.banked
			if pool.is_empty():
				return {"type": "end_turn"}
			return {"type": "charge_skill", "skill_id": state.skills[0]["id"],
				"source": source, "index": 0}
		"concentrator":
			var humours := Catalog.HUMOURS
			return {"type": "concentrate",
				"humour": humours[_rng.pick_index(humours.size())]}
		"slipper":
			if _rng.pick_index(6) == 0:
				return {"type": "slip_away"}
			var options := _legal_commands(state)
			return options[_rng.pick_index(options.size())]
		"instinct_only":
			if not state.instinct_used:
				return {"type": "play_skill", "skill_id": "scratch"}
			return {"type": "end_turn"}
		"approach_spammer":
			# Approaches are turn-1 only and lock after any action; spamming
			# them proves the lock holds and the cost is paid exactly once.
			var modes := state.approaches.keys()
			if state.turn <= 1:
				return {"type": "approach",
					"mode": modes[_rng.pick_index(modes.size())]}
			return {"type": "end_turn"}
		"pacifist":
			return {"type": "end_turn"}
	return {"type": "end_turn"}


## Every command that is at least structurally sensible right now. Some will
## still be rejected (no paws, wrong humour) — that is deliberate: the
## rejection path needs exercising as much as the acceptance path.
func _legal_commands(state: CombatState) -> Array[Dictionary]:
	var options: Array[Dictionary] = [{"type": "end_turn"}]
	if not state.instinct_used:
		options.append({"type": "play_skill", "skill_id": "scratch"})
	for entry in state.skills:
		options.append({"type": "play_skill", "skill_id": entry["id"]})
		for i in state.hand.size():
			options.append({"type": "charge_skill", "skill_id": entry["id"],
				"source": "hand", "index": i})
		for i in state.banked.size():
			options.append({"type": "charge_skill", "skill_id": entry["id"],
				"source": "bank", "index": i})
	for i in state.hand.size():
		options.append({"type": "bank", "hand_index": i})
		options.append({"type": "discard", "hand_index": i})
	for humour in Catalog.HUMOURS:
		options.append({"type": "concentrate", "humour": humour})
	if state.can_approach():
		for mode in state.approaches:
			options.append({"type": "approach", "mode": mode})
	return options


## Malformed, out-of-range and nonsense commands. Every one of these must be
## refused with a reason and must not touch the state.
func _illegal_command(state: CombatState) -> Dictionary:
	var junk: Array[Dictionary] = [
		{},
		{"type": ""},
		{"type": "wibble"},
		{"type": "play_skill"},
		{"type": "play_skill", "skill_id": "a_skill_that_never_was"},
		{"type": "charge_skill", "skill_id": "scratch", "source": "hand", "index": 0},
		{"type": "charge_skill", "skill_id": "pounce", "source": "pocket", "index": 0},
		{"type": "charge_skill", "skill_id": "pounce", "source": "hand", "index": -1},
		{"type": "charge_skill", "skill_id": "pounce", "source": "hand", "index": 999},
		{"type": "bank", "hand_index": -1},
		{"type": "bank", "hand_index": state.hand.size() + 5},
		{"type": "discard", "hand_index": -3},
		{"type": "discard", "hand_index": 9999},
		{"type": "approach", "mode": "backflip"},
		{"type": "approach", "mode": ""},
	]
	for humour in JUNK_HUMOURS:
		junk.append({"type": "concentrate", "humour": humour})
	return junk[_rng.pick_index(junk.size())]
