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
const APPROACH_TEXT := {
	"stalk": "Stalk — spend Shadow 2. Begin hidden: its first move finds nothing, and your claws stay keen (+1 first hit).",
	"ambush": "Ambush — spend Ferocity 2. Strike first for 3, but it comes up angry (+2 on its first hit).",
	"case": "Case It — spend Guile 2. Study the target: draw 2 extra cards.",
	"ward": "Ward — spend Moonlight 2. Stitch a ward: Block 4 that holds through its first turn.",
}

var catalog: Catalog
var state: CombatState
var encounter_def: Dictionary
var environment_def: Dictionary
var skill_ids: Array = []
var hints: Dictionary = {}
var log_lines: Array[String] = []
var selected_skill := ""

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
var overlay: Control
var overlay_label: Label
var overlay_button: Button


func setup(p_catalog: Catalog, config: Dictionary, encounter_id: String, p_hints: Dictionary = {}) -> void:
	catalog = p_catalog
	encounter_def = catalog.encounters[encounter_id]
	environment_def = catalog.environments[encounter_def["environment"]]
	skill_ids = Array(config.get("skills", []))
	hints = p_hints
	var full_config := config.duplicate(true)
	full_config["environment"] = environment_def
	full_config["enemy"] = encounter_def["enemies"][0]
	state = CombatState.create(catalog, int(Time.get_ticks_usec()) % 1000000007, full_config)


func _ready() -> void:
	_build_ui()
	_log("— %s —" % encounter_def["name"])
	_drain_events()
	_refresh()
	_maybe_offer_approach()
	_start_ambient_animation()


# ------------------------------------------------------------------ commands

func _on_approach(mode: String) -> void:
	approach_overlay.visible = false
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
	var card_id: String = state.hand[hand_index]
	var result := state.do_command({"type": "bank", "hand_index": hand_index})
	if result["ok"]:
		_log("Banked %s." % catalog.energy_cards[card_id]["name"])
	else:
		_log(result["error"])
	_after_command()


func _on_end_turn() -> void:
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
	if not state.can_approach():
		return
	var any_affordable := false
	for mode in CombatState.APPROACHES:
		if state.can_pay(state.effective_cost(CombatState.APPROACHES[mode]["cost"])):
			any_affordable = true
			break
	if any_affordable:
		approach_overlay.visible = true


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
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# Location ribbon
	var ribbon := TextureRect.new()
	ribbon.texture = UITheme.tex("ui/ui_ribbon")
	ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ribbon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ribbon.custom_minimum_size = Vector2(0, 58)
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

	hint_label = _label(root, 16, Color("8a5a20"))
	hint_label.add_theme_font_override("font", UITheme.italic_font())
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.visible = not hints.is_empty()

	# Enemy block
	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 14)
	root.add_child(enemy_row)
	enemy_art = _framed_portrait(catalog.enemies[state.enemy_id].get("image", ""),
		Color(catalog.enemies[state.enemy_id].get("color", "#888888")))
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
	log_label.custom_minimum_size = Vector2(0, 64)
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
	var end_turn := Button.new()
	end_turn.text = "End Turn"
	end_turn.custom_minimum_size = Vector2(0, 62)
	end_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_turn.add_theme_font_override("font", UITheme.display_font())
	end_turn.add_theme_font_size_override("font_size", 26)
	end_turn.add_theme_stylebox_override("normal", UITheme.amber_stylebox())
	end_turn.add_theme_stylebox_override("hover", UITheme.amber_stylebox(Color(1.08, 1.05, 1.0)))
	end_turn.add_theme_stylebox_override("pressed", UITheme.amber_stylebox(Color(0.85, 0.8, 0.75)))
	end_turn.pressed.connect(_on_end_turn)
	action_row.add_child(end_turn)
	var slip := Button.new()
	slip.text = "Slip Away"
	slip.custom_minimum_size = Vector2(150, 62)
	slip.add_theme_stylebox_override("normal", UITheme.dark_stylebox())
	slip.add_theme_stylebox_override("hover", UITheme.dark_stylebox(Color(1.15, 1.15, 1.15)))
	slip.add_theme_stylebox_override("pressed", UITheme.dark_stylebox(Color(0.8, 0.8, 0.8)))
	slip.add_theme_color_override("font_color", Color("e8e4d8"))
	slip.pressed.connect(_on_slip_away)
	action_row.add_child(slip)

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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "How does Ash go in?"
	title.add_theme_font_override("font", UITheme.display_font())
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for mode in CombatState.APPROACHES:
		var b := Button.new()
		b.text = APPROACH_TEXT[mode]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 64)
		b.disabled = not state.can_pay(state.effective_cost(CombatState.APPROACHES[mode]["cost"]))
		b.pressed.connect(_on_approach.bind(mode))
		box.add_child(b)
	var walk := Button.new()
	walk.text = "Walk in — spend nothing. A door is a door."
	walk.custom_minimum_size = Vector2(0, 56)
	walk.pressed.connect(_on_approach.bind(""))
	box.add_child(walk)
	return dim


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


func _framed_portrait(image_id: String, fallback: Color) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(150, 196)
	var art := UITheme.tex(image_id)
	if art != null:
		var art_rect := TextureRect.new()
		art_rect.texture = art
		art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_rect.clip_contents = true
		art_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		art_rect.set_offsets_preset(Control.PRESET_FULL_RECT)
		for side in [SIDE_LEFT, SIDE_TOP]:
			art_rect.set_offset(side, 10)
		for side in [SIDE_RIGHT, SIDE_BOTTOM]:
			art_rect.set_offset(side, -10)
		holder.add_child(art_rect)
	else:
		var swatch := ColorRect.new()
		swatch.color = fallback
		swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
		for side in [SIDE_LEFT, SIDE_TOP]:
			swatch.set_offset(side, 10)
		for side in [SIDE_RIGHT, SIDE_BOTTOM]:
			swatch.set_offset(side, -10)
		holder.add_child(swatch)
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
	for skill_id in skill_ids + ["scratch"]:
		skills_row.add_child(_skill_button(skill_id))


func _card_button(card_id: String, scale := 1.0) -> Button:
	var card: Dictionary = catalog.energy_cards[card_id]
	var humour: String = card["humour"]
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(104, 142) * scale
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
	value.text = str(card["value"])
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
	b.custom_minimum_size = Vector2(96, 118)
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
		pips = "∞" if not state.instinct_used else "—"
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
