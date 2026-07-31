extends Node
## Screenshot tour: drives the real rendered game and saves PNGs of every
## screen so layout can be inspected without a human tapping through.
## Launch:  godot --path game -- --tour
## Output:  <repo>/screenshots/NN_name.png   (window closes when done)
##
## The tour uses a throwaway profile (never touches the real save) and
## interacts by calling the same handlers taps would.

var game: Node
var shot_index := 0
var _last_screen: Control = null
var _story_taps := 0

@onready var out_dir: String = ProjectSettings.globalize_path("res://") + "../screenshots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = get_parent()
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
		var script_path: String = screen.get_script().resource_path
		if script_path.ends_with("story_screen.gd"):
			await _tour_story(screen, fresh)
		elif script_path.ends_with("battle.gd"):
			await _tour_battle(screen, fresh)
		elif script_path.ends_with("hub_screen.gd"):
			await _shot("hub")
			break
		else:
			await _shot("unknown_screen")
			break
		await _wait(0.25)
	await _shot("final")
	get_tree().quit(0)


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
		await _shot("battle_open_" + screen.state.enemy_id)
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
	if screen.detail_panel != null and screen.detail_panel.visible:
		await _shot("battle_skill_detail")
		screen._on_detail_use()
		return
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
