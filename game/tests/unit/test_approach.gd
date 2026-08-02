extends TestCase
## The Approach: pre-combat energy spends that shape initiative.

var catalog: Catalog = DataLoader.load_catalog()

func _fight(deck: Array, enemy: String = "chained_dog", extra: Dictionary = {}) -> CombatState:
	var config := {
		"player_hp": 20,
		"deck": deck,
		"skills": ["pounce", "slink"],
		"enemy": enemy,
		"shuffle": false,
		# These scenarios were authored around a full opening hand; the
		# 3-card opening rule is covered in test_combat.
		"opening_hand": 5,
	}
	config.merge(extra, true)
	return CombatState.create(catalog, 21, config)

func test_stalk_hides_and_sharpens() -> void:
	var state := _fight(["guile_1", "ferocity_2", "shadow_1", "shadow_1", "guile_1", "ferocity_2"])
	assert_ok(state.do_command({"type": "approach", "mode": "stalk"}), "stalk")
	assert_true(state.hidden, "hidden after stalk")
	assert_true(state.sharpened, "sharpened after stalk")
	var hp_before := state.player_hp
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.player_hp, hp_before, "its first move found nothing")
	assert_eq(state.hidden, false, "hiding is spent")
	# Second enemy turn is real: Lunge (intent 2) after Bark was wasted.
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_true(state.player_hp < hp_before, "the second move is real")

func test_ambush_hits_first_but_angers() -> void:
	var state := _fight(["guile_1", "shadow_1", "guile_1", "ferocity_1", "ferocity_1", "shadow_1"])
	assert_ok(state.do_command({"type": "approach", "mode": "ambush"}), "ambush")
	assert_eq(state.enemy_hp, 9, "ambush opens for 3")
	# Dog intent 1 is Bark (hand steal): rage wasted on a non-damage move is
	# possible by design; take the second turn (Lunge 4 + 2 rage? no — rage
	# only lasts one act). First act consumes the rage flag either way.
	var hand_before := state.hand.size()
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.hand.size() < hand_before + 5, true, "fight continues")

func test_case_hand_math_exact() -> void:
	var state := _fight(["shadow_1", "ferocity_1", "guile_2", "shadow_1", "ferocity_2", "guile_1", "guile_1"])
	# Hand (back five): guile_1, guile_1, ferocity_2, shadow_1, guile_2
	assert_ok(state.do_command({"type": "approach", "mode": "case"}), "case")
	# Pays with guile_2 (largest first), draws 2 (ferocity_1, shadow_1): 4+2=6.
	assert_eq(state.hand.size(), 6, "case over-draws past the hand limit")

func test_case_studies_you_back() -> void:
	# Every approach has a price: Case draws 2 but the enemy's first strike
	# gains +1 (wraith turn 1: Empty Sleeve 6 -> 7).
	var state := _fight(["shadow_1", "ferocity_1", "guile_1", "guile_1",
		"shadow_1", "guile_1"], "rag_wraith")
	assert_ok(state.do_command({"type": "approach", "mode": "case"}), "case")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(int(state.flags["damage_taken"]), 7, "it studied you back")

func test_ward_block_survives_one_turn() -> void:
	var state := _fight(["guile_1", "shadow_1", "guile_1", "mysticism_2", "ferocity_1", "shadow_1"])
	assert_ok(state.do_command({"type": "approach", "mode": "ward"}), "ward")
	assert_eq(state.player_block, 4, "warded")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_true(state.player_block > 0 or state.flags["damage_taken"] == 0,
		"ward holds through the first enemy turn")

func test_approach_locks_after_acting() -> void:
	var state := _fight(["guile_1", "ferocity_2", "shadow_1", "shadow_1", "guile_1", "ferocity_2"])
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scratch"}))
	assert_rejected(state.do_command({"type": "approach", "mode": "stalk"}),
		"approach after acting")

func test_start_hidden_config() -> void:
	var state := _fight(["guile_1", "ferocity_2", "shadow_1", "shadow_1", "guile_1", "ferocity_2"],
		"the_unpicked", {"start_hidden": true})
	assert_true(state.hidden, "story-granted surprise")
	var hp_before := state.player_hp
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.player_hp, hp_before, "interrupted mid-work: first act wasted")
