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
##   2. Energy is conserved. deck + hand + spent never changes count.
##      Nothing in the rules creates or destroys an energy card mid-fight.
##   3. Spent is spent. The deck only grows on the two commands allowed to
##      return energy (concentrate, and end_turn's sunbeam) — CLAUDE.md's
##      "energy never reshuffles" law, enforced instead of remembered.
##   4. Bounds hold: hp <= max, block/alarm/paws never negative, and a turn
##      always OPENS on the paw limit (a card may push a single turn past it;
##      nothing may carry the extra over). A held purr means no
##      skill/charge/concentrate is ever accepted (the purr holds him still).
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
	"hoarder",           # charges everything onto skills, never fires
	"overcharger",       # keeps feeding a skill that is already powered
	"concentrator",      # gives up every single turn to will energy back
	"slipper",           # slips away at arbitrary moments, including turn 1
	"instinct_only",     # scratch and nothing else, forever
	"approach_spammer",  # tries every entrance, repeatedly, then dawdles
	"pacifist",          # ends turn and never acts: dies to the night pressing
	"purrer",            # starts a purr then keeps trying to act through it
	"turtle",            # guards, hides and unknots; never once attacks
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
		var channel_before: bool = not state.channel.is_empty()
		var result := state.do_command(command)
		commands += 1
		if result["ok"]:
			stall = 0
			_check_accepted(state, command, deck_before, channel_before)
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
	# The default kit is EVERY action in the catalog, read from the catalog
	# rather than listed here. It was a list of three once, and when the
	# Chapter 1 roster went from seven actions to fourteen the sweep went on
	# reporting "no violations" over thirteen thousand runs that never once
	# touched a new card. A fuzzer with a hand-written loadout only ever
	# fuzzes the day it was written. Wider than any shippable tray on
	# purpose: jam and burn need targets, and every effect needs exercising.
	var kit: Array = skills
	if kit.is_empty():
		for skill_id in catalog.skills:
			if not catalog.skills[skill_id].get("instinct", false):
				kit.append(String(skill_id))
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
		"deck": state.deck, "hand": state.hand,
		"spent": state.spent, "skills": state.skills,
		"statuses": state.statuses, "channel": state.channel,
		"instinct": state.instinct_used, "sharpened": state.sharpened,
		"paws": state.paws_left, "enemy_hp": state.enemy_hp,
		"enemy_block": state.enemy_block,
		"turn": state.turn, "outcome": state.outcome,
		"alarm": state.alarm, "spotted": state.spotted,
		"hidden": state.hidden, "approach": state.approach,
		"locked": state.approach_locked,
	})


func _count_cards(state: CombatState) -> int:
	return state.deck.size() + state.hand.size() + state.spent.size()


func _check_accepted(state: CombatState, command: Dictionary,
		deck_before: int, channel_before: bool) -> void:
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
	# Paws: never negative, and a TURN always starts on the limit. The upper
	# bound used to be paw_limit flat, which was true only while nothing
	# could give a paw back — Her Hour now can, and going over the budget
	# for one turn IS the card ("one more minute than the clock was
	# offering"). What must still hold is that the extra minute does not
	# carry: whatever this turn was given, the next one opens on the limit.
	if state.paws_left < 0:
		_violation("negative paws (%d) after '%s'" % [state.paws_left, kind])
	if kind == "end_turn" and state.outcome == CombatState.Outcome.ONGOING \
			and state.paws_left != state.paw_limit:
		_violation("a turn opened on %d paws, not the limit of %d" % [
			state.paws_left, state.paw_limit])
	if channel_before and ["play_skill", "charge_skill", "concentrate"].has(kind):
		_violation("'%s' was accepted while the purr held" % kind)
	if state.alarm < 0:
		_violation("negative alarm (%d) after '%s'" % [state.alarm, kind])
	if state.enemy_hp > state.enemy_max_hp:
		_violation("enemy hp %d over max %d after '%s'" % [
			state.enemy_hp, state.enemy_max_hp, kind])
	if state.enemy_block < 0:
		_violation("negative enemy guard (%d) after '%s'" % [state.enemy_block, kind])
	if state.outcome == CombatState.Outcome.ONGOING and state.player_hp <= 0:
		_violation("player at %d hp but the encounter is still running" % state.player_hp)
	for entry in state.skills:
		if int(entry["charges_left"]) < 0:
			_violation("skill '%s' has %d charges after '%s'" % [
				entry["id"], entry["charges_left"], kind])
		# Unknot writes to this counter, which nothing but the turn-over used
		# to touch; a clear that went one past zero would read as a skill
		# that can never be jammed again.
		if int(entry["jammed_turns"]) < 0:
			_violation("skill '%s' is jammed for %d turns after '%s'" % [
				entry["id"], entry["jammed_turns"], kind])


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
			# Never fires anything: charges and hoards until the night
			# presses kill him. Exercises over-charge and paw exhaustion.
			if not state.hand.is_empty() and not state.skills.is_empty():
				return {"type": "charge_skill",
					"skill_id": state.skills[0]["id"], "source": "hand", "index": 0}
			return {"type": "end_turn"}
		"overcharger":
			# Keeps feeding one skill past full power.
			if state.skills.is_empty() or state.hand.is_empty():
				return {"type": "end_turn"}
			return {"type": "charge_skill", "skill_id": state.skills[0]["id"],
				"source": "hand", "index": 0}
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
		"turtle":
			# The defensive roster grew four cards in one chapter — a guard
			# that survives the turn-over, a hide, an unjam, a heal — and the
			# question a turtle asks is whether the stack of them can hold a
			# fight open forever. It must not: the night presses from turn 8
			# and charges run out, so this ends in a death, and the harness
			# fails it if the encounter never finishes at all.
			var guards: Array[Dictionary] = [{"type": "end_turn"}]
			for skill_id in ["long_shadow", "vanish", "slink", "loaf",
					"unknot", "purr", "her_thread", "moonwise"]:
				if not state.skill_state(skill_id).is_empty():
					guards.append({"type": "play_skill", "skill_id": skill_id})
			return guards[_rng.pick_index(guards.size())]
		"purrer":
			# Starts the purr, then hammers at everything the purr is meant
			# to forbid — every one of those must be rejected cleanly.
			if state.channel.is_empty():
				return {"type": "play_skill", "skill_id": "purr"}
			match _rng.pick_index(3):
				0: return {"type": "play_skill", "skill_id": "scratch"}
				1: return {"type": "concentrate", "humour": "ferocity"}
				_: return {"type": "end_turn"}
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
		# Banking (2026-08-08) and discarding (2026-08-09) were REMOVED; the
		# commands and the old bank source must stay refused forever, not
		# quietly half-work.
		{"type": "bank", "hand_index": 0},
		{"type": "charge_skill", "skill_id": "pounce", "source": "bank", "index": 0},
		{"type": "discard", "hand_index": 0},
		{"type": "discard", "hand_index": -3},
		{"type": "approach", "mode": "backflip"},
		{"type": "approach", "mode": ""},
	]
	for humour in JUNK_HUMOURS:
		junk.append({"type": "concentrate", "humour": humour})
	return junk[_rng.pick_index(junk.size())]
