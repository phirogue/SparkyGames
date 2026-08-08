extends TestCase
## The prologue script itself, checked as CONTENT.
##
## Three rounds of the owner's defect lists have been wiring rather than
## code: a fight set in an environment its story had already left, a coach
## step pointing at a skill that fight did not carry, a beat that dealt
## Shadow out of a deck holding none. None of that is visible in a diff and
## all of it is visible in ten seconds of play, which is the worst possible
## place to find it. So the script is validated the way data/*.json is.

const BattleScreen := preload("res://scenes/battle.gd")

## The prologue is assembled from story/prologue/ (an index plus one file per
## arc). Tests load it the way the game does, through StoryLoader, so a split
## that assembles wrongly fails here rather than on somebody's phone.
const STORY_DIR := "res://story/prologue"

## Coach target keys the battle screen knows how to resolve. "skill:<id>" is
## handled separately because the id half is checked against the catalog.
const COACH_KEYS := [
	"", "approach", "use", "charge", "banner", "rule", "portrait", "thread",
	"intent", "chronicle", "status", "paws", "concentrate", "end_turn",
	"slip", "hand", "hp", "guard", "deck",
]


func _story() -> Dictionary:
	return StoryLoader.load_prologue(STORY_DIR)


func _lines_of(scene: Dictionary) -> Array:
	return scene.get("lines", [])


func test_prologue_parses_and_every_scene_has_a_known_type() -> void:
	var story := _story()
	assert_true(not story.is_empty(),
		"story/prologue/ must assemble — check index.json and every arc it names")
	var known := ["story", "notice", "battle", "title", "hollow_court_if_died",
		"flashback", "favor_redeem"]
	for scene in story.get("scenes", []):
		assert_true(known.has(String(scene.get("type", ""))),
			"unknown scene type '%s'" % scene.get("type", ""))


func test_every_id_the_prologue_names_exists() -> void:
	var catalog := DataLoader.load_catalog()
	var story := _story()
	for scene in story.get("scenes", []):
		if scene.has("environment"):
			assert_true(catalog.environments.has(scene["environment"]),
				"unknown environment '%s'" % scene["environment"])
		if scene.has("encounter"):
			assert_true(catalog.encounters.has(scene["encounter"]),
				"unknown encounter '%s'" % scene["encounter"])
		for skill_id in Array(scene.get("grant", [])) + Array(scene.get("skills", [])):
			assert_true(catalog.skills.has(skill_id),
				"unknown skill '%s'" % skill_id)
		var cards: Array = Array(scene.get("deck", [])) \
			+ Array(scene.get("add_cards", [])) + Array(scene.get("opening_cards", []))
		if scene.has("add_card"):
			cards.append(scene["add_card"])
		for card_id in cards:
			assert_true(catalog.energy_cards.has(card_id),
				"unknown energy card '%s'" % card_id)


## Every coach step must point somewhere the battle screen can resolve, and
## a "skill:" step must name a skill THAT FIGHT actually carries — the
## rag-wraith once coached Loaf while running a loadout without it, so the
## spotlight fell on nothing.
func test_coach_steps_point_at_things_that_are_there() -> void:
	var catalog := DataLoader.load_catalog()
	for scene in _story().get("scenes", []):
		if String(scene.get("type", "")) != "battle":
			continue
		var carried: Array = Array(scene.get("skills", [])) + ["scratch"]
		for step in scene.get("coach", []):
			var target := String(step.get("target", ""))
			assert_true(not String(step.get("text", "")).is_empty(),
				"a coach step with no text is a blank bubble")
			if not target.begins_with("skill:"):
				assert_true(COACH_KEYS.has(target),
					"coach step targets unknown key '%s'" % target)
				continue
			var skill_id := target.trim_prefix("skill:")
			assert_true(catalog.skills.has(skill_id),
				"coach points at unknown skill '%s'" % skill_id)
			# A battle that pins no skills uses the profile loadout, which the
			# grants earlier in the script decide; only pinned fights can be
			# checked here, and those are the ones that got it wrong.
			if scene.has("skills"):
				assert_true(carried.has(skill_id),
					"%s coaches '%s' but does not carry it"
					% [scene["encounter"], skill_id])


## Loadout law, enforced against the script rather than remembered.
func test_no_battle_pins_more_skills_than_the_tray_holds() -> void:
	for scene in _story().get("scenes", []):
		if not scene.has("skills"):
			continue
		var carried: Array = Array(scene["skills"]).duplicate()
		if not carried.has("scratch"):
			carried.append("scratch")
		assert_true(carried.size() <= SaveService.LOADOUT_SIZE,
			"%s pins %d abilities; the tray holds %d"
			% [scene.get("encounter", "?"), carried.size(), SaveService.LOADOUT_SIZE])


## ONE deck for the whole night (owner rule): a beat may only deal energy the
## deck laid down actually contains, or the fight that teaches Moonlight
## opens on Ferocity and the lesson lands on nothing.
func test_scripted_openers_are_paid_for_by_the_one_deck() -> void:
	var supply := {}
	var demand := {}
	for scene in _story().get("scenes", []):
		for card_id in scene.get("deck", []):
			supply[card_id] = int(supply.get(card_id, 0)) + 1
		for card_id in scene.get("opening_cards", []):
			demand[card_id] = int(demand.get(card_id, 0)) + 1
	assert_true(not supply.is_empty(), "the prologue must lay down a deck")
	for card_id in demand:
		assert_true(int(demand[card_id]) <= int(supply.get(card_id, 0)),
			"beats deal %d x %s but the night's deck holds %d"
			% [demand[card_id], card_id, int(supply.get(card_id, 0))])


## Law 6: victory text after a retreat is a canon bug. Every fight the player
## can walk away from needs its outcome variants written.
func test_walk_away_fights_have_both_outcome_variants() -> void:
	var catalog := DataLoader.load_catalog()
	var scenes: Array = _story().get("scenes", [])
	for i in scenes.size():
		var scene: Dictionary = scenes[i]
		if String(scene.get("type", "")) != "battle":
			continue
		var encounter: Dictionary = catalog.encounters[scene["encounter"]]
		# A locked room has no retreat to write text for, and a scripted
		# withdrawal has no victory to write text for.
		if encounter.get("no_retreat", false) or int(encounter.get("withdraw_after", 0)) > 0:
			continue
		var outcomes := {}
		for j in range(i + 1, scenes.size()):
			if String(scenes[j].get("type", "")) == "battle":
				break
			if scenes[j].has("when_outcome"):
				outcomes[scenes[j]["when_outcome"]] = true
		if outcomes.is_empty():
			continue  # an outcome-neutral follow-up is a deliberate choice
		for wanted in ["victory", "retreat"]:
			assert_true(outcomes.has(wanted),
				"%s writes a '%s' follow-up but no '%s' one"
				% [scene["encounter"], outcomes.keys()[0], wanted])


## Rules lines are {text, rule} objects; a bare string is Ash talking. A
## malformed line would render as "{ text: ... }" on the page.
func test_narration_lines_are_strings_or_rule_objects() -> void:
	var story := _story()
	var blocks: Array = story.get("scenes", []).duplicate()
	for key in ["hollow_court_first", "hollow_court_repeat"]:
		blocks.append_array(story.get(key, []))
	for scene in blocks:
		var lines: Array = _lines_of(scene)
		for answer in scene.get("answers", []):
			lines = lines + Array(answer)
		for line in lines:
			if line is Dictionary:
				assert_true(line.has("text"),
					"a narration object must carry 'text': %s" % str(line))
			elif line is Array:
				# VERSE: a beat broken across the author's own lines, for the
				# ones that need the weight ("Her window is ahead now. /
				# Dark."). Every entry must still be text; an empty entry is a
				# deliberate blank line.
				for part in line:
					assert_true(part is String,
						"a verse line must be text: %s" % str(part))
				assert_true(Array(line).size() <= 5,
					"verse is a beat, not a page: %s" % str(line))
			else:
				assert_true(line is String, "a narration line must be text: %s" % str(line))


## The Hollow Court is played as pages now; a choice page must offer one
## answer per choice or picking the last option falls through silently.
func test_hollow_court_pages_answer_every_choice() -> void:
	var story := _story()
	for key in ["hollow_court_first", "hollow_court_repeat"]:
		var pages: Array = story.get(key, [])
		assert_true(not pages.is_empty(), "%s must have pages" % key)
		for page in pages:
			assert_true(page is Dictionary, "%s pages are objects now" % key)
			assert_true(not _lines_of(page).is_empty(), "a page with no lines")
			var choices: Array = page.get("choices", [])
			if choices.is_empty():
				continue
			assert_true(choices.size() <= 3, "max 3 choices on a story card")
			assert_eq(Array(page.get("answers", [])).size(), choices.size(),
				"%s: every choice needs its reply" % key)


## Owner rule 2026-08-04: a skill must be TAUGHT immediately before the fight
## that uses it, and taught on its own notice card rather than wedged between
## story beats. Slink used to be granted a page and a half before anything
## could be slunk, which read as the game interrupting Ash mid-sentence.
##
## "Immediately before" means: nothing but battle-less scenes between the
## notice and the next battle — and that battle must actually offer the skill.
func test_every_grant_lands_on_the_fight_that_uses_it() -> void:
	var catalog := DataLoader.load_catalog()
	var scenes: Array = _story().get("scenes", [])
	var taught := 0
	for i in scenes.size():
		var scene: Dictionary = scenes[i]
		if scene.get("grant", []).is_empty():
			continue
		assert_eq(String(scene.get("type", "")), "notice",
			"rules go on a notice card, not in narration (scene %d)" % i)
		taught += 1
		var found := false
		for j in range(i + 1, scenes.size()):
			if String(scenes[j].get("type", "")) != "battle":
				continue
			assert_eq(j, i + 1,
				"scene %d teaches %s but a story beat sits between it and the fight"
					% [i, str(scene["grant"])])
			# The fight either pins its own skill list or takes the loadout,
			# and either way the freshly taught card has to be in the tray.
			var pinned: Array = scenes[j].get("skills", [])
			for skill_id in scene["grant"]:
				assert_true(catalog.skills.has(skill_id),
					"grants an unknown skill '%s'" % skill_id)
				assert_true(pinned.is_empty() or pinned.has(skill_id),
					"scene %d teaches %s but the next fight does not carry it"
						% [i, skill_id])
			found = true
			break
		assert_true(found, "scene %d teaches a skill no later fight uses" % i)
	assert_true(taught >= 3, "the prologue teaches at least Pounce, Slink and the pair")
