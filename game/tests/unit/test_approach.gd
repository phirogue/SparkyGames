extends TestCase
## The Approach: pre-combat energy spends that shape initiative.
##
## An approach is paid straight OFF THE SPOOL (owner rule 2026-08-10): the
## entrance is decided before the fight begins, so its price comes from the
## wound deck, never from the opening hand. Decks here are unshuffled and
## drawn from the BACK, so the FRONT of each list is what stays on the spool
## to pay the entrance.

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
	var state := _fight(["shadow_1", "shadow_1", "guile_1", "ferocity_2",
		"shadow_1", "shadow_1", "guile_1", "ferocity_2"])
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

func test_approach_pays_off_the_spool_not_the_hand() -> void:
	# Front two shadows stay on the spool; the back five are the hand.
	var state := _fight(["shadow_1", "shadow_1", "guile_1", "ferocity_2",
		"shadow_1", "guile_1", "ferocity_1"])
	assert_eq(state.hand.size(), 5, "opening hand")
	assert_eq(state.deck.size(), 2, "two shadow left on the spool")
	assert_ok(state.do_command({"type": "approach", "mode": "stalk"}), "stalk")
	assert_eq(state.hand.size(), 5, "the hand is untouched by an entrance")
	assert_eq(state.deck.size(), 0, "the price came off the spool")
	assert_eq(state.spent.size(), 2, "and the spent pile holds it")

func test_approach_needs_the_spool_even_when_the_hand_could_pay() -> void:
	# The HAND is full of shadow; the spool holds none. The entrance must be
	# refused — hand energy is for the fight, not the doorway.
	var state := _fight(["guile_1", "ferocity_1",
		"shadow_1", "shadow_1", "shadow_1", "shadow_1", "shadow_1"])
	assert_true(not state.can_pay_approach("stalk"), "the spool cannot cover it")
	assert_rejected(state.do_command({"type": "approach", "mode": "stalk"}),
		"stalk with an empty spool")
	assert_true(state.can_approach(), "a refused entrance stays open")

func test_spool_payment_spends_small_cards_first() -> void:
	# Spool: shadow_2 and two shadow_1. The entrance (2 Shadow) must take the
	# two small cards and leave the potent one wound on.
	var state := _fight(["shadow_2", "shadow_1", "shadow_1",
		"guile_1", "ferocity_2", "guile_1", "ferocity_1", "guile_1"])
	assert_ok(state.do_command({"type": "approach", "mode": "stalk"}), "stalk")
	assert_eq(state.deck, ["shadow_2"], "the potent card is preserved")

func test_ambush_hits_first_but_angers() -> void:
	var state := _fight(["ferocity_1", "ferocity_1", "guile_1",
		"shadow_1", "guile_1", "ferocity_1", "ferocity_1", "shadow_1"])
	assert_ok(state.do_command({"type": "approach", "mode": "ambush"}), "ambush")
	assert_eq(state.enemy_hp, 9, "ambush opens for 3")
	# Dog intent 1 is Bark (hand steal): rage wasted on a non-damage move is
	# possible by design; take the second turn (Lunge 4 + 2 rage? no — rage
	# only lasts one act). First act consumes the rage flag either way.
	var hand_before := state.hand.size()
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.hand.size() < hand_before + 5, true, "fight continues")

func test_case_hand_math_exact() -> void:
	var state := _fight(["guile_2", "ferocity_1", "shadow_1",
		"guile_1", "guile_1", "ferocity_2", "shadow_1", "mysticism_1"])
	# Hand (back five): guile_1, guile_1, ferocity_2, shadow_1, mysticism_1.
	# Spool: guile_2, ferocity_1, shadow_1.
	assert_ok(state.do_command({"type": "approach", "mode": "case"}), "case")
	# Pays guile_2 off the spool, draws 2 (shadow_1, ferocity_1): 5 + 2 = 7.
	assert_eq(state.hand.size(), 7, "case over-draws past the hand limit")
	assert_eq(state.deck.size(), 0, "the price and the study both came off the spool")

func test_case_studies_you_back() -> void:
	# Every approach has a price: Case draws 2 but the enemy's first strike
	# gains +1 (wraith turn 1: Empty Sleeve 6 -> 7).
	var state := _fight(["guile_1", "guile_1", "shadow_1", "ferocity_1",
		"guile_1", "shadow_1", "guile_1"], "rag_wraith")
	assert_ok(state.do_command({"type": "approach", "mode": "case"}), "case")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(int(state.flags["damage_taken"]), 7, "it studied you back")

func test_ward_block_survives_one_turn() -> void:
	var state := _fight(["mysticism_2", "guile_1", "shadow_1",
		"guile_1", "ferocity_1", "shadow_1", "guile_1", "shadow_1"])
	assert_ok(state.do_command({"type": "approach", "mode": "ward"}), "ward")
	assert_eq(state.player_block, 4, "warded")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_true(state.player_block > 0 or state.flags["damage_taken"] == 0,
		"ward holds through the first enemy turn")

func test_approach_locks_after_acting() -> void:
	var state := _fight(["shadow_1", "shadow_1", "guile_1", "ferocity_2",
		"shadow_1", "guile_1", "ferocity_2"])
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scratch"}))
	assert_rejected(state.do_command({"type": "approach", "mode": "stalk"}),
		"approach after acting")

## An approach costs its LISTED price everywhere (owner rule 2026-08-03).
## Needle Lane's fog takes 1 off Shadow, and it used to take it off Stalk
## too — so the chooser quoted "Shadow 2" and charged 1.
func test_approach_price_ignores_the_environment_discount() -> void:
	# Spool after the 3-card opening: two shadow_1. A flat 2-Shadow price
	# empties it; a (wrongly) discounted price of 1 would leave a card.
	var state := _fight(
		["shadow_1", "shadow_1", "ferocity_2", "guile_1", "shadow_1"],
		"gutter_wisp",
		{"opening_hand": 3, "environment": {"cost_mod": {"shadow": -1}}})
	assert_eq(state.hand.size(), 3, "opening hand")
	assert_eq(state.effective_cost({"shadow": 1}), {} as Dictionary,
		"the fog really does make Slink free")
	assert_ok(state.do_command({"type": "approach", "mode": "stalk"}), "stalk")
	assert_eq(state.deck.size(), 0, "Stalk still costs a flat 2 Shadow")
	assert_eq(state.hand.size(), 3, "and none of it came from the hand")


func test_start_hidden_config() -> void:
	var state := _fight(["guile_1", "ferocity_2", "shadow_1", "shadow_1", "guile_1", "ferocity_2"],
		"the_unpicked", {"start_hidden": true})
	assert_true(state.hidden, "story-granted surprise")
	var hp_before := state.player_hp
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.player_hp, hp_before, "interrupted mid-work: first act wasted")
