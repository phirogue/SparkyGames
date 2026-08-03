class_name MinigameBots
extends RefCounted
## The agent that plays the mission minigames so a human does not have to.
##
## Two jobs, and they answer different questions:
##
##   SOLVER bots ask "is this module actually playable?" — they play to win
##   using only the public rules, and a module whose solver cannot finish
##   its own shipped content is not built, however nice it looks.
##
##   CHAOS bots ask "does it break?" — random legal play, illegal commands,
##   and degenerate strategies, checked against the same invariants the
##   combat harness uses (ChaosPlay): a rejected command changes nothing, a
##   finished session stays finished, and every session terminates.
##
## Both report through `violations`, so one instance can sweep everything
## and the runner prints a single verdict.

const COMMAND_CAP := 600

var catalog: Catalog
var violations: Array[String] = []

var _label := ""
var _rng: CoreRng


func _init(p_catalog: Catalog) -> void:
	catalog = p_catalog


func _violation(message: String) -> void:
	violations.append("%s: %s" % [_label, message])


# =========================================================== shared invariants

## The universal contract, checked around every command of every module.
## `snapshot` is the module's own state digest.
func _guard(state: Object, command: Dictionary, before: String,
		result: Dictionary, snapshot: Callable) -> void:
	if result.get("ok", false):
		return
	if snapshot.call(state) != before:
		_violation("rejected '%s' changed the state anyway (%s)" % [
			command.get("type", "?"), result.get("error", "")])
	if String(result.get("error", "")).is_empty():
		_violation("'%s' was rejected without saying why" % command.get("type", "?"))


## Once a module reports an outcome, nothing further may be accepted. Only
## meaningful on a FINISHED session — calling it on a running one would
## report every ordinary accepted command as a violation, which buried the
## one real defect under 45 lines of noise the first time this ran.
func _guard_finished(state: Object, probes: Array, snapshot: Callable) -> void:
	if not Minigame.is_over(state.outcome):
		_violation("session did not finish, so the post-session guard could not run")
		return
	var before: String = snapshot.call(state)
	for command in probes:
		if state.do_command(command).get("ok", false):
			_violation("'%s' was accepted after the session ended" % command.get("type", "?"))
	if snapshot.call(state) != before:
		_violation("a command after the session ended changed the state")


# ================================================================ 1. Stitch

func _stitch_snapshot(state) -> String:
	return JSON.stringify({
		"sewn": state.sewn.keys(), "paws": state.paws,
		"outcome": state.outcome, "hint": state.squint_hint,
	})


## Solver: sew exactly the chart's solution. If the module's own rules do not
## recognise its own solution as a closed seam, the module is broken.
func solve_stitch(chart_id: String) -> Dictionary:
	_label = "stitch/%s/solver" % chart_id
	var chart: Dictionary = catalog.stitch_charts[chart_id]
	var state := StitchState.create(chart)
	var commands := 0
	for edge_id in chart.get("solution", []):
		var before := _stitch_snapshot(state)
		var command := {"type": "sew", "edge": String(edge_id)}
		var result := state.do_command(command)
		_guard(state, command, before, result, _stitch_snapshot)
		commands += 1
	if state.outcome != Minigame.Outcome.SUCCESS:
		_violation("sewing the chart's own solution did not close the seam")
	# Sewing one more edge after success must be refused, not silently undo it.
	_guard_finished(state, [{"type": "sew", "edge": "h:0:0"},
		{"type": "give_up"}, {"type": "squint"}], _stitch_snapshot)
	return {"commands": commands, "outcome": state.outcome}


## Squint must never lie: it may only ever name a stitch that is genuinely
## absent from the solution, and it must be free when nothing is wrong.
func probe_stitch_squint(chart_id: String) -> void:
	_label = "stitch/%s/squint" % chart_id
	var chart: Dictionary = catalog.stitch_charts[chart_id]
	var state := StitchState.create(chart)
	var solution: Array = chart.get("solution", [])
	var paws_before: int = state.paws
	var clean := state.do_command({"type": "squint"})
	if not clean.get("clean", false):
		_violation("squint claimed a wrong stitch on an empty chart")
	if state.paws != paws_before:
		_violation("squint charged a paw for finding nothing wrong")
	# Sew one correct edge and one deliberately wrong one.
	state.do_command({"type": "sew", "edge": String(solution[0])})
	var wrong := ""
	for edge_id in state.all_edges():
		if not solution.has(edge_id):
			wrong = edge_id
			break
	if wrong == "":
		return
	state.do_command({"type": "sew", "edge": wrong})
	var hint := state.do_command({"type": "squint"})
	if String(hint.get("hint", "")) != wrong:
		_violation("squint named '%s' but the wrong stitch was '%s'" % [
			hint.get("hint", ""), wrong])
	if state.paws != paws_before - 1:
		_violation("squint did not charge its paw for a real hint")


func chaos_stitch(chart_id: String, seed_value: int) -> void:
	_label = "stitch/%s/chaos seed %d" % [chart_id, seed_value]
	_rng = CoreRng.new(seed_value)
	var state := StitchState.create(catalog.stitch_charts[chart_id])
	var edges := state.all_edges()
	var junk: Array[Dictionary] = [
		{}, {"type": "wibble"}, {"type": "sew"}, {"type": "sew", "edge": "h:99:99"},
		{"type": "unpick", "edge": "nonsense"}, {"type": "sew", "edge": "v:-1:0"},
	]
	var commands := 0
	while not Minigame.is_over(state.outcome) and commands < COMMAND_CAP:
		var command: Dictionary
		if _rng.pick_index(4) == 0:
			command = junk[_rng.pick_index(junk.size())]
		else:
			var edge_id := edges[_rng.pick_index(edges.size())]
			var kind := "unpick" if state.sewn.has(edge_id) else "sew"
			command = {"type": kind, "edge": edge_id}
			if _rng.pick_index(12) == 0:
				command = {"type": "squint"}
		var before := _stitch_snapshot(state)
		var result := state.do_command(command)
		_guard(state, command, before, result, _stitch_snapshot)
		if state.paws < 0:
			_violation("paws went negative")
		commands += 1
	if commands >= COMMAND_CAP and not Minigame.is_over(state.outcome):
		# Not a defect: random sewing is not expected to solve a loop puzzle.
		# The point is that it never broke an invariant getting nowhere.
		pass
	_replay_check(state, StitchState.create(catalog.stitch_charts[chart_id]),
		_stitch_snapshot)


# ============================================================= 2. Testimony

func _testimony_snapshot(state) -> String:
	return JSON.stringify({
		"visible": state.visible, "pressed": state.pressed.keys(),
		"patience": state.patience, "outcome": state.outcome,
		"broken": state.broken_ribbon, "standing": state.standing_cost,
	})


## Solver: press everything pressable, then present the right evidence.
## Also proves the fair-play rule — the winning ribbon must be reachable.
func solve_testimony(testimony_id: String, held: Array) -> Dictionary:
	_label = "testimony/%s/solver" % testimony_id
	var state := TestimonyState.create(catalog.testimonies[testimony_id], held)
	var commands := 0
	# Press until nothing new appears; pressing must never cost patience.
	var patience_before: int = state.patience
	var pressing := true
	while pressing and commands < COMMAND_CAP:
		pressing = false
		for ribbon_id in state.visible.duplicate():
			if state.can_press(ribbon_id):
				var before := _testimony_snapshot(state)
				var command := {"type": "press", "ribbon": ribbon_id}
				var result := state.do_command(command)
				_guard(state, command, before, result, _testimony_snapshot)
				commands += 1
				pressing = true
	if state.patience != patience_before:
		_violation("pressing cost patience — it must be the safe move")
	var breakable := state.breakable_now()
	if breakable.is_empty():
		_violation("no ribbon is breakable with the evidence the lead expects")
		return {"commands": commands, "outcome": state.outcome}
	var target: String = breakable[0]
	var evidence := String(state.ribbons[target].get("contradicted_by", ""))
	var before_break := _testimony_snapshot(state)
	var break_command := {"type": "present", "ribbon": target, "evidence": evidence}
	var break_result := state.do_command(break_command)
	_guard(state, break_command, before_break, break_result, _testimony_snapshot)
	commands += 1
	if state.outcome != Minigame.Outcome.SUCCESS:
		_violation("the correct presentation did not break the testimony")
	if state.break_effects().is_empty():
		_violation("the break handed back nothing for the story to use")
	_guard_finished(state, [{"type": "press", "ribbon": target},
		{"type": "leave"}], _testimony_snapshot)
	return {"commands": commands, "outcome": state.outcome}


## Patience must run out into PARTIAL, never into a wall, and every wrong
## presentation must cost the witness's guild exactly one standing.
func probe_testimony_patience(testimony_id: String, held: Array) -> void:
	_label = "testimony/%s/patience" % testimony_id
	var testimony: Dictionary = catalog.testimonies[testimony_id]
	var state := TestimonyState.create(testimony, held)
	# Find an honest ribbon and an evidence that does NOT contradict it.
	var honest := ""
	for ribbon_id in state.visible:
		if not state.is_shimmering(ribbon_id):
			honest = ribbon_id
			break
	if honest == "" or held.is_empty():
		return
	var patience: int = state.patience
	for i in patience:
		var result := state.do_command({"type": "present", "ribbon": honest,
			"evidence": String(held[0])})
		if not result.get("ok", false):
			_violation("presenting on an honest ribbon was refused: %s" % result.get("error", ""))
			return
		if result.get("broke", false):
			return  # it was breakable after all; not this probe's business
	if state.outcome != Minigame.Outcome.PARTIAL:
		_violation("patience ran out but the outcome was %s, not partial" %
			Minigame.outcome_name(state.outcome))
	var guild_id := state.guild()
	if guild_id != "" and int(state.standing_cost.get(guild_id, 0)) != -patience:
		_violation("wrong presentations cost %d standing, expected %d" % [
			int(state.standing_cost.get(guild_id, 0)), -patience])


func chaos_testimony(testimony_id: String, held: Array, seed_value: int) -> void:
	_label = "testimony/%s/chaos seed %d" % [testimony_id, seed_value]
	_rng = CoreRng.new(seed_value)
	var testimony: Dictionary = catalog.testimonies[testimony_id]
	var state := TestimonyState.create(testimony, held)
	var ribbon_ids: Array = state.ribbons.keys()
	var commands := 0
	while not Minigame.is_over(state.outcome) and commands < COMMAND_CAP:
		var roll := _rng.pick_index(6)
		var command: Dictionary
		if roll == 0:
			command = [{}, {"type": "press", "ribbon": "ghost"},
				{"type": "present", "ribbon": "ghost", "evidence": "ghost"},
				{"type": "present", "ribbon": String(ribbon_ids[0]),
					"evidence": "a_thing_he_does_not_have"}][_rng.pick_index(4)]
		elif roll < 4:
			command = {"type": "press",
				"ribbon": String(ribbon_ids[_rng.pick_index(ribbon_ids.size())])}
		else:
			var evidence := "" if held.is_empty() \
				else String(held[_rng.pick_index(held.size())])
			command = {"type": "present",
				"ribbon": String(ribbon_ids[_rng.pick_index(ribbon_ids.size())]),
				"evidence": evidence}
		var before := _testimony_snapshot(state)
		var result := state.do_command(command)
		_guard(state, command, before, result, _testimony_snapshot)
		if state.patience < 0:
			_violation("patience went negative")
		commands += 1
	if not Minigame.is_over(state.outcome):
		_violation("the witness never finished with the player")


# ================================================================== 3. Ward

func _ward_snapshot(state) -> String:
	return JSON.stringify({
		"covered": state.covered, "placed": state.placed.keys(),
		"hand": state.hand, "spent": state.spent, "outcome": state.outcome,
	})


## Solver: greedily fill the tear, first-open-cell first. It does not have
## to find the perfect cover — it has to prove that legal play converges and
## that the effects a mend carries out are coherent.
func solve_ward(ward_id: String, hand: Array) -> Dictionary:
	_label = "ward/%s/solver" % ward_id
	var state := WardState.create(catalog, catalog.wards[ward_id], hand)
	var commands := 0
	while state.has_legal_move() and commands < COMMAND_CAP:
		var placed_one := false
		for patch in state.rack:
			var patch_id := String(patch["id"])
			if state.placed.has(patch_id) or not state.can_afford(patch_id):
				continue
			for rotation in 4:
				for row in state.height:
					for col in state.width:
						if not state.fits(patch_id, row, col, rotation):
							continue
						var before := _ward_snapshot(state)
						var command := {"type": "place", "patch": patch_id,
							"row": row, "col": col, "rotation": rotation}
						var result := state.do_command(command)
						_guard(state, command, before, result, _ward_snapshot)
						commands += 1
						placed_one = true
						break
					if placed_one: break
				if placed_one: break
			if placed_one: break
		if not placed_one:
			break
	if not Minigame.is_over(state.outcome):
		state.do_command({"type": "finish"})
	var uncovered := state.uncovered_cells().size()
	var effects := state.carried_effects()
	if state.outcome == Minigame.Outcome.SUCCESS and uncovered != 0:
		_violation("a perfect mend was declared with %d cells still open" % uncovered)
	if state.outcome == Minigame.Outcome.PARTIAL and effects.size() != uncovered:
		_violation("%d open cells produced %d gap effects" % [uncovered, effects.size()])
	if state.spent.size() != state.placed.size():
		_violation("%d patches down but %d cards spent — the mend must cost" % [
			state.placed.size(), state.spent.size()])
	_guard_finished(state, [{"type": "finish"},
		{"type": "place", "patch": "p_dot", "row": 0, "col": 0, "rotation": 0}],
		_ward_snapshot)
	return {"commands": commands, "outcome": state.outcome,
		"uncovered": uncovered, "spent": state.spent.size()}


## Lifting a patch frees its cells but must NOT refund the card — otherwise
## the tear can be brute-forced for nothing and the economy hook is a lie.
func probe_ward_lift(ward_id: String, hand: Array) -> void:
	_label = "ward/%s/lift" % ward_id
	var state := WardState.create(catalog, catalog.wards[ward_id], hand)
	var patch_id := String(state.rack[0]["id"])
	var placed := false
	for rotation in 4:
		for row in state.height:
			for col in state.width:
				if state.fits(patch_id, row, col, rotation) and state.can_afford(patch_id):
					state.do_command({"type": "place", "patch": patch_id,
						"row": row, "col": col, "rotation": rotation})
					placed = true
					break
			if placed: break
		if placed: break
	if not placed:
		return
	if Minigame.is_over(state.outcome):
		return  # that patch finished the mend; there is nothing left to lift
	var spent_after_place: int = state.spent.size()
	var hand_after_place: int = state.hand.size()
	var open_after_place: int = state.uncovered_cells().size()
	var covered_cells: int = state.placed[patch_id]["cells"].size()
	state.do_command({"type": "lift", "patch": patch_id})
	if state.spent.size() != spent_after_place or state.hand.size() != hand_after_place:
		_violation("lifting a patch refunded its energy — spent must be spent")
	if state.uncovered_cells().size() != open_after_place + covered_cells:
		_violation("lifting freed %d cells, expected %d" % [
			state.uncovered_cells().size() - open_after_place, covered_cells])
	if state.placed.has(patch_id):
		_violation("a lifted patch is still recorded as placed")


func chaos_ward(ward_id: String, hand: Array, seed_value: int) -> void:
	_label = "ward/%s/chaos seed %d" % [ward_id, seed_value]
	_rng = CoreRng.new(seed_value)
	var state := WardState.create(catalog, catalog.wards[ward_id], hand)
	var patch_ids: Array = []
	for patch in state.rack:
		patch_ids.append(String(patch["id"]))
	var commands := 0
	while not Minigame.is_over(state.outcome) and commands < COMMAND_CAP:
		var roll := _rng.pick_index(8)
		var command: Dictionary
		if roll == 0:
			command = [{}, {"type": "place", "patch": "ghost", "row": 0, "col": 0},
				{"type": "lift", "patch": "ghost"},
				{"type": "place", "patch": String(patch_ids[0]),
					"row": -5, "col": 99, "rotation": 17}][_rng.pick_index(4)]
		elif roll == 1:
			command = {"type": "lift",
				"patch": String(patch_ids[_rng.pick_index(patch_ids.size())])}
		elif roll == 7:
			command = {"type": "finish"}
		else:
			command = {"type": "place",
				"patch": String(patch_ids[_rng.pick_index(patch_ids.size())]),
				"row": _rng.pick_index(state.height),
				"col": _rng.pick_index(state.width),
				"rotation": _rng.pick_index(4)}
		var before := _ward_snapshot(state)
		var result := state.do_command(command)
		_guard(state, command, before, result, _ward_snapshot)
		if state.hand.size() + state.spent.size() != hand.size():
			_violation("energy was created or destroyed: %d + %d != %d" % [
				state.hand.size(), state.spent.size(), hand.size()])
		if state.covered.size() > state.hole.size():
			_violation("more cells covered than the tear has")
		commands += 1
	if not Minigame.is_over(state.outcome):
		_violation("the mend never resolved")


# =============================================================== 4. Lattice

func _lattice_snapshot(state) -> String:
	return JSON.stringify({
		"pulled": state.pulled, "alarm": state.alarm,
		"mistakes": state.mistakes, "gaps": state.gap_effects,
		"outcome": state.outcome,
	})


## Solver: follow the safe order the topology guarantees. A clean run must
## raise no alarm at all — if it does, the "safe order" is not safe.
func solve_lattice(lattice_id: String) -> Dictionary:
	_label = "lattice/%s/solver" % lattice_id
	var lattice: Dictionary = catalog.lattices[lattice_id]
	var state := LatticeState.create(lattice)
	var order := state.safe_order()
	if order.is_empty():
		_violation("no safe pull order exists — the lattice cannot be undone")
		return {"outcome": state.outcome}
	for thread_id in order:
		var before := _lattice_snapshot(state)
		var command := {"type": "pull", "thread": thread_id}
		var result := state.do_command(command)
		_guard(state, command, before, result, _lattice_snapshot)
		if not result.get("pulled", false):
			_violation("the safe order was blocked at '%s'" % thread_id)
	if state.outcome != Minigame.Outcome.SUCCESS:
		_violation("the safe order did not undo the lattice")
	if state.alarm != 0 or state.mistakes != 0:
		_violation("a clean run raised alarm %d over %d mistakes" % [
			state.alarm, state.mistakes])
	_guard_finished(state, [{"type": "pull", "thread": order[0]},
		{"type": "give_up"}], _lattice_snapshot)
	return {"outcome": state.outcome, "pulls": order.size()}


## A blocked pull is a COST, not a rejection: the command succeeds, the
## thread stays put, and the alarm climbs. Check that contract explicitly.
func probe_lattice_mistake(lattice_id: String) -> void:
	_label = "lattice/%s/mistake" % lattice_id
	var state := LatticeState.create(catalog.lattices[lattice_id])
	var blocked := ""
	for thread_id in state.order:
		if not state.can_pull(thread_id):
			blocked = thread_id
			break
	if blocked == "":
		return
	var result := state.do_command({"type": "pull", "thread": blocked})
	if not result.get("ok", false):
		_violation("a blocked pull was rejected; it should twang and cost")
	if result.get("pulled", true):
		_violation("a blocked thread came out anyway")
	if state.pulled.has(blocked):
		_violation("a blocked thread was recorded as pulled")
	if state.alarm < 1 and state.gap_effects.is_empty():
		_violation("a mis-pull cost nothing at all")


func chaos_lattice(lattice_id: String, seed_value: int) -> void:
	_label = "lattice/%s/chaos seed %d" % [lattice_id, seed_value]
	_rng = CoreRng.new(seed_value)
	var lattice: Dictionary = catalog.lattices[lattice_id]
	var state := LatticeState.create(lattice)
	var commands := 0
	while not Minigame.is_over(state.outcome) and commands < COMMAND_CAP:
		var command: Dictionary
		if _rng.pick_index(5) == 0:
			command = [{}, {"type": "pull"}, {"type": "pull", "thread": "ghost"},
				{"type": "wibble"}][_rng.pick_index(4)]
		else:
			command = {"type": "pull",
				"thread": String(state.order[_rng.pick_index(state.order.size())])}
		var before := _lattice_snapshot(state)
		var result := state.do_command(command)
		_guard(state, command, before, result, _lattice_snapshot)
		if state.pulled.size() > state.order.size():
			_violation("more threads pulled than the lattice has")
		commands += 1
	if not Minigame.is_over(state.outcome):
		_violation("the lattice never resolved")
	_replay_check(state, LatticeState.create(lattice), _lattice_snapshot)


# ============================================================== 5. Crossing

func _crossing_snapshot(state) -> String:
	return JSON.stringify({
		"progress": state.progress, "sheltered": state.sheltered,
		"gust": state.gust, "hp": state.player_hp, "turn": state.turn,
		"hand": state.hand, "deck": state.deck, "spent": state.spent,
		"paws": state.paws, "outcome": state.outcome,
	})


func _crossing_config(hand_deck: Array) -> Dictionary:
	return {"player_hp": 10, "player_max_hp": 10, "deck": hand_deck, "paws": 3}


## Solver: press while the hand is clean, shelter when the gust is holding a
## card you own. Proves a crossing is winnable by informed play alone.
func solve_crossing(crossing_id: String, deck: Array, seed_value: int) -> Dictionary:
	_label = "crossing/%s/solver seed %d" % [crossing_id, seed_value]
	var state := CrossingState.create(catalog, seed_value,
		catalog.crossings[crossing_id], _crossing_config(deck))
	var commands := 0
	var total_cards: int = state.deck.size() + state.hand.size() + state.spent.size()
	while not Minigame.is_over(state.outcome) and commands < COMMAND_CAP:
		# Informed play: wait out a gust that is holding something of yours,
		# press otherwise. Sheltering costs a card, so this converges — that
		# it did NOT converge is how the free-shelter defect was found.
		var command := {"type": "shelter"} if state.at_risk() else {"type": "press_on"}
		var before := _crossing_snapshot(state)
		var result := state.do_command(command)
		_guard(state, command, before, result, _crossing_snapshot)
		commands += 1
		if state.progress < state.sheltered:
			_violation("progress fell below what was sheltered")
		if state.player_hp > state.player_max_hp:
			_violation("hp climbed over max")
		if state.deck.size() + state.hand.size() + state.spent.size() != total_cards:
			_violation("energy was created or destroyed during the crossing")
		if not result.get("ok", false) and command["type"] == "press_on":
			# Hand and deck both empty: nothing left to move on with.
			state.do_command({"type": "slip_away"})
	if not Minigame.is_over(state.outcome):
		_violation("the crossing never resolved")
	_guard_finished(state, [{"type": "press_on"}, {"type": "shelter"},
		{"type": "slip_away"}], _crossing_snapshot)
	return {"outcome": state.outcome, "progress": state.progress,
		"turns": state.turn, "hp": state.player_hp, "commands": commands}


## Reckless: press every turn, never wait. The counterweight to the careful
## solver — if BOTH lines cross every time the module has no gamble in it,
## and if reckless never founders the hazard is decoration.
func rush_crossing(crossing_id: String, deck: Array, seed_value: int) -> Dictionary:
	_label = "crossing/%s/reckless seed %d" % [crossing_id, seed_value]
	var state := CrossingState.create(catalog, seed_value,
		catalog.crossings[crossing_id], _crossing_config(deck))
	var commands := 0
	while not Minigame.is_over(state.outcome) and commands < COMMAND_CAP:
		var before := _crossing_snapshot(state)
		var command := {"type": "press_on"}
		var result := state.do_command(command)
		_guard(state, command, before, result, _crossing_snapshot)
		commands += 1
		if not result.get("ok", false):
			state.do_command({"type": "slip_away"})
	if not Minigame.is_over(state.outcome):
		_violation("reckless play never resolved the crossing")
	return {"outcome": state.outcome, "progress": state.progress,
		"turns": state.turn, "hp": state.player_hp}


## Pick the Line must not lie: the gust it previews has to be the gust that
## actually posts on the next shelter, or the aid is worse than nothing.
func probe_crossing_peek(crossing_id: String, deck: Array, seed_value: int) -> void:
	_label = "crossing/%s/peek seed %d" % [crossing_id, seed_value]
	var state := CrossingState.create(catalog, seed_value,
		catalog.crossings[crossing_id], _crossing_config(deck))
	var peek := state.do_command({"type": "pick_line"})
	if not peek.get("ok", false):
		_violation("Pick the Line was refused on a fresh turn: %s" % peek.get("error", ""))
		return
	var promised := String(peek.get("next_gust", ""))
	if state.do_command({"type": "pick_line"}).get("ok", false):
		_violation("Pick the Line was payable twice in one turn")
	state.do_command({"type": "shelter"})
	if state.gust != promised:
		_violation("peeked '%s' but '%s' posted" % [promised, state.gust])
	if state.paws != state.paw_limit:
		_violation("sheltering did not refresh the paws")


func chaos_crossing(crossing_id: String, deck: Array, seed_value: int) -> void:
	_label = "crossing/%s/chaos seed %d" % [crossing_id, seed_value]
	_rng = CoreRng.new(seed_value * 7 + 3)
	var state := CrossingState.create(catalog, seed_value,
		catalog.crossings[crossing_id], _crossing_config(deck))
	var options: Array[Dictionary] = [{"type": "press_on"}, {"type": "shelter"},
		{"type": "pick_line"}, {"type": "slip_away"}]
	var junk: Array[Dictionary] = [{}, {"type": "wibble"}, {"type": "press"}]
	var commands := 0
	while not Minigame.is_over(state.outcome) and commands < COMMAND_CAP:
		var command: Dictionary = junk[_rng.pick_index(junk.size())] \
			if _rng.pick_index(6) == 0 else options[_rng.pick_index(3)]
		var before := _crossing_snapshot(state)
		var result := state.do_command(command)
		_guard(state, command, before, result, _crossing_snapshot)
		if state.progress < 0 or state.progress > state.length:
			_violation("progress %d is outside 0..%d" % [state.progress, state.length])
		if state.paws < 0 or state.paws > state.paw_limit:
			_violation("paws %d outside 0..%d" % [state.paws, state.paw_limit])
		commands += 1
	if not Minigame.is_over(state.outcome):
		_violation("the crossing never resolved under random play")


# ================================================================== replay

## Same start + same logged commands = the same finish. Modules without RNG
## get this for free; it is checked anyway, because the day one of them
## grows a random element is the day it silently stops being reproducible.
func _replay_check(state: Object, fresh: Object, snapshot: Callable) -> void:
	for entry in state.log.entries:
		if Minigame.is_over(fresh.outcome):
			break
		fresh.do_command(entry)
	if snapshot.call(fresh) != snapshot.call(state):
		_violation("replaying the command log did not reproduce the session")
