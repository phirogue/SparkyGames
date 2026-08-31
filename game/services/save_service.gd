class_name SaveService
extends RefCounted
## Persistent profile in user://. Versioned JSON, temp-file write with a
## rolling backup — per docs/design/tech-stack.md save rules.

## The pre-slots save, kept as a constant because it is still READ once: a
## player who installed before books existed has their game in this file, and
## adopt_legacy_save() moves it into the first slot on the next launch.
const PROFILE_PATH := "user://profile.json"
const TEMP_PATH := "user://profile.tmp"
const BACKUP_PATH := "user://profile.bak"

## Three books on the shelf. The player picks one at the start screen and
## never thinks about it again — the game writes to that one slot at its own
## checkpoints, and the only load offered inside the game is "go back to the
## page this book is open at" (see restore_checkpoint). There is deliberately
## no save-anywhere: a player who could stamp a save, try something and roll
## it back would be playing a different game than the one being designed.
const SLOT_COUNT := 3

const DEFAULT_PROFILE := {
	"schema_version": 7,
	"prologue_done": false,
	# Which prologue beat this book is open at (v7). The prologue is the
	# longest unskippable stretch in the game, so quitting in the middle of
	# it and coming back to the first card would be the game forgetting an
	# hour of reading. Meaningless once `prologue_done` is true.
	"prologue_index": 0,
	# When this book was last written, as unix seconds. The start screen
	# sorts by it to decide what "Continue" continues, and the shelf shows
	# it so two books in progress can be told apart. 0 means unrecorded.
	"saved_at": 0,
	"gleam": 0,
	# Level-1 Ash (owner calibration 2026-08-01): 10 HP; growth comes as
	# mission rewards, never as visible numbers.
	"max_hp": 10,
	# Starter deck: 15 cards, ALL value 1 — potent 2s/3s are rewards, not
	# starting kit (owner rarity rule).
	"deck": [
		"ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1",
		"guile_1", "guile_1", "guile_1",
		"shadow_1", "shadow_1", "shadow_1", "shadow_1",
		"mysticism_1", "mysticism_1", "mysticism_1",
	],
	# Every energy card the player OWNS (v6). The deck is the subset that goes
	# out; re-spooling at the loadout is free and non-destructive (owner
	# 2026-08-08), so a card cut from the deck stays here forever.
	"card_pool": [
		"ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1",
		"guile_1", "guile_1", "guile_1",
		"shadow_1", "shadow_1", "shadow_1", "shadow_1",
		"mysticism_1", "mysticism_1", "mysticism_1",
	],
	"skills": ["scratch"],
	# The player's chosen prowl loadout (non-Scratch skills, LOADOUT_SIZE - 1
	# of them). Empty means "auto": the first owned. Edited at the Mantel.
	"loadout": [],
	"flags": {},
	# Lessons already delivered (data/lessons.json). A lesson plays ONCE, at
	# the moment it first matters; the Casebook replays any of them on demand
	# forever after (owner rule 2026-08-04).
	"taught": [],
	# WHAT THE PLAYER HAS DONE, as facts (core/chronicle.gd). Each entry is a
	# kind plus the ids and numbers involved; the words are rendered when the
	# Casebook is opened, from story/interface.json. See `journal` below for
	# what this replaced and why.
	"chronicle": [],
	# LEGACY (pre-v5): finished sentences, appended as they happened. Kept
	# because a player's existing history is theirs and re-deriving it from
	# prose is guesswork — the Casebook shows these under the structured ones.
	# Nothing writes to it any more.
	"journal": [],
	"codex": { "enemies": [], "places": [] },
	"achievements": {},
	# Options (see scenes/settings_screen.gd). Old saves merge against these,
	# so a profile written before the settings page existed comes up with
	# sound on and the lamps normal (law 7).
	"settings": {
		"volume": 1.0,
		"sfx": true,
		"music": true,
		"lamps_low": false,     # the reading-in-the-dark dim overlay
		"ask_to_spend": false,  # confirm purchases at the Magpie Exchange
	},
	# --- chapter spine (v3, Chapter 1) ---
	# The open case and what has been proved. "active" points at a case id in
	# data/case.json; the prologue ends by pointing the thread into the city,
	# so Wax & Wick is open from the moment the Mantel is.
	"case": { "active": "wax_and_wick", "evidence": [], "leads_done": [] },
	# Guild standing: id -> int, negative means they remember and not fondly.
	"standing": {},
	# Favor-knots owed TO Ash (world-bible.md) — spending one unties it.
	"favors": [],
	# Quest ids completed at least once; what makes `once` quests stay done.
	"quests_done": [],
	# Quest id -> times STARTED (not finished). Drives `when_attempt` story
	# gating: a retried quest plays its remembering beats instead of its
	# first-meeting ones. Migration thought (law 7): an old save merges to {}
	# and every quest reads as a first visit — one remembering line lost,
	# nothing owed.
	"quest_attempts": {},
	# Durable FACTS: what this Ash has seen, met and learned, as
	# {name: int} — set by story steps (`sets`) the moment they are shown,
	# read by `when_fact` gates so a line that leans on a branch-gated
	# event provably plays only for players who saw it. Migration thought
	# (law 7): an old save merges to {} and every "have we met?" would
	# answer no to characters known for chapters — so game.gd re-derives
	# facts from quests_done + flags on adopt (ProwlScript.derive_facts),
	# idempotently, every load. Nothing here is authoritative that cannot
	# be re-derived or re-earned.
	"facts": {},
}

# ---------------------------------------------------------------- the shelf
#
# Three books, one file each. Nothing above this line knows about slots: the
# path-parameterised load/save below are still the whole mechanism, and a slot
# is only a naming convention for the three paths it hands them.

## Where the shelf lives. A variable rather than a constant for exactly one
## reason: the tests exercise erase_slot and latest_slot, which need real
## files, and a test that wrote to the real shelf would delete the player's
## game the first time somebody ran the suite on their own machine. Nothing in
## the game ever assigns this — tests/unit/test_shelf.gd is the only writer.
static var shelf_prefix := "user://book_"


static func slot_path(slot: int) -> String:
	return "%s%d.json" % [shelf_prefix, slot]


static func slot_temp_path(slot: int) -> String:
	return "%s%d.tmp" % [shelf_prefix, slot]


static func slot_backup_path(slot: int) -> String:
	return "%s%d.bak" % [shelf_prefix, slot]


static func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot)) 		or FileAccess.file_exists(slot_backup_path(slot))


static func load_slot(slot: int) -> Dictionary:
	return load_profile(slot_path(slot), slot_backup_path(slot))


## Writes a book, stamping the hour it was written. Every checkpoint in the
## game comes through here, which is why the stamp lives here rather than at
## the call sites — a save that forgot to record its time would make the shelf
## lie about which book is the most recent one.
static func save_slot(profile: Dictionary, slot: int) -> void:
	profile["saved_at"] = int(Time.get_unix_time_from_system())
	save_profile(profile, slot_path(slot), slot_temp_path(slot),
		slot_backup_path(slot))


## Burns a book so a new game can be started in its place. The backup goes
## too: leaving it would let load_profile resurrect the erased game the next
## time the new one failed to parse, which is the worst possible moment to
## hand somebody a stranger's save.
static func erase_slot(slot: int) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for path in [slot_path(slot), slot_temp_path(slot), slot_backup_path(slot)]:
		if FileAccess.file_exists(path):
			dir.remove(path)


## The pre-slots save, moved onto the shelf. Runs once at boot: a player who
## installed before the start screen existed has a game in user://profile.json,
## and finding an empty shelf on the next launch would read as their save being
## deleted. The old file is left where it is rather than removed — an adoption
## that half-worked must not be the thing that loses a game.
static func adopt_legacy_save(slot: int = 1) -> bool:
	if slot_exists(slot) or not FileAccess.file_exists(PROFILE_PATH):
		return false
	var adopted := load_profile(PROFILE_PATH, BACKUP_PATH)
	# Its real age is on the file, which is a better answer than "now" —
	# a book last touched in March should not claim it was written today.
	adopted["saved_at"] = int(FileAccess.get_modified_time(PROFILE_PATH))
	save_profile(adopted, slot_path(slot), slot_temp_path(slot),
		slot_backup_path(slot))
	return true


## What the shelf shows, as FACTS. No words: the slots screen has the catalog
## and story/interface.json, and a sentence built here would be a sentence no
## content tool could reach (law 20). One entry per slot, always SLOT_COUNT of
## them, so an empty shelf still draws three books.
static func shelf() -> Array:
	var out: Array = []
	for slot in range(1, SLOT_COUNT + 1):
		out.append(slot_summary(slot))
	return out


static func slot_summary(slot: int) -> Dictionary:
	var summary := {
		"slot": slot, "used": false, "saved_at": 0, "prologue_done": false,
		"gleam": 0, "lives_spent": 0, "quests_done": 0, "evidence": 0,
		"case": "",
	}
	if not slot_exists(slot):
		return summary
	var profile := load_slot(slot)
	summary["used"] = true
	summary["saved_at"] = int(profile.get("saved_at", 0))
	summary["prologue_done"] = bool(profile.get("prologue_done", false))
	summary["gleam"] = int(profile.get("gleam", 0))
	summary["lives_spent"] = int(profile.get("achievements", {})
		.get("stats", {}).get("lives_spent", 0))
	summary["quests_done"] = Array(profile.get("quests_done", [])).size()
	var case_state: Dictionary = profile.get("case", {})
	summary["case"] = String(case_state.get("active", ""))
	summary["evidence"] = Array(case_state.get("evidence", [])).size()
	return summary


## Which book "Continue" continues: the one written most recently. -1 when the
## shelf is empty, which is what makes the start screen grey the button out
## rather than offering a continue with nothing behind it.
static func latest_slot() -> int:
	var best := -1
	var best_time := -1
	for slot in range(1, SLOT_COUNT + 1):
		if not slot_exists(slot):
			continue
		var stamp := int(slot_summary(slot)["saved_at"])
		if stamp > best_time:
			best_time = stamp
			best = slot
	return best


## Going back to the page the book is open at.
##
## This is the ONLY load the game offers while it is being played, and it is
## deliberately not a load in the save-scumming sense: the player cannot
## choose when a book is written, so "revert" can only ever undo the current
## unfinished night, never a consequence the game already wrote down. A death,
## a spent life, a quest attempt and a purchase are all committed at the
## moment they happen (see game.gd `_save()` call sites).
##
## `settings` are carried across from the LIVE profile rather than restored:
## the lamps and the loudness are not progress, and a player who turned the
## music off two minutes ago should not have it come back on because they
## turned back a page.
static func restore_checkpoint(saved: Dictionary, live: Dictionary) -> Dictionary:
	var restored := saved.duplicate(true)
	restored["settings"] = Dictionary(live.get("settings", {})).duplicate(true)
	return restored


## Everything the prologue teaches; granted retroactively to saves that
## predate progressive skill unlocks.
const PROLOGUE_SKILLS := ["scratch", "pounce", "slink", "purr", "loaf"]

## The loadout law lives in core (Catalog.LOADOUT_SIZE) because it is a rule;
## this alias is the door every scene already knocks on. Raising it means
## re-checking battle.gd's tray width budget.
const LOADOUT_SIZE := Catalog.LOADOUT_SIZE


# Paths are parameters (defaulting to the real save) so tests can round-trip
# against scratch files without ever touching a player's profile.
static func load_profile(profile_path: String = PROFILE_PATH,
		backup_path: String = BACKUP_PATH) -> Dictionary:
	for path in [profile_path, backup_path]:
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var parsed: Variant = JSON.parse_string(file.get_as_text())
				if parsed is Dictionary and parsed.has("schema_version"):
					return _migrate(parsed)
	return DEFAULT_PROFILE.duplicate(true)


static func save_profile(profile: Dictionary,
		profile_path: String = PROFILE_PATH, temp_path: String = TEMP_PATH,
		backup_path: String = BACKUP_PATH) -> void:
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: cannot open temp save file")
		return
	file.store_string(JSON.stringify(profile, "\t"))
	file.close()
	var dir := DirAccess.open("user://")
	if FileAccess.file_exists(profile_path):
		var copy_err := dir.copy(profile_path, backup_path)
		if copy_err != OK:
			push_error("SaveService: backup copy failed (%d)" % copy_err)
	var rename_err := dir.rename(temp_path, profile_path)
	if rename_err != OK:
		push_error("SaveService: temp->profile rename failed (%d)" % rename_err)


static func _migrate(profile: Dictionary) -> Dictionary:
	# One-step migration chain; never delete old migrators (tech-stack rules).
	var merged := _deep_merge(DEFAULT_PROFILE.duplicate(true), profile)
	# Pre-skill-unlock saves: a finished prologue implies its skill grants.
	if merged["prologue_done"] and merged["skills"].size() <= 1:
		merged["skills"] = PROLOGUE_SKILLS.duplicate()
	# 2026-08-01 energy rename: moonlight became mysticism (the wild).
	for key in ["deck", "card_pool"]:
		var renamed: Array = []
		for card_id in merged[key]:
			renamed.append(String(card_id).replace("moonlight", "mysticism"))
		merged[key] = renamed
	# v2 (2026-08-02): the level-1 recalibration. Old saves carried 20 HP
	# and potent starter cards into a 10-HP, all-1s world.
	if int(profile.get("schema_version", 1)) < 2:
		merged["max_hp"] = mini(int(merged["max_hp"]), 10)
		merged["deck"] = DEFAULT_PROFILE["deck"].duplicate()
		merged["schema_version"] = 2
	# v3 (2026-08-03): the chapter spine (case / standing / favors /
	# quests_done). The deep merge supplies the new keys themselves; what the
	# migration owes is the law-7 question "what does an old save IMPLY?" —
	# a finished prologue implies the case is open, because the prologue's
	# last line already points the thread into the city. The guard also
	# repairs a save that stored an emptied "active" (no case = a Case Board
	# the player could never open again).
	if merged["prologue_done"] and String(merged["case"]["active"]).is_empty():
		merged["case"]["active"] = DEFAULT_PROFILE["case"]["active"]
	if int(profile.get("schema_version", 1)) < 3:
		merged["schema_version"] = 3
	# v4 (2026-08-04): lessons. Law 7 -- what does an old save IMPLY? A player
	# who has already finished the prologue has been taught the fight rules by
	# the coach and has been living at the Mantel; re-teaching them the basics
	# on their next launch would be the game forgetting who they are. Every
	# lesson stays available in the Casebook either way.
	if int(profile.get("schema_version", 1)) < 4:
		if merged["prologue_done"]:
			for lesson_id in IMPLIED_BY_PROLOGUE:
				if not merged["taught"].has(lesson_id):
					merged["taught"].append(lesson_id)
		merged["schema_version"] = 4
	# v5 (2026-08-06): the chronicle. Law 7 -- what does an old save IMPLY?
	# Its `journal` holds finished sentences that cannot be turned back into
	# the facts behind them, so they are NOT converted: guessing which enemy
	# "Spent a life to the Chained Dog" refers to would be inventing history.
	# The old lines stay readable in the Casebook and the structured log starts
	# empty. A finished prologue does imply its one certain event, so that much
	# is seeded -- otherwise a returning player's Casebook opens blank and
	# reads as if the game forgot them.
	if int(profile.get("schema_version", 1)) < 5:
		if merged["prologue_done"] and Array(merged["chronicle"]).is_empty():
			var chronicle := Chronicle.new()
			chronicle.record("prologue_done")
			merged["chronicle"] = chronicle.to_list()
		merged["schema_version"] = 5
	# v6 (2026-08-08): the card collection. Cutting stopped being a purchase
	# and became free selection at the loadout, which needs what the player
	# OWNS stored apart from what they carry. Law 7 — what does an old save
	# IMPLY? Under the old economy a cut card was sold and gone, so the
	# collection is exactly the deck the save carried (the deep merge above
	# would otherwise hand every old save the fresh-install starter pool).
	if int(profile.get("schema_version", 1)) < 6:
		merged["card_pool"] = merged["deck"].duplicate()
		merged["schema_version"] = 6
	# v7 (2026-08-30): the shelf. Saves became slots, and a book learned to
	# remember which prologue beat it is open at and when it was last written.
	# Law 7 — what does an old save IMPLY? It was written before the game
	# recorded a time, so `saved_at` cannot be invented: it stays 0 and the
	# shelf says so in words rather than printing a fictional date. Its
	# `prologue_index` is 0, which is right for a save that finished the
	# prologue (the field is dead for it) and is the only honest answer for
	# one that did not — the beat it stopped at was never written down.
	if int(profile.get("schema_version", 1)) < 7:
		merged["schema_version"] = 7
	# A finished prologue has no beat to resume; keeping a stale index would
	# make a replay of the prologue restart in the middle of it.
	if merged["prologue_done"]:
		merged["prologue_index"] = 0
	# Repair, every load: the deck must never hold a card the collection does
	# not (a hand-written scenario spec, or a reward that missed grant_card).
	# Counts, not membership — decks repeat cards.
	merged["card_pool"] = _pool_covering(merged["card_pool"], merged["deck"])
	return merged


## The pool, extended until it covers every copy the deck holds.
static func _pool_covering(pool: Array, deck: Array) -> Array:
	var have := {}
	for card_id in pool:
		have[card_id] = int(have.get(card_id, 0)) + 1
	var need := {}
	for card_id in deck:
		need[card_id] = int(need.get(card_id, 0)) + 1
	var out := pool.duplicate()
	for card_id in need:
		for _i in maxi(0, int(need[card_id]) - int(have.get(card_id, 0))):
			out.append(card_id)
	return out


## A card enters the player's life: into the collection AND onto the spool,
## so a bought or rewarded card is felt on the very next prowl without a
## detour through the loadout. The ONE door for granting cards — appending
## to profile["deck"] alone would desync the collection.
static func grant_card(profile: Dictionary, card_id: String) -> void:
	if not (profile.get("deck") is Array):
		profile["deck"] = []
	if not (profile.get("card_pool") is Array):
		profile["card_pool"] = []
	profile["deck"].append(card_id)
	profile["card_pool"].append(card_id)


## Lessons a finished prologue has effectively already delivered -- the ones
## the in-fight coach and the Mantel walkthrough already cover. Kept beside
## the migration that uses it so the two cannot drift apart.
const IMPLIED_BY_PROLOGUE := ["growing_stronger"]


## The skills that enter a battle (loadout law: LOADOUT_SIZE out at a time,
## Scratch included). The player's chosen loadout wins, filtered to what they
## still own; empty/invalid falls back to the first owned. Pure and static so
## tests can pin it without a scene tree.
static func battle_loadout(profile: Dictionary) -> Array:
	var owned: Array = profile.get("skills", [])
	var room := LOADOUT_SIZE - 1  # Scratch always holds the first slot
	var picked: Array = []
	for skill_id in profile.get("loadout", []):
		if picked.size() >= room:
			break
		if skill_id != "scratch" and owned.has(skill_id) and not picked.has(skill_id):
			picked.append(skill_id)
	if picked.is_empty():
		for skill_id in owned:
			if picked.size() >= room:
				break
			if skill_id != "scratch":
				picked.append(skill_id)
	return ["scratch"] + picked


## The player's CURRENT state as a scenario spec — the warm start.
##
## A scenario is how any player state gets reproduced without playing to it
## (game/tests/scenarios/README.md). Writing one by hand means guessing at a
## profile shape; this turns whatever is actually happening right now into one.
##
##     "it only breaks when I'm on my last life with a thin deck"
##     -> export it, and the repro is one command forever
##
## Only what makes a state DIFFERENT is written: keys equal to the defaults are
## dropped, so the spec stays readable and keeps working when the defaults move
## (a spec that pins every key silently freezes the starting deck of the day it
## was written). The chronicle is dropped too — a warm start wants the state,
## not the history that produced it.
static func to_scenario(profile: Dictionary, carryover: Dictionary = {},
		launch: String = "hub", comment: String = "", seed_value: int = 0) -> Dictionary:
	var spec := {}
	if not comment.is_empty():
		spec["comment"] = comment
	spec["profile"] = _difference(DEFAULT_PROFILE, profile)
	# `saved_at` is the hour the export happened, which is true of every
	# export and tells the next reader nothing — a spec that carried it would
	# churn its own diff every time it was regenerated.
	for noise in ["schema_version", "chronicle", "journal", "achievements",
			"saved_at"]:
		spec["profile"].erase(noise)
	if not carryover.is_empty():
		spec["carryover"] = carryover.duplicate(true)
	if seed_value != 0:
		spec["seed"] = seed_value
	spec["launch"] = launch
	return spec


## Keys where `current` differs from `base`. Nested dictionaries recurse, so a
## profile that changed one setting exports one setting rather than the block.
static func _difference(base: Dictionary, current: Dictionary) -> Dictionary:
	var out := {}
	for key in current:
		if not base.has(key):
			out[key] = current[key]
			continue
		if base[key] is Dictionary and current[key] is Dictionary:
			var nested := _difference(base[key], current[key])
			if not nested.is_empty():
				out[key] = nested
		elif base[key] != current[key]:
			out[key] = current[key]
	return out


## Recursive merge: the save's values win, but NESTED dictionaries merge
## key-by-key instead of replacing the default wholesale. A shallow
## Dictionary.merge() meant any NEW nested default (a codex list, a settings
## key) would never reach existing saves — the law-7 failure mode.
static func _deep_merge(base: Dictionary, override: Dictionary) -> Dictionary:
	for key in override:
		if base.get(key) is Dictionary and override[key] is Dictionary:
			base[key] = _deep_merge(base[key], override[key])
		else:
			base[key] = override[key]
	return base
