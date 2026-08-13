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
		"outcome": state.outcome,
		"hint": [state.squint_wrong, state.squint_sew],
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


## Squint must never lie. It says two things and both are read off the
## chart's own solution, so neither can be a guess:
##   `wrong` is always a sewn stitch the solution does NOT use
##   `sew`   is always a solution stitch that is NOT sewn yet
## It charges exactly one paw, and only when it had something to say.
func probe_stitch_squint(chart_id: String) -> void:
	_label = "stitch/%s/squint" % chart_id
	var chart: Dictionary = catalog.stitch_charts[chart_id]
	var state := StitchState.create(chart)
	var solution: Array = chart.get("solution", [])
	# On an empty chart nothing is wrong but plenty is missing, so Squint must
	# volunteer a stitch to sew rather than shrug (owner 2026-08-09: "Squint
	# doesn't do anything, but should highlight a possible edge").
	var paws_before: int = state.paws
	var opening := state.do_command({"type": "squint"})
	if String(opening.get("wrong", "")) != "":
		_violation("squint claimed a wrong stitch on an empty chart")
	if not solution.has(String(opening.get("sew", ""))):
		_violation("squint suggested '%s', which is not in the solution"
			% opening.get("sew", ""))
	if state.paws != paws_before - 1:
		_violation("squint did not charge its paw for a real hint")
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
	var paws_now: int = state.paws
	var hint := state.do_command({"type": "squint"})
	if String(hint.get("wrong", "")) != wrong:
		_violation("squint named '%s' but the wrong stitch was '%s'" % [
			hint.get("wrong", ""), wrong])
	if state.sewn.has(String(hint.get("sew", ""))):
		_violation("squint suggested sewing '%s', which is already sewn"
			% hint.get("sew", ""))
	if state.paws != paws_now - 1:
		_violation("squint did not charge its paw for a real hint")
	# A correctly sewn seam has nothing to say and must not bill for saying it.
	var solved := StitchState.create(chart)
	for edge_id in solution:
		solved.do_command({"type": "sew", "edge": String(edge_id)})
	solved.outcome = Minigame.Outcome.ONGOING   # ask it anyway
	var paws_solved: int = solved.paws
	var clean := solved.do_command({"type": "squint"})
	if not clean.get("clean", false):
		_violation("squint found fault with a correctly sewn seam")
	if solved.paws != paws_solved:
		_violation("squint charged a paw for finding nothing wrong")


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
	# A break must land SOMEWHERE: in case effects, or in a quest that routes
	# on the outcome (`when_minigame`), or in a lesson that runs it as
	# practice. A testimony none of those consume resolves into silence.
	if state.break_effects().is_empty() and not _testimony_is_consumed(testimony_id):
		_violation("the break handed back nothing for the story to use")
	_guard_finished(state, [{"type": "press", "ribbon": target},
		{"type": "leave"}], _testimony_snapshot)
	return {"commands": commands, "outcome": state.outcome}


## Where an effect-less break is still consumed: a quest step that plays this
## testimony and later routes a story page on `when_minigame`, or a lesson
## whose practice scene is this testimony (the lesson is the consumer).
func _testimony_is_consumed(testimony_id: String) -> bool:
	for lesson_id in catalog.lessons:
		if String(catalog.lessons[lesson_id].get("scene", "")) == "testimony:%s" % testimony_id:
			return true
	for quest_id in catalog.quests:
		var steps := ProwlScript.steps_of(catalog.quests[quest_id])
		var plays_it_at := -1
		for i in steps.size():
			var step: Dictionary = steps[i]
			if ProwlScript.type_of(step) == ProwlScript.MINIGAME \
					and String(step.get("module", "")) == "testimony" \
					and String(step.get("id", "")) == testimony_id:
				plays_it_at = i
			elif plays_it_at >= 0 and i > plays_it_at and step.has("when_minigame"):
				return true
	return false


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
		"drawn": state.drawn, "deck": state.deck, "spent": state.spent,
		"outcome": state.outcome,
	})


## Solver: wind the spool down, laying each drawn piece where it closes the
## most tear. It does not have to find a perfect mend — it has to prove that
## legal play converges, that drawing really costs, and that the effects a
## mend carries out are coherent.
##
## Rebuilt for the draw model (owner 2026-08-13): there is no rack to search,
## so the loop is DRAW, then place what came.
func solve_ward(ward_id: String, deck: Array) -> Dictionary:
	_label = "ward/%s/solver" % ward_id
	var state := WardState.create(catalog, catalog.wards[ward_id], deck)
	var commands := 0
	var drawn := 0
	while commands < COMMAND_CAP and not Minigame.is_over(state.outcome):
		if state.drawn == "":
			if state.deck.is_empty() or state.uncovered_cells().is_empty():
				break
			var before_draw := _ward_snapshot(state)
			var draw_command := {"type": "draw"}
			var draw_result := state.do_command(draw_command)
			_guard(state, draw_command, before_draw, draw_result, _ward_snapshot)
			drawn += 1
			commands += 1
			continue
		# Greedy on COVERAGE, not on the first legal square: cloth may be laid
		# anywhere, so "the first placement that fits" is the top-left corner
		# every time and proves nothing about mendability.
		var move := state.best_placement()
		if move.is_empty():
			# Nothing this piece can still close. Lay it out of the way rather
			# than stalling — a paw that never empties can never draw again.
			move = {"row": 0, "col": 0, "rotation": 0}
		var before := _ward_snapshot(state)
		var command := {"type": "place", "row": int(move["row"]),
			"col": int(move["col"]), "rotation": int(move["rotation"])}
		var result := state.do_command(command)
		_guard(state, command, before, result, _ward_snapshot)
		commands += 1
	if not Minigame.is_over(state.outcome):
		state.do_command({"type": "finish"})
	var uncovered := state.uncovered_cells().size()
	var effects := state.carried_effects()
	if state.outcome == Minigame.Outcome.SUCCESS and uncovered != 0:
		_violation("a perfect mend was declared with %d cells still open" % uncovered)
	if state.outcome == Minigame.Outcome.PARTIAL and effects.size() != uncovered:
		_violation("%d open cells produced %d gap effects" % [uncovered, effects.size()])
	if state.spent.size() != drawn:
		_violation("%d cards drawn but %d spent — drawing must cost" % [
			drawn, state.spent.size()])
	if state.deck.size() + state.spent.size() != deck.size():
		_violation("the spool gained or lost cards: %d + %d != %d" % [
			state.deck.size(), state.spent.size(), deck.size()])
	_guard_finished(state, [{"type": "finish"}, {"type": "draw"},
		{"type": "place", "row": 0, "col": 0, "rotation": 0}], _ward_snapshot)
	return {"commands": commands, "outcome": state.outcome,
		"uncovered": uncovered, "drawn": drawn}


## Lifting picks a laid patch back UP into the paw. It must not un-spend the
## card (the card went at the draw, which is where the decision was) and it
## must not put anything back on the spool — otherwise a player could wind the
## same card down forever and the wager is not a wager.
func probe_ward_lift(ward_id: String, deck: Array) -> void:
	_label = "ward/%s/lift" % ward_id
	var state := WardState.create(catalog, catalog.wards[ward_id], deck)
	state.do_command({"type": "draw"})
	var card := state.drawn
	var move := state.best_placement()
	if move.is_empty():
		return
	state.do_command({"type": "place", "row": int(move["row"]),
		"col": int(move["col"]), "rotation": int(move["rotation"])})
	if Minigame.is_over(state.outcome):
		return  # that piece finished the mend; there is nothing left to lift
	var spent_after_place: int = state.spent.size()
	var deck_after_place: int = state.deck.size()
	var open_after_place: int = state.uncovered_cells().size()
	var patch_key := String(state.placed_order[0])
	# Only the TORN squares under it reopen: cloth may hang over sound cloth,
	# and sound cloth was never counted as mended.
	var torn_under := 0
	for key in state.placed[patch_key]["cells"]:
		if state.hole.has(String(key)):
			torn_under += 1
	state.do_command({"type": "lift", "patch": patch_key})
	if state.spent.size() != spent_after_place or state.deck.size() != deck_after_place:
		_violation("lifting a patch moved cards — the draw is what costs, not the placing")
	if state.drawn != card:
		_violation("lifting put a different piece of cloth in the paw")
	if state.uncovered_cells().size() != open_after_place + torn_under:
		_violation("lifting freed %d torn cells, expected %d" % [
			state.uncovered_cells().size() - open_after_place, torn_under])
	if state.placed.has(patch_key):
		_violation("a lifted patch is still recorded as placed")
	# A full paw cannot draw and cannot lift again: one piece of cloth at a
	# time, or the wind-down means nothing.
	if state.can_draw():
		_violation("the spool paid out while there was cloth in the paw")


func chaos_ward(ward_id: String, deck: Array, seed_value: int) -> void:
	_label = "ward/%s/chaos seed %d" % [ward_id, seed_value]
	_rng = CoreRng.new(seed_value)
	var state := WardState.create(catalog, catalog.wards[ward_id], deck)
	var commands := 0
	while not Minigame.is_over(state.outcome) and commands < COMMAND_CAP:
		var roll := _rng.pick_index(9)
		var command: Dictionary
		if roll == 0:
			command = [{}, {"type": "place", "row": -5, "col": 99, "rotation": 17},
				{"type": "lift", "patch": "ghost"},
				{"type": "place", "row": 0, "col": 0, "rotation": 0}][_rng.pick_index(4)]
		elif roll == 1:
			var keys: Array = state.placed_order
			command = {"type": "lift", "patch": "ghost"} if keys.is_empty() \
				else {"type": "lift",
					"patch": String(keys[_rng.pick_index(keys.size())])}
		elif roll == 8:
			command = {"type": "finish"}
		elif roll < 5:
			command = {"type": "draw"}
		else:
			command = {"type": "place",
				"row": _rng.pick_index(state.height),
				"col": _rng.pick_index(state.width),
				"rotation": _rng.pick_index(4)}
		var before := _ward_snapshot(state)
		var result := state.do_command(command)
		_guard(state, command, before, result, _ward_snapshot)
		# Energy is conserved: every card is on the spool, in the paw as cloth
		# already spent, or in the spent pile. Cloth in the paw is spent, so it
		# is counted there and never twice.
		if state.deck.size() + state.spent.size() != deck.size():
			_violation("energy was created or destroyed: %d + %d != %d" % [
				state.deck.size(), state.spent.size(), deck.size()])
		# Patches may spill onto sound cloth and stack on each other (owner
		# 2026-08-09), so `covered` legitimately exceeds the tear. What must
		# still hold: nothing is covered off the ward, and the mend can never
		# close more torn squares than the tear has.
		for key in state.covered:
			var parts := String(key).split(",")
			var r := int(parts[0])
			var c := int(parts[1])
			if r < 0 or r >= state.height or c < 0 or c >= state.width:
				_violation("cell '%s' is covered but is not on the ward" % key)
		var still_open := state.uncovered_cells()
		if still_open.size() > state.hole.size():
			_violation("%d cells open in a %d-cell tear" % [
				still_open.size(), state.hole.size()])
		for key in still_open:
			if not state.hole.has(String(key)):
				_violation("sound cloth '%s' was counted as an open tear" % key)
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
		"at": state.at, "chosen": state.chosen, "paid": state.paid,
		"hp": state.player_hp, "hand": state.hand, "deck": state.deck,
		"spent": state.spent, "paws": state.paws, "revealed": state.revealed,
		"outcome": state.outcome,
	})


func _crossing_config(hand_deck: Array) -> Dictionary:
	return {"player_hp": 10, "player_max_hp": 10, "deck": hand_deck, "paws": 3}


## Every card in the paw that counts toward a way, cheapest first, so the
## solver spends its smallest coins before its biggest — the play a careful
## person makes, and the one that leaves the most for the fight after.
func _payment_order(state, humour: String) -> Array:
	var useful: Array = []
	for card_id in state.hand:
		var worth: int = state.worth_toward(String(card_id), humour)
		if worth > 0:
			useful.append({"card": String(card_id), "worth": worth})
	useful.sort_custom(func(a, b): return int(a["worth"]) < int(b["worth"]))
	return useful


## Solver: at each point take the way it can actually afford, cheapest total
## first, and pay it in full. Proves a crossing is crossable by informed play
## alone — and that "informed" is possible, since the validator guarantees
## every point has a way any energy can pay for.
func solve_crossing(crossing_id: String, deck: Array, seed_value: int) -> Dictionary:
	_label = "crossing/%s/solver seed %d" % [crossing_id, seed_value]
	var state := CrossingState.create(catalog, seed_value,
		catalog.crossings[crossing_id], _crossing_config(deck))
	var commands := 0
	var total_cards: int = state.deck.size() + state.hand.size() + state.spent.size()
	var clean := 0
	while not Minigame.is_over(state.outcome) and commands < COMMAND_CAP:
		# Pick the way this paw can cover for the least worth. Ties go to the
		# first listed, so the choice is deterministic under a seed.
		var best := ""
		var best_spend := 99
		for entry in state.ways():
			var way: Dictionary = entry
			var humour := String(way.get("humour", "any"))
			var cost := int(way.get("cost", 0))
			var have := 0
			var spend := 0
			for payment in _payment_order(state, humour):
				if have >= cost:
					break
				have += int(payment["worth"])
				spend += 1
			if have >= cost and spend < best_spend:
				best_spend = spend
				best = String(way.get("id", ""))
		if best == "":
			# Cannot cover anything: take the cheapest way and go short. That is
			# a legal, sensible line, and the module must survive it.
			best = String(state.ways()[0].get("id", ""))
		var choose := {"type": "choose", "way": best}
		var before := _crossing_snapshot(state)
		var result := state.do_command(choose)
		_guard(state, choose, before, result, _crossing_snapshot)
		commands += 1
		var humour := String(state.way(best).get("humour", "any"))
		for payment in _payment_order(state, humour):
			if state.shortfall() <= 0:
				break
			var put := {"type": "put", "card": String(payment["card"])}
			var put_before := _crossing_snapshot(state)
			var put_result := state.do_command(put)
			_guard(state, put, put_before, put_result, _crossing_snapshot)
			commands += 1
		if state.shortfall() <= 0:
			clean += 1
		var go := {"type": "go"}
		var go_before := _crossing_snapshot(state)
		var go_result := state.do_command(go)
		_guard(state, go, go_before, go_result, _crossing_snapshot)
		commands += 1
		if state.player_hp > state.player_max_hp:
			_violation("hp climbed over max")
		if state.deck.size() + state.hand.size() + state.spent.size() 				+ state.paid.size() != total_cards:
			_violation("energy was created or destroyed during the crossing")
		if not go_result.get("bitten", false) and int(go_result.get("short", 0)) == 0 \
				and int(go_result.get("hurt", 0)) != 0:
			_violation("a way paid in full still cost health")
	if not Minigame.is_over(state.outcome):
		_violation("the crossing never resolved")
	_guard_finished(state, [{"type": "go"}, {"type": "read_ahead"},
		{"type": "turn_back"}], _crossing_snapshot)
	return {"outcome": state.outcome, "at": state.at, "points": state.length(),
		"clean": clean, "hurts": state.hurts, "hp": state.player_hp,
		"commands": commands}


## Reckless: choose the first way and go without paying anything at all. The
## counterweight to the careful solver — if this ALSO gets home unharmed the
## shortfall risk is decoration, and if the careful line ever gets hurt the
## price of paying in full is a lie.
func rush_crossing(crossing_id: String, deck: Array, seed_value: int) -> Dictionary:
	_label = "crossing/%s/reckless seed %d" % [crossing_id, seed_value]
	var state := CrossingState.create(catalog, seed_value,
		catalog.crossings[crossing_id], _crossing_config(deck))
	var commands := 0
	while not Minigame.is_over(state.outcome) and commands < COMMAND_CAP:
		var choose := {"type": "choose", "way": String(state.ways()[0].get("id", ""))}
		var before := _crossing_snapshot(state)
		var result := state.do_command(choose)
		_guard(state, choose, before, result, _crossing_snapshot)
		var go := {"type": "go"}
		var go_before := _crossing_snapshot(state)
		var go_result := state.do_command(go)
		_guard(state, go, go_before, go_result, _crossing_snapshot)
		commands += 2
	if not Minigame.is_over(state.outcome):
		_violation("reckless play never resolved the crossing")
	return {"outcome": state.outcome, "at": state.at, "hurts": state.hurts,
		"hp": state.player_hp}


## Read Ahead must not lie: the point it previews has to be the point that
## actually arrives, or the aid is worse than nothing. It also costs exactly
## one paw, once per corner.
func probe_crossing_peek(crossing_id: String, deck: Array, seed_value: int) -> void:
	_label = "crossing/%s/peek seed %d" % [crossing_id, seed_value]
	var state := CrossingState.create(catalog, seed_value,
		catalog.crossings[crossing_id], _crossing_config(deck))
	if state.next_point().is_empty():
		return   # a one-point crossing has nothing to read ahead to
	var paws_before: int = state.paws
	var peek := state.do_command({"type": "read_ahead"})
	if not peek.get("ok", false):
		_violation("Read Ahead was refused at a fresh corner: %s" % peek.get("error", ""))
		return
	if state.paws != paws_before - 1:
		_violation("Read Ahead did not charge its paw")
	var promised := String(peek.get("point", {}).get("id", ""))
	if state.do_command({"type": "read_ahead"}).get("ok", false):
		_violation("Read Ahead was payable twice at one corner")
	state.do_command({"type": "choose", "way": String(state.ways()[0].get("id", ""))})
	state.do_command({"type": "go"})
	if String(state.point().get("id", "")) != promised:
		_violation("read '%s' but '%s' arrived" % [
			promised, state.point().get("id", "")])
	if state.paws != state.paw_limit:
		_violation("moving on did not refresh the paws")


func chaos_crossing(crossing_id: String, deck: Array, seed_value: int) -> void:
	_label = "crossing/%s/chaos seed %d" % [crossing_id, seed_value]
	_rng = CoreRng.new(seed_value * 7 + 3)
	var state := CrossingState.create(catalog, seed_value,
		catalog.crossings[crossing_id], _crossing_config(deck))
	var junk: Array[Dictionary] = [{}, {"type": "wibble"}, {"type": "press_on"},
		{"type": "choose", "way": "nowhere"}, {"type": "put", "card": "ghost"},
		{"type": "take_back", "card": "ghost"}]
	var total_cards: int = state.deck.size() + state.hand.size()
	var commands := 0
	while not Minigame.is_over(state.outcome) and commands < COMMAND_CAP:
		var command: Dictionary
		var roll := _rng.pick_index(10)
		if roll == 0:
			command = junk[_rng.pick_index(junk.size())]
		elif roll == 1:
			command = {"type": "read_ahead"}
		elif roll == 2:
			command = {"type": "turn_back"}
		elif roll < 6 and not state.ways().is_empty():
			var ways: Array = state.ways()
			command = {"type": "choose",
				"way": String(ways[_rng.pick_index(ways.size())].get("id", ""))}
		elif roll < 8 and not state.hand.is_empty():
			command = {"type": "put",
				"card": String(state.hand[_rng.pick_index(state.hand.size())])}
		elif roll == 8 and not state.paid.is_empty():
			command = {"type": "take_back",
				"card": String(state.paid[_rng.pick_index(state.paid.size())])}
		else:
			command = {"type": "go"}
		var before := _crossing_snapshot(state)
		var result := state.do_command(command)
		_guard(state, command, before, result, _crossing_snapshot)
		if state.at < 0 or state.at > state.length():
			_violation("at %d is outside 0..%d" % [state.at, state.length()])
		if state.paws < 0 or state.paws > state.paw_limit:
			_violation("paws %d outside 0..%d" % [state.paws, state.paw_limit])
		if state.player_hp > state.player_max_hp:
			_violation("hp climbed over max")
		if state.deck.size() + state.hand.size() + state.spent.size() 				+ state.paid.size() != total_cards:
			_violation("energy was created or destroyed: %d/%d/%d/%d of %d" % [
				state.deck.size(), state.hand.size(), state.spent.size(),
				state.paid.size(), total_cards])
		# Cards offered on a way are never on it twice, and never in the paw at
		# the same time — the one place a put/take_back pair could launder energy.
		for card_id in state.paid:
			if state.hand.has(card_id) and state.paid.count(card_id) \
					+ state.hand.count(card_id) > total_cards:
				_violation("card '%s' is both on the way and in the paw" % card_id)
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
