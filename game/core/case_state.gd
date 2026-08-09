class_name CaseState
extends RefCounted
## The chapter spine's persistent state: what Ash has PROVED (evidence and
## leads), who owes him (favor-knots), and who resents him (guild standing).
##
## Pure rules — no Node, no FileAccess, no RNG. Everything here takes the
## profile dictionary and a Catalog and returns plain data, so the Case
## Board, the recap card, quest gating and the tests all read one source of
## truth instead of three copies of the same "does he have it yet" check.
##
## Profile shape (see SaveService.DEFAULT_PROFILE):
##   "case":     {"active": <case id>, "evidence": [ids], "leads_done": [ids]}
##   "standing": {<guild id>: int}     negative = they remember, and not fondly
##   "favors":   [favor ids]           knots tied in Ash's thread, owed TO him

# ------------------------------------------------------------------ evidence

static func progress(profile: Dictionary) -> Dictionary:
	return profile.get("case", {})


static func active_case(catalog: Catalog, profile: Dictionary) -> Dictionary:
	return catalog.cases.get(String(progress(profile).get("active", "")), {})


static func has_evidence(profile: Dictionary, evidence_id: String) -> bool:
	return progress(profile).get("evidence", []).has(evidence_id)


## Records a find. Returns true when it is NEW (so callers only toast once —
## replaying a lead must not re-announce the thing it yields).
static func add_evidence(profile: Dictionary, evidence_id: String) -> bool:
	var case_progress: Dictionary = progress(profile)
	var found: Array = case_progress.get("evidence", [])
	if found.has(evidence_id):
		return false
	found.append(evidence_id)
	case_progress["evidence"] = found
	profile["case"] = case_progress
	return true


static func mark_lead_done(profile: Dictionary, lead_id: String) -> bool:
	var case_progress: Dictionary = progress(profile)
	var done: Array = case_progress.get("leads_done", [])
	if done.has(lead_id):
		return false
	done.append(lead_id)
	case_progress["leads_done"] = done
	profile["case"] = case_progress
	return true


## Every evidence entry of the active case, in case-file order, each tagged
## with "found". The Case Board draws the un-found ones as empty pinned
## cards — the player can always see how many things are still out there.
static func evidence_slots(catalog: Catalog, profile: Dictionary) -> Array:
	var slots: Array = []
	for entry in active_case(catalog, profile).get("evidence", []):
		var slot: Dictionary = (entry as Dictionary).duplicate()
		slot["found"] = has_evidence(profile, String(entry["id"]))
		slots.append(slot)
	return slots


## Suspects whose card is face-up: revealed_by "start", or by evidence held.
## Each card is tagged "cleared" when the evidence that RULES THEM OUT is
## held — eliminating people is the one thing a case board is for
## (story-structure: every chapter ends with at least one suspect crossed
## off), and the finale's "Cross him off" must be true on screen, not only
## in Ash's narration.
static func suspects_known(catalog: Catalog, profile: Dictionary) -> Array:
	var known: Array = []
	for suspect in active_case(catalog, profile).get("suspects", []):
		var by := String(suspect.get("revealed_by", "start"))
		if by == "start" or has_evidence(profile, by):
			var card: Dictionary = (suspect as Dictionary).duplicate()
			var cleared_by := String(suspect.get("cleared_by", ""))
			card["cleared"] = cleared_by != "" and has_evidence(profile, cleared_by)
			known.append(card)
	return known


## The threads on the board: [evidence_id, suspect_id] for every FOUND piece
## of evidence that points at a KNOWN suspect. A thread to a suspect the
## player has not met yet would spoil the reveal, so it is filtered out.
static func threads(catalog: Catalog, profile: Dictionary) -> Array:
	var known := {}
	for suspect in suspects_known(catalog, profile):
		known[String(suspect["id"])] = true
	var lines: Array = []
	for entry in active_case(catalog, profile).get("evidence", []):
		if not has_evidence(profile, String(entry["id"])):
			continue
		for suspect_id in entry.get("implicates", []):
			if known.has(String(suspect_id)):
				lines.append([String(entry["id"]), String(suspect_id)])
	return lines


## The lead the player is on: the first whose "requires" are all satisfied
## and whose evidence is still missing. Empty when the case is closed.
static func next_lead(catalog: Catalog, profile: Dictionary) -> Dictionary:
	for lead in active_case(catalog, profile).get("leads", []):
		if has_evidence(profile, String(lead.get("evidence", ""))):
			continue
		var blocked := false
		for needed in lead.get("requires", []):
			if not has_evidence(profile, String(needed)):
				blocked = true
				break
		if not blocked:
			return lead
	return {}


## "Previously on": the chapter has to have a memory, so a cold launch
## opens with the last thing found and the thing to do next. Empty array
## means there is nothing worth recapping yet — the caller shows nothing
## rather than a card that says "you have done nothing".
##
## THREE SHORT LINES, deliberately (story-structure's <=3 lines x 8-14
## words). The story screen retires narration that overflows its fixed text
## budget, and a chattier recap lost its own headline to that guard. The
## note and the lead's name live on the Case Board, one tap away.
static func recap_lines(catalog: Catalog, profile: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var case_def := active_case(catalog, profile)
	if case_def.is_empty():
		return lines
	var found: Array = progress(profile).get("evidence", [])
	if found.is_empty():
		return lines
	var last_id := String(found.back())
	for entry in case_def.get("evidence", []):
		if String(entry["id"]) == last_id:
			lines.append("Last found: %s." % entry["name"])
			break
	lines.append("%d of %d things are on the board." % [
		found.size(), case_def.get("evidence", []).size()])
	var lead := next_lead(catalog, profile)
	if lead.is_empty():
		lines.append("Nothing left to pull. The case is as open as it gets.")
	else:
		# The lead's own recap_line, not its board card: board cards are
		# written to sell a quest at length and blow the recap's budget.
		lines.append(String(lead.get("recap_line", lead.get("board_card", ""))))
	return lines


# ------------------------------------------------------------------ standing

static func standing_of(profile: Dictionary, guild_id: String) -> int:
	return int(profile.get("standing", {}).get(guild_id, 0))


## Applies {guild_id: delta} and returns the notice lines whose threshold was
## CROSSED by this change — guild standing is felt as gossip, never as a
## number on a bar (there is no standing UI this chapter, by design).
static func apply_standing(catalog: Catalog, profile: Dictionary,
		deltas: Dictionary) -> Array[String]:
	var notices: Array[String] = []
	var standing: Dictionary = profile.get("standing", {})
	for guild_id in deltas:
		var before := int(standing.get(guild_id, 0))
		var after := before + int(deltas[guild_id])
		standing[guild_id] = after
		for notice in catalog.guilds.get(guild_id, {}).get("notices", []):
			var at := int(notice.get("at", 0))
			# Thresholds fire in the direction they sit: a -2 line fires on
			# the way DOWN past -2, a +3 line on the way UP past +3.
			var crossed := (at >= 0 and before < at and after >= at) \
				or (at < 0 and before > at and after <= at)
			if crossed:
				notices.append(String(notice.get("text", "")))
	profile["standing"] = standing
	return notices


## The line that describes where a guild stands RIGHT NOW: the satisfied
## threshold furthest from neutral, or the guild's neutral line.
static func standing_line(catalog: Catalog, profile: Dictionary,
		guild_id: String) -> String:
	var guild: Dictionary = catalog.guilds.get(guild_id, {})
	if guild.is_empty():
		return ""
	var value := standing_of(profile, guild_id)
	var best := String(guild.get("neutral_line", ""))
	var best_distance := 0
	for notice in guild.get("notices", []):
		var at := int(notice.get("at", 0))
		var satisfied := (at >= 0 and value >= at) or (at < 0 and value <= at)
		if satisfied and absi(at) > best_distance:
			best_distance = absi(at)
			best = String(notice.get("text", ""))
	return best


# ------------------------------------------------------------------- favors

static func has_favor(profile: Dictionary, favor_id: String) -> bool:
	return profile.get("favors", []).has(favor_id)


static func grant_favor(profile: Dictionary, favor_id: String) -> bool:
	var favors: Array = profile.get("favors", [])
	if favors.has(favor_id):
		return false
	favors.append(favor_id)
	profile["favors"] = favors
	return true


## Spending a knot UNTIES it: settled debts stop being useful, which is the
## whole point of the Gentleman's economy (world-bible.md).
static func spend_favor(profile: Dictionary, favor_id: String) -> bool:
	var favors: Array = profile.get("favors", [])
	if not favors.has(favor_id):
		return false
	favors.erase(favor_id)
	profile["favors"] = favors
	return true


static func held_favors(catalog: Catalog, profile: Dictionary) -> Array:
	var held: Array = []
	for favor_id in profile.get("favors", []):
		if catalog.favors.has(favor_id):
			held.append(catalog.favors[favor_id])
	return held
