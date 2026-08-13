class_name CrossingState
extends RefCounted
## The Long Way Home — get across, one decision at a time (minigames.md #5).
## Pure rules, seeded, simmable.
##
## OWNER 2026-08-13, the design this file now implements: "rather than the
## gust dynamic, it might be better for the character to continuously choose
## the energy in their hand to play based on the marked effects described.
## Eg: rushing forward requires so much energy, going around takes x amount,
## etc. If not enough energy is put on a chosen path there is a chance for a
## consequence."
##
## So a crossing is a short chain of DECISION POINTS. Each one is a thing in
## the road with its own picture, and two or three ways past it — each way
## named, and priced in a humour and an amount:
##
##   The gate, and no way under it
##     Rush it       3 Ferocity
##     Go round      2 Guile
##     Wait it out   1 anything
##
## You put cards from your paw ON the way you choose. Worth counts, not card
## count, and Moonlight pays for anything at its worth (the wild, as
## everywhere else). Then you go.
##
## Pay in full and you are past it clean. Pay SHORT and you still get past —
## no minigame in this game is a wall — but the shortfall is a rolled chance
## of the consequence: the hazard bites and you are hurt. The roll is off the
## seeded CoreRng, so a crossing still replays exactly and still sims (law 8),
## and the odds are posted on the board BEFORE the commit so the gamble is
## informed rather than a coin toss.
##
## Cards put on a way are spent, and stay spent into the prowl's next
## encounter. Traversal and combat share one stamina, which is the point.

## Shipped default; the live value is the per-state `night_presses_point`,
## read from data/rules.json `minigames.crossing.night_presses_turn`. From
## that point on the consequence bites double — the same escalation clock
## combat runs on.
const NIGHT_PRESSES_POINT := 8
## How much one point of shortfall is worth as a chance of the consequence,
## and the ceiling. Short by one is a real gamble; short by three is close to
## a promise. Both are dials in data/rules.json.
const SHORTFALL_RISK := 0.35
const RISK_CEILING := 0.95

var night_presses_point: int = NIGHT_PRESSES_POINT
var shortfall_risk: float = SHORTFALL_RISK

var crossing: Dictionary = {}
var points: Array = []          # the things in the road, in order
var at: int = 0                 # which one is in front of him
var paid: Array = []            # card ids put on the chosen way so far
var chosen: String = ""         # the way being paid for, "" if none yet
var revealed: bool = false      # has Read Ahead paid for the next point
var hazard: int = 1
var hurts: int = 0              # how many times a shortfall actually bit
var player_hp: int = 10
var player_max_hp: int = 10
var deck: Array = []
var hand: Array = []
var spent: Array = []
var paws: int = 3
var paw_limit: int = 3
var outcome: int = Minigame.Outcome.ONGOING
var rng: CoreRng
var log: CommandLog

const WILD_HUMOUR := "mysticism"

var _catalog: Catalog
var _events: Array[String] = []


static func create(catalog: Catalog, seed_value: int,
		crossing_data: Dictionary, config: Dictionary = {}) -> CrossingState:
	var state := CrossingState.new()
	state._catalog = catalog
	state.crossing = crossing_data
	state.rng = CoreRng.new(seed_value)
	state.log = CommandLog.new()
	state.points = crossing_data.get("points", []).duplicate(true)
	state.hazard = int(crossing_data.get("hazard", 1))
	# Shared dials: the crossing spends the same paws and opens the same hand
	# as a fight, because it IS one — against a street (owner framing: same
	# energy deck, different actions; no new resources).
	var dials := catalog.rules
	state.night_presses_point = dials.count("minigames.crossing.night_presses_turn")
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
	return state


# -------------------------------------------------------------- the road

## The thing in the road right now, or {} once he is home.
func point() -> Dictionary:
	return points[at] if at >= 0 and at < points.size() else {}


func next_point() -> Dictionary:
	return points[at + 1] if at + 1 < points.size() else {}


func length() -> int:
	return points.size()


## The ways past the thing in front of him: [{id, label, humour, cost}].
func ways() -> Array:
	return point().get("ways", [])


func way(way_id: String) -> Dictionary:
	for entry in ways():
		if String(entry.get("id", "")) == way_id:
			return entry
	return {}


## What a card is worth toward a way: its own worth in its own humour, and
## Moonlight is worth its own worth toward anything. A card of the wrong
## humour is worth nothing there, which is what makes the choice a choice.
func worth_toward(card_id: String, humour: String) -> int:
	var card: Dictionary = _catalog.energy_cards.get(card_id, {})
	var card_humour := String(card.get("humour", ""))
	if humour == "any" or card_humour == humour or card_humour == WILD_HUMOUR:
		return int(card.get("value", 0))
	return 0


## What is already on the chosen way.
func paid_worth() -> int:
	if chosen == "":
		return 0
	var humour := String(way(chosen).get("humour", "any"))
	var total := 0
	for card_id in paid:
		total += worth_toward(String(card_id), humour)
	return total


func cost_of(way_id: String) -> int:
	return int(way(way_id).get("cost", 0))


## How far short the chosen way still is. Zero means it is covered.
func shortfall() -> int:
	return maxi(0, cost_of(chosen) - paid_worth()) if chosen != "" else 0


## The odds the shortfall bites, posted BEFORE the commit — an informed
## gamble is the house rule; a hidden one is a coin toss.
func risk() -> float:
	return minf(shortfall_risk * float(shortfall()), RISK_CEILING)


## What the consequence costs if it lands. Doubles once the night presses,
## the same escalation clock combat runs on.
func bite() -> int:
	return hazard * (2 if at + 1 >= night_presses_point else 1)


## Every card in the paw that would count toward the chosen way. The board
## rings these, so "what can I even pay with" is never a guess.
func useful_cards() -> Array[int]:
	var useful: Array[int] = []
	if chosen == "":
		return useful
	var humour := String(way(chosen).get("humour", "any"))
	for i in hand.size():
		if worth_toward(String(hand[i]), humour) > 0:
			useful.append(i)
	return useful


# ------------------------------------------------------------------ commands

func do_command(command: Dictionary) -> Dictionary:
	if Minigame.is_over(outcome):
		return _fail("the crossing is behind you")
	var result: Dictionary
	match String(command.get("type", "")):
		"choose":
			result = _cmd_choose(String(command.get("way", "")))
		"put":
			result = _cmd_put(String(command.get("card", "")))
		"take_back":
			result = _cmd_take_back(String(command.get("card", "")))
		"go":
			result = _cmd_go()
		"read_ahead":
			result = _cmd_read_ahead()
		"turn_back":
			result = _cmd_turn_back()
		_:
			result = _fail("unknown command '%s'" % command.get("type", ""))
	if result["ok"]:
		log.record(at, command)
	return result


## Pick a way past this one. Changing your mind takes back whatever you had
## already put down — the cards were never committed, only offered.
func _cmd_choose(way_id: String) -> Dictionary:
	if way(way_id).is_empty():
		return _fail("there is no way '%s' past this" % way_id)
	if way_id == chosen:
		return _fail("that way is already chosen")
	_return_paid()
	chosen = way_id
	_events.append("way_chosen")
	return _ok()


func _cmd_put(card_id: String) -> Dictionary:
	if chosen == "":
		return _fail("choose a way past it first")
	var index := hand.find(card_id)
	if index < 0:
		return _fail("that card is not in your paw")
	if worth_toward(card_id, String(way(chosen).get("humour", "any"))) <= 0:
		return _fail("that energy is no use on this way")
	hand.remove_at(index)
	paid.append(card_id)
	_events.append("card_put")
	return {"ok": true, "error": "", "paid": paid_worth(),
		"cost": cost_of(chosen)}


func _cmd_take_back(card_id: String) -> Dictionary:
	var index := paid.find(card_id)
	if index < 0:
		return _fail("that card is not on the way")
	paid.remove_at(index)
	hand.append(card_id)
	_events.append("card_taken_back")
	return _ok()


## Go. Whatever is on the way is spent whether it was enough or not, and a
## shortfall is a rolled chance of the consequence rather than a refusal —
## this module never stops the player, it only charges them.
func _cmd_go() -> Dictionary:
	if chosen == "":
		return _fail("choose a way past it first")
	var short := shortfall()
	var odds := risk()
	var bitten := false
	if short > 0:
		bitten = rng.chance(odds)
	for card_id in paid:
		spent.append(card_id)
	paid.clear()
	var taken := bite() if bitten else 0
	if bitten:
		player_hp -= taken
		_events.append("bitten")
	else:
		_events.append("passed")
	chosen = ""
	revealed = false
	paws = paw_limit
	at += 1
	_draw_up()
	if player_hp <= 0:
		player_hp = 0
		# Foundering is a PARTIAL outcome, not a death: the street beat him,
		# and the story picks it up wherever he stopped. No game-overs here.
		outcome = Minigame.Outcome.PARTIAL
		_events.append("foundered")
	elif at >= points.size():
		outcome = Minigame.Outcome.SUCCESS
		_events.append("home")
	if bitten:
		hurts += 1
	return {"ok": true, "error": "", "short": short, "odds": odds,
		"bitten": bitten, "hurt": taken}


## One card back into the paw at each new point, so a long crossing keeps
## dealing and a short one does not hand out a whole second hand.
func _draw_up() -> void:
	if not deck.is_empty():
		hand.append(deck.pop_back())


## Read the next thing in the road before committing to this one. A paw
## buys certainty, which is the only thing a paw buys here.
func _cmd_read_ahead() -> Dictionary:
	if paws < 1:
		return _fail("no paws left at this corner")
	if revealed:
		return _fail("you have already read what is after this")
	if next_point().is_empty():
		return _fail("there is nothing after this but the door")
	paws -= 1
	revealed = true
	_events.append("read_ahead")
	return {"ok": true, "error": "", "point": next_point()}


func _cmd_turn_back() -> Dictionary:
	_return_paid()
	outcome = Minigame.Outcome.WALKED if at <= 0 else Minigame.Outcome.PARTIAL
	_events.append("walked_away")
	return _ok()


func _return_paid() -> void:
	for card_id in paid:
		hand.append(card_id)
	paid.clear()


# ------------------------------------------------------------------ results

## What the crossing hands back to the prowl: the pool it burned through.
## Traversal and combat share one stamina, so this feeds carryover directly.
func carryover() -> Dictionary:
	return {
		"hp": player_hp,
		"deck": deck + hand + paid,
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
