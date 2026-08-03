extends TestCase
## Chapter 1 spine: the Case Board's data (evidence, suspects, threads,
## leads, recap), guild standing, favor-knots, and quest schema v2 gating.
## All pure — no scene tree, no save file.

const CASE_ID := "wax_and_wick"


func _catalog() -> Catalog:
	return DataLoader.load_catalog()


func _profile(evidence: Array = [], standing: Dictionary = {},
		favors: Array = []) -> Dictionary:
	var profile := SaveService.DEFAULT_PROFILE.duplicate(true)
	profile["prologue_done"] = true
	profile["case"]["evidence"] = evidence.duplicate()
	profile["standing"] = standing.duplicate()
	profile["favors"] = favors.duplicate()
	return profile


# ------------------------------------------------------------------ content

func test_shipped_case_content_is_coherent() -> void:
	var catalog := _catalog()
	assert_true(catalog.cases.has(CASE_ID), "Chapter 1's case file must exist")
	assert_eq(catalog.cases[CASE_ID]["evidence"].size(), 5,
		"Wax & Wick is a five-evidence case (chapters/01)")
	assert_eq(catalog.cases[CASE_ID]["leads"].size(), 5, "five main leads")
	assert_true(catalog.guilds.size() >= 2, "guild standing needs guilds")
	assert_true(not catalog.favors.is_empty(), "favor-knots need favors")
	assert_eq(catalog.validate().size(), 0,
		"shipped content problems: %s" % str(catalog.validate()))


func test_validation_catches_broken_case_wiring() -> void:
	# A lead pointing at evidence that does not exist is a lead the player
	# could never finish — it must never reach a build.
	var bad := Catalog.new({
		"cases": {"c": {
			"id": "c", "question": "?",
			"suspects": [{"id": "s", "name": "", "revealed_by": "ghost"}],
			"evidence": [{"id": "e", "name": "E", "note": "n", "lead": "nowhere",
				"implicates": ["nobody"]}],
			"leads": [{"id": "l", "board_card": "", "evidence": "missing",
				"requires": ["also_missing"]}],
		}},
		"guilds": {"g": {"id": "g", "name": "", "neutral_line": "",
			"notices": [{"at": 0, "text": ""}]}},
		"favors": {"f": {"id": "f", "name": "F", "guild": "nope", "redeem_lines": []}},
	})
	var problems := bad.validate()
	assert_true(problems.size() >= 10,
		"expected the broken case/guild/favor wiring to be caught, got %d: %s" % [
			problems.size(), str(problems)])


func test_validation_catches_quest_v2_problems() -> void:
	var bad := Catalog.new({
		"encounters": {"enc": {"id": "enc", "enemies": []}},
		"quests": {"q": {"id": "q", "name": "Q", "board_card": "card",
			"encounters": ["enc"], "kind": "sideways", "district": "atlantis",
			"guild": "nobody", "requires": {"evidence": ["nothing"],
				"standing": {"nobody": 1}}}},
	})
	var problems := bad.validate()
	assert_true(problems.size() >= 5,
		"expected kind/district/guild/requires problems, got %s" % str(problems))


# ----------------------------------------------------------------- evidence

func test_evidence_is_recorded_once() -> void:
	var profile := _profile()
	assert_true(CaseState.add_evidence(profile, "candle_stub"), "first find is new")
	assert_true(not CaseState.add_evidence(profile, "candle_stub"),
		"a re-run of the same lead must not re-announce its thing")
	assert_true(CaseState.has_evidence(profile, "candle_stub"), "and it is held")


func test_evidence_slots_show_what_is_still_missing() -> void:
	var slots := CaseState.evidence_slots(_catalog(), _profile(["candle_stub"]))
	assert_eq(slots.size(), 5, "every slot is shown, found or not")
	assert_true(slots[0]["found"], "the found one is marked found")
	assert_true(not slots[1]["found"], "the rest are still out there")


# ----------------------------------------------------------------- suspects

func test_suspects_reveal_with_the_evidence_that_names_them() -> void:
	var catalog := _catalog()
	var fresh := CaseState.suspects_known(catalog, _profile())
	assert_eq(fresh.size(), 1,
		"only the shape from the prologue is face-up at the start")
	assert_eq(String(fresh[0]["id"]), "unpicked", "and it is the Unpicked")
	var later := CaseState.suspects_known(catalog, _profile(["candle_stub"]))
	assert_eq(later.size(), 2, "the sealed stub puts Wick on the board")


func test_threads_never_point_at_an_unmet_suspect() -> void:
	var catalog := _catalog()
	# cart_docket implicates the Gentleman AND reveals him, so both ends
	# exist; backward_seam alone must not draw a thread to anyone unmet.
	var threads := CaseState.threads(catalog, _profile(["backward_seam"]))
	for thread: Array in threads:
		assert_true(thread[1] == "unpicked",
			"a thread to a suspect the player has not met would spoil them")
	assert_eq(CaseState.threads(catalog, _profile()).size(), 0,
		"nothing found, nothing strung")


# -------------------------------------------------------------------- leads

func test_next_lead_follows_the_requires_chain() -> void:
	var catalog := _catalog()
	assert_eq(String(CaseState.next_lead(catalog, _profile())["id"]), "l1",
		"a fresh case starts on the first lead")
	assert_eq(String(CaseState.next_lead(catalog, _profile(["candle_stub"]))["id"]),
		"l2", "the stub unblocks the ledger job")
	# Out-of-order evidence must not skip the chain: L2's evidence found by
	# some other route still leaves L1's thing missing, so L1 is next.
	assert_eq(String(CaseState.next_lead(catalog, _profile(["wick_ledger"]))["id"]),
		"l1", "an unfound early thing keeps its lead open")


func test_case_closes_when_everything_is_found() -> void:
	var all_ids: Array = []
	for entry in _catalog().cases[CASE_ID]["evidence"]:
		all_ids.append(entry["id"])
	assert_true(CaseState.next_lead(_catalog(), _profile(all_ids)).is_empty(),
		"nothing left to pull")


# -------------------------------------------------------------------- recap

func test_recap_is_silent_until_there_is_something_to_remember() -> void:
	assert_eq(CaseState.recap_lines(_catalog(), _profile()).size(), 0,
		"a card that says 'you have done nothing' is worse than no card")


func test_recap_names_the_last_find_and_the_next_pull() -> void:
	var catalog := _catalog()
	var lines := CaseState.recap_lines(catalog, _profile(["candle_stub"]))
	assert_eq(lines.size(), 3, "last find, tally, next lead")
	assert_true(lines[0].contains("The Sealed Stub"), "opens on the last thing found")
	assert_true(lines[1].contains("1 of 5"), "counts the board")
	assert_eq(lines[2], String(CaseState.next_lead(catalog,
		_profile(["candle_stub"]))["recap_line"]),
		"and closes on the next lead's recap line, not its longer board card")
	# The story screen retires narration that overflows its text budget, so a
	# recap that grows past three short lines silently loses its headline.
	for line in lines:
		assert_true(line.length() <= Catalog.RECAP_LINE_MAX,
			"recap lines stay short enough to survive the story budget: %s" % line)


# ----------------------------------------------------------------- standing

func test_standing_notice_fires_on_the_crossing_only() -> void:
	var catalog := _catalog()
	var profile := _profile()
	assert_eq(CaseState.apply_standing(catalog, profile, {"chandlers": -1}).size(), 0,
		"-1 has crossed nothing yet")
	var crossed := CaseState.apply_standing(catalog, profile, {"chandlers": -1})
	assert_eq(crossed.size(), 1, "-2 crosses the Chandlers' first notice")
	assert_eq(CaseState.apply_standing(catalog, profile, {"chandlers": -1}).size(), 0,
		"-3 fires nothing again: notices are crossings, not states")
	assert_eq(CaseState.standing_of(profile, "chandlers"), -3, "the number still tracks")


func test_standing_notices_fire_in_the_direction_they_sit() -> void:
	var catalog := _catalog()
	var profile := _profile()
	var up := CaseState.apply_standing(catalog, profile, {"lamplighters": 2})
	assert_eq(up.size(), 1, "a +2 line fires on the way up")
	var down := CaseState.apply_standing(catalog, profile, {"lamplighters": -4})
	assert_eq(down.size(), 1, "and the -2 line on the way down")


func test_standing_line_reports_the_loudest_true_thing() -> void:
	var catalog := _catalog()
	assert_eq(CaseState.standing_line(catalog, _profile(), "chandlers"),
		String(catalog.guilds["chandlers"]["neutral_line"]),
		"neutral until they have a reason")
	var line := CaseState.standing_line(catalog, _profile([], {"chandlers": -7}),
		"chandlers")
	assert_true(line.contains("wherever you stand"),
		"the furthest-from-neutral satisfied notice wins, got: %s" % line)


# ------------------------------------------------------------------- favors

func test_favor_knots_are_tied_once_and_untied_when_spent() -> void:
	var profile := _profile()
	assert_true(CaseState.grant_favor(profile, "lamplighters_knot"), "tied")
	assert_true(not CaseState.grant_favor(profile, "lamplighters_knot"),
		"a knot is not tied twice")
	assert_true(CaseState.spend_favor(profile, "lamplighters_knot"), "spent")
	assert_true(not CaseState.has_favor(profile, "lamplighters_knot"),
		"settled debts stop being useful (world-bible)")
	assert_true(not CaseState.spend_favor(profile, "lamplighters_knot"),
		"and cannot be spent twice")


func test_held_favors_resolve_against_the_catalog() -> void:
	var held := CaseState.held_favors(_catalog(),
		_profile([], {}, ["lamplighters_knot", "a_knot_that_was_cut_from_the_game"]))
	assert_eq(held.size(), 1, "an id the catalog lost must not crash the board")
	assert_eq(String(held[0]["id"]), "lamplighters_knot", "the real one survives")


# --------------------------------------------------------------- quest gate

func _gated_catalog() -> Catalog:
	return Catalog.new({"quests": {
		"core_lead": {"id": "core_lead", "kind": "core", "once": true, "requires": {}},
		"needs_thing": {"id": "needs_thing", "kind": "side",
			"requires": {"evidence": ["candle_stub"]}},
		"needs_friends": {"id": "needs_friends", "kind": "side",
			"requires": {"standing": {"lamplighters": 2}}},
		"needs_choice": {"id": "needs_choice", "kind": "side",
			"requires": {"flags": {"vole_mercy": 1}}},
	}})


func test_quest_gates_read_evidence_standing_and_flags() -> void:
	var catalog := _gated_catalog()
	var profile := _profile()
	var open_ids: Array[String] = []
	for quest: Dictionary in QuestGate.board(catalog, profile):
		open_ids.append(String(quest["id"]))
	assert_eq(open_ids, ["core_lead"] as Array[String],
		"only the ungated quest is on a fresh board, got %s" % str(open_ids))
	assert_true(QuestGate.is_available(catalog.quests["needs_thing"],
		_profile(["candle_stub"])), "evidence opens its quest")
	assert_true(QuestGate.is_available(catalog.quests["needs_friends"],
		_profile([], {"lamplighters": 2})), "standing opens its quest")
	assert_true(not QuestGate.is_available(catalog.quests["needs_friends"],
		_profile([], {"lamplighters": 1})), "standing below the bar does not")
	var flagged := _profile()
	flagged["flags"]["vole_mercy"] = 1
	assert_true(QuestGate.is_available(catalog.quests["needs_choice"], flagged),
		"a past choice opens its quest")


func test_once_quests_leave_the_board_when_done() -> void:
	var catalog := _gated_catalog()
	var profile := _profile()
	assert_true(QuestGate.mark_done(profile, "core_lead"), "recorded")
	assert_true(not QuestGate.mark_done(profile, "core_lead"), "recorded once")
	assert_true(not QuestGate.is_available(catalog.quests["core_lead"], profile),
		"a `once` quest does not come back")


func test_board_puts_the_case_before_the_odd_jobs() -> void:
	var profile := _profile(["candle_stub"], {"lamplighters": 2})
	profile["flags"]["vole_mercy"] = 1
	var board := QuestGate.board(_gated_catalog(), profile)
	assert_eq(board.size(), 4, "everything is open now")
	assert_eq(String(board[0]["kind"]), "core", "core leads read first")


# ---------------------------------------------------------------- migration

func test_migration_gives_old_saves_the_chapter_spine() -> void:
	var merged := SaveService._migrate({
		"schema_version": 2, "prologue_done": true, "gleam": 30,
	})
	assert_eq(int(merged["schema_version"]), 3, "schema version bumped")
	assert_eq(String(merged["case"]["active"]), "wax_and_wick",
		"a finished prologue implies the case is open (law 7)")
	assert_eq(merged["case"]["evidence"], [] as Array, "with nothing proved yet")
	assert_true(merged.has("standing") and merged.has("favors")
		and merged.has("quests_done"), "and the rest of the spine's keys")
	assert_eq(int(merged["gleam"]), 30, "without disturbing what was there")


func test_migration_repairs_an_emptied_case_pointer() -> void:
	var merged := SaveService._migrate({
		"schema_version": 3, "prologue_done": true,
		"case": {"active": "", "evidence": [], "leads_done": []},
	})
	assert_eq(String(merged["case"]["active"]), "wax_and_wick",
		"no active case would mean a Case Board that never opens again")
