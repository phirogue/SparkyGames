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


## Owner 2026-08-13: "if a player handles all the constraints but it's not a
## continuous seam, a hint pop up should appear saying that the constraints
## are met but it's not a continuous seam." The board can only raise that card
## if the rules can name WHICH way the thread failed, so seam_fault does —
## and it must say nothing at all when there is nothing wrong.
func test_stitch_names_why_an_answered_board_is_still_not_a_seam() -> void:
	var chart: Dictionary = catalog.stitch_charts["chart_hoop"]
	var solved := StitchState.create(chart)
	assert_eq(solved.seam_fault(), "", "an untouched board has nothing to say")
	for edge_id in chart["solution"]:
		solved.do_command({"type": "sew", "edge": String(edge_id)})
	assert_eq(solved.outcome, Minigame.Outcome.SUCCESS, "the hoop closes")
	assert_eq(solved.seam_fault(), "", "and a closed seam has no fault")

	# A run of stitches with two ends, on a board whose clues are all still
	# unanswered, must also stay quiet: an unanswered number is the louder
	# problem and the card would be shouting past it.
	var open_board := StitchState.create(chart)
	open_board.do_command({"type": "sew", "edge": "h:0:0"})
	assert_true(not open_board.all_clues_satisfied(), "numbers still outstanding")
	assert_eq(open_board.seam_fault(), "", "so the board says nothing yet")

	# A clue-less chart is the honest way to build each fault: with nothing to
	# answer, every board answers everything, and only the thread is at issue.
	var blank := StitchState.create({"width": 3, "height": 3, "clues": {},
		"solution": [], "when_outcome": {}})
	blank.do_command({"type": "sew", "edge": "h:0:0"})
	assert_eq(blank.seam_fault(), "loose_end", "one stitch has two loose ends")
	# A T-junction at a dot: three stitches meeting where thread cannot fork.
	var forked := StitchState.create({"width": 3, "height": 3, "clues": {},
		"solution": [], "when_outcome": {}})
	for edge_id in ["h:1:0", "h:1:1", "v:0:1", "v:1:1"]:
		forked.do_command({"type": "sew", "edge": edge_id})
	assert_eq(forked.seam_fault(), "branch", "the thread forks at a hole")


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


## Owner 2026-08-13: "treat it as another card game. Each new card drawn has a
## shape on it, the shape corresponds to the energy type." There is no rack:
## the cost is the DRAW, and what you get for it is whatever that card cuts.
func test_ward_drawing_spends_a_card_off_the_spool() -> void:
	var state := WardState.create(catalog, catalog.wards["ward_practice"],
		["shadow_3", "guile_1"])
	assert_eq(state.drawn, "", "the paw starts empty")
	assert_ok(state.do_command({"type": "draw"}), "draw the top of the spool")
	assert_eq(state.drawn, "guile_1", "the top card is in the paw")
	assert_eq(state.deck.size(), 1, "and off the spool")
	assert_eq(state.spent.size(), 1, "spent the moment it was drawn")
	assert_true(not state.can_draw(), "and no second card while the paw is full")
	assert_true(not state.do_command({"type": "draw"}).get("ok", false),
		"drawing with cloth in the paw is refused")


## The shape a card cuts is the card's, not the ward's — a new energy card
## owes a shape in data/patch_shapes.json or the draw is unplaceable.
func test_ward_shapes_come_from_the_card() -> void:
	var state := WardState.create(catalog, catalog.wards["ward_practice"], [])
	assert_eq(state.shape_of("shadow_3").size(), 4,
		"a worth-3 shadow card cuts a square of four")
	assert_eq(state.shape_of("mysticism_1").size(), 1,
		"the thinnest Moonlight card cuts a single stitch")
	for card_id in catalog.energy_cards:
		assert_true(not state.shape_of(String(card_id)).is_empty(),
			"energy card '%s' cuts nothing" % card_id)


func test_ward_a_square_of_cloth_closes_the_practice_tear() -> void:
	var state := WardState.create(catalog, catalog.wards["ward_practice"],
		["shadow_3"])
	state.do_command({"type": "draw"})
	assert_ok(state.do_command({"type": "place", "row": 1, "col": 1,
		"rotation": 0}), "the square lands over the tear")
	assert_eq(state.uncovered_cells().size(), 0, "nothing left open")
	assert_eq(state.outcome, Minigame.Outcome.SUCCESS,
		"a whole ward finishes itself")


## Owner 2026-08-09: patches may sit on top of each other and may hang over
## sound cloth. The rules stopped policing tidiness because the score already
## does it — cloth that covers nothing new bought nothing, and the card is
## gone either way.
func test_ward_patches_may_spill_onto_sound_cloth_and_stack() -> void:
	# The spool is drawn from the END, so shadow_1 (two straight) comes first
	# and the 2x2 square comes second.
	var state := WardState.create(catalog, catalog.wards["ward_practice"],
		["shadow_3", "shadow_1"])
	var open_before: int = state.uncovered_cells().size()
	state.do_command({"type": "draw"})
	assert_ok(state.do_command({"type": "place", "row": 0, "col": 0,
		"rotation": 0}), "cloth may land on sound cloth")
	assert_eq(state.uncovered_cells().size(), open_before,
		"but it closes nothing, which is the whole penalty")
	assert_eq(state.spent.size(), 1, "and the card is still gone")
	state.do_command({"type": "draw"})
	assert_ok(state.do_command({"type": "place", "row": 0, "col": 0,
		"rotation": 0}), "and a second piece may sit on top of the first")
	assert_eq(state.spent.size(), 2, "costing its own card")


## Lifting the top of a stack must uncover back to the patch underneath, not
## punch a hole through both — the reason cover is recomputed from the laying
## order rather than erased cell by cell.
func test_ward_lifting_the_top_of_a_stack_leaves_what_was_under_it() -> void:
	var state := WardState.create(catalog, catalog.wards["ward_practice"],
		["mysticism_1", "shadow_1"])
	state.do_command({"type": "draw"})            # shadow_1, two straight
	state.do_command({"type": "place", "row": 1, "col": 1, "rotation": 0})
	var under := String(state.placed_order[0])
	state.do_command({"type": "draw"})            # mysticism_1, one stitch
	state.do_command({"type": "place", "row": 1, "col": 1, "rotation": 0})
	var over := String(state.placed_order[1])
	assert_eq(String(state.covered["1,1"]), over, "the single stitch is on top")
	assert_ok(state.do_command({"type": "lift", "patch": over}))
	assert_eq(String(state.covered["1,1"]), under,
		"lifting it uncovers the piece beneath, not the cloth")


## Lifting picks the cloth back UP. It must not un-spend the card (that went
## at the draw, which is where the decision was) and must not put anything
## back on the spool — otherwise the same card winds down forever.
func test_ward_lifting_moves_cloth_and_never_cards() -> void:
	var state := WardState.create(catalog, catalog.wards["ward_practice"],
		["mysticism_1", "shadow_1"])
	state.do_command({"type": "draw"})
	state.do_command({"type": "place", "row": 0, "col": 0, "rotation": 0})
	var spent_before: int = state.spent.size()
	var deck_before: int = state.deck.size()
	var patch_key := String(state.placed_order[0])
	assert_ok(state.do_command({"type": "lift", "patch": patch_key}))
	assert_eq(state.drawn, "shadow_1", "the cloth is back in the paw")
	assert_eq(state.spent.size(), spent_before, "the card stays spent")
	assert_eq(state.deck.size(), deck_before, "and nothing goes back on the spool")
	assert_true(not state.do_command({"type": "draw"}).get("ok", false),
		"a full paw cannot draw")
	assert_ok(state.do_command({"type": "place", "row": 1, "col": 1,
		"rotation": 0}), "and the same cloth can be laid somewhere better")


func test_ward_gap_effects_match_the_cells_left_open() -> void:
	var state := WardState.create(catalog, catalog.wards["ward_hall"],
		["shadow_1"])
	state.do_command({"type": "draw"})
	assert_ok(state.do_command({"type": "place", "row": 1, "col": 1,
		"rotation": 0}), "one piece, then the spool is bare")
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


## THE BUG THIS PINS (owner 2026-08-16): "do not change the color of the
## threads once they become uncovered, at the moment the legal threads just
## become red, making the game completely trivial."
##
## Colouring the pullable threads is a TEACHING aid and belongs on exactly one
## board: the practice lattice the unpicking lesson opens. It had drifted onto
## `lattice_counting_room`, which is a graded puzzle inside `creditors` — so
## the first real unpicking in the game highlighted its own answers. Reading
## the stack IS this minigame; a board that marks the legal threads has no
## puzzle left in it.
func test_only_the_practice_lattice_reveals_its_free_threads() -> void:
	var lesson_board := ""
	var lesson: Dictionary = catalog.lessons.get("unpicking", {})
	var scene := String(lesson.get("scene", ""))
	if scene.begins_with("lattice:"):
		lesson_board = scene.trim_prefix("lattice:")
	assert_true(lesson_board != "",
		"the unpicking lesson must open a lattice, got '%s'" % scene)
	for lattice_id in catalog.lattices:
		var teaches: bool = bool(
			catalog.lattices[lattice_id].get("teach_free", false))
		if lattice_id == lesson_board:
			assert_true(teaches,
				"%s is the lesson board and must show what 'free' looks like"
					% lattice_id)
		else:
			assert_true(not teaches,
				"%s is a real puzzle and must not colour in its own answers"
					% lattice_id)


# ---------------------------------------------------- 5. The Long Way Home

func test_crossings_can_be_crossed() -> void:
	var bots := _bots()
	for crossing_id in catalog.crossings:
		for seed_value in [11, 404, 9001]:
			bots.solve_crossing(crossing_id, TEST_DECK, seed_value)
		bots.probe_crossing_peek(crossing_id, TEST_DECK, 77)
	assert_eq(bots.violations.size(), 0, "crossing: %s" % str(bots.violations))


## Owner 2026-08-13: "the character continuously chooses the energy in their
## hand to play based on the marked effects described." Paying is the whole
## verb, so it gets the whole test: the right energy counts, the wrong energy
## is refused outright, Moonlight counts toward anything, and worth is what is
## counted rather than cards.
func test_crossing_pays_a_way_in_the_energy_it_asks_for() -> void:
	var state := CrossingState.create(catalog, 42,
		catalog.crossings["crossing_practice"],
		{"player_hp": 10, "deck": TEST_DECK.duplicate(), "shuffle": false,
		"opening_hand": 8})
	# The practice road opens on a gate: over it for 3 ferocity, the hinge for
	# 2 guile, or wait for 4 of anything.
	assert_ok(state.do_command({"type": "choose", "way": "hinge"}))
	assert_eq(state.cost_of("hinge"), 2, "the hinge wants two of guile")
	assert_true(not state.do_command({"type": "put", "card": "shadow_2"})
		.get("ok", false), "shadow is no use on a guile way")
	assert_ok(state.do_command({"type": "put", "card": "guile_1"}),
		"guile counts toward a guile way")
	assert_eq(state.paid_worth(), 1, "worth 1 down")
	assert_eq(state.shortfall(), 1, "and one still owing")
	assert_ok(state.do_command({"type": "put", "card": "mysticism_1"}),
		"Moonlight pays toward anything")
	assert_eq(state.shortfall(), 0, "which covers it")
	assert_eq(state.risk(), 0.0, "a way paid in full is no gamble at all")


## Changing your mind hands the cards back. They were offered, never spent —
## only GO spends them.
func test_crossing_choosing_again_returns_what_was_offered() -> void:
	var state := CrossingState.create(catalog, 42,
		catalog.crossings["crossing_practice"],
		{"player_hp": 10, "deck": TEST_DECK.duplicate(), "shuffle": false,
		"opening_hand": 8})
	var hand_before: int = state.hand.size()
	state.do_command({"type": "choose", "way": "hinge"})
	state.do_command({"type": "put", "card": "guile_1"})
	assert_eq(state.hand.size(), hand_before - 1, "the card left the paw")
	assert_eq(state.spent.size(), 0, "but nothing is spent yet")
	assert_ok(state.do_command({"type": "choose", "way": "wait"}))
	assert_eq(state.hand.size(), hand_before, "changing way hands it back")
	assert_eq(state.paid_worth(), 0, "and the new way starts unpaid")


## Paying in full is never a gamble; going short always is, and the odds rise
## with the shortfall. The board posts risk() before the commit, so this is
## the number the player is shown.
func test_crossing_shortfall_is_a_posted_gamble() -> void:
	var state := CrossingState.create(catalog, 42,
		catalog.crossings["crossing_practice"],
		{"player_hp": 10, "deck": TEST_DECK.duplicate(), "shuffle": false,
		"opening_hand": 8})
	state.do_command({"type": "choose", "way": "wait"})   # the any-energy way
	# Read the price off the data rather than pinning it: the way costs were
	# retuned on 2026-08-16 against what a paw actually holds, and a test that
	# hardcodes them fails for the wrong reason next time they move.
	var cost := state.cost_of("wait")
	assert_true(cost >= 2, "the any-energy way has to cost something")
	assert_eq(state.shortfall(), cost, "nothing down yet")
	var bare := state.risk()
	state.do_command({"type": "put", "card": "shadow_2"})
	assert_eq(state.shortfall(), cost - 2,
		"worth 2 down against a cost of %d" % cost)
	assert_true(state.risk() < bare,
		"putting energy down must lower the risk, %f vs %f" % [state.risk(), bare])
	assert_true(state.risk() > 0.0, "and short is never free")


## THE BUG THIS PINS (owner 2026-08-16): "the actions are very expensive, most
## of the time the card load out is not enough to fully pay for any of the
## actions." Every point offered ways at 2 and 3 of a named humour and 4 of
## anything, against an opening paw of three value-1 cards — worth 3 in total
## and about 1 in any one colour. Nothing was ever payable, so a board built
## to be a decision was really a slot machine with extra steps.
##
## The invariant: at EVERY point of EVERY crossing, a full paw dealt off the
## shipped starting deck can pay for at least one way outright. The player may
## still choose to go short — that is the game — but going short must never be
## the only thing on offer.
func test_crossing_a_full_paw_can_always_afford_a_way() -> void:
	var start: Array = catalog.rules.list("start.deck")
	var hand_size: int = catalog.rules.count("combat.opening_hand")
	# A full paw of the starting deck, valued the way the board values it.
	var paw_worth := 0
	for i in hand_size:
		paw_worth += int(catalog.energy_cards.get(
			String(start[i % start.size()]), {}).get("value", 0))
	for crossing_id in catalog.crossings:
		var crossing: Dictionary = catalog.crossings[crossing_id]
		for point in crossing.get("points", []):
			var cheapest := 999
			for way in point.get("ways", []):
				cheapest = mini(cheapest, int(way.get("cost", 0)))
			assert_true(cheapest <= paw_worth,
				"%s/%s: cheapest way costs %d but a full paw is only worth %d" \
					% [crossing_id, String(point.get("id", "?")), cheapest,
					paw_worth])


## The paw is dealt back UP at each point rather than topped up by one, or it
## withers: open on three, spend two, meet the second thing in the road
## holding two and the third holding one, at which point every remaining
## decision is forced. The deck is the prowl's shared spool, so this is not
## free — it just charges the player somewhere they can see it.
func test_crossing_deals_the_paw_back_up_at_each_point() -> void:
	var state := CrossingState.create(catalog, 7,
		catalog.crossings["crossing_practice"],
		{"player_hp": 40, "player_max_hp": 40, "deck": TEST_DECK.duplicate()})
	var want: int = mini(state.hand_size, TEST_DECK.size())
	assert_eq(state.hand.size(), want, "opens on a full paw")
	var guard := 0
	while not Minigame.is_over(state.outcome) and guard < 20:
		guard += 1
		state.do_command({"type": "choose",
			"way": String(state.ways()[0].get("id", ""))})
		# Spend everything that is any use on this way.
		for card_id in state.hand.duplicate():
			state.do_command({"type": "put", "card": card_id})
		state.do_command({"type": "go"})
		if Minigame.is_over(state.outcome):
			break
		assert_eq(state.hand.size(), mini(state.hand_size,
			state.hand.size() + state.deck.size()),
			"the paw is dealt back up at every point, not topped up by one")


## Going is never refused, however little is on the way — no board in this
## game is a wall. What it costs is health, and only sometimes.
func test_crossing_going_short_is_allowed_and_only_sometimes_bites() -> void:
	var bitten := 0
	var arrived := 0
	for seed_value in [1, 2, 3, 4, 5, 6, 7, 8]:
		var state := CrossingState.create(catalog, seed_value,
			catalog.crossings["crossing_practice"],
			{"player_hp": 40, "player_max_hp": 40, "deck": TEST_DECK.duplicate()})
		var guard := 0
		while not Minigame.is_over(state.outcome) and guard < 40:
			assert_ok(state.do_command({"type": "choose",
				"way": String(state.ways()[0].get("id", ""))}),
				"there is always a way to choose")
			var result := state.do_command({"type": "go"})
			assert_ok(result, "going short is a legal move, not a refusal")
			if result.get("bitten", false):
				bitten += 1
			guard += 1
		if state.outcome == Minigame.Outcome.SUCCESS:
			arrived += 1
		assert_true(Minigame.is_over(state.outcome), "the crossing must resolve")
	assert_true(bitten > 0, "paying nothing at all must sometimes cost")
	assert_true(arrived > 0,
		"and a cat with health to spare must sometimes still get home")


## The same seed and the same choices must give the same night — the roll is
## off CoreRng, so a crossing still replays and still sims (law 8).
func test_crossing_is_deterministic_under_a_seed() -> void:
	var first := _walk_crossing(99)
	var second := _walk_crossing(99)
	assert_eq(first, second, "the same seed must produce the same crossing")
	# ...and the rolls must actually be rolls. Sampled rather than compared in
	# pairs: two seeds CAN agree by chance, and a test that fails on a
	# coincidence is a test that fails for no reason.
	var seen := {}
	for seed_value in [1, 2, 3, 5, 8, 13, 21, 34]:
		seen[_walk_crossing(seed_value)] = true
	assert_true(seen.size() > 1,
		"a shortfall must be a gamble, not a foregone conclusion (got %s)"
			% str(seen.keys()))


func _walk_crossing(seed_value: int) -> String:
	var state := CrossingState.create(catalog, seed_value,
		catalog.crossings["crossing_mereside"],
		{"player_hp": 40, "player_max_hp": 40, "deck": TEST_DECK.duplicate()})
	var guard := 0
	while not Minigame.is_over(state.outcome) and guard < 40:
		state.do_command({"type": "choose",
			"way": String(state.ways()[0].get("id", ""))})
		state.do_command({"type": "go"})
		guard += 1
	return "%d/%d/%d" % [state.outcome, state.player_hp, state.hurts]


## No soft-locks: at every corner there is always a way to choose and always
## a GO available, because going short is legal. The validator guarantees a
## way any energy can pay for; the rules guarantee you may go anyway.
func test_crossing_never_soft_locks() -> void:
	var state := CrossingState.create(catalog, 7,
		catalog.crossings["crossing_practice"],
		{"player_hp": 10, "deck": TEST_DECK.duplicate()})
	var guard := 0
	while not Minigame.is_over(state.outcome) and guard < 300:
		assert_true(state.ways().size() >= 2, "every point offers a way past")
		var has_any := false
		for way in state.ways():
			if String(way.get("humour", "")) == "any":
				has_any = true
		assert_true(has_any, "and one of them takes any energy at all")
		state.do_command({"type": "choose",
			"way": String(state.ways()[0].get("id", ""))})
		assert_ok(state.do_command({"type": "go"}), "a legal move must always exist")
		guard += 1
	assert_true(Minigame.is_over(state.outcome),
		"the crossing must reach an ending, got %s after %d moves" % [
			Minigame.outcome_name(state.outcome), guard])


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
