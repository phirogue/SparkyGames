extends Control
## Game flow orchestrator: prologue script -> hub -> quest prowls.
## Owns the profile, the achievement tracker, and all screen transitions.
## Screens are dumb; this file is the only place that decides "what next".

const StoryScreen := preload("res://scenes/story_screen.gd")
const BattleScreen := preload("res://scenes/battle.gd")
const HubScreen := preload("res://scenes/hub_screen.gd")
const SplashScreen := preload("res://scenes/splash_screen.gd")
const StartScreen := preload("res://scenes/start_screen.gd")
const ShelfScreen := preload("res://scenes/shelf_screen.gd")
const CreditsScreen := preload("res://scenes/credits_screen.gd")
const JournalScreen := preload("res://scenes/journal_screen.gd")
const CaseBoardScreen := preload("res://scenes/case_board_screen.gd")
const DevMenuScreen := preload("res://scenes/dev_menu_screen.gd")
const SettingsScreen := preload("res://scenes/settings_screen.gd")
const ExchangeScreen := preload("res://scenes/exchange_screen.gd")
const LoadoutScreen := preload("res://scenes/loadout_screen.gd")
const StitchScreen := preload("res://scenes/minigames/stitch_screen.gd")
const TestimonyScreen := preload("res://scenes/minigames/testimony_screen.gd")
const WardScreen := preload("res://scenes/minigames/ward_screen.gd")
const LatticeScreen := preload("res://scenes/minigames/lattice_screen.gd")
const CrossingScreen := preload("res://scenes/minigames/crossing_screen.gd")

## THE ECONOMY IS A DIAL, NOT A CONSTANT. These live in data/rules.json and
## are read through `catalog.rules`; the accessors below are the only readers.
## They were consts here until 2026-08-05, which meant a balance pass on the
## satchel wager was an edit to a scene script — and meant tests/simulate.gd
## could not see the numbers the game actually ran on.
##   prowl.press_on_mult  satchel multiplier growth per fight of depth
##   prowl.toll_rate      the Hollow Court's cut of banked gleam on a death
##   prowl.refusal_rate   the filing fee when the Court refuses an
##                        unscheduled death (an ordinary defeat)
##   prowl.slip_forfeit   what goes over the wall when you leave in a hurry
##   presentation.flashback_tint  the one sepia every Remembered Day uses, so
##                                memory reads the same everywhere (a scene
##                                may still override with image_tint)
func _press_on_mult() -> float: return catalog.rules.num("prowl.press_on_mult")
func _toll_rate() -> float: return catalog.rules.num("prowl.toll_rate")
func _refusal_rate() -> float: return catalog.rules.num("prowl.refusal_rate")
func _slip_forfeit() -> float: return catalog.rules.num("prowl.slip_forfeit")
func _flashback_tint() -> String: return catalog.rules.text("presentation.flashback_tint")

var catalog: Catalog
var profile: Dictionary
var tracker: AchievementTracker
var story: Dictionary          # assembled from story/prologue/ by StoryLoader

var current_screen: Control
var toasts: Array[String] = [] # achievement lines to surface on the next story screen

# Prowl state
var quest: Dictionary = {}
var encounter_index := 0
var satchel := 0
## Times the current quest was started before this run (drives when_attempt).
var quest_attempt := 0
var carryover: Dictionary = {}
var last_outcome := CombatState.Outcome.ONGOING
## How the most recent minigame step ended, for `when_minigame` story gates —
## the post-testimony page that narrates a confession the player never won
## was this chapter's canon bug, same class as victory text after a retreat.
var last_minigame_won := false


var tour_mode := false
var dev_mode := false   # component runner / scenario: throwaway world
## Which book on the shelf this session is writing to (SaveService.SLOT_COUNT
## of them). -1 means "no book": a tour or a component run, where every
## checkpoint is dropped on the floor instead of written down.
var active_slot := -1

## Where a throwaway world keeps its shelf. Tour and component runs open,
## start and ERASE books; pointed at the real prefix, one of them would delete
## somebody's game. Nothing writes here either (dev saves are dropped), so
## these files stay empty unless a dev launch seeds them on purpose.
const DEV_SHELF_PREFIX := "user://dev_book_"
var _dev_seed := 0      # scenario-pinned battle seed (0 = clock-random)
var settings_layer: CanvasLayer
var settings_overlay: Control    # the settings page itself; toggle .visible
var lamp_layer: CanvasLayer
var lamp_dim: ColorRect
## The score. Every screen tells it what room the player is in; it drops a
## repeat on the floor, so asking on every swap costs nothing.
var music: MusicService
var _music_log := false   # --music-log: print every track change
## The one-shots. Separate bus, separate switch, separate fader from `music`.
var sfx: SfxService


## Drawn hamburger glyph for the always-available settings button (no
## generated art dependency; glyph fonts are unreliable for ☰).
class MenuGlyph extends Control:
	func _draw() -> void:
		for i in 3:
			var y := size.y * (0.3 + 0.2 * i)
			draw_line(Vector2(size.x * 0.25, y), Vector2(size.x * 0.75, y),
				Color("e8dcc0"), 3.0)


## Boot cannot continue (damaged install / corrupt content). Shows a plain
## readable page — the one screen allowed to skip the storybook template.
func _fatal(message: String) -> void:
	push_error(message)
	var page := Panel.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = message + "\n\nPlease reinstall the game."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 40)
	page.add_child(label)
	add_child(page)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("100e0c"))  # the book's dark edge
	theme = UITheme.build()  # storybook theme; every child screen inherits
	catalog = DataLoader.load_catalog()
	# Content must be coherent before ANY screen builds on it. This is the
	# shipped-scene validation gate (main.gd is not the boot scene) — in a
	# release export a broken bundle stops here with a readable page instead
	# of a null-deref three screens later.
	var problems := catalog.validate()
	if not problems.is_empty():
		_fatal("This copy of the game has damaged content.\n\n" +
			"\n".join(problems.slice(0, 6)))
		return
	tour_mode = OS.get_cmdline_user_args().has("--tour")
	if tour_mode:
		# A THROWAWAY SHELF, WIPED. The tour walks the start screen, opens
		# books and starts new ones — every one of those is destructive
		# against the real shelf, and photographing a stranger's saves would
		# be its own defect. Wiped as well as redirected, because a dev launch
		# that seeded the throwaway shelf earlier would otherwise leave its
		# books lying in the tour's shots of a FIRST launch (2026-08-30).
		SaveService.shelf_prefix = DEV_SHELF_PREFIX
		for slot in range(1, SaveService.SLOT_COUNT + 1):
			SaveService.erase_slot(slot)
	# The profile is a BLANK until a book is chosen at the start screen. It is
	# built here anyway because everything from the settings layer down reads
	# it during boot, and a null profile three lines later is a crash on a
	# screen the player has not reached yet.
	profile = SaveService.DEFAULT_PROFILE.duplicate(true)
	if not tour_mode:
		# A player who installed before the shelf existed has their game in
		# the old single-profile file. Move it onto the shelf before anything
		# reads the shelf, or their first sight of the new start screen is an
		# empty one — which reads as the update having eaten their save.
		SaveService.adopt_legacy_save()
		# SETTINGS FOLLOW THE PLAYER, NOT THE BOOK. They live in the profile
		# for storage, but the lamps and the loudness are a person's
		# preference, not one save's progress — so the cover comes up with
		# them already applied (a player who muted the music must not hear the
		# title theme at full every launch until they press Continue), and
		# opening any book carries whatever is currently set INTO it.
		var latest := SaveService.latest_slot()
		if latest > 0:
			profile["settings"] = SaveService.load_slot(latest).get(
				"settings", profile["settings"])
	tracker = AchievementTracker.new(catalog)
	tracker.from_dict(profile.get("achievements", {}))
	# The prologue is assembled from story/prologue/ — an index naming the arcs
	# in order, one file per arc. StoryLoader hands back the same shape the
	# single prologue.json used to have, so everything below is unchanged.
	story = StoryLoader.load_prologue()
	if story.is_empty():
		_fatal("This copy of the game is missing its story.\n(story/prologue/)")
		return
	_build_settings_layer()
	# AFTER the settings layer, which is what creates the Music bus the
	# players route through — a player built before its bus lands on Master
	# and the Music toggle silences nothing.
	music = MusicService.new()
	music.name = "MusicService"
	music.fade_seconds = catalog.rules.num("presentation.music_fade")
	music.fallback_track = catalog.music_for_environment("")   # defaults.story
	# The tour photographs two thousand screens with nobody listening, and it
	# swaps screens faster than a crossfade can finish — unless it was asked
	# to report the score, which is the only way to walk EVERY quest and see
	# what each one sounds like (law 2, for the system with no screenshots).
	_music_log = OS.get_cmdline_user_args().has("--music-log")
	music.enabled = not tour_mode or _music_log
	add_child(music)
	# The one-shots. Same reasoning as the score for the bus ordering, and the
	# same reason to be quiet under the tour — except the tour has no --sfx-log
	# equivalent, because a one-shot leaves no state to report: it either fired
	# or it did not, and tests/unit/test_sfx.gd is where that is asserted.
	sfx = SfxService.new()
	sfx.name = "SfxService"
	sfx.configure(catalog.sfx)
	sfx.enabled = not tour_mode
	add_child(sfx)
	# UITheme builds every button in the game from a static context and has no
	# path to a service instance, so the tap sound is reached through this.
	SfxService.instance = sfx
	# The tour node attaches BEFORE the first screen is swapped in, and
	# regardless of how the game is launched: `--tour --scene scenario:<name>`
	# photographs a scenario's screens, which is the only way to get shots of
	# states the prologue never reaches (a case mid-chapter, a flashback).
	if tour_mode:
		add_child(load("res://tests/tour.gd").new())
	if OS.get_cmdline_user_args().has("--rect-probe"):
		add_child(load("res://tests/rect_probe.gd").new())
	# Warm start: dump the REAL save as a scenario spec and quit, without
	# touching it. Runs before any dev launch replaces `profile`, so what gets
	# exported is the player's actual state rather than a throwaway one.
	var export_name := _cmdline_value("--export-scenario")
	if export_name != "":
		_export_scenario(export_name)
		get_tree().quit()
		return
	var dev_scene := _cmdline_value("--scene")
	if dev_scene != "":
		# Component runner (owner rule 2026-08-01): jump straight to one
		# piece of the game on a throwaway profile — no full playthrough
		# needed to test one screen. See CLAUDE.md for specs.
		dev_mode = true  # throwaway world: never write the real save
		SaveService.shelf_prefix = DEV_SHELF_PREFIX   # ...nor the real shelf
		profile = SaveService.DEFAULT_PROFILE.duplicate(true)
		_dev_launch(dev_scene)
	else:
		# Splash, then the start screen. The tour takes the same route as a
		# player — it just photographs every door instead of picking one.
		var splash: Control = SplashScreen.new()
		splash.finished.connect(_show_start, CONNECT_ONE_SHOT)
		_swap(splash)


## Give the throwaway profile the kit a player would actually be carrying by
## the time they reach this content: a full tray (LOADOUT_SIZE, Scratch
## included) and a deck with something in it. Used by every dev launch that
## drops into mid-game content.
##
## Owner rule 2026-08-05: "when testing scenarios you are typically fighting
## with only the free Scratch — run them with a proper hand of 5 selected
## action cards." A bare-clawed test proves the fight is survivable at zero
## power and proves nothing whatever about the fight the game ships.
func _equip_for_testing() -> void:
	var kit: Array = ["scratch", "pounce", "slink", "purr", "loaf",
		"swat", "shelf_justice"]
	for skill_id in kit:
		if catalog.skills.has(skill_id) and not profile["skills"].has(skill_id):
			profile["skills"].append(skill_id)
	profile["loadout"] = []   # auto-fills the tray from what is owned
	profile["gleam"] = maxi(int(profile["gleam"]), 40)


## Writes the CURRENT state out as a scenario spec, so it can be dropped back
## into later without playing to it again (the warm start).
##
##   godot --path game -- --export-scenario last_life
##
## Lands in user:// rather than res://: an export is read-only on a device, and
## the path is printed so the file can be copied into game/tests/scenarios/ to
## keep. Exporting is the fast way to answer "only happens when…" — play until
## it happens, export, and the repro is one command from then on.
func _export_scenario(scenario_name: String) -> void:
	var spec := SaveService.to_scenario(profile, carryover,
		"hub" if quest.is_empty() else "quest:" + String(quest.get("id", "")),
		"Exported from live play.", _dev_seed)
	var path := "user://%s.json" % scenario_name
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("cannot write scenario to %s" % path)
		return
	file.store_string(JSON.stringify(spec, "  "))
	file.close()
	print("scenario written: ", ProjectSettings.globalize_path(path))
	print("copy it into game/tests/scenarios/ to keep it, then run it with")
	print("  godot --path game -- --scene scenario:", scenario_name)


## Two throwaway books so the shelf screen has something to show. A DEV
## LAUNCH ARRIVES EQUIPPED (owner rule 2026-08-05) applies to a page whose
## whole content is the saves on it: an empty shelf photographs as three
## identical blank plates and proves nothing about the screen.
func _seed_dev_shelf() -> void:
	var mid := SaveService.DEFAULT_PROFILE.duplicate(true)
	mid["prologue_done"] = true
	mid["gleam"] = 46
	mid["quests_done"] = ["night_rounds", "garden_route", "empty_coat"]
	mid["achievements"] = {"stats": {"lives_spent": 2}, "unlocked": []}
	SaveService.save_slot(mid, 1)
	var early := SaveService.DEFAULT_PROFILE.duplicate(true)
	early["prologue_index"] = 6
	SaveService.save_slot(early, 3)


func _cmdline_value(flag: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(flag)
	if index >= 0 and index + 1 < args.size():
		return args[index + 1]
	return ""


## Jump straight into one component: "hub", "start" (a.k.a. "title"),
## "shelf", "credits", "journal", "case",
## "exchange", "loadout", "settings", "recap", "story:<scene index>",
## "battle:<encounter_id>[:skill,skill,...]", "quest:<quest_id>", or
## "scenario:<name>" (full Ash setup from tests/scenarios/<name>.json — see
## that folder's README).
func _dev_launch(spec: String) -> void:
	var parts := spec.split(":")
	match parts[0]:
		"hub":
			profile["prologue_done"] = true
			_show_hub()
		"start", "title":
			# "title" is kept as an alias: it is what every launcher, doc and
			# muscle memory calls this screen, and the tour walks it by name.
			# Seeded, so the cover shows the state a returning player sees —
			# Continue lit, and the book it would open named underneath. The
			# empty-shelf cover is what the full --tour photographs.
			_seed_dev_shelf()
			_show_start()
		"shelf":
			_seed_dev_shelf()
			_show_shelf("load")
		"credits":
			_show_credits()
		"journal":
			_show_journal()
		"exchange":
			profile["prologue_done"] = true
			# A market with an empty purse shows nothing but refusals, so the
			# dev launch arrives able to buy the top shelf.
			profile["gleam"] = maxi(int(profile["gleam"]), 60)
			_show_exchange()
		"loadout":
			profile["prologue_done"] = true
			if profile["skills"].size() <= 1:
				profile["skills"] = ["scratch", "pounce", "slink", "purr", "loaf",
					"swat", "shelf_justice"]
			_show_loadout()
		"settings":
			profile["prologue_done"] = true
			# A DEV LAUNCH ARRIVES EQUIPPED (owner rule 2026-08-05): the book
			# panel has a live state and a throwaway state, and without a book
			# on the dev shelf only the throwaway one could ever be looked at.
			_seed_dev_shelf()
			active_slot = 1
			_show_hub()
			_refresh_book_state()
			_open_settings()
		"case":
			profile["prologue_done"] = true
			_show_case_board()
		"recap":
			# The cold-launch card on its own. A profile with no evidence has
			# nothing to recap, so this drops to the hub — which is the real
			# behaviour, not a broken launch. Use a scenario for a full one.
			profile["prologue_done"] = true
			_show_recap(_show_hub)
		"story":
			_run_prologue_scene(int(parts[1]) if parts.size() > 1 else 0)
		"battle":
			var encounter := parts[1] if parts.size() > 1 else "prologue_vole"
			if parts.size() > 2:
				profile["skills"] = Array(parts[2].split(","))
				profile["loadout"] = []  # explicit skills ARE the loadout
			elif profile["skills"].size() <= 1:
				# Bare battle spec on a fresh profile: standard dev kit.
				profile["skills"] = ["pounce", "slink", "purr"]
			_show_battle(encounter, func(state: CombatState) -> void:
				print("dev battle outcome: ", state.outcome)
				get_tree().quit())
		"quest":
			profile["prologue_done"] = true
			# A DEV LAUNCH ARRIVES EQUIPPED (owner rule 2026-08-05). The
			# throwaway profile starts with Scratch alone, so every quest ever
			# photographed was fought bare-clawed — which is not the game, and
			# it hid whatever the real five-card tray does to these screens.
			# Anyone testing a quest is testing the fight it actually is.
			_equip_for_testing()
			var quest_id := parts[1] if parts.size() > 1 else "night_rounds"
			if not catalog.quests.has(quest_id):
				push_error("unknown quest '%s'" % quest_id)
				get_tree().quit(1)
				return
			_start_quest(quest_id)
		"scenario":
			_launch_scenario(parts[1] if parts.size() > 1 else "")
		"dev":
			profile["prologue_done"] = true
			_show_dev_menu()
		"stitch":
			_show_stitch(parts[1] if parts.size() > 1 else
				String(catalog.stitch_charts.keys()[0]))
		"testimony":
			_show_testimony(parts[1] if parts.size() > 1 else
				String(catalog.testimonies.keys()[0]))
		"ward":
			_show_ward(parts[1] if parts.size() > 1 else
				String(catalog.wards.keys()[0]))
		"lattice":
			_show_lattice(parts[1] if parts.size() > 1 else
				String(catalog.lattices.keys()[0]))
		"crossing":
			_show_crossing(parts[1] if parts.size() > 1 else
				String(catalog.crossings.keys()[0]))
		_:
			push_error("unknown --scene spec '%s'" % spec)
			get_tree().quit(1)


## Scenario runner: a JSON spec describes Ash's ENTIRE setup (partial
## profile deep-merged over defaults, optional carryover, optional pinned
## seed) plus where to drop in. Testers can reproduce any player state —
## any loadout, any quest order, any economy — without a playthrough.
func _launch_scenario(scenario_name: String) -> void:
	var path := "res://tests/scenarios/%s.json" % scenario_name
	var file := FileAccess.open(path, FileAccess.READ)
	var spec: Variant = null if file == null else JSON.parse_string(file.get_as_text())
	if not (spec is Dictionary):
		push_error("scenario '%s' missing or malformed (%s)" % [scenario_name, path])
		get_tree().quit(1)
		return
	profile = SaveService._deep_merge(
		SaveService.DEFAULT_PROFILE.duplicate(true), spec.get("profile", {}))
	_heal_facts()
	tracker = AchievementTracker.new(catalog)
	tracker.from_dict(profile.get("achievements", {}))
	# A scenario may carry its OWN story scenes, which is how a story system
	# gets exercised before the chapter that uses it is written: the spec
	# becomes the scene list `story:<index>` walks. Same schema as
	# story/prologue/.
	if spec.has("story"):
		story = {"scenes": spec["story"]}
	carryover = spec.get("carryover", {})
	_dev_seed = int(spec.get("seed", 0))
	var launch := String(spec.get("launch", "hub"))
	if launch.begins_with("scenario"):
		push_error("scenarios cannot launch scenarios")
		get_tree().quit(1)
		return
	_dev_launch(launch)


# ------------------------------------------------------------------ helpers

func _swap(screen: Control) -> void:
	if current_screen != null:
		current_screen.queue_free()
	current_screen = screen
	add_child(screen)
	# Screens are Controls parented to this Control: anchor them to fill it,
	# or their tap targets collapse to zero size. Must be the offsets variant —
	# set_anchors_preset alone compensates offsets to preserve the (zero) rect.
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Tell the score what room this is. "" means silence; asking for the track
## already playing does nothing, which is why every _show_* below can call
## this unconditionally. A screen that should keep whatever is playing — a
## notice, a lesson page — simply does not call.
func _play_music(track_id: String) -> void:
	if music == null:
		return
	# The score is the one system a screenshot cannot check (law 1 has no
	# equivalent for sound), so it says what it is doing on request:
	#   godot --headless --path game --quit-after 240 -- --scene hub --music-log
	# prints every track change, which is how a room with the wrong bed gets
	# caught without anyone listening to fifteen tracks.
	if _music_log and track_id != music.current_track():
		print("[music] %s -> %s" % [
			music.current_track() if not music.current_track().is_empty() else "(silence)",
			track_id if not track_id.is_empty() else "(silence)"])
	music.play(track_id, catalog.music_loops(track_id))


func _story_config(environment_id: String, lines: Array) -> Dictionary:
	var environment: Dictionary = catalog.environments.get(environment_id, {})
	var config := {
		"lines": lines,
		# Carried so _show_story knows what room this beat happens in. The
		# story screen ignores the key; the score does not.
		"environment": environment_id,
		"color": environment.get("color", "#22242a"),
		"accent": environment.get("accent", "#d8ccb4"),
		"heading": environment.get("name", ""),
	}
	if environment.has("image"):
		config["image"] = environment["image"]
	if environment.has("image_tint"):
		config["image_tint"] = environment["image_tint"]
	# NO blanket portrait override. The Hollow Court used to force npc_clerk
	# onto every page set there, so the arrival beat — the corridor, before
	# anyone has spoken — opened on a portrait of the ghost the player has not
	# met yet (owner 2026-08-04). Pages that want the Clerk ask for him.
	return config


## Settings live on a CanvasLayer so they are reachable from ANY screen
## (owner rule 2026-08-01) — the layer floats above whatever is swapped in.
## The page is an OVERLAY rather than a swapped screen on purpose: opening
## settings mid-battle must not tear down the combat state underneath it.
func _build_settings_layer() -> void:
	_ensure_audio_buses()
	settings_layer = CanvasLayer.new()
	settings_layer.layer = 10
	add_child(settings_layer)
	var gear := Button.new()
	# Named so PageGuard knows this one belongs in the margin: it is chrome
	# floating over the book, not content on the page, and it must stay
	# reachable from every screen (owner rule 2026-08-01).
	gear.name = "ChromeSettingsButton"
	gear.flat = true
	gear.custom_minimum_size = Vector2(52, 52)
	gear.position = Vector2(8, 8)
	gear.size = Vector2(52, 52)
	gear.pressed.connect(_open_settings)
	var glyph := MenuGlyph.new()
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear.add_child(glyph)
	settings_layer.add_child(gear)

	var page: Control = SettingsScreen.new()
	# A tour or a component run has no book behind it, so the page greys the
	# book row out rather than offering to turn back a page nothing wrote.
	page.setup(profile.get("settings", {}), not (tour_mode or dev_mode))
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.visible = false
	page.setting_changed.connect(_on_setting_changed)
	page.revert_requested.connect(_revert_to_checkpoint)
	page.close_book_requested.connect(_close_book)
	page.closed.connect(func() -> void:
		settings_overlay.visible = false
		_save())
	settings_layer.add_child(page)
	settings_overlay = page

	# The lamp dim sits ABOVE everything, settings included, so the effect of
	# the toggle is visible while the toggle is being looked at.
	lamp_layer = CanvasLayer.new()
	lamp_layer.layer = 20
	add_child(lamp_layer)
	lamp_dim = ColorRect.new()
	lamp_dim.color = Color(0.0, 0.0, 0.0, 0.35)
	lamp_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	lamp_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lamp_dim.visible = false
	lamp_layer.add_child(lamp_dim)

	_apply_settings()


## Named buses so "Music" and "Sound Effects" mute the real thing from the day
## audio ships instead of being retrofitted onto master later. Godot exports
## only the default bus layout, so they are made here if absent.
func _ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			var index := AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


func _on_setting_changed(key: String, value: Variant) -> void:
	var settings: Dictionary = profile.get("settings", {})
	settings[key] = value
	profile["settings"] = settings
	_apply_settings()


## One place that turns the saved options into engine state; called on boot
## and after every change, so there is no per-setting apply path to forget.
func _apply_settings() -> void:
	var settings: Dictionary = profile.get("settings", {})
	# Master. No longer has a control on the settings page — the two channels
	# below replaced it — but it stays in the profile and stays applied, so a
	# scenario spec or a future accessibility option can still pull everything
	# down at once.
	var volume := float(settings.get("volume", 1.0))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)
	# The score and the one-shots are independent in BOTH directions: each has
	# its own switch and its own fader, and neither reads the other's. A player
	# who wants the music without a hundred taps sets Effects to nothing and
	# leaves Music alone.
	for entry in [["Music", "music", "music_volume"], ["SFX", "sfx", "sfx_volume"]]:
		var index := AudioServer.get_bus_index(String(entry[0]))
		if index < 0:
			continue
		var on := bool(settings.get(String(entry[1]), true))
		var level := float(settings.get(String(entry[2]), 1.0))
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))
		# Muted when switched off OR faded to nothing. A fader at zero that
		# left the bus unmuted would still decode every stream for silence.
		AudioServer.set_bus_mute(index, not on or level <= 0.0)
	# The bus mute silences the score instantly; this stops it decoding at all.
	# Both, because the bus is what makes the switch feel immediate and the
	# stop is what stops spending battery on audio nobody asked for.
	if music != null:
		music.set_muted(not bool(settings.get("music", true)))
	if sfx != null:
		sfx.set_muted(not bool(settings.get("sfx", true)))
	if lamp_dim != null:
		lamp_dim.visible = bool(settings.get("lamps_low", false))


## Is there a book behind this session? Not merely "is a slot chosen" — a
## tour picks a book and never writes it, so there is nothing on disk to turn
## back to and the page would be offering a load that quietly did nothing.
func _refresh_book_state() -> void:
	if settings_overlay == null:
		return
	settings_overlay.set_book_live(
		active_slot > 0 and SaveService.slot_exists(active_slot))


func _open_settings() -> void:
	settings_overlay.visible = true


# ------------------------------------------------------- the cover & shelf
#
# Everything between the splash and the first page of the game. The player
# picks a book here and never thinks about slots again: from that point on the
# game writes to `active_slot` at its own checkpoints, and the only load it
# offers is _revert_to_checkpoint.


## The start screen. Four ways in, and Continue names the book it would open.
func _show_start() -> void:
	var screen: Control = StartScreen.new()
	screen.setup(catalog, SaveService.shelf(), SaveService.latest_slot())
	screen.chose.connect(_on_start_chose)
	_play_music(catalog.music_for_screen("start"))
	_swap(screen)


func _on_start_chose(action: String) -> void:
	match action:
		"continue":
			_open_book(SaveService.latest_slot())
		"new":
			_show_shelf("new")
		"load":
			_show_shelf("load")
		"credits":
			_show_credits()


func _show_shelf(mode: String) -> void:
	var screen: Control = ShelfScreen.new()
	screen.setup(catalog, SaveService.shelf(), mode)
	screen.closed.connect(_show_start)
	screen.chose.connect(func(slot: int) -> void:
		if mode == "new":
			_new_book(slot)
		else:
			_open_book(slot))
	_play_music(catalog.music_for_screen("shelf"))
	_swap(screen)


func _show_credits() -> void:
	var screen: Control = CreditsScreen.new()
	screen.closed.connect(_show_start)
	_play_music(catalog.music_for_screen("credits"))
	_swap(screen)


## Open a book and start playing it. The prologue resumes at the beat the book
## was left on rather than at the first card — it is the longest unskippable
## stretch in the game, and starting it over is the game forgetting an hour of
## reading (see SaveService `prologue_index`).
func _open_book(slot: int) -> void:
	if slot <= 0 or not SaveService.slot_exists(slot):
		_show_start()
		return
	active_slot = slot
	# restore_checkpoint, not a bare load: it is the one place that knows
	# settings cross from the live profile into the loaded one.
	_adopt_profile(SaveService.restore_checkpoint(
		SaveService.load_slot(slot), profile))
	if profile["prologue_done"]:
		_show_recap(_show_hub)
	else:
		_run_prologue_scene(int(profile.get("prologue_index", 0)))


## Start a fresh game in a book. The shelf has already asked before writing
## over anything, so by here the answer is yes — and the old book is erased
## rather than merely overwritten, so no backup of it survives to be restored
## by accident later.
func _new_book(slot: int) -> void:
	active_slot = slot
	SaveService.erase_slot(slot)
	_adopt_profile(SaveService.restore_checkpoint(
		SaveService.DEFAULT_PROFILE.duplicate(true), profile))
	_save()
	_run_prologue_scene(0)


## What an old save IMPLIES (law 7): profiles from before facts existed — and
## scenario specs, which hand-author quests_done — arrive with facts = {},
## which would make every "have we met?" answer no to characters the player
## has known for chapters. Re-derive from completed quests and the profile's
## own flags; idempotent, additive, cheap, so it runs on every adopt rather
## than once per schema bump.
func _heal_facts() -> void:
	# Sanitize first: saves are player-owned files, and a hand-edited value
	# ("met_bodkin": "yes") would misgate or crash every later fact read.
	profile["facts"] = ProwlScript.sanitize_facts(profile.get("facts", {}))
	var derived := ProwlScript.derive_facts(catalog.quests,
		Array(profile.get("quests_done", [])), Dictionary(profile.get("flags", {})))
	for key in derived:
		if not profile["facts"].has(key):
			profile["facts"][key] = derived[key]


## Take a loaded profile as the live one, and re-point everything that keeps a
## copy of a piece of it. Missing one of these is how a loaded game ends up
## with the previous book's achievements or the previous book's lamps.
func _adopt_profile(loaded: Dictionary) -> void:
	profile = loaded
	_heal_facts()
	tracker.from_dict(profile.get("achievements", {}))
	toasts = []
	quest = {}
	carryover = {}
	encounter_index = 0
	satchel = 0
	quest_attempt = 0
	last_outcome = CombatState.Outcome.ONGOING
	last_minigame_won = false
	if settings_overlay != null:
		settings_overlay.settings = profile.get("settings", {})
	_refresh_book_state()
	_apply_settings()


## Back to the page the book is open at.
##
## The one load the game offers while it is being played, and the reason there
## is no save button anywhere: the player never chooses when a book is
## written, so this can only ever throw away the unfinished night. Everything
## the game has already committed — a life spent, a quest attempted, a
## purchase made — was written at the moment it happened and comes back with
## the book. Settings are carried across rather than restored (they are not
## progress); SaveService.restore_checkpoint owns that rule.
func _revert_to_checkpoint() -> void:
	if active_slot <= 0 or not SaveService.slot_exists(active_slot):
		return
	_adopt_profile(SaveService.restore_checkpoint(
		SaveService.load_slot(active_slot), profile))
	if profile["prologue_done"]:
		_show_hub()
	else:
		_run_prologue_scene(int(profile.get("prologue_index", 0)))


## Close the book and go back to the shelf. Nothing is written on the way out:
## the last checkpoint IS the saved position, and quietly stamping a new one
## here would turn "close the book" into the save button this design does not
## have.
func _close_book() -> void:
	active_slot = -1
	_adopt_profile(SaveService.restore_checkpoint(
		SaveService.DEFAULT_PROFILE.duplicate(true), profile))
	_show_start()


func _show_story(config: Dictionary, on_done: Callable) -> void:
	# Notices (skills, achievements, casebook) get their OWN view first —
	# mixed into narration they read as story and confused it (owner fix).
	if not toasts.is_empty():
		var pending := toasts.duplicate()
		toasts = []
		_show_notices(pending, func() -> void: _show_story(config, on_done))
		return
	var screen: Control = StoryScreen.new()
	screen.setup(config)
	# ONE_SHOT: a story page's tap catcher stays live after its last line, and
	# two taps landing in one frame must advance the flow once, not twice.
	screen.finished.connect(on_done, CONNECT_ONE_SHOT)
	if config.has("environment"):
		_play_music(catalog.music_for_environment(String(config["environment"])))
	_swap(screen)


## The Hollow Court, played as a small SCENE rather than one wall of text
## (owner 2026-08-04: the first visit read as if Ash already knew the place).
## This is the TRUE-DEATH scene only — a `mortal` beat spending a life
## (docs/design/death-and-lives.md); ordinary defeats play the REFUSED desk
## in _show_court_refused instead. First death gets the arrival — the room
## before the Clerk, the Clerk's banter, a line of Ash's own choosing, and a
## plain account of what dying costs. Every death after that gets one of the
## countdown visits, because by then he does know the place. Extra lines
## (the Toll) are appended to the last page.
func _show_hollow_court(on_done: Callable, extra_lines: Array = []) -> void:
	var lives_spent := int(tracker.stats.get("lives_spent", 0))
	var pages: Array
	if lives_spent <= 1:
		pages = story["hollow_court_first"].duplicate(true)
	else:
		# EVERY DEATH IS A DIFFERENT VISIT (owner rule 2026-08-05, law 15).
		# `hollow_court_repeat` is the canonical-death COUNTDOWN — one scene
		# per life, in order, each written for its number, and the ninth gets
		# the one that has been waiting for it. Deaths are authored `mortal`
		# beats now, so every entry here will be seen at most once per game.
		var visits: Array = story["hollow_court_repeat"]
		var index: int = mini(lives_spent - 2, visits.size() - 1)
		pages = [visits[index].duplicate(true)] if visits[index] is Dictionary \
			else Array(visits[index]).duplicate(true)
	if not extra_lines.is_empty() and not pages.is_empty():
		var last: Dictionary = pages[pages.size() - 1]
		last["lines"] = Array(last["lines"]) + extra_lines
	_play_pages(pages, 0, on_done)


## Plays a list of authored story pages in order. A page is
## {lines, portrait?, heading?, choices?, answers?}: `choices` shows buttons,
## and `answers[i]` (a line array) is played back as the reply before the
## sequence continues. This is deliberately small — a scene player, not a
## dialogue engine; when a chapter needs branching state it goes through
## flags and `when_flag` like every other scene.
func _play_pages(pages: Array, index: int, on_done: Callable) -> void:
	if index >= pages.size():
		on_done.call()
		return
	var page: Dictionary = pages[index]
	var config := _story_config(String(page.get("environment", "hollow_court")),
		page["lines"])
	for key in ["portrait", "heading", "choices", "art_desc"]:
		if page.has(key):
			config[key] = page[key]
	_show_story(config, func(choice: int) -> void:
		var answers: Array = page.get("answers", [])
		if choice >= 0 and choice < answers.size():
			var reply := _story_config(
				String(page.get("environment", "hollow_court")), answers[choice])
			for key in ["portrait", "art_desc"]:
				if page.has(key):
					reply[key] = page[key]
			_show_story(reply, func(_i: int) -> void:
				_play_pages(pages, index + 1, on_done))
			return
		_play_pages(pages, index + 1, on_done))


## A parchment interstitial listing what the night just granted — skill
## notes in the warm accent color so they never read as story text.
func _show_notices(lines: Array, on_done: Callable) -> void:
	var screen := Control.new()
	screen.name = "NoticeScreen"
	UITheme.page_panel(screen)
	var tap := Button.new()
	tap.flat = true
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap.pressed.connect(func() -> void: on_done.call(), CONNECT_ONE_SHOT)
	screen.add_child(tap)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	var title := Label.new()
	title.text = "Noted, with interest"
	title.add_theme_font_override("font", UITheme.smallcaps_font())
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UITheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var wrap := float(UITheme.CONTENT_WIDTH)
	for line in lines:
		var note := Label.new()
		note.text = String(line)
		note.add_theme_font_size_override("font_size", 28)
		note.add_theme_color_override("font_color", UITheme.ACCENT_WARM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.custom_minimum_size = Vector2(wrap, UITheme.measure_text(
			String(line), UITheme.body_font(), 28, wrap).y)
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(note)
	var hint := Label.new()
	hint.text = "— tap to continue —"
	hint.add_theme_font_override("font", UITheme.italic_font())
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", UITheme.INK_FADED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hint)
	_swap(screen)


func _show_battle(encounter_id: String, on_done: Callable, hints: Dictionary = {},
		extra: Dictionary = {}, coach: Array = []) -> void:
	_last_encounter_env = catalog.encounters[encounter_id]["environment"]
	var config := {
		"player_max_hp": int(profile["max_hp"]),
		"player_hp": carryover.get("hp", int(profile["max_hp"])),
		"deck": carryover.get("deck", profile["deck"]),
		# Loadout law: at most 4 abilities out at a time, Scratch included.
		# Clamp HERE, not just in the UI — otherwise core equips skills the
		# player cannot see and enemy jam intents can target the invisible
		# ones. First three owned + the free Scratch until a picker exists.
		"skills": _battle_loadout(),
		"lingering": carryover.get("lingering", []),
		# How well Ash knows this creature: finished fights against it, won
		# or lost. Intents with masked_until stay unreadable until then.
		"familiarity": _enemy_familiarity(
			String(catalog.encounters[encounter_id]["enemies"][0])),
	}
	if carryover.has("skill_charges"):
		config["skill_charges"] = carryover["skill_charges"]
	if carryover.has("skill_powered"):
		config["skill_powered"] = carryover["skill_powered"]
	if _dev_seed != 0:
		config["seed"] = _dev_seed
	config.merge(extra, true)
	var screen: Control = BattleScreen.new()
	screen.setup(catalog, config, encounter_id, hints, coach)
	# ONE_SHOT: the outcome overlay's continue button can be double-tapped,
	# and a fight must be digested — rewards, chronicle, save — exactly once.
	screen.encounter_finished.connect(on_done, CONNECT_ONE_SHOT)
	_play_music(catalog.music_for_encounter(encounter_id))
	_swap(screen)


## The skills that actually enter a battle — the player's chosen loadout
## (edited at the Mantel), resolved by SaveService.battle_loadout so the
## rule is testable without a scene tree.
func _battle_loadout() -> Array:
	return SaveService.battle_loadout(profile)


## Fights finished against this enemy, won or lost — reading an opponent is
## a matter of having stood in front of it, not of having beaten it.
func _enemy_familiarity(enemy_id: String) -> int:
	var stats: Dictionary = tracker.stats
	return int(stats.get("defeated_" + enemy_id, 0)) \
		+ int(stats.get("felled_by_" + enemy_id, 0))


## A scene's chapter-spine effects: evidence found, knots tied, guilds
## noticing. All three surface as notice cards rather than narration (owner
## fix: grants mixed into prose read as story), and all three are idempotent
## so replaying a scene never double-counts.
func _apply_scene_spine(scene: Dictionary) -> void:
	var changed := false
	for evidence_id in scene.get("grant_evidence", []):
		if _find_evidence(String(evidence_id)):
			changed = true
	for favor_id in scene.get("grant_favor", []):
		if CaseState.grant_favor(profile, String(favor_id)):
			changed = true
			toasts.append("✦ A knot in your thread: %s — %s" % [
				catalog.favors[favor_id]["name"], catalog.favors[favor_id].get("flavor", "")])
	if scene.has("standing"):
		for line in CaseState.apply_standing(catalog, profile, scene["standing"]):
			toasts.append("❋ %s" % line)
		changed = true
	if changed:
		_save()


## Records a find on the Case Board. Returns true when it is new, so the
## notice fires once — replaying a lead must not re-announce its thing.
func _find_evidence(evidence_id: String) -> bool:
	if not CaseState.add_evidence(profile, evidence_id):
		return false
	for entry in CaseState.active_case(catalog, profile).get("evidence", []):
		if String(entry["id"]) == evidence_id:
			toasts.append("✎ Case Board: %s — %s" % [
				entry["name"], entry.get("found_line", "")])
			_remember("evidence_found", {"evidence": evidence_id})
			break
	return true


## Ash gets permanently harder to kill. There is no XP bar and no level
## number anywhere in the game (difficulty-and-progression.md: the level is
## OUR ruler, never the player's) — growth arrives as the residue of
## difficult work, and this is the function that leaves it on him.
##
## Idempotent by construction is impossible here (HP is a number, not a set),
## so callers must only reach it from a `once` quest or a one-shot story
## beat. `sharpen_the_claws` is `once: true` for exactly this reason.
func _grant_growth(growth: Dictionary) -> void:
	var gained_hp := int(growth.get("max_hp", 0))
	if gained_hp != 0:
		profile["max_hp"] = int(profile["max_hp"]) + gained_hp
		toasts.append("✦ Harder to kill: %d lives in him now." % int(profile["max_hp"]))
	var gained_cards: Array = growth.get("cards", [])
	if not gained_cards.is_empty():
		var names: Array[String] = []
		for card_id in gained_cards:
			SaveService.grant_card(profile, String(card_id))
			names.append(String(catalog.energy_cards[card_id]["name"]))
			# A card won mid-prowl joins THIS prowl too, or the reward is
			# invisible until the player next comes home.
			if not carryover.is_empty():
				var deck: Array = carryover.get("deck", [])
				deck.append(String(card_id))
				carryover["deck"] = deck
		toasts.append("✦ Wound onto the spool: %s. (%d cards.)"
			% [", ".join(names), profile["deck"].size()])
	var gained_paws := int(growth.get("paws", 0))
	if gained_paws != 0:
		profile["paws"] = int(profile.get("paws", 3)) + gained_paws
		toasts.append("✦ A fourth paw. %d actions a turn." % int(profile["paws"]))
	_save()


## Plays a lesson the FIRST time the game reaches it, and never again
## uninvited (owner rule 2026-08-04). Replays live in the Casebook, so a
## player who skipped or forgot one can go back for it deliberately.
func _teach(lesson_id: String, on_done: Callable) -> void:
	if not catalog.lessons.has(lesson_id):
		push_warning("unknown lesson '%s'" % lesson_id)
		on_done.call()
		return
	var taught: Array = profile.get("taught", [])
	if taught.has(lesson_id):
		on_done.call()
		return
	taught.append(lesson_id)
	profile["taught"] = taught
	_save()
	_play_lesson(lesson_id, on_done)


## Shows a lesson's pages, then — for a `practice` lesson — hands the player
## the real screen on throwaway content so the rules are learned with paws
## rather than read. Used by both the first teach and the Casebook replay.
func _play_lesson(lesson_id: String, on_done: Callable) -> void:
	var lesson: Dictionary = catalog.lessons[lesson_id]
	var pages: Array = lesson.get("pages", [])
	var finish := func() -> void:
		if String(lesson.get("kind", "pages")) != "practice":
			on_done.call()
			return
		var spec := String(lesson.get("scene", "")).split(":")
		if spec.size() < 2:
			on_done.call()
			return
		_launch_minigame(spec[0], spec[1], func(_won: bool) -> void: on_done.call())
	_play_lesson_page(lesson, pages, 0, finish)


func _play_lesson_page(lesson: Dictionary, pages: Array, index: int,
		on_done: Callable) -> void:
	if index >= pages.size():
		on_done.call()
		return
	var page: Dictionary = pages[index]
	var config := _story_config("parlor_cold", page["lines"])
	config["heading"] = String(page.get("title", lesson.get("name", "")))
	config["rules_page"] = true   # story screen styles the whole page as rules
	if page.has("portrait"):
		config["portrait"] = page["portrait"]
	_show_story(config, func(_i: int) -> void:
		_play_lesson_page(lesson, pages, index + 1, on_done))


## Opens one of the five modules and reports whether it was WON. One entry
## point on top of the five `_show_*` launchers, so a prowl step, a lesson's
## practice run and the component runner all behave identically — and so the
## payout below happens exactly once per session, wherever it was played.
func _launch_minigame(module: String, content_id: String, on_done: Callable) -> void:
	match module:
		"stitch": _show_stitch(content_id, on_done)
		"testimony": _show_testimony(content_id, on_done)
		"ward": _show_ward(content_id, on_done)
		"lattice": _show_lattice(content_id, on_done)
		"crossing": _show_crossing(content_id, on_done)
		_:
			push_error("unknown minigame module '%s'" % module)
			on_done.call(false)


## The one close-handler every module shares: bank whatever the session
## earned, then hand control back. `on_done` is a func(won: bool); an empty
## one means "nobody is waiting" — the standalone launches — and falls back
## to the dev menu or the hub as before.
func _module_closed(screen: Control, on_done: Callable) -> Callable:
	return func() -> void:
		var won := false
		var state: Variant = screen.get("state")
		if state != null:
			won = int(state.outcome) == int(Minigame.Outcome.SUCCESS)
			_collect_minigame_rewards(state)
		if on_done.is_valid():
			on_done.call(won)
		elif dev_mode:
			_show_dev_menu()
		else:
			_show_hub()


## What a finished module hands back to the chapter: evidence found, leads
## closed, knots tied, standing spent. Read off the module's own state so
## every module pays out through one path.
func _collect_minigame_rewards(state: Object) -> void:
	var effects: Dictionary = {}
	if state.has_method("break_effects"):
		effects = state.break_effects()
	# rewards() is a METHOD on every module state, never a property — the old
	# property probe here matched nothing, so reward tables were silently
	# skipped. earned_rewards() also gates on SUCCESS: a walked-away ward must
	# not tie the guild's knot.
	if state.has_method("earned_rewards"):
		effects.merge(state.earned_rewards())
	for evidence_id in effects.get("evidence", []):
		_find_evidence(String(evidence_id))
	for lead_id in effects.get("leads_done", []):
		CaseState.mark_lead_done(profile, String(lead_id))
	if effects.has("favor") and CaseState.grant_favor(profile, String(effects["favor"])):
		toasts.append("✦ A knot in your thread: %s" %
			catalog.favors[effects["favor"]]["name"])
	for guild_id in effects.get("standing", {}):
		for line in CaseState.apply_standing(catalog, profile,
				{guild_id: effects["standing"][guild_id]}):
			toasts.append("❋ %s" % line)
	if "standing_cost" in state and state.get("standing_cost") is Dictionary:
		for guild_id in state.get("standing_cost"):
			for line in CaseState.apply_standing(catalog, profile,
					{guild_id: state.get("standing_cost")[guild_id]}):
				toasts.append("❋ %s" % line)
	_save()


## Add a skill to the player's permanent kit, with a story-toast. The kit is
## built over time (owner rule) — nobody starts with the full bar.
func _grant_skills(skill_ids: Array) -> void:
	for skill_id in skill_ids:
		if profile["skills"].has(skill_id):
			continue
		profile["skills"].append(skill_id)
		var def: Dictionary = catalog.skills[skill_id]
		toasts.append("✦ New skill: %s — %s" % [def["name"], def.get("flavor", "")])
	_save()


var _last_encounter_env := ""
## Whether the defeat _digest just recorded was a true death (a `mortal`
## encounter) or one the Court will refuse — read by _prowl_defeat, which
## runs after _digest and has no state in hand.
var last_defeat_mortal := false


func _digest(state: CombatState) -> void:
	last_outcome = state.outcome
	# The Casebook observes: creatures met and places prowled.
	var codex: Dictionary = profile["codex"]
	if not codex["enemies"].has(state.enemy_id):
		codex["enemies"].append(state.enemy_id)
		toasts.append("✎ Casebook: %s" % catalog.enemies[state.enemy_id]["name"])
	if _last_encounter_env != "" and not codex["places"].has(_last_encounter_env):
		codex["places"].append(_last_encounter_env)
	if state.outcome == CombatState.Outcome.DEFEAT:
		# Lives are spent, never taken (docs/design/death-and-lives.md): only
		# a `mortal` beat files a death; everything else the Court refuses.
		last_defeat_mortal = state.mortal
		_remember("life_spent" if state.mortal else "court_refused",
			{"enemy": state.enemy_id})
	for id in tracker.record_encounter(state):
		toasts.append("★ %s — %s" % [
			catalog.achievements[id]["name"], catalog.achievements[id]["description"],
		])
	if state.outcome == CombatState.Outcome.DEFEAT:
		carryover = {}  # sent home either way: full deck, full charges, full hp
	else:
		var charges := {}
		# Energy fed onto a card that never fired stays ON the card for the
		# rest of this venture (owner rule 2026-08-10) — the Mantel is what
		# clears it, by way of _start_quest resetting the carryover.
		var powered := {}
		for s in state.skills:
			charges[s["id"]] = s["charges_left"]
			if not (s["powered"] as Dictionary).is_empty():
				powered[s["id"]] = (s["powered"] as Dictionary).duplicate()
		# The pool persists between encounters (owner rule: no reset until
		# a rest); spent stays spent — EXCEPT one breath back with a win.
		var pool: Array = state.deck + state.hand
		var spent_pool: Array = state.spent.duplicate()
		if state.outcome == CombatState.Outcome.VICTORY and not spent_pool.is_empty():
			var best_i := 0
			for i in spent_pool.size():
				if int(catalog.energy_cards[spent_pool[i]]["value"]) > \
						int(catalog.energy_cards[spent_pool[best_i]]["value"]):
					best_i = i
			pool.append(spent_pool[best_i])
			spent_pool.remove_at(best_i)
		carryover = {
			"hp": state.player_hp,
			"deck": pool,
			"spent": spent_pool,
			"skill_charges": charges,
			"skill_powered": powered,
			"lingering": state.lingering_out(),
		}
	_save()


## Writes one thing that happened into the player's chronicle.
##
## Records FACTS — a kind plus the ids and numbers involved — never sentences.
## The Casebook turns them into prose when it is opened, from
## story/interface.json, so a rewrite of a line re-reads every past entry and
## no wording is ever trapped in a save file. Three of these call sites used to
## build player-facing strings inline here, which law 20 forbids.
func _remember(kind: String, ids: Dictionary = {}, nums: Dictionary = {},
		texts: Dictionary = {}) -> void:
	var chronicle := Chronicle.from_list(profile.get("chronicle", []))
	chronicle.record(kind, ids, nums, texts)
	profile["chronicle"] = chronicle.to_list()


## THE CHECKPOINT. Every call site of this is a moment the game decided is
## worth writing down, and the player has no way to ask for one — which is the
## whole of the save design (see settings_screen.gd's book panel).
func _save() -> void:
	# Tour AND component-runner/scenario worlds are throwaway — writing them
	# would clobber the player's real book with test state. So is a session
	# sitting on the start screen with no book open.
	if tour_mode or dev_mode or active_slot <= 0:
		return
	profile["achievements"] = tracker.to_dict()
	SaveService.save_slot(profile, active_slot)
	# The first checkpoint of a new book is what makes it a book: until this
	# runs there is nothing on disk to turn back TO, and the settings page
	# must not offer to.
	_refresh_book_state()


# ------------------------------------------------------------------ prologue

func _run_prologue_scene(index: int) -> void:
	var scenes: Array = story["scenes"]
	if index >= scenes.size():
		if not profile["prologue_done"]:
			profile["prologue_done"] = true
			# Endowed progress: the Casebook opens already inscribed.
			_remember("prologue_done")
		# Nothing left to resume: a stale index would restart a REPLAYED
		# prologue in the middle of itself.
		profile["prologue_index"] = 0
		_save()
		_show_hub()
		return
	var scene: Dictionary = scenes[index]
	# Where the book is open. Written at the top of every beat, gates and all,
	# so closing the game mid-prologue comes back to the card being read
	# rather than to the first one. Cheap: the profile is a few kilobytes and
	# a beat is a page turn, not a frame.
	if int(profile.get("prologue_index", 0)) != index:
		profile["prologue_index"] = index
		_save()
	var next := func(_arg: Variant = null) -> void: _run_prologue_scene(index + 1)
	# Branch gates: choice flags and last-battle outcomes both route scenes.
	if scene.has("when_flag"):
		var gate: Dictionary = scene["when_flag"]
		if int(profile["flags"].get(gate["flag"], -1)) != int(gate["value"]):
			next.call()
			return
	if scene.has("when_outcome"):
		var wanted: int = {
			"victory": CombatState.Outcome.VICTORY,
			"defeat": CombatState.Outcome.DEFEAT,
			"retreat": CombatState.Outcome.RETREATED,
		}.get(scene["when_outcome"], -1)
		if last_outcome != wanted:
			next.call()
			return
	# Chapter-spine gates: a scene can be for people who found the thing,
	# who are owed a knot, or who a guild is speaking to. All three read
	# state that CaseState owns; none of them mutate it.
	if scene.has("when_evidence") and not CaseState.has_evidence(
			profile, String(scene["when_evidence"])):
		next.call()
		return
	if scene.has("when_favor") and not CaseState.has_favor(
			profile, String(scene["when_favor"])):
		next.call()
		return
	if scene.has("when_standing"):
		var gate: Dictionary = scene["when_standing"]
		var value := CaseState.standing_of(profile, String(gate.get("guild", "")))
		if value < int(gate.get("min", -999)) or value > int(gate.get("max", 999)):
			next.call()
			return
	match scene["type"]:
		# Rules on their own card, immediately before the fight that needs
		# them (owner rule 2026-08-04: teaching wedged between story beats
		# interrupts the flow, and Slink was introduced a page and a half
		# before anything could be slunk). A new humour and the skill it buys
		# arrive together on one "Noted, with interest" page — the same card
		# achievements and casebook finds already use, so learning a rule
		# always looks like learning a rule and never like narration.
		"notice":
			if scene.has("grant"):
				_grant_skills(scene["grant"])
			for note in scene.get("notes", []):
				toasts.append(String(note))
			if toasts.is_empty():
				next.call()
			else:
				var pending := toasts.duplicate()
				toasts = []
				_show_notices(pending, next)
		"story":
			if scene.has("grant"):
				_grant_skills(scene["grant"])
			_apply_scene_spine(scene)
			if scene.get("refresh_spent", false):
				# Story-granted second wind: everything spent rejoins the
				# pool (the vole hunt's "wound fresh" excitement).
				var refreshed: Array = carryover.get("deck", [])
				refreshed.append_array(carryover.get("spent", []))
				carryover["deck"] = refreshed
				carryover["spent"] = []
			if scene.has("add_card"):
				# Story finds join the prowl deck immediately and the
				# permanent deck forever.
				var deck: Array = carryover.get("deck", profile["deck"].duplicate())
				deck.append(scene["add_card"])
				carryover["deck"] = deck
				SaveService.grant_card(profile, String(scene["add_card"]))
				_save()
			var config := _story_config(scene["environment"], scene["lines"])
			if scene.has("portrait"):
				config["portrait"] = scene["portrait"]
			if scene.has("art_desc"):
				config["art_desc"] = scene["art_desc"]
			if scene.has("choices"):
				config["choices"] = scene["choices"]
				_show_story(config, func(choice: int) -> void:
					if scene.has("flag"):
						profile["flags"][scene["flag"]] = choice
						_remember("choice_made", {}, {},
							{"choice": String(scene["choices"][choice])})
						_save()
					_run_prologue_scene(index + 1))
			else:
				_show_story(config, next)
		"battle":
			var extra := {}
			if scene.has("start_hidden_if_flag"):
				var gate: Dictionary = scene["start_hidden_if_flag"]
				if int(profile["flags"].get(gate["flag"], -1)) == int(gate["value"]):
					extra["start_hidden"] = true
			if scene.has("deck"):
				# Tutorial opener: fixed teaching deck, fresh charges, no
				# power sitting on the cards.
				extra["deck"] = scene["deck"]
				extra["skill_charges"] = {}
				extra["skill_powered"] = {}
			elif scene.has("add_cards"):
				# New energy joins the CARRIED pool (appended last so an
				# unshuffled battle opens with exactly these cards).
				var pool: Array = carryover.get("deck", profile["deck"].duplicate())
				pool.append_array(scene["add_cards"])
				carryover["deck"] = pool
			if scene.has("shuffle"):
				extra["shuffle"] = scene["shuffle"]
			if scene.has("opening_cards"):
				# Scripted opener: the beat that teaches Shadow deals the
				# Shadow. One deck for the whole night, dealt on purpose.
				extra["opening_cards"] = scene["opening_cards"]
			if scene.has("skills"):
				# Loadout law: a battle can pin the carried kit (Scratch plus
				# LOADOUT_SIZE-1) even when the profile owns more skills.
				extra["skills"] = scene["skills"]
			if scene.get("no_approach", false):
				extra["no_approach"] = true
			_show_battle(scene["encounter"], func(state: CombatState) -> void:
				_digest(state)
				_run_prologue_scene(index + 1),
				scene.get("hints", {}), extra, scene.get("coach", []))
		"hollow_court_if_died":
			if last_outcome == CombatState.Outcome.DEFEAT:
				_show_hollow_court(func() -> void: next.call())
			elif last_outcome == CombatState.Outcome.VICTORY:
				_show_story(_story_config("parlor_cold", story["unpicked_won"]), next)
			else:
				next.call()
		"flashback":
			# A Remembered Day: the same story page, tinted and headed, with
			# choices refused by the screen (you cannot re-decide a memory).
			_apply_scene_spine(scene)
			var flash := _story_config(scene["environment"], scene["lines"])
			flash["flashback"] = true
			flash["image_tint"] = scene.get("image_tint", _flashback_tint())
			flash["heading"] = "Remembered Day — %s" % scene.get("title", "")
			if scene.has("portrait"):
				flash["portrait"] = scene["portrait"]
			if scene.has("art_desc"):
				flash["art_desc"] = scene["art_desc"]
			_show_story(flash, next)
		"favor_redeem":
			# The one redemption beat: if the knot is held it is spent HERE
			# and its scripted lines play; if it is not, the scene never
			# happened. Settled debts stop being useful, by design.
			var favor_id := String(scene.get("favor", ""))
			if not CaseState.spend_favor(profile, favor_id):
				next.call()
				return
			_save()
			var favor: Dictionary = catalog.favors.get(favor_id, {})
			var redeem := _story_config(scene.get("environment", "parlor_cold"),
				favor.get("redeem_lines", []))
			redeem["heading"] = String(favor.get("redeem_heading", "A knot comes undone"))
			if scene.has("portrait"):
				redeem["portrait"] = scene["portrait"]
			_show_story(redeem, next)
		"title":
			_show_story({
				"lines": [Strings.line("title.name"), Strings.line("title.prologue_done")],
				"color": "#1c2026", "big": true,
				"portrait": "sc_title",
			}, next)


# ------------------------------------------------------------------ hub & prowls

func _show_hub() -> void:
	var screen: Control = HubScreen.new()
	# The room gets walked through ONCE (owner rule 2026-08-04). Recorded on
	# the profile rather than in memory so it survives a quit, and set before
	# the screen is built so a crash mid-lesson does not re-teach it forever.
	var lesson: Array = []
	if not bool(profile["flags"].get("mantel_taught", false)):
		lesson = story.get("mantel_coach", [])
		profile["flags"]["mantel_taught"] = true
		_save()
	screen.setup(catalog, profile, tracker, lesson)
	screen.quest_selected.connect(_start_quest)
	screen.profile_changed.connect(_save)
	screen.open_journal.connect(_show_journal)
	screen.open_case_board.connect(_show_case_board)
	screen.open_exchange.connect(_show_exchange)
	screen.open_loadout.connect(_show_loadout)
	screen.replay_prologue.connect(func() -> void:
		carryover = {}
		last_outcome = CombatState.Outcome.ONGOING
		_run_prologue_scene(0))
	_play_music(catalog.music_for_screen("hub"))
	_swap(screen)


func _show_journal(tab := "deeds") -> void:
	var screen: Control = JournalScreen.new()
	screen.setup(catalog, profile)
	screen.initial_tab = tab
	screen.closed.connect(_show_hub)
	# Replaying a lesson comes back HERE, onto the LESSONS tab (owner
	# 2026-08-09) — a player brushing up on three rules in a row is neither
	# walked through the parlor nor dropped back on Deeds each time.
	screen.replay_lesson.connect(func(lesson_id: String) -> void:
		_play_lesson(lesson_id, func() -> void: _show_journal("lessons")))
	_play_music(catalog.music_for_screen("journal"))
	_swap(screen)


func _show_exchange() -> void:
	var screen: Control = ExchangeScreen.new()
	screen.setup(catalog, profile)
	screen.profile_changed.connect(_save)
	screen.closed.connect(_show_hub)
	_play_music(catalog.music_for_screen("exchange"))
	_swap(screen)


func _show_loadout() -> void:
	var screen: Control = LoadoutScreen.new()
	screen.setup(catalog, profile)
	# The loadout edits the profile in place as it goes, so the save happens on
	# the way out — one write per visit instead of one per tap.
	screen.closed.connect(func() -> void:
		_save()
		_show_hub())
	_play_music(catalog.music_for_screen("loadout"))
	_swap(screen)


# --------------------------------------------------- minigames & dev mode

## Where a minigame returns to. In dev mode there is no story around it, so
## it goes back to the developer menu; in play it will hand off to the beat
## that launched it (Phase 3+, when the leads are wired).
func _minigame_done() -> Callable:
	return func() -> void:
		if dev_mode:
			_show_dev_menu()
		else:
			_show_hub()


## A minigame teaches itself over its own board the first time the player
## meets it, and its "?" replays that lesson forever after (owner 2026-08-09:
## three of the five modules "make no sense, need a tutorial"). The flag is a
## profile flag rather than a `taught` entry because the lesson belongs to the
## SCREEN, not to the Casebook's list of concepts — and an old save that has
## already played a module implies nothing about having understood it, so the
## migration is simply "you get the lesson once more".
func _teach_module(screen: Control, module: String) -> void:
	screen.coach_steps = catalog.tutorial_steps(module)
	var flag := "taught_%s" % module
	screen.coach_auto = not bool(profile["flags"].get(flag, false))
	if screen.coach_auto:
		profile["flags"][flag] = true


func _show_stitch(chart_id: String, on_done := Callable()) -> void:
	if not catalog.stitch_charts.has(chart_id):
		push_error("unknown stitch chart '%s'" % chart_id)
		return
	var chart: Dictionary = catalog.stitch_charts[chart_id]
	var screen: Control = StitchScreen.new()
	screen.setup(chart)
	# A mirror chart is a different lesson, not the same one again: the rule
	# that changed is the only rule the player has to be told twice.
	_teach_module(screen, "stitch_mirror" if bool(chart.get("mirrored", false))
		else "stitch")
	screen.closed.connect(_module_closed(screen, on_done), CONNECT_ONE_SHOT)
	_play_music(catalog.music_for_minigame("stitch"))
	_swap(screen)


func _show_testimony(testimony_id: String, on_done := Callable()) -> void:
	if not catalog.testimonies.has(testimony_id):
		push_error("unknown testimony '%s'" % testimony_id)
		return
	# A testimony is only as playable as the Casebook behind it, so a dev
	# launch hands over every piece of evidence in the case — otherwise the
	# witness cannot be broken and the beat looks defective when it is empty.
	var held: Array = profile.get("case", {}).get("evidence", [])
	if dev_mode and held.is_empty():
		held = catalog.evidence_ids().keys()
	var screen: Control = TestimonyScreen.new()
	screen.setup(catalog, catalog.testimonies[testimony_id], held)
	_teach_module(screen, "testimony")
	screen.closed.connect(_module_closed(screen, on_done), CONNECT_ONE_SHOT)
	_play_music(catalog.music_for_minigame("testimony"))
	_swap(screen)


func _show_ward(ward_id: String, on_done := Callable()) -> void:
	if not catalog.wards.has(ward_id):
		push_error("unknown ward '%s'" % ward_id)
		return
	var screen: Control = WardScreen.new()
	screen.setup(catalog, catalog.wards[ward_id],
		carryover.get("deck", profile["deck"]))
	_teach_module(screen, "ward")
	screen.closed.connect(_module_closed(screen, on_done), CONNECT_ONE_SHOT)
	_play_music(catalog.music_for_minigame("ward"))
	_swap(screen)


func _show_lattice(lattice_id: String, on_done := Callable()) -> void:
	if not catalog.lattices.has(lattice_id):
		push_error("unknown lattice '%s'" % lattice_id)
		return
	var screen: Control = LatticeScreen.new()
	screen.setup(catalog.lattices[lattice_id])
	_teach_module(screen, "lattice")
	screen.closed.connect(_module_closed(screen, on_done), CONNECT_ONE_SHOT)
	_play_music(catalog.music_for_minigame("lattice"))
	_swap(screen)


func _show_crossing(crossing_id: String, on_done := Callable()) -> void:
	if not catalog.crossings.has(crossing_id):
		push_error("unknown crossing '%s'" % crossing_id)
		return
	var screen: Control = CrossingScreen.new()
	screen.setup(catalog, catalog.crossings[crossing_id],
		_dev_seed if _dev_seed != 0 else 20260803, {
			"player_hp": carryover.get("hp", int(profile["max_hp"])),
			"player_max_hp": int(profile["max_hp"]),
			"deck": carryover.get("deck", profile["deck"]),
		})
	_teach_module(screen, "crossing")
	screen.closed.connect(_module_closed(screen, on_done), CONNECT_ONE_SHOT)
	_play_music(catalog.music_for_minigame("crossing"))
	_swap(screen)


## Developer mode: one screen that reaches every part of the game. Dev mode
## is a THROWAWAY world (never writes the real save), which is what makes it
## safe to jump anywhere and quit whenever.
func _show_dev_menu() -> void:
	dev_mode = true
	var screen: Control = DevMenuScreen.new()
	screen.setup(catalog, story)
	screen.jump.connect(func(spec: String) -> void: _dev_launch(spec))
	_play_music(catalog.music_for_screen("dev"))
	_swap(screen)


func _show_case_board() -> void:
	var screen: Control = CaseBoardScreen.new()
	screen.setup(catalog, profile)
	screen.closed.connect(_show_hub)
	_play_music(catalog.music_for_screen("case_board"))
	_swap(screen)


## "Previously on": a mystery has to have a memory, so a cold launch into a
## chapter already in progress opens on the last thing found and the thread
## still to pull. Composed from case.json state — there is no hand-written
## recap to keep in sync. Nothing found yet means nothing to recap, and the
## player goes straight to the Mantel.
func _show_recap(on_done: Callable) -> void:
	var lines := CaseState.recap_lines(catalog, profile)
	if lines.is_empty():
		on_done.call()
		return
	var config := _story_config("parlor_cold", lines)
	config["heading"] = "The case so far"
	_show_story(config, func(_choice: int) -> void: on_done.call())


func _start_quest(quest_id: String) -> void:
	quest = catalog.quests[quest_id]
	encounter_index = 0
	satchel = 0
	carryover = {}
	# How many times this quest has been STARTED before tonight. Story steps
	# gate on it (`when_attempt`), so a retried quest changes instead of
	# replaying, and the people in it remember the first visit (owner
	# 2026-08-10). Counted at the door, not at the finish — a withdrawal and
	# a death are both a first visit the city noticed.
	var attempts: Dictionary = profile.get("quest_attempts", {})
	quest_attempt = int(attempts.get(quest_id, 0))
	attempts[quest_id] = quest_attempt + 1
	profile["quest_attempts"] = attempts
	_save()
	# A stale outcome from a previous quest's minigame must never route this
	# quest's `when_minigame` pages.
	last_minigame_won = false
	# The opening card is set wherever the quest actually STARTS, which is no
	# longer always a fight — "The Carrying" opens in her parlor at first
	# light and has no fight in it at all.
	var steps := ProwlScript.steps_of(quest)
	var opening := "parlor_cold"
	for step: Dictionary in steps:
		match ProwlScript.type_of(step):
			ProwlScript.BATTLE:
				opening = String(catalog.encounters[step["encounter"]]["environment"])
			ProwlScript.STORY:
				opening = String(step.get("environment", opening))
			_:
				continue
		break
	_show_story(_story_config(opening,
		[quest["board_card"], Strings.line("prowl.opening_tail")]),
		func(_i: int) -> void: _run_step(0))


## Runs the quest's script one step at a time (see core/prowl_script.gd). A
## step that opens a screen resumes here when that screen closes; nothing
## else in the prowl knows or cares which kind of step it just finished.
func _run_step(index: int) -> void:
	encounter_index = index
	var steps := ProwlScript.steps_of(quest)
	if index >= steps.size():
		_finish_quest()
		return
	var step: Dictionary = steps[index]
	var next := func() -> void: _run_step(index + 1)
	match ProwlScript.type_of(step):
		ProwlScript.BATTLE:
			_show_battle(String(step["encounter"]), _on_prowl_battle_done)
		ProwlScript.STORY, ProwlScript.FLASHBACK:
			_run_prowl_story(step, next)
		ProwlScript.MINIGAME:
			_run_prowl_minigame(step, next)
		ProwlScript.LESSON:
			_teach(String(step["lesson"]), next)
		ProwlScript.NOTICE:
			for note in step.get("notes", []):
				toasts.append(String(note))
			var pending := toasts.duplicate()
			toasts = []
			_show_notices(pending, next)
		_:
			push_warning("prowl step %d has unknown type" % index)
			next.call()


## A story beat inside a prowl. Same vocabulary as the prologue's scenes —
## flags, choices, evidence, standing, growth — so a quest writer has one
## language to learn, not two.
func _run_prowl_story(step: Dictionary, on_done: Callable) -> void:
	if step.has("when_flag"):
		var gate: Dictionary = step["when_flag"]
		if int(profile["flags"].get(gate["flag"], -1)) != int(gate["value"]):
			on_done.call()
			return
	if ProwlScript.minigame_gate_blocks(step, last_minigame_won):
		on_done.call()
		return
	if ProwlScript.attempt_gate_blocks(step, quest_attempt):
		on_done.call()
		return
	if ProwlScript.fact_gate_blocks(step, profile.get("facts", {})):
		on_done.call()
		return
	# Facts are recorded the moment the page is SHOWN, not when the quest
	# ends — you have met Bodkin even if you die in the next alley. Saved
	# immediately for the same reason.
	if step.has("sets"):
		profile["facts"] = profile.get("facts", {})
		profile["facts"].merge(ProwlScript.facts_set_by(step), true)
		_save()
	_apply_scene_spine(step)
	if step.has("grant_growth"):
		_grant_growth(step["grant_growth"])
	if step.has("lead"):
		CaseState.mark_lead_done(profile, String(step["lead"]))
		_save()
	var config := _story_config(String(step.get("environment", "parlor_cold")), step["lines"])
	for key in ["portrait", "art_desc", "heading"]:
		if step.has(key):
			config[key] = step[key]
	# A Remembered Day inside a prowl: the same page, tinted and headed, with
	# choices refused (the validator guarantees none were written).
	if ProwlScript.type_of(step) == ProwlScript.FLASHBACK:
		config["flashback"] = true
		config["image_tint"] = step.get("image_tint", _flashback_tint())
		config["heading"] = "Remembered Day — %s" % step.get("title", "")
	if not step.has("choices"):
		_show_story(config, func(_i: int) -> void: on_done.call())
		return
	config["choices"] = step["choices"]
	_show_story(config, func(choice: int) -> void:
		if step.has("flag"):
			profile["flags"][step["flag"]] = choice
			_remember("choice_made", {}, {},
				{"choice": String(step["choices"][choice])})
			_save()
		on_done.call())


## A minigame as a prowl step. Losing one is never fatal and never blocks the
## quest — the module's own when_outcome prose says what it cost, and a
## scripted `on_loss_lines` says what Ash makes of it. A prowl that can
## dead-end on a puzzle is a prowl that eats a satchel (law 13).
func _run_prowl_minigame(step: Dictionary, on_done: Callable) -> void:
	var module := String(step.get("module", ""))
	var content_id := String(step.get("id", ""))
	var after := func(won: bool) -> void:
		last_minigame_won = won
		var lines: Array = step.get("on_win_lines" if won else "on_loss_lines", [])
		if lines.is_empty():
			on_done.call()
		else:
			_show_story(_story_config(String(step.get("environment", "parlor_cold")),
				lines), func(_i: int) -> void: on_done.call())
	_launch_minigame(module, content_id, after)


func _on_prowl_battle_done(state: CombatState) -> void:
	_digest(state)
	match state.outcome:
		CombatState.Outcome.VICTORY:
			# Depth is counted in FIGHTS, not steps: walking to the Ratsmeet
			# is not danger and must not inflate the satchel multiplier.
			var mult := 1.0 + _press_on_mult() * ProwlScript.depth_at(quest, encounter_index)
			var earned := int(ceil(int(catalog.enemies[state.enemy_id].get("gleam", 0)) * mult))
			satchel += earned
			if ProwlScript.has_battle_after(quest, encounter_index):
				_offer_press_on(earned)
			else:
				_run_step(encounter_index + 1)
		CombatState.Outcome.DEFEAT:
			_prowl_defeat()
		CombatState.Outcome.RETREATED:
			_prowl_retreat()


func _offer_press_on(just_earned: int) -> void:
	# The card previews the next FIGHT, which may be several story beats away
	# — pressing on past a conversation is still pressing on.
	var next_encounter: Dictionary = catalog.encounters[
		ProwlScript.next_battle_after(quest, encounter_index)]
	var next_enemy: Dictionary = catalog.enemies[next_encounter["enemies"][0]]
	var environment: Dictionary = catalog.environments[next_encounter["environment"]]
	var danger := "•".repeat(clampi(int(next_enemy["hp"]) / 4, 1, 5))
	_show_story({
		# Book-keeping is the GAME talking, so it takes the rules face, not
		# Ash's narration voice (owner 2026-08-05: "+4 Gleam Satchel 4 needs
		# to be in a different font as it is not story, and it needs to be
		# explained"). The wager underneath is Ash, and stays his.
		"lines": [
			{"text": Strings.line("prowl.press_on.earned", [satchel, just_earned]),
				"rule": true},
			{"text": Strings.line("prowl.press_on.ahead", [next_encounter["name"],
				danger, environment.get("rule_text", "")]), "rule": true},
			Strings.line("prowl.press_on.wager"),
		],
		"color": environment.get("color", "#22242a"),
		"accent": environment.get("accent", "#d8ccb4"),
		"heading": environment.get("name", ""),
		"choices": [Strings.line("prowl.press_on.press"),
			Strings.line("prowl.press_on.slip", [
				satchel - int(floor(satchel * _slip_forfeit())), satchel])],
	}, func(choice: int) -> void:
		if choice == 0:
			tracker.increment("pressed_on")
			_run_step(encounter_index + 1)
		else:
			_prowl_retreat())


func _finish_quest() -> void:
	var bonus := int(quest.get("reward_bonus", 0))
	var banked := satchel + bonus
	profile["gleam"] = int(profile["gleam"]) + banked
	# Not every job pays (owner 2026-08-09: gleam with no diegetic source is a
	# canon bug). A quest that banked nothing says so plainly instead of
	# reporting a zero like a till receipt.
	if banked > 0:
		_remember("quest_done", {"quest": String(quest["id"])}, {"gleam": banked})
	else:
		_remember("quest_done_quiet", {"quest": String(quest["id"])})
	if quest.has("unlock_skill") and not profile["skills"].has(quest["unlock_skill"]):
		_grant_skills([quest["unlock_skill"]])
	# Standing and knots are paid ONCE per quest, even for repeatable ones:
	# reputation is not a grind, and a farmable guild meter would make every
	# `requires.standing` gate meaningless.
	if QuestGate.mark_done(profile, String(quest["id"])):
		# A quest may open a door in the Mantel (QuestGate.doors reads these).
		# Finding the Magpie is what makes the Exchange a place Ash knows,
		# rather than a shop that was always in his parlor.
		for flag in quest.get("set_flags", {}):
			profile["flags"][flag] = quest["set_flags"][flag]
		if quest.has("standing"):
			for line in CaseState.apply_standing(catalog, profile, quest["standing"]):
				toasts.append("❋ %s" % line)
		if quest.has("grant_favor") and CaseState.grant_favor(
				profile, String(quest["grant_favor"])):
			toasts.append("✦ A knot in your thread: %s" %
				catalog.favors[quest["grant_favor"]]["name"])
	for evidence_id in quest.get("grant_evidence", []):
		_find_evidence(String(evidence_id))
	if quest.has("lead"):
		CaseState.mark_lead_done(profile, String(quest["lead"]))
	for id in tracker.increment("quests_completed"):
		toasts.append("★ %s" % catalog.achievements[id]["name"])
	for id in tracker.increment("gleam_banked", banked):
		toasts.append("★ %s" % catalog.achievements[id]["name"])
	_save()
	var finish_lines: Array = Strings.lines("prowl.finish", [banked, satchel, bonus]) \
		if banked > 0 else Strings.lines("prowl.finish_quiet")
	_show_story(_story_config("parlor_cold", finish_lines),
		func(_i: int) -> void: _show_hub())


## Slipping away has a PRICE (owner rule 2026-08-03 — "there is still no
## consequence to slipping away"). Two of them, in fact: the enemy's parting
## move lands in CombatState, and going over the wall in a hurry spills half
## the satchel. Pressing on one more room is a real bet again.
## The fraction is data/rules.json `prowl.slip_forfeit`.
func _prowl_retreat() -> void:
	var dropped := int(floor(satchel * _slip_forfeit()))
	var kept := satchel - dropped
	profile["gleam"] = int(profile["gleam"]) + kept
	if not quest.is_empty():
		_remember("quest_withdrawn", {"quest": String(quest["id"])})
	if kept > 0:
		for id in tracker.increment("gleam_banked", kept):
			toasts.append("★ %s" % catalog.achievements[id]["name"])
	_save()
	var lines: Array = Strings.lines("prowl.retreat", [kept])
	if dropped > 0:
		lines.append(Strings.line("prowl.retreat_dropped", [dropped]))
	lines.append(Strings.line("prowl.retreat_tail"))
	_show_story(_story_config("parlor_cold", lines),
		func(_i: int) -> void: _show_hub())


## Defeat forks on what the fight WAS (docs/design/death-and-lives.md): a
## `mortal` beat is a true death and spends a life; anything else is an
## unscheduled arrival the Court refuses. _digest has already filed the
## stats and the chronicle — this only decides which desk scene plays.
func _prowl_defeat() -> void:
	if last_defeat_mortal:
		_prowl_death()
	else:
		_prowl_refusal()


func _prowl_death() -> void:
	var first_ever: bool = int(tracker.stats.get("lives_spent", 0)) <= 1
	var toll := 0
	if not first_ever:
		toll = int(ceil(int(profile["gleam"]) * _toll_rate()))
		profile["gleam"] = int(profile["gleam"]) - toll
	_save()
	var extra: Array = []
	if toll > 0:
		extra.append({"text": Strings.line("prowl.toll", [toll]), "rule": true})
	_show_hollow_court(_show_hub, extra)


## An ordinary defeat: the Court refuses the death and takes a filing fee —
## smaller than the Toll, but a defeat that costs nothing teaches nothing.
## The satchel is simply never banked, same as a death.
func _prowl_refusal() -> void:
	var fee := int(ceil(int(profile["gleam"]) * _refusal_rate()))
	profile["gleam"] = int(profile["gleam"]) - fee
	_save()
	var extra: Array = []
	if fee > 0:
		extra.append({"text": Strings.line("prowl.refusal_fee", [fee]), "rule": true})
	_show_court_refused(_show_hub, extra)


## The REFUSED stamp, played as a desk scene like every other visit. The
## first refusal is the one that TEACHES (its page carries the rule line);
## after that the variants rotate, because this is a screen a struggling
## player will see often and a refusal that reads exactly like the last one
## tells them nothing happened (law 15). Two variants carry planted clues —
## see docs/design/the-unraveler.md before editing ANY of them.
func _show_court_refused(on_done: Callable, extra_lines: Array = []) -> void:
	var refusals := int(tracker.stats.get("refusals", 0))
	var visits: Array = story["hollow_court_refused"]
	var index := 0
	if refusals > 1 and visits.size() > 1:
		index = 1 + ((refusals - 2) % (visits.size() - 1))
	var pages: Array = [visits[index].duplicate(true)] if visits[index] is Dictionary \
		else Array(visits[index]).duplicate(true)
	if not extra_lines.is_empty() and not pages.is_empty():
		var last: Dictionary = pages[pages.size() - 1]
		last["lines"] = Array(last["lines"]) + extra_lines
	_play_pages(pages, 0, on_done)
