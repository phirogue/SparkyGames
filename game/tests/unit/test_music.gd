extends TestCase
## The score: that every room has one, that every track named in content is a
## file on disk, and that the one behaviour the whole design rests on holds —
## asking for the track already playing does nothing.
##
## A missing bed is the quietest defect this project can ship. Nothing raises,
## nothing renders wrong, and a room that plays silence looks exactly like a
## room somebody meant to be silent. So it is checked here rather than noticed
## later.

const MUSIC_DIR := "res://assets/music/"


func _catalog() -> Catalog:
	return DataLoader.load_catalog()


func test_every_track_has_a_file_that_was_imported() -> void:
	var catalog := _catalog()
	var tracks := catalog.music_tracks()
	assert_true(not tracks.is_empty(), "data/music.json names tracks")
	for track_id in tracks:
		# ResourceLoader, not FileAccess: in an export the .ogg is packed and
		# the loose file is gone, so a FileAccess check would pass in the repo
		# and fail on a phone. This is the check that matches the shipped game.
		assert_true(ResourceLoader.exists("%s%s.ogg" % [MUSIC_DIR, track_id]),
			"music track '%s' has an imported file" % track_id)


func test_the_shipped_content_names_no_unknown_track() -> void:
	# Catalog.validate() carries the music rules; this asserts the real
	# content passes them, so a typo in environments.json fails a test rather
	# than a boot.
	for problem in _catalog().validate():
		if problem.contains("music") or problem.contains("track"):
			assert_true(false, problem)


func test_every_place_sounds_like_somewhere() -> void:
	var catalog := _catalog()
	for environment_id in catalog.environments:
		var track := catalog.music_for_environment(String(environment_id))
		assert_true(not track.is_empty(),
			"place '%s' has music" % environment_id)
		assert_true(catalog.music_tracks().has(track),
			"place '%s' names a real track" % environment_id)


func test_every_screen_the_flow_asks_for_is_mapped() -> void:
	# The keys game.gd actually passes. A screen added to the flow without a
	# line in music.json would fall back to silence, which nobody would file.
	var catalog := _catalog()
	var screens: Dictionary = catalog.music.get("screens", {})
	for key in ["title", "hub", "journal", "case_board", "exchange",
			"loadout", "dev", "splash"]:
		assert_true(screens.has(key), "screen '%s' has a music entry" % key)
	for module in Catalog.MINIGAME_MODULES:
		var track := catalog.music_for_minigame(String(module))
		assert_true(catalog.music_tracks().has(track),
			"minigame '%s' names a real track" % module)


func test_a_fight_sounds_like_a_fight_unless_it_says_otherwise() -> void:
	var catalog := _catalog()
	# An ordinary encounter takes the combat bed, not its alley's track.
	assert_eq(catalog.music_for_encounter("prologue_wisp"), "mus_combat",
		"ordinary encounter")
	# The ones the story treats as more than a fight name their own.
	assert_eq(catalog.music_for_encounter("prologue_parlor"), "mus_unpicked",
		"the Unpicked")
	assert_eq(catalog.music_for_encounter("q_wax_tallowman"), "mus_tallowman",
		"the Tallowman")


func test_only_the_ending_is_allowed_to_end() -> void:
	var catalog := _catalog()
	for track_id in catalog.music_tracks():
		assert_eq(catalog.music_loops(String(track_id)),
			String(track_id) != "mus_ending", "track '%s' loops" % track_id)


## The rule the design rests on: a story beat swaps the screen on every page
## turn and asks for its music each time. If that restarted the bed, the score
## would stutter once a sentence.
func test_asking_twice_does_not_restart_the_track() -> void:
	var service := _service()
	if service == null:
		return
	service.play("mus_prowl")
	assert_eq(service.starts, 1, "first ask starts the track")
	service.play("mus_prowl")
	service.play("mus_prowl")
	assert_eq(service.starts, 1, "asking again changes nothing")
	assert_eq(service.current_track(), "mus_prowl", "still the same track")
	service.play("mus_combat")
	assert_eq(service.starts, 2, "a different track does start")
	# Silence is a real state, and coming back from it plays again.
	service.play("")
	assert_eq(service.current_track(), "", "empty id means silence")
	service.play("mus_combat")
	assert_eq(service.starts, 3, "after silence the track starts over")
	service.queue_free()


func test_a_disabled_service_stays_quiet() -> void:
	# The tour sets this: two thousand screenshots, nobody listening, and
	# screens swapping faster than a crossfade could finish.
	var service := _service()
	if service == null:
		return
	service.enabled = false
	service.play("mus_prowl")
	assert_eq(service.starts, 0, "disabled service starts nothing")
	assert_eq(service.current_track(), "", "and claims no track")
	service.queue_free()


## MusicService owns AudioStreamPlayers, so it needs a tree. The headless
## runner IS a SceneTree; if that ever changes these two tests skip rather
## than fail on an unrelated harness change.
func _service() -> MusicService:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var service := MusicService.new()
	(loop as SceneTree).root.add_child(service)
	return service


## Silence is a decision, never an accident. Every one of these paths is a
## thing somebody could forget when they add content next year, and not one of
## them is allowed to leave the player in a quiet room.
func test_a_forgotten_mapping_falls_back_instead_of_falling_silent() -> void:
	var catalog := _catalog()
	var tracks := catalog.music_tracks()
	# A screen nobody remembered to score.
	var screen_track := catalog.music_for_screen("a_screen_added_next_year")
	assert_true(tracks.has(screen_track), "unmapped screen still gets a bed")
	# A place added to environments.json without a `music` field.
	var place_track := catalog.music_for_environment("a_place_added_next_year")
	assert_true(tracks.has(place_track), "unmapped place still gets a bed")
	# A module added without a line in music.json.
	var module_track := catalog.music_for_minigame("a_module_added_next_year")
	assert_true(tracks.has(module_track), "unmapped minigame still gets a bed")
	# A fight in a quest written later.
	var fight_track := catalog.music_for_encounter("an_encounter_added_next_year")
	assert_true(tracks.has(fight_track), "unmapped encounter still gets a bed")


## The two silences that ARE deliberate, so a later "helpful" fallback cannot
## quietly put music under the splash or the developer menu.
func test_the_deliberate_silences_stay_silent() -> void:
	var catalog := _catalog()
	assert_eq(catalog.music_for_screen("splash"), "", "the splash is silent on purpose")
	assert_eq(catalog.music_for_screen("dev"), "", "the dev menu is silent on purpose")


func test_a_missing_file_falls_back_to_the_bed() -> void:
	var service := _service()
	if service == null:
		return
	service.fallback_track = "mus_prowl"
	service.play("mus_a_track_nobody_generated")
	assert_eq(service.current_track(), "mus_prowl",
		"a track with no file lands on the fallback, not on silence")
	service.queue_free()


## The Music switch on the settings page. Off must actually stop the stream —
## a muted bus still decodes — and must not lose track of where the player is,
## or turning it back on plays the wrong room.
func test_the_music_switch_stops_playback_and_remembers_the_room() -> void:
	var service := _service()
	if service == null:
		return
	service.play("mus_mantel")
	assert_eq(service.starts, 1, "playing")
	service.set_muted(true)
	service.play("mus_hollow_court")
	assert_eq(service.starts, 1, "muted: the room changed but nothing started")
	assert_eq(service.current_track(), "mus_hollow_court",
		"muted: the score still follows the player")
	service.set_muted(false)
	assert_eq(service.starts, 2, "unmuted: the room the player is in starts")
	assert_eq(service.current_track(), "mus_hollow_court", "and it is the right room")
	service.queue_free()
