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
var _did_partial_charge := false
var _did_no_escape := false
var _did_chronicle_shot := false
var _battle_taps := 0


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
		elif script_path.ends_with("hub_screen.gd"):
			await _shot("hub")
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
	get_tree().quit(0)


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
func _tour_market_and_kit() -> void:
	game.profile["gleam"] = maxi(int(game.profile["gleam"]), 60)
	game._show_exchange()
	await _wait(0.5)
	await _shot("exchange")
	game.current_screen._on_good_pressed("add")
	await _wait(0.35)
	await _shot("exchange_choosing")
	game.current_screen._on_add_card("guile")
	await _wait(0.35)
	await _shot("exchange_bought")
	if game.profile["skills"].size() <= 1:
		game.profile["skills"] = ["scratch", "pounce", "slink", "purr", "loaf",
			"swat", "shelf_justice"]
	game._show_loadout()
	await _wait(0.5)
	await _shot("loadout")
	game.current_screen._on_slot_pressed(
		String(SaveService.battle_loadout(game.profile)[1]))
	await _wait(0.35)
	await _shot("loadout_swapped")
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
		if not screen.card_bank.disabled:
			screen._on_card_bank()
		else:
			screen._close_card()
		return
	if screen.concentrate_overlay != null and screen.concentrate_overlay.visible:
		await _shot("battle_concentrate")
		screen.concentrate_overlay.visible = false
		return
	# Show the two new modals once each, in the dog fight.
	if screen.state.enemy_id == "chained_dog":
		if not _did_card_modal and not screen.state.hand.is_empty():
			_did_card_modal = true
			screen._on_card_pressed(0)
			return
		if not _did_concentrate and not screen.state.spent.is_empty():
			_did_concentrate = true
			screen._on_concentrate_pressed()
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


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
