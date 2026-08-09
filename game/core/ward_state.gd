class_name WardState
extends RefCounted
## Patch the Ward — thread-patch quilting (docs/design/minigames.md #3).
## Lineage: Patchwork / Calico. Pure rules.
##
## A torn ward is a grid with a ragged hole. A rack offers patch polyominoes,
## and each patch is PAID with an energy card of its humour out of the same
## hand the player fights with — Moonlight (mysticism) pays for anything,
## and spent is spent. That is the whole point of the module: the mend comes
## out of tonight's stamina, so patching is an economic decision inside the
## prowl, not a free minigame bolted beside it.
##
## You will usually not cover everything. Each uncovered cell carries a gap
## effect into the next encounter (Minigame.GAP_EFFECTS); a perfect patch
## grants the ward's boon. Partial is the expected result, not a failure.

const WILD_HUMOUR := "mysticism"

var ward: Dictionary = {}
var width: int = 0
var height: int = 0
var hole: Dictionary = {}          # "r,c" -> true, the damaged cells
var covered: Dictionary = {}       # "r,c" -> patch id
var placed: Dictionary = {}        # patch id -> {row, col, rotation, cells}
var rack: Array = []               # [{id, shape, humour}]
var hand: Array = []               # energy card ids, shared with combat
var spent: Array = []              # paid cards; they do not come back
var outcome: int = Minigame.Outcome.ONGOING
var log: CommandLog

var _catalog: Catalog
var _events: Array[String] = []


static func create(catalog: Catalog, ward_data: Dictionary,
		hand_cards: Array) -> WardState:
	var state := WardState.new()
	state._catalog = catalog
	state.ward = ward_data
	state.width = int(ward_data.get("width", 0))
	state.height = int(ward_data.get("height", 0))
	for cell in ward_data.get("hole", []):
		state.hole[String(cell)] = true
	state.rack = ward_data.get("rack", []).duplicate(true)
	state.hand = hand_cards.duplicate()
	state.log = CommandLog.new()
	return state


# ------------------------------------------------------------------ geometry

func patch_def(patch_id: String) -> Dictionary:
	for patch in rack:
		if String(patch["id"]) == patch_id:
			return patch
	return {}


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


## Where a patch would land, as "r,c" keys. Does not check legality.
func footprint(patch_id: String, row: int, col: int, rotation: int) -> Array[String]:
	var cells: Array[String] = []
	var patch := patch_def(patch_id)
	if patch.is_empty():
		return cells
	for offset in rotate_shape(patch.get("shape", []), rotation):
		cells.append("%d,%d" % [row + int(offset[0]), col + int(offset[1])])
	return cells


## A patch fits when every cell it covers is a torn cell that nothing else
## has covered yet. Patches may not overlap and may not spill onto sound
## cloth — mending the undamaged parts is what an amateur does.
func fits(patch_id: String, row: int, col: int, rotation: int) -> bool:
	var cells := footprint(patch_id, row, col, rotation)
	if cells.is_empty():
		return false
	for key in cells:
		if not hole.has(key) or covered.has(key):
			return false
	return true


## The card this patch would take out of the hand: its own humour first,
## then a Moonlight wild. Returns -1 when the hand cannot pay.
func payment_index(patch_id: String) -> int:
	var humour := String(patch_def(patch_id).get("humour", ""))
	var wild := -1
	for i in hand.size():
		var card: Dictionary = _catalog.energy_cards.get(hand[i], {})
		if String(card.get("humour", "")) == humour:
			return i
		if String(card.get("humour", "")) == WILD_HUMOUR and wild < 0:
			wild = i
	return wild


func can_afford(patch_id: String) -> bool:
	return payment_index(patch_id) >= 0


# ------------------------------------------------------------------ commands

func do_command(command: Dictionary) -> Dictionary:
	if Minigame.is_over(outcome):
		return _fail("the mend is finished")
	var result: Dictionary
	match String(command.get("type", "")):
		"place":
			result = _cmd_place(String(command.get("patch", "")),
				int(command.get("row", -1)), int(command.get("col", -1)),
				int(command.get("rotation", 0)))
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


func _cmd_place(patch_id: String, row: int, col: int, rotation: int) -> Dictionary:
	if patch_def(patch_id).is_empty():
		return _fail("no patch '%s' on the rack" % patch_id)
	if placed.has(patch_id):
		return _fail("that patch is already down")
	if not fits(patch_id, row, col, rotation):
		return _fail("that patch does not sit in the tear there")
	var index := payment_index(patch_id)
	if index < 0:
		return _fail("no %s energy in hand to sew it with" %
			Catalog.humour_name(String(patch_def(patch_id).get("humour", ""))))
	# Pay FIRST, then place: the card is gone whatever happens next, which is
	# what makes lifting a patch a real decision rather than a free undo.
	spent.append(hand[index])
	hand.remove_at(index)
	var cells := footprint(patch_id, row, col, rotation)
	for key in cells:
		covered[key] = patch_id
	placed[patch_id] = {"row": row, "col": col, "rotation": rotation, "cells": cells}
	_events.append("patch_placed")
	if uncovered_cells().is_empty():
		# A perfect mend finishes itself — there is nothing left to decide.
		outcome = Minigame.Outcome.SUCCESS
		_events.append("ward_whole")
	return _ok()


## Lifting frees the cells but NOT the card: spent is spent, here as in
## combat. Otherwise a player would brute-force placements for free.
func _cmd_lift(patch_id: String) -> Dictionary:
	if not placed.has(patch_id):
		return _fail("that patch is not down")
	for key in placed[patch_id]["cells"]:
		covered.erase(key)
	placed.erase(patch_id)
	_events.append("patch_lifted")
	return _ok()


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


## For the UI and the bots: is there any legal, affordable move left? When
## there is not, the mend is as good as it is going to get.
func has_legal_move() -> bool:
	for patch in rack:
		var patch_id := String(patch["id"])
		if placed.has(patch_id) or not can_afford(patch_id):
			continue
		for rotation in 4:
			for row in height:
				for col in width:
					if fits(patch_id, row, col, rotation):
						return true
	return false


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
