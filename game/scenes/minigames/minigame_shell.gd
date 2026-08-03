class_name MinigameShell
extends RefCounted
## The page furniture every mission minigame shares, so the five prototypes
## differ only where their RULES differ (docs/design/minigames.md).
##
## Deliberately geometric: dots, lines, boxes and type. No generated art, no
## new asset dependencies — the doc calls for drawn boards, and a prototype
## that waits on images cannot be felt this week.
##
## Zone template (law 12) for every module, summing with separations to
## UITheme.CONTENT_HEIGHT (1104):
##   header 96 + status 64 + board 760 + actions 148 = 1068, +3x12 = 1104

const SEPARATION := 12
const ZONE_HEADER := 96
const ZONE_STATUS := 64
const ZONE_BOARD := 760
const ZONE_ACTIONS := 148

const INK_FAINT := Color("2b232033")
const THREAD := Color("8c2f24")
const BRASS := Color("b08d3f")
const CLOTH := Color("d8c9a8")
const TORN := Color("6b5747")


## Builds page + margin + the four zones. Returns
## {"header": HBox, "status": Label, "board": Control, "actions": HBox}.
## The caller draws into `board` and adds buttons to `actions`.
static func build(root: Control, title: String, on_back: Callable) -> Dictionary:
	var margin := UITheme.page_scaffold(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)

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
	back.pressed.connect(on_back)
	header.add_child(back)
	var title_label := UITheme.measured_label(title, 38,
		UITheme.CONTENT_WIDTH - 112, UITheme.display_font())
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title_label)

	var status := UITheme.measured_label("", 24, UITheme.CONTENT_WIDTH,
		UITheme.body_font(), UITheme.INK_SOFT)
	status.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH, ZONE_STATUS)
	column.add_child(status)

	var board := Control.new()
	board.custom_minimum_size = Vector2(UITheme.CONTENT_WIDTH, ZONE_BOARD)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(board)

	var actions := HBoxContainer.new()
	actions.custom_minimum_size = Vector2(0, ZONE_ACTIONS)
	actions.add_theme_constant_override("separation", 10)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(actions)

	return {"header": header, "status": status, "board": board, "actions": actions}


## The outcome card. Failure is a story outcome, never a game-over, so all
## three endings get the same treatment: what happened, the prose, one way on.
static func show_outcome(root: Control, outcome: int, data: Dictionary,
		on_done: Callable) -> void:
	var modal := UITheme.modal(root, 520.0)
	var box: VBoxContainer = modal["box"]
	var heading := UITheme.measured_label(
		_outcome_heading(outcome), 34, 488.0, UITheme.display_font())
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var prose := String(data.get("when_outcome", {}).get(
		Minigame.outcome_key(outcome), ""))
	if prose != "":
		var line := UITheme.measured_label(prose, 24, 488.0, UITheme.italic_font())
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(line)
	var onward := UITheme.amber_button("Onward", 28)
	onward.pressed.connect(on_done)
	box.add_child(onward)
	modal["overlay"].visible = true


static func _outcome_heading(outcome: int) -> String:
	match outcome:
		Minigame.Outcome.SUCCESS: return "It holds"
		Minigame.Outcome.PARTIAL: return "It half-holds"
		Minigame.Outcome.WALKED: return "Left as it lies"
	return ""


## A pip row (patience, paws, alarm) drawn as filled and empty circles.
class PipRow extends Control:
	var filled := 0
	var total := 0
	var fill_color := Color("8c2f24")

	func set_pips(p_filled: int, p_total: int) -> void:
		filled = p_filled
		total = p_total
		queue_redraw()

	func _draw() -> void:
		for i in total:
			var centre := Vector2(12 + i * 30, size.y * 0.5)
			if i < filled:
				draw_circle(centre, 10.0, fill_color)
			else:
				draw_arc(centre, 10.0, 0, TAU, 24, Color("a99c82"), 2.0)
