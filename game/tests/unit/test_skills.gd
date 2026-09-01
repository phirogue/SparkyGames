extends TestCase
## The Chapter 1 action roster, and the effect vocabulary it added.
##
## Every effect below reaches into state that already existed for something
## else — `sharpened` was a lingering, `hidden` and `_ward_holds` were
## approaches, `pierce` was an enemy intent mode. That reuse is the point, and
## it is also the risk: a skill that sets a flag the wrong way round looks
## exactly like a skill that works until the turn-over. So each one is pinned
## from the player's side (what happened to the enemy, the guard, the paws)
## rather than by reading the flag back.

var catalog: Catalog = DataLoader.load_catalog()

## A fight whose OPENING HAND is written down rather than drawn for. `hand`
## is dealt in order and `rest` stays on the spool beneath it; shuffle stays
## off, so a failure here is always about the skill and never about the seed.
## Paws are generous on purpose — these tests ask what an action DOES, and
## the paw budget has its own tests.
func _fight(skills: Array, hand: Array, enemy: String = "gutter_wisp",
		rest: Array = []) -> CombatState:
	var spool: Array = rest.duplicate()
	var dealt: Array = hand.duplicate()
	dealt.reverse()          # the deck is drawn from the BACK
	spool.append_array(dealt)
	return CombatState.create(catalog, 11, {
		"player_hp": 20,
		"deck": spool,
		"skills": skills,
		"enemy": enemy,
		"shuffle": false,
		"opening_hand": hand.size(),
		"paws": 9,
	})


# ------------------------------------------------------------------ the roster

func test_every_humour_has_the_roster_the_chapter_promises() -> void:
	# Owner brief: four Ferocity, four Guile, four Shadow, two Moonlight, and
	# Scratch outside the count because it is an instinct, not a choice.
	var by_humour := {}
	var instincts := 0
	for id in catalog.skills:
		var def: Dictionary = catalog.skills[id]
		if def.get("instinct", false):
			instincts += 1
			continue
		var cost: Dictionary = def.get("cost", {})
		assert_eq(cost.size(), 1,
			"skill '%s' is paid for in exactly one humour" % id)
		var humour := String(cost.keys()[0])
		by_humour[humour] = int(by_humour.get(humour, 0)) + 1
	assert_eq(instincts, 1, "exactly one instinct")
	assert_eq(by_humour.get("ferocity", 0), 4, "Ferocity actions")
	assert_eq(by_humour.get("guile", 0), 4, "Guile actions")
	assert_eq(by_humour.get("shadow", 0), 4, "Shadow actions")
	assert_eq(by_humour.get("mysticism", 0), 2, "Moonlight actions")

func test_every_skill_can_be_learned() -> void:
	# The defect this guards is silent everywhere else: a card that exists in
	# the loadout code, the balance sim and the art folder, and never once in
	# the game. Catalog.validate() owns the check; this pins that it is ON.
	var taught := {}
	for key in ["start.skills", "start.prologue_skills"]:
		for skill_id in catalog.rules.list(key):
			taught[String(skill_id)] = true
	for quest_id in catalog.quests:
		for skill_id in ProwlScript.skills_taught_by(catalog.quests[quest_id]):
			taught[skill_id] = true
	for id in catalog.skills:
		assert_true(taught.has(String(id)),
			"skill '%s' is granted by something" % id)

func test_no_skill_is_taught_twice() -> void:
	# Two quests handing over the same action is not fatal (_grant_skills is
	# idempotent) — it is a WRITING bug: the second beat narrates Ash learning
	# something he has been doing for three quests.
	var seen := {}
	for quest_id in catalog.quests:
		for skill_id in ProwlScript.skills_taught_by(catalog.quests[quest_id]):
			assert_true(not seen.has(skill_id),
				"skill '%s' is taught by '%s' and again by '%s'" % [
					skill_id, seen.get(skill_id, ""), quest_id])
			seen[skill_id] = quest_id

func test_every_skill_renders_rule_text() -> void:
	# A card whose effect has no template shows a BLANK rule line — legible as
	# a design choice, invisible as a defect, and shipped once already.
	for id in catalog.skills:
		var summary := SkillText.effect_summary(catalog.skills[id])
		assert_true(not summary.strip_edges().is_empty(),
			"skill '%s' says what it does" % id)
		assert_true(not summary.contains("%"),
			"skill '%s' rule text has an unfilled placeholder" % id)


# ------------------------------------------------------------------- ferocity

func test_rake_sharpens_the_next_strike_once() -> void:
	var state := _fight(["rake", "swat"], ["ferocity_2", "ferocity_1"], "chained_dog")
	var full := state.enemy_hp
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "rake"}))
	assert_eq(state.enemy_hp, full - 3, "Rake itself deals 3")
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "swat"}))
	assert_eq(state.enemy_hp, full - 3 - 3, "the strike after Rake lands 2+1")
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scratch"}))
	assert_eq(state.enemy_hp, full - 3 - 3 - 1,
		"and only the next one — Scratch is back to 1")

func test_bite_down_goes_through_a_raised_guard() -> void:
	var state := _fight(["bite_down", "pounce"], ["ferocity_3", "ferocity_2"], "candle_golem")
	# Hand it the guard directly: the golem raises one on its second intent,
	# and a test that plays four turns to reach that is a test about pacing.
	state.enemy_block = 6
	var full := state.enemy_hp
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "bite_down"}))
	assert_eq(state.enemy_hp, full - 5, "the guard turns none of it")
	assert_eq(state.enemy_block, 6, "and the guard is still standing")
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "pounce"}))
	assert_eq(state.enemy_hp, full - 5, "an ordinary strike is still turned")
	assert_eq(state.enemy_block, 2, "which is what wears the guard down")


# --------------------------------------------------------------------- shadow

func test_unknot_frees_every_jammed_action_at_once() -> void:
	var state := _fight(["unknot", "pounce", "swat"], ["shadow_1", "ferocity_2"])
	for s in state.skills:
		if s["id"] != "unknot":
			s["jammed_turns"] = 3
	assert_rejected(state.do_command({"type": "play_skill", "skill_id": "pounce"}),
		"jammed before")
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "unknot"}))
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "pounce"}),
		"Pounce comes loose")
	assert_eq(state.skill_state("swat")["jammed_turns"], 0,
		"and so does everything else, in one go")
	assert_eq(state.player_block, 1, "with a thin guard for the turn it cost")

func test_long_shadow_guard_survives_the_turn_over() -> void:
	# Three cards for three points: hand payment spends the FEWEST cards, so
	# Slink takes the 2 and Shade is left paying with the pair of 1s.
	var state := _fight(["long_shadow", "slink"],
		["shadow_1", "shadow_1", "shadow_2"])
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "slink"}))
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "long_shadow"}))
	assert_eq(state.player_block, 7, "3 from Slink, 4 from Shade")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.player_block, 7 - int(state.flags["damage_taken"]),
		"the whole guard held the turn over, not just Shade's share")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.player_block, 0, "and it holds for exactly one turn-over")

func test_vanish_wastes_its_next_move_and_keens_the_claws() -> void:
	var state := _fight(["vanish", "pounce"], ["shadow_2", "ferocity_2"], "chained_dog")
	var hp := state.player_hp
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "vanish"}))
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.player_hp, hp, "its move landed on nothing")
	var full := state.enemy_hp
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "pounce"}))
	assert_eq(state.enemy_hp, full - 5, "and the strike out of hiding lands 4+1")

func test_vanish_is_the_stalk_taken_late() -> void:
	# The claim the notice card makes, checked against the approach it names:
	# same two effects, same order, so the rule text cannot quietly become a
	# lie about a mechanic the player already knows.
	var stalked := _fight(["pounce"], ["ferocity_2"], "chained_dog",
		["shadow_1", "shadow_1"])
	assert_ok(stalked.do_command({"type": "approach", "mode": "stalk"}))
	var vanished := _fight(["vanish", "pounce"], ["shadow_2", "ferocity_2"],
		"chained_dog")
	assert_ok(vanished.do_command({"type": "play_skill", "skill_id": "vanish"}))
	assert_eq(vanished.hidden, stalked.hidden, "both are nowhere")
	assert_eq(vanished.sharpened, stalked.sharpened, "both are keen")


# ---------------------------------------------------------------------- guile

func test_scrounge_draws_off_the_spool_and_the_spool_does_not_refill() -> void:
	var state := _fight(["scrounge"], ["guile_1"], "gutter_wisp",
		["ferocity_1", "ferocity_1", "shadow_1"])
	var spool := state.deck.size()
	var hand := state.hand.size()
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scrounge"}))
	# One Guile card paid for it, two came off the spool: net +1 in hand.
	assert_eq(state.hand.size(), hand + 1, "a fuller hand")
	assert_eq(state.deck.size(), spool - 2, "a thinner spool (law 13: spent is spent)")

func test_scrounge_at_the_hand_limit_is_not_a_way_to_overfill() -> void:
	var state := _fight(["scrounge"], ["guile_1"], "gutter_wisp",
		["ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1", "shadow_1", "shadow_1"])
	while state.hand.size() < state.hand_limit and not state.deck.is_empty():
		state.hand.append(state.deck.pop_back())
	var spool := state.deck.size()
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scrounge"}))
	assert_true(state.hand.size() <= state.hand_limit, "the hand limit holds")
	assert_true(state.deck.size() <= spool, "and nothing was invented")


# ------------------------------------------------------------------ moonlight

func test_moonlight_costs_take_moonlight_and_nothing_else() -> void:
	# The reverse of the wild rule: Moonlight pays for anything, and only
	# Moonlight pays for HERS. A Ferocity-only spool cannot buy her work.
	var state := _fight(["moonwise", "her_thread"],
		["ferocity_1", "ferocity_1", "ferocity_1", "ferocity_2"])
	assert_rejected(state.do_command({"type": "play_skill", "skill_id": "moonwise"}),
		"a fistful of Ferocity does not buy Moonwise")
	assert_rejected(state.do_command({"type": "play_skill", "skill_id": "her_thread"}),
		"nor Her Hour")

func test_moonwise_reads_a_masked_intent_for_the_rest_of_the_fight() -> void:
	var state := _fight(["moonwise"], ["mysticism_1"], "the_tallowman", ["shadow_1"])
	var masked := {"name": "?", "target": "health", "amount": 3, "masked_until": 2}
	assert_true(state.intent_masked(masked), "unreadable to a stranger")
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "moonwise"}))
	assert_true(not state.intent_masked(masked), "and readable after")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_true(not state.intent_masked(masked), "for the rest of the fight")

func test_her_thread_buys_paws_back_within_the_turn() -> void:
	var state := CombatState.create(catalog, 11, {
		"player_hp": 20,
		"deck": ["mysticism_1", "mysticism_1", "ferocity_1", "ferocity_1"],
		"skills": ["her_thread", "swat"],
		"enemy": "gutter_wisp",
		"shuffle": false,
		"opening_hand": 4,
		"paws": 2,
	})
	state.player_hp = 15
	# Two Moonlight cards cost two paws to place; the thread hands three back
	# (2 granted, against the 2 spent) — so the turn continues where it would
	# otherwise have ended, which is the whole card.
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "her_thread"}))
	assert_eq(state.paws_left, 2, "two paws spent, two given back")
	assert_eq(state.player_hp, 17, "and two mended")
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "swat"}),
		"the turn is not over after all")

func test_paws_granted_do_not_survive_the_turn() -> void:
	var state := _fight(["her_thread"], ["mysticism_1", "mysticism_1"])
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "her_thread"}))
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.paws_left, state.paw_limit,
		"a turn starts on the paw limit, whatever last turn was given")


# ------------------------------------------------------------ rejection safety

func test_a_rejected_new_skill_changes_nothing() -> void:
	# The chaos harness's chief invariant, applied to every action added here:
	# an unaffordable tap must cost no charge, no paw, no card and no flag.
	for skill_id in ["rake", "bite_down", "unknot", "long_shadow", "vanish",
			"scrounge", "moonwise", "her_thread"]:
		var state := _fight([skill_id], [], "gutter_wisp", ["guile_2"])
		state.hand = []  # nothing to pay with, whatever it costs
		var before := {
			"hp": state.player_hp, "block": state.player_block,
			"paws": state.paws_left, "deck": state.deck.size(),
			"spent": state.spent.size(), "enemy": state.enemy_hp,
			"hidden": state.hidden, "sharp": state.sharpened,
			"revealed": state.intents_revealed,
			"charges": state.skill_state(skill_id)["charges_left"],
		}
		assert_rejected(state.do_command({"type": "play_skill", "skill_id": skill_id}),
			"'%s' with an empty hand" % skill_id)
		assert_eq(state.player_hp, before["hp"], "%s: hp" % skill_id)
		assert_eq(state.player_block, before["block"], "%s: guard" % skill_id)
		assert_eq(state.paws_left, before["paws"], "%s: paws" % skill_id)
		assert_eq(state.deck.size(), before["deck"], "%s: spool" % skill_id)
		assert_eq(state.spent.size(), before["spent"], "%s: spent" % skill_id)
		assert_eq(state.enemy_hp, before["enemy"], "%s: enemy" % skill_id)
		assert_eq(state.hidden, before["hidden"], "%s: hidden" % skill_id)
		assert_eq(state.sharpened, before["sharp"], "%s: sharpened" % skill_id)
		assert_eq(state.intents_revealed, before["revealed"], "%s: read" % skill_id)
		assert_eq(state.skill_state(skill_id)["charges_left"], before["charges"],
			"%s: charges" % skill_id)
