extends Control
## Game flow orchestrator: prologue script -> hub -> quest prowls.
## Owns the profile, the achievement tracker, and all screen transitions.
## Screens are dumb; this file is the only place that decides "what next".

const StoryScreen := preload("res://scenes/story_screen.gd")
const BattleScreen := preload("res://scenes/battle.gd")
const HubScreen := preload("res://scenes/hub_screen.gd")
const SplashScreen := preload("res://scenes/splash_screen.gd")
const JournalScreen := preload("res://scenes/journal_screen.gd")
const CaseBoardScreen := preload("res://scenes/case_board_screen.gd")
const DevMenuScreen := preload("res://scenes/dev_menu_screen.gd")
const StitchScreen := preload("res://scenes/minigames/stitch_screen.gd")
const TestimonyScreen := preload("res://scenes/minigames/testimony_screen.gd")
const WardScreen := preload("res://scenes/minigames/ward_screen.gd")
const LatticeScreen := preload("res://scenes/minigames/lattice_screen.gd")
const CrossingScreen := preload("res://scenes/minigames/crossing_screen.gd")

## The remembered-day tint: one sepia constant, used by every flashback so
## memory reads the same everywhere (a scene may override with image_tint).
const FLASHBACK_TINT := "#d9b689"

const PRESS_ON_MULT := 0.25   # satchel multiplier growth per depth
const TOLL_RATE := 0.25       # the Hollow Court's cut of banked gleam on death

var catalog: Catalog
var profile: Dictionary
var tracker: AchievementTracker
var story: Dictionary          # story/prologue.json

var current_screen: Control
var toasts: Array[String] = [] # achievement lines to surface on the next story screen

# Prowl state
var quest: Dictionary = {}
var encounter_index := 0
var satchel := 0
var carryover: Dictionary = {}
var last_outcome := CombatState.Outcome.ONGOING


var tour_mode := false
var dev_mode := false   # component runner / scenario: throwaway world
var _dev_seed := 0      # scenario-pinned battle seed (0 = clock-random)
var settings_layer: CanvasLayer
var settings_overlay: Control
var volume_slider: HSlider


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
		# Screenshot tour: throwaway profile, never touches the real save.
		profile = SaveService.DEFAULT_PROFILE.duplicate(true)
	else:
		profile = SaveService.load_profile()
	tracker = AchievementTracker.new(catalog)
	tracker.from_dict(profile.get("achievements", {}))
	var file := FileAccess.open("res://story/prologue.json", FileAccess.READ)
	var parsed: Variant = null if file == null else JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_fatal("This copy of the game is missing its story.\n(story/prologue.json)")
		return
	story = parsed
	_build_settings_layer()
	# The tour node attaches BEFORE the first screen is swapped in, and
	# regardless of how the game is launched: `--tour --scene scenario:<name>`
	# photographs a scenario's screens, which is the only way to get shots of
	# states the prologue never reaches (a case mid-chapter, a flashback).
	if tour_mode:
		add_child(load("res://tests/tour.gd").new())
	var dev_scene := _cmdline_value("--scene")
	if dev_scene != "":
		# Component runner (owner rule 2026-08-01): jump straight to one
		# piece of the game on a throwaway profile — no full playthrough
		# needed to test one screen. See CLAUDE.md for specs.
		dev_mode = true  # throwaway world: never write the real save
		profile = SaveService.DEFAULT_PROFILE.duplicate(true)
		_dev_launch(dev_scene)
	elif tour_mode:
		# The tour walks the splash and title too, for screenshot coverage.
		var tour_splash: Control = SplashScreen.new()
		tour_splash.finished.connect(func() -> void:
			_show_title(func() -> void: _run_prologue_scene(0)), CONNECT_ONE_SHOT)
		_swap(tour_splash)
	else:
		var splash: Control = SplashScreen.new()
		splash.finished.connect(func() -> void:
			_show_title(func() -> void:
				if profile["prologue_done"]:
					_show_recap(_show_hub)
				else:
					_run_prologue_scene(0)), CONNECT_ONE_SHOT)
		_swap(splash)


func _cmdline_value(flag: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(flag)
	if index >= 0 and index + 1 < args.size():
		return args[index + 1]
	return ""


## Jump straight into one component: "hub", "title", "journal", "case",
## "recap", "story:<scene index>", "battle:<encounter_id>[:skill,skill,...]",
## "quest:<quest_id>", or "scenario:<name>" (full Ash setup from
## tests/scenarios/<name>.json — see that folder's README).
func _dev_launch(spec: String) -> void:
	var parts := spec.split(":")
	match parts[0]:
		"hub":
			profile["prologue_done"] = true
			_show_hub()
		"title":
			_show_title(func() -> void: get_tree().quit())
		"journal":
			_show_journal()
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
	tracker = AchievementTracker.new(catalog)
	tracker.from_dict(profile.get("achievements", {}))
	# A scenario may carry its OWN story scenes, which is how a story system
	# gets exercised before the chapter that uses it is written: the spec
	# becomes the scene list `story:<index>` walks. Same schema as
	# story/prologue.json.
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


func _story_config(environment_id: String, lines: Array) -> Dictionary:
	var environment: Dictionary = catalog.environments.get(environment_id, {})
	var config := {
		"lines": lines,
		"color": environment.get("color", "#22242a"),
		"accent": environment.get("accent", "#d8ccb4"),
		"heading": environment.get("name", ""),
	}
	if environment.has("image"):
		config["image"] = environment["image"]
	if environment.has("image_tint"):
		config["image_tint"] = environment["image_tint"]
	if environment_id == "hollow_court":
		config["portrait"] = "npc_clerk"
	return config


## Settings live on a CanvasLayer so they are reachable from ANY screen
## (owner rule 2026-08-01) — the layer floats above whatever is swapped in.
func _build_settings_layer() -> void:
	settings_layer = CanvasLayer.new()
	settings_layer.layer = 10
	add_child(settings_layer)
	var gear := Button.new()
	gear.flat = true
	gear.custom_minimum_size = Vector2(52, 52)
	gear.position = Vector2(8, 8)
	gear.size = Vector2(52, 52)
	gear.tooltip_text = "Settings"
	gear.pressed.connect(_open_settings)
	var glyph := MenuGlyph.new()
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear.add_child(glyph)
	settings_layer.add_child(gear)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.07, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	settings_layer.add_child(dim)
	settings_overlay = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	panel.theme = UITheme.build()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_override("font", UITheme.display_font())
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UITheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var vol_label := Label.new()
	vol_label.text = "Sound"
	vol_label.add_theme_font_size_override("font_size", 28)
	vol_label.add_theme_color_override("font_color", UITheme.INK)
	box.add_child(vol_label)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.custom_minimum_size = Vector2(0, 48)
	volume_slider.value_changed.connect(func(value: float) -> void:
		_apply_volume(value))
	box.add_child(volume_slider)
	var close := Button.new()
	close.text = "Back to the night"
	close.custom_minimum_size = Vector2(0, 96)
	close.pressed.connect(func() -> void:
		var settings: Dictionary = profile.get("settings", {})
		settings["volume"] = volume_slider.value
		profile["settings"] = settings
		_save()
		settings_overlay.visible = false)
	box.add_child(close)
	_apply_volume(float(profile.get("settings", {}).get("volume", 1.0)))


func _open_settings() -> void:
	volume_slider.set_value_no_signal(
		float(profile.get("settings", {}).get("volume", 1.0)))
	settings_overlay.visible = true


func _apply_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(0, value <= 0.0)


## Title card between the studio splash and the game. Uses the painted
## title logo once it exists (regen pending: current art reads "of of");
## until then the title is typeset live.
func _show_title(on_continue: Callable) -> void:
	var screen := Control.new()
	screen.name = "TitleScreen"
	var bg := ColorRect.new()
	bg.color = Color("14110e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)
	var tap := Button.new()
	tap.flat = true
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap.pressed.connect(func() -> void: on_continue.call(), CONNECT_ONE_SHOT)
	screen.add_child(tap)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	var title_art := UITheme.tex("ui/logo_ashcat_title")
	if title_art != null:
		var art := TextureRect.new()
		art.texture = title_art
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# The painted title is a tall poster; give it most of the screen.
		art.custom_minimum_size = Vector2(560, 960)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(art)
	else:
		for part in [["The Nine Lives", 64], ["of ASHCAT", 88]]:
			var line := Label.new()
			line.text = part[0]
			line.add_theme_font_override("font", UITheme.display_font())
			line.add_theme_font_size_override("font_size", part[1])
			line.add_theme_color_override("font_color", Color("e8dcc0"))
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(line)
	var hint := Label.new()
	hint.text = "— tap to begin —"
	hint.add_theme_font_override("font", UITheme.italic_font())
	hint.add_theme_font_size_override("font_size", 30)
	hint.add_theme_color_override("font_color", Color("8f8577"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hint)
	var tween := screen.create_tween().set_loops()
	tween.tween_property(hint, "modulate:a", 0.4, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(hint, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	_swap(screen)


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
	screen.finished.connect(on_done)
	_swap(screen)


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
	}
	if carryover.has("skill_charges"):
		config["skill_charges"] = carryover["skill_charges"]
	if _dev_seed != 0:
		config["seed"] = _dev_seed
	config.merge(extra, true)
	var screen: Control = BattleScreen.new()
	screen.setup(catalog, config, encounter_id, hints, coach)
	screen.encounter_finished.connect(on_done)
	_swap(screen)


## The skills that actually enter a battle — the player's chosen loadout
## (edited at the Mantel), resolved by SaveService.battle_loadout so the
## rule is testable without a scene tree.
func _battle_loadout() -> Array:
	return SaveService.battle_loadout(profile)


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
			profile["journal"].append("Found: %s" % entry["name"])
			break
	return true


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
		profile["journal"].append("Spent a life to %s. The Court noted it." %
			catalog.enemies[state.enemy_id]["name"])
	for id in tracker.record_encounter(state):
		toasts.append("★ %s — %s" % [
			catalog.achievements[id]["name"], catalog.achievements[id]["description"],
		])
	if state.outcome == CombatState.Outcome.DEFEAT:
		carryover = {}  # a new life: full deck, full charges, full hp
	else:
		var charges := {}
		for s in state.skills:
			charges[s["id"]] = s["charges_left"]
		# The pool persists between encounters (owner rule: no reset until
		# a rest); spent stays spent — EXCEPT one breath back with a win.
		var pool: Array = state.deck + state.hand + state.banked
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
			"lingering": state.lingering_out(),
		}
	_save()


func _save() -> void:
	# Tour AND component-runner/scenario worlds are throwaway — writing them
	# would clobber the player's real profile with test state.
	if tour_mode or dev_mode:
		return
	profile["achievements"] = tracker.to_dict()
	SaveService.save_profile(profile)


# ------------------------------------------------------------------ prologue

func _run_prologue_scene(index: int) -> void:
	var scenes: Array = story["scenes"]
	if index >= scenes.size():
		if not profile["prologue_done"]:
			profile["prologue_done"] = true
			# Endowed progress: the Casebook opens already inscribed.
			profile["journal"].append("The night the kettle screamed. Elspeth is gone. The thread leads into the city.")
		_save()
		_show_hub()
		return
	var scene: Dictionary = scenes[index]
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
				profile["deck"].append(scene["add_card"])
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
						profile["journal"].append("Chose: %s" % String(scene["choices"][choice]))
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
				# Tutorial opener: fixed teaching deck, fresh charges.
				extra["deck"] = scene["deck"]
				extra["skill_charges"] = {}
			elif scene.has("add_cards"):
				# New energy joins the CARRIED pool (appended last so an
				# unshuffled battle opens with exactly these cards).
				var pool: Array = carryover.get("deck", profile["deck"].duplicate())
				pool.append_array(scene["add_cards"])
				carryover["deck"] = pool
			if scene.has("shuffle"):
				extra["shuffle"] = scene["shuffle"]
			if scene.has("skills"):
				# Loadout law: a battle can pin the carried kit (max 4 with
				# Scratch) even when the profile owns more skills.
				extra["skills"] = scene["skills"]
			if scene.get("no_approach", false):
				extra["no_approach"] = true
			_show_battle(scene["encounter"], func(state: CombatState) -> void:
				_digest(state)
				_run_prologue_scene(index + 1),
				scene.get("hints", {}), extra, scene.get("coach", []))
		"hollow_court_if_died":
			if last_outcome == CombatState.Outcome.DEFEAT:
				var lines: Array = story["hollow_court_first"] \
					if int(tracker.stats.get("lives_spent", 0)) <= 1 \
					else story["hollow_court_repeat"]
				_show_story(_story_config("hollow_court", lines), next)
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
			flash["image_tint"] = scene.get("image_tint", FLASHBACK_TINT)
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
				"lines": ["THE NINE LIVES OF ASHCAT", "Prologue complete. The Mantel is open."],
				"color": "#1c2026", "big": true,
				"portrait": "sc_title",
			}, next)


# ------------------------------------------------------------------ hub & prowls

func _show_hub() -> void:
	var screen: Control = HubScreen.new()
	screen.setup(catalog, profile, tracker)
	screen.quest_selected.connect(_start_quest)
	screen.profile_changed.connect(_save)
	screen.open_journal.connect(_show_journal)
	screen.open_case_board.connect(_show_case_board)
	screen.replay_prologue.connect(func() -> void:
		carryover = {}
		last_outcome = CombatState.Outcome.ONGOING
		_run_prologue_scene(0))
	_swap(screen)


func _show_journal() -> void:
	var screen: Control = JournalScreen.new()
	screen.setup(catalog, profile)
	screen.closed.connect(_show_hub)
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


func _show_stitch(chart_id: String) -> void:
	if not catalog.stitch_charts.has(chart_id):
		push_error("unknown stitch chart '%s'" % chart_id)
		return
	var screen: Control = StitchScreen.new()
	screen.setup(catalog.stitch_charts[chart_id])
	screen.closed.connect(_minigame_done())
	_swap(screen)


func _show_testimony(testimony_id: String) -> void:
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
	screen.closed.connect(_minigame_done())
	_swap(screen)


func _show_ward(ward_id: String) -> void:
	if not catalog.wards.has(ward_id):
		push_error("unknown ward '%s'" % ward_id)
		return
	var screen: Control = WardScreen.new()
	screen.setup(catalog, catalog.wards[ward_id],
		carryover.get("deck", profile["deck"]))
	screen.closed.connect(_minigame_done())
	_swap(screen)


func _show_lattice(lattice_id: String) -> void:
	if not catalog.lattices.has(lattice_id):
		push_error("unknown lattice '%s'" % lattice_id)
		return
	var screen: Control = LatticeScreen.new()
	screen.setup(catalog.lattices[lattice_id])
	screen.closed.connect(_minigame_done())
	_swap(screen)


func _show_crossing(crossing_id: String) -> void:
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
	screen.closed.connect(_minigame_done())
	_swap(screen)


## Developer mode: one screen that reaches every part of the game. Dev mode
## is a THROWAWAY world (never writes the real save), which is what makes it
## safe to jump anywhere and quit whenever.
func _show_dev_menu() -> void:
	dev_mode = true
	var screen: Control = DevMenuScreen.new()
	screen.setup(catalog, story)
	screen.jump.connect(func(spec: String) -> void: _dev_launch(spec))
	_swap(screen)


func _show_case_board() -> void:
	var screen: Control = CaseBoardScreen.new()
	screen.setup(catalog, profile)
	screen.closed.connect(_show_hub)
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
	var encounter: Dictionary = catalog.encounters[quest["encounters"][0]]
	_show_story(_story_config(encounter["environment"], [quest["board_card"], "Out the window, then."]),
		func(_i: int) -> void: _next_encounter())


func _next_encounter() -> void:
	_show_battle(quest["encounters"][encounter_index], _on_prowl_battle_done)


func _on_prowl_battle_done(state: CombatState) -> void:
	_digest(state)
	match state.outcome:
		CombatState.Outcome.VICTORY:
			var mult := 1.0 + PRESS_ON_MULT * encounter_index
			var earned := int(ceil(int(catalog.enemies[state.enemy_id].get("gleam", 0)) * mult))
			satchel += earned
			if encounter_index >= quest["encounters"].size() - 1:
				_finish_quest()
			else:
				_offer_press_on(earned)
		CombatState.Outcome.DEFEAT:
			_prowl_death()
		CombatState.Outcome.RETREATED:
			_prowl_retreat()


func _offer_press_on(just_earned: int) -> void:
	var next_encounter: Dictionary = catalog.encounters[quest["encounters"][encounter_index + 1]]
	var next_enemy: Dictionary = catalog.enemies[next_encounter["enemies"][0]]
	var environment: Dictionary = catalog.environments[next_encounter["environment"]]
	var danger := "•".repeat(clampi(int(next_enemy["hp"]) / 4, 1, 5))
	_show_story({
		"lines": [
			"+%d gleam. Satchel: %d." % [just_earned, satchel],
			"Ahead: %s — danger %s\n%s" % [next_encounter["name"], danger, environment.get("rule_text", "")],
			"Deeper pays better. Deeper also bites.",
		],
		"color": environment.get("color", "#22242a"),
		"accent": environment.get("accent", "#d8ccb4"),
		"heading": environment.get("name", ""),
		"choices": ["Press On", "Slip Away (bank %d)" % satchel],
	}, func(choice: int) -> void:
		if choice == 0:
			tracker.increment("pressed_on")
			encounter_index += 1
			_next_encounter()
		else:
			_prowl_retreat())


func _finish_quest() -> void:
	var bonus := int(quest.get("reward_bonus", 0))
	var banked := satchel + bonus
	profile["gleam"] = int(profile["gleam"]) + banked
	profile["journal"].append("%s: done. %d gleam banked." % [quest["name"], banked])
	if quest.has("unlock_skill") and not profile["skills"].has(quest["unlock_skill"]):
		_grant_skills([quest["unlock_skill"]])
	# Standing and knots are paid ONCE per quest, even for repeatable ones:
	# reputation is not a grind, and a farmable guild meter would make every
	# `requires.standing` gate meaningless.
	if QuestGate.mark_done(profile, String(quest["id"])):
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
	_show_story(_story_config("parlor_cold", [
		"Done. %d gleam banked (%d satchel + %d for the trouble)." % [banked, satchel, bonus],
		"The Mantel waits. So does the thread.",
	]), func(_i: int) -> void: _show_hub())


func _prowl_retreat() -> void:
	profile["gleam"] = int(profile["gleam"]) + satchel
	if not quest.is_empty():
		profile["journal"].append("Withdrew from %s. The quest keeps." % quest["name"])
	if satchel > 0:
		for id in tracker.increment("gleam_banked", satchel):
			toasts.append("★ %s" % catalog.achievements[id]["name"])
	_save()
	_show_story(_story_config("parlor_cold", [
		"Home by the gutters. %d gleam banked." % satchel,
		"The quest keeps. Quests do. It is one of their few virtues.",
	]), func(_i: int) -> void: _show_hub())


func _prowl_death() -> void:
	var first_ever: bool = int(tracker.stats.get("lives_spent", 0)) <= 1
	var toll := 0
	if not first_ever:
		toll = int(ceil(int(profile["gleam"]) * TOLL_RATE))
		profile["gleam"] = int(profile["gleam"]) - toll
	_save()
	var lines: Array = story["hollow_court_repeat"].duplicate()
	if first_ever:
		lines = story["hollow_court_first"].duplicate()
	elif toll > 0:
		lines.append("(The Toll: %d gleam. The satchel: wherever you dropped it.)" % toll)
	_show_story(_story_config("hollow_court", lines),
		func(_i: int) -> void: _show_hub())
