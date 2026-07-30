extends Control
## One encounter, rendered with palette stand-ins (colored panels instead of
## art). Owns no game flow: game.gd builds the config, listens for
## encounter_finished, and decides what happens next.

signal encounter_finished(state: CombatState)

const HUMOUR_COLORS := {
	"ferocity": Color(0.85, 0.35, 0.25),
	"guile": Color(0.45, 0.65, 0.35),
	"shadow": Color(0.55, 0.5, 0.7),
	"moonlight": Color(0.55, 0.65, 0.8),
}

var catalog: Catalog
var state: CombatState
var encounter_def: Dictionary
var environment_def: Dictionary
var skill_ids: Array = []
var log_lines: Array[String] = []

var backdrop: ColorRect
var title_label: Label
var rule_label: Label
var enemy_swatch: ColorRect
var enemy_label: Label
var enemy_hp_bar: ProgressBar
var intent_label: Label
var alarm_label: Label
var log_label: Label
var player_label: Label
var banked_row: HBoxContainer
var hand_row: HBoxContainer
var skills_grid: GridContainer
var overlay: ColorRect
var overlay_label: Label
var overlay_button: Button


func setup(p_catalog: Catalog, config: Dictionary, encounter_id: String) -> void:
	catalog = p_catalog
	encounter_def = catalog.encounters[encounter_id]
	environment_def = catalog.environments[encounter_def["environment"]]
	skill_ids = Array(config.get("skills", []))
	var full_config := config.duplicate(true)
	full_config["environment"] = environment_def
	full_config["enemy"] = encounter_def["enemies"][0]
	state = CombatState.create(catalog, int(Time.get_ticks_usec()) % 1000000007, full_config)


func _ready() -> void:
	_build_ui()
	_log("— %s —" % encounter_def["name"])
	_refresh()
	_start_ambient_animation()


## Programmatic life over static stand-ins (design rule in asset-pipeline.md):
## the enemy swatch "breathes" continuously — faster and harsher when the
## fight turns against you. Later this same tween drives real art.
func _start_ambient_animation() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(enemy_swatch, "modulate",
		Color(1.25, 1.25, 1.25), 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(enemy_swatch, "modulate",
		Color(0.8, 0.8, 0.8), 0.9).set_trans(Tween.TRANS_SINE)


func _flash(node: CanvasItem, color: Color, duration := 0.35) -> void:
	var tween := create_tween()
	tween.tween_property(node, "modulate", color, duration * 0.4)
	tween.tween_property(node, "modulate", Color.WHITE, duration * 0.6)


# ------------------------------------------------------------------ commands

func _on_skill_pressed(skill_id: String) -> void:
	var result := state.do_command({"type": "play_skill", "skill_id": skill_id})
	if result["ok"]:
		_log("Ash: %s." % catalog.skills[skill_id]["name"])
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
	var was_spotted := state.spotted
	var result := state.do_command({"type": "end_turn"})
	if result["ok"]:
		var suffix := "!" if was_spotted else "."
		_log("%s: %s%s" % [catalog.enemies[state.enemy_id]["name"], intent["name"], suffix])
	_after_command()


func _on_slip_away() -> void:
	state.do_command({"type": "slip_away"})
	_after_command()


func _after_command() -> void:
	for event in state.take_events():
		match event:
			"sunbeam":
				_log("A sunbeam. One spent card comes back, warm.")
				_flash(backdrop, Color(1.5, 1.3, 0.9), 0.7)
			"spotted":
				_log("SPOTTED. The garden is awake, and it has opinions.")
				_flash(backdrop, Color(1.5, 0.7, 0.6), 0.5)
	_refresh()
	if state.outcome != CombatState.Outcome.ONGOING:
		_show_outcome()


func _show_outcome() -> void:
	match state.outcome:
		CombatState.Outcome.VICTORY:
			overlay_label.text = "%s: dealt with." % catalog.enemies[state.enemy_id]["name"]
			overlay_button.text = "Continue"
		CombatState.Outcome.DEFEAT:
			overlay_label.text = "The dark comes up like a floor."
			overlay_button.text = "..."
		CombatState.Outcome.RETREATED:
			overlay_label.text = "You were never here."
			overlay_button.text = "Slip Away"
	overlay.show()


func _on_overlay_continue() -> void:
	encounter_finished.emit(state)


# ------------------------------------------------------------------ ui

func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.color = Color(environment_def["color"]).darkened(0.25)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	title_label = _label(root, 20)
	title_label.text = environment_def["name"]
	title_label.modulate = Color(environment_def.get("accent", "#ffffff"))
	rule_label = _label(root, 15)
	rule_label.text = environment_def.get("rule_text", "")
	rule_label.modulate = Color(1, 1, 1, 0.7)

	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 12)
	root.add_child(enemy_row)
	enemy_swatch = ColorRect.new()
	enemy_swatch.custom_minimum_size = Vector2(72, 72)
	enemy_swatch.color = Color(catalog.enemies[state.enemy_id].get("color", "#888888"))
	enemy_row.add_child(enemy_swatch)
	var enemy_col := VBoxContainer.new()
	enemy_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_row.add_child(enemy_col)
	enemy_label = _label(enemy_col, 26)
	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.custom_minimum_size = Vector2(0, 22)
	enemy_hp_bar.show_percentage = false
	enemy_col.add_child(enemy_hp_bar)

	intent_label = _label(root, 20)
	intent_label.modulate = Color(1.0, 0.8, 0.6)
	alarm_label = _label(root, 18)
	alarm_label.modulate = Color(1.0, 0.6, 0.5)
	root.add_child(HSeparator.new())

	log_label = _label(root, 16)
	log_label.custom_minimum_size = Vector2(0, 110)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	player_label = _label(root, 21)
	banked_row = HBoxContainer.new()
	banked_row.add_theme_constant_override("separation", 8)
	root.add_child(banked_row)
	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 8)
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(hand_row)

	skills_grid = GridContainer.new()
	skills_grid.columns = 2
	skills_grid.add_theme_constant_override("h_separation", 8)
	skills_grid.add_theme_constant_override("v_separation", 8)
	root.add_child(skills_grid)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	root.add_child(action_row)
	var end_turn := Button.new()
	end_turn.text = "End Turn"
	end_turn.custom_minimum_size = Vector2(0, 60)
	end_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_turn.pressed.connect(_on_end_turn)
	action_row.add_child(end_turn)
	var slip := Button.new()
	slip.text = "Slip Away"
	slip.custom_minimum_size = Vector2(170, 60)
	slip.pressed.connect(_on_slip_away)
	action_row.add_child(slip)

	overlay = ColorRect.new()
	overlay.color = Color(0.04, 0.04, 0.07, 0.88)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.hide()
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)
	overlay_label = Label.new()
	overlay_label.add_theme_font_size_override("font_size", 25)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(overlay_label)
	overlay_button = Button.new()
	overlay_button.custom_minimum_size = Vector2(230, 60)
	overlay_button.pressed.connect(_on_overlay_continue)
	box.add_child(overlay_button)


func _label(parent: Container, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _refresh() -> void:
	var enemy: Dictionary = catalog.enemies[state.enemy_id]
	enemy_label.text = enemy["name"]
	enemy_hp_bar.max_value = state.enemy_max_hp
	enemy_hp_bar.value = maxi(state.enemy_hp, 0)
	var intent := state.current_intent()
	if state.spotted:
		intent_label.text = "Next: %s! — it sees you; expect worse" % intent["name"]
	else:
		intent_label.text = "Next: %s — %s" % [intent["name"], _intent_text(intent)]
	if state.stealth_threshold > 0:
		alarm_label.visible = true
		alarm_label.text = "SPOTTED" if state.spotted \
			else "Alarm %d / %d" % [state.alarm, state.stealth_threshold]
	else:
		alarm_label.visible = false
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
		b.tooltip_text = "Tap to bank for later (enemies can steal it)"
		b.pressed.connect(_on_card_pressed.bind(i))
		hand_row.add_child(b)
	_clear(skills_grid)
	for skill_id in skill_ids + ["scratch"]:
		skills_grid.add_child(_skill_button(skill_id))


func _card_button(card_id: String) -> Button:
	var card: Dictionary = catalog.energy_cards[card_id]
	var b := Button.new()
	b.text = "%s\n%s %d" % [card["name"], String(card["humour"]).capitalize(), card["value"]]
	b.custom_minimum_size = Vector2(118, 80)
	b.modulate = HUMOUR_COLORS.get(card["humour"], Color.WHITE)
	return b


func _skill_button(skill_id: String) -> Button:
	var def: Dictionary = catalog.skills[skill_id]
	var runtime := state.skill_state(skill_id)
	var is_instinct: bool = def.get("instinct", false)
	var cost := state.effective_cost(def.get("cost", {}))
	var cost_parts: Array[String] = []
	for humour in cost:
		cost_parts.append("%s %d" % [String(humour).capitalize(), cost[humour]])
	var cost_text := "free" if cost_parts.is_empty() else ", ".join(cost_parts)
	var charges_text := "∞" if is_instinct else str(runtime.get("charges_left", 0))
	var b := Button.new()
	b.text = "%s  (%s | ×%s)" % [def["name"], cost_text, charges_text]
	b.custom_minimum_size = Vector2(0, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = String(def.get("flavor", ""))
	var jammed: bool = not is_instinct and int(runtime.get("jammed_turns", 0)) > 0
	var spent_out: bool = not is_instinct and int(runtime.get("charges_left", 0)) <= 0
	b.disabled = jammed or spent_out or not state.can_pay(cost) \
		or state.statuses.get("loafed", 0) > 0
	if jammed:
		b.text += "  [jammed]"
	b.pressed.connect(_on_skill_pressed.bind(skill_id))
	return b


func _intent_text(intent: Dictionary) -> String:
	match intent["target"]:
		"health": return "%d damage" % int(intent["amount"])
		"skills": return "burns a skill charge" if intent.get("mode", "jam") == "burn" else "jams a skill"
		"hand": return "steals %d card(s)" % int(intent["amount"])
	return "?"


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
