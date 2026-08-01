extends Control
## Battle screen, matched to assets/incoming/ui_objective.png:
## banner header + rule card · framed portrait beside a name-plate holding the
## thread-of-life · framed intent chip · chronicle strip · icon status strip ·
## fanned energy hand · skill cards in a parchment tray · amber End Turn with
## a dark Slip Away card. All rules live in CombatState.
##
## LAYOUT CONTRACT — 720x1280 canvas, content width 652:
##   A Header    88px   location banner (left) + rule card (right)
##   B Opponent 372px   portrait 280x360 | name-plate(thread) + intent chip
##   C Chronicle 56px
##   D Status    64px   heart · shield · spool · turn, with dividers
##   E Hand     180px   fanned energy cards 112x152
##   F Skills  160-312  tray, 4-per-row ink-bordered cards 152x148
##   G Buttons  100px

signal encounter_finished(state: CombatState)

## Drawn paw action-point pip. The generated paw art is a sparse speckled
## outline over a transparent interior — no modulate can make it read at
## 44px on parchment — so the pips are drawn (swap in art when a solid
## version exists).
class PawIcon extends Control:
	var filled := true
	func _init(p_filled: bool) -> void:
		filled = p_filled
		custom_minimum_size = Vector2(40, 40)
	func _draw() -> void:
		var ink := Color("2b2320")
		var color := ink if filled else Color(ink, 0.18)
		var s := minf(size.x, size.y)
		var center := Vector2(size.x / 2.0, size.y / 2.0)
		draw_circle(center + Vector2(0, s * 0.16), s * 0.26, color)
		for i in 4:
			var angle := deg_to_rad(-142.0 + 35.0 * i)
			draw_circle(center + Vector2(cos(angle), sin(angle)) * s * 0.32,
				s * 0.12, color)

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
const HUMOUR_COLORS := {
	"ferocity": Color("c2472e"),
	"guile": Color("5a7a3a"),
	"shadow": Color("4a4258"),
	"moonlight": Color("6a82a8"),
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

var hint_label: Label
var enemy_art: Control
var enemy_label: Label
var enemy_hp_label: Label
var thread_bar: ThreadBar
var intent_label: Label
var banner_plate: Control
var rule_plate: Control
var name_plate: Control
var intent_plate: Control
var log_plate: Control
var status_plate: Control
var paws_row: HBoxContainer
var concentrate_button: Button
var concentrate_overlay: Control
var concentrate_box: VBoxContainer
var card_overlay: Control
var card_title: Label
var card_body: Label
var card_slot: Control
var card_bank: Button
var card_discard: Button
var selected_card := -1
var alarm_label: Label
var log_label: Label
var hp_label: Label
var block_label: Label
var deck_label: Label
var turn_label: Label
var banked_row: HBoxContainer
var hand_fan: Control
var skills_grid: GridContainer
var detail_overlay: Control
var detail_panel: PanelContainer
var detail_title: Label
var detail_pips: HBoxContainer
var detail_label: Label
var detail_art: TextureRect
var detail_charge: Button
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


## Loads project art if it exists (art lands incrementally; placeholders fall back).
static func _art(image_id: String) -> Texture2D:
	return UITheme.tex(image_id)


func _ready() -> void:
	_build_ui()
	if not coach_steps.is_empty():
		coach = Coach.new(coach_steps, _coach_target)
		add_child(coach)
	# The strip under the portrait opens with WHO this is (owner request);
	# combat lines take the strip over once the action starts.
	_log(String(catalog.enemies[state.enemy_id].get("flavor", encounter_def["name"])))
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
		"charge": return detail_charge
		"banner": return banner_plate
		"rule": return rule_plate
		"portrait": return enemy_art
		"thread": return name_plate
		"intent": return intent_plate
		"chronicle": return log_plate
		"status": return status_plate
		"paws": return paws_row
		"concentrate": return concentrate_button
		"end_turn": return end_turn_button
		"slip": return slip_button
		"hand": return hand_fan
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
	_refresh_detail()
	detail_overlay.visible = true


## Fills the close-up popup from current state; called on open and after
## every charge so the pips and buttons track the card's power live.
func _refresh_detail() -> void:
	var skill_id := selected_skill
	if skill_id == "":
		return
	var def: Dictionary = catalog.skills[skill_id]
	var cost := state.effective_cost(def.get("cost", {}))
	var is_instinct: bool = def.get("instinct", false)
	var cost_parts: Array[String] = []
	for humour in cost:
		cost_parts.append("%d %s" % [cost[humour], String(humour).capitalize()])
	var title_text: String = "%s — %s" % [def["name"], "free, once per turn" if is_instinct
		else ("needs " + ", ".join(cost_parts) if not cost_parts.is_empty() else "free")]
	detail_title.text = title_text
	# Panel is 620 wide with 16px flat-stylebox margins: wrap EQUALS width.
	var title_wrap := 620.0 - 32.0
	detail_title.custom_minimum_size = Vector2(title_wrap, UITheme.measure_text(
		title_text, UITheme.display_font(), 34, title_wrap).y)
	# Energy requirement as pips: one circle per point of cost, colored by
	# humour, filled as the card is powered.
	_clear(detail_pips)
	var runtime := state.skill_state(skill_id)
	for humour in cost:
		var powered := int(runtime.get("powered", {}).get(humour, 0))
		var pips := Label.new()
		var filled := mini(powered, int(cost[humour]))
		pips.text = "●".repeat(filled) + "○".repeat(int(cost[humour]) - filled)
		pips.add_theme_font_size_override("font_size", 40)
		pips.add_theme_color_override("font_color", HUMOUR_COLORS.get(humour, UITheme.INK_SOFT))
		detail_pips.add_child(pips)
	detail_pips.visible = not cost.is_empty()
	var body_text := "%s\n%s" % [_effect_summary(def), String(def.get("flavor", ""))]
	detail_label.text = body_text
	var wrap := 620.0 - 32.0 - 200.0 - 16.0
	detail_label.custom_minimum_size = Vector2(wrap, UITheme.measure_text(
		body_text, UITheme.body_font(), 26, wrap).y + 8)
	detail_art.texture = UITheme.tex("sk_" + skill_id)
	var next_humour := ""
	for humour in state.remaining_cost(skill_id):
		next_humour = humour
		break
	detail_charge.visible = not is_instinct and not cost.is_empty()
	if detail_charge.visible:
		detail_charge.text = ("Add %s" % String(next_humour).capitalize()) \
			if next_humour != "" else "Powered"
		detail_charge.disabled = next_humour == "" or _charge_pick(next_humour).is_empty() \
			or state.paws_left < 1 or not _skill_playable(skill_id)
	detail_use.disabled = not _skill_ready(skill_id)


## The best card to feed: smallest matching value wastes the least on
## overshoot; hand is preferred over bank on ties.
func _charge_pick(humour: String) -> Dictionary:
	var best := {}
	for source in ["hand", "bank"]:
		var pool: Array = state.hand if source == "hand" else state.banked
		for i in pool.size():
			var card: Dictionary = catalog.energy_cards[pool[i]]
			if card["humour"] == humour and \
					(best.is_empty() or int(card["value"]) < int(best["value"])):
				best = {"source": source, "index": i, "value": int(card["value"])}
	return best


func _on_detail_charge() -> void:
	if coach != null:
		coach.notify("charge")
	var skill_id := selected_skill
	var next_humour := ""
	for humour in state.remaining_cost(skill_id):
		next_humour = humour
		break
	if next_humour == "":
		return
	var pick := _charge_pick(next_humour)
	if pick.is_empty():
		return
	var result := state.do_command({"type": "charge_skill", "skill_id": skill_id,
		"source": pick["source"], "index": pick["index"]})
	if result["ok"]:
		_log("Fed %s to %s." % [String(next_humour).capitalize(),
			catalog.skills[skill_id]["name"]])
	else:
		_log(result["error"])
	_drain_events()
	_refresh()
	_refresh_detail()


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
	detail_overlay.visible = false


func _on_card_pressed(hand_index: int) -> void:
	if coach != null:
		coach.notify("hand")
	selected_card = hand_index
	var card_id: String = state.hand[hand_index]
	var card: Dictionary = catalog.energy_cards[card_id]
	var humour := String(card["humour"]).capitalize()
	card_title.text = "%s — worth %d" % [humour, int(card["value"])]
	_clear(card_slot)
	var big := _card_button(card_id, 1.8)
	big.disabled = true
	card_slot.add_child(big)
	var body_text := "Bank it for later (a paw now, safe from theft... mostly).\nDiscard and it is gone until you rest at home."
	card_body.text = body_text
	var wrap := 560.0 - 32.0
	card_body.custom_minimum_size = Vector2(wrap, UITheme.measure_text(
		body_text, UITheme.body_font(), 26, wrap).y)
	card_bank.disabled = state.banked.size() >= CombatState.BANK_LIMIT or state.paws_left < 1
	card_overlay.visible = true


func _close_card() -> void:
	selected_card = -1
	card_overlay.visible = false


func _on_card_bank() -> void:
	var hand_index := selected_card
	_close_card()
	if hand_index < 0 or hand_index >= state.hand.size():
		return
	var card_id: String = state.hand[hand_index]
	var result := state.do_command({"type": "bank", "hand_index": hand_index})
	if result["ok"]:
		_log("Banked %s." % catalog.energy_cards[card_id]["name"])
	else:
		_log(result["error"])
	_after_command()


func _on_card_discard() -> void:
	var hand_index := selected_card
	_close_card()
	if hand_index < 0 or hand_index >= state.hand.size():
		return
	var card_id: String = state.hand[hand_index]
	var result := state.do_command({"type": "discard", "hand_index": hand_index})
	if result["ok"]:
		_log("Discarded %s. Gone till home." % catalog.energy_cards[card_id]["name"])
	else:
		_log(result["error"])
	_after_command()


func _on_concentrate_pressed() -> void:
	if coach != null:
		coach.notify("concentrate")
	# One button per humour with spent cards to will back.
	_clear(concentrate_box)
	var counts := {}
	for card_id in state.spent:
		var humour := String(catalog.energy_cards[card_id]["humour"])
		counts[humour] = int(counts.get(humour, 0)) + 1
	for humour in counts:
		var b := Button.new()
		b.text = "%s — %d spent" % [String(humour).capitalize(), counts[humour]]
		b.custom_minimum_size = Vector2(0, 96)
		b.add_theme_font_size_override("font_size", 28)
		b.add_theme_color_override("font_color", HUMOUR_COLORS.get(humour, UITheme.INK))
		b.pressed.connect(_on_concentrate_choose.bind(String(humour)))
		concentrate_box.add_child(b)
	if counts.is_empty():
		var none := Label.new()
		none.text = "Nothing spent yet — nothing to will back."
		none.add_theme_font_size_override("font_size", 26)
		none.add_theme_color_override("font_color", UITheme.INK_SOFT)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		concentrate_box.add_child(none)
	concentrate_overlay.visible = true


func _on_concentrate_choose(humour: String) -> void:
	concentrate_overlay.visible = false
	var result := state.do_command({"type": "concentrate", "humour": humour})
	if result["ok"]:
		_log("Ash stares at nothing. A %s comes back." % String(humour).capitalize())
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
			"concentrated": pass  # the chooser handler already narrates it


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
	# Autowrap labels reserve no height in a VBox: measure at the label's
	# true wrap width (panel 480 minus 16px margins each side) so the plate
	# always encases title and button.
	var outcome_wrap := 480.0 - 32.0
	overlay_label.custom_minimum_size = Vector2(outcome_wrap, UITheme.measure_text(
		overlay_label.text, UITheme.display_font(), 34, outcome_wrap).y)
	overlay.visible = true


func _on_overlay_continue() -> void:
	encounter_finished.emit(state)


# ------------------------------------------------------------------ ui build

func _plate(min_height: float = 0.0) -> PanelContainer:
	# Parchment plate (flat stylebox — the strip texture carries transparent
	# padding that breaks 9-patch fills, so plates are drawn, not textured).
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("efe0c2")
	style.set_border_width_all(2)
	style.border_color = Color("4a3b2c")
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	plate.add_theme_stylebox_override("panel", style)
	if min_height > 0:
		plate.custom_minimum_size = Vector2(0, min_height)
	return plate


func _build_ui() -> void:
	var page := Panel.new()
	page.add_theme_stylebox_override("panel", UITheme.page_stylebox())
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 54)
	margin.add_theme_constant_override("margin_bottom", 92)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	# --- Zone A: header — location banner left, rule card right -----------
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.custom_minimum_size = Vector2(0, 88)
	root.add_child(header)
	var banner := _plate()
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(banner)
	banner_plate = banner
	var loc := Label.new()
	loc.text = environment_def["name"]
	loc.add_theme_font_override("font", UITheme.display_font())
	loc.add_theme_font_size_override("font_size", 38)
	loc.add_theme_color_override("font_color", UITheme.INK)
	loc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_child(loc)
	var rule_card := PanelContainer.new()
	rule_card.custom_minimum_size = Vector2(240, 0)
	header.add_child(rule_card)
	rule_plate = rule_card
	var rule_label := Label.new()
	rule_label.text = environment_def.get("rule_text", "")
	rule_label.add_theme_font_size_override("font_size", 22)
	rule_label.add_theme_color_override("font_color", UITheme.INK)
	rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Label width is pinned EQUAL to the measured wrap width (law #2): the
	# panel's flat stylebox has 16px margins each side, so 240 - 32.
	var rule_wrap := 240.0 - 32.0
	var rule_measured := UITheme.measure_text(
		rule_label.text, UITheme.body_font(), 22, rule_wrap)
	rule_label.custom_minimum_size = Vector2(rule_wrap, rule_measured.y + 6)
	rule_card.add_child(rule_label)

	hint_label = Label.new()
	hint_label.add_theme_font_override("font", UITheme.italic_font())
	hint_label.add_theme_font_size_override("font_size", 24)
	hint_label.add_theme_color_override("font_color", Color("8a5a20"))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.visible = not hints.is_empty()
	root.add_child(hint_label)

	# --- Zone B: opponent -------------------------------------------------
	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 16)
	enemy_row.custom_minimum_size = Vector2(0, 366)
	root.add_child(enemy_row)
	enemy_art = _framed_portrait(catalog.enemies[state.enemy_id].get("image", ""),
		String(catalog.enemies[state.enemy_id]["name"]))
	enemy_row.add_child(enemy_art)
	var enemy_col := VBoxContainer.new()
	enemy_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_col.add_theme_constant_override("separation", 14)
	enemy_col.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_row.add_child(enemy_col)

	name_plate = _plate(120)
	enemy_col.add_child(name_plate)
	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 8)
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	name_plate.add_child(name_box)
	enemy_label = Label.new()
	enemy_label.add_theme_font_override("font", UITheme.display_font())
	enemy_label.add_theme_font_size_override("font_size", 38)
	enemy_label.add_theme_color_override("font_color", UITheme.INK)
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_box.add_child(enemy_label)
	thread_bar = ThreadBar.new()
	thread_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_child(thread_bar)
	enemy_hp_label = Label.new()
	enemy_hp_label.add_theme_font_size_override("font_size", 22)
	enemy_hp_label.add_theme_color_override("font_color", Color("8a2f22"))
	enemy_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_box.add_child(enemy_hp_label)

	# Intent chip: text only (owner 2026-08-01 — per-attack images would need
	# an image per move; the words carry it).
	intent_plate = _plate(96)
	enemy_col.add_child(intent_plate)
	intent_label = Label.new()
	intent_label.add_theme_font_size_override("font_size", 28)
	intent_label.add_theme_color_override("font_color", UITheme.INK)
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_plate.add_child(intent_label)
	alarm_label = Label.new()
	alarm_label.add_theme_font_size_override("font_size", 24)
	alarm_label.add_theme_color_override("font_color", Color("a03828"))
	alarm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_col.add_child(alarm_label)

	# --- Zone C: chronicle strip ------------------------------------------
	log_plate = _plate(40)
	root.add_child(log_plate)
	log_label = Label.new()
	log_label.add_theme_font_override("font", UITheme.italic_font())
	log_label.add_theme_font_size_override("font_size", 20)
	log_label.add_theme_color_override("font_color", UITheme.INK_SOFT)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	log_plate.add_child(log_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	# --- Zone D: status strip ---------------------------------------------
	status_plate = _plate(56)
	root.add_child(status_plate)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 12)
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_plate.add_child(status_row)
	hp_label = _status_chip(status_row, "ui/ui_heart_full")
	_divider(status_row)
	block_label = _status_chip(status_row, "ui/ui_shield")
	_divider(status_row)
	deck_label = _status_chip(status_row, "ui/ui_spool")
	_divider(status_row)
	# Paw action points: one paw per energy placement this turn.
	paws_row = HBoxContainer.new()
	paws_row.add_theme_constant_override("separation", 4)
	status_row.add_child(paws_row)
	_divider(status_row)
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 26)
	turn_label.add_theme_color_override("font_color", UITheme.INK_SOFT)
	status_row.add_child(turn_label)

	# --- Zone E: fanned hand ----------------------------------------------
	banked_row = HBoxContainer.new()
	banked_row.add_theme_constant_override("separation", 6)
	banked_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(banked_row)
	hand_fan = Control.new()
	hand_fan.custom_minimum_size = Vector2(0, 144)
	root.add_child(hand_fan)

	# --- Zone F: skills tray ----------------------------------------------
	var tray := PanelContainer.new()
	root.add_child(tray)
	skills_grid = GridContainer.new()
	skills_grid.columns = 4
	skills_grid.add_theme_constant_override("h_separation", 8)
	skills_grid.add_theme_constant_override("v_separation", 8)
	tray.add_child(skills_grid)

	# Detail popup: a centered modal over a DIMMED battle — the card close-up
	# is the only bright thing on screen (owner rule). Magnified art left,
	# measured text right, energy-requirement pips, and the powering flow:
	# feed energy onto the card; Use unlocks only once fully powered.
	var detail_dim := ColorRect.new()
	detail_dim.color = Color(0.08, 0.07, 0.06, 0.72)
	detail_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_dim.visible = false
	add_child(detail_dim)
	detail_overlay = detail_dim
	var detail_center := CenterContainer.new()
	detail_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_dim.add_child(detail_center)
	detail_panel = PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(620, 0)
	detail_center.add_child(detail_panel)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 14)
	detail_panel.add_child(detail_box)
	detail_title = Label.new()
	detail_title.add_theme_font_override("font", UITheme.display_font())
	detail_title.add_theme_font_size_override("font_size", 34)
	detail_title.add_theme_color_override("font_color", UITheme.INK)
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(detail_title)
	detail_pips = HBoxContainer.new()
	detail_pips.add_theme_constant_override("separation", 10)
	detail_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	detail_box.add_child(detail_pips)
	var detail_body := HBoxContainer.new()
	detail_body.add_theme_constant_override("separation", 16)
	detail_box.add_child(detail_body)
	var art_holder := PanelContainer.new()
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color("f4e7cd")
	art_style.set_border_width_all(3)
	art_style.border_color = UITheme.INK
	art_style.set_corner_radius_all(12)
	art_style.set_content_margin_all(6)
	art_holder.add_theme_stylebox_override("panel", art_style)
	art_holder.custom_minimum_size = Vector2(200, 200)
	art_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail_body.add_child(art_holder)
	detail_art = TextureRect.new()
	detail_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	detail_art.clip_contents = true
	art_holder.add_child(detail_art)
	detail_label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 26)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_body.add_child(detail_label)
	var detail_buttons := HBoxContainer.new()
	detail_buttons.add_theme_constant_override("separation", 12)
	detail_box.add_child(detail_buttons)
	detail_charge = Button.new()
	detail_charge.custom_minimum_size = Vector2(0, 96)
	detail_charge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_charge.add_theme_font_override("font", UITheme.display_font())
	detail_charge.add_theme_font_size_override("font_size", 30)
	detail_charge.add_theme_stylebox_override("normal", UITheme.amber_stylebox())
	detail_charge.add_theme_stylebox_override("hover", UITheme.amber_stylebox(Color(1.08, 1.05, 1.0)))
	detail_charge.add_theme_stylebox_override("pressed", UITheme.amber_stylebox(Color(0.85, 0.8, 0.75)))
	detail_charge.pressed.connect(_on_detail_charge)
	detail_buttons.add_child(detail_charge)
	detail_use = Button.new()
	detail_use.text = "Use"
	detail_use.custom_minimum_size = Vector2(150, 96)
	detail_use.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_use.add_theme_font_override("font", UITheme.display_font())
	detail_use.add_theme_font_size_override("font_size", 34)
	detail_use.add_theme_stylebox_override("normal", UITheme.amber_stylebox())
	detail_use.add_theme_stylebox_override("hover", UITheme.amber_stylebox(Color(1.08, 1.05, 1.0)))
	detail_use.add_theme_stylebox_override("pressed", UITheme.amber_stylebox(Color(0.85, 0.8, 0.75)))
	detail_use.pressed.connect(_on_detail_use)
	detail_buttons.add_child(detail_use)
	var detail_cancel := Button.new()
	detail_cancel.text = "Not now"
	detail_cancel.custom_minimum_size = Vector2(170, 96)
	detail_cancel.pressed.connect(_close_detail)
	detail_buttons.add_child(detail_cancel)

	# --- Zone G: actions ---------------------------------------------------
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	action_row.custom_minimum_size = Vector2(0, 108)
	root.add_child(action_row)
	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_turn_button.add_theme_font_override("font", UITheme.display_font())
	end_turn_button.add_theme_font_size_override("font_size", 44)
	end_turn_button.add_theme_stylebox_override("normal", UITheme.amber_stylebox())
	end_turn_button.add_theme_stylebox_override("hover", UITheme.amber_stylebox(Color(1.08, 1.05, 1.0)))
	end_turn_button.add_theme_stylebox_override("pressed", UITheme.amber_stylebox(Color(0.85, 0.8, 0.75)))
	end_turn_button.pressed.connect(_on_end_turn)
	action_row.add_child(end_turn_button)
	concentrate_button = Button.new()
	concentrate_button.text = "Concentrate"
	concentrate_button.custom_minimum_size = Vector2(170, 108)
	concentrate_button.add_theme_font_size_override("font_size", 22)
	concentrate_button.tooltip_text = "Give up the turn to will one spent energy back"
	concentrate_button.pressed.connect(_on_concentrate_pressed)
	action_row.add_child(concentrate_button)
	slip_button = Button.new()
	slip_button.text = "Slip Away"
	slip_button.custom_minimum_size = Vector2(170, 108)
	slip_button.add_theme_font_size_override("font_size", 24)
	var slip_style := StyleBoxFlat.new()
	slip_style.bg_color = Color("2e3446")
	slip_style.set_border_width_all(3)
	slip_style.border_color = Color("1a1d28")
	slip_style.set_corner_radius_all(12)
	slip_button.add_theme_stylebox_override("normal", slip_style)
	var slip_hover: StyleBoxFlat = slip_style.duplicate()
	slip_hover.bg_color = Color("3a4258")
	slip_button.add_theme_stylebox_override("hover", slip_hover)
	var slip_pressed: StyleBoxFlat = slip_style.duplicate()
	slip_pressed.bg_color = Color("232838")
	slip_button.add_theme_stylebox_override("pressed", slip_pressed)
	slip_button.add_theme_color_override("font_color", Color("e8e4d8"))
	slip_button.pressed.connect(_on_slip_away)
	action_row.add_child(slip_button)

	approach_overlay = _build_approach_overlay()
	overlay = _build_outcome_overlay()
	card_overlay = _build_card_overlay()
	concentrate_overlay = _build_concentrate_overlay()


func _divider(parent: Container) -> void:
	var divider := Label.new()
	divider.text = "|"
	divider.add_theme_font_size_override("font_size", 30)
	divider.add_theme_color_override("font_color", UITheme.INK_FADED)
	parent.add_child(divider)


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
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)
	approach_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "How does Ash go in?"
	title.add_theme_font_override("font", UITheme.display_font())
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
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
	b.custom_minimum_size = Vector2(0, 128)
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
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", UITheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	var desc := Label.new()
	desc.text = desc_text
	desc.add_theme_font_size_override("font_size", 26)
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
	overlay_label.add_theme_font_size_override("font_size", 34)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(overlay_label)
	overlay_button = Button.new()
	overlay_button.custom_minimum_size = Vector2(300, 104)
	overlay_button.add_theme_stylebox_override("normal", UITheme.amber_stylebox())
	overlay_button.pressed.connect(_on_overlay_continue)
	box.add_child(overlay_button)
	return dim


## Close-up for a tapped hand card: Bank it, Discard it, or back out.
func _build_card_overlay() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.07, 0.06, 0.72)
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
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	card_title = Label.new()
	card_title.add_theme_font_override("font", UITheme.display_font())
	card_title.add_theme_font_size_override("font_size", 34)
	card_title.add_theme_color_override("font_color", UITheme.INK)
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(card_title)
	card_slot = CenterContainer.new()
	card_slot.custom_minimum_size = Vector2(0, 256)
	box.add_child(card_slot)
	card_body = Label.new()
	card_body.add_theme_font_size_override("font_size", 26)
	card_body.add_theme_color_override("font_color", UITheme.INK_SOFT)
	card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(card_body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	card_bank = Button.new()
	card_bank.text = "Bank"
	card_bank.custom_minimum_size = Vector2(0, 96)
	card_bank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_bank.add_theme_font_override("font", UITheme.display_font())
	card_bank.add_theme_font_size_override("font_size", 30)
	card_bank.add_theme_stylebox_override("normal", UITheme.amber_stylebox())
	card_bank.add_theme_stylebox_override("hover", UITheme.amber_stylebox(Color(1.08, 1.05, 1.0)))
	card_bank.add_theme_stylebox_override("pressed", UITheme.amber_stylebox(Color(0.85, 0.8, 0.75)))
	card_bank.pressed.connect(_on_card_bank)
	buttons.add_child(card_bank)
	card_discard = Button.new()
	card_discard.text = "Discard"
	card_discard.custom_minimum_size = Vector2(150, 96)
	card_discard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_discard.add_theme_stylebox_override("normal", UITheme.dark_stylebox())
	card_discard.add_theme_stylebox_override("hover", UITheme.dark_stylebox(Color(1.2, 1.2, 1.2)))
	card_discard.add_theme_stylebox_override("pressed", UITheme.dark_stylebox(Color(0.8, 0.8, 0.8)))
	card_discard.add_theme_color_override("font_color", Color("e8e4d8"))
	card_discard.pressed.connect(_on_card_discard)
	buttons.add_child(card_discard)
	var cancel := Button.new()
	cancel.text = "Not now"
	cancel.custom_minimum_size = Vector2(150, 96)
	cancel.pressed.connect(_close_card)
	buttons.add_child(cancel)
	return dim


## Concentrate chooser: which spent energy does Ash stare back into being?
func _build_concentrate_overlay() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.07, 0.06, 0.72)
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
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Stare at nothing?"
	title.add_theme_font_override("font", UITheme.display_font())
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", UITheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var blurb := Label.new()
	blurb.text = "Will one spent energy back to the top of the deck. It costs the whole turn — the enemy acts."
	blurb.add_theme_font_size_override("font_size", 26)
	blurb.add_theme_color_override("font_color", UITheme.INK_SOFT)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var blurb_wrap := 560.0 - 32.0
	blurb.custom_minimum_size = Vector2(blurb_wrap, UITheme.measure_text(
		blurb.text, UITheme.body_font(), 26, blurb_wrap).y)
	box.add_child(blurb)
	concentrate_box = VBoxContainer.new()
	concentrate_box.add_theme_constant_override("separation", 10)
	box.add_child(concentrate_box)
	var cancel := Button.new()
	cancel.text = "Not now"
	cancel.custom_minimum_size = Vector2(0, 96)
	cancel.pressed.connect(func() -> void: concentrate_overlay.visible = false)
	box.add_child(cancel)
	return dim


func _framed_portrait(image_id: String, description: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(300, 366)
	var art := UITheme.art_or_placeholder(image_id, description)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.set_offset(SIDE_LEFT, 38)
	art.set_offset(SIDE_TOP, 36)
	art.set_offset(SIDE_RIGHT, -38)
	art.set_offset(SIDE_BOTTOM, -52)
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
	chip.add_theme_constant_override("separation", 6)
	parent.add_child(chip)
	var icon := TextureRect.new()
	# Cropped to opaque content: the generated icons float in transparent
	# padding, so the raw texture drew a glyph half the size of its box.
	icon.texture = UITheme.cropped_tex(icon_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(52, 52)
	chip.add_child(icon)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", UITheme.INK)
	chip.add_child(label)
	return label


# ------------------------------------------------------------------ refresh

func _refresh() -> void:
	var enemy: Dictionary = catalog.enemies[state.enemy_id]
	enemy_label.text = enemy["name"]
	enemy_hp_label.text = "%d / %d" % [maxi(state.enemy_hp, 0), state.enemy_max_hp]
	thread_bar.set_health(maxi(state.enemy_hp, 0), state.enemy_max_hp)
	var intent := state.current_intent()
	if state.hidden:
		intent_label.text = "Unaware. Its plan: %s" % intent["name"]
	elif state.spotted:
		intent_label.text = "%s! — it sees you" % intent["name"]
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
	_clear(paws_row)
	for i in state.paw_limit:
		var paw := PawIcon.new(i < state.paws_left)
		paw.tooltip_text = "Actions left this turn — each energy placed costs a paw"
		paws_row.add_child(paw)
	turn_label.text = "turn %d" % state.turn
	log_label.text = "\n".join(log_lines)

	_clear(banked_row)
	for card_id in state.banked:
		var b := _card_button(card_id, 0.62)
		b.disabled = true
		banked_row.add_child(b)
	_refresh_hand_fan()
	_clear(skills_grid)
	skill_buttons.clear()
	var shown: Array[String] = []
	for skill_id in skill_ids + ["scratch"]:
		if not shown.has(skill_id):
			shown.append(skill_id)
	for skill_id in shown:
		var button := _skill_button(skill_id)
		skill_buttons[skill_id] = button
		skills_grid.add_child(button)


## The hand as a fan (objective mock): overlapped, slightly rotated cards.
func _refresh_hand_fan() -> void:
	_clear(hand_fan)
	var n := state.hand.size()
	if n == 0:
		return
	var card_size := Vector2(94, 128)
	var overlap_step := 82.0
	var total_width := overlap_step * (n - 1) + card_size.x
	var start_x: float = (hand_fan.size.x - total_width) / 2.0
	if hand_fan.size.x <= 1:  # first layout pass: estimate from zone width
		start_x = (592.0 - total_width) / 2.0
	var center := (n - 1) / 2.0
	for i in n:
		var b := _card_button(state.hand[i], 1.0)
		b.tooltip_text = "Tap to bank for later (enemies can steal it)"
		b.pressed.connect(_on_card_pressed.bind(i))
		hand_fan.add_child(b)
		var offset := i - center
		b.position = Vector2(start_x + overlap_step * i,
			4.0 + 5.0 * absf(offset) * absf(offset))
		b.rotation_degrees = offset * 4.0
		b.pivot_offset = card_size / 2.0


func _card_button(card_id: String, scale := 1.0) -> Button:
	var card: Dictionary = catalog.energy_cards[card_id]
	var humour: String = card["humour"]
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(94, 128) * scale
	b.size = b.custom_minimum_size
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
	glyph.set_offset(SIDE_LEFT, 20 * scale)
	glyph.set_offset(SIDE_RIGHT, -20 * scale)
	glyph.set_offset(SIDE_TOP, 24 * scale)
	glyph.set_offset(SIDE_BOTTOM, -44 * scale)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(glyph)
	var value := Label.new()
	value.text = str(int(card["value"]))
	value.add_theme_font_override("font", UITheme.display_font())
	value.add_theme_font_size_override("font_size", int(30 * scale))
	value.add_theme_color_override("font_color", UITheme.INK)
	value.position = Vector2(14, 8) * scale
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(value)
	var name_label := Label.new()
	name_label.text = String(humour).capitalize()
	name_label.add_theme_font_size_override("font_size", int(17 * scale))
	name_label.add_theme_color_override("font_color", UITheme.INK)
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.set_offset(SIDE_TOP, -34 * scale)
	name_label.set_offset(SIDE_BOTTOM, -14 * scale)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_label)
	return b


func _skill_button(skill_id: String) -> Button:
	# Objective mock: rounded ink-bordered card, art on top, grey→colored
	# pips overlapping the art's bottom edge, name below.
	var def: Dictionary = catalog.skills[skill_id]
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(142, 112)
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("f4e7cd")
	card_style.set_border_width_all(3)
	card_style.border_color = UITheme.INK
	card_style.set_corner_radius_all(14)
	card_style.set_content_margin_all(0)
	card.add_theme_stylebox_override("panel", card_style)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(card)

	var art := TextureRect.new()
	art.texture = UITheme.tex("sk_" + skill_id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.clip_contents = true
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.set_offset(SIDE_LEFT, 6)
	art.set_offset(SIDE_RIGHT, -6)
	art.set_offset(SIDE_TOP, 6)
	art.set_offset(SIDE_BOTTOM, -40)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)

	var runtime := state.skill_state(skill_id)
	var is_instinct: bool = def.get("instinct", false)
	var humour := ""
	for key in def.get("cost", {}):
		humour = key
		break
	var pip_color: Color = HUMOUR_COLORS.get(humour, UITheme.INK_SOFT)

	var pips_label := Label.new()
	var jammed: bool = not is_instinct and int(runtime.get("jammed_turns", 0)) > 0
	if jammed:
		pips_label.text = "jammed"
	elif is_instinct:
		pips_label.text = "free" if not state.instinct_used else "spent"
	else:
		var left := int(runtime.get("charges_left", 0))
		var pips := ""
		for i in int(def.get("charges", 0)):
			pips += "●" if i < left else "○"
		pips_label.text = pips
	pips_label.add_theme_font_size_override("font_size", 24)
	pips_label.add_theme_color_override("font_color", pip_color)
	pips_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pips_label.set_offset(SIDE_TOP, -50)
	pips_label.set_offset(SIDE_BOTTOM, -28)
	pips_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pips_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pips_label)

	var name_label := Label.new()
	name_label.text = String(def["name"])
	name_label.add_theme_font_override("font", UITheme.smallcaps_font())
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", UITheme.INK)
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.set_offset(SIDE_TOP, -28)
	name_label.set_offset(SIDE_BOTTOM, -6)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_label)

	b.modulate = Color(1, 1, 1, 1.0 if _skill_playable(skill_id) else 0.45)
	b.pressed.connect(_on_skill_selected.bind(skill_id))
	return b


## Can the player DO anything with this skill right now — use it, or feed
## at least one energy onto it? Drives tray dimming and popup opening.
func _skill_playable(skill_id: String) -> bool:
	var def: Dictionary = catalog.skills[skill_id]
	var runtime := state.skill_state(skill_id)
	if state.statuses.get("loafed", 0) > 0:
		return false
	var cost := state.effective_cost(def.get("cost", {}))
	if def.get("instinct", false):
		return not state.instinct_used and state.can_pay(cost)
	if cost.is_empty() and runtime.get("free_used", false):
		return false
	if int(runtime.get("jammed_turns", 0)) > 0 \
			or int(runtime.get("charges_left", 0)) <= 0:
		return false
	if state.skill_powered(skill_id):
		return true
	# Not yet powered: feeding it needs a paw AND a matching card.
	if state.paws_left < 1:
		return false
	for humour in state.remaining_cost(skill_id):
		if not _charge_pick(humour).is_empty():
			return true
	return false


## Ready to FIRE: fully powered (owner rule — a skill is only usable once
## every pip is fed), or genuinely free.
func _skill_ready(skill_id: String) -> bool:
	var def: Dictionary = catalog.skills[skill_id]
	if def.get("instinct", false) or state.effective_cost(def.get("cost", {})).is_empty():
		return _skill_playable(skill_id)
	return _skill_playable(skill_id) and state.skill_powered(skill_id)


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
		"skills": return "burns a charge" if intent.get("mode", "jam") == "burn" else "jams a skill"
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
	while log_lines.size() > 1:
		log_lines.remove_at(0)
	if log_label != null:
		log_label.text = "\n".join(log_lines)


func _clear(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
