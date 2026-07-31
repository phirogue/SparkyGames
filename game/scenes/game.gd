extends Control
## Game flow orchestrator: prologue script -> hub -> quest prowls.
## Owns the profile, the achievement tracker, and all screen transitions.
## Screens are dumb; this file is the only place that decides "what next".

const StoryScreen := preload("res://scenes/story_screen.gd")
const BattleScreen := preload("res://scenes/battle.gd")
const HubScreen := preload("res://scenes/hub_screen.gd")
const SplashScreen := preload("res://scenes/splash_screen.gd")
const JournalScreen := preload("res://scenes/journal_screen.gd")

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


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("100e0c"))  # the book's dark edge
	theme = UITheme.build()  # storybook theme; every child screen inherits
	catalog = DataLoader.load_catalog()
	tour_mode = OS.get_cmdline_user_args().has("--tour")
	if tour_mode:
		# Screenshot tour: throwaway profile, never touches the real save.
		profile = SaveService.DEFAULT_PROFILE.duplicate(true)
	else:
		profile = SaveService.load_profile()
	tracker = AchievementTracker.new(catalog)
	tracker.from_dict(profile.get("achievements", {}))
	var file := FileAccess.open("res://story/prologue.json", FileAccess.READ)
	story = JSON.parse_string(file.get_as_text())
	if tour_mode:
		add_child(load("res://tests/tour.gd").new())
		_run_prologue_scene(0)
	else:
		var splash: Control = SplashScreen.new()
		splash.finished.connect(func() -> void:
			if profile["prologue_done"]:
				_show_hub()
			else:
				_run_prologue_scene(0))
		_swap(splash)


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
	var all_lines := toasts + lines
	toasts = []
	var config := {
		"lines": all_lines,
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


func _show_story(config: Dictionary, on_done: Callable) -> void:
	var screen: Control = StoryScreen.new()
	screen.setup(config)
	screen.finished.connect(on_done)
	_swap(screen)


func _show_battle(encounter_id: String, on_done: Callable, hints: Dictionary = {},
		extra: Dictionary = {}, coach: Array = []) -> void:
	_last_encounter_env = catalog.encounters[encounter_id]["environment"]
	var config := {
		"player_max_hp": int(profile["max_hp"]),
		"player_hp": carryover.get("hp", int(profile["max_hp"])),
		"deck": carryover.get("deck", profile["deck"]),
		"skills": profile["skills"],
		"lingering": carryover.get("lingering", []),
	}
	if carryover.has("skill_charges"):
		config["skill_charges"] = carryover["skill_charges"]
	config.merge(extra, true)
	var screen: Control = BattleScreen.new()
	screen.setup(catalog, config, encounter_id, hints, coach)
	screen.encounter_finished.connect(on_done)
	_swap(screen)


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
		carryover = {
			"hp": state.player_hp,
			"deck": state.deck + state.hand + state.banked,
			"skill_charges": charges,
			"lingering": state.lingering_out(),
		}
	_save()


func _save() -> void:
	if tour_mode:
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
	match scene["type"]:
		"story":
			if scene.has("grant"):
				_grant_skills(scene["grant"])
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
				# Tutorial stage: fixed teaching deck, fresh charges.
				extra["deck"] = scene["deck"]
				extra["skill_charges"] = {}
			if scene.has("shuffle"):
				extra["shuffle"] = scene["shuffle"]
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
