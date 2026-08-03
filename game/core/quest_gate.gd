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
##   requires  {"evidence": [ids], "standing": {guild: min}, "flags": {f: v}}

static func is_available(quest: Dictionary, profile: Dictionary) -> bool:
	if bool(quest.get("once", false)) \
			and profile.get("quests_done", []).has(String(quest.get("id", ""))):
		return false
	var requires: Dictionary = quest.get("requires", {})
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


## Records a completion. Returns true when it is new — `once` quests need
## this to stop coming back, and repeatable ones are harmless to re-record.
static func mark_done(profile: Dictionary, quest_id: String) -> bool:
	var done: Array = profile.get("quests_done", [])
	if done.has(quest_id):
		return false
	done.append(quest_id)
	profile["quests_done"] = done
	return true
