extends Control
## The Case Board — the chapter's spine and its recap mechanism. Opening it
## answers "where was I?": the question, the suspects whose cards are
## face-up, every evidence slot (found and still-empty), and red thread
## between the things and the people they point at.
##
## Everything here is drawn from data/case.json via CaseState; the screen
## owns no case knowledge of its own. Empty slots are deliberate — the
## player should always be able to count what is still out there.

signal closed

## FIXED zone template (law 12). These must sum, with SEPARATION between
## them, to UITheme.CONTENT_HEIGHT exactly. New content goes INTO a zone;
## if it truly needs room, change the template here first and re-check with
##   godot --path game -s tests/calibrate.gd -- zones case
## 96 + 140 + 290 + 416 + 114 = 1056, plus 4 x 12 separation = 1104.
const SEPARATION := 12
const ZONE_HEADER := 96      # back arrow + case title
const ZONE_QUESTION := 140   # the question the whole chapter answers
const ZONE_SUSPECTS := 290   # heading + a row of three suspect cards
const ZONE_EVIDENCE := 416   # heading + the pinned-things grid
const ZONE_FOOTER := 114     # next lead, knots owed, loudest guild notice

const COLUMNS := 3
const CHIP_WIDTH := (UITheme.CONTENT_WIDTH - (COLUMNS - 1) * SEPARATION) / COLUMNS  # 186
const SUSPECT_ART_HEIGHT := 180
const EVIDENCE_ROW_HEIGHT := 176
const EVIDENCE_ART_HEIGHT := 110

const THREAD_COLOR := Color("8c2f24")   # waxed red string
const PIN_COLOR := Color("b08d3f")      # brass

var catalog: Catalog
var profile: Dictionary

var _threads: ThreadOverlay
var _chips: Dictionary = {}     # "suspect:<id>" / "evidence:<id>" -> Control
var _detail: Dictionary = {}    # UITheme.modal parts
var _detail_title: Label
var _detail_body: Label


## Red string between a suspect card and a thing that points at them. Drawn
## as an overlay rather than inside the grids so a thread can cross zones,
## and pinned edge-to-edge (suspect's bottom, evidence's top) instead of
## centre-to-centre, which would lay string across the art.
class ThreadOverlay extends Control:
	var pairs: Array = []   # [[suspect_chip, evidence_chip], ...]
	var _last: PackedVector2Array = PackedVector2Array()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	# Container layout settles a frame or two after _ready, and again on any
	# resize; redraw when the pins actually move rather than every frame.
	func _process(_delta: float) -> void:
		var now := _pin_points()
		if now != _last:
			_last = now
			queue_redraw()

	func _pin_points() -> PackedVector2Array:
		var points := PackedVector2Array()
		var inverse := get_global_transform().affine_inverse()
		for pair: Array in pairs:
			if not is_instance_valid(pair[0]) or not is_instance_valid(pair[1]):
				continue
			var top: Rect2 = (pair[0] as Control).get_global_rect()
			var bottom: Rect2 = (pair[1] as Control).get_global_rect()
			# Pins sit just OUTSIDE the cards, in the gap between the rows —
			# the overlay draws behind the cards, so a pin inside one would
			# be hidden by it.
			points.append(inverse * Vector2(top.get_center().x, top.end.y + 4.0))
			points.append(inverse * Vector2(bottom.get_center().x, bottom.position.y - 4.0))
		return points

	func _draw() -> void:
		var points := _pin_points()
		var i := 0
		while i + 1 < points.size():
			draw_line(points[i], points[i + 1], THREAD_COLOR, 3.0, true)
			draw_circle(points[i], 5.0, PIN_COLOR)
			draw_circle(points[i + 1], 5.0, PIN_COLOR)
			i += 2


func setup(p_catalog: Catalog, p_profile: Dictionary) -> void:
	catalog = p_catalog
	profile = p_profile


func _ready() -> void:
	var margin := UITheme.page_scaffold(self)
	# The thread is added FIRST so it draws BEHIND the cards and headings.
	# Strung over the top it read as a strikethrough through "What — 2 of 5";
	# behind, the glyphs stay legible and the string still shows in the gap
	# between the rows, which is the only place it needs to be seen.
	_threads = ThreadOverlay.new()
	_threads.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(_threads)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)

	var case_def := CaseState.active_case(catalog, profile)
	_build_header(column, case_def)
	_build_question(column, case_def)
	_build_suspects(column)
	_build_evidence(column)
	_build_footer(column)

	for pair in CaseState.threads(catalog, profile):
		var suspect_chip: Control = _chips.get("suspect:" + String(pair[1]))
		var evidence_chip: Control = _chips.get("evidence:" + String(pair[0]))
		if suspect_chip != null and evidence_chip != null:
			_threads.pairs.append([suspect_chip, evidence_chip])

	_build_detail_modal()


# ------------------------------------------------------------------- zones

func _build_header(column: VBoxContainer, case_def: Dictionary) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, ZONE_HEADER)
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	var back := Button.new()
	back.custom_minimum_size = Vector2(96, 96)
	var arrow := UITheme.tex("ui/ui_arrow_back")
	if arrow != null:
		back.icon = arrow
		back.expand_icon = true
	else:
		back.text = "←"
	back.pressed.connect(func() -> void: closed.emit())
	header.add_child(back)
	var title := UITheme.measured_label(
		String(case_def.get("name", "The Case Board")), 40,
		UITheme.CONTENT_WIDTH - 112, UITheme.display_font())
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_FILL
	header.add_child(title)


func _build_question(column: VBoxContainer, case_def: Dictionary) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_QUESTION)
	holder.add_theme_constant_override("separation", 4)
	column.add_child(holder)
	holder.add_child(UITheme.measured_label(
		String(case_def.get("question", "")), 26, UITheme.CONTENT_WIDTH,
		UITheme.body_font()))
	holder.add_child(UITheme.measured_label(
		String(case_def.get("aphorism", "")), 21, UITheme.CONTENT_WIDTH,
		UITheme.italic_font(), UITheme.INK_SOFT))


func _build_suspects(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_SUSPECTS)
	holder.add_theme_constant_override("separation", 8)
	column.add_child(holder)
	holder.add_child(_heading("Who"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SEPARATION)
	holder.add_child(row)
	var known := CaseState.suspects_known(catalog, profile)
	var total: int = CaseState.active_case(catalog, profile).get("suspects", []).size()
	for i in maxi(total, known.size()):
		if i < known.size():
			var suspect: Dictionary = known[i]
			var chip := _card(String(suspect["name"]), String(suspect.get("art", "")),
				String(suspect.get("line", "")), SUSPECT_ART_HEIGHT, 22, true)
			_chips["suspect:" + String(suspect["id"])] = chip
			row.add_child(chip)
		else:
			# A face-down card: the player can count how many people are still
			# unaccounted for without being told who they are.
			row.add_child(_card("Not yet a name", "", "", SUSPECT_ART_HEIGHT, 22, false))
	# Cards are laid out top-aligned, so a two-line name never shoves the row.
	row.alignment = BoxContainer.ALIGNMENT_BEGIN


func _build_evidence(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_EVIDENCE)
	holder.add_theme_constant_override("separation", 8)
	column.add_child(holder)
	var slots := CaseState.evidence_slots(catalog, profile)
	var found := 0
	for slot in slots:
		if slot["found"]:
			found += 1
	holder.add_child(_heading("What — %d of %d" % [found, slots.size()]))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", SEPARATION)
	grid.add_theme_constant_override("v_separation", SEPARATION)
	holder.add_child(grid)
	for slot: Dictionary in slots:
		var is_found: bool = slot["found"]
		var chip := _card(
			String(slot["name"]) if is_found else "Still out there",
			String(slot.get("art", "")) if is_found else "",
			String(slot.get("note", "")) if is_found else "",
			EVIDENCE_ART_HEIGHT, 21, is_found)
		chip.custom_minimum_size = Vector2(CHIP_WIDTH, EVIDENCE_ROW_HEIGHT)
		if is_found:
			_chips["evidence:" + String(slot["id"])] = chip
			_tap_target(chip).pressed.connect(
				_on_evidence_pressed.bind(String(slot["id"])))
		grid.add_child(chip)


func _build_footer(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_FOOTER)
	holder.add_theme_constant_override("separation", 6)
	column.add_child(holder)
	var lead := CaseState.next_lead(catalog, profile)
	var knots := CaseState.held_favors(catalog, profile)
	var knot_names: Array[String] = []
	for knot in knots:
		knot_names.append(String(knot["name"]))
	var candidates: Array = [
		["Next: " + String(lead.get("name", "nothing left to pull")), 24,
			UITheme.body_font(), UITheme.INK],
		["Knots owed to you: " + (", ".join(knot_names) if not knot_names.is_empty()
			else "none. Yet."), 20, UITheme.body_font(), UITheme.INK_SOFT],
	]
	for guild_id in profile.get("standing", {}):
		candidates.append([CaseState.standing_line(catalog, profile, guild_id), 20,
			UITheme.italic_font(), UITheme.INK_SOFT])
	# Zone budget is fixed, and guild notices are the least load-bearing line
	# here (they also arrive as notice cards and on the recap). Add lines in
	# priority order while they MEASURE inside the zone; drop the rest.
	var used := 0.0
	for entry: Array in candidates:
		var text := String(entry[0])
		if text.is_empty():
			continue
		var height := UITheme.measure_text(text, entry[2] as Font, int(entry[1]),
			float(UITheme.CONTENT_WIDTH)).y
		if used + height + (6.0 if used > 0.0 else 0.0) > float(ZONE_FOOTER):
			break
		used += height + (6.0 if used > 0.0 else 0.0)
		holder.add_child(UITheme.measured_label(text, int(entry[1]),
			UITheme.CONTENT_WIDTH, entry[2] as Font, entry[3] as Color))


# ------------------------------------------------------------------- parts

func _heading(text: String) -> Label:
	return UITheme.measured_label(text, 28, UITheme.CONTENT_WIDTH,
		UITheme.smallcaps_font(), UITheme.INK_SOFT)


## One pinned card: framed art (or a visible placeholder) over a measured
## caption. `filled` false draws the blank card that marks a thing not yet
## found — the board is a to-do list as much as a record.
func _card(caption: String, art_id: String, art_desc: String,
		art_height: int, font_size: int, filled: bool) -> Control:
	var chip := VBoxContainer.new()
	chip.custom_minimum_size = Vector2(CHIP_WIDTH, 0)
	chip.add_theme_constant_override("separation", 6)
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(CHIP_WIDTH, art_height)
	frame.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e4d5b4") if filled else Color("d8c9a8")
	style.set_border_width_all(3)
	style.border_color = UITheme.INK if filled else Color("a99c82")
	style.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", style)
	chip.add_child(frame)
	if filled and art_id != "":
		var art := UITheme.art_or_placeholder(art_id, art_desc)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.add_child(art)
	elif not filled:
		var mark := Label.new()
		mark.text = "?"
		mark.add_theme_font_override("font", UITheme.display_font())
		mark.add_theme_font_size_override("font_size", 56)
		mark.add_theme_color_override("font_color", Color("a99c82"))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(mark)
	var label := UITheme.measured_label(caption, font_size, CHIP_WIDTH,
		UITheme.body_font(), UITheme.INK if filled else UITheme.INK_FADED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(label)
	chip.set_meta("frame", frame)
	return chip


## A transparent Button filling the card's picture frame, so the whole
## picture is the tap target instead of a hotspot. It goes on the FRAME, not
## on the card: the card is a VBoxContainer, and a Button parented there
## would be laid out as another row instead of overlaying anything.
func _tap_target(chip: Control) -> Button:
	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	(chip.get_meta("frame") as Control).add_child(button)
	return button


# ------------------------------------------------------------------ detail

func _build_detail_modal() -> void:
	_detail = UITheme.modal(self, 520.0)
	var dim: Control = _detail["overlay"]
	# Law 13: every modal needs an escape path. Dim-tap dismisses, and the
	# catcher sits UNDER the centered panel so it never swallows its buttons.
	var catcher := Button.new()
	catcher.flat = true
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.pressed.connect(_close_detail)
	dim.add_child(catcher)
	dim.move_child(catcher, 0)
	var box: VBoxContainer = _detail["box"]
	_detail_title = UITheme.measured_label("", 32, 488.0, UITheme.display_font())
	box.add_child(_detail_title)
	_detail_body = UITheme.measured_label("", 24, 488.0, UITheme.body_font())
	box.add_child(_detail_body)
	var close := UITheme.dark_button("Pin it back", 24, Vector2(0, UITheme.BUTTON_HEIGHT))
	close.pressed.connect(_close_detail)
	box.add_child(close)


func _on_evidence_pressed(evidence_id: String) -> void:
	for slot: Dictionary in CaseState.evidence_slots(catalog, profile):
		if String(slot["id"]) != evidence_id or not slot["found"]:
			continue
		_detail_title.text = String(slot["name"])
		_detail_title.custom_minimum_size = Vector2(488.0, UITheme.measure_text(
			_detail_title.text, UITheme.display_font(), 32, 488.0).y)
		_detail_body.text = String(slot.get("note", ""))
		_detail_body.custom_minimum_size = Vector2(488.0, UITheme.measure_text(
			_detail_body.text, UITheme.body_font(), 24, 488.0).y)
		_detail["overlay"].visible = true
		return


func _close_detail() -> void:
	_detail["overlay"].visible = false
