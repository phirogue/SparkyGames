extends TestCase
## FACTS: the durable configuration of what this Ash has seen, met and
## learned (core/prowl_script.gd, profile.facts). A story step records facts
## with `sets` the moment it is shown; any step may gate on them with
## `when_fact` — which is how a line that leans on a branch-gated event is
## PROVEN appropriate instead of remembered to be. The bug class this kills:
## "Cardew said it" quoted unconditionally when Cardew only said it on one
## branch of one quest, and Bodkin introducing himself twice.


func _catalog() -> Catalog:
	return DataLoader.load_catalog()


# ------------------------------------------------------------------ gating

func test_fact_gate_semantics() -> void:
	var facts := {"met_bodkin": 1}
	assert_true(not ProwlScript.fact_gate_blocks(
		{"when_fact": {"fact": "met_bodkin", "is": 1}}, facts),
		"'is' passes when the fact holds")
	assert_true(ProwlScript.fact_gate_blocks(
		{"when_fact": {"fact": "met_bodkin", "not": 1}}, facts),
		"'not' blocks when the fact holds")
	assert_true(ProwlScript.fact_gate_blocks(
		{"when_fact": {"fact": "met_merrow", "is": 1}}, facts),
		"'is' blocks when the fact is missing")
	assert_true(not ProwlScript.fact_gate_blocks(
		{"when_fact": {"fact": "met_merrow", "not": 1}}, facts),
		"'not' passes when the fact is missing — absence matches every not")
	assert_true(not ProwlScript.fact_gate_blocks({"lines": ["x"]}, facts),
		"steps without the key always play")


func test_fact_gate_clause_lists_must_all_hold() -> void:
	var facts := {"met_bodkin": 1}
	var both := {"when_fact": [
		{"fact": "met_bodkin", "is": 1}, {"fact": "met_merrow", "not": 1}]}
	assert_true(not ProwlScript.fact_gate_blocks(both, facts),
		"a list of clauses passes when every clause holds")
	facts["met_merrow"] = 1
	assert_true(ProwlScript.fact_gate_blocks(both, facts),
		"and blocks the moment any clause fails")


func test_fact_values_survive_the_json_float_trap() -> void:
	# Godot's JSON parser returns every number as a float (CLAUDE.md trap
	# 26): a fact set from file arrives as 1.0 and a gate comparing with ==
	# against int 1 would never match.
	var facts := ProwlScript.facts_set_by({"sets": {"met_bodkin": 1.0}})
	assert_eq(int(facts["met_bodkin"]), 1, "sets coerces to int")
	assert_true(not ProwlScript.fact_gate_blocks(
		{"when_fact": {"fact": "met_bodkin", "is": 1.0}}, facts),
		"and a float clause value still matches")


# -------------------------------------------------------------- derivation

func _quests_for_derive() -> Dictionary:
	return {
		"first_meeting": {"steps": [
			{"type": "story", "lines": ["hello"],
				"when_fact": {"fact": "met_x", "not": 1}},
			{"type": "story", "lines": ["you again"],
				"when_fact": {"fact": "met_x", "is": 1}, "sets": {"seen_twice": 1}},
			{"type": "story", "lines": ["name given"],
				"when_fact": {"fact": "met_x", "not": 1}, "sets": {"met_x": 1}},
		]},
		"branchy": {"steps": [
			{"type": "story", "lines": ["a"],
				"when_flag": {"flag": "route", "value": 0}, "sets": {"took_a": 1}},
			{"type": "story", "lines": ["b"],
				"when_flag": {"flag": "route", "value": 1}, "sets": {"took_b": 1}},
			{"type": "story", "lines": ["puzzle"],
				"when_minigame": "success", "sets": {"solved": 1}},
			{"type": "story", "lines": ["again"],
				"when_attempt": "retry", "sets": {"retried": 1}},
		]},
	}


func test_derive_replays_what_a_done_quest_actually_showed() -> void:
	# Law 7: an old save merges to facts = {}, and every "have we met?"
	# would answer no to characters the player has known for chapters.
	var derived := ProwlScript.derive_facts(_quests_for_derive(),
		["first_meeting", "branchy"], {"route": 1})
	assert_eq(int(derived.get("met_x", 0)), 1,
		"the first-meeting chain derives: its 'not met' gate passed on first play")
	assert_true(not derived.has("seen_twice"),
		"the returning-player variant does not derive — it never showed first time")
	assert_true(not derived.has("took_a"), "the branch the flags refute is skipped")
	assert_eq(int(derived.get("took_b", 0)), 1, "the branch the flags confirm applies")
	assert_true(not derived.has("solved"),
		"minigame-gated sets never derive — that outcome is unknowable after the fact")
	assert_true(not derived.has("retried"), "retry-only beats never derive")
	assert_true(ProwlScript.derive_facts(
		_quests_for_derive(), ["nonexistent"], {}).is_empty(),
		"unknown quest ids derive nothing rather than crashing")


func test_sanitize_drops_hostile_values() -> void:
	# Saves are player-owned files. A hand-edited facts dict can hold
	# anything; only numeric values may survive to be gated on.
	var junk: Variant = {"met_bodkin": "yes", "knows_eleven": {"a": 1},
		"heard_cardew_again": null, "ok_float": 2.0, "ok_int": 1, "": 5}
	var clean := ProwlScript.sanitize_facts(junk)
	assert_eq(clean.size(), 2, "only the numeric, named facts survive: %s" % str(clean))
	assert_eq(int(clean["ok_float"]), 2, "floats coerce to int")
	assert_eq(int(clean["ok_int"]), 1, "ints pass through")
	assert_eq(ProwlScript.sanitize_facts(clean), clean, "sanitize is idempotent")
	assert_true(ProwlScript.sanitize_facts("not even a dict").is_empty(),
		"a non-dict facts blob becomes empty rather than crashing")


func test_derive_is_stable_for_shipped_content_in_any_done_order() -> void:
	# Scenario specs and hostile saves can put quests_done in any order the
	# requires-graph forbids. The validator bans cross-quest fact-gated
	# setters precisely so this cannot matter; hold it as an invariant.
	var catalog := _catalog()
	var done: Array = catalog.quests.keys()
	var flags := {"carrying_answer": 2, "lamp_approach": 1, "wick_verdict": 0,
		"prologue_route": 0}
	var forward := ProwlScript.derive_facts(catalog.quests, done, flags)
	var backward_done := done.duplicate()
	backward_done.reverse()
	var backward := ProwlScript.derive_facts(catalog.quests, backward_done, flags)
	assert_true(forward == backward,
		"derivation must not depend on quests_done order: %s vs %s"
		% [str(forward), str(backward)])
	assert_eq(int(forward.get("met_bodkin", 0)), 1,
		"a completed creditors always derives the Bodkin meeting")
	assert_eq(int(forward.get("heard_cardew_learned", 0)), 1,
		"the branch the flags confirm derives")
	assert_true(not forward.has("heard_cardew_again"),
		"and the branch the flags refute does not")


# -------------------------------------------------------------- validation

func test_validation_catches_malformed_fact_gates() -> void:
	var bad := Catalog.new({"quests": {"q": {
		"id": "q", "name": "Q", "kind": "side", "district": "thimblefield",
		"board_card": "c", "steps": [
			{"type": "battle", "encounter": "nope",
				"when_fact": {"fact": "met_x", "is": 1}},
			{"type": "story", "lines": ["x"],
				"when_fact": {"fact": "", "is": 1}},
			{"type": "story", "lines": ["x"],
				"when_fact": {"fact": "met_x", "is": 1, "not": 1}},
			{"type": "story", "lines": ["x"],
				"when_fact": {"fact": "met_x"}},
			{"type": "story", "lines": ["x"], "sets": {"": 1}},
			{"type": "story", "lines": ["x"], "sets": {"y": "gouda"}},
		]}}})
	var joined := "\n".join(bad.validate())
	assert_true(joined.contains("only story beats read facts"),
		"a fact key on a battle step is flagged: %s" % joined)
	assert_true(joined.contains("nameless fact"), "nameless facts are flagged")
	assert_true(joined.contains("exactly one of is/not"),
		"a clause needs exactly one operator, not zero and not two")
	assert_true(joined.contains("non-integer"), "fact values are ints only")


func test_validation_catches_underivable_and_trap_setters() -> void:
	var bad := Catalog.new({"quests": {"q": {
		"id": "q", "name": "Q", "kind": "side", "district": "thimblefield",
		"board_card": "c", "steps": [
			{"type": "story", "lines": ["x"], "sets": {"y": 0}},
			{"type": "story", "lines": ["x"], "when_minigame": "success",
				"sets": {"y": 1}},
			{"type": "story", "lines": ["x"], "when_attempt": "retry",
				"sets": {"y": 1}},
		]},
		"other": {"id": "other", "name": "O", "kind": "side",
			"district": "thimblefield", "board_card": "c", "steps": [
			{"type": "story", "lines": ["x"], "sets": {"foreign": 1}},
			{"type": "story", "lines": ["x"], "sets": {"z": 1},
				"when_fact": {"fact": "y", "is": 1}},
		]}}})
	var joined := "\n".join(bad.validate())
	assert_true(joined.contains("gate differently; use absence"),
		"a fact set to 0 is rejected — absent and 0 gate differently")
	assert_true(joined.contains("behind a minigame gate"),
		"sets behind a minigame gate cannot derive and is rejected")
	assert_true(joined.contains("retry-only beat"),
		"sets on a retry-only beat cannot derive and is rejected")
	assert_true(joined.contains("foreign fact"),
		"a setter gated on another quest's fact is order-sensitive and rejected")


func test_scenario_specs_author_only_real_facts() -> void:
	# A scenario with a typo'd or impossible fact photographs a state no
	# player can reach — and someone then fixes prose against it.
	var catalog := _catalog()
	var set_names := {}
	for quest_id in catalog.quests:
		for step: Dictionary in ProwlScript.steps_of(catalog.quests[quest_id]):
			for key in step.get("sets", {}):
				set_names[String(key)] = true
	var dir := DirAccess.open("res://tests/scenarios")
	assert_true(dir != null, "tests/scenarios must be readable")
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var file := FileAccess.open("res://tests/scenarios/" + file_name, FileAccess.READ)
		var spec: Variant = null if file == null else JSON.parse_string(file.get_as_text())
		if not (spec is Dictionary):
			continue
		var facts: Dictionary = Dictionary(spec.get("profile", {})).get("facts", {})
		for key in facts:
			assert_true(set_names.has(String(key)),
				"%s authors fact '%s', which no content sets" % [file_name, key])


func test_validation_catches_facts_nothing_ever_sets() -> void:
	# A typo'd gate never opens (or never closes) and reads as missing
	# prose, not as an error — so it must fail at boot instead.
	var bad := Catalog.new({"quests": {"q": {
		"id": "q", "name": "Q", "kind": "side", "district": "thimblefield",
		"board_card": "c", "steps": [
			{"type": "story", "lines": ["x"],
				"when_fact": {"fact": "met_bodkinn", "is": 1}},
		]}}})
	assert_true("\n".join(bad.validate()).contains("which nothing ever sets"),
		"a gate on an unset fact is a boot-time problem")


# ------------------------------------------------------- shipped contract

## Every "is"-gated beat needs a way for every player to get SOMETHING: the
## quest must either set that fact itself (the first-meeting pattern — the
## variant is a bonus for returning players) or carry a "not" twin of the
## same fact and value (the two-variant pattern). An "is" gate with neither
## is a beat some players silently never see, which reads as a missing page.
func test_is_gates_have_a_complement_or_a_setter() -> void:
	var catalog := _catalog()
	for quest_id in catalog.quests:
		var sets_here := {}
		var not_gates := {}
		var steps := ProwlScript.steps_of(catalog.quests[quest_id])
		for step: Dictionary in steps:
			for key in step.get("sets", {}):
				sets_here["%s=%d" % [String(key), int(step["sets"][key])]] = true
			for clause in _clauses_of(step):
				if clause.has("not"):
					not_gates["%s=%d" % [String(clause.get("fact", "")),
						int(clause["not"])]] = true
		for step: Dictionary in steps:
			for clause in _clauses_of(step):
				if not clause.has("is"):
					continue
				var key := "%s=%d" % [String(clause.get("fact", "")), int(clause["is"])]
				assert_true(sets_here.has(key) or not_gates.has(key),
					"'%s' gates a beat on %s with no complement and no setter — some players silently get nothing" % [quest_id, key])


func _clauses_of(step: Dictionary) -> Array:
	if not step.has("when_fact"):
		return []
	if step["when_fact"] is Array:
		return Array(step["when_fact"])
	return [step["when_fact"]]
