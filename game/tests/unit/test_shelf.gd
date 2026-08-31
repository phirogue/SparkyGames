extends TestCase
## The shelf: three books, which one Continue opens, and the one load the game
## offers while it is being played.
##
## The save design has one property worth protecting with tests, because it is
## invisible in a screenshot and easy to refactor away: THE PLAYER NEVER
## CHOOSES WHEN A BOOK IS WRITTEN. Everything here is downstream of that —
## restore_checkpoint can only ever hand back the last checkpoint, and it
## carries settings across rather than restoring them, because the lamps and
## the loudness are not progress.
##
## Every test runs against a scratch prefix. SaveService.shelf_prefix exists
## for this and nothing else: a suite that wrote to "user://book_1.json" would
## erase a real game the first time anyone ran it on their own machine.

const SCRATCH := "user://test_shelf_"


func _use_scratch_shelf() -> void:
	SaveService.shelf_prefix = SCRATCH
	_cleanup()


func _cleanup() -> void:
	for slot in range(1, SaveService.SLOT_COUNT + 1):
		SaveService.erase_slot(slot)
	SaveService.shelf_prefix = "user://book_"


func _written(slot: int, gleam: int, done := true) -> void:
	var profile := SaveService.DEFAULT_PROFILE.duplicate(true)
	profile["gleam"] = gleam
	profile["prologue_done"] = done
	SaveService.save_slot(profile, slot)


# ------------------------------------------------------------------- shelf

func test_books_do_not_read_each_other() -> void:
	_use_scratch_shelf()
	_written(1, 11)
	_written(2, 22)
	_written(3, 33)
	assert_eq(int(SaveService.load_slot(1)["gleam"]), 11, "book 1 is book 1")
	assert_eq(int(SaveService.load_slot(2)["gleam"]), 22, "book 2 is book 2")
	assert_eq(int(SaveService.load_slot(3)["gleam"]), 33, "book 3 is book 3")
	_cleanup()


func test_an_unwritten_book_is_empty_and_a_written_one_is_not() -> void:
	_use_scratch_shelf()
	assert_true(not SaveService.slot_exists(2), "nothing written yet")
	_written(2, 5)
	assert_true(SaveService.slot_exists(2), "a written book is on the shelf")
	var shelf := SaveService.shelf()
	assert_eq(shelf.size(), SaveService.SLOT_COUNT,
		"the shelf always shows every book, written or not")
	assert_true(not bool(shelf[0]["used"]), "book 1 is empty")
	assert_true(bool(shelf[1]["used"]), "book 2 is written")
	_cleanup()


func test_erasing_a_book_takes_its_backup_too() -> void:
	# The failure this guards: erase leaves the .bak, the new game's first
	# write is interrupted, and load_profile resurrects the ERASED game —
	# handing the player a stranger's save at the worst possible moment.
	_use_scratch_shelf()
	_written(1, 40)
	_written(1, 41)   # the second write is what creates the rolling backup
	assert_true(FileAccess.file_exists(SaveService.slot_backup_path(1)),
		"a second write leaves a backup")
	SaveService.erase_slot(1)
	assert_true(not SaveService.slot_exists(1),
		"an erased book is gone, backup and all")
	_cleanup()


func test_continue_opens_the_most_recently_written_book() -> void:
	_use_scratch_shelf()
	assert_eq(SaveService.latest_slot(), -1, "an empty shelf continues nothing")
	_written(1, 1)
	var older := SaveService.load_slot(1)
	# save_slot stamps the hour it wrote. Two saves inside the same second
	# would tie, so book 1 is aged by hand rather than by sleeping.
	older["saved_at"] = int(older["saved_at"]) - 3600
	SaveService.save_profile(older, SaveService.slot_path(1),
		SaveService.slot_temp_path(1), SaveService.slot_backup_path(1))
	_written(3, 3)
	assert_eq(SaveService.latest_slot(), 3,
		"the newest book is the one Continue opens")
	_cleanup()


func test_a_summary_says_where_a_book_is_without_saying_a_word() -> void:
	# The shelf screen turns these into sentences; the service hands over
	# facts only (law 20 — a sentence built here is a sentence no content
	# tool could reach).
	_use_scratch_shelf()
	var profile := SaveService.DEFAULT_PROFILE.duplicate(true)
	profile["prologue_done"] = true
	profile["gleam"] = 64
	profile["quests_done"] = ["night_rounds", "garden_route"]
	profile["case"] = {"active": "wax_and_wick", "evidence": ["a", "b"],
		"leads_done": []}
	profile["achievements"] = {"stats": {"lives_spent": 2}, "unlocked": []}
	SaveService.save_slot(profile, 2)
	var summary := SaveService.slot_summary(2)
	assert_true(bool(summary["used"]), "written")
	assert_eq(int(summary["gleam"]), 64, "gleam")
	assert_eq(int(summary["quests_done"]), 2, "nights done")
	assert_eq(int(summary["lives_spent"]), 2, "lives spent")
	assert_eq(int(summary["evidence"]), 2, "things found")
	assert_eq(String(summary["case"]), "wax_and_wick", "the open case")
	assert_true(int(summary["saved_at"]) > 0, "the hour it was written")
	_cleanup()


func test_saving_stamps_the_hour() -> void:
	_use_scratch_shelf()
	var profile := SaveService.DEFAULT_PROFILE.duplicate(true)
	assert_eq(int(profile["saved_at"]), 0, "a fresh profile has no hour")
	SaveService.save_slot(profile, 1)
	assert_true(int(profile["saved_at"]) > 0,
		"save_slot stamps the book it writes — latest_slot depends on it")
	_cleanup()


# -------------------------------------------------------- the legacy save

func test_a_pre_shelf_save_is_adopted_into_the_first_book() -> void:
	# A player who installed before the start screen existed has their game in
	# user://profile.json. Finding an empty shelf would read as the update
	# having deleted it.
	_use_scratch_shelf()
	var legacy := SaveService.DEFAULT_PROFILE.duplicate(true)
	legacy["gleam"] = 91
	legacy["prologue_done"] = true
	SaveService.save_profile(legacy, SaveService.PROFILE_PATH,
		SaveService.TEMP_PATH, SaveService.BACKUP_PATH)
	assert_true(SaveService.adopt_legacy_save(1), "the old save is adopted")
	assert_eq(int(SaveService.load_slot(1)["gleam"]), 91, "with its game in it")
	# Idempotent: a second launch must not overwrite the book the player has
	# been playing since with the stale copy of it.
	SaveService.save_slot({"schema_version": 7, "gleam": 5}, 1)
	assert_true(not SaveService.adopt_legacy_save(1),
		"adoption happens once, not on every launch")
	assert_eq(int(SaveService.load_slot(1)["gleam"]), 5,
		"the book the player has been writing wins")
	_cleanup()
	var dir := DirAccess.open("user://")
	for path in [SaveService.PROFILE_PATH, SaveService.TEMP_PATH,
			SaveService.BACKUP_PATH]:
		if FileAccess.file_exists(path):
			dir.remove(path)


# --------------------------------------------------- turning back the page

func test_reverting_gives_back_the_checkpoint_and_nothing_else() -> void:
	var saved := SaveService.DEFAULT_PROFILE.duplicate(true)
	saved["gleam"] = 20
	var live := saved.duplicate(true)
	live["gleam"] = 200   # a night's takings, not yet banked at a checkpoint
	var restored := SaveService.restore_checkpoint(saved, live)
	assert_eq(int(restored["gleam"]), 20,
		"the unfinished night goes; the checkpoint is what comes back")
	assert_eq(int(live["gleam"]), 200,
		"restoring does not reach into the live profile it was handed")


func test_settings_follow_the_player_into_whichever_book_they_open() -> void:
	# The same rule as reverting, in the other direction: settings are a
	# person's preference, not one save's progress. Opening book 2 must not
	# turn the music back on because book 2 was last written before it was
	# turned off. game.gd routes _open_book / _new_book / _close_book through
	# restore_checkpoint for exactly this.
	var book := SaveService.DEFAULT_PROFILE.duplicate(true)
	book["gleam"] = 30
	book["settings"]["music"] = true
	var live := SaveService.DEFAULT_PROFILE.duplicate(true)
	live["settings"]["music"] = false
	var opened := SaveService.restore_checkpoint(book, live)
	assert_eq(int(opened["gleam"]), 30, "the book's game comes across")
	assert_true(not bool(opened["settings"]["music"]),
		"the player's settings do not")


func test_reverting_keeps_the_lamps_where_the_player_left_them() -> void:
	# Settings are not progress. A player who turned the music off two minutes
	# ago must not have it come back on because they turned back a page.
	var saved := SaveService.DEFAULT_PROFILE.duplicate(true)
	saved["settings"]["music"] = true
	saved["settings"]["volume"] = 1.0
	var live := SaveService.DEFAULT_PROFILE.duplicate(true)
	live["settings"]["music"] = false
	live["settings"]["volume"] = 0.4
	var restored := SaveService.restore_checkpoint(saved, live)
	assert_true(not bool(restored["settings"]["music"]),
		"the music stays off")
	assert_true(is_equal_approx(float(restored["settings"]["volume"]), 0.4),
		"the loudness stays where it was put")


# --------------------------------------------------------- prologue resume

func test_a_finished_prologue_has_no_beat_left_to_resume() -> void:
	# A stale index on a finished book would restart a REPLAYED prologue in
	# the middle of itself.
	var merged := SaveService._migrate({
		"schema_version": 7, "prologue_done": true, "prologue_index": 14,
	})
	assert_eq(int(merged["prologue_index"]), 0, "cleared on a finished book")


func test_an_old_save_keeps_its_own_counsel_about_when_it_was_written() -> void:
	# Law 7: what does an old save IMPLY? Nothing about an hour that was never
	# recorded — so the field stays 0 and the shelf says so in words rather
	# than printing a date it invented.
	var merged := SaveService._migrate({"schema_version": 6, "gleam": 8})
	assert_eq(int(merged["schema_version"]), 7, "migrated to the shelf version")
	assert_eq(int(merged["saved_at"]), 0, "no invented hour")
	assert_eq(int(merged["gleam"]), 8, "and the game itself survives")
