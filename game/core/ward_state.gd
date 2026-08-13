class_name WardState
extends RefCounted
## Patch the Ward — mend a tear off your own spool (minigames.md #3).
## Lineage: Patchwork / Calico crossed with a push-your-luck draw. Pure rules.
##
## OWNER 2026-08-13, the design this file now implements: "treat it as another
## card game. Each new card drawn has a shape on it, the shape corresponds to
## the energy type. Player can choose to draw more cards winding down the deck
## or leave early with parts not covered. Rather than having all patterns
## available from the get go."
##
## So there is no rack. There is a torn ward and there is your spool. DRAW
## takes the top card, spends it, and hands you whatever cloth that card cuts
## (data/patch_shapes.json: the humour is the character of the cut, the worth
## is its size). Lay it anywhere on the ward. Then decide again: another card
## off the spool, or stop and carry the gaps into the next fight.
##
## That is the whole tension, and it is the same clock the rest of the run
## runs on — every patch is a card the fighting will not have. Spent stays
## spent, exactly as in combat.
##
## Lifting a laid patch picks it back UP into the paw. It does not un-spend
## the card (the card went when you drew it, which was the decision) and it
## does not put anything back on the spool. Repositioning is free; drawing is
## not. That answers the owner's earlier complaint — energy only ever goes
## down on a choice the player actually made.
##
## PATCHES MAY OVERLAP and may hang over sound cloth (owner 2026-08-09). The
## only placement the rules refuse is one that falls off the ward. The only
## thing scored is how much of the TEAR is still open.

var ward: Dictionary = {}
var width: int = 0
var height: int = 0
var hole: Dictionary = {}          # "r,c" -> true, the damaged cells
var covered: Dictionary = {}       # "r,c" -> the TOPMOST patch key over it
var placed: Dictionary = {}        # patch key -> {row, col, rotation, cells, card}
var placed_order: Array[String] = []   # laying order; later patches sit on top
var deck: Array = []               # the spool, top is the END of the array
var spent: Array = []              # drawn cards; they do not come back
var drawn: String = ""             # the card in the paw, "" when empty-pawed
var outcome: int = Minigame.Outcome.ONGOING
var log: CommandLog

var _catalog: Catalog
var _events: Array[String] = []
var _serial: int = 0               # patch keys, so the same card twice is two


static func create(catalog: Catalog, ward_data: Dictionary,
		deck_cards: Array) -> WardState:
	var state := WardState.new()
	state._catalog = catalog
	state.ward = ward_data
	state.width = int(ward_data.get("width", 0))
	state.height = int(ward_data.get("height", 0))
	for cell in ward_data.get("hole", []):
		state.hole[String(cell)] = true
	state.deck = deck_cards.duplicate()
	state.log = CommandLog.new()
	return state


# ------------------------------------------------------------------ geometry

## The cloth a card cuts. Content, not code (law 9): a new energy card gets a
## shape in data/patch_shapes.json or Catalog.validate() fails the build.
func shape_of(card_id: String) -> Array:
	return _catalog.patch_shapes.get(card_id, {}).get("shape", [])


func humour_of(card_id: String) -> String:
	return String(_catalog.energy_cards.get(card_id, {}).get("humour", ""))


## What is in the paw right now, or {} when nothing is.
func drawn_patch() -> Dictionary:
	if drawn == "":
		return {}
	return {"card": drawn, "shape": shape_of(drawn), "humour": humour_of(drawn),
		"name": String(_catalog.patch_shapes.get(drawn, {}).get("name", ""))}


## A shape rotated 0/90/180/270 and normalised so its top-left sits at (0,0).
## Offsets are [row, col] pairs; rotation turns (r, c) into (c, -r).
static func rotate_shape(shape: Array, rotation: int) -> Array:
	var cells: Array = []
	for offset in shape:
		var r := int(offset[0])
		var c := int(offset[1])
		for _i in (rotation % 4 + 4) % 4:
			var turned_r := c
			var turned_c := -r
			r = turned_r
			c = turned_c
		cells.append([r, c])
	var min_r := 9999
	var min_c := 9999
	for cell in cells:
		min_r = mini(min_r, int(cell[0]))
		min_c = mini(min_c, int(cell[1]))
	var normalised: Array = []
	for cell in cells:
		normalised.append([int(cell[0]) - min_r, int(cell[1]) - min_c])
	normalised.sort()
	return normalised


## Where the card in the paw would land, as "r,c" keys. No legality check.
func footprint(card_id: String, row: int, col: int, rotation: int) -> Array[String]:
	var cells: Array[String] = []
	for offset in rotate_shape(shape_of(card_id), rotation):
		cells.append("%d,%d" % [row + int(offset[0]), col + int(offset[1])])
	return cells


## A patch fits anywhere it lands wholly ON THE WARD. It may overlap patches
## already down and it may cover sound cloth; neither buys anything. The grid
## edge is the only hard rule, because a patch half off the cloth is not a
## placement, it is a dropped patch.
func fits(card_id: String, row: int, col: int, rotation: int) -> bool:
	var cells := footprint(card_id, row, col, rotation)
	if cells.is_empty():
		return false
	for key in cells:
		var parts := String(key).split(",")
		var r := int(parts[0])
		var c := int(parts[1])
		if r < 0 or r >= height or c < 0 or c >= width:
			return false
	return true


## How much of the TEAR this placement would newly close — the only number
## worth anything, and the one the UI shows while a patch is in the paw.
func gain_at(card_id: String, row: int, col: int, rotation: int) -> int:
	var gain := 0
	for key in footprint(card_id, row, col, rotation):
		if hole.has(key) and not covered.has(key):
			gain += 1
	return gain


func can_draw() -> bool:
	return drawn == "" and not deck.is_empty() and not Minigame.is_over(outcome)


# ------------------------------------------------------------------ commands

func do_command(command: Dictionary) -> Dictionary:
	if Minigame.is_over(outcome):
		return _fail("the mend is finished")
	var result: Dictionary
	match String(command.get("type", "")):
		"draw":
			result = _cmd_draw()
		"place":
			result = _cmd_place(int(command.get("row", -1)),
				int(command.get("col", -1)), int(command.get("rotation", 0)))
		"lift":
			result = _cmd_lift(String(command.get("patch", "")))
		"finish":
			result = _cmd_finish()
		"give_up":
			result = _cmd_give_up()
		_:
			result = _fail("unknown command '%s'" % command.get("type", ""))
	if result["ok"]:
		log.record(0, command)
	return result


## The decision the whole module is about: one more card off the spool, or
## stop. The card is spent the moment it is drawn — that is what makes this a
## wager rather than a shopping trip.
func _cmd_draw() -> Dictionary:
	if drawn != "":
		return _fail("there is already cloth in your paw")
	if deck.is_empty():
		return _fail("the spool is bare")
	drawn = String(deck.pop_back())
	spent.append(drawn)
	if shape_of(drawn).is_empty():
		# Content is validated, so this is a broken build rather than a rule:
		# fail loudly rather than hand the player an invisible patch.
		push_error("energy card '%s' cuts no patch shape" % drawn)
	_events.append("patch_drawn")
	return {"ok": true, "error": "", "card": drawn}


func _cmd_place(row: int, col: int, rotation: int) -> Dictionary:
	if drawn == "":
		return _fail("nothing in your paw to lay")
	if not fits(drawn, row, col, rotation):
		return _fail("that patch would hang off the edge of the ward")
	var key := "p%d" % _serial
	_serial += 1
	placed[key] = {"row": row, "col": col, "rotation": rotation,
		"cells": footprint(drawn, row, col, rotation), "card": drawn}
	placed_order.append(key)
	drawn = ""
	_recompute_cover()
	_events.append("patch_placed")
	if uncovered_cells().is_empty():
		# A perfect mend finishes itself — there is nothing left to decide.
		outcome = Minigame.Outcome.SUCCESS
		_events.append("ward_whole")
	return _ok()


## Lifting picks a laid patch back UP into the paw, so it can go somewhere
## better. It costs nothing, because the card was spent at the draw. It needs
## an empty paw: two pieces of cloth in one paw is not a thing.
func _cmd_lift(patch_key: String) -> Dictionary:
	if not placed.has(patch_key):
		return _fail("that patch is not down")
	if drawn != "":
		return _fail("your paw is full")
	drawn = String(placed[patch_key]["card"])
	placed.erase(patch_key)
	placed_order.erase(patch_key)
	# Rebuilt rather than erased cell by cell: with patches allowed to stack,
	# lifting the top one has to UNCOVER back to whatever was underneath it.
	_recompute_cover()
	_events.append("patch_lifted")
	return _ok()


## Topmost-wins, in laying order. Cheap on a board this size, and the only
## way a stack stays honest through a lift.
func _recompute_cover() -> void:
	covered.clear()
	for patch_key in placed_order:
		for key in placed[patch_key]["cells"]:
			covered[String(key)] = patch_key


func _cmd_finish() -> Dictionary:
	if uncovered_cells().is_empty():
		outcome = Minigame.Outcome.SUCCESS
		_events.append("ward_whole")
	elif covered.is_empty():
		# Nothing sewn at all is a walk-away, not a partial mend.
		outcome = Minigame.Outcome.WALKED
		_events.append("walked_away")
	else:
		outcome = Minigame.Outcome.PARTIAL
		_events.append("ward_patched_thin")
	return _ok()


func _cmd_give_up() -> Dictionary:
	outcome = Minigame.Outcome.WALKED
	_events.append("walked_away")
	return _ok()


# ------------------------------------------------------------------ results

func uncovered_cells() -> Array[String]:
	var open: Array[String] = []
	for key in hole:
		if not covered.has(key):
			open.append(String(key))
	open.sort()
	return open


## What the mend carries into the next encounter: one gap effect per
## uncovered cell (they stack), or the ward's boon for a perfect patch.
func carried_effects() -> Array[String]:
	var effects: Array[String] = []
	if outcome == Minigame.Outcome.SUCCESS:
		var boon := String(ward.get("perfect_effect", ""))
		if boon != "":
			effects.append(boon)
		return effects
	if outcome == Minigame.Outcome.ONGOING:
		return effects
	var gap := String(ward.get("gap_effect", ""))
	if gap != "":
		for _cell in uncovered_cells():
			effects.append(gap)
	return effects


## The spool as it stands when the mend ends: what was not drawn stays wound
## on, and what was drawn is spent into the next encounter. Traversal, mending
## and fighting share one stamina, which is the point of all three.
func carryover() -> Dictionary:
	return {"deck": deck.duplicate(), "spent": spent.duplicate()}


## For the UI and the bots: where the cloth in the paw does the most good.
## Returns {} when there is nothing in the paw or nowhere left to help.
func best_placement() -> Dictionary:
	if drawn == "":
		return {}
	var best := {}
	var best_gain := 0
	for rotation in 4:
		for row in height:
			for col in width:
				if not fits(drawn, row, col, rotation):
					continue
				var gain := gain_at(drawn, row, col, rotation)
				if gain > best_gain:
					best_gain = gain
					best = {"row": row, "col": col, "rotation": rotation,
						"gain": gain}
	return best


## Is the mend still worth another card? True while the spool has something
## on it and the tear is still open — the honest reading of "keep going?".
func has_legal_move() -> bool:
	if drawn != "":
		return true
	return not deck.is_empty() and not uncovered_cells().is_empty()


func rewards() -> Dictionary:
	return ward.get("rewards", {})


## What this session actually PAYS. Rewards are earned, not attended: a
## partial patch or a walk-away must not tie the guild's knot.
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
