extends TestCase
## SaveService: migration, deep-merge of new defaults into old saves, and a
## full write/read round-trip against scratch paths (never the real profile).

const TEST_PROFILE := "user://test_profile.json"
const TEST_TEMP := "user://test_profile.tmp"
const TEST_BACKUP := "user://test_profile.bak"


func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	for path in [TEST_PROFILE, TEST_TEMP, TEST_BACKUP]:
		if FileAccess.file_exists(path):
			dir.remove(path)


func test_migrate_preserves_player_values() -> void:
	var merged := SaveService._migrate({
		"schema_version": 2, "gleam": 42, "prologue_done": true,
		"skills": ["scratch", "pounce"],
	})
	assert_eq(int(merged["gleam"]), 42, "gleam survives migration")
	assert_eq(merged["skills"], ["scratch", "pounce"] as Array, "skills survive")


func test_migrate_deep_merges_new_nested_defaults() -> void:
	# An old save whose nested dicts predate newer default keys must GAIN
	# those keys — the shallow-merge bug replaced the whole nested dict.
	var merged := SaveService._migrate({
		"schema_version": 2,
		"settings": {},
		"codex": { "enemies": ["the_vole"] },
	})
	assert_true(merged["settings"].has("volume"),
		"new nested default (settings.volume) reaches an old save")
	assert_true(merged["codex"].has("places"),
		"new nested default (codex.places) reaches an old save")
	assert_eq(merged["codex"]["enemies"], ["the_vole"] as Array,
		"old nested values are kept")


func test_migrate_grants_prologue_skills() -> void:
	var merged := SaveService._migrate({
		"schema_version": 2, "prologue_done": true, "skills": ["scratch"],
	})
	assert_eq(merged["skills"], SaveService.PROLOGUE_SKILLS as Array,
		"a finished prologue implies its skill grants (law 7)")


func test_migrate_renames_moonlight_cards() -> void:
	var merged := SaveService._migrate({
		"schema_version": 2, "deck": ["moonlight_1", "ferocity_1"],
	})
	assert_eq(merged["deck"], ["mysticism_1", "ferocity_1"] as Array,
		"pre-rename card ids migrate to the stable mysticism id")


func test_migrate_v1_recalibration() -> void:
	var merged := SaveService._migrate({
		"schema_version": 1, "max_hp": 20, "deck": ["ferocity_3", "guile_3"],
	})
	assert_eq(int(merged["max_hp"]), 10, "v1 saves drop to the level-1 HP")
	assert_eq(merged["deck"], SaveService.DEFAULT_PROFILE["deck"] as Array,
		"v1 potent decks reset to the starter deck")
	# The chain runs to the END, not one step: a v1 save must arrive at the
	# current schema in a single load, not stall a version short of it.
	assert_eq(int(merged["schema_version"]),
		int(SaveService.DEFAULT_PROFILE["schema_version"]),
		"an old save migrates all the way to the current schema")


func test_migrate_builds_the_collection_from_the_deck() -> void:
	# v6, law 7: under the old economy a cut card was sold and gone, so an old
	# save's collection is exactly the deck it carried — NOT the fresh-install
	# starter pool the deep merge would otherwise hand it.
	var merged := SaveService._migrate({
		"schema_version": 5, "deck": ["ferocity_2", "guile_1"],
	})
	assert_eq(merged["card_pool"], ["ferocity_2", "guile_1"] as Array,
		"an old save's card_pool is its deck, copy for copy")


func test_migrate_repairs_a_deck_the_collection_misses() -> void:
	# A current-schema profile whose deck outruns its pool (a hand-written
	# scenario spec) is repaired by count, never by trimming the deck.
	var merged := SaveService._migrate({
		"schema_version": 6,
		"deck": ["ferocity_1", "ferocity_1", "guile_2"],
		"card_pool": ["ferocity_1"],
	})
	assert_eq(merged["card_pool"].count("ferocity_1"), 2,
		"the pool grows to cover every copy the deck holds")
	assert_eq(merged["card_pool"].count("guile_2"), 1,
		"cards the pool never saw are added")
	assert_eq(merged["deck"], ["ferocity_1", "ferocity_1", "guile_2"] as Array,
		"the deck is never trimmed by the repair")


func test_grant_card_feeds_deck_and_collection_together() -> void:
	var profile := {"deck": ["guile_1"], "card_pool": ["guile_1"]}
	SaveService.grant_card(profile, "shadow_3")
	assert_eq(profile["deck"], ["guile_1", "shadow_3"] as Array,
		"a granted card is on the spool immediately")
	assert_eq(profile["card_pool"], ["guile_1", "shadow_3"] as Array,
		"and in the collection forever")


func test_save_load_round_trip() -> void:
	_cleanup()
	var profile := SaveService.DEFAULT_PROFILE.duplicate(true)
	profile["gleam"] = 77
	profile["skills"] = ["scratch", "slink"]
	SaveService.save_profile(profile, TEST_PROFILE, TEST_TEMP, TEST_BACKUP)
	var loaded := SaveService.load_profile(TEST_PROFILE, TEST_BACKUP)
	assert_eq(int(loaded["gleam"]), 77, "gleam round-trips")
	assert_eq(loaded["skills"], ["scratch", "slink"] as Array, "skills round-trip")
	_cleanup()


func test_backup_fallback_on_corrupt_primary() -> void:
	_cleanup()
	var profile := SaveService.DEFAULT_PROFILE.duplicate(true)
	profile["gleam"] = 55
	SaveService.save_profile(profile, TEST_PROFILE, TEST_TEMP, TEST_BACKUP)
	# Second save creates the rolling backup of the first.
	profile["gleam"] = 56
	SaveService.save_profile(profile, TEST_PROFILE, TEST_TEMP, TEST_BACKUP)
	# Corrupt the primary the way a mid-write kill would.
	var file := FileAccess.open(TEST_PROFILE, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	var loaded := SaveService.load_profile(TEST_PROFILE, TEST_BACKUP)
	assert_eq(int(loaded["gleam"]), 55, "corrupt primary falls back to backup")
	_cleanup()


func test_a_failed_write_never_touches_the_good_save() -> void:
	# Written is not saved. A temp file that cannot even be opened (the shape
	# a full disk actually takes on a phone) must leave the existing profile
	# alone — losing the checkpoint, never the book. The reread-verify guard
	# in save_profile covers the subtler case of a write that opened fine and
	# then truncated; this pins the loud end of the same promise.
	_cleanup()
	var profile := SaveService.DEFAULT_PROFILE.duplicate(true)
	profile["gleam"] = 77
	SaveService.save_profile(profile, TEST_PROFILE, TEST_TEMP, TEST_BACKUP)
	profile["gleam"] = 99
	SaveService.save_profile(profile, TEST_PROFILE,
		"user://no_such_dir/impossible.tmp", TEST_BACKUP)
	var loaded := SaveService.load_profile(TEST_PROFILE, TEST_BACKUP)
	assert_eq(int(loaded["gleam"]), 77, "the failed save left the good one alone")
	_cleanup()


func test_no_save_returns_defaults() -> void:
	_cleanup()
	var loaded := SaveService.load_profile(TEST_PROFILE, TEST_BACKUP)
	assert_eq(int(loaded["gleam"]), 0, "fresh install gets the default profile")
	assert_eq(loaded["skills"], ["scratch"] as Array, "default skills")


func test_battle_loadout_auto_derives_first_owned() -> void:
	var loadout := SaveService.battle_loadout({
		"skills": ["scratch", "pounce", "slink", "purr", "loaf"], "loadout": [],
	})
	assert_eq(loadout, ["scratch", "pounce", "slink", "purr", "loaf"] as Array,
		"empty loadout = Scratch + the first owned, up to LOADOUT_SIZE")


func test_battle_loadout_respects_player_choice() -> void:
	var loadout := SaveService.battle_loadout({
		"skills": ["scratch", "pounce", "slink", "purr", "loaf", "swat"],
		"loadout": ["swat", "loaf", "purr"],
	})
	assert_eq(loadout, ["scratch", "swat", "loaf", "purr"] as Array,
		"chosen loadout wins, Scratch always first")


func test_battle_loadout_filters_unowned_and_caps() -> void:
	var loadout := SaveService.battle_loadout({
		"skills": ["scratch", "pounce", "slink"],
		"loadout": ["shelf_justice", "pounce", "slink", "purr", "pounce"],
	})
	assert_eq(loadout, ["scratch", "pounce", "slink"] as Array,
		"unowned and duplicate picks are dropped; cap holds")


func test_battle_loadout_never_exceeds_the_law() -> void:
	var loadout := SaveService.battle_loadout({
		"skills": ["scratch", "pounce", "slink", "purr", "loaf", "swat", "shelf_justice"],
		"loadout": [],
	})
	assert_eq(loadout.size(), SaveService.LOADOUT_SIZE,
		"loadout law: LOADOUT_SIZE out at a time, Scratch included")
	# The battle tray FANS its cards (step compresses to fit), so there is no
	# column count to pin against the law any more — the fan's own width
	# arithmetic is asserted in test_rules.gd against SKILL_CARD_SIZE.
