extends Control
## Playtest battle scene: the four prologue encounters as one continuous
## prowl. Functional UI only — juice and art come later. All rules live in
## CombatState; this scene renders state and forwards taps.

const ENCOUNTER_CHAIN: Array[String] = [
	"prologue_wisp", "prologue_dog", "prologue_wraith", "prologue_parlor",
]
const STARTER_DECK: Array[String] = [
	"ferocity_1", "ferocity_1", "ferocity_2", "ferocity_2", "ferocity_3",
	"guile_1", "guile_1", "guile_2", "guile_2",
	"shadow_1", "shadow_1", "shadow_2", "shadow_3",
	"moonlight_1", "moonlight_1", "moonlight_2",
]
const STARTER_SKILLS: Array[String] = [
	"pounce", "swat", "slink", "purr", "loaf", "shelf_justice",
]
const HUMOUR_COLORS := {
	"ferocity": Color(0.85, 0.35, 0.25),
	"guile": Color(0.45, 0.65, 0.35),
	"shadow": Color(0.45, 0.4, 0.6),
	"moonlight": Color(0.55, 0.65, 0.8),
}

var catalog: Catalog
var tracker: AchievementTracker
var state: CombatState
var chain_index := 0
var log_lines: Array[String] = []

var enemy_label: Label
var enemy_hp_bar: ProgressBar
var intent_label: Label
var log_label: Label
var player_label: Label
var banked_row: HBoxContainer
var hand_row: HBoxContainer
var skills_grid: GridContainer
var end_turn_button: Button
var slip_button: Button
var overlay: ColorRect
var overlay_label: Label
var overlay_button: Button


func _ready() -> void:
	catalog = DataLoader.load_catalog()
	tracker = AchievementTracker.new(catalog)
	_build_ui()
	_start_run()


# ------------------------------------------------------------------ run flow

func _start_run() -> void:
	chain_index = 0
	_start_encounter({})


## carryover = {} for a fresh run, else {hp, deck, skill_charges} from the
## previous encounter — energy and charges persist across a prowl.
func _start_encounter(carryover: Dictionary) -> void:
	var encounter: Dictionary = catalog.encounters[ENCOUNTER_CHAIN[chain_index]]
	var config := {
		"player_max_hp": 20,
		"player_hp": carryover.get("hp", 20),
		"deck": carryover.get("deck", STARTER_DECK),
		"skills": STARTER_SKILLS,
		"enemy": encounter["enemies"][0],
	}
	if carryover.has("skill_charges"):
		config["skill_charges"] = carryover["skill_charges"]
	state = CombatState.create(catalog, int(Time.get_ticks_usec()) % 1000000007, config)
	_log("— %s —" % encounter["name"])
	overlay.hide()
	_refresh()


func _carryover_from_state() -> Dictionary:
	var charges := {}
	for s in state.skills:
		charges[s["id"]] = s["charges_left"]
	return {
		"hp": state.player_hp,
		"deck": state.deck + state.hand + state.banked,
		"skill_charges": charges,
	}


func _finish_encounter() -> void:
	for id in tracker.record_encounter(state):
		_log("★ Achievement: %s" % catalog.achievements[id]["name"])
	match state.outcome:
		CombatState.Outcome.VICTORY:
			if chain_index == ENCOUNTER_CHAIN.size() - 1:
				_show_overlay("The Unpicked... falls?\n\nThat was not supposed to happen.\nThe Clerk has questions.\n\n(Prologue complete)", "Start Over")
			else:
				_show_overlay("%s defeated." % catalog.enemies[state.enemy_id]["name"], "Press On")
		CombatState.Outcome.DEFEAT:
			_show_overlay("A life is spent.\n\nThe Hollow Court validates parking.\n(First visit is complimentary.)", "Wake Up")
		CombatState.Outcome.RETREATED:
			_show_overlay("You slip away.\n\nA cat does not lose fights.\nIt schedules them for never.", "Return")


func _on_overlay_continue() -> void:
	match state.outcome:
		CombatState.Outcome.VICTORY:
			if chain_index == ENCOUNTER_CHAIN.size() - 1:
				_start_run()
			else:
				var carry := _carryover_from_state()
				chain_index += 1
				_start_encounter(carry)
		CombatState.Outcome.DEFEAT:
			_start_run()
		CombatState.Outcome.RETREATED:
			_start_encounter(_carryover_from_state())


# ------------------------------------------------------------------ commands

func _on_skill_pressed(skill_id: String) -> void:
	var result := state.do_command({"type": "play_skill", "skill_id": skill_id})
	if result["ok"]:
		_log("Ash uses %s." % catalog.skills[skill_id]["name"])
	else:
		_log(result["error"])
	_after_command()


func _on_card_pressed(hand_index: int) -> void:
	var card_id: String = state.hand[hand_index]
	var result := state.do_command({"type": "bank", "hand_index": hand_index})
	if result["ok"]:
		_log("Banked %s." % catalog.energy_cards[card_id]["name"])
	else:
		_log(result["error"])
	_after_command()


func _on_end_turn() -> void:
	var intent := state.current_intent()
	var result := state.do_command({"type": "end_turn"})
	if result["ok"]:
		_log("%s uses %s." % [catalog.enemies[state.enemy_id]["name"], intent["name"]])
	_after_command()


func _on_slip_away() -> void:
	state.do_command({"type": "slip_away"})
	_after_command()


func _after_command() -> void:
	_refresh()
	if state.outcome != CombatState.Outcome.ONGOING:
		_finish_encounter()


# ------------------------------------------------------------------ ui build

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	enemy_label = _label(root, 30)
	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.custom_minimum_size = Vector2(0, 26)
	enemy_hp_bar.show_percentage = false
	root.add_child(enemy_hp_bar)
	intent_label = _label(root, 22)
	intent_label.modulate = Color(1.0, 0.8, 0.6)
	root.add_child(HSeparator.new())

	log_label = _label(root, 18)
	log_label.custom_minimum_size = Vector2(0, 120)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	player_label = _label(root, 24)
	banked_row = HBoxContainer.new()
	banked_row.add_theme_constant_override("separation", 8)
	root.add_child(banked_row)
	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 8)
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(hand_row)

	skills_grid = GridContainer.new()
	skills_grid.columns = 2
	skills_grid.add_theme_constant_override("h_separation", 10)
	skills_grid.add_theme_constant_override("v_separation", 10)
	root.add_child(skills_grid)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	root.add_child(action_row)
	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.custom_minimum_size = Vector2(0, 64)
	end_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_turn_button.pressed.connect(_on_end_turn)
	action_row.add_child(end_turn_button)
	slip_button = Button.new()
	slip_button.text = "Slip Away"
	slip_button.custom_minimum_size = Vector2(180, 64)
	slip_button.pressed.connect(_on_slip_away)
	action_row.add_child(slip_button)

	overlay = ColorRect.new()
	overlay.color = Color(0.05, 0.05, 0.08, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.hide()
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var overlay_box := VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 24)
	center.add_child(overlay_box)
	overlay_label = Label.new()
	overlay_label.add_theme_font_size_override("font_size", 26)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(overlay_label)
	overlay_button = Button.new()
	overlay_button.custom_minimum_size = Vector2(240, 64)
	overlay_button.pressed.connect(_on_overlay_continue)
	overlay_box.add_child(overlay_button)


func _label(parent: Container, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


# ------------------------------------------------------------------ refresh

func _refresh() -> void:
	var enemy: Dictionary = catalog.enemies[state.enemy_id]
	enemy_label.text = enemy["name"]
	enemy_hp_bar.max_value = state.enemy_max_hp
	enemy_hp_bar.value = maxi(state.enemy_hp, 0)
	var intent := state.current_intent()
	intent_label.text = "Next: %s — %s" % [intent["name"], _intent_text(intent)]
	player_label.text = "Ash  HP %d/%d   Block %d   Deck %d   Turn %d" % [
		state.player_hp, state.player_max_hp, state.player_block,
		state.deck.size(), state.turn,
	]
	log_label.text = "\n".join(log_lines)

	_clear(banked_row)
	for card_id in state.banked:
		var b := _card_button(card_id)
		b.disabled = true
		banked_row.add_child(b)
	_clear(hand_row)
	for i in state.hand.size():
		var b := _card_button(state.hand[i])
		b.tooltip_text = "Tap to bank (save for later; enemies can steal it)"
		b.pressed.connect(_on_card_pressed.bind(i))
		hand_row.add_child(b)
	_clear(skills_grid)
	for skill_id in STARTER_SKILLS + ["scratch"]:
		skills_grid.add_child(_skill_button(skill_id))


func _card_button(card_id: String) -> Button:
	var card: Dictionary = catalog.energy_cards[card_id]
	var b := Button.new()
	b.text = "%s\n%s %d" % [card["name"], String(card["humour"]).capitalize(), card["value"]]
	b.custom_minimum_size = Vector2(120, 84)
	b.modulate = HUMOUR_COLORS.get(card["humour"], Color.WHITE)
	return b


func _skill_button(skill_id: String) -> Button:
	var def: Dictionary = catalog.skills[skill_id]
	var runtime := state.skill_state(skill_id)
	var is_instinct: bool = def.get("instinct", false)
	var cost_parts: Array[String] = []
	for humour in def.get("cost", {}):
		cost_parts.append("%s %d" % [String(humour).capitalize(), def["cost"][humour]])
	var cost_text := "free" if cost_parts.is_empty() else ", ".join(cost_parts)
	var charges_text := "∞" if is_instinct else str(runtime.get("charges_left", 0))
	var b := Button.new()
	b.text = "%s  (%s | ×%s)" % [def["name"], cost_text, charges_text]
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = String(def.get("flavor", ""))
	var jammed: bool = not is_instinct and int(runtime.get("jammed_turns", 0)) > 0
	var spent_out: bool = not is_instinct and int(runtime.get("charges_left", 0)) <= 0
	b.disabled = jammed or spent_out or not state.can_pay(def.get("cost", {})) \
		or state.statuses.get("loafed", 0) > 0
	if jammed:
		b.text += "  [jammed]"
	b.pressed.connect(_on_skill_pressed.bind(skill_id))
	return b


func _intent_text(intent: Dictionary) -> String:
	match intent["target"]:
		"health": return "%d damage" % int(intent["amount"])
		"skills": return "burns a skill charge" if intent.get("mode", "jam") == "burn" else "jams a skill"
		"hand": return "steals %d card(s) from your hand" % int(intent["amount"])
	return "?"


func _show_overlay(text: String, button_text: String) -> void:
	overlay_label.text = text
	overlay_button.text = button_text
	overlay.show()


func _log(line: String) -> void:
	log_lines.append(line)
	while log_lines.size() > 5:
		log_lines.remove_at(0)
	if log_label != null:
		log_label.text = "\n".join(log_lines)


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
