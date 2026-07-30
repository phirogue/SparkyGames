extends TestCase
## AchievementTracker: unlock thresholds, no double-unlocks, encounter digestion,
## and save/load round-trips.

var catalog: Catalog = DataLoader.load_catalog()

func _tracker() -> AchievementTracker:
	return AchievementTracker.new(catalog)

func _quick_win(seed_value: int = 7) -> CombatState:
	# shuffle:false -> opening hand is the last five cards: two ferocity_2s,
	# a ferocity_1, guile_1, shadow_1. Pounce (4) + Scratch (1) + Swat (2)
	# kills the 6 hp wisp in one turn: flawless, no enemy action.
	var state := CombatState.create(catalog, seed_value, {
		"player_hp": 12,
		"deck": ["moonlight_1", "guile_2", "shadow_2", "shadow_1", "guile_1",
				"ferocity_1", "ferocity_2", "ferocity_2"],
		"skills": ["pounce", "swat", "slink", "purr", "loaf"],
		"enemy": "gutter_wisp",
		"shuffle": false,
	})
	state.do_command({"type": "play_skill", "skill_id": "pounce"})
	state.do_command({"type": "play_skill", "skill_id": "scratch"})
	state.do_command({"type": "play_skill", "skill_id": "swat"})
	return state

func test_unlocks_at_threshold_once() -> void:
	var tracker := _tracker()
	var newly := tracker.increment("encounters_won")
	assert_true(newly.has("the_vole_dispute"), "first win unlocks The Vole Dispute")
	assert_eq(tracker.increment("encounters_won").size(), 0, "no re-unlock on second win")
	assert_true(tracker.is_unlocked("the_vole_dispute"), "stays unlocked")

func test_higher_threshold_waits() -> void:
	var tracker := _tracker()
	for i in 8:
		assert_eq(tracker.increment("lives_spent").has("regular_customer"), false,
			"regular_customer must not unlock at %d deaths" % (i + 1))
	assert_true(tracker.increment("lives_spent").has("regular_customer"),
		"regular_customer unlocks at 9 deaths")

func test_record_victory_encounter() -> void:
	var tracker := _tracker()
	var state := _quick_win()
	assert_eq(state.outcome, CombatState.Outcome.VICTORY, "fixture should win")
	var newly := tracker.record_encounter(state)
	assert_true(newly.has("the_vole_dispute"), "win achievement from encounter digest")
	assert_eq(int(tracker.stats.get("defeated_gutter_wisp", 0)), 1, "per-enemy stat")
	assert_true(int(tracker.stats.get("energy_spent", 0)) > 0, "energy stat fed from flags")

func test_flawless_win_detected() -> void:
	var tracker := _tracker()
	var state := _quick_win()  # won before the enemy ever acted
	tracker.record_encounter(state)
	assert_true(tracker.is_unlocked("not_a_whisker"), "no-damage win is flawless")

func test_retreat_and_death_stats() -> void:
	var tracker := _tracker()
	var state := CombatState.create(catalog, 3, {
		"player_hp": 12,
		"deck": ["guile_1", "guile_1"], "skills": [], "enemy": "gutter_wisp",
	})
	state.do_command({"type": "slip_away"})
	var newly := tracker.record_encounter(state)
	assert_true(newly.has("the_meeting_was_declined"), "first retreat unlocks")
	var doomed := CombatState.create(catalog, 5, {
		"player_hp": 3,
		"deck": ["guile_1", "guile_1"], "skills": [], "enemy": "the_unpicked",
	})
	for i in 10:
		if doomed.outcome != CombatState.Outcome.ONGOING:
			break
		doomed.do_command({"type": "end_turn"})
	newly = tracker.record_encounter(doomed)
	assert_true(newly.has("first_visit_complimentary"), "first death unlocks")
	assert_true(newly.has("nine_minus_one"), "falling to the Unpicked unlocks")

func test_save_round_trip() -> void:
	var tracker := _tracker()
	tracker.increment("encounters_won")
	tracker.increment("retreats")
	var saved := tracker.to_dict()
	var restored := _tracker()
	restored.from_dict(saved)
	assert_eq(restored.unlocked, tracker.unlocked, "unlocked list survives save")
	assert_eq(int(restored.stats["encounters_won"]), 1, "stats survive save")
	assert_eq(restored.increment("encounters_won").size(), 0,
		"restored tracker does not re-unlock")

func test_every_achievement_stat_is_reachable_naming() -> void:
	# Guard against typos: every achievement stat must be either a known
	# lifetime stat or a per-enemy pattern over enemies that exist.
	var known := ["encounters_won", "lives_spent", "retreats", "flawless_wins",
		"exhausted_wins", "full_bank_wins", "shelf_justice_kills",
		"scratch_only_wins", "purrs_completed", "hand_cards_lost", "energy_spent",
		"unspotted_wins", "pressed_on", "quests_completed", "gleam_banked"]
	for id in catalog.achievements:
		var stat: String = catalog.achievements[id]["stat"]
		var ok: bool = known.has(stat)
		for prefix in ["defeated_", "felled_by_"]:
			if stat.begins_with(prefix) and catalog.enemies.has(stat.trim_prefix(prefix)):
				ok = true
		assert_true(ok, "achievement '%s' watches unreachable stat '%s'" % [id, stat])
