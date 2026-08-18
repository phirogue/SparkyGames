extends Control
## Testimony board (minigames.md #2).
##
## Owner pass 2026-08-13: "this is a very crowded board and game right now, it
## needs to be streamlined. The idea is good, but the execution is too
## convoluted." What that changed, and why:
##
##   - The witness is the whole top of the page now, at nearly twice the size
##     ("make the portrait of the character much larger"). A face is what you
##     are reading.
##   - What they SAY is no longer a small column squeezed beside the portrait
##     ("the text of what they say in the top right is too small"). A reply is
##     a moment: it comes up as a card, at body size, and you dismiss it. That
##     took a whole zone off the board, which is most of the de-crowding.
##   - Statements never scroll ("I should not need to scroll on the things to
##     say"). They are fitted to the room there is, at or above the type floor.
##   - A statement you have already pressed wears a different cloth, so you
##     can see at a glance what is still worth pressing.
##   - The Casebook is chips again, but tapping one opens what the Casebook
##     actually says about it, and you choose to hold it up from there — the
##     player should never have to remember a note from another screen.
##   - "Let it lie" is one thin plate instead of a two-row slab, and the
##     height it gave up went to the board.
##
## The patience pips moved up into the status band with the count, because a
## running total belongs with the other running total.

signal closed

## Board template inside the shell's board zone. With the thin action row the
## board is 780 tall (see MinigameShell.ACTIONS_THIN):
##   witness 300 + ribbons 344 + casebook 120 + 2x8 separation = 780.
const WITNESS_BAND := 300.0
const RIBBON_ZONE := 344.0
const CASEBOOK_ZONE := 120.0
const BAND_SEPARATION := 8.0
## A Casebook chip is a PICTURE of the thing, at a fixed size. Six pieces of
## evidence with their names on them wrapped to "The Dock / et", grew the
## strip past its zone, and squeezed the witness and the statements to make
## room — one row of oversized minimums squashing every band above it.
const CHIP_SIZE := 84.0
## The portrait keeps the frame's aspect and takes the band's full height.
const PORTRAIT_SIZE := Vector2(256.0, 300.0)
## Type ladder a statement is fitted down through. Nothing below the floor.
const RIBBON_SIZES := [30, 28, 26, 24, 22]

var state: TestimonyState
var testimony: Dictionary = {}
var coach_steps: Array = []
var coach_auto := false
var coach: Coach = null

var _board: Control
var _help: Button
var _markers: Dictionary = {}
var _finished := false
var _status: Label
var _ribbon_box: VBoxContainer
var _evidence_row: HBoxContainer
var _patience_row: MinigameShell.PipRow
var _selected_evidence := ""
var _catalog: Catalog
## Set when a reply card is standing over a testimony that has already ended,
## so the outcome waits for the player to read the break before it lands.
var _finish_after_reply := false
## Last-refresh snapshots, so feedback can tell what CHANGED (the battle's
## hand-diff pattern): a new ribbon settles, spent patience pulses.
var _prev_visible: Array = []
var _prev_patience := -1


func setup(catalog: Catalog, testimony_data: Dictionary, held: Array) -> void:
	_catalog = catalog
	testimony = testimony_data
	state = TestimonyState.create(testimony_data, held)


func _ready() -> void:
	var witness_name := String(testimony.get("witness", {}).get("name", "A Witness"))
	var shell := MinigameShell.build(self, witness_name,
		func() -> void: closed.emit(), MinigameShell.ACTIONS_THIN)
	_status = shell["status"]
	_board = shell["board"]
	_help = shell["help"]
	_build_status_band()

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", int(BAND_SEPARATION))
	_board.add_child(column)

	# The witness, framed the way the battle frames its opponent, and given
	# the room a face deserves.
	var witness_row := HBoxContainer.new()
	witness_row.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH, WITNESS_BAND)
	witness_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(witness_row)
	witness_row.add_child(_framed_witness(
		String(testimony.get("witness", {}).get("art", "")), witness_name))

	_ribbon_box = VBoxContainer.new()
	_ribbon_box.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH, RIBBON_ZONE)
	_ribbon_box.add_theme_constant_override("separation", 8)
	_ribbon_box.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_ribbon_box)

	var casebook := VBoxContainer.new()
	casebook.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH, CASEBOOK_ZONE)
	casebook.add_theme_constant_override("separation", 4)
	column.add_child(casebook)
	casebook.add_child(UITheme.measured_label(
		Strings.line("minigames.testimony.casebook"),
		UITheme.TYPE_SUPPORT, UITheme.CONTENT_WIDTH, UITheme.smallcaps_font(),
		UITheme.INK_SOFT))
	_evidence_row = HBoxContainer.new()
	_evidence_row.add_theme_constant_override("separation", 6)
	_evidence_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_evidence_row.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH, CHIP_SIZE)
	casebook.add_child(_evidence_row)

	var row := MinigameShell.action_row(shell["actions"])
	var leave := MinigameShell.leave_button(
		Strings.line("minigames.testimony.leave"), MinigameShell.ACTION_FONT,
		MinigameShell.ACTIONS_THIN - 24.0, UITheme.CONTENT_WIDTH)
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


## Patience belongs with the count, not under the board taking up a verb's
## worth of plate. Both readings now live in the status band.
func _build_status_band() -> void:
	_status.visible = false
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH,
		MinigameShell.ZONE_STATUS)
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var column := _status.get_parent()
	column.add_child(row)
	column.move_child(row, _status.get_index())
	var label := Label.new()
	label.add_theme_font_size_override("font_size", MinigameShell.STATUS_FONT)
	label.add_theme_color_override("font_color", UITheme.INK)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	_status = label
	_patience_row = MinigameShell.PipRow.new()
	_patience_row.custom_minimum_size = Vector2(
		34 * maxi(int(testimony.get("patience", 3)), 1) + 8,
		MinigameShell.ZONE_STATUS)
	row.add_child(_patience_row)


## The battle's framed portrait, on the witness: art windowed to the frame's
## MEASURED aperture (law 22 — the frame's geometry is never trusted).
func _framed_witness(image_id: String, description: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = PORTRAIT_SIZE
	holder.size = PORTRAIT_SIZE
	var art := UITheme.art_or_placeholder(image_id, description)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	var frame := UITheme.tex("ui/ui_frame_portrait_thin")
	if frame != null:
		var opaque := UITheme.content_region(frame, "ui/ui_frame_portrait_thin")
		var aperture := UITheme.frame_aperture("ui/ui_frame_portrait_thin")
		var sx := PORTRAIT_SIZE.x / opaque.size.x
		var sy := PORTRAIT_SIZE.y / opaque.size.y
		var tuck := 4.0
		art.set_offset(SIDE_LEFT, (aperture.position.x - opaque.position.x) * sx - tuck)
		art.set_offset(SIDE_TOP, (aperture.position.y - opaque.position.y) * sy - tuck)
		art.set_offset(SIDE_RIGHT, -(opaque.end.x - aperture.end.x) * sx + tuck)
		art.set_offset(SIDE_BOTTOM, -(opaque.end.y - aperture.end.y) * sy + tuck)
	if art is TextureRect:
		art.clip_contents = true
	holder.add_child(art)
	if frame != null:
		var frame_rect := TextureRect.new()
		frame_rect.texture = UITheme.cropped_tex("ui/ui_frame_portrait_thin")
		frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_rect.stretch_mode = TextureRect.STRETCH_SCALE
		frame_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(frame_rect)
	return holder


## A ribbon's dress: the stitched fabric band. A statement already pressed
## wears the same cloth in a cooler dye, because the owner could not tell at a
## glance which ones they had already been through.
func _ribbon_stylebox(spent: bool) -> StyleBox:
	var texture := UITheme.tex("ui/ui_ribbon_band")
	if texture == null:
		var flat := UITheme.panel_stylebox(10)
		if spent:
			flat.bg_color = Color("c9c6cf")
		return flat
	var box := StyleBoxTexture.new()
	box.texture = texture
	# Wide side margins keep the frayed ends and the stitched corners from
	# stretching; the middle of the band tiles the weave. The vertical content
	# margin is deliberately thin — the band has to hold two lines of a
	# statement inside its share of a fixed zone (law 6).
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		box.set_texture_margin(side, 48)
		# Clear of the frayed ends: at 24 the first letter sat in the fray.
		box.set_content_margin(side, 40)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		box.set_texture_margin(side, 34)
		box.set_content_margin(side, 10)
	if spent:
		box.modulate_color = Color(0.74, 0.78, 0.88)
	return box


func _ribbon_wrap() -> float:
	return UITheme.CONTENT_WIDTH - 88.0   # both content margins, measured


func _start_tutorial() -> void:
	coach = MinigameShell.start_tutorial(self, coach_steps, _coach_target, coach)


func _coach_target(key: String) -> Control:
	match key:
		"board": return _board
		"board:patience": return _patience_row
		"board:ribbons": return _cover("ribbons", _ribbon_box)
		"board:casebook": return _cover("casebook", _evidence_row)
	return null


## Points at a live container by copying its rect — the marker is a child of
## the board, so a container that reflows stays covered.
func _cover(key: String, over: Control) -> Control:
	var marker: MinigameShell.Marker = _markers[key]
	marker.cover(Rect2(over.global_position - _board.global_position,
		over.size).grow(6.0))
	return marker


func _refresh() -> void:
	_status.text = Strings.line("minigames.testimony.status",
		[state.visible.size()])
	# Spent patience pulses the pips it came off — the cost is FELT, not
	# only recounted (the battle's rule for numbers that change).
	if state.patience < _prev_patience:
		UITheme.pulse(_patience_row, 1.25)
	_prev_patience = state.patience
	_patience_row.set_pips(state.patience, int(testimony.get("patience", 3)))
	_refresh_ribbons()
	_refresh_casebook()
	if Minigame.is_over(state.outcome) and not _finish_after_reply:
		_finish()


## Statements, fitted to the room there is. No scroll bar, ever (owner
## 2026-08-13) — the zone is fixed, so the TYPE gives, down to the floor and
## no further.
func _refresh_ribbons() -> void:
	for child in _ribbon_box.get_children():
		_ribbon_box.remove_child(child)
		child.queue_free()
	var count := maxi(state.visible.size(), 1)
	var plate_height := (RIBBON_ZONE - float(count - 1) * 8.0) / float(count)
	var text_box := Vector2(_ribbon_wrap(), plate_height - 20.0)
	for ribbon_id in state.visible:
		var ribbon: Dictionary = state.ribbons[ribbon_id]
		var text := String(ribbon.get("text", ""))
		if state.is_shimmering(ribbon_id):
			text += "  ❋"                      # a thread that will not hold
		var spent: bool = state.pressed.has(ribbon_id)
		var plate := Button.new()
		plate.text = text
		plate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		plate.add_theme_font_size_override("font_size", UITheme.fit_font_size(
			text, UITheme.body_font(), RIBBON_SIZES, text_box))
		for colour in ["font_color", "font_hover_color", "font_pressed_color"]:
			plate.add_theme_color_override(colour,
				UITheme.INK_SOFT if spent else UITheme.INK)
		for style_state in ["normal", "hover", "pressed", "focus"]:
			plate.add_theme_stylebox_override(style_state, _ribbon_stylebox(spent))
		plate.custom_minimum_size = Vector2(0, plate_height)
		plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
		plate.pressed.connect(_on_ribbon.bind(ribbon_id))
		_ribbon_box.add_child(plate)
		# A statement the witness just added settles in like a drawn card.
		if not _prev_visible.has(ribbon_id) and not _prev_visible.is_empty():
			UITheme.settle(plate)
	_prev_visible = state.visible.duplicate()


## The Casebook strip: one picture per thing carried, at a fixed size that
## shrinks only if the case runs to more evidence than the page is wide.
## The NAME lives in the note the chip opens — a name squeezed onto an 80px
## chip is not a name, it is a syllable.
func _refresh_casebook() -> void:
	for child in _evidence_row.get_children():
		_evidence_row.remove_child(child)
		child.queue_free()
	var held := state.held_evidence()
	if held.is_empty():
		return
	var side := minf(CHIP_SIZE, (UITheme.CONTENT_WIDTH - 6.0
		* float(held.size() - 1)) / float(held.size()))
	for evidence_id in held:
		var entry := _evidence(String(evidence_id))
		var chip := Button.new()
		chip.custom_minimum_size = Vector2(side, side)
		chip.tooltip_text = String(entry.get("name", evidence_id))
		if _selected_evidence == evidence_id:
			# In the paw, held up: amber, the way a chosen thing looks
			# everywhere else in the book.
			for style_state in ["normal", "hover", "pressed", "focus"]:
				chip.add_theme_stylebox_override(style_state,
					UITheme.amber_stylebox())
		var art := UITheme.cropped_tex(String(entry.get("art", "")))
		if art != null:
			var picture := TextureRect.new()
			picture.texture = art
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			picture.set_offset(SIDE_LEFT, 8)
			picture.set_offset(SIDE_TOP, 8)
			picture.set_offset(SIDE_RIGHT, -8)
			picture.set_offset(SIDE_BOTTOM, -8)
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(picture)
		else:
			chip.text = String(entry.get("name", evidence_id))
			chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			chip.add_theme_font_size_override("font_size", UITheme.TYPE_FLOOR)
		chip.pressed.connect(_open_evidence.bind(String(evidence_id)))
		_evidence_row.add_child(chip)


## What the Casebook says about a thing, on the page where it is needed
## (owner 2026-08-13: "clicking on things from the casebook should bring up a
## pop up reminding the player what is written in the casebook"). Holding it
## up is a choice made FROM the note, so nobody presents a thing they have
## half-remembered.
func _open_evidence(evidence_id: String) -> void:
	var entry := _evidence(evidence_id)
	var modal := UITheme.modal(self, 520.0)
	var overlay: Control = modal["overlay"]
	var panel: Control = modal["panel"]
	var box: VBoxContainer = modal["box"]
	var wrap := 488.0
	var close := func() -> void:
		UITheme.close_modal(overlay, panel)
		overlay.queue_free()
	var title := UITheme.measured_label(String(entry.get("name", evidence_id)),
		34, wrap, UITheme.display_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var art := String(entry.get("art", ""))
	if UITheme.tex(art) != null:
		var picture := UITheme.icon(art, 160.0)
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(picture)
	var note := String(entry.get("note", entry.get("found_line", "")))
	if note != "":
		box.add_child(UITheme.measured_label(note, UITheme.TYPE_SUPPORT, wrap,
			UITheme.body_font(), UITheme.INK))
	var hold := UITheme.amber_button(
		Strings.line("minigames.testimony.hold_up"), 30)
	hold.pressed.connect(func() -> void:
		_selected_evidence = evidence_id
		close.call()
		_refresh())
	box.add_child(hold)
	var back := UITheme.dark_button(
		Strings.line("minigames.testimony.put_back"), 26, Vector2(0, 72))
	back.pressed.connect(func() -> void:
		if _selected_evidence == evidence_id:
			_selected_evidence = ""
		close.call()
		_refresh())
	box.add_child(back)
	UITheme.modal_escape(modal, close)
	UITheme.open_modal(overlay, panel)


func _evidence(evidence_id: String) -> Dictionary:
	for case_id in _catalog.cases:
		for entry in _catalog.cases[case_id].get("evidence", []):
			if String(entry["id"]) == evidence_id:
				return entry
	return {"id": evidence_id, "name": evidence_id}


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
	if said == "":
		said = String(result.get("error", ""))
	# The reply IS the beat, so it gets the page rather than a column beside
	# the portrait. A break holds the outcome card back until it is read.
	_finish_after_reply = Minigame.is_over(state.outcome)
	if said != "":
		_say(said)
	_refresh()
	if _finish_after_reply and said == "":
		_finish_after_reply = false
		_finish()


## What the witness just said, at body size, over the board.
func _say(said: String) -> void:
	var witness_name := String(testimony.get("witness", {}).get("name", ""))
	var modal := UITheme.modal(self, 520.0)
	var overlay: Control = modal["overlay"]
	var panel: Control = modal["panel"]
	var box: VBoxContainer = modal["box"]
	var wrap := 488.0
	var who := UITheme.measured_label(witness_name, 30, wrap,
		UITheme.smallcaps_font(), UITheme.INK_SOFT)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(who)
	box.add_child(UITheme.measured_label(said, UITheme.TYPE_BODY, wrap,
		UITheme.italic_font(), UITheme.INK))
	var onward := UITheme.amber_button(
		Strings.line("minigames.testimony.go_on"), 32)
	onward.pressed.connect(func() -> void:
		UITheme.close_modal(overlay, panel)
		overlay.queue_free()
		if _finish_after_reply:
			_finish_after_reply = false
			_finish())
	box.add_child(onward)
	UITheme.modal_escape(modal, func() -> void:
		UITheme.close_modal(overlay, panel)
		overlay.queue_free()
		if _finish_after_reply:
			_finish_after_reply = false
			_finish())
	UITheme.open_modal(overlay, panel)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if coach != null and is_instance_valid(coach):
		coach.queue_free()
	MinigameShell.show_outcome(self, state.outcome, testimony,
		func() -> void: closed.emit())
