extends Control
## Testimony prototype board — story-screen family, no art (minigames.md #2).
##
## Ribbons are parchment plates down the page. Tap one to PRESS it. To
## PRESENT, pick an evidence chip from the strip along the bottom first, then
## tap the ribbon it contradicts — the same two-step a drag would be, without
## needing drag handling in a prototype.
##
## A ribbon only shows its loose thread once the player actually holds the
## evidence that disproves it. That is the fair-play rule, drawn.

signal closed

var state: TestimonyState
var testimony: Dictionary = {}
var coach_steps: Array = []
var coach_auto := false
var coach: Coach = null

var _board: Control
var _help: Button
var _markers: Dictionary = {}
var _scroll: ScrollContainer
var _finished := false
var _status: Label
var _ribbon_box: VBoxContainer
var _evidence_row: HFlowContainer
var _patience_row: MinigameShell.PipRow
var _said: Label
var _selected_evidence := ""
var _catalog: Catalog


func setup(catalog: Catalog, testimony_data: Dictionary, held: Array) -> void:
	_catalog = catalog
	testimony = testimony_data
	state = TestimonyState.create(testimony_data, held)


func _ready() -> void:
	var witness_name := String(testimony.get("witness", {}).get("name", "A Witness"))
	var shell := MinigameShell.build(self, witness_name,
		func() -> void: closed.emit())
	_status = shell["status"]
	_board = shell["board"]
	_help = shell["help"]

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	shell["board"].add_child(column)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH, 400)
	column.add_child(scroll)
	_scroll = scroll
	_ribbon_box = VBoxContainer.new()
	_ribbon_box.add_theme_constant_override("separation", 10)
	_ribbon_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_ribbon_box)

	_said = UITheme.measured_label("", 22, UITheme.CONTENT_WIDTH,
		UITheme.italic_font(), UITheme.INK_SOFT)
	column.add_child(_said)

	var strip_title := UITheme.measured_label(
		Strings.line("minigames.testimony.casebook"),
		UITheme.TYPE_FLOOR, UITheme.CONTENT_WIDTH, UITheme.smallcaps_font(),
		UITheme.INK_SOFT)
	column.add_child(strip_title)
	_evidence_row = HFlowContainer.new()
	_evidence_row.add_theme_constant_override("h_separation", 6)
	_evidence_row.add_theme_constant_override("v_separation", 6)
	column.add_child(_evidence_row)

	var row := MinigameShell.action_row(shell["actions"])
	_patience_row = MinigameShell.PipRow.new()
	_patience_row.custom_minimum_size = Vector2(200, MinigameShell.ACTION_HEIGHT)
	row.add_child(_patience_row)
	var leave := MinigameShell.leave_button(Strings.line("minigames.testimony.leave"))
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func() -> void:
		state.do_command({"type": "leave"})
		_finish())
	row.add_child(leave)

	for key in ["ribbons", "casebook", "patience"]:
		var marker := MinigameShell.Marker.new()
		_board.add_child(marker)
		_markers[key] = marker

	_help.pressed.connect(_start_tutorial)
	_help.visible = not coach_steps.is_empty()
	_refresh()
	if coach_auto:
		_start_tutorial()


func _start_tutorial() -> void:
	coach = MinigameShell.start_tutorial(self, coach_steps, _coach_target, coach)


func _coach_target(key: String) -> Control:
	match key:
		"board": return _board
		"board:patience": return _patience_row
		"board:ribbons": return _cover("ribbons", _scroll)
		"board:casebook": return _cover("casebook", _evidence_row)
	return null


## Points at a live container by copying its rect — the marker is a child of
## the board, so a container that scrolls or reflows stays covered.
func _cover(key: String, over: Control) -> Control:
	var marker: MinigameShell.Marker = _markers[key]
	marker.cover(Rect2(over.global_position - _board.global_position,
		over.size).grow(6.0))
	return marker


func _refresh() -> void:
	_status.text = Strings.line("minigames.testimony.status",
		[state.visible.size(), state.patience])
	_patience_row.set_pips(state.patience, int(testimony.get("patience", 3)))

	for child in _ribbon_box.get_children():
		_ribbon_box.remove_child(child)
		child.queue_free()
	for ribbon_id in state.visible:
		var ribbon: Dictionary = state.ribbons[ribbon_id]
		var plate := Button.new()
		plate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		plate.add_theme_font_size_override("font_size", 22)
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var marks := ""
		if state.is_shimmering(ribbon_id):
			marks += "  ❋"                      # a thread that will not hold
		if state.pressed.has(ribbon_id):
			marks += "  (pressed)"
		plate.text = String(ribbon.get("text", "")) + marks
		plate.custom_minimum_size = Vector2(0, UITheme.measure_text(
			plate.text, UITheme.body_font(), 22,
			UITheme.CONTENT_WIDTH - 40).y + 40)
		plate.pressed.connect(_on_ribbon.bind(ribbon_id))
		_ribbon_box.add_child(plate)

	for child in _evidence_row.get_children():
		_evidence_row.remove_child(child)
		child.queue_free()
	for evidence_id in state.held_evidence():
		var chip := Button.new()
		chip.toggle_mode = true
		chip.button_pressed = _selected_evidence == evidence_id
		chip.custom_minimum_size = Vector2(0, 52)
		chip.add_theme_font_size_override("font_size", 22)
		chip.text = _evidence_name(String(evidence_id))
		chip.pressed.connect(func() -> void:
			_selected_evidence = "" if _selected_evidence == evidence_id else String(evidence_id)
			_refresh())
		_evidence_row.add_child(chip)

	if Minigame.is_over(state.outcome):
		_finish()


func _evidence_name(evidence_id: String) -> String:
	for case_id in _catalog.cases:
		for entry in _catalog.cases[case_id].get("evidence", []):
			if String(entry["id"]) == evidence_id:
				return String(entry["name"])
	return evidence_id


func _on_ribbon(ribbon_id: String) -> void:
	if Minigame.is_over(state.outcome):
		return
	var result: Dictionary
	if _selected_evidence != "":
		result = state.do_command({"type": "present", "ribbon": ribbon_id,
			"evidence": _selected_evidence})
		_selected_evidence = ""
	else:
		result = state.do_command({"type": "press", "ribbon": ribbon_id})
	var said := String(result.get("said", ""))
	_said.text = said if said != "" else String(result.get("error", ""))
	_said.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH, UITheme.measure_text(
		_said.text, UITheme.italic_font(), 22, float(UITheme.CONTENT_WIDTH)).y)
	_refresh()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if coach != null and is_instance_valid(coach):
		coach.queue_free()
	MinigameShell.show_outcome(self, state.outcome, testimony,
		func() -> void: closed.emit())
