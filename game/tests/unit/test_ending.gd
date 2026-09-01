extends TestCase
## The chapter close: a case counts as CLOSED exactly when it exists, has
## leads, and every one of them is satisfied (CaseState.case_closed). That is
## the one condition the Mantel reads to show the one-time ending card and to
## relabel its empty board (mantel.board_closed). Scene-free on purpose: the
## detection is core, so a bug here fails in a test run, not in a parlor.


func _catalog() -> Catalog:
	return DataLoader.load_catalog()


## A profile holding every piece of evidence the active case can yield —
## including each lead's own evidence, so no lead is left to pull.
func _profile_with_everything(catalog: Catalog) -> Dictionary:
	var profile := SaveService.DEFAULT_PROFILE.duplicate(true)
	var case_def := CaseState.active_case(catalog, profile)
	for entry in case_def.get("evidence", []):
		CaseState.add_evidence(profile, String(entry["id"]))
	for lead in case_def.get("leads", []):
		CaseState.add_evidence(profile, String(lead.get("evidence", "")))
	return profile


func test_fresh_profile_is_not_closed() -> void:
	var catalog := _catalog()
	var profile := SaveService.DEFAULT_PROFILE.duplicate(true)
	assert_true(not CaseState.next_lead(catalog, profile).is_empty(),
		"a fresh Chapter 1 profile has a lead to pull")
	assert_true(not CaseState.case_closed(catalog, profile),
		"a case with leads left is open")


func test_all_evidence_closes_the_case() -> void:
	var catalog := _catalog()
	var profile := _profile_with_everything(catalog)
	assert_true(CaseState.next_lead(catalog, profile).is_empty(),
		"no lead is left once every evidence is held")
	assert_true(CaseState.case_closed(catalog, profile),
		"the case reads as closed")


func test_no_active_case_is_not_closed() -> void:
	var catalog := _catalog()
	var profile := SaveService.DEFAULT_PROFILE.duplicate(true)
	profile["case"]["active"] = ""
	assert_true(not CaseState.case_closed(catalog, profile),
		"a board that never opened is not a board that closed")


func test_default_profile_has_not_seen_the_ending() -> void:
	# The hub shows the card only when ending_seen is false AND the case is
	# closed; the profile default must start on the showing side of the gate.
	assert_true(SaveService.DEFAULT_PROFILE.has("ending_seen"),
		"the profile carries the ending_seen key (law 14)")
	assert_eq(bool(SaveService.DEFAULT_PROFILE["ending_seen"]), false,
		"a fresh profile has an ending still owed to it")
