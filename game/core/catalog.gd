class_name Catalog
extends RefCounted
## Immutable content definitions, keyed by stable string id. Built from JSON
## by DataLoader (services layer); core never touches the filesystem.
##
## Humours (energy types): "ferocity", "guile", "shadow", "mysticism".

const HUMOURS: Array[String] = ["ferocity", "guile", "shadow", "mysticism"]

## Player-facing humour names. The fourth humour's DATA id stays "mysticism"
## (save-file stability) but its name is Moonlight again (owner, 2026-08-02).
## All UI goes through humour_name() — never .capitalize() on a humour id.
const HUMOUR_NAMES := {
	"ferocity": "Ferocity",
	"guile": "Guile",
	"shadow": "Shadow",
	"mysticism": "Moonlight",
}

static func humour_name(humour: String) -> String:
	return HUMOUR_NAMES.get(humour, String(humour).capitalize())

## The city's districts. Quests name one; a typo here would silently orphan
## a quest from its region rules, so the canon list (world-bible.md) is a
## const the validator checks against.
const DISTRICTS: Array[String] = [
	"thimblefield", "wickrow", "shambles", "gravamen", "mereside",
]

## Quest kinds: "core" quests are the case's spine, "side" is everything else.
const QUEST_KINDS: Array[String] = ["core", "side"]

## A lead's recap line shares one story page with two other lines and a
## fixed-size illustration. Measured against the story screen's text budget:
## ~70 characters is two wrapped lines at 37px, which fits; more does not.
const RECAP_LINE_MAX := 70

var energy_cards: Dictionary = {}   # id -> {id, humour, value}
var skills: Dictionary = {}         # id -> {id, name, cost, charges, effects, instinct}
var enemies: Dictionary = {}        # id -> {id, name, hp, intents}
var encounters: Dictionary = {}     # id -> {id, enemies, environment}
var achievements: Dictionary = {}   # id -> {id, name, description, stat, threshold, hidden}
var environments: Dictionary = {}   # id -> {id, name, color, cost_mod, sunbeam_turns, stealth_threshold}
var quests: Dictionary = {}         # id -> {id, name, board_card, encounters, kind, guild, district, once, requires}
var cases: Dictionary = {}          # id -> {id, name, question, suspects, evidence, leads}
var guilds: Dictionary = {}         # id -> {id, name, neutral_line, notices}
var favors: Dictionary = {}         # id -> {id, name, guild, flavor, redeem_lines}
# Mission minigames (docs/design/minigames.md). Puzzle CONTENT is data, so
# adding a puzzle never means touching a scene script.
var stitch_charts: Dictionary = {}  # id -> {width, height, clues, solution, mirrored}
var testimonies: Dictionary = {}    # id -> {witness, ribbons, patience}
var wards: Dictionary = {}          # id -> {width, height, hole, rack, effects}
var lattices: Dictionary = {}       # id -> {threads, elastic, error_cost}
var crossings: Dictionary = {}      # id -> {length, hazard, gusts}

func _init(data: Dictionary = {}) -> void:
	energy_cards = data.get("energy_cards", {})
	skills = data.get("skills", {})
	enemies = data.get("enemies", {})
	encounters = data.get("encounters", {})
	achievements = data.get("achievements", {})
	environments = data.get("environments", {})
	quests = data.get("quests", {})
	cases = data.get("cases", {})
	guilds = data.get("guilds", {})
	favors = data.get("favors", {})
	stitch_charts = data.get("stitch_charts", {})
	testimonies = data.get("testimonies", {})
	wards = data.get("wards", {})
	lattices = data.get("lattices", {})
	crossings = data.get("crossings", {})


## Every evidence id defined by any case — quest gates reference these
## across files, so the cross-file check needs one flat set.
func evidence_ids() -> Dictionary:
	var ids := {}
	for case_id in cases:
		for entry in cases[case_id].get("evidence", []):
			ids[String(entry.get("id", ""))] = true
	return ids


func _lead_exists(lead_id: String) -> bool:
	for case_id in cases:
		for lead in cases[case_id].get("leads", []):
			if String(lead.get("id", "")) == lead_id:
				return true
	return false

## Returns a list of problems; empty list means the catalog is coherent.
func validate() -> Array[String]:
	var problems: Array[String] = []
	for id in energy_cards:
		var card: Dictionary = energy_cards[id]
		if not HUMOURS.has(card.get("humour", "")):
			problems.append("energy card '%s' has unknown humour '%s'" % [id, card.get("humour", "")])
		if int(card.get("value", 0)) < 1:
			problems.append("energy card '%s' has non-positive value" % id)
	for id in skills:
		var skill: Dictionary = skills[id]
		for humour in skill.get("cost", {}):
			if not HUMOURS.has(humour):
				problems.append("skill '%s' cost uses unknown humour '%s'" % [id, humour])
		if not skill.get("instinct", false) and int(skill.get("charges", 0)) < 1:
			problems.append("skill '%s' has no charges and is not an instinct" % id)
	for id in enemies:
		var enemy: Dictionary = enemies[id]
		if int(enemy.get("hp", 0)) < 1:
			problems.append("enemy '%s' has non-positive hp" % id)
		var intents: Array = enemy.get("intents", [])
		if intents.is_empty():
			problems.append("enemy '%s' has no intents" % id)
		for intent in intents:
			if not ["health", "skills", "hand"].has(intent.get("target", "")):
				problems.append("enemy '%s' intent targets unknown '%s'" % [id, intent.get("target", "")])
			var mode := String(intent.get("mode", ""))
			var legal_modes: Array = ["pierce"] if intent.get("target") == "health" \
				else ["jam", "burn"] if intent.get("target") == "skills" else []
			if mode != "" and not legal_modes.has(mode):
				problems.append("enemy '%s' intent '%s' has unknown mode '%s' for target '%s'" % [
					id, intent.get("name", "?"), mode, intent.get("target", "")])
	for id in encounters:
		for enemy_id in encounters[id].get("enemies", []):
			if not enemies.has(enemy_id):
				problems.append("encounter '%s' references unknown enemy '%s'" % [id, enemy_id])
		var environment_id: String = encounters[id].get("environment", "")
		if not environments.is_empty() and not environments.has(environment_id):
			problems.append("encounter '%s' references unknown environment '%s'" % [id, environment_id])
	for id in quests:
		var quest: Dictionary = quests[id]
		if quest.get("encounters", []).is_empty():
			problems.append("quest '%s' has no encounters" % id)
		for encounter_id in quest.get("encounters", []):
			if not encounters.has(encounter_id):
				problems.append("quest '%s' references unknown encounter '%s'" % [id, encounter_id])
		if String(quest.get("board_card", "")).is_empty():
			problems.append("quest '%s' has no board card text" % id)
		problems.append_array(_validate_quest_v2(id, quest))
	for id in achievements:
		var achievement: Dictionary = achievements[id]
		if String(achievement.get("name", "")).is_empty():
			problems.append("achievement '%s' has no name" % id)
		if String(achievement.get("description", "")).is_empty():
			problems.append("achievement '%s' has no description" % id)
		if String(achievement.get("stat", "")).is_empty():
			problems.append("achievement '%s' watches no stat" % id)
		if int(achievement.get("threshold", 0)) < 1:
			problems.append("achievement '%s' has a non-positive threshold" % id)
	problems.append_array(_validate_cases())
	problems.append_array(_validate_guilds())
	problems.append_array(_validate_favors())
	problems.append_array(_validate_minigames())
	return problems


# ---------------------------------------------------------------- minigames

## Every module's content is checked for the one thing that would make it
## unplayable: a puzzle with no solution, a witness who cannot be broken, a
## tear the rack cannot cover. These are brute-forced where the search is
## small (minigames.md: "at test time, not runtime") — validate() runs at
## boot, so the expensive checks live behind `deep` and are called by the
## test suite instead.
func _validate_minigames(deep := false) -> Array[String]:
	var problems: Array[String] = []
	for id in stitch_charts:
		problems.append_array(_validate_stitch_chart(id, stitch_charts[id]))
	for id in testimonies:
		problems.append_array(_validate_testimony(id, testimonies[id]))
	for id in wards:
		problems.append_array(_validate_ward(id, wards[id], deep))
	for id in lattices:
		problems.append_array(_validate_lattice(id, lattices[id]))
	for id in crossings:
		problems.append_array(_validate_crossing(id, crossings[id]))
	return problems


## The expensive checks: coverability searches and solution uniqueness.
## Called by the tests, never at boot.
func validate_minigames_deep() -> Array[String]:
	return _validate_minigames(true)


const OUTCOME_KEYS: Array[String] = ["success", "partial", "walk_away"]


## Failure is a story outcome, never a game-over — so every module's data
## owes prose for all three endings (minigames.md shared rules).
func _validate_outcomes(kind: String, id: String, data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var texts: Dictionary = data.get("when_outcome", {})
	for key in OUTCOME_KEYS:
		if String(texts.get(key, "")).is_empty():
			problems.append("%s '%s' has no '%s' outcome text" % [kind, id, key])
	return problems


func _validate_stitch_chart(id: String, chart: Dictionary) -> Array[String]:
	var problems := _validate_outcomes("stitch chart", id, chart)
	var width := int(chart.get("width", 0))
	var height := int(chart.get("height", 0))
	if width < 2 or height < 2:
		problems.append("stitch chart '%s' is smaller than 2x2" % id)
		return problems
	if width > 6 or height > 6:
		problems.append("stitch chart '%s' is bigger than 6x6 (charts stay small)" % id)
	var state := StitchState.create(chart)
	for key in chart.get("clues", {}):
		var parts := String(key).split(",")
		if parts.size() != 2:
			problems.append("stitch chart '%s' has malformed clue key '%s'" % [id, key])
			continue
		var row := int(parts[0])
		var col := int(parts[1])
		if row < 0 or row >= height or col < 0 or col >= width:
			problems.append("stitch chart '%s' clue '%s' is off the grid" % [id, key])
		var value := int(chart["clues"][key])
		if value < 0 or value > StitchState.MAX_CLUE:
			problems.append("stitch chart '%s' clue '%s' is %d (must be 0-%d)" % [
				id, key, value, StitchState.MAX_CLUE])
	# The stored solution IS the existence proof, so it has to actually
	# solve: every edge real, every clue met, one closed loop.
	var solution: Array = chart.get("solution", [])
	if solution.is_empty():
		problems.append("stitch chart '%s' has no solution to prove it is solvable" % id)
		return problems
	for edge_id in solution:
		if not state.has_edge(String(edge_id)):
			problems.append("stitch chart '%s' solution names unknown edge '%s'" % [
				id, edge_id])
			return problems
		state.sewn[String(edge_id)] = true
	if not state.is_single_loop():
		problems.append("stitch chart '%s' solution is not one closed loop" % id)
	for key in chart.get("clues", {}):
		var parts := String(key).split(",")
		if parts.size() == 2 and not state.clue_satisfied(int(parts[0]), int(parts[1])):
			problems.append("stitch chart '%s' solution breaks clue '%s'" % [id, key])
	return problems


func _validate_testimony(id: String, testimony: Dictionary) -> Array[String]:
	var problems := _validate_outcomes("testimony", id, testimony)
	if String(testimony.get("witness", {}).get("name", "")).is_empty():
		problems.append("testimony '%s' has a nameless witness" % id)
	var guild_id := String(testimony.get("witness", {}).get("guild", ""))
	if guild_id != "" and not guilds.has(guild_id):
		problems.append("testimony '%s' witness belongs to unknown guild '%s'" % [
			id, guild_id])
	# The cat rule (canon): Ash cannot press humans, only animals about humans.
	var species := String(testimony.get("witness", {}).get("species", ""))
	if species == "human":
		problems.append("testimony '%s' presses a human witness — Ash cannot" % id)
	var ribbon_ids := {}
	for ribbon in testimony.get("ribbons", []):
		ribbon_ids[String(ribbon.get("id", ""))] = true
	var known_evidence := evidence_ids()
	var initial := 0
	var breakable := 0
	var wrong_paths := 0
	for ribbon in testimony.get("ribbons", []):
		var ribbon_id := String(ribbon.get("id", ""))
		if String(ribbon.get("text", "")).is_empty():
			problems.append("testimony '%s' ribbon '%s' has no text" % [id, ribbon_id])
		if bool(ribbon.get("initial", false)):
			initial += 1
		for spawned in ribbon.get("spawns", []):
			if not ribbon_ids.has(String(spawned)):
				problems.append("testimony '%s' ribbon '%s' spawns unknown '%s'" % [
					id, ribbon_id, spawned])
		var contradicted := String(ribbon.get("contradicted_by", ""))
		if contradicted == "":
			wrong_paths += 1
			continue
		breakable += 1
		if not known_evidence.has(contradicted):
			problems.append("testimony '%s' ribbon '%s' is contradicted by unknown evidence '%s'" % [
				id, ribbon_id, contradicted])
		if String(ribbon.get("break_text", "")).is_empty():
			problems.append("testimony '%s' ribbon '%s' breaks without saying so" % [
				id, ribbon_id])
	if initial < 1:
		problems.append("testimony '%s' opens with no ribbons" % id)
	if breakable < 1:
		problems.append("testimony '%s' has no breakable ribbon — the lead would dead-end" % id)
	# Patience must survive exploring every honest ribbon, or the fair-play
	# promise ("wrong-but-honest ribbons exist") becomes a trap.
	if int(testimony.get("patience", 0)) < wrong_paths:
		problems.append("testimony '%s' has patience %d but %d honest ribbons to try" % [
			id, int(testimony.get("patience", 0)), wrong_paths])
	return problems


func _validate_ward(id: String, ward: Dictionary, deep: bool) -> Array[String]:
	var problems := _validate_outcomes("ward", id, ward)
	var width := int(ward.get("width", 0))
	var height := int(ward.get("height", 0))
	if width < 1 or height < 1:
		problems.append("ward '%s' has no grid" % id)
		return problems
	var hole: Array = ward.get("hole", [])
	if hole.is_empty():
		problems.append("ward '%s' has no tear to mend" % id)
	for cell in hole:
		var parts := String(cell).split(",")
		if parts.size() != 2 or int(parts[0]) < 0 or int(parts[0]) >= height \
				or int(parts[1]) < 0 or int(parts[1]) >= width:
			problems.append("ward '%s' tear cell '%s' is off the grid" % [id, cell])
	var rack_area := 0
	for patch in ward.get("rack", []):
		var humour := String(patch.get("humour", ""))
		if not HUMOURS.has(humour):
			problems.append("ward '%s' patch '%s' has unknown humour '%s'" % [
				id, patch.get("id", "?"), humour])
		if patch.get("shape", []).is_empty():
			problems.append("ward '%s' patch '%s' has no shape" % [id, patch.get("id", "?")])
		rack_area += patch.get("shape", []).size()
	if rack_area < hole.size():
		problems.append("ward '%s' rack covers %d cells, the tear is %d — unmendable" % [
			id, rack_area, hole.size()])
	problems.append_array(Minigame.unknown_effects(
		[ward.get("gap_effect", "draft")], Minigame.GAP_EFFECTS).map(
			func(e): return "ward '%s' has unknown gap effect '%s'" % [id, e]))
	if String(ward.get("perfect_effect", "")) != "":
		problems.append_array(Minigame.unknown_effects(
			[ward["perfect_effect"]], Minigame.BOON_EFFECTS).map(
				func(e): return "ward '%s' has unknown boon '%s'" % [id, e]))
	for guild_id in ward.get("rewards", {}).get("standing", {}):
		if not guilds.has(guild_id):
			problems.append("ward '%s' rewards standing with unknown guild '%s'" % [id, guild_id])
	if ward.has("guild") and String(ward["guild"]) != "" and not guilds.has(String(ward["guild"])):
		problems.append("ward '%s' belongs to unknown guild '%s'" % [id, ward["guild"]])
	if String(ward.get("rewards", {}).get("favor", "")) != "" \
			and not favors.has(String(ward["rewards"]["favor"])):
		problems.append("ward '%s' grants unknown favor '%s'" % [id, ward["rewards"]["favor"]])
	if deep and not _hole_is_coverable(ward):
		problems.append("ward '%s' tear cannot be perfectly covered by its rack" % id)
	return problems


## Exact-cover search: can the rack tile the tear with no overlap and no
## spill? Small boards, heavy pruning (always fill the first open cell), so
## this is cheap enough for a test but still not something to do at boot.
func _hole_is_coverable(ward: Dictionary) -> bool:
	var open := {}
	for cell in ward.get("hole", []):
		open[String(cell)] = true
	var rack: Array = ward.get("rack", [])
	return _cover_search(open, rack, {})


func _cover_search(open: Dictionary, rack: Array, used: Dictionary) -> bool:
	if open.is_empty():
		return true
	var keys: Array = open.keys()
	keys.sort()
	var target := String(keys[0])
	var target_parts := target.split(",")
	var target_row := int(target_parts[0])
	var target_col := int(target_parts[1])
	for patch in rack:
		var patch_id := String(patch["id"])
		if used.has(patch_id):
			continue
		for rotation in 4:
			var shape := WardState.rotate_shape(patch.get("shape", []), rotation)
			# Anchor each cell of the shape onto the target in turn, so the
			# first open cell is always covered — that is the pruning.
			for anchor in shape:
				var row := target_row - int(anchor[0])
				var col := target_col - int(anchor[1])
				var cells: Array[String] = []
				var fits := true
				for offset in shape:
					var key := "%d,%d" % [row + int(offset[0]), col + int(offset[1])]
					if not open.has(key):
						fits = false
						break
					cells.append(key)
				if not fits:
					continue
				var next_open := open.duplicate()
				for key in cells:
					next_open.erase(key)
				used[patch_id] = true
				if _cover_search(next_open, rack, used):
					used.erase(patch_id)
					return true
				used.erase(patch_id)
	return false


func _validate_lattice(id: String, lattice: Dictionary) -> Array[String]:
	var problems := _validate_outcomes("lattice", id, lattice)
	var thread_ids := {}
	for thread in lattice.get("threads", []):
		thread_ids[String(thread.get("id", ""))] = true
	if thread_ids.size() < 2:
		problems.append("lattice '%s' needs at least two threads" % id)
	for thread in lattice.get("threads", []):
		for other in thread.get("over", []):
			if not thread_ids.has(String(other)):
				problems.append("lattice '%s' thread '%s' lies over unknown '%s'" % [
					id, thread.get("id", "?"), other])
	for rule in lattice.get("elastic", []):
		if not thread_ids.has(String(rule.get("when_removed", ""))):
			problems.append("lattice '%s' elastic rule fires on unknown thread '%s'" % [
				id, rule.get("when_removed", "?")])
		for addition in rule.get("adds", []):
			for key in ["thread", "over"]:
				if not thread_ids.has(String(addition.get(key, ""))):
					problems.append("lattice '%s' elastic rule names unknown thread '%s'" % [
						id, addition.get(key, "?")])
	var cost := String(lattice.get("error_cost", "alarm"))
	if cost != "alarm" and not Minigame.GAP_EFFECTS.has(cost):
		problems.append("lattice '%s' has unknown error cost '%s'" % [id, cost])
	# The real check: is there ANY order that pulls everything? A cycle in
	# the over-graph, or an elastic rule that strands a thread, makes the
	# puzzle quietly impossible — and it would look like a hard puzzle.
	if problems.is_empty() and LatticeState.create(lattice).safe_order().is_empty():
		problems.append("lattice '%s' has no safe pull order — it cannot be undone" % id)
	return problems


func _validate_crossing(id: String, crossing: Dictionary) -> Array[String]:
	var problems := _validate_outcomes("crossing", id, crossing)
	if int(crossing.get("length", 0)) < 1:
		problems.append("crossing '%s' has no distance to cover" % id)
	if int(crossing.get("hazard", 0)) < 1:
		problems.append("crossing '%s' has no hazard — slipping would be free" % id)
	var environment_id := String(crossing.get("environment", ""))
	if environment_id != "" and not environments.is_empty() \
			and not environments.has(environment_id):
		problems.append("crossing '%s' names unknown environment '%s'" % [id, environment_id])
	for humour in crossing.get("gust_script", []):
		if not HUMOURS.has(String(humour)):
			problems.append("crossing '%s' scripts unknown gust '%s'" % [id, humour])
	for humour in crossing.get("gust_weights", {}):
		if not HUMOURS.has(String(humour)):
			problems.append("crossing '%s' weights unknown gust '%s'" % [id, humour])
		if int(crossing["gust_weights"][humour]) < 0:
			problems.append("crossing '%s' has a negative weight for '%s'" % [id, humour])
	if crossing.get("gust_script", []).is_empty() \
			and crossing.get("gust_weights", {}).is_empty():
		problems.append("crossing '%s' has no gusts at all" % id)
	return problems


## Quest schema v2 (chapter1-build-plan Phase 1): kind/guild/district/once/
## requires. Gating is only trustworthy if the ids it names are real, so
## every reference is checked across files here rather than failing silently
## as a quest that can never appear on the board.
func _validate_quest_v2(id: String, quest: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var kind := String(quest.get("kind", ""))
	if not QUEST_KINDS.has(kind):
		problems.append("quest '%s' has unknown kind '%s'" % [id, kind])
	var district := String(quest.get("district", ""))
	if not DISTRICTS.has(district):
		problems.append("quest '%s' is in unknown district '%s'" % [id, district])
	var guild := String(quest.get("guild", ""))
	if guild != "" and not guilds.has(guild):
		problems.append("quest '%s' belongs to unknown guild '%s'" % [id, guild])
	for guild_id in quest.get("standing", {}):
		if not guilds.has(guild_id):
			problems.append("quest '%s' rewards standing with unknown guild '%s'" % [id, guild_id])
	if quest.has("grant_favor") and not favors.has(String(quest["grant_favor"])):
		problems.append("quest '%s' grants unknown favor '%s'" % [id, quest["grant_favor"]])
	var known_evidence := evidence_ids()
	for evidence_id in quest.get("grant_evidence", []):
		if not known_evidence.has(String(evidence_id)):
			problems.append("quest '%s' grants unknown evidence '%s'" % [id, evidence_id])
	if quest.has("lead") and not _lead_exists(String(quest["lead"])):
		problems.append("quest '%s' completes unknown lead '%s'" % [id, quest["lead"]])
	var requires: Dictionary = quest.get("requires", {})
	for evidence_id in requires.get("evidence", []):
		if not known_evidence.has(String(evidence_id)):
			problems.append("quest '%s' requires unknown evidence '%s'" % [id, evidence_id])
	for guild_id in requires.get("standing", {}):
		if not guilds.has(guild_id):
			problems.append("quest '%s' requires standing with unknown guild '%s'" % [id, guild_id])
	return problems


## The case file: every thread on the Case Board must have both ends. A lead
## pointing at evidence that does not exist is a lead the player can never
## finish, and it would render as a permanently empty pinned card.
func _validate_cases() -> Array[String]:
	var problems: Array[String] = []
	for case_id in cases:
		var case_def: Dictionary = cases[case_id]
		if String(case_def.get("question", "")).is_empty():
			problems.append("case '%s' has no question" % case_id)
		var evidence_by_id := {}
		for entry in case_def.get("evidence", []):
			evidence_by_id[String(entry.get("id", ""))] = entry
		var suspect_ids := {}
		for suspect in case_def.get("suspects", []):
			suspect_ids[String(suspect.get("id", ""))] = true
			if String(suspect.get("name", "")).is_empty():
				problems.append("case '%s' has a nameless suspect" % case_id)
		var lead_ids := {}
		for lead in case_def.get("leads", []):
			lead_ids[String(lead.get("id", ""))] = true
		for suspect in case_def.get("suspects", []):
			var by := String(suspect.get("revealed_by", "start"))
			if by != "start" and not evidence_by_id.has(by):
				problems.append("case '%s' suspect '%s' is revealed by unknown evidence '%s'" % [
					case_id, suspect.get("id", "?"), by])
		for entry in case_def.get("evidence", []):
			var entry_id := String(entry.get("id", ""))
			if String(entry.get("name", "")).is_empty():
				problems.append("case '%s' evidence '%s' has no name" % [case_id, entry_id])
			if String(entry.get("note", "")).is_empty():
				problems.append("case '%s' evidence '%s' has no note text" % [case_id, entry_id])
			if not lead_ids.has(String(entry.get("lead", ""))):
				problems.append("case '%s' evidence '%s' comes from unknown lead '%s'" % [
					case_id, entry_id, entry.get("lead", "")])
			for suspect_id in entry.get("implicates", []):
				if not suspect_ids.has(String(suspect_id)):
					problems.append("case '%s' evidence '%s' implicates unknown suspect '%s'" % [
						case_id, entry_id, suspect_id])
		for lead in case_def.get("leads", []):
			var lead_id := String(lead.get("id", ""))
			if String(lead.get("board_card", "")).is_empty():
				problems.append("case '%s' lead '%s' has no board card text" % [case_id, lead_id])
			# The recap card's text budget is fixed and the story screen
			# silently retires whatever overflows it, so an over-long recap
			# line does not look like a bug — it looks like a missing line.
			var recap := String(lead.get("recap_line", ""))
			if recap.is_empty():
				problems.append("case '%s' lead '%s' has no recap line" % [case_id, lead_id])
			elif recap.length() > RECAP_LINE_MAX:
				problems.append("case '%s' lead '%s' recap line is %d chars (max %d)" % [
					case_id, lead_id, recap.length(), RECAP_LINE_MAX])
			if not evidence_by_id.has(String(lead.get("evidence", ""))):
				problems.append("case '%s' lead '%s' yields unknown evidence '%s'" % [
					case_id, lead_id, lead.get("evidence", "")])
			for needed in lead.get("requires", []):
				if not evidence_by_id.has(String(needed)):
					problems.append("case '%s' lead '%s' requires unknown evidence '%s'" % [
						case_id, lead_id, needed])
	return problems


func _validate_guilds() -> Array[String]:
	var problems: Array[String] = []
	for id in guilds:
		var guild: Dictionary = guilds[id]
		if String(guild.get("name", "")).is_empty():
			problems.append("guild '%s' has no name" % id)
		if String(guild.get("neutral_line", "")).is_empty():
			problems.append("guild '%s' has no neutral line" % id)
		var seen := {}
		for notice in guild.get("notices", []):
			var at := int(notice.get("at", 0))
			if at == 0:
				problems.append("guild '%s' has a notice at neutral (0) — it would never fire" % id)
			if seen.has(at):
				problems.append("guild '%s' has two notices at %d" % [id, at])
			seen[at] = true
			if String(notice.get("text", "")).is_empty():
				problems.append("guild '%s' has an empty notice at %d" % [id, at])
	return problems


func _validate_favors() -> Array[String]:
	var problems: Array[String] = []
	for id in favors:
		var favor: Dictionary = favors[id]
		if String(favor.get("name", "")).is_empty():
			problems.append("favor '%s' has no name" % id)
		var guild := String(favor.get("guild", ""))
		if guild != "" and not guilds.has(guild):
			problems.append("favor '%s' is owed by unknown guild '%s'" % [id, guild])
		if favor.get("redeem_lines", []).is_empty():
			problems.append("favor '%s' has no redemption lines" % id)
	return problems
