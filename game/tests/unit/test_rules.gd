extends TestCase
## The tuning dials, and the one thing that keeps them honest.
##
## data/rules.json is what a designer edits. Rules.DEFAULTS is what the game
## falls back to when a key is missing, and several places still hold a `const`
## for callers that have no Catalog in hand (SaveService is static by design;
## CombatState's consts are its documented defaults).
##
## That is three copies of the same number, which is exactly the arrangement
## that drifts. These tests are the mechanism that makes drift impossible:
## change the JSON without changing the code and a test goes red, naming the
## key and both values. Nobody has to remember to propagate anything.

const BattleScreen := preload("res://scenes/battle.gd")


func _rules() -> Rules:
	return DataLoader.load_catalog().rules


func _shipped() -> Dictionary:
	var file := FileAccess.open("res://data/rules.json", FileAccess.READ)
	assert_true(file != null, "data/rules.json exists")
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert_true(parsed is Dictionary, "data/rules.json parses as an object")
	return parsed if parsed is Dictionary else {}


## Every leaf in Rules.DEFAULTS must be present in the shipped file and equal
## to it. Walked recursively so a new nested dial is covered the day it is
## added, without anyone remembering to extend this test.
func test_shipped_file_matches_the_defaults() -> void:
	_compare_branch(Rules.DEFAULTS, _shipped(), "")


func _compare_branch(defaults: Dictionary, shipped: Dictionary, path: String) -> void:
	for key in defaults:
		var here: String = String(key) if path.is_empty() else path + "." + String(key)
		if not shipped.has(key):
			assert_true(false, "rules.json is missing the dial '%s'" % here)
			continue
		if defaults[key] is Dictionary and shipped[key] is Dictionary:
			_compare_branch(defaults[key], shipped[key], here)
		else:
			assert_true(_same(shipped[key], defaults[key]),
				"rules.json and Rules.DEFAULTS disagree on '%s': file has %s, code has %s"
				% [here, shipped[key], defaults[key]])


## Value equality that survives a JSON round trip.
##
## Godot's JSON parser hands back every number as a float, so a cost written
## `12` in the file arrives as 12.0 and never strictly equals the int 12 in
## DEFAULTS — including inside nested arrays like the Magpie's shelf. Comparing
## numbers numerically is the only way this test measures what it means to.
func _same(a: Variant, b: Variant) -> bool:
	var a_num := a is int or a is float
	var b_num := b is int or b is float
	if a_num and b_num:
		return is_equal_approx(float(a), float(b))
	if a is Array and b is Array:
		var left: Array = a
		var right: Array = b
		if left.size() != right.size():
			return false
		for i in left.size():
			if not _same(left[i], right[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		var left_map: Dictionary = a
		var right_map: Dictionary = b
		if left_map.size() != right_map.size():
			return false
		for key in left_map:
			if not right_map.has(key) or not _same(left_map[key], right_map[key]):
				return false
		return true
	return a == b


## The reverse direction: a dial in the file that nothing in code knows about
## is a number the designer THINKS is live and is not. Notes keys are skipped.
func test_no_orphan_dials_in_the_file() -> void:
	_check_known(_shipped(), Rules.DEFAULTS, "")


func _check_known(shipped: Dictionary, defaults: Dictionary, path: String) -> void:
	for key in shipped:
		if String(key).begins_with("_"):
			continue  # editor notes, not dials
		var here: String = String(key) if path.is_empty() else path + "." + String(key)
		if not defaults.has(key):
			assert_true(false,
				"rules.json sets '%s', which no code reads — add it to Rules.DEFAULTS or delete it"
				% here)
			continue
		if shipped[key] is Dictionary and defaults[key] is Dictionary:
			_check_known(shipped[key], defaults[key], here)


# ------------------------------------------------- the consts that still exist

## SaveService is static (the loadout law has to be testable without a scene
## tree), so the starting kit is still a const there. It must agree with the
## dial a designer would reach for.
func test_the_starting_kit_matches_the_dials() -> void:
	var dials := _rules()
	assert_eq(int(SaveService.DEFAULT_PROFILE["max_hp"]), dials.count("start.max_hp"),
		"start.max_hp")
	assert_true(_same(SaveService.DEFAULT_PROFILE["deck"], dials.list("start.deck")),
		"start.deck")
	assert_true(_same(SaveService.DEFAULT_PROFILE["skills"], dials.list("start.skills")),
		"start.skills")
	assert_true(_same(SaveService.PROLOGUE_SKILLS as Array,
		dials.list("start.prologue_skills")), "start.prologue_skills")
	assert_true(_same(SaveService.IMPLIED_BY_PROLOGUE as Array,
		dials.list("start.lessons_implied_by_prologue")),
		"start.lessons_implied_by_prologue")


func test_combat_consts_match_the_dials() -> void:
	var dials := _rules()
	assert_eq(CombatState.HAND_LIMIT, dials.count("combat.hand_limit"), "combat.hand_limit")
	assert_eq(CombatState.DEFAULT_PAWS, dials.count("combat.paws"), "combat.paws")
	assert_eq(CombatState.OPENING_HAND, dials.count("combat.opening_hand"),
		"combat.opening_hand")
	assert_eq(CombatState.CONCENTRATE_USES, dials.count("combat.concentrate_uses"),
		"combat.concentrate_uses")
	assert_eq(CombatState.WILD_HUMOUR, dials.text("combat.wild_humour"),
		"combat.wild_humour")
	assert_eq(Catalog.LOADOUT_SIZE, dials.count("combat.loadout_size"),
		"combat.loadout_size")
	assert_eq(Catalog.RECAP_LINE_MAX, dials.count("presentation.recap_line_max"),
		"presentation.recap_line_max")
	assert_eq(CrossingState.NIGHT_PRESSES_POINT,
		dials.count("minigames.crossing.night_presses_turn"),
		"minigames.crossing.night_presses_turn")


## The skill tray used to be a fixed grid, and this test asserted it had one
## column per loadout slot. It is a FAN now (battle.gd `_refresh_skill_fan`),
## which fits whatever it is given by shrinking the step between cards — so
## overflow is structurally impossible and the old assertion has nothing left
## to guard.
##
## The risk did not disappear, it moved: raise the loadout law far enough and
## the cards overlap until there is no tappable strip of each one left. That is
## what is checked now, against the same arithmetic the fan uses.
func test_every_loadout_slot_stays_tappable_in_the_fan() -> void:
	const MIN_TAPPABLE := 44.0  # the usual floor for a finger-sized target
	var slots := _rules().count("combat.loadout_size")
	var card := BattleScreen.SKILL_CARD_SIZE.x
	var fan_width := float(UITheme.CONTENT_WIDTH)
	var step := card + 8.0
	if slots > 1:
		step = minf(step, (fan_width - card) / float(slots - 1))
	assert_true(step >= MIN_TAPPABLE,
		"at %d loadout slots the fan leaves %.0fpx of each card exposed; %.0f is the floor"
			% [slots, step, MIN_TAPPABLE])
	# And the whole fan still has to sit inside the page (law 12).
	assert_true(step * (slots - 1) + card <= fan_width + 0.5,
		"the fan of %d cards is wider than the page" % slots)


# ---------------------------------------------------------- the dials in force

## A fight must actually RUN on the dials, not merely agree with them. This is
## the test that would have caught wiring the field and then reading the const.
func test_a_battle_takes_its_limits_from_the_dials() -> void:
	var catalog := DataLoader.load_catalog()
	var state := CombatState.create(catalog, 1, {
		"player_hp": 10, "deck": ["ferocity_1", "guile_1", "shadow_1", "mysticism_1"],
		"skills": ["scratch"], "enemy": "the_vole",
		"environment": {},
	})
	assert_eq(state.hand_limit, catalog.rules.count("combat.hand_limit"),
		"the fight carries the hand limit dial")
	assert_eq(state.concentrate_left, catalog.rules.count("combat.concentrate_uses"),
		"the fight carries the concentrate dial")
	assert_eq(state.approaches.size(), catalog.rules.approaches().size(),
		"the fight carries the approach table")
	for mode in state.approaches:
		assert_true(state.approaches[mode].has("cost"),
			"approach '%s' has a price" % mode)
		assert_true(not state.approaches[mode].has("name"),
			"approach '%s' carries no name — names are writing, not rules (law 20)" % mode)


## Every approach the rules offer must have a player-facing name and blurb, or
## the chooser renders a button with a missing-key placeholder on it.
func test_every_approach_has_its_writing() -> void:
	for mode in _rules().approaches():
		assert_true(not Strings.line("battle.approach_name." + mode).is_empty(),
			"approach '%s' has a name in story/interface.json" % mode)
		assert_true(not Strings.line("battle.approach." + mode).is_empty(),
			"approach '%s' has a description in story/interface.json" % mode)


## A bad dials file must be caught by validate(), not by a division by zero
## three screens later.
func test_incoherent_dials_are_rejected() -> void:
	var broken := Rules.new({
		"combat": {"hand_limit": 0, "opening_hand": 9},
		"prowl": {"toll_rate": 4.0},
		"exchange": {"deck_floor": 999},
	})
	var problems := broken.validate()
	assert_true(problems.size() >= 4,
		"a nonsense balance file reports every problem, got %d" % problems.size())
	var joined := "\n".join(problems)
	assert_true(joined.contains("hand_limit"), "names the zero hand limit")
	assert_true(joined.contains("toll_rate"), "names the out-of-range rate")
	assert_true(joined.contains("deck_floor"), "names the impossible deck floor")


## A missing file must degrade to the shipped balance, not to an unplayable
## game. This is the whole reason DEFAULTS exists.
func test_an_empty_file_falls_back_to_shipped_balance() -> void:
	var empty := Rules.new({})
	assert_eq(empty.count("combat.hand_limit"), CombatState.HAND_LIMIT,
		"an absent dials file still yields the shipped hand limit")
	assert_true(empty.validate().is_empty(),
		"the shipped defaults are themselves coherent")


## The dials name content. A typo in a starting card id would boot the player
## with a deck one card short and no error anywhere.
func test_the_dials_only_name_content_that_exists() -> void:
	var problems := DataLoader.load_catalog().validate()
	for problem in problems:
		assert_true(not problem.begins_with("rules:"),
			"shipped dials reference real content: %s" % problem)
