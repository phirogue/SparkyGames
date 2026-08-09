class_name CrossingState
extends RefCounted
## The Long Way Round — push-your-luck traversal (minigames.md #5).
## Lineage: Can't Stop / Quacks. Pure rules, seeded, simmable.
##
## The owner's design contract: **the same energy deck, different actions.**
## No new board and no new resources — a crossing runs on the battle
## screen's skeleton (same hand, same paws, same spent pile). Only the
## action row and the "opponent" change: the opponent zone becomes a route
## track and a posted GUST, the humour the storm currently owns.
##
##   PRESS ON    draw 1, advance 1 per card in hand — but if ANY card in
##               hand matches the gust you slip: lose that advance back
##               (never below what you sheltered), take the hazard, and the
##               storm takes the matching cards into the spent pile.
##   PICK THE LINE (1 paw) peek the next gust before committing.
##   SHELTER     bank the progress so far, post a fresh gust, end the turn.
##   SLIP AWAY   abandon the crossing (walk-away).
##
## Spent cards stay spent into the prowl's next encounter: traversal and
## combat share one stamina, which is the point. The night presses from
## turn 8 exactly as in combat — gusts double.

## Shipped default; the live value is the per-state `night_presses_turn`
## field, read from data/rules.json `minigames.crossing.night_presses_turn`.
const NIGHT_PRESSES_TURN := 8
var night_presses_turn: int = NIGHT_PRESSES_TURN

var crossing: Dictionary = {}
var length: int = 10
var progress: int = 0
var sheltered: int = 0          # progress that can no longer be lost
var gust: String = ""           # humour the storm owns this turn
var next_gust: String = ""      # revealed only by Pick the Line
var peeked: bool = false
var hazard: int = 1
var turn: int = 1
var paws: int = 3
var paw_limit: int = 3
var player_hp: int = 10
var player_max_hp: int = 10
var deck: Array = []
var hand: Array = []
var spent: Array = []
var outcome: int = Minigame.Outcome.ONGOING
var rng: CoreRng
var log: CommandLog

var _catalog: Catalog
var _gust_weights: Dictionary = {}
var _script: Array = []         # authored gust order, if the data pins one
var _script_index: int = 0
var _events: Array[String] = []


static func create(catalog: Catalog, seed_value: int,
		crossing_data: Dictionary, config: Dictionary = {}) -> CrossingState:
	var state := CrossingState.new()
	state._catalog = catalog
	state.crossing = crossing_data
	state.rng = CoreRng.new(seed_value)
	state.log = CommandLog.new()
	state.length = int(crossing_data.get("length", 10))
	state.hazard = int(crossing_data.get("hazard", 1))
	state._script = crossing_data.get("gust_script", []).duplicate()
	state._gust_weights = crossing_data.get("gust_weights", {})
	# Shared dials: the crossing spends the same paws and opens the same hand
	# as a fight, because it IS a fight against weather (owner framing: same
	# energy deck, different actions — no new resources).
	var dials := catalog.rules
	state.night_presses_turn = dials.count("minigames.crossing.night_presses_turn")
	state.player_max_hp = int(config.get("player_max_hp", config.get("player_hp", 10)))
	state.player_hp = int(config.get("player_hp", state.player_max_hp))
	state.paw_limit = int(config.get("paws", dials.count("combat.paws")))
	state.paws = state.paw_limit
	state.deck = Array(config.get("deck", [])).duplicate()
	if config.get("shuffle", true):
		state.rng.shuffle(state.deck)
	for i in mini(int(config.get("opening_hand", dials.count("combat.opening_hand"))),
			state.deck.size()):
		state.hand.append(state.deck.pop_back())
	state.gust = state._roll_gust()
	return state


## The storm's next humour: an authored script when the data pins one (so a
## tutorial crossing can promise what it teaches — law 6), otherwise a
## weighted roll off the seeded stream.
func _roll_gust() -> String:
	if not _script.is_empty():
		var picked := String(_script[_script_index % _script.size()])
		_script_index += 1
		return picked
	if _gust_weights.is_empty():
		return Catalog.HUMOURS[rng.pick_index(Catalog.HUMOURS.size())]
	var pool: Array[String] = []
	for humour in _gust_weights:
		for _i in int(_gust_weights[humour]):
			pool.append(String(humour))
	if pool.is_empty():
		return Catalog.HUMOURS[rng.pick_index(Catalog.HUMOURS.size())]
	return pool[rng.pick_index(pool.size())]


## The cards in hand the storm would take right now. The player can see this
## before pressing — the gamble is informed, which is what makes it a
## decision rather than a coin toss.
func exposed_cards() -> Array[int]:
	var exposed: Array[int] = []
	for i in hand.size():
		if String(_catalog.energy_cards.get(hand[i], {}).get("humour", "")) == gust:
			exposed.append(i)
	return exposed


func at_risk() -> bool:
	return not exposed_cards().is_empty()


# ------------------------------------------------------------------ commands

func do_command(command: Dictionary) -> Dictionary:
	if Minigame.is_over(outcome):
		return _fail("the crossing is behind you")
	var result: Dictionary
	match String(command.get("type", "")):
		"press_on":
			result = _cmd_press_on()
		"pick_line":
			result = _cmd_pick_line()
		"shelter":
			result = _cmd_shelter()
		"slip_away":
			result = _cmd_slip_away()
		_:
			result = _fail("unknown command '%s'" % command.get("type", ""))
	if result["ok"]:
		log.record(turn, command)
	return result


func _cmd_press_on() -> Dictionary:
	if not deck.is_empty():
		hand.append(deck.pop_back())
	var gain := hand.size()
	if gain <= 0:
		_check_exhausted()
		return _fail("nothing in hand to move on")
	var exposed := exposed_cards()
	if exposed.is_empty():
		progress += gain
		_events.append("advanced")
		if progress >= length:
			progress = length
			outcome = Minigame.Outcome.SUCCESS
			_events.append("crossed")
		return {"ok": true, "error": "", "slipped": false, "gain": gain}
	# Slipped. The advance is given back (never below what was sheltered),
	# the hazard lands, and the storm keeps the cards it caught.
	progress = maxi(sheltered, progress - gain)
	player_hp -= hazard
	for i in range(exposed.size() - 1, -1, -1):
		spent.append(hand[exposed[i]])
		hand.remove_at(exposed[i])
	_events.append("slipped")
	_check_exhausted()
	if player_hp <= 0:
		player_hp = 0
		# Foundering is a PARTIAL outcome, not a death: the crossing beat
		# you, the story picks it up on the near bank. No game-overs here.
		outcome = Minigame.Outcome.PARTIAL
		_events.append("foundered")
	return {"ok": true, "error": "", "slipped": true, "lost": gain}


func _cmd_pick_line() -> Dictionary:
	if paws < 1:
		return _fail("no paws left this turn")
	if peeked:
		return _fail("you have already read the sky this turn")
	paws -= 1
	peeked = true
	if next_gust == "":
		next_gust = _roll_gust()
	_events.append("peeked")
	return {"ok": true, "error": "", "next_gust": next_gust}


## Sheltering BURNS a card — you wait the gust out on your own stamina.
##
## This is the design doc's "cards spent to slips/shelters go to the SAME
## spent pool", and leaving it out made the module unfinishable: cards only
## ever left the hand on a slip, so a careful player's hand grew until it
## held every humour, every gust matched something, and there was no safe
## press left. Free shelters also meant infinite gust-rerolling. Burning a
## card makes waiting cost what pressing costs, and guarantees the crossing
## ends: hand and deck now only ever shrink. Found by tests/minigames.gd.
func _cmd_shelter() -> Dictionary:
	if hand.is_empty():
		return _fail("nothing left in hand to wait it out with")
	# The storm takes what it was reaching for; failing that, the top card.
	var exposed := exposed_cards()
	var index: int = exposed[0] if not exposed.is_empty() else 0
	spent.append(hand[index])
	hand.remove_at(index)
	sheltered = progress
	# A peeked gust is the one that actually posts — Pick the Line must not
	# lie, or the aid is worthless.
	gust = next_gust if next_gust != "" else _roll_gust()
	next_gust = ""
	peeked = false
	turn += 1
	paws = paw_limit
	if turn >= night_presses_turn:
		hazard = int(crossing.get("hazard", 1)) * 2
		_events.append("night_presses")
	_events.append("sheltered")
	_check_exhausted()
	return _ok()


## Out of cards and out of deck is the end of the crossing, not a stall.
## Without this the player could sit on an empty hand forever, and a beat
## that is supposed to last 30-90 seconds would have no end condition at all.
func _check_exhausted() -> void:
	if outcome != Minigame.Outcome.ONGOING:
		return
	if hand.is_empty() and deck.is_empty():
		outcome = Minigame.Outcome.PARTIAL if sheltered > 0 else Minigame.Outcome.WALKED
		_events.append("exhausted")


func _cmd_slip_away() -> Dictionary:
	outcome = Minigame.Outcome.WALKED if sheltered <= 0 else Minigame.Outcome.PARTIAL
	_events.append("walked_away")
	return _ok()


# ------------------------------------------------------------------ results

## What the crossing hands back to the prowl: the pool it burned through.
## Traversal and combat share one stamina, so this feeds carryover directly.
func carryover() -> Dictionary:
	return {
		"hp": player_hp,
		"deck": deck + hand,
		"spent": spent.duplicate(),
	}


func rewards() -> Dictionary:
	return crossing.get("rewards", {})


## What this session actually PAYS — the reward table only on a dry arrival.
func earned_rewards() -> Dictionary:
	return rewards() if outcome == Minigame.Outcome.SUCCESS else {}


func take_events() -> Array[String]:
	var events := _events.duplicate()
	_events.clear()
	return events


func _ok() -> Dictionary:
	return {"ok": true, "error": ""}


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
