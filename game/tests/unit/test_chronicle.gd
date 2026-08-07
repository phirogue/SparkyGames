extends TestCase
## The chronicle: what the player has done, stored as facts.
##
## The old journal was an array of finished sentences, which could not be
## re-rendered, filtered, counted or turned back into the state it described —
## and which meant player-facing prose was being written inside .gd files.
## These tests hold the line on all of that.


func _catalog() -> Catalog:
	return DataLoader.load_catalog()


# --------------------------------------------------------------- the contract

## Every kind must have a sentence, and every sentence must have a kind. A kind
## with no template renders as a missing-key placeholder in the Casebook; a
## template with no kind is a line somebody wrote that nothing will ever show.
func test_every_kind_has_a_template_and_back() -> void:
	for kind in Chronicle.KINDS:
		var line := Strings.line("chronicle_log." + String(kind))
		assert_true(not line.is_empty(),
			"kind '%s' has a sentence in story/interface.json" % kind)
	var templates: Dictionary = Strings.section("chronicle_log")
	for key in templates:
		if String(key).begins_with("_"):
			continue
		assert_true(Chronicle.KINDS.has(String(key)),
			"story/interface.json writes 'chronicle_log.%s', which no event kind produces"
				% key)


## Placeholders are filled positionally, so a template whose count disagrees
## with its kind's declared fields renders a mangled sentence.
func test_every_template_takes_the_arguments_its_kind_supplies() -> void:
	for kind in Chronicle.KINDS:
		var spec: Dictionary = Chronicle.KINDS[kind]
		var expected: int = (Array(spec.get("ids", [])).size()
			+ Array(spec.get("texts", [])).size()
			+ Array(spec.get("nums", [])).size())
		var line := Strings.line("chronicle_log." + String(kind))
		var placeholders := line.count("%s") + line.count("%d")
		assert_eq(placeholders, expected,
			"chronicle_log.%s takes %d placeholders but the kind supplies %d"
				% [kind, placeholders, expected])


func test_an_unknown_kind_is_refused() -> void:
	var chronicle := Chronicle.new()
	chronicle.record("something_that_never_happened")
	assert_eq(chronicle.events.size(), 0, "an unknown kind records nothing")


# ------------------------------------------------------------------ behaviour

func test_events_record_facts_not_sentences() -> void:
	var chronicle := Chronicle.new()
	chronicle.record("life_spent", {"enemy": "the_vole"})
	assert_eq(chronicle.events.size(), 1, "one event")
	var event: Dictionary = chronicle.events[0]
	assert_eq(String(event["kind"]), "life_spent", "the kind is stored")
	assert_eq(String(event["ids"]["enemy"]), "the_vole", "the id is stored")
	# The point of the whole exercise: no prose in the save file.
	assert_true(not JSON.stringify(event).to_lower().contains("court"),
		"the sentence is NOT stored — only the fact")


func test_the_casebook_renders_names_from_the_catalog() -> void:
	var catalog := _catalog()
	var enemy_id := String(catalog.enemies.keys()[0])
	var chronicle := Chronicle.new()
	chronicle.record("life_spent", {"enemy": enemy_id})
	var described := chronicle.describe(catalog)
	assert_eq(described.size(), 1, "one line to render")
	assert_eq(String(described[0]["key"]), "chronicle_log.life_spent", "the right template")
	assert_eq(String(described[0]["args"][0]),
		String(catalog.enemies[enemy_id]["name"]),
		"the id is resolved to the name a player reads")


## Renaming a quest must re-read the whole history. This is the capability the
## prose journal could never have.
func test_renaming_content_re_reads_past_entries() -> void:
	var catalog := _catalog()
	var quest_id := String(catalog.quests.keys()[0])
	var chronicle := Chronicle.new()
	chronicle.record("quest_done", {"quest": quest_id}, {"gleam": 12})
	catalog.quests[quest_id]["name"] = "A Different Name Entirely"
	assert_eq(String(chronicle.describe(catalog)[0]["args"][0]),
		"A Different Name Entirely",
		"a past entry picks up the new name with no migration")


func test_the_casebook_reads_newest_first() -> void:
	var chronicle := Chronicle.new()
	chronicle.record("prologue_done")
	chronicle.record("choice_made", {}, {}, {"choice": "the second thing"})
	var described := chronicle.describe(_catalog())
	assert_eq(String(described[0]["kind"]), "choice_made", "newest line first")


func test_events_can_be_counted_and_filtered() -> void:
	var chronicle := Chronicle.new()
	chronicle.record("life_spent", {"enemy": "the_vole"})
	chronicle.record("prologue_done")
	chronicle.record("life_spent", {"enemy": "the_vole"})
	assert_eq(chronicle.count("life_spent"), 2, "counting works")
	assert_eq(chronicle.of_kind("life_spent").size(), 2, "filtering works")
	assert_eq(String(chronicle.last_of("prologue_done").get("kind", "")),
		"prologue_done", "the last of a kind is findable")


func test_an_unknown_id_falls_back_to_the_id() -> void:
	var chronicle := Chronicle.new()
	chronicle.record("life_spent", {"enemy": "a_creature_that_was_cut"})
	var args: Array = chronicle.describe(_catalog())[0]["args"]
	assert_eq(String(args[0]), "a_creature_that_was_cut",
		"a dropped id renders as itself, not as an empty gap in the page")


func test_the_log_is_capped_and_drops_the_oldest() -> void:
	var chronicle := Chronicle.new()
	for i in Chronicle.LIMIT + 20:
		chronicle.record("prologue_done")
	assert_eq(chronicle.events.size(), Chronicle.LIMIT, "the log is capped")
	assert_true(int(chronicle.events[0]["seq"]) > 1,
		"the OLDEST entries are the ones dropped — recent history is what a "
		+ "player is trying to remember")


func test_a_chronicle_survives_a_save_round_trip() -> void:
	var chronicle := Chronicle.new()
	chronicle.record("quest_done", {"quest": "night_rounds"}, {"gleam": 30})
	chronicle.record("prologue_done")
	var reloaded := Chronicle.from_list(
		JSON.parse_string(JSON.stringify(chronicle.to_list())))
	assert_eq(reloaded.events.size(), 2, "both events come back")
	assert_eq(String(reloaded.events[0]["ids"]["quest"]), "night_rounds", "ids survive")
	# Sequence must keep climbing, or a later event sorts under an earlier one.
	reloaded.record("prologue_done")
	assert_true(int(reloaded.events[2]["seq"]) > int(reloaded.events[1]["seq"]),
		"sequence numbers continue after a reload")


func test_a_corrupt_entry_loses_one_line_not_the_history() -> void:
	var reloaded := Chronicle.from_list([
		{"seq": 1, "kind": "prologue_done"},
		{"nonsense": true},
		{"seq": 3, "kind": "life_spent", "ids": {"enemy": "the_vole"}},
	])
	assert_eq(reloaded.events.size(), 2, "the good entries survive a bad one")


# ------------------------------------------------------- migration & warm start

## Law 7: what does an old save IMPLY? Its prose lines cannot be turned back
## into facts, so they are kept and shown rather than guessed at.
func test_v4_saves_keep_their_prose_and_gain_a_chronicle() -> void:
	var merged := SaveService._migrate({
		"schema_version": 4, "prologue_done": true,
		"journal": ["Found: a thing", "Chose: the left door"],
	})
	assert_eq(int(merged["schema_version"]), 5, "migrated to v5")
	assert_eq(Array(merged["journal"]).size(), 2,
		"the old lines are kept — a player's history is theirs")
	assert_eq(Chronicle.from_list(merged["chronicle"]).count("prologue_done"), 1,
		"a finished prologue seeds the one event it certainly implies")


func test_an_unfinished_save_gets_an_empty_chronicle() -> void:
	var merged := SaveService._migrate({"schema_version": 4, "prologue_done": false})
	assert_eq(Array(merged["chronicle"]).size(), 0,
		"nothing is invented for a player who has not got there yet")


## The warm start: whatever is happening now, written out as a spec that
## reproduces it. Only the DIFFERENCES from the defaults are written, so the
## spec stays readable and does not freeze the starting kit of the day it was
## made.
func test_a_live_state_exports_as_a_scenario() -> void:
	var profile := SaveService.DEFAULT_PROFILE.duplicate(true)
	profile["gleam"] = 44
	profile["prologue_done"] = true
	profile["chronicle"] = [{"seq": 1, "kind": "prologue_done"}]
	var spec := SaveService.to_scenario(profile, {"hp": 3}, "battle:prologue_vole",
		"one hit from the Court")
	assert_eq(int(spec["profile"]["gleam"]), 44, "what changed is written")
	assert_true(spec["profile"]["prologue_done"], "and so is this")
	assert_true(not spec["profile"].has("max_hp"),
		"what did NOT change is left out, so the spec survives a defaults change")
	assert_true(not spec["profile"].has("chronicle"),
		"a warm start wants the state, not the history that produced it")
	assert_eq(int(spec["carryover"]["hp"]), 3, "carryover comes along")
	assert_eq(String(spec["launch"]), "battle:prologue_vole", "and where to drop in")


## An exported spec must actually load back as the state it came from — the
## whole promise of the feature.
func test_an_exported_scenario_restores_the_state() -> void:
	var profile := SaveService.DEFAULT_PROFILE.duplicate(true)
	profile["gleam"] = 77
	profile["skills"] = ["scratch", "pounce", "slink"]
	profile["settings"]["lamps_low"] = true
	var spec := SaveService.to_scenario(profile)
	var restored := SaveService._deep_merge(
		SaveService.DEFAULT_PROFILE.duplicate(true), spec["profile"])
	assert_eq(int(restored["gleam"]), 77, "gleam comes back")
	assert_eq(restored["skills"], ["scratch", "pounce", "slink"] as Array, "kit comes back")
	assert_true(restored["settings"]["lamps_low"], "a nested change comes back")
	assert_true(restored["settings"].has("volume"),
		"and the settings it did NOT touch are still there")
