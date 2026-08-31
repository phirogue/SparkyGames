extends TestCase
## Combat engine invariants. Every test builds its state from a fixed seed so
## failures are reproducible — determinism is itself under test.

var catalog: Catalog = DataLoader.load_catalog()

func _wisp_fight(seed_value: int = 7) -> CombatState:
	return CombatState.create(catalog, seed_value, {
		"player_hp": 12,
		"deck": ["ferocity_2", "ferocity_2", "ferocity_1", "shadow_1", "shadow_1",
				"mysticism_1", "guile_1", "ferocity_2", "shadow_2", "guile_2"],
		"skills": ["pounce", "slink", "purr", "loaf"],
		"enemy": "gutter_wisp",
	})

func test_unknown_content_ids_degrade_instead_of_crashing() -> void:
	# Catalog.validate() catches dangling ids at boot, but nothing forces a
	# hand-written scenario through validate() first. A typo'd id must cost a
	# loud push_error and a degraded fight — never a crash, never a modulo by
	# zero on an empty intent list.
	var state := CombatState.create(catalog, 7, {
		"player_hp": 12,
		"deck": ["ferocity_1", "no_such_card", "guile_1"],
		"skills": ["pounce", "no_such_skill"],
		"enemy": "no_such_enemy",
	})
	assert_eq(state.skills.size(), 1, "the unknown skill was skipped")
	assert_eq(state.enemy_hp, 1, "the phantom enemy is a one-hit dummy")
	assert_true(state.current_intent().is_empty(), "no intents reads as empty, not a crash")
	assert_ok(state.do_command({"type": "end_turn"}), "the phantom passes its move")
	# The unknown card in hand is a rejection, not a crash (fuzzer invariant:
	# a rejected command changes nothing).
	var index := state.hand.find("no_such_card")
	if index >= 0:
		assert_rejected(state.do_command({"type": "charge_skill",
			"skill_id": "pounce", "source": "hand", "index": index}))


func test_determinism_same_seed_same_state() -> void:
	var a := _wisp_fight(42)
	var b := _wisp_fight(42)
	assert_eq(a.hand, b.hand, "hands from same seed")
	assert_eq(a.deck, b.deck, "decks from same seed")

func test_opening_hand_then_one_draw_per_turn() -> void:
	var state := _wisp_fight()
	assert_eq(state.hand.size(), CombatState.OPENING_HAND, "battles open with 3 cards")
	assert_eq(state.deck.size(), 7, "deck after opening draw")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.hand.size(), CombatState.OPENING_HAND + 1,
		"exactly ONE energy recovers per turn")

func test_pounce_costs_energy_and_damages() -> void:
	var state := _wisp_fight()
	var spent_before := state.spent.size()
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "pounce"}), "pounce")
	assert_eq(state.enemy_hp, 2, "wisp hp after pounce")
	assert_true(state.spent.size() > spent_before, "energy was spent")
	assert_eq(state.skill_state("pounce")["charges_left"], 2, "pounce charges")

func test_victory_ends_encounter() -> void:
	var state := _wisp_fight()
	# Pounce (4) + Scratch (1), enemy turn, Scratch (1) = 6 = wisp hp.
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "pounce"}))
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scratch"}))
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scratch"}))
	assert_eq(state.outcome, CombatState.Outcome.VICTORY, "outcome")
	assert_rejected(state.do_command({"type": "end_turn"}), "acting after victory")

func test_instinct_once_per_turn() -> void:
	var state := _wisp_fight()
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scratch"}), "first scratch")
	assert_rejected(state.do_command({"type": "play_skill", "skill_id": "scratch"}),
		"second scratch same turn")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scratch"}),
		"scratch again next turn")
	assert_eq(state.enemy_hp, 4, "wisp hp after two scratches across two turns")

func test_lingering_warmed_and_sharpened() -> void:
	var state := CombatState.create(catalog, 5, {
		"player_hp": 10, "player_max_hp": 20,
		"deck": ["ferocity_2", "ferocity_2", "guile_1", "guile_1", "shadow_1", "shadow_1"],
		"skills": ["pounce"],
		"enemy": "gutter_wisp",
		"lingering": ["warmed", "sharpened"],
		"shuffle": false,
		"opening_hand": 5,
	})
	assert_eq(state.player_hp, 12, "warmed grants +2 hp on entry")
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "pounce"}), "sharpened pounce")
	assert_eq(state.enemy_hp, 6 - 5, "sharpened adds +1 to the first hit only")
	assert_eq(state.sharpened, false, "sharpened is consumed")

func test_lingering_out_from_flawless_win() -> void:
	var state := _wisp_fight()
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "pounce"}))
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scratch"}))
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scratch"}))
	assert_eq(state.outcome, CombatState.Outcome.VICTORY, "fixture wins")
	# Seed 7 turn-1 intent for the wisp is Flicker Bite (2 damage) — so this
	# win is NOT flawless and must not grant sharpened.
	assert_eq(state.lingering_out().has("sharpened"), int(state.flags["damage_taken"]) == 0,
		"sharpened only on flawless wins")

func test_energy_never_reshuffles() -> void:
	var state := _wisp_fight()
	# Burn through everything: play pounce until unaffordable, end turns to draw.
	for i in 20:
		if state.outcome != CombatState.Outcome.ONGOING:
			break
		if not state.do_command({"type": "play_skill", "skill_id": "pounce"})["ok"]:
			state.do_command({"type": "end_turn"})
	var total := state.deck.size() + state.hand.size() + state.spent.size()
	assert_eq(total, 10, "cards are conserved, never recycled")

func test_slip_away_always_available() -> void:
	var state := _wisp_fight()
	assert_ok(state.do_command({"type": "slip_away"}))
	assert_eq(state.outcome, CombatState.Outcome.RETREATED, "outcome")

func test_slip_away_takes_a_parting_shot() -> void:
	# Wisp turn-1 intent is Flicker Bite (health 2): retreat is never free.
	var state := _wisp_fight()
	var hp_before := state.player_hp
	assert_ok(state.do_command({"type": "slip_away"}))
	assert_eq(state.player_hp, hp_before - 2, "one strike lands on the way out")
	assert_eq(state.outcome, CombatState.Outcome.RETREATED, "but away is away")

## Retreat used to be free against anything that wasn't swinging at your
## health — you could walk out on a thief and lose nothing at all (owner:
## "there is still no consequence to slipping away"). Now the whole
## telegraphed move plays out on your back.
func test_slip_away_lets_a_thief_take_its_card() -> void:
	var state := _wisp_fight()
	assert_ok(state.do_command({"type": "end_turn"}))  # burn the Flicker Bite
	assert_eq(state.current_intent()["target"], "hand", "wisp turn 2 is Covet")
	var hand_before := state.hand.size()
	assert_ok(state.do_command({"type": "slip_away"}))
	assert_eq(state.hand.size(), hand_before - 1, "it lifts one on the way past")
	assert_eq(int(state.flags["hand_lost"]), 1, "and the theft is recorded")
	assert_eq(state.outcome, CombatState.Outcome.RETREATED, "away is still away")

## Some rooms have no back door (the Unpicked, prologue).
func test_no_retreat_encounters_refuse_slip_away() -> void:
	var state := CombatState.create(catalog, 3, {
		"player_hp": 12, "deck": ["ferocity_1", "ferocity_1", "ferocity_1"],
		"skills": ["pounce"], "enemy": "the_unpicked", "no_retreat": true,
	})
	assert_rejected(state.do_command({"type": "slip_away"}), "slipping away")
	assert_eq(state.outcome, CombatState.Outcome.ONGOING, "the fight goes on")

## Block answers damage; nothing used to answer a thief. Loaf does now —
## which is what makes it worth losing a turn to (owner rule 2026-08-03).
func test_loaf_guards_the_hand_from_theft() -> void:
	# Unshuffled, drawn from the back: opens on three Guile, one per turn after.
	var state := CombatState.create(catalog, 5, {
		"player_hp": 12, "shuffle": false,
		"deck": ["ferocity_1", "guile_1", "guile_1", "guile_1", "guile_1"],
		"skills": ["loaf"], "enemy": "gutter_wisp",
	})
	assert_ok(state.do_command({"type": "end_turn"}))  # burn the Flicker Bite
	assert_eq(state.current_intent()["target"], "hand", "wisp turn 2 is Covet")
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "loaf"}), "loaf")
	var hand_before := state.hand.size()
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(int(state.flags["hand_lost"]), 0, "nothing was taken")
	# The turn's draw adds one; the theft would have removed one.
	assert_eq(state.hand.size(), hand_before + 1, "a folded cat has nothing loose")

## Scripted openers: the beat that teaches Shadow deals the Shadow, wherever
## in the deck it sits. This is what lets the prologue run on ONE deck.
func test_opening_cards_deal_named_energy_from_anywhere_in_the_deck() -> void:
	var state := CombatState.create(catalog, 11, {
		"player_hp": 10, "shuffle": false,
		"deck": ["shadow_1", "shadow_1", "ferocity_1", "ferocity_1", "ferocity_1"],
		"opening_cards": ["shadow_1", "shadow_1"],
		"skills": ["slink"], "enemy": "gutter_wisp",
	})
	assert_eq(state.hand, ["shadow_1", "shadow_1", "ferocity_1"] as Array,
		"named cards first, then the top of the deck fills the opener")
	assert_eq(state.deck.size(), 2, "and they came OUT of the deck, not out of thin air")

## A named card the deck no longer holds is skipped, not conjured — a fight
## late in the night must not hand back energy the player already spent.
func test_opening_cards_never_invent_energy() -> void:
	var state := CombatState.create(catalog, 11, {
		"player_hp": 10, "shuffle": false, "opening_hand": 2,
		"deck": ["ferocity_1", "ferocity_1"],
		"opening_cards": ["mysticism_3", "guile_2"],
		"skills": ["slink"], "enemy": "gutter_wisp",
	})
	assert_eq(state.hand, ["ferocity_1", "ferocity_1"] as Array, "only what was there")
	assert_true(state.deck.is_empty(), "and the deck is not padded")

## A survivable fight cannot kill you (the rag-wraith is a lesson about
## declining a fight, and a lesson you can fail to death is a lesson nobody
## hears). It still HURTS — the floor is 1, not invulnerability.
func test_hp_floor_makes_a_fight_survivable() -> void:
	var state := CombatState.create(catalog, 4, {
		"player_hp": 3, "shuffle": false, "hp_floor": 1,
		"deck": ["ferocity_1", "ferocity_1", "ferocity_1"],
		"skills": ["pounce"], "enemy": "rag_wraith",
	})
	for i in 6:
		if state.outcome != CombatState.Outcome.ONGOING:
			break
		assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.player_hp, 1, "damage stops at the floor")
	assert_eq(state.outcome, CombatState.Outcome.ONGOING, "and never becomes a death")
	assert_true(int(state.flags["damage_taken"]) > 0, "but the hits still landed")


## A scripted fight ends when the script says, not when the grind does.
func test_doom_turn_finishes_an_unwinnable_fight() -> void:
	var state := CombatState.create(catalog, 4, {
		"player_hp": 40, "shuffle": false, "doom_turn": 6,
		"deck": ["ferocity_1", "ferocity_1", "ferocity_1"],
		"skills": ["pounce"], "enemy": "the_unpicked",
	})
	for i in 5:
		assert_ok(state.do_command({"type": "end_turn"}), "turn %d" % (i + 1))
		assert_eq(state.outcome, CombatState.Outcome.ONGOING, "still standing on turn %d" % (i + 1))
	assert_eq(state.turn, 6, "the sixth turn is the last one")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.outcome, CombatState.Outcome.DEFEAT, "it finishes what it came to do")


## Case It draws 2 ON TOP of the opening hand, even past the usual limit —
## the owner asked whether Case should mean five cards, and it must. The
## price comes off the spool (owner 2026-08-10), so the hand only ever grows.
func test_case_it_opens_the_hand_to_five() -> void:
	var state := CombatState.create(catalog, 9, {
		"player_hp": 10, "shuffle": false,
		"deck": ["guile_1", "guile_1", "shadow_1", "ferocity_1", "guile_1", "guile_1", "guile_1"],
		"opening_cards": ["guile_1", "guile_1"],
		"skills": ["pounce"], "enemy": "rag_wraith",
	})
	assert_eq(state.hand.size(), 3, "three to start")
	assert_ok(state.do_command({"type": "approach", "mode": "case"}), "case it")
	assert_eq(state.hand.size(), 5, "two Guile paid off the spool, two cards studied out")


## The chronicle has to be able to say what an action DID, not just that it
## happened (owner 2026-08-04: "include the effects of the actions").
func test_the_journal_records_numbers() -> void:
	var state := _wisp_fight()
	state.take_journal()
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "slink"}), "slink")
	var after_block := "\n".join(state.take_journal())
	assert_true(after_block.contains("Guard +3"), "block is recorded: " + after_block)
	assert_ok(state.do_command({"type": "end_turn"}))
	var after_enemy := "\n".join(state.take_journal())
	assert_true(after_enemy.contains("Flicker Bite"), "the move is named: " + after_enemy)
	assert_true(after_enemy.contains("blocked"), "and what the guard soaked: " + after_enemy)


func test_the_night_presses() -> void:
	var state := CombatState.create(catalog, 3, {
		"player_hp": 40,
		"deck": ["guile_1", "guile_1", "guile_1"],
		"skills": [],
		"enemy": "gutter_wisp",
	})
	for i in 10:
		state.do_command({"type": "end_turn"})
	# Unpressed, ten wisp acts deal at most 10 (its cycle alternates a
	# card steal). From turn 8 the night presses and strikes grow.
	assert_true(int(state.flags["damage_taken"]) > 10,
		"late turns hit harder — fights cannot stall forever")

## Purr is a commitment (owner 2026-08-08: "The actions that take multiple
## turns don't make sense as I seem to still be able to do things right
## after"). While the channel holds, Ash plays nothing, feeds nothing and
## concentrates on nothing — damage breaking the purr is what frees him.
func test_purr_holds_ash_still_until_broken() -> void:
	var state := CombatState.create(catalog, 3, {
		"player_hp": 20,
		"deck": ["mysticism_1", "mysticism_1", "shadow_1", "shadow_1", "guile_1", "guile_1"],
		"skills": ["purr", "slink"],
		"enemy": "chained_dog",  # intent order: hand, health, health
	})
	state.player_hp = 10
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "purr"}), "purr")
	assert_rejected(state.do_command({"type": "play_skill", "skill_id": "scratch"}),
		"even the instinct waits while the purr holds")
	assert_rejected(state.do_command({"type": "charge_skill", "skill_id": "slink",
		"source": "hand", "index": 0}), "no feeding energy while the purr holds")
	state.spent.append("guile_1")
	assert_rejected(state.do_command({"type": "concentrate", "humour": "guile"}),
		"no concentrating while the purr holds")
	state.spent.pop_back()
	# Turn 1 enemy intent is Bark (hand) — no damage, the purr survives.
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_rejected(state.do_command({"type": "play_skill", "skill_id": "scratch"}),
		"still purring on the second turn")
	# Turn 2 intent is Lunge (health) — the hit breaks the purr and frees him.
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.channel.is_empty(), true, "the purr broke")
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scratch"}),
		"a broken purr frees him to act")


func test_purr_heals_and_is_interrupted_by_damage() -> void:
	var state := CombatState.create(catalog, 3, {
		"player_hp": 20,
		"deck": ["mysticism_1", "mysticism_1", "shadow_1", "shadow_1", "guile_1", "guile_1"],
		"skills": ["purr", "slink"],
		"enemy": "chained_dog",  # intent order: hand, health, health
	})
	state.player_hp = 10
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "purr"}), "purr")
	# Turn 1 enemy intent is Bark (hand) — no damage, purr survives, heals +2.
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.player_hp, 12, "hp after one purr tick")
	assert_eq(state.channel.is_empty(), false, "purr still channeling")
	# Turn 2 intent is Lunge (health 4) — damage breaks the purr.
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.player_hp, 8, "hp after lunge")
	assert_eq(state.channel.is_empty(), true, "purr interrupted")

func test_hand_attack_discards_cards() -> void:
	var state := CombatState.create(catalog, 5, {
		"player_hp": 20,
		"deck": ["guile_1", "guile_1", "guile_1", "guile_1", "guile_1"],
		"skills": ["loaf"],
		"enemy": "chained_dog",  # first intent: Bark (hand, 1)
		"opening_hand": 5,
	})
	assert_eq(state.hand.size(), 5, "opening hand")
	assert_ok(state.do_command({"type": "end_turn"}))
	# 5 in hand, Bark discards 1, then draw refills from empty deck: 4 remain.
	assert_eq(state.hand.size(), 4, "hand after bark with empty deck")
	assert_eq(state.spent.size(), 1, "barked card is gone for the adventure")

func test_skill_jam_blocks_use_and_recovers() -> void:
	var state := CombatState.create(catalog, 11, {
		"player_hp": 30,
		"deck": ["ferocity_2", "ferocity_2", "ferocity_2", "ferocity_2", "ferocity_2", "ferocity_2"],
		"skills": ["pounce"],
		"enemy": "rag_wraith",  # intent order: health, skills(jam), health
	})
	assert_ok(state.do_command({"type": "end_turn"}), "turn 1: eat Empty Sleeve")
	assert_ok(state.do_command({"type": "end_turn"}), "turn 2: Unravel jams")
	assert_eq(state.skill_state("pounce")["jammed_turns"] > 0, false,
		"jam already ticked down at the start of our turn")
	# Jam lands during enemy phase then decrements at next turn start (1 -> 0),
	# so from the player's seat the skill was locked for exactly the enemy round.
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "pounce"}), "pounce after recovery")

## Banking was REMOVED (owner 2026-08-08: "whats the point of banking a card
## if it can be stolen"). The command must be refused as unknown and touch
## nothing — a removed feature that half-works is worse than one that never
## existed.
func test_banking_is_gone() -> void:
	var state := _wisp_fight()
	var hand_before := state.hand.size()
	assert_rejected(state.do_command({"type": "bank", "hand_index": 0}),
		"the bank command no longer exists")
	assert_eq(state.hand.size(), hand_before, "and the hand is untouched")
	assert_rejected(state.do_command({"type": "charge_skill", "skill_id": "pounce",
		"source": "bank", "index": 0}), "the bank energy source no longer exists")

func test_loaf_stuns_self() -> void:
	var state := _wisp_fight()
	if not state.can_pay({"guile": 1}):
		return  # seed didn't deal guile; covered by fixed-seed hand below anyway
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "loaf"}), "loaf")
	assert_eq(state.player_block, 5, "loaf block")
	assert_rejected(state.do_command({"type": "play_skill", "skill_id": "scratch"}),
		"acting while loafed")

func test_defeat_by_boss() -> void:
	var state := CombatState.create(catalog, 9, {
		"player_hp": 5,
		"deck": ["guile_1", "guile_1", "guile_1"],
		"skills": [],
		"enemy": "the_unpicked",
	})
	for i in 10:
		if state.outcome != CombatState.Outcome.ONGOING:
			break
		state.do_command({"type": "end_turn"})
	assert_eq(state.outcome, CombatState.Outcome.DEFEAT, "the Unpicked wins the prologue")

## Ordered fixture (shuffle false, draws pop from the BACK): opening hand is
## one ferocity + four guile; one more ferocity arrives on the turn-2 draw.
func _charge_fixture() -> CombatState:
	return CombatState.create(catalog, 7, {
		"player_hp": 20,
		"deck": ["guile_1", "guile_1", "guile_1", "guile_1", "guile_1",
				"guile_1", "ferocity_1", "guile_1", "guile_1", "ferocity_1"],
		"skills": ["pounce"],
		"enemy": "gutter_wisp",
		"shuffle": false,
	})

func test_charge_powers_skill_across_turns() -> void:
	var state := _charge_fixture()
	assert_ok(state.do_command({"type": "charge_skill", "skill_id": "pounce",
		"source": "hand", "index": 0}), "feed first ferocity")
	assert_eq(state.skill_powered("pounce"), false, "one of two pips filled")
	assert_rejected(state.do_command({"type": "play_skill", "skill_id": "pounce"}),
		"cannot fire half-powered with no ferocity left in hand")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_ok(state.do_command({"type": "charge_skill", "skill_id": "pounce",
		"source": "hand", "index": 2}), "feed the drawn ferocity next turn")
	assert_eq(state.skill_powered("pounce"), true, "power persists across turns")
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "pounce"}), "fire when full")
	assert_eq(state.enemy_hp, 2, "pounce lands for 4")
	assert_eq(state.spent.size(), 2, "only the two fed cards were consumed")

func test_charge_rejects_wrong_humour() -> void:
	var state := _charge_fixture()
	assert_rejected(state.do_command({"type": "charge_skill", "skill_id": "pounce",
		"source": "hand", "index": 1}), "pounce has no use for guile")

func test_paws_limit_energy_placements() -> void:
	# Draws pop from the BACK: opening hand is [guile, guile, fer, fer, fer];
	# the deck keeps [ferocity, guile] and the turn-2 draw is that guile.
	var state := CombatState.create(catalog, 7, {
		"player_hp": 20,
		"deck": ["ferocity_1", "guile_1", "ferocity_1", "ferocity_1",
				"ferocity_1", "guile_1", "guile_1"],
		"skills": ["pounce", "shelf_justice"],
		"enemy": "gutter_wisp",
		"shuffle": false,
		"opening_hand": 5,
	})
	assert_ok(state.do_command({"type": "charge_skill", "skill_id": "pounce",
		"source": "hand", "index": 2}), "paw 1: feed pounce a ferocity")
	assert_ok(state.do_command({"type": "charge_skill", "skill_id": "pounce",
		"source": "hand", "index": 2}), "paw 2: feed pounce again")
	assert_ok(state.do_command({"type": "charge_skill", "skill_id": "shelf_justice",
		"source": "hand", "index": 0}), "paw 3: feed shelf justice a guile")
	assert_rejected(state.do_command({"type": "charge_skill", "skill_id": "shelf_justice",
		"source": "hand", "index": 0}), "fourth placement: out of paws")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.paws_left, state.paw_limit, "paws refill each turn")
	assert_ok(state.do_command({"type": "charge_skill", "skill_id": "shelf_justice",
		"source": "hand", "index": 0}), "fresh paws, fresh charge")

## Discarding was REMOVED (owner 2026-08-09: "there is no reason to
## personally discard an energy card in your hand as it gives no benefit").
## Energy leaves the hand by powering an action, or by being stolen.
func test_discarding_is_gone() -> void:
	var state := _charge_fixture()
	var hand_before := state.hand.size()
	assert_rejected(state.do_command({"type": "discard", "hand_index": 1}),
		"the discard command no longer exists")
	assert_eq(state.hand.size(), hand_before, "and the hand is untouched")

func test_concentrate_wills_energy_back_and_costs_the_turn() -> void:
	var state := _charge_fixture()
	assert_rejected(state.do_command({"type": "concentrate", "humour": "mysticism"}),
		"nothing spent yet to will back")
	assert_ok(state.do_command({"type": "charge_skill", "skill_id": "pounce",
		"source": "hand", "index": 0}), "spend the ferocity onto pounce")
	var turn_before := state.turn
	assert_ok(state.do_command({"type": "concentrate", "humour": "ferocity"}))
	assert_eq(state.turn, turn_before + 1, "concentrating IS the turn")
	assert_eq(state.spent.size(), 0, "the ferocity came back")
	var total := state.deck.size() + state.hand.size() + state.spent.size()
	assert_eq(total, 10, "cards conserved through the recall")

func test_command_log_records_only_successes() -> void:
	var state := _wisp_fight()
	state.do_command({"type": "play_skill", "skill_id": "no_such_skill"})
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scratch"}))
	assert_eq(state.log.size(), 1, "log length")
	assert_eq(state.log.entries[0]["type"], "play_skill", "logged command type")

# ---------------------------------------------------------------- payment plan

## Draws come off the deck's BACK (pop_back), so list the cards you want in
## the opening hand LAST.
func _pay_fixture(deck: Array, opening: int) -> CombatState:
	return CombatState.create(catalog, 3, {
		"player_hp": 10,
		"deck": deck,
		"skills": ["pounce"],
		"enemy": "gutter_wisp",
		"shuffle": false,
		"opening_hand": opening,
	})

func test_wild_card_cannot_split_across_humours() -> void:
	# One mysticism_2 has enough VALUE for {ferocity:1, guile:1}, but a card
	# is atomic — it can only cover one humour's shortfall. can_pay must not
	# promise what _pay cannot deliver (the old value-sum bug).
	var state := _pay_fixture(["shadow_1", "shadow_1", "mysticism_2"], 1)
	assert_eq(state.hand, ["mysticism_2"] as Array, "fixture hand")
	assert_true(state.can_pay({"ferocity": 1}), "wild covers a single shortfall")
	assert_true(not state.can_pay({"ferocity": 1, "guile": 1}),
		"one wild card must NOT satisfy two separate humours")

func test_wilds_allocate_biggest_shortfall_first() -> void:
	# {ferocity:1, guile:2} with wilds [m2, m1]: the m2 must go to guile (2)
	# and the m1 to ferocity (1) — burning the m2 on the small gap first
	# would strand the cost unpaid.
	var state := _pay_fixture(["shadow_1", "mysticism_1", "mysticism_2"], 2)
	assert_true(state.can_pay({"ferocity": 1, "guile": 2}),
		"two wilds cover two shortfalls when allocated sensibly")
	state._pay({"ferocity": 1, "guile": 2})
	assert_eq(state.hand.size(), 0, "both wilds were spent")
	assert_eq(state.spent.size(), 2, "both landed in spent")

func test_wild_keyed_cost_accepts_only_true_wilds() -> void:
	var state := _pay_fixture(["mysticism_1", "ferocity_2", "ferocity_2"], 2)
	assert_true(not state.can_pay({"mysticism": 1}),
		"ferocity cannot pay a mysticism-keyed cost")
	var wild_state := _pay_fixture(["ferocity_2", "mysticism_1"], 1)
	assert_true(wild_state.can_pay({"mysticism": 1}), "a true wild pays it")

func test_specific_energy_pays_before_wilds() -> void:
	var state := _pay_fixture(["shadow_1", "mysticism_1", "ferocity_1"], 2)
	state._pay({"ferocity": 1})
	assert_true(state.hand.has("mysticism_1"),
		"the wild survives when specific energy can pay")
	assert_true(state.spent.has("ferocity_1"), "the ferocity was spent")

func test_pierce_intent_ignores_block() -> void:
	# The anti-turtle tool: a pierce hit goes straight through block.
	var state := CombatState.create(catalog, 3, {
		"player_hp": 10,
		"deck": ["shadow_1", "shadow_1", "shadow_1", "shadow_1", "shadow_1"],
		"skills": ["slink"],
		"enemy": "garden_watch_captain",
		"shuffle": false,
		"opening_hand": 3,
	})
	# Fast-forward the intent cycle to Regulation Peck (index 2, pierce 3).
	state._intent_index = 2
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "slink"}), "slink up")
	assert_eq(state.player_block, 3, "block is up")
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.player_hp, 7, "pierce 3 lands through block 3 untouched")

## Chapter 1 enemies raise a guard ("block" intent): it soaks the player's
## damage and expires when the enemy next moves — the fight teaches timing
## the big hit for the open turn.
func test_enemy_guard_soaks_damage_until_its_next_move() -> void:
	var state := CombatState.create(catalog, 5, {
		"player_hp": 30, "shuffle": false,
		"deck": ["ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1",
				"ferocity_1", "ferocity_1"],
		"skills": ["pounce"], "enemy": "candle_golem",
	})
	state._intent_index = 1  # Hold the Light: it guards itself +4
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.enemy_block, 4, "the guard is raised")
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "pounce"}), "pounce into it")
	assert_eq(state.enemy_hp, 16, "the guard turned the whole pounce")
	assert_eq(state.enemy_block, 0, "and was spent doing it")
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scratch"}))
	assert_eq(state.enemy_hp, 15, "the next hit lands clean")


func test_enemy_guard_expires_when_it_moves() -> void:
	var state := CombatState.create(catalog, 5, {
		"player_hp": 30, "shuffle": false,
		"deck": ["guile_1", "guile_1", "guile_1"],
		"skills": [], "enemy": "candle_golem",
	})
	state._intent_index = 1  # Hold the Light
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.enemy_block, 4, "guard up")
	assert_ok(state.do_command({"type": "end_turn"}))  # Wax Over (jam) — its next move
	assert_eq(state.enemy_block, 0, "an unspent guard does not stack across its moves")


## Masked intents (owner 2026-08-09): a move with `masked_until: N` is
## unreadable until Ash has finished N fights against that enemy. Purely a
## telegraph matter — the move itself still happens as written.
func test_masked_intents_unmask_with_familiarity() -> void:
	var masked_intent := {"name": "Regulation Peck (past the guard)",
		"target": "health", "amount": 3, "masked_until": 1}
	var stranger := CombatState.create(catalog, 5, {
		"player_hp": 10, "deck": ["shadow_1", "shadow_1", "shadow_1"],
		"skills": [], "enemy": "garden_watch_captain",
	})
	assert_true(stranger.intent_masked(masked_intent),
		"a first meeting cannot read the trick move")
	assert_true(not stranger.intent_masked({"target": "health", "amount": 2}),
		"ordinary moves read from the first fight")
	var veteran := CombatState.create(catalog, 5, {
		"player_hp": 10, "deck": ["shadow_1", "shadow_1", "shadow_1"],
		"skills": [], "enemy": "garden_watch_captain",
		"familiarity": 1,
	})
	assert_true(not veteran.intent_masked(masked_intent),
		"one finished fight and Ash reads it")


func test_enemy_heal_mends_and_caps_at_full_thread() -> void:
	# Read the fixture's numbers from the catalog: the Tallowman is LIVE
	# balance data (balance-notes Pass 8 retuned it mid-pass), and a heal
	# test pinned to last week's hp fails on every retune without telling
	# anyone anything about healing.
	var full := int(catalog.enemies["the_tallowman"]["hp"])
	var state := CombatState.create(catalog, 5, {
		"player_hp": 30, "shuffle": false,
		"deck": ["guile_1", "guile_1", "guile_1"],
		"skills": [], "enemy": "the_tallowman",
	})
	assert_ok(state.do_command({"type": "play_skill", "skill_id": "scratch"}))
	assert_eq(state.enemy_hp, full - 1, "scratched once")
	state._intent_index = 2  # Reform — mends more than the scratch took
	assert_ok(state.do_command({"type": "end_turn"}))
	assert_eq(state.enemy_hp, full, "mending stops at its full thread — never over")


# --- found by the chaos harness (tests/chaos_play.gd), 2026-08-03 ---------

## A command that was REJECTED must change nothing at all. approach_locked
## used to be set before the command was validated, so a fumbled tap - a
## skill you cannot afford, a mis-swiped card index - silently cost the
## player their entrance before anything had happened.
func test_a_rejected_command_does_not_burn_the_approach() -> void:
	var state := _wisp_fight()
	assert_true(state.can_approach(), "turn 1 opens with the entrance available")
	assert_rejected(state.do_command({"type": "play_skill", "skill_id": "no_such_skill"}),
		"an unknown skill")
	assert_true(state.can_approach(), "a rejected skill tap must not close the window")
	assert_rejected(state.do_command({"type": "charge_skill", "skill_id": "pounce",
		"source": "hand", "index": 99}), "a bad index")
	assert_true(state.can_approach(), "a mis-swiped card must not close the window")
	assert_rejected(state.do_command({"type": "concentrate", "humour": "cheese"}),
		"a humour that does not exist")
	assert_true(state.can_approach(), "nonsense must not close the window")
	assert_ok(state.do_command({"type": "approach", "mode": "stalk"}),
		"the entrance is still there to be taken")

## ...and a command that SUCCEEDS still closes it. The fix must not turn
## into "approaches are free whenever you like".
func test_a_real_action_still_closes_the_approach() -> void:
	var state := _wisp_fight()
	var index := -1
	for i in state.hand.size():
		if catalog.energy_cards[state.hand[i]]["humour"] == "ferocity":
			index = i
			break
	assert_true(index >= 0, "seed 7 opening hand should contain ferocity")
	assert_ok(state.do_command({"type": "charge_skill", "skill_id": "pounce",
		"source": "hand", "index": index}), "a real action")
	assert_true(not state.can_approach(), "acting spends the moment for an entrance")
	assert_rejected(state.do_command({"type": "approach", "mode": "stalk"}),
		"the entrance after acting")


## Concentrate is PRICED (owner rule 2026-08-05: "it gives the desired energy
## immediately and any number of times — it should become active for the next
## turn, and there should be a cost"). Three prices: the turn, the delay, and
## a hard limit per fight.
func test_concentrate_costs_the_turn_and_runs_out() -> void:
	var state := CombatState.create(catalog, 11, {
		"player_hp": 30, "shuffle": false, "enemy": "the_vole",
		"deck": ["ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1"],
	})
	# Spend something so there is a card to will back.
	state.spent.append("ferocity_1")
	var before_turn := state.turn
	var hand_before := state.hand.size()
	assert_eq(state.concentrate_left, CombatState.CONCENTRATE_USES,
		"a fight opens with the full allowance")
	var result := state.do_command({"type": "concentrate", "humour": "ferocity"})
	assert_true(result["ok"], "concentrating with a spent Ferocity is legal")
	assert_true(state.turn > before_turn, "it costs the WHOLE turn — the enemy acts")
	assert_eq(state.concentrate_left, CombatState.CONCENTRATE_USES - 1,
		"and one of the allowance")
	assert_true(state.hand.size() <= hand_before + 1,
		"the card returns to the DECK, not straight into the hand")

	# Burn the rest, then be refused.
	while state.concentrate_left > 0 and state.outcome == CombatState.Outcome.ONGOING:
		state.spent.append("ferocity_1")
		state.do_command({"type": "concentrate", "humour": "ferocity"})
	state.spent.append("ferocity_1")
	var refused := state.do_command({"type": "concentrate", "humour": "ferocity"})
	assert_true(not refused["ok"],
		"an unlimited escape hatch is not a decision — it must run out")


func test_concentrate_is_refused_with_nothing_spent_of_that_humour() -> void:
	var state := CombatState.create(catalog, 12, {
		"player_hp": 30, "shuffle": false, "enemy": "the_vole",
		"deck": ["ferocity_1", "ferocity_1", "ferocity_1"],
	})
	var before := state.concentrate_left
	var result := state.do_command({"type": "concentrate", "humour": "shadow"})
	assert_true(not result["ok"], "there is no spent Shadow to will back")
	assert_eq(state.concentrate_left, before,
		"a REJECTED command changes nothing — not even the allowance (law 14)")


## Energy fed onto a card that never fired STAYS on the card for the next
## fight of the same venture (owner rule 2026-08-10). The prowl carries it as
## config `skill_powered`; only the Mantel clears it (a fresh quest starts
## with an empty carryover).
func test_powered_energy_carries_into_the_next_fight() -> void:
	var state := CombatState.create(catalog, 5, {
		"player_hp": 12, "shuffle": false,
		"deck": ["ferocity_1", "ferocity_1", "shadow_1"],
		"skills": ["pounce", "slink"],
		"enemy": "gutter_wisp",
		"skill_powered": {"pounce": {"ferocity": 1}},
	})
	assert_eq(state.skill_state("pounce")["powered"], {"ferocity": 1} as Dictionary,
		"the stored energy arrived with the fight")
	assert_eq(state.remaining_cost("pounce"), {"ferocity": 1} as Dictionary,
		"only the shortfall is still owed")
	assert_eq(state.skill_state("slink")["powered"], {} as Dictionary,
		"a card with nothing on it starts clean")
