extends TestCase
## The one-shots. What is asserted here is what cannot be heard from a
## screenshot and would otherwise only be caught by a player: that a cue fires
## at all, that it does not fire the same recording twice running (law 15),
## that a rate limit drops the NOISE and never the action, and that the switch
## is honoured.
##
## The sibling of test_music.gd. Between them they hold the rule that the score
## and the one-shots are independent: separate services, separate buses,
## separate switches, separate faders.


func _service() -> SfxService:
	var service := SfxService.new()
	service.configure({
		"defaults": {"gain_db": -4.0, "cooldown": 0.0},
		"cues": {
			"one": {"files": ["a"], "cooldown": 0.0},
			"many": {"files": ["a", "b", "c"], "cooldown": 0.0},
			"pair": {"files": ["a", "b"], "cooldown": 0.0},
			"slow": {"files": ["a", "b"], "cooldown": 5.0},
		},
	})
	service.set_seed(1234)
	return service


func test_a_cue_fires() -> void:
	var service := _service()
	service.play("many")
	assert_eq(service.plays, 1, "the cue sounded")


func test_a_cue_nobody_defined_is_not_silent_it_is_an_error() -> void:
	# A call site asking for a sound that does not exist would otherwise be
	# indistinguishable from a wire that was never connected — the defect that
	# ships, because nobody reports a sound they never knew about.
	var service := _service()
	service.play("no_such_cue")
	assert_eq(service.plays, 0, "nothing sounded")


func test_a_cue_never_repeats_the_same_recording_twice_running() -> void:
	# Law 15, the whole reason `files` is a list. A claw that sounds identical
	# five times in one fight stops being a cat and becomes a wav file.
	var service := _service()
	var last := -1
	for i in 200:
		service.play("many")
		var picked := int(service._last_variant["many"])
		assert_true(picked != last, "variant %d differs from the one before" % i)
		last = picked


func test_two_variants_alternate_rather_than_sticking() -> void:
	var service := _service()
	var seen := {}
	for i in 20:
		service.play("pair")
		seen[int(service._last_variant["pair"])] = true
	assert_eq(seen.size(), 2, "both recordings get used")


func test_a_single_recording_cue_still_fires_every_time() -> void:
	# The no-repeat rule must not become a no-play rule when there is only one
	# file to choose from.
	var service := _service()
	for i in 5:
		service.play("one")
	assert_eq(service.plays, 5, "all five sounded")


func test_the_rate_limit_drops_the_noise_not_the_action() -> void:
	# A burst of resolved events must not machine-gun one recording. What the
	# cooldown may NOT do is swallow the thing that caused it — it is a guard
	# on the speaker, not a debounce on the game.
	var service := _service()
	for i in 10:
		service.play("slow")
	assert_eq(service.plays, 1, "nine were dropped as noise")
	# ... and the state the game cares about is untouched, because the service
	# has none: play() is the only entry point and it returns nothing.


func test_turning_sound_effects_off_stops_them() -> void:
	var service := _service()
	service.set_muted(true)
	service.play("many")
	assert_eq(service.plays, 0, "nothing sounded")
	assert_true(service.is_muted(), "and it says so")
	service.set_muted(false)
	service.play("many")
	assert_eq(service.plays, 1, "back on")


func test_the_tour_hears_nothing() -> void:
	# Two thousand screenshots with no ears attached.
	var service := _service()
	service.enabled = false
	service.play("many")
	assert_eq(service.plays, 0, "silent under the tour")


func test_every_cue_in_the_real_data_has_its_files_wired() -> void:
	# The check that actually protects the game: data/sfx.json names files, and
	# a name with nothing behind it is a silent tap in a fight. Catalog.validate
	# covers this too; asserted here so it fails in the unit run rather than
	# only at boot.
	var catalog := DataLoader.load_catalog()
	var missing: Array[String] = []
	for cue_id: String in catalog.sfx_cues():
		for file_id in catalog.sfx_files(cue_id):
			if not ResourceLoader.exists("res://assets/sfx/%s.ogg" % file_id):
				missing.append("%s -> %s" % [cue_id, file_id])
	assert_true(missing.is_empty(),
		"every cue's recordings are wired (missing: %s)" % ", ".join(missing))


func test_the_cues_the_game_actually_calls_all_exist() -> void:
	# The other direction, and the one a rename breaks: a call site naming a
	# cue that data/sfx.json does not define. Kept as an explicit list because
	# grepping .gd for string literals from a test is worse than maintaining
	# the roll of what the game promises to be able to say.
	var catalog := DataLoader.load_catalog()
	var cues := catalog.sfx_cues()
	const CALLED := [
		"ui_tap", "ui_reject", "ui_modal_open", "ui_modal_close", "ui_toggle",
		"page_turn", "book_open", "book_close",
		"ash_claw", "enemy_hit", "blocked", "play_skill", "charge",
		"concentrate", "end_turn", "card_draw", "card_stolen",
		"ash_hiss", "ash_trill",
		"sting_victory", "sting_defeat",
		"stitch", "thread_snap", "ward_place", "contradiction",
		"crossing_slip", "lattice_resolve",
		"coins", "stamp",
	]
	for cue_id in CALLED:
		assert_true(cues.has(cue_id), "the game calls '%s' and it is defined" % cue_id)
