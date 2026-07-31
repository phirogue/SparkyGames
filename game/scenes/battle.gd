extends Control
## Battle screen, styled per reference/battle screen - v2.png: the fight is a
## page in the casebook. Real template art with color fallbacks; all rules
## stay in CombatState.

signal encounter_finished(state: CombatState)

const HUMOUR_CARD_FRAME := {
	"ferocity": "ui/ui_frame_card_red",
	"guile": "ui/ui_frame_card_green",
	"shadow": "ui/ui_frame_card_black",
	"moonlight": "ui/ui_frame_card_blue",
}
const HUMOUR_GLYPH := {
	"ferocity": "energy_claw",
	"guile": "energy_eye",
	"shadow": "energy_shade",
	"moonlight": "energy_moon",
}
const INTENT_ICON := {
	"health": "ui/ui_icon_intent_attack",
	"skills": "ui/ui_icon_intent_skills",
	"hand": "ui/ui_icon_intent_hand",
}
## Max 3 options ever shown (owner readability rule): 2 approaches + Walk In.
const APPROACH_TITLE := {
	"stalk": "Stalk — Shadow 2",
	"ambush": "Ambush — Ferocity 2",
	"case": "Case It — Guile 2",
	"ward": "Ward — Moonlight 2",
}
const APPROACH_DESC := {
	"stalk": "Begin hidden. Its first move misses. First hit +1.",
	"ambush": "Strike first for 3. It comes up angry.",
	"case": "Study the target. Draw 2 cards.",
	"ward": "Block 4 that holds through its first turn.",
}

var catalog: Catalog
var state: CombatState
var encounter_def: Dictionary
var environment_def: Dictionary
var skill_ids: Array = []
var hints: Dictionary = {}
var coach_steps: Array = []
var no_approach := false
var log_lines: Array[String] = []
var selected_skill := ""
var coach: Coach = null
var skill_buttons: Dictionary = {}
var end_turn_button: Button
var slip_button: Button

var title_label: Label
var rule_label: Label
var hint_label: Label
var enemy_art: Control
var enemy_label: Label
var thread_bar: ThreadBar
var intent_icon: TextureRect
var intent_label: Label
var alarm_label: Label
var log_label: Label
var hp_label: Label
var block_label: Label
var deck_label: Label
var turn_label: Label
var banked_row: HBoxContainer
var hand_row: HBoxContainer
var skills_row: HBoxContainer
var detail_panel: PanelContainer
var detail_label: Label
var detail_use: Button
var approach_overlay: Control
var approach_panel: Control
var overlay: Control
var overlay_label: Label
var overlay_button: Button


func setup(p_catalog: Catalog, config: Dictionary, encounter_id: String,
		p_hints: Dictionary = {}, p_coach: Array = []) -> void:
	catalog = p_catalog
	encounter_def = catalog.encounters[encounter_id]
	environment_def = catalog.environments[encounter_def["environment"]]
	skill_ids = Array(config.get("skills", []))
	hints = p_hints
	coach_steps = p_coach
	no_approach = config.get("no_approach", false)
	var full_config := config.duplicate(true)
	full_config["environment"] = environment_def
	full_config["enemy"] = encounter_def["enemies"][0]
	state = CombatState.create(catalog, int(Time.get_ticks_usec()) % 1000000007, full_config)


func _ready() -> void:
	_build_ui()
	if not coach_steps.is_empty():
		coach = Coach.new(coach_steps, _coach_target)
		add_child(coach)
	_log("— %s —" % encounter_def["name"])
	_drain_events()
	_refresh()
	_maybe_offer_approach()
	_start_ambient_animation()


func _coach_target(key: String) -> Control:
	if key.begins_with("skill:"):
		return skill_buttons.get(key.trim_prefix("skill:"), null)
	match key:
		"approach": return approach_panel if approach_overlay.visible else null
		"use": return detail_use
		"end_turn": return end_turn_button
		"slip": return slip_button
		"hand": return hand_row
	return null


# ------------------------------------------------------------------ commands

func _on_approach(mode: String) -> void:
	approach_overlay.visible = false
	if coach != null:
		coach.notify("approach")
	if mode == "":
		_log("Walked in. Sometimes the front door is the trick.")
	else:
		var result := state.do_command({"type": "approach", "mode": mode})
		if not result["ok"]:
			_log(result["error"])
	_drain_events()
	_refresh()
	if state.outcome != CombatState.Outcome.ONGOING:
		_show_outcome()


func _on_skill_selected(skill_id: String) -> void:
	if coach != null:
		coach.notify("skill:" + skill_id)
	selected_skill = skill_id
	var def: Dictionary = catalog.skills[skill_id]
	var cost := state.effective_cost(def.get("cost", {}))
	var cost_parts: Array[String] = []
	for humour in cost:
		cost_parts.append("%d %s" % [cost[humour], String(humour).capitalize()])
	var lines: Array[String] = [
		"%s — %s" % [def["name"], "free, once per turn" if def.get("instinct", false)
			else "costs " + (", ".join(cost_parts) if not cost_parts.is_empty() else "nothing")],
		_effect_summary(def),
		String(def.get("flavor", "")),
	]
	detail_label.text = "\n".join(lines)
	detail_use.disabled = not _skill_playable(skill_id)
	detail_panel.visible = true


func _on_detail_use() -> void:
	if coach != null:
		coach.notify("use")
	var skill_id := selected_skill
	_close_detail()
	var result := state.do_command({"type": "play_skill", "skill_id": skill_id})
	if result["ok"]:
		_log("Ash: %s." % catalog.skills[skill_id]["name"])
	else:
		_log(result["error"])
	_after_command()


func _close_detail() -> void:
	selected_skill = ""
	detail_panel.visible = false


func _on_card_pressed(hand_index: int) -> void:
	if coach != null:
		coach.notify("hand")
	var card_id: String = state.hand[hand_index]
	var result := state.do_command({"type": "bank", "hand_index": hand_index})
	if result["ok"]:
		_log("Banked %s." % catalog.energy_cards[card_id]["name"])
	else:
		_log(result["error"])
	_after_command()


func _on_end_turn() -> void:
	if coach != null:
		coach.notify("end_turn")
	_close_detail()
	var intent := state.current_intent()
	var was_spotted := state.spotted
	var was_hidden := state.hidden
	var result := state.do_command({"type": "end_turn"})
	if result["ok"] and not was_hidden:
		var suffix := "!" if was_spotted else "."
		_log("%s: %s%s" % [catalog.enemies[state.enemy_id]["name"], intent["name"], suffix])
	_after_command()


func _on_slip_away() -> void:
	if coach != null:
		coach.notify("slip")
	_close_detail()
	state.do_command({"type": "slip_away"})
	_after_command()


func _after_command() -> void:
	_drain_events()
	_refresh()
	if state.outcome != CombatState.Outcome.ONGOING:
		_show_outcome()


func _drain_events() -> void:
	for event in state.take_events():
		match event:
			"sunbeam": _log("A sunbeam. One spent card returns, warm.")
			"spotted": _log("SPOTTED. Expect worse manners now.")
			"warmed": _log("Still warm from the purr: +2 HP.")
			"sharpened": _log("Claws keen from a clean fight: +1 first hit.")
			"sharpened_strike": _log("The keen edge lands.")
			"hidden_wasted": _log("It strikes at the shadow you left behind.")
			"approach_stalk": _log("You are a rumor in the dark.")
			"approach_ambush": _log("Claws first. Questions never.")
			"approach_case": _log("You watch. You learn. You draw.")
			"approach_ward": _log("A ward, stitched quick and holding.")


func _maybe_offer_approach() -> void:
	if no_approach or not state.can_approach():
		return
	for mode in CombatState.APPROACHES:
		if state.can_pay(state.effective_cost(CombatState.APPROACHES[mode]["cost"])):
			approach_overlay.visible = true
			return


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
	overlay.visible = true


func _on_overlay_continue() -> void:
	encounter_finished.emit(state)


# ------------------------------------------------------------------ ui build

func _build_ui() -> void:
	var page := Panel.new()
	page.add_theme_stylebox_override("panel", UITheme.page_stylebox())
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	# Location ribbon
	var ribbon := TextureRect.new()
	ribbon.texture = UITheme.tex("ui/ui_ribbon")
	ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ribbon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ribbon.custom_minimum_size = Vector2(0, 50)
	root.add_child(ribbon)
	title_label = Label.new()
	title_label.text = environment_def["name"]
	title_label.add_theme_font_override("font", UITheme.smallcaps_font())
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", UITheme.INK)
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ribbon.add_child(title_label)

	rule_label = _label(root, 14, UITheme.INK_SOFT)
	rule_label.text = environment_def.get("rule_text", "")
	rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Scene art strip: the location, image-heavy per the owner's direction.
	var scene_strip := PanelContainer.new()
	var strip_frame := StyleBoxFlat.new()
	strip_frame.bg_color = Color(environment_def.get("color", "#333"))
	strip_frame.set_border_width_all(2)
	strip_frame.border_color = UITheme.INK
	scene_strip.add_theme_stylebox_override("panel", strip_frame)
	scene_strip.custom_minimum_size = Vector2(0, 84)
	scene_strip.clip_contents = true
	root.add_child(scene_strip)
	scene_strip.add_child(UITheme.art_or_placeholder(
		environment_def.get("image", ""), environment_def.get("name", "location art")))

	hint_label = _label(root, 16, Color("8a5a20"))
	hint_label.add_theme_font_override("font", UITheme.italic_font())
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.visible = not hints.is_empty()

	# Enemy block
	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 14)
	root.add_child(enemy_row)
	enemy_art = _framed_portrait(catalog.enemies[state.enemy_id].get("image", ""),
		String(catalog.enemies[state.enemy_id]["name"]))
	enemy_row.add_child(enemy_art)
	var enemy_col := VBoxContainer.new()
	enemy_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_col.add_theme_constant_override("separation", 6)
	enemy_col.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_row.add_child(enemy_col)
	enemy_label = _label(enemy_col, 28, UITheme.INK)
	enemy_label.add_theme_font_override("font", UITheme.display_font())
	thread_bar = ThreadBar.new()
	thread_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_col.add_child(thread_bar)
	var intent_row := HBoxContainer.new()
	intent_row.add_theme_constant_override("separation", 8)
	enemy_col.add_child(intent_row)
	intent_icon = TextureRect.new()
	intent_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	intent_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	intent_icon.custom_minimum_size = Vector2(34, 34)
	intent_row.add_child(intent_icon)
	intent_label = _label(intent_row, 17, Color("7a3b22"))
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alarm_label = _label(enemy_col, 16, Color("a03828"))

	# Log strip
	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", UITheme.strip_stylebox())
	root.add_child(log_panel)
	log_label = Label.new()
	log_label.add_theme_font_override("font", UITheme.italic_font())
	log_label.add_theme_font_size_override("font_size", 15)
	log_label.add_theme_color_override("font_color", UITheme.INK_SOFT)
	log_label.custom_minimum_size = Vector2(0, 48)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	log_panel.add_child(log_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	# Status row: icon + number pairs
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 18)
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(status_row)
	hp_label = _status_chip(status_row, "ui/ui_heart_full")
	block_label = _status_chip(status_row, "ui/ui_shield")
	deck_label = _status_chip(status_row, "ui/ui_spool")
	turn_label = _label(status_row, 16, UITheme.INK_SOFT)

	banked_row = HBoxContainer.new()
	banked_row.add_theme_constant_override("separation", 8)
	banked_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(banked_row)
	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 6)
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(hand_row)

	skills_row = HBoxContainer.new()
	skills_row.add_theme_constant_override("separation", 8)
	skills_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(skills_row)

	# Skill detail / confirm panel
	detail_panel = PanelContainer.new()
	detail_panel.visible = false
	root.add_child(detail_panel)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 8)
	detail_panel.add_child(detail_box)
	detail_label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 16)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(detail_label)
	var detail_buttons := HBoxContainer.new()
	detail_buttons.add_theme_constant_override("separation", 10)
	detail_box.add_child(detail_buttons)
	detail_use = Button.new()
	detail_use.text = "Use"
	detail_use.custom_minimum_size = Vector2(0, 50)
	detail_use.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_use.add_theme_stylebox_override("normal", UITheme.amber_stylebox())
	detail_use.add_theme_stylebox_override("hover", UITheme.amber_stylebox(Color(1.08, 1.05, 1.0)))
	detail_use.add_theme_stylebox_override("pressed", UITheme.amber_stylebox(Color(0.85, 0.8, 0.75)))
	detail_use.pressed.connect(_on_detail_use)
	detail_buttons.add_child(detail_use)
	var detail_cancel := Button.new()
	detail_cancel.text = "Not now"
	detail_cancel.custom_minimum_size = Vector2(130, 50)
	detail_cancel.pressed.connect(_close_detail)
	detail_buttons.add_child(detail_cancel)

	# Actions
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	root.add_child(action_row)
	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.custom_minimum_size = Vector2(0, 56)
	end_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_turn_button.add_theme_font_override("font", UITheme.display_font())
	end_turn_button.add_theme_font_size_override("font_size", 26)
	end_turn_button.add_theme_stylebox_override("normal", UITheme.amber_stylebox())
	end_turn_button.add_theme_stylebox_override("hover", UITheme.amber_stylebox(Color(1.08, 1.05, 1.0)))
	end_turn_button.add_theme_stylebox_override("pressed", UITheme.amber_stylebox(Color(0.85, 0.8, 0.75)))
	end_turn_button.pressed.connect(_on_end_turn)
	action_row.add_child(end_turn_button)
	slip_button = Button.new()
	slip_button.text = "Slip Away"
	slip_button.custom_minimum_size = Vector2(150, 56)
	slip_button.add_theme_stylebox_override("normal", UITheme.dark_stylebox())
	slip_button.add_theme_stylebox_override("hover", UITheme.dark_stylebox(Color(1.15, 1.15, 1.15)))
	slip_button.add_theme_stylebox_override("pressed", UITheme.dark_stylebox(Color(0.8, 0.8, 0.8)))
	slip_button.add_theme_color_override("font_color", Color("e8e4d8"))
	slip_button.pressed.connect(_on_slip_away)
	action_row.add_child(slip_button)

	approach_overlay = _build_approach_overlay()
	overlay = _build_outcome_overlay()


func _build_approach_overlay() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.07, 0.06, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	approach_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "How does Ash go in?"
	title.add_theme_font_override("font", UITheme.display_font())
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	# Readability rule: at most 2 approaches + Walk In on screen.
	var affordable: Array[String] = []
	for mode in CombatState.APPROACHES:
		if affordable.size() < 2 and \
				state.can_pay(state.effective_cost(CombatState.APPROACHES[mode]["cost"])):
			affordable.append(mode)
	for mode in affordable:
		box.add_child(_approach_button(APPROACH_TITLE[mode], APPROACH_DESC[mode], mode))
	box.add_child(_approach_button("Walk In", "Spend nothing. A door is a door.", ""))
	return dim


func _approach_button(title_text: String, desc_text: String, mode: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 96)
	b.pressed.connect(_on_approach.bind(mode))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(content)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", UITheme.display_font())
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UITheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	var desc := Label.new()
	desc.text = desc_text
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", UITheme.INK_SOFT)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(desc)
	return b


func _build_outcome_overlay() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.07, 0.06, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)
	overlay_label = Label.new()
	overlay_label.add_theme_font_override("font", UITheme.display_font())
	overlay_label.add_theme_font_size_override("font_size", 24)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(overlay_label)
	overlay_button = Button.new()
	overlay_button.custom_minimum_size = Vector2(220, 58)
	overlay_button.add_theme_stylebox_override("normal", UITheme.amber_stylebox())
	overlay_button.pressed.connect(_on_overlay_continue)
	box.add_child(overlay_button)
	return dim


func _framed_portrait(image_id: String, description: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(164, 212)
	var art := UITheme.art_or_placeholder(image_id, description)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		art.set_offset(side, 10)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		art.set_offset(side, -10)
	if art is TextureRect:
		art.clip_contents = true
	holder.add_child(art)
	var frame := UITheme.tex("ui/ui_frame_portrait")
	if frame != null:
		var frame_rect := TextureRect.new()
		frame_rect.texture = frame
		frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_rect.stretch_mode = TextureRect.STRETCH_SCALE
		frame_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(frame_rect)
	return holder


func _status_chip(parent: Container, icon_id: String) -> Label:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 4)
	parent.add_child(chip)
	var icon := TextureRect.new()
	icon.texture = UITheme.tex(icon_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(28, 28)
	chip.add_child(icon)
	var label := _label(chip, 19, UITheme.INK)
	return label


func _label(parent: Container, size: int, color: Color = UITheme.INK) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


# ------------------------------------------------------------------ refresh

func _refresh() -> void:
	var enemy: Dictionary = catalog.enemies[state.enemy_id]
	enemy_label.text = enemy["name"]
	thread_bar.set_health(maxi(state.enemy_hp, 0), state.enemy_max_hp)
	var intent := state.current_intent()
	intent_icon.texture = UITheme.tex(INTENT_ICON.get(intent["target"], ""))
	if state.hidden:
		intent_label.text = "It hasn't seen you. Its plan: %s" % intent["name"]
	elif state.spotted:
		intent_label.text = "%s! — it sees you; expect worse" % intent["name"]
	else:
		intent_label.text = "Next: %s — %s" % [intent["name"], _intent_text(intent)]
	if state.stealth_threshold > 0:
		alarm_label.visible = true
		alarm_label.text = "SPOTTED" if state.spotted \
			else "Alarm %d / %d" % [state.alarm, state.stealth_threshold]
	else:
		alarm_label.visible = false
	if hints.has(str(state.turn)):
		hint_label.text = "❋ " + String(hints[str(state.turn)])
	hp_label.text = "%d/%d" % [state.player_hp, state.player_max_hp]
	block_label.text = str(state.player_block)
	deck_label.text = str(state.deck.size())
	turn_label.text = "turn %d" % state.turn
	log_label.text = "\n".join(log_lines)

	_clear(banked_row)
	for card_id in state.banked:
		var b := _card_button(card_id, 0.8)
		b.disabled = true
		banked_row.add_child(b)
	_clear(hand_row)
	for i in state.hand.size():
		var b := _card_button(state.hand[i], 1.0)
		b.tooltip_text = "Tap to bank for later (enemies can steal it)"
		b.pressed.connect(_on_card_pressed.bind(i))
		hand_row.add_child(b)
	_clear(skills_row)
	skill_buttons.clear()
	var shown: Array[String] = []
	for skill_id in skill_ids + ["scratch"]:
		if not shown.has(skill_id):
			shown.append(skill_id)
	for skill_id in shown:
		var button := _skill_button(skill_id)
		skill_buttons[skill_id] = button
		skills_row.add_child(button)


func _card_button(card_id: String, scale := 1.0) -> Button:
	var card: Dictionary = catalog.energy_cards[card_id]
	var humour: String = card["humour"]
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(92, 126) * scale
	var frame := TextureRect.new()
	frame.texture = UITheme.tex(HUMOUR_CARD_FRAME.get(humour, ""))
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(frame)
	var glyph := TextureRect.new()
	glyph.texture = UITheme.tex(HUMOUR_GLYPH.get(humour, ""))
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.set_offset(SIDE_LEFT, 22 * scale)
	glyph.set_offset(SIDE_RIGHT, -22 * scale)
	glyph.set_offset(SIDE_TOP, 26 * scale)
	glyph.set_offset(SIDE_BOTTOM, -40 * scale)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(glyph)
	var value := Label.new()
	value.text = str(int(card["value"]))
	value.add_theme_font_override("font", UITheme.display_font())
	value.add_theme_font_size_override("font_size", int(24 * scale))
	value.add_theme_color_override("font_color", UITheme.INK)
	value.position = Vector2(12, 8) * scale
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(value)
	var name_label := Label.new()
	name_label.text = String(humour).capitalize()
	name_label.add_theme_font_size_override("font_size", int(13 * scale))
	name_label.add_theme_color_override("font_color", UITheme.INK)
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.set_offset(SIDE_TOP, -30 * scale)
	name_label.set_offset(SIDE_BOTTOM, -12 * scale)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_label)
	return b


func _skill_button(skill_id: String) -> Button:
	var def: Dictionary = catalog.skills[skill_id]
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(90, 108)
	var art := TextureRect.new()
	art.texture = UITheme.tex("sk_" + skill_id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.clip_contents = true
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.set_offset(SIDE_LEFT, 8)
	art.set_offset(SIDE_RIGHT, -8)
	art.set_offset(SIDE_TOP, 8)
	art.set_offset(SIDE_BOTTOM, -30)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)
	var frame := TextureRect.new()
	frame.texture = UITheme.tex("ui/ui_frame_skill")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.set_offset(SIDE_BOTTOM, -24)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(frame)
	var caption := Label.new()
	var runtime := state.skill_state(skill_id)
	var is_instinct: bool = def.get("instinct", false)
	var pips := ""
	if is_instinct:
		pips = "free" if not state.instinct_used else "used"
	else:
		var left := int(runtime.get("charges_left", 0))
		var total := int(def.get("charges", 0))
		for i in total:
			pips += "●" if i < left else "○"
	caption.text = "%s %s" % [def["name"], pips]
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", UITheme.INK)
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.set_offset(SIDE_TOP, -24)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(caption)
	var jammed: bool = not is_instinct and int(runtime.get("jammed_turns", 0)) > 0
	if jammed:
		caption.text = def["name"] + " [jammed]"
	b.modulate = Color(1, 1, 1, 1.0 if _skill_playable(skill_id) else 0.45)
	b.pressed.connect(_on_skill_selected.bind(skill_id))
	return b


func _skill_playable(skill_id: String) -> bool:
	var def: Dictionary = catalog.skills[skill_id]
	var runtime := state.skill_state(skill_id)
	if state.statuses.get("loafed", 0) > 0:
		return false
	if def.get("instinct", false):
		return not state.instinct_used and state.can_pay(state.effective_cost(def.get("cost", {})))
	return int(runtime.get("jammed_turns", 0)) == 0 \
		and int(runtime.get("charges_left", 0)) > 0 \
		and state.can_pay(state.effective_cost(def.get("cost", {})))


func _effect_summary(def: Dictionary) -> String:
	var parts: Array[String] = []
	for effect in def.get("effects", []):
		match effect.get("type", ""):
			"damage": parts.append("Deal %d damage" % int(effect["amount"]))
			"block": parts.append("Block %d" % int(effect["amount"]))
			"heal": parts.append("Heal %d" % int(effect["amount"]))
			"channel_heal": parts.append("Heal %d per turn for %d turns — breaks if you take damage" % [
				int(effect["amount"]), int(effect.get("turns", 2))])
			"draw": parts.append("Draw %d" % int(effect["amount"]))
			"self_stun": parts.append("You cannot act next turn")
	return " · ".join(parts)


func _intent_text(intent: Dictionary) -> String:
	match intent["target"]:
		"health": return "%d damage" % int(intent["amount"])
		"skills": return "burns a skill charge" if intent.get("mode", "jam") == "burn" else "jams a skill"
		"hand": return "steals %d card(s)" % int(intent["amount"])
	return "?"


func _start_ambient_animation() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(enemy_art, "modulate",
		Color(1.08, 1.08, 1.08), 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(enemy_art, "modulate",
		Color(0.9, 0.9, 0.9), 0.9).set_trans(Tween.TRANS_SINE)


func _log(line: String) -> void:
	log_lines.append(line)
	while log_lines.size() > 3:
		log_lines.remove_at(0)
	if log_label != null:
		log_label.text = "\n".join(log_lines)


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
