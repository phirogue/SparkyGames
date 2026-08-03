class_name LatticeState
extends RefCounted
## The Unpicking — pull threads in a safe order (docs/design/minigames.md #4).
## Lineage: pick-up-sticks x knot topology. Pure rules.
##
## A lattice of threads crosses on the page. Each thread lists the threads it
## lies OVER; a thread may only be pulled when nothing still lies over it.
## Pull them all and the working comes apart.
##
## A wrong pull twangs the lattice: +Alarm in a heist, or a gap effect into
## the next fight in a ward. Later charts have ELASTIC threads that re-cross
## when a neighbour goes, so the safe order changes mid-puzzle — telegraphed
## by a tremble, never a gotcha.
##
## This is the killer's verb. The rules are deliberately clean and quiet.

var lattice: Dictionary = {}
var threads: Dictionary = {}         # id -> {id, over: [...], path: [...]}
var order: Array[String] = []        # stable id order for rendering
var pulled: Array[String] = []       # in the order they came out
var alarm: int = 0
var gap_effects: Array[String] = []  # accrued from mis-pulls
var mistakes: int = 0
var outcome: int = Minigame.Outcome.ONGOING
var trembling: Array[String] = []    # threads whose over-list just changed
var log: CommandLog

var _over: Dictionary = {}           # id -> {other id: true}, live (elastic)
var _events: Array[String] = []


static func create(lattice_data: Dictionary) -> LatticeState:
	var state := LatticeState.new()
	state.lattice = lattice_data
	for thread in lattice_data.get("threads", []):
		var id := String(thread["id"])
		state.threads[id] = thread
		state.order.append(id)
		var over := {}
		for other in thread.get("over", []):
			over[String(other)] = true
		state._over[id] = over
	state.log = CommandLog.new()
	return state


# ------------------------------------------------------------------ topology

## The threads still lying over this one. Empty means it slides free.
func blockers(thread_id: String) -> Array[String]:
	var blocking: Array[String] = []
	for other in order:
		if pulled.has(other) or other == thread_id:
			continue
		if _over.get(other, {}).has(thread_id):
			blocking.append(other)
	return blocking


func can_pull(thread_id: String) -> bool:
	return threads.has(thread_id) and not pulled.has(thread_id) \
		and blockers(thread_id).is_empty()


func remaining() -> Array[String]:
	var left: Array[String] = []
	for id in order:
		if not pulled.has(id):
			left.append(id)
	return left


## A safe order for the whole lattice, or [] when none exists. This is the
## solvability check: the over-graph must be acyclic, and elastic rules must
## not be able to strand a thread. Used by validation and by the bots.
func safe_order() -> Array[String]:
	var probe := LatticeState.create(lattice)
	var sequence: Array[String] = []
	while not probe.remaining().is_empty():
		var moved := false
		for id in probe.remaining():
			if probe.can_pull(id):
				probe.do_command({"type": "pull", "thread": id})
				sequence.append(id)
				moved = true
				break
		if not moved:
			return []   # stranded: no legal pull and threads still in place
	return sequence


# ------------------------------------------------------------------ commands

func do_command(command: Dictionary) -> Dictionary:
	if Minigame.is_over(outcome):
		return _fail("the working is already undone")
	var result: Dictionary
	match String(command.get("type", "")):
		"pull":
			result = _cmd_pull(String(command.get("thread", "")))
		"give_up":
			result = _cmd_give_up()
		_:
			result = _fail("unknown command '%s'" % command.get("type", ""))
	if result["ok"]:
		log.record(0, command)
	return result


func _cmd_pull(thread_id: String) -> Dictionary:
	if not threads.has(thread_id):
		return _fail("no thread '%s' in this lattice" % thread_id)
	if pulled.has(thread_id):
		return _fail("that thread is already out")
	trembling.clear()
	if not can_pull(thread_id):
		# A mis-pull is a COST, not a rejection: the command succeeded, the
		# lattice twanged, and the player learns something. Rejecting it
		# would make the puzzle unloseable and the alarm decorative.
		mistakes += 1
		_apply_error_cost()
		_events.append("twang")
		return {"ok": true, "error": "", "pulled": false,
			"blocked_by": blockers(thread_id)}
	pulled.append(thread_id)
	_events.append("thread_out")
	_apply_elastic(thread_id)
	if remaining().is_empty():
		outcome = Minigame.Outcome.SUCCESS
		_events.append("lattice_undone")
	return {"ok": true, "error": "", "pulled": true, "blocked_by": []}


## Elastic threads: removing one lets others snap back across their
## neighbours. The data says exactly what re-crosses, so it is authored and
## deterministic rather than emergent and unfair.
func _apply_elastic(removed_id: String) -> void:
	for rule in lattice.get("elastic", []):
		if String(rule.get("when_removed", "")) != removed_id:
			continue
		for addition in rule.get("adds", []):
			var thread_id := String(addition.get("thread", ""))
			var over_id := String(addition.get("over", ""))
			if not threads.has(thread_id) or not threads.has(over_id):
				continue
			if pulled.has(thread_id) or pulled.has(over_id):
				continue
			_over[thread_id][over_id] = true
			if not trembling.has(over_id):
				trembling.append(over_id)
			_events.append("tremble")


func _apply_error_cost() -> void:
	var cost := String(lattice.get("error_cost", "alarm"))
	if cost == "alarm":
		alarm += int(lattice.get("alarm_per_mistake", 1))
		_events.append("alarm_raised")
		var threshold := int(lattice.get("alarm_threshold", 0))
		if threshold > 0 and alarm >= threshold:
			# Caught. The working is half-undone and the street knows: a
			# partial outcome, never a game-over.
			outcome = Minigame.Outcome.PARTIAL
			_events.append("spotted")
	else:
		gap_effects.append(cost)
		_events.append("gap_torn")


func _cmd_give_up() -> Dictionary:
	outcome = Minigame.Outcome.WALKED if pulled.is_empty() else Minigame.Outcome.PARTIAL
	_events.append("walked_away")
	return _ok()


# ------------------------------------------------------------------ results

func carried_effects() -> Array[String]:
	return gap_effects.duplicate()


func rewards() -> Dictionary:
	return lattice.get("rewards", {})


func take_events() -> Array[String]:
	var events := _events.duplicate()
	_events.clear()
	return events


func _ok() -> Dictionary:
	return {"ok": true, "error": ""}


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
