extends TestCase
## The five mission minigames: rules, content validity, and the invariants
## the bot harness enforces. The full sweep is tests/minigames.gd; this is
## the slice that runs on every commit.

var catalog: Catalog = DataLoader.load_catalog()


func _bots() -> MinigameBots:
	return MinigameBots.new(catalog)


func _all_evidence() -> Array:
	var held: Array = catalog.evidence_ids().keys()
	held.sort()
	return held


const TEST_DECK: Array = [
	"ferocity_1", "ferocity_2", "guile_1", "guile_2",
	"shadow_1", "shadow_2", "mysticism_1", "mysticism_2",
]


# ---------------------------------------------------------------- content

## The expensive searches (exact cover, loop checks, safe pull order) belong
## here rather than at boot: a puzzle with no solution must never ship, but
## proving that every launch would cost the player start-up time.
func test_all_shipped_puzzles_are_solvable() -> void:
	var problems := catalog.validate_minigames_deep()
	assert_eq(problems.size(), 0, "minigame content problems: %s" % str(problems))


## Owner 2026-08-09: three of the five modules "make no sense, need a
## tutorial". A module the player can be dropped into owes them an
## explanation, and the explanation is content, so it is checked like content.
func test_every_module_teaches_itself() -> void:
	for module in Catalog.MINIGAME_MODULES:
		var steps := catalog.tutorial_steps(module)
		assert_true(steps.size() >= 2,
			"minigame '%s' has no tutorial" % module)
		for step in steps:
			assert_true(String(step.get("text", "")).strip_edges() != "",
				"a '%s' tutorial step says nothing" % module)


func test_every_module_carries_all_three_outcomes() -> void:
	# Failure is a story outcome, never a game-over, so every puzzle owes
	# prose for success, partial AND walk-away.
	for table in [catalog.stitch_charts, catalog.testimonies, catalog.wards,
			catalog.lattices, catalog.crossings]:
		for id in table:
			var texts: Dictionary = table[id].get("when_outcome", {})
			for key in ["success", "partial", "walk_away"]:
				assert_true(String(texts.get(key, "")) != "",
					"'%s' has no '%s' outcome text" % [id, key])


## Rewards are earned, not attended: the module reward table pays on SUCCESS
## and on nothing else. (It pays through earned_rewards() — the collector in
## game.gd reads methods, not properties; the old property probe matched
## nothing and every reward table was silently skipped.)
func test_module_rewards_pay_only_on_success() -> void:
	var ward := WardState.create(catalog, catalog.wards["ward_hall"], TEST_DECK)
	assert_eq(ward.earned_rewards().size(), 0, "an unfinished ward has earned nothing")
	ward.outcome = Minigame.Outcome.WALKED
	assert_eq(ward.earned_rewards().size(), 0, "a walked-away ward earns nothing")
	ward.outcome = Minigame.Outcome.PARTIAL
	assert_eq(ward.earned_rewards().size(), 0, "a half-mend earns nothing either")
	ward.outcome = Minigame.Outcome.SUCCESS
	assert_eq(ward.earned_rewards(),
		catalog.wards["ward_hall"].get("rewards", {}) as Dictionary,
		"a closed ward pays exactly its table")


# ---------------------------------------------------------- 1. Seam & Stitch

func test_stitch_charts_can_be_sewn() -> void:
	var bots := _bots()
	for chart_id in catalog.stitch_charts:
		bots.solve_stitch(chart_id)
	assert_eq(bots.violations.size(), 0, "stitch: %s" % str(bots.violations))


func test_stitch_squint_never_lies() -> void:
	var bots := _bots()
	for chart_id in catalog.stitch_charts:
		bots.probe_stitch_squint(chart_id)
	assert_eq(bots.violations.size(), 0, "squint: %s" % str(bots.violations))


## One closed loop, not two. Three sides of a square is not a seam, and two
## separate rings are not a seam either — this is the rule the whole puzzle
## rests on, so it gets its own test rather than only living in a solver.
func test_stitch_requires_exactly_one_closed_loop() -> void:
	var state := StitchState.create(catalog.stitch_charts["chart_hoop"])
	for edge_id in ["h:0:0", "v:0:0", "h:2:0"]:
		state.do_command({"type": "sew", "edge": edge_id})
	assert_true(not state.is_single_loop(), "an open run of stitches is not a loop")
	assert_eq(state.outcome, Minigame.Outcome.ONGOING, "and does not finish the chart")


## Owner 2026-08-09: "When a legal solution is presented, nothing happens."
## Half of that was here — completion was only ever checked after SEWING, so
## a player who over-sewed and then unpicked their way onto the answer had
## already made the last move the game was listening for.
func test_stitch_closes_when_the_last_move_is_an_unpick() -> void:
	var chart: Dictionary = catalog.stitch_charts["chart_hoop"]
	var state := StitchState.create(chart)
	# One stitch too many, then the whole solution.
	var spare := ""
	for edge_id in state.all_edges():
		if not chart["solution"].has(edge_id):
			spare = edge_id
			break
	assert_true(spare != "", "the hoop has an edge outside its solution")
	state.do_command({"type": "sew", "edge": spare})
	for edge_id in chart["solution"]:
		state.do_command({"type": "sew", "edge": String(edge_id)})
	assert_eq(state.outcome, Minigame.Outcome.ONGOING,
		"an extra stitch is not a closed seam")
	assert_ok(state.do_command({"type": "unpick", "edge": spare}))
	assert_eq(state.outcome, Minigame.Outcome.SUCCESS,
		"taking out the last wrong stitch closes it")


## Owner 2026-08-09: "Squint doesn't do anything, but should highlight a
## possible edge that is part of the solution."
func test_squint_points_at_a_stitch_that_is_in_the_seam() -> void:
	var chart: Dictionary = catalog.stitch_charts["chart_sampler"]
	var state := StitchState.create(chart)
	var result := state.do_command({"type": "squint"})
	assert_true(chart["solution"].has(String(result.get("sew", ""))),
		"squint must name a stitch the finished seam uses")
	assert_eq(state.squint_sew, String(result.get("sew", "")),
		"and the board must be told which one, so it can draw it")
	# Sewing it clears the callout: a hint you have acted on is stale.
	state.do_command({"type": "sew", "edge": state.squint_sew})
	assert_eq(state.squint_sew, "", "acting on a hint clears it")


func test_stitch_unpicking_is_free_and_reversible() -> void:
	var state := StitchState.create(catalog.stitch_charts["chart_hoop"])
	var paws: int = state.paws
	assert_ok(state.do_command({"type": "sew", "edge": "h:0:0"}))
	assert_ok(state.do_command({"type": "unpick", "edge": "h:0:0"}))
	assert_eq(state.sewn.size(), 0, "the stitch is gone")
	assert_eq(state.paws, paws, "thinking again costs nothing")
	assert_rejected(state.do_command({"type": "unpick", "edge": "h:0:0"}),
		"unpicking nothing")


# ------------------------------------------------------------- 2. Testimony

func test_testimony_can_be_broken() -> void:
	var bots := _bots()
	for testimony_id in catalog.testimonies:
		bots.solve_testimony(testimony_id, _all_evidence())
	assert_eq(bots.violations.size(), 0, "testimony: %s" % str(bots.violations))


func test_testimony_patience_runs_out_into_partial() -> void:
	var bots := _bots()
	for testimony_id in catalog.testimonies:
		bots.probe_testimony_patience(testimony_id, _all_evidence())
	assert_eq(bots.violations.size(), 0, "patience: %s" % str(bots.violations))


## Fair play: a ribbon only shimmers once the player actually holds the
## evidence that disproves it. Otherwise the shimmer is a pixel-hunt marker
## for something they cannot act on yet.
func test_testimony_shimmer_waits_for_the_evidence() -> void:
	var testimony: Dictionary = catalog.testimonies["shift_boss"]
	var empty := TestimonyState.create(testimony, [])
	for ribbon_id in empty.ribbons:
		assert_true(not empty.is_shimmering(ribbon_id),
			"'%s' shimmered with an empty Casebook" % ribbon_id)
	var armed := TestimonyState.create(testimony, ["wick_ledger"])
	armed.do_command({"type": "press", "ribbon": "r_round"})
	assert_true(armed.is_shimmering("r_signed"),
		"the ledger must mark the ribbon it disproves")


func test_testimony_cannot_present_what_you_do_not_hold() -> void:
	var state := TestimonyState.create(catalog.testimonies["shift_boss"], [])
	assert_rejected(state.do_command({"type": "present", "ribbon": "r_round",
		"evidence": "wick_ledger"}), "presenting evidence you lack")


# -------------------------------------------------------- 3. Patch the Ward

func test_wards_can_be_mended() -> void:
	var bots := _bots()
	for ward_id in catalog.wards:
		bots.solve_ward(ward_id, TEST_DECK)
		bots.probe_ward_lift(ward_id, TEST_DECK)
	assert_eq(bots.violations.size(), 0, "ward: %s" % str(bots.violations))


## The economy hook: a patch is paid from the hand, and Moonlight is wild.
## If patches were free the module would be a puzzle bolted beside the game
## rather than a decision inside it.
func test_ward_patches_are_paid_for_from_the_hand() -> void:
	var state := WardState.create(catalog, catalog.wards["ward_practice"],
		["mysticism_1", "shadow_1"])
	assert_eq(state.hand.size(), 2, "two cards to spend")
	assert_true(state.can_afford("p_domino"), "shadow pays for the shadow patch")
	assert_true(state.can_afford("p_square"), "and the wild pays for the square")
	assert_ok(state.do_command({"type": "place", "patch": "p_domino",
		"row": 1, "col": 1, "rotation": 0}), "place the domino")
	assert_eq(state.hand.size(), 1, "a card left the paw")
	assert_eq(state.spent.size(), 1, "and went to the spent pile")


## Owner 2026-08-09: patches may sit on top of each other and may hang over
## sound cloth. The rules stopped policing tidiness because the score already
## does it — a patch that covers nothing new bought nothing and cost a card.
func test_ward_patches_may_spill_onto_sound_cloth() -> void:
	var state := WardState.create(catalog, catalog.wards["ward_practice"], TEST_DECK)
	# The practice tear is 2x2 at (1,1). Laying a domino on plain cloth is now
	# legal, pays a card, and mends nothing.
	var open_before: int = state.uncovered_cells().size()
	assert_ok(state.do_command({"type": "place", "patch": "p_domino",
		"row": 0, "col": 0, "rotation": 0}), "a patch may land on sound cloth")
	assert_eq(state.spent.size(), 1, "and it still costs a card")
	assert_eq(state.uncovered_cells().size(), open_before,
		"but it closes nothing, which is the whole penalty")


func test_ward_patches_may_stack_and_only_coverage_counts() -> void:
	var state := WardState.create(catalog, catalog.wards["ward_practice"],
		["mysticism_1", "shadow_1", "guile_1"])
	# The square covers the whole 2x2 tear...
	assert_ok(state.do_command({"type": "place", "patch": "p_square",
		"row": 1, "col": 1, "rotation": 0}), "the square fills the tear")
	assert_eq(state.uncovered_cells().size(), 0, "nothing left open")
	assert_eq(state.outcome, Minigame.Outcome.SUCCESS, "a whole ward finishes itself")
	# ...and a second patch laid over it would have been legal and worthless.
	var stacked := WardState.create(catalog, catalog.wards["ward_practice"],
		["shadow_1", "guile_1"])
	assert_ok(stacked.do_command({"type": "place", "patch": "p_domino",
		"row": 1, "col": 1, "rotation": 0}), "the domino takes two squares")
	assert_eq(stacked.uncovered_cells().size(), 2, "two still open")
	assert_ok(stacked.do_command({"type": "place", "patch": "p_dot",
		"row": 1, "col": 1, "rotation": 0}), "a dot may sit on top of it")
	assert_eq(stacked.uncovered_cells().size(), 2, "and mends nothing new")
	assert_eq(stacked.spent.size(), 2, "while still costing its card")


## Lifting the top of a stack must uncover back to the patch underneath, not
## punch a hole through both — the reason cover is recomputed from the laying
## order rather than erased cell by cell.
func test_ward_lifting_the_top_of_a_stack_leaves_what_was_under_it() -> void:
	var state := WardState.create(catalog, catalog.wards["ward_practice"],
		["shadow_1", "guile_1"])
	state.do_command({"type": "place", "patch": "p_domino",
		"row": 1, "col": 1, "rotation": 0})
	state.do_command({"type": "place", "patch": "p_dot",
		"row": 1, "col": 1, "rotation": 0})
	assert_eq(String(state.covered["1,1"]), "p_dot", "the dot is on top")
	assert_ok(state.do_command({"type": "lift", "patch": "p_dot"}))
	assert_eq(String(state.covered["1,1"]), "p_domino",
		"lifting the dot uncovers the domino, not the cloth")
	assert_eq(state.uncovered_cells().size(), 2, "and opens nothing new")


func test_ward_gap_effects_match_the_cells_left_open() -> void:
	var state := WardState.create(catalog, catalog.wards["ward_hall"], ["shadow_1"])
	assert_ok(state.do_command({"type": "place", "patch": "p_domino",
		"row": 1, "col": 1, "rotation": 0}), "one patch, then out of matching energy")
	assert_ok(state.do_command({"type": "finish"}))
	assert_eq(state.outcome, Minigame.Outcome.PARTIAL, "a thin mend is partial")
	assert_eq(state.carried_effects().size(), state.uncovered_cells().size(),
		"one gap effect per cell left open")


# -------------------------------------------------------- 4. The Unpicking

func test_lattices_can_be_undone() -> void:
	var bots := _bots()
	for lattice_id in catalog.lattices:
		bots.solve_lattice(lattice_id)
		bots.probe_lattice_mistake(lattice_id)
	assert_eq(bots.violations.size(), 0, "lattice: %s" % str(bots.violations))


## A blocked pull is a COST, not a rejection — the command succeeds, the
## thread stays, the alarm climbs. Rejecting it would make the puzzle
## unloseable and the alarm decorative.
func test_lattice_blocked_pull_costs_rather_than_refuses() -> void:
	var state := LatticeState.create(catalog.lattices["lattice_counting_room"])
	var result := state.do_command({"type": "pull", "thread": "t_floor"})
	assert_ok(result, "a blocked pull is still a legal move")
	assert_true(not result.get("pulled", true), "but the thread stays put")
	assert_eq(state.alarm, 1, "and the lattice twangs")


## Elastic rules re-cross threads mid-puzzle. The safe order must survive
## them, or the puzzle strands itself and looks merely hard.
func test_lattice_elastic_still_has_a_safe_order() -> void:
	var state := LatticeState.create(catalog.lattices["lattice_elastic"])
	var order := state.safe_order()
	assert_eq(order.size(), state.order.size(),
		"every thread must come out in some order, got %s" % str(order))
	assert_eq(String(order[0]), "e_top", "the free thread goes first")


# ---------------------------------------------------- 5. The Long Way Round

func test_crossings_can_be_crossed() -> void:
	var bots := _bots()
	for crossing_id in catalog.crossings:
		for seed_value in [11, 404, 9001]:
			bots.solve_crossing(crossing_id, TEST_DECK, seed_value)
		bots.probe_crossing_peek(crossing_id, TEST_DECK, 77)
	assert_eq(bots.violations.size(), 0, "crossing: %s" % str(bots.violations))


## Sheltering burns a card. Without that cost the hand only ever grew, every
## gust eventually matched something, and the crossing could not be finished
## — the defect the feasibility runner caught on its first pass.
func test_crossing_sheltering_costs_a_card() -> void:
	var state := CrossingState.create(catalog, 42,
		catalog.crossings["crossing_practice"],
		{"player_hp": 10, "deck": TEST_DECK.duplicate()})
	var hand_before: int = state.hand.size()
	assert_ok(state.do_command({"type": "shelter"}))
	assert_eq(state.hand.size(), hand_before - 1, "waiting it out costs energy")
	assert_eq(state.spent.size(), 1, "and the card is spent, not discarded")


## No soft-locks: at every moment either the crossing is over, or there is
## still something the player can do. Shelter needs a card to burn and
## Press On needs a card or a deck, so the dangerous state is "hand empty" —
## and that must always leave Press On (which draws) or the ending.
func test_crossing_never_soft_locks() -> void:
	var state := CrossingState.create(catalog, 7,
		catalog.crossings["crossing_practice"],
		{"player_hp": 10, "deck": TEST_DECK.duplicate()})
	var guard := 0
	while not Minigame.is_over(state.outcome) and guard < 300:
		assert_true(not state.hand.is_empty() or not state.deck.is_empty(),
			"nothing in hand AND nothing in deck must end the crossing, not stall it")
		# Wait out a gust when there is something to burn, press otherwise.
		var command := {"type": "shelter"} if not state.hand.is_empty() \
			else {"type": "press_on"}
		assert_ok(state.do_command(command), "a legal move must always exist")
		guard += 1
	assert_true(Minigame.is_over(state.outcome),
		"the crossing must reach an ending, got %s after %d moves" % [
			Minigame.outcome_name(state.outcome), guard])


func test_crossing_progress_never_falls_below_shelter() -> void:
	var state := CrossingState.create(catalog, 5,
		catalog.crossings["crossing_mereside"],
		{"player_hp": 10, "deck": TEST_DECK.duplicate()})
	var guard := 0
	while not Minigame.is_over(state.outcome) and guard < 200:
		state.do_command({"type": "press_on"})
		assert_true(state.progress >= state.sheltered,
			"sheltered progress must be safe from a slip")
		guard += 1


# ------------------------------------------------------------------ chaos

func test_random_and_illegal_play_breaks_nothing() -> void:
	var bots := _bots()
	for seed_value in [3, 1971]:
		for chart_id in catalog.stitch_charts:
			bots.chaos_stitch(chart_id, seed_value)
		for testimony_id in catalog.testimonies:
			bots.chaos_testimony(testimony_id, _all_evidence(), seed_value)
		for ward_id in catalog.wards:
			bots.chaos_ward(ward_id, TEST_DECK, seed_value)
		for lattice_id in catalog.lattices:
			bots.chaos_lattice(lattice_id, seed_value)
		for crossing_id in catalog.crossings:
			bots.chaos_crossing(crossing_id, TEST_DECK, seed_value)
	assert_eq(bots.violations.size(), 0, "chaos: %s" % str(bots.violations))
