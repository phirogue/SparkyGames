extends Node
## Screenshot tour: drives the real rendered game and saves PNGs of every
## screen so layout can be inspected without a human tapping through.
## Launch:  godot --path game -- --tour
## Output:  <repo>/screenshots/NN_name.png   (window closes when done)
##
## A scenario can be photographed instead of the prologue, which is the only
## way to shoot states the prologue never reaches (a case mid-chapter, a
## flashback). Send those somewhere of their own so they do not overwrite
## the canonical tour:
##   godot --path game -- --tour --tour-out spine --scene scenario:ch1_spine_demo
##
## The tour uses a throwaway profile (never touches the real save) and
## interacts by calling the same handlers taps would.

var game: Node
var shot_index := 0
var out_dir: String = ""
var _last_screen: Control = null
var _story_taps := 0
var _did_card_modal := false
var _did_concentrate := false
var _did_spool_modal := false
var _did_partial_charge := false
var _did_no_escape := false
var _did_chronicle_shot := false
var _battle_taps := 0
## Layout defects found while shooting. Reported at the end and made the
## tour's exit code, so tools/tour_all.py can fail a sweep on them.
var layout_problems: Array[String] = []


func _ready() -> void:
	game = get_parent()
	var tag := String(game._cmdline_value("--tour-out"))
	out_dir = ProjectSettings.globalize_path("res://") + "../screenshots/" \
		+ ("%s/" % tag if tag != "" else "")
	DirAccess.make_dir_recursive_absolute(out_dir)
	set_process(false)
	_run()


func _run() -> void:
	await _wait(0.6)
	while is_instance_valid(game) and game.current_screen != null:
		var screen: Control = game.current_screen
		var fresh := screen != _last_screen
		_last_screen = screen
		if fresh:
			_story_taps = 0
		var script_ref: Variant = screen.get_script()
		var script_path: String = script_ref.resource_path if script_ref != null else ""
		if screen.name == "TitleScreen" or screen.name == "NoticeScreen":
			await _shot("title" if screen.name == "TitleScreen" else "notices")
			for child in screen.get_children():
				if child is Button:
					child.pressed.emit()
					break
		elif script_path.ends_with("splash_screen.gd"):
			await _shot("splash")
			screen.finished.emit()
		elif script_path.ends_with("story_screen.gd"):
			await _tour_story(screen, fresh)
		elif script_path.ends_with("battle.gd"):
			await _tour_battle(screen, fresh)
		elif script_path.ends_with("case_board_screen.gd"):
			# Reached when the board is launched directly (--scene case);
			# the hub route drives it through _tour_case_board instead.
			await _shot("case_board")
			break
		elif script_path.contains("/minigames/"):
			await _tour_minigame(screen, script_path)
			break
		elif script_path.ends_with("hub_screen.gd"):
			# The first-visit walkthrough of the room, one shot a step. It has
			# to be photographed BEFORE the doors are forced open below, since
			# what it points at is a room with almost nothing in it yet.
			while screen.coach != null and screen.coach.active():
				await _shot("mantel_coach")
				screen.coach.force_advance()
				await _wait(0.2)
			await _shot("hub")
			# Reading a note off the board: the take-or-back popup that now
			# stands between a tap and a night's work (owner 2026-08-08).
			var board: Array = QuestGate.board(game.catalog, game.profile)
			if not board.is_empty():
				screen._open_note(board[0])
				await _wait(0.45)
				await _shot("hub_quest_note")
				screen._close_note()
				await _wait(0.3)
			await _tour_lessons()
			await _tour_case_board()
			await _tour_market_and_kit()
			game._open_settings()
			await _wait(0.4)
			await _shot("settings")
			# Both toggle states have to be photographed: the OFF art is a
			# different picture, not a modulate of the ON one.
			game.settings_overlay._on_toggle("music")
			game.settings_overlay._on_toggle("lamps_low")
			game.settings_overlay._on_volume_step(3)
			await _wait(0.35)
			await _shot("settings_changed")
			game.settings_overlay._on_toggle("lamps_low")
			game.settings_overlay.visible = false
			break
		else:
			await _shot("unknown_screen")
			break
		await _wait(0.25)
	await _shot("final")
	if layout_problems.is_empty():
		get_tree().quit(0)
		return
	printerr("%d LAYOUT DEFECT(S) — content outside the page:" % layout_problems.size())
	for problem in layout_problems:
		printerr("  ", problem)
	get_tree().quit(2)



## Every mission minigame, photographed: its tutorial, its board, one real
## move, and the card it ends on. Nothing here was in the tour before, which
## is how a stitch grid with no right-hand edge and three modules that taught
## nothing all reached an owner review (law 2, owner 2026-08-09).
func _tour_minigame(screen: Control, script_path: String) -> void:
	var module := script_path.get_file().replace("_screen.gd", "")
	await _wait(0.5)
	# The lesson plays itself on a fresh profile. Shoot every step of it.
	var guard := 0
	while screen.coach != null and screen.coach.active() and guard < 20:
		await _shot("%s_lesson" % module)
		screen.coach.force_advance()
		await _wait(0.2)
		guard += 1
	await _wait(0.3)
	await _shot("%s_board" % module)
	match module:
		"stitch": await _tour_stitch(screen)
		"ward": await _tour_ward(screen)
		"lattice": await _tour_lattice(screen)
		"crossing": await _tour_crossing(screen)
		"testimony": await _tour_testimony(screen)
	await _shot("%s_end" % module)


## Squint's callout, a half-sewn seam, and the seam closing — the three
## states of the board that are not "an empty grid".
func _tour_stitch(screen: Control) -> void:
	screen._on_squint()
	await _wait(0.3)
	await _shot("stitch_squint")
	var solution: Array = screen.chart.get("solution", [])
	for i in solution.size():
		screen.state.do_command({"type": "sew", "edge": String(solution[i])})
		if i == solution.size() - 2:
			screen._refresh()
			await _wait(0.25)
			await _shot("stitch_nearly")
	screen._refresh()
	await _wait(1.1)   # the seam cinches before the outcome card arrives


## A patch carried out of the rack and dropped on the tear: the drag the
## owner asked for, photographed mid-air and after it lands.
func _tour_ward(screen: Control) -> void:
	var move: Dictionary = screen.state.best_placement()
	if move.is_empty():
		return
	var canvas = screen._canvas
	var rack_index := 0
	for i in screen.state.rack.size():
		if String(screen.state.rack[i]["id"]) == String(move["patch"]):
			rack_index = i
	screen.on_press(canvas._rack_rects[rack_index].get_center())
	await _wait(0.2)
	await _shot("ward_picked_up")
	var target: Vector2 = canvas._origin + Vector2(
		(int(move["col"]) + 0.5) * canvas._step,
		(int(move["row"]) + 0.5) * canvas._step)
	screen.on_motion(target)
	await _wait(0.2)
	await _shot("ward_dragging")
	screen.on_release(target)
	await _wait(0.3)
	await _shot("ward_placed")
	screen.state.do_command({"type": "finish"})
	screen._refresh()
	await _wait(0.4)


## One clean pull and one twang, so the alarm and the flash both get shot.
func _tour_lattice(screen: Control) -> void:
	var free := ""
	var trapped := ""
	for thread_id in screen.state.remaining():
		if screen.state.can_pull(thread_id):
			free = thread_id if free == "" else free
		else:
			trapped = thread_id if trapped == "" else trapped
	# Named, not aimed: thread midpoints sit close enough together that a
	# coordinate tap photographed a clean pull and called it a twang.
	if trapped != "":
		screen.pull_thread(trapped)
		await _wait(0.3)
		await _shot("lattice_twang")
	if free != "":
		screen.pull_thread(free)
		await _wait(0.3)
		await _shot("lattice_pulled")


func _tour_crossing(screen: Control) -> void:
	screen._command({"type": "press_on"}, "press")
	await _wait(0.3)
	await _shot("crossing_pressed")
	screen._command({"type": "pick_line"}, "peek")
	await _wait(0.3)
	await _shot("crossing_peeked")
	screen._command({"type": "shelter"}, "shelter")
	await _wait(0.3)
	await _shot("crossing_sheltered")


func _tour_testimony(screen: Control) -> void:
	var ribbons: Array = screen.state.visible.duplicate()
	if not ribbons.is_empty():
		screen._on_ribbon(String(ribbons[0]))
		await _wait(0.3)
		await _shot("testimony_pressed")

## The Case Board, its evidence note, and the "previously on" recap the same
## state composes. The prologue never finds evidence, so a tour of the real
## flow would only ever photograph an empty board — seed a mid-chapter state
## on the throwaway profile first (unless a scenario already supplied one).
func _tour_case_board() -> void:
	var case_progress: Dictionary = game.profile["case"]
	if case_progress.get("evidence", []).is_empty():
		case_progress["evidence"] = ["candle_stub", "wick_ledger"]
		game.profile["standing"] = {"chandlers": -3}
		game.profile["favors"] = ["lamplighters_knot"]
	game._show_case_board()
	await _wait(0.5)
	await _shot("case_board")
	game.current_screen._on_evidence_pressed("candle_stub")
	await _wait(0.35)
	await _shot("case_evidence")
	game.current_screen._close_detail()
	await _wait(0.25)
	game._show_recap(func() -> void: game._show_hub())
	await _wait(0.6)
	# Narration reveals a line per tap; the shot has to be of the full page.
	for i in 2:
		game.current_screen._advance()
		await _wait(0.5)
	await _shot("case_recap")
	game.current_screen.finished.emit(-1)
	await _wait(0.4)


## The Magpie Exchange and the loadout page. Both are all refusals and empty
## slots on a fresh profile — the prologue ends with no gleam and one skill —
## so the throwaway profile is given a purse and a satchel of skills first.
## Photographing an honestly-empty market would prove nothing about the layout.
## The Casebook's Lessons tab, and one lesson replayed. The tab is the
## owner's "let me go through that tutorial again" and the greyed rows are
## the promise that there is more to learn — both need photographing, and
## the replay needs proving it comes back here rather than to the hub.
func _tour_lessons() -> void:
	# A fresh tour profile has met nothing, so every row would be grey. Give
	# it the two concept lessons the opening arc delivers, which is the state
	# a player is actually in when they first open this tab.
	for lesson_id in ["the_exchange", "the_case_board"]:
		if not game.profile["taught"].has(lesson_id):
			game.profile["taught"].append(lesson_id)
	# Knowledge needs things OBSERVED or both explorer lists photograph
	# empty; seed the prologue's own encounters.
	game.profile["codex"]["enemies"] = ["the_vole", "gutter_wisp", "rag_wraith"]
	game.profile["codex"]["places"] = ["rooftop_dusk", "needle_lane", "parlor_cold"]
	game._show_journal()
	await _wait(0.4)
	var casebook: Control = game.current_screen
	await _shot("casebook_deeds")
	# The Knowledge explorer, both kinds, and one card of each opened FULL
	# (owner 2026-08-09: the popup shows the whole image).
	casebook._show_knowledge()
	await _wait(0.3)
	await _shot("casebook_creatures")
	casebook._show_creature_card("gutter_wisp")
	await _wait(0.45)
	await _shot("casebook_creature_card")
	casebook._close_card()
	await _wait(0.3)
	casebook._knowledge_kind = "places"
	casebook._show_knowledge()
	await _wait(0.3)
	await _shot("casebook_places")
	casebook._show_place_card("needle_lane")
	await _wait(0.45)
	await _shot("casebook_place_card")
	casebook._close_card()
	await _wait(0.3)
	casebook._show_lessons()
	await _wait(0.3)
	await _shot("casebook_lessons")
	game._play_lesson("the_exchange", func() -> void: pass)
	await _wait(0.4)
	await _shot("lesson_replayed")


func _tour_market_and_kit() -> void:
	game.profile["gleam"] = maxi(int(game.profile["gleam"]), 60)
	game._show_exchange()
	await _wait(0.5)
	await _shot("exchange")
	# The counter popup: the list of what is on offer, one card close up,
	# and the shelf again after the coin moves. Every modal state the screen
	# has gets driven and photographed (laws 2 and 13).
	game.current_screen._on_good_pressed("add")
	await _wait(0.45)
	await _shot("exchange_choosing")
	game.current_screen._show_card_detail("guile_2")
	await _wait(0.35)
	await _shot("exchange_card_detail")
	game.current_screen._buy_current()
	await _wait(0.45)
	await _shot("exchange_bought")
	game.current_screen._on_good_pressed("tonic")
	await _wait(0.45)
	await _shot("exchange_tonic")
	game.current_screen._close_shop()
	await _wait(0.3)
	if game.profile["skills"].size() <= 1:
		game.profile["skills"] = ["scratch", "pounce", "slink", "purr", "loaf",
			"swat", "shelf_justice"]
	game._show_loadout()
	await _wait(0.5)
	await _shot("loadout")
	# The skill close-up, then the card actually set down through it.
	var first_pick := String(SaveService.battle_loadout(game.profile)[1])
	game.current_screen._open_skill(first_pick)
	await _wait(0.45)
	await _shot("loadout_skill")
	game.current_screen._unequip(first_pick)
	game.current_screen._close_skill()
	await _wait(0.45)
	await _shot("loadout_swapped")
	# The Spool: winding energy off (free since 2026-08-08) and the floor.
	game.current_screen._open_spool()
	await _wait(0.45)
	await _shot("loadout_spool")
	game.current_screen._wind_off("guile_1")
	await _wait(0.35)
	await _shot("loadout_spool_wound")
	game.current_screen._close_spool()
	await _wait(0.3)
	# The swap choice (owner 2026-08-09): fill the tray back up, then ask for
	# one more — the popup must turn into "choose what steps aside".
	game.current_screen._open_skill("swat")
	await _wait(0.3)
	game.current_screen._equip("swat")
	await _wait(0.3)
	game.current_screen._open_skill("shelf_justice")
	await _wait(0.3)
	game.current_screen._equip("shelf_justice")
	await _wait(0.45)
	await _shot("loadout_swap_choice")
	game.current_screen._apply_swap(0, "shelf_justice")
	await _wait(0.45)
	await _shot("loadout_swapped_chosen")
	game._show_hub()
	await _wait(0.5)


func _tour_story(screen: Control, fresh: bool) -> void:
	if fresh:
		await _wait(0.6)  # let the first line's fade-in finish
		await _shot("story_first_line")
	if screen._choice_box != null and screen._choice_box.visible:
		await _shot("story_choices")
		screen.finished.emit(0)
		return
	_story_taps += 1
	if _story_taps > 12:  # failsafe
		screen.finished.emit(-1)
		return
	if screen._revealed >= screen.lines.size() and screen.choices.is_empty():
		# Everything visible: capture the full page BEFORE ending the scene.
		await _wait(0.6)
		await _shot("story_full")
		screen._advance()
		return
	screen._advance()
	await _wait(0.55)


func _tour_battle(screen: Control, fresh: bool) -> void:
	if fresh:
		_battle_taps = 0
		await _shot("battle_open_" + screen.state.enemy_id)
	_battle_taps += 1
	if _battle_taps > 80:  # failsafe: a looping battle ends, not the disk
		push_warning("tour: battle %s exceeded tap budget, slipping away" % screen.state.enemy_id)
		screen._close_detail()
		screen._on_slip_away()
		return
	if screen.approach_overlay != null and screen.approach_overlay.visible:
		await _shot("battle_approach_" + screen.state.enemy_id)
		screen._on_approach("")
		return
	if screen.coach != null and screen.coach.active():
		await _shot("battle_coach_" + screen.state.enemy_id)
		screen.coach.force_advance()
		return
	if screen.overlay != null and screen.overlay.visible:
		await _shot("battle_outcome_" + screen.state.enemy_id)
		screen._on_overlay_continue()
		return
	# The scripted withdrawal takes priority over everything: its only button
	# is the way out, and ignoring it would just burn the tap budget.
	if screen.withdraw_overlay != null and screen.withdraw_overlay.visible:
		await _shot("battle_withdraw_" + screen.state.enemy_id)
		screen.withdraw_overlay.visible = false
		screen._on_slip_away()
		return
	if screen.no_escape_overlay != null and screen.no_escape_overlay.visible:
		await _shot("battle_no_escape_" + screen.state.enemy_id)
		screen.no_escape_overlay.visible = false
		return
	# Reach for the door once in a locked room, so the refusal is photographed.
	if screen.state.no_retreat and not _did_no_escape:
		_did_no_escape = true
		screen._on_slip_away()
		return
	if screen.detail_overlay != null and screen.detail_overlay.visible:
		await _shot("battle_skill_detail")
		# Power the card fully (owner mechanic), then fire if ready. The FIRST
		# feed gets its own shot: a partly-powered card is the state the owner
		# read as "an empty circle yet to be filled", so it has to be visible
		# in the tour or the next regression is invisible too.
		var guard := 0
		while screen.detail_charge.visible and not screen.detail_charge.disabled and guard < 8:
			var skill_id: String = screen.selected_skill
			screen._on_detail_charge()
			guard += 1
			if guard == 1 and screen.detail_pips.visible and not _did_partial_charge:
				_did_partial_charge = true
				await _wait(0.2)
				await _shot("battle_skill_charged")
				# ...and back out to the board: energy fed onto a card has to
				# still read as fed once the popup is gone (owner defect).
				screen._close_detail()
				await _wait(0.3)
				await _shot("battle_tray_powered")
				screen._on_skill_selected(skill_id)
				await _wait(0.2)
		if not screen.detail_use.disabled:
			screen._on_detail_use()
		else:
			screen._close_detail()
		return
	if screen.card_overlay != null and screen.card_overlay.visible:
		await _shot("battle_card_detail")
		screen._close_card()
		return
	if screen.concentrate_overlay != null and screen.concentrate_overlay.visible:
		await _shot("battle_concentrate")
		screen.concentrate_overlay.visible = false
		return
	if screen.spool_overlay != null and screen.spool_overlay.visible:
		await _shot("battle_spool")
		UITheme.close_modal(screen.spool_overlay, screen.spool_panel)
		return
	# Show the modals once each, in the dog fight.
	if screen.state.enemy_id == "chained_dog":
		if not _did_card_modal and not screen.state.hand.is_empty():
			_did_card_modal = true
			screen._on_card_pressed(0)
			return
		if not _did_concentrate and not screen.state.spent.is_empty():
			_did_concentrate = true
			screen._on_concentrate_pressed()
			return
		if not _did_spool_modal:
			_did_spool_modal = true
			screen._open_spool_popup()
			return
	# Once per fight, photograph the bare board with a full chronicle. Every
	# other battle shot has a modal over the strip, so a broken scroll or an
	# unmeasured log line would never show up in the tour.
	if not _did_chronicle_shot and screen.log_lines.size() >= 8:
		_did_chronicle_shot = true
		await _shot("battle_chronicle")
	# Play one sensible action: best damage skill else end turn.
	var acted := false
	for entry in screen.state.skills:
		if screen._skill_playable(entry["id"]):
			screen._on_skill_selected(entry["id"])
			acted = true
			break
	if not acted:
		if not screen.state.instinct_used and screen._skill_playable("scratch"):
			screen._on_skill_selected("scratch")
		else:
			screen._on_end_turn()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	shot_index += 1
	var path := out_dir + "%02d_%s.png" % [shot_index, label]
	image.save_png(path)
	print("shot: ", path.get_file())
	# Every shot is also CHECKED, not just saved (owner 2026-08-05). A human
	# reading screenshots was the only guard against content leaving the page,
	# and it let a battle screen ship with its cards off the edge. Godot knows
	# the rects; ask it.
	for problem in PageGuard.violations(game):
		var line := "%s: %s" % [path.get_file(), problem]
		if not layout_problems.has(line):
			layout_problems.append(line)
		printerr("LAYOUT: ", line)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
