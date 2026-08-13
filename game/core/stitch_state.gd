class_name StitchState
extends RefCounted
## Seam & Stitch — sew one closed seam (docs/design/minigames.md #1).
## Lineage: Slitherlink. Pure rules; no Node, no rendering, no global RNG.
##
## The board is a dot grid. Between the dots run EDGES, and the player sews
## or unpicks them freely. Some cells carry a clue: how many of that cell's
## four edges the finished seam uses. It is solved when the sewn edges form
## exactly ONE closed loop and every clue is satisfied.
##
## Edge ids are stable strings so a command log is readable and replayable:
##   "h:<r>:<c>"  the horizontal edge below dot-row r, spanning cell column c
##   "v:<r>:<c>"  the vertical edge right of dot-column c, spanning cell row r
## For a w x h cell grid there are (h+1) dot rows and (w+1) dot columns.
##
## Calm puzzle: unpicking is free and there is no timer. The only pressure
## is Squint, an optional aid that costs a paw.

enum Command { SEW, UNPICK, SQUINT, GIVE_UP }

const MAX_CLUE := 3   # docs cap clues at 0-3; 4 is legal Slitherlink but
                      # reads as a solid box and was cut for legibility

var chart: Dictionary = {}        # the data block this session is playing
var width: int = 0                # cells across
var height: int = 0               # cells down
var clues: Dictionary = {}        # "r,c" -> int
var mirrored: bool = false        # Ch3: clues are shown reflected (view-only)

var sewn: Dictionary = {}         # edge id -> true
var paws: int = 3                 # Squint budget
## What Squint last said. TWO answers, because a stuck player has two
## different problems and the old aid only ever spoke to one of them:
##   squint_wrong -- a stitch that is sewn and should not be (unpick it)
##   squint_sew   -- a stitch the finished seam uses and you have not sewn
## The second is the one the owner asked for: an aid that only ever says
## "something is wrong, somewhere" is an aid that does nothing.
var squint_wrong: String = ""
var squint_sew: String = ""
var outcome: int = Minigame.Outcome.ONGOING
var log: CommandLog

var _solution: Dictionary = {}    # edge id -> true, from the chart data
var _events: Array[String] = []


static func create(chart_data: Dictionary) -> StitchState:
	var state := StitchState.new()
	state.chart = chart_data
	state.width = int(chart_data.get("width", 0))
	state.height = int(chart_data.get("height", 0))
	state.clues = chart_data.get("clues", {})
	state.mirrored = bool(chart_data.get("mirrored", false))
	state.paws = int(chart_data.get("paws", 3))
	state.log = CommandLog.new()
	for edge_id in chart_data.get("solution", []):
		state._solution[String(edge_id)] = true
	return state


# ------------------------------------------------------------------ geometry

## Every edge id on this board, in a stable order (the renderer walks this,
## so it never has to know the id format).
func all_edges() -> Array[String]:
	var edges: Array[String] = []
	for r in height + 1:
		for c in width:
			edges.append("h:%d:%d" % [r, c])
	for r in height:
		for c in width + 1:
			edges.append("v:%d:%d" % [r, c])
	return edges


func has_edge(edge_id: String) -> bool:
	var parts := edge_id.split(":")
	if parts.size() != 3:
		return false
	var r := int(parts[1])
	var c := int(parts[2])
	if parts[0] == "h":
		return r >= 0 and r <= height and c >= 0 and c < width
	if parts[0] == "v":
		return r >= 0 and r < height and c >= 0 and c <= width
	return false


## The two dots an edge joins, as "r,c" keys.
func edge_dots(edge_id: String) -> Array[String]:
	var parts := edge_id.split(":")
	var r := int(parts[1])
	var c := int(parts[2])
	if parts[0] == "h":
		return ["%d,%d" % [r, c], "%d,%d" % [r, c + 1]]
	return ["%d,%d" % [r, c], "%d,%d" % [r + 1, c]]


## The four edges around a cell, clockwise from the top.
func cell_edges(row: int, col: int) -> Array[String]:
	return [
		"h:%d:%d" % [row, col],
		"v:%d:%d" % [row, col + 1],
		"h:%d:%d" % [row + 1, col],
		"v:%d:%d" % [row, col],
	]


func cell_count(row: int, col: int) -> int:
	var count := 0
	for edge_id in cell_edges(row, col):
		if sewn.has(edge_id):
			count += 1
	return count


## A clue is BROKEN once too many of its edges are sewn — the renderer marks
## those red so the player sees the mistake without being punished for it.
func clue_broken(row: int, col: int) -> bool:
	var key := "%d,%d" % [row, col]
	if not clues.has(key):
		return false
	return cell_count(row, col) > int(clues[key])


func clue_satisfied(row: int, col: int) -> bool:
	var key := "%d,%d" % [row, col]
	if not clues.has(key):
		return true
	return cell_count(row, col) == int(clues[key])


# ------------------------------------------------------------------ commands

func do_command(command: Dictionary) -> Dictionary:
	if Minigame.is_over(outcome):
		return _fail("the working is finished")
	var result: Dictionary
	match String(command.get("type", "")):
		"sew":
			result = _cmd_sew(String(command.get("edge", "")))
		"unpick":
			result = _cmd_unpick(String(command.get("edge", "")))
		"squint":
			result = _cmd_squint()
		"give_up":
			result = _cmd_give_up()
		_:
			result = _fail("unknown command '%s'" % command.get("type", ""))
	if result["ok"]:
		log.record(0, command)
	return result


func _cmd_sew(edge_id: String) -> Dictionary:
	if not has_edge(edge_id):
		return _fail("no edge '%s' on this chart" % edge_id)
	if sewn.has(edge_id):
		return _fail("that stitch is already sewn")
	sewn[edge_id] = true
	_clear_hint()
	_check_complete()
	return _ok()


## Free, always. A calm puzzle punishes nothing about thinking again.
##
## Completion is checked HERE as well as after sewing. It was not, and that
## is the whole of "when a legal solution is presented, nothing happens":
## a player who over-sewed and then unpicked their way onto the answer had
## already made the last move the game was listening for.
func _cmd_unpick(edge_id: String) -> Dictionary:
	if not has_edge(edge_id):
		return _fail("no edge '%s' on this chart" % edge_id)
	if not sewn.has(edge_id):
		return _fail("there is no stitch there to unpick")
	sewn.erase(edge_id)
	_clear_hint()
	_check_complete()
	return _ok()


## Squint: the chart says one true thing out loud, for a paw.
##
## It answers both of a stuck player's questions at once — what have I sewn
## that the seam does not use, and where does the seam actually go — because
## the previous version answered neither usefully ("nothing sewn is wrong,
## yet" is not a hint, and the owner reported Squint as doing nothing).
## Both answers are read off the chart's stored solution, so the aid can
## never mislead. It charges only when it has something to say.
func _cmd_squint() -> Dictionary:
	if paws < 1:
		return _fail("no paws left to squint with")
	var wrong: Array[String] = []
	for edge_id in sewn:
		if not _solution.has(edge_id):
			wrong.append(String(edge_id))
	wrong.sort()   # deterministic: the same board always names the same stitch
	var missing := _next_solution_edge()
	if wrong.is_empty() and missing == "":
		# Nothing wrong and nothing left to add: the seam is already right.
		# Billing for that would be a cheat.
		_clear_hint()
		_events.append("squint_clean")
		return {"ok": true, "error": "", "wrong": "", "sew": "", "clean": true}
	paws -= 1
	squint_wrong = wrong[0] if not wrong.is_empty() else ""
	squint_sew = missing
	_events.append("squint")
	return {"ok": true, "error": "", "wrong": squint_wrong, "sew": squint_sew,
		"clean": false}


## One stitch the finished seam uses that is not sewn yet, preferring one
## that continues work already on the cloth — a hint next to your own paw
## reads as "keep going", a hint across the board reads as a new puzzle.
func _next_solution_edge() -> String:
	var missing: Array[String] = []
	for edge_id in _solution:
		if not sewn.has(String(edge_id)):
			missing.append(String(edge_id))
	if missing.is_empty():
		return ""
	missing.sort()
	var touched := {}
	for edge_id in sewn:
		for dot in edge_dots(String(edge_id)):
			touched[dot] = true
	for edge_id in missing:
		for dot in edge_dots(edge_id):
			if touched.has(dot):
				return edge_id
	return missing[0]


func _clear_hint() -> void:
	squint_wrong = ""
	squint_sew = ""


func _cmd_give_up() -> Dictionary:
	# Walk-away, not failure: the working doesn't hold and the story says so.
	outcome = Minigame.Outcome.WALKED
	_events.append("walked_away")
	return _ok()


# ------------------------------------------------------------------ solving

## One closed loop, every clue satisfied. Checked after each stitch so the
## seam cinches taut the instant it is true.
func _check_complete() -> void:
	if is_solved():
		outcome = Minigame.Outcome.SUCCESS
		_events.append("seam_closed")


func is_solved() -> bool:
	if sewn.is_empty():
		return false
	for key in clues:
		var parts := String(key).split(",")
		if not clue_satisfied(int(parts[0]), int(parts[1])):
			return false
	return is_single_loop()


## Two conditions, both necessary: every dot the seam touches has exactly two
## stitches (so the thread runs through, never branches or stops), and all
## the stitches belong to ONE component (so it is one seam, not three).
func is_single_loop() -> bool:
	var degree := {}
	for edge_id in sewn:
		for dot in edge_dots(String(edge_id)):
			degree[dot] = int(degree.get(dot, 0)) + 1
	for dot in degree:
		if int(degree[dot]) != 2:
			return false
	return _connected_component_size() == sewn.size()


## How many sewn edges are reachable from any one of them.
func _connected_component_size() -> int:
	if sewn.is_empty():
		return 0
	var by_dot := {}
	for edge_id in sewn:
		for dot in edge_dots(String(edge_id)):
			if not by_dot.has(dot):
				by_dot[dot] = []
			by_dot[dot].append(String(edge_id))
	var start := String(sewn.keys()[0])
	var seen := {start: true}
	var queue: Array[String] = [start]
	while not queue.is_empty():
		var current: String = queue.pop_back()
		for dot in edge_dots(current):
			for neighbour in by_dot.get(dot, []):
				if not seen.has(neighbour):
					seen[neighbour] = true
					queue.append(String(neighbour))
	return seen.size()


## Every number on the chart has exactly what it asked for. NOT the same as
## solved: a chart can answer all of its clues with a thread that branches,
## stops short, or runs as two separate rings.
func all_clues_satisfied() -> bool:
	return clues_satisfied() == clues.size()


## Why a board that answers every clue is still not a seam, as a key the UI
## can hang a line on. "" means there is nothing to say — either the seam is
## closed, or a number is still unanswered and that is the louder problem.
##
## Owner 2026-08-13: a player who satisfies every constraint and then watches
## nothing happen has no way to learn that a closed LOOP is a separate rule.
## The board knows exactly which of the three ways it failed, so it says so.
##   loose_end -- a dot with one stitch: the thread stops in mid-air
##   branch    -- a dot with three or four: the thread forks
##   two_rings -- every dot fine, but the stitches make more than one loop
func seam_fault() -> String:
	if sewn.is_empty() or not all_clues_satisfied() or is_solved():
		return ""
	var degree := {}
	for edge_id in sewn:
		for dot in edge_dots(String(edge_id)):
			degree[dot] = int(degree.get(dot, 0)) + 1
	var loose := false
	for dot in degree:
		if int(degree[dot]) > 2:
			return "branch"        # the worst-formed one wins: say that first
		if int(degree[dot]) == 1:
			loose = true
	if loose:
		return "loose_end"
	return "two_rings"


## Progress for the UI: clues satisfied out of clues given.
func clues_satisfied() -> int:
	var count := 0
	for key in clues:
		var parts := String(key).split(",")
		if clue_satisfied(int(parts[0]), int(parts[1])):
			count += 1
	return count


## The reward block the story layer applies on success.
func rewards() -> Dictionary:
	return chart.get("rewards", {})


## What this session actually PAYS — the reward table only on a closed seam.
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
