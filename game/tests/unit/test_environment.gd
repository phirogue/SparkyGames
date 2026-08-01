extends TestCase
## Environment mechanics: cost modifiers, sunbeams, stealth/alarm.

var catalog: Catalog = DataLoader.load_catalog()

func _fight(environment: Dictionary, enemy: String = "gutter_wisp", deck: Array = []) -> CombatState:
	if deck.is_empty():
		deck = ["ferocity_2", "ferocity_2", "guile_1", "guile_1", "mysticism_1", "shadow_1"]
	# shuffle: false -> draws come from the BACK of the deck array, so tests
	# control the opening hand exactly.
	return CombatState.create(catalog, 13, {
		"player_hp": 20,
		"deck": deck,
		"skills": ["pounce", "slink", "loaf"],
		"enemy": enemy,
		"environment": environment,
		"shuffle": false,
	})

func test_cost_mod_reduces_cost() -> void:
	var state := _fight({"cost_mod": {"shadow": -1}})
	# Slink normally costs shadow 1 -> free here, payable with zero shadow cards.
	assert_eq(state.effective_cost({"shadow": 1}).size(), 0, "shadow 1 reduced to nothing")
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "slink"}), "free slink")
	assert_eq(state.player_block, 3, "slink still blocks")
	# Free never means spam: a cost-free skill locks until next turn.
	assert_rejected(state.do_command({"type": "play_skill", "skill_id": "slink"}),
		"second free slink same turn")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "slink"}),
		"free slink again next turn")

func test_cost_mod_increases_cost() -> void:
	var state := _fight({"cost_mod": {"ferocity": 1}})
	assert_eq(int(state.effective_cost({"ferocity": 2})["ferocity"]), 3, "pounce costs 3 here")

func test_sunbeam_returns_spent_card() -> void:
	# Back five cards become the opening hand; a ferocity_2 is guaranteed in it.
	var state := _fight({"sunbeam_turns": [2]},
		"chained_dog",
		["guile_1", "guile_2", "shadow_1", "guile_1", "ferocity_1", "ferocity_2", "ferocity_2"])
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "pounce"}), "spend energy first")
	var spent_before := state.spent.size()
	assert_true(spent_before > 0, "something was spent")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.turn, 2, "sunbeam turn reached")
	assert_true(state.take_events().has("sunbeam"), "sunbeam fired")
	# Dog's Bark stole one card (+1 spent), the sunbeam returned one (-1).
	assert_eq(state.spent.size(), spent_before, "net spent unchanged")

func test_alarm_and_spotted() -> void:
	# The dog has 12 hp, so two pounces (8) trip the alarm without killing it.
	var state := _fight({"stealth_threshold": 4},
		"chained_dog",
		["ferocity_2", "ferocity_2", "ferocity_2", "ferocity_2", "ferocity_2", "ferocity_2"])
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "pounce"}), "loud pounce 1")
	assert_eq(state.alarm, 2, "alarm after one pounce")
	assert_eq(state.spotted, false, "not spotted yet")
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "pounce"}), "loud pounce 2")
	assert_true(state.spotted, "alarm threshold crossed")
	assert_true(state.take_events().has("spotted"), "spotted event emitted")
	# Once spotted, hand/skill intents become straight damage.
	var hp_before := state.player_hp
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_true(state.player_hp < hp_before, "spotted enemy always damages")

func test_quiet_skills_raise_no_alarm() -> void:
	var state := _fight({"stealth_threshold": 4}, "garden_watch",
		["shadow_1", "shadow_1", "guile_1", "guile_1", "mysticism_1", "shadow_2"])
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "slink"}), "quiet slink")
	assert_eq(state.alarm, 0, "shadow raises no alarm")

func test_unspotted_stealth_win_counts() -> void:
	var tracker := AchievementTracker.new(catalog)
	var state := _fight({"stealth_threshold": 4}, "gutter_wisp",
		["shadow_1", "shadow_1", "guile_1", "guile_1", "mysticism_1", "shadow_2"])
	for i in 12:
		if state.outcome != CombatState.Outcome.ONGOING:
			break
		state.do_command({"type": "play_skill", "skill_id": "scratch"})
		if state.outcome == CombatState.Outcome.ONGOING:
			state.do_command({"type": "end_turn"})
	assert_eq(state.outcome, CombatState.Outcome.VICTORY, "scratched the wisp down")
	var newly := tracker.record_encounter(state)
	assert_true(newly.has("nothing_woke"), "unspotted stealth win unlocks Nothing Woke")

func test_environment_defaults_are_inert() -> void:
	var state := _fight({})
	assert_eq(state.stealth_threshold, 0, "no stealth by default")
	assert_eq(state.effective_cost({"ferocity": 2})["ferocity"], 2, "no cost mod by default")
