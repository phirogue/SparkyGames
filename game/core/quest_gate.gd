class_name QuestGate
extends RefCounted
## Quest schema v2 gating — what is actually on the board right now.
##
## This is the rule that makes "tackle the quests in any order and
## everything still works" true: gating lives in ONE pure function that the
## hub, the scenario specs and the tests all call, instead of the hub
## deciding for itself what to draw.
##
## Quest fields it reads (see game/data/quests.json):
##   kind      "core" | "side"   core quests are the case's spine
##   once      true  = disappears from the board once completed
##   requires  {"evidence": [ids], "standing": {guild: min}, "flags": {f: v},
##              "quests": [ids already completed]}

static func is_available(quest: Dictionary, profile: Dictionary) -> bool:
	if bool(quest.get("once", false)) \
			and profile.get("quests_done", []).has(String(quest.get("id", ""))):
		return false
	var requires: Dictionary = quest.get("requires", {})
	# Work that opens other work (owner rule 2026-08-04: learning the city is
	# a mission in its own right). The board starts as ONE note, and finding
	# the Magpie is what puts the rest of it up.
	for quest_id in requires.get("quests", []):
		if not profile.get("quests_done", []).has(String(quest_id)):
			return false
	for evidence_id in requires.get("evidence", []):
		if not CaseState.has_evidence(profile, String(evidence_id)):
			return false
	var standing: Dictionary = requires.get("standing", {})
	for guild_id in standing:
		if CaseState.standing_of(profile, guild_id) < int(standing[guild_id]):
			return false
	var flags: Dictionary = requires.get("flags", {})
	for flag in flags:
		if int(profile.get("flags", {}).get(flag, -1)) != int(flags[flag]):
			return false
	return true


## The board, in reading order: core leads first (the case is the point),
## then side work. Stable within each group so the board does not reshuffle
## itself between visits.
static func board(catalog: Catalog, profile: Dictionary) -> Array:
	var core: Array = []
	var side: Array = []
	for quest_id in catalog.quests:
		var quest: Dictionary = catalog.quests[quest_id]
		if not is_available(quest, profile):
			continue
		if String(quest.get("kind", "side")) == "core":
			core.append(quest)
		else:
			side.append(quest)
	return core + side


## The doors out of the Mantel, and what opens each one (owner rule
## 2026-08-04: "when the Mantel is first shown, there should be fewer things
## on it"). A room that arrives fully furnished teaches nothing and reads as
## a control panel; this one fills up as Ash earns it. Pure, so the hub, the
## tutorial and the tests all agree on what is behind which door.
##
## Returns door ids -> whether they are open yet.
static func doors(profile: Dictionary) -> Dictionary:
	var owned: Array = profile.get("skills", [])
	var spare := 0
	for skill_id in owned:
		if skill_id != "scratch":
			spare += 1
	return {
		# The Casebook is his own memory: he has always had it.
		"casebook": true,
		# The board is empty until something is pinned to it. An empty Case
		# Board is the single most confusing screen in the game.
		"case_board": not profile.get("case", {}).get("evidence", []).is_empty(),
		# Brindle has to be FOUND before she will sell you anything.
		"exchange": profile.get("quests_done", []).has(MAGPIE_QUEST),
		# Nothing to choose between until the kit outgrows the tray.
		"loadout": spare > Catalog.LOADOUT_SIZE - 1,
	}


## The quest that introduces the city's fence, and with her the Exchange.
const MAGPIE_QUEST := "find_the_magpie"


## Records a completion. Returns true when it is new — `once` quests need
## this to stop coming back, and repeatable ones are harmless to re-record.
static func mark_done(profile: Dictionary, quest_id: String) -> bool:
	var done: Array = profile.get("quests_done", [])
	if done.has(quest_id):
		return false
	done.append(quest_id)
	profile["quests_done"] = done
	return true
