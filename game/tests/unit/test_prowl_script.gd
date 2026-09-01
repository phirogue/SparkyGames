extends TestCase
## The prowl script: a quest is an ordered run of fights, story beats,
## minigames and lessons (core/prowl_script.gd), and the Chapter 1 arc that
## rides on it.
##
## The rules worth pinning are the ones that were wrong the first time a
## quest stopped being a pure fight-chain: depth is counted in FIGHTS, and
## Press On is only offered when there is another fight to press to.


func _catalog() -> Catalog:
	return DataLoader.load_catalog()


func _quest(steps: Array) -> Dictionary:
	return {"id": "q", "name": "Q", "board_card": "c", "steps": steps}


func test_a_bare_encounter_list_still_compiles_to_a_script() -> void:
	var quest := {"encounters": ["a", "b"]}
	var steps := ProwlScript.steps_of(quest)
	assert_eq(steps.size(), 2, "one step per encounter")
	assert_eq(ProwlScript.type_of(steps[0]), ProwlScript.BATTLE, "and they are fights")
	assert_eq(ProwlScript.battles_of(quest), ["a", "b"] as Array, "in order")


func test_depth_counts_fights_not_steps() -> void:
	# Walking to the Ratsmeet is not danger. If depth counted steps, a quest
	# with three story beats before its second fight would pay a deep-prowl
	# multiplier for a conversation.
	var quest := _quest([
		{"type": "story", "lines": ["a"]},
		{"type": "battle", "encounter": "q_saw_gutter"},
		{"type": "story", "lines": ["b"]},
		{"type": "lesson", "lesson": "stitching"},
		{"type": "battle", "encounter": "q_rats_doorman"},
	])
	assert_eq(ProwlScript.depth_at(quest, 1), 0, "the first fight is depth 0")
	assert_eq(ProwlScript.depth_at(quest, 4), 1, "the second is depth 1, not 4")


func test_press_on_is_only_offered_when_there_is_another_fight() -> void:
	var quest := _quest([
		{"type": "battle", "encounter": "q_saw_gutter"},
		{"type": "story", "lines": ["the last word"]},
	])
	assert_true(not ProwlScript.has_battle_after(quest, 0),
		"a quest that ends on a conversation must not ask 'deeper?'")
	assert_eq(ProwlScript.next_battle_after(quest, 0), "", "and previews nothing")
	var two := _quest([
		{"type": "battle", "encounter": "q_saw_gutter"},
		{"type": "story", "lines": ["walking"]},
		{"type": "battle", "encounter": "q_rats_doorman"},
	])
	assert_true(ProwlScript.has_battle_after(two, 0), "there IS another fight")
	assert_eq(ProwlScript.next_battle_after(two, 0), "q_rats_doorman",
		"and the card previews it, not the story beat in between")


## Owner rule 2026-08-04: every concept is taught the first time it is
## introduced. A minigame that appears in a quest with no lesson before it is
## a player meeting a whole ruleset cold.
func test_every_minigame_in_a_quest_is_taught_before_it_is_played() -> void:
	var catalog := _catalog()
	for quest_id in catalog.quests:
		var steps := ProwlScript.steps_of(catalog.quests[quest_id])
		var taught := {}
		for i in steps.size():
			var step: Dictionary = steps[i]
			match ProwlScript.type_of(step):
				ProwlScript.LESSON:
					var lesson: Dictionary = catalog.lessons[step["lesson"]]
					var spec := String(lesson.get("scene", "")).split(":")
					if spec.size() > 0:
						taught[spec[0]] = true
				ProwlScript.MINIGAME:
					assert_true(taught.has(String(step["module"])),
						"%s plays %s at step %d with no lesson before it"
							% [quest_id, step["module"], i])


## A lesson that nothing ever teaches can only be found by a player who goes
## looking in the Casebook for a rule they have not met — which is backwards.
func test_every_lesson_is_delivered_somewhere() -> void:
	var catalog := _catalog()
	var delivered := {}
	for quest_id in catalog.quests:
		for step in ProwlScript.steps_of(catalog.quests[quest_id]):
			if ProwlScript.type_of(step) == ProwlScript.LESSON:
				delivered[String(step["lesson"])] = quest_id
	for lesson_id in catalog.lessons:
		# growing_stronger is delivered by sharpen_the_claws; the fight and
		# Mantel tutorials are the live Coach, which is not a lesson step.
		assert_true(delivered.has(lesson_id),
			"lesson '%s' is never taught by any quest" % lesson_id)


## The Chapter 1 opening arc, walked the way a player walks it: finish what
## the board offers, see what the board offers next. A gate that names a
## quest nothing unlocks would strand the chapter, and the board would go
## quietly empty rather than loudly wrong.
func test_the_chapter_one_arc_can_be_walked_to_the_end() -> void:
	var catalog := _catalog()
	var profile := SaveService.DEFAULT_PROFILE.duplicate(true)
	profile["prologue_done"] = true
	var core_total := 0
	for quest_id in catalog.quests:
		if String(catalog.quests[quest_id].get("kind", "")) == "core":
			core_total += 1
	var done := 0
	for _round in 12:
		var board := QuestGate.board(catalog, profile)
		var took_one := false
		for quest: Dictionary in board:
			if String(quest.get("kind", "")) != "core":
				continue
			QuestGate.mark_done(profile, String(quest["id"]))
			# Finishing a quest grants what it promises; the next gate may
			# read any of it.
			for evidence_id in quest.get("grant_evidence", []):
				CaseState.add_evidence(profile, String(evidence_id))
			for step in ProwlScript.steps_of(quest):
				for evidence_id in step.get("grant_evidence", []):
					CaseState.add_evidence(profile, String(evidence_id))
				if step.has("standing"):
					CaseState.apply_standing(catalog, profile, step["standing"])
			if quest.has("standing"):
				CaseState.apply_standing(catalog, profile, quest["standing"])
			done += 1
			took_one = true
			break
		if not took_one:
			break
	assert_eq(done, core_total,
		"only %d of %d core quests are reachable — a gate names something nothing opens"
			% [done, core_total])


## The first board is one note, and the board grows. A player who finishes
## the Magpie and sees nothing new has been told the chapter is over.
func test_the_board_opens_up_as_the_arc_is_walked() -> void:
	var catalog := _catalog()
	var profile := SaveService.DEFAULT_PROFILE.duplicate(true)
	profile["prologue_done"] = true
	assert_eq(QuestGate.board(catalog, profile).size(), 2,
		"two notes to start — the thread and the Magpie (owner 2026-08-10)")
	# This walker follows the thread first, so the rest of the pacing reads
	# as it did when the board opened with the Magpie alone.
	QuestGate.mark_done(profile, "follow_the_thread")
	QuestGate.mark_done(profile, "find_the_magpie")
	var after_magpie := QuestGate.board(catalog, profile)
	# The board NARROWS here rather than opening (gating fixed 2026-08-31):
	# the side patrols used to hang beside the carrying, so a player could
	# walk wisp rounds for several nights while Elspeth sat dead in her chair
	# — and then be told Cardew came "at first light". A body does not wait,
	# and neither does the board.
	assert_eq(after_magpie.size(), 1,
		"the carrying, alone: nothing is offered beside a body being carried out")
	var core_ids: Array[String] = []
	for quest: Dictionary in after_magpie:
		if String(quest.get("kind", "")) == "core":
			core_ids.append(String(quest["id"]))
	assert_eq(core_ids, ["the_carrying"] as Array[String],
		"and exactly one piece of the CASE, because a body does not wait its turn")
	QuestGate.mark_done(profile, "the_carrying")
	var middle: Array[String] = []
	for quest: Dictionary in QuestGate.board(catalog, profile):
		if String(quest.get("kind", "")) == "core":
			middle.append(String(quest["id"]))
	middle.sort()
	assert_eq(middle, ["ask_the_rats", "sharpen_the_claws", "what_i_saw"] as Array[String],
		"then three real choices at once — this is where the night stops being a corridor")


## Law 17's minigame cousin: a story step keyed to a minigame outcome plays
## only on that outcome, so a lost testimony can never be followed by the
## page that narrates the confession the player did not win.
func test_story_steps_can_gate_on_the_minigame_outcome() -> void:
	var won_page := {"type": "story", "when_minigame": "success", "lines": ["won"]}
	assert_true(not ProwlScript.minigame_gate_blocks(won_page, true),
		"the success page plays on a win")
	assert_true(ProwlScript.minigame_gate_blocks(won_page, false),
		"and is skipped on a loss")
	var loss_page := {"type": "story", "when_minigame": "loss", "lines": ["lost"]}
	assert_true(not ProwlScript.minigame_gate_blocks(loss_page, false),
		"the loss page plays on a loss")
	assert_true(ProwlScript.minigame_gate_blocks(loss_page, true),
		"and is skipped on a win")
	assert_true(not ProwlScript.minigame_gate_blocks(
		{"type": "story", "lines": ["any"]}, false), "ungated steps always play")


## Growth is permanent and must never be farmable: the quest that hands it
## out has to be a `once` quest, or the tannery wall is an HP printer.
func test_growth_is_only_granted_by_quests_that_cannot_repeat() -> void:
	var catalog := _catalog()
	for quest_id in catalog.quests:
		var quest: Dictionary = catalog.quests[quest_id]
		var grants := quest.has("grant_growth")
		for step in ProwlScript.steps_of(quest):
			if step.has("grant_growth"):
				grants = true
		if not grants:
			continue
		assert_true(bool(quest.get("once", false)),
			"'%s' grants permanent growth but can be replayed" % quest_id)
		assert_true(not bool(quest.get("repeatable", false)),
			"'%s' grants permanent growth and is marked repeatable" % quest_id)


## A retried quest must not replay its first-meeting beats (owner 2026-08-10:
## "npcs met in the first pass should remember you"). `when_attempt` keys a
## step to whether the quest has been tried before; ungated steps always play.
func test_attempt_gate_swaps_first_meetings_for_remembering() -> void:
	var first_page := {"type": "story", "when_attempt": "first", "lines": ["hello"]}
	var retry_page := {"type": "story", "when_attempt": "retry", "lines": ["you again"]}
	assert_true(not ProwlScript.attempt_gate_blocks(first_page, 0),
		"the first-meeting page plays on attempt one")
	assert_true(ProwlScript.attempt_gate_blocks(first_page, 1),
		"and is skipped on a retry")
	assert_true(ProwlScript.attempt_gate_blocks(retry_page, 0),
		"the remembering page waits out the first attempt")
	assert_true(not ProwlScript.attempt_gate_blocks(retry_page, 2),
		"and plays on any retry")
	assert_true(not ProwlScript.attempt_gate_blocks(
		{"type": "story", "lines": ["any"]}, 5), "ungated steps always play")


## Every first-gated beat needs a retry twin somewhere in the quest (and the
## other way round) — a quest whose whole script is when_attempt "first"
## would replay as a wordless fight-chain.
func test_attempt_gates_come_in_pairs() -> void:
	var catalog := _catalog()
	for quest_id in catalog.quests:
		var has_first := false
		var has_retry := false
		for step in ProwlScript.steps_of(catalog.quests[quest_id]):
			match String(step.get("when_attempt", "")):
				"first": has_first = true
				"retry": has_retry = true
		assert_true(has_first == has_retry,
			"'%s' gates beats on attempt in one direction only" % quest_id)
