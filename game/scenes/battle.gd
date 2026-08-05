extends Control
## Battle screen, matched to assets/library/mockups/ui_objective.png:
## banner header + rule card · framed portrait beside a name-plate holding the
## thread-of-life · framed intent chip · chronicle strip · icon status strip ·
## fanned energy hand · skill cards in a parchment tray · amber End Turn with
## a dark Slip Away card. All rules live in CombatState.
##
## ZONE TEMPLATE (owner rule: fixed template, nothing moves again).
## Content is 576x1104 inside the calibrated stitch margins
## (UITheme.PAGE_MARGIN_* = 68/40/76/136). Zone heights are REAL heights
## (content + plate margins); the sum plus separations must equal
## CONTENT_HEIGHT exactly. Verified with tests/calibrate.gd -- zones battle.
const ZONE_SEP := 3        # root VBox separation (6 gaps)
const ZONE_HEADER := 98    # banner 30px | rule card 300 wide, 20px text
const ZONE_OPPONENT := 394 # portrait 364x394 | name(thread)+intent col 200
const ZONE_CHRONICLE := 150 # last 5 log lines at 22px, plate margin 5
const ZONE_STATUS := 58    # icons 40, labels 28, margin 8 (measured: 58)
const ZONE_HAND := 140     # fanned cards 113x154 tuck up over the gap
const ZONE_SKILLS := 150   # tray margin 8, 5-per-row cards 107x134
const ZONE_ACTIONS := 96   # tap-target floor
# 98+394+150+58+140+150+96 = 1086; + 6*3 = 1104 = CONTENT_HEIGHT
# The status strip MEASURES 58, not the 56 it was declared at, so the
# template overran the page by 2px on every battle screen ever shot (owner
# tour, 2026-08-05). Two came off the opponent zone. Law 12: the numbers are
# the contract -- when reality disagrees, change the template, not the sum.

const PORTRAIT_SIZE := Vector2(364, 396)
const RULE_CARD_WIDTH := 300.0
## The chronicle keeps the whole fight and scrolls (owner 2026-08-04). The
## cap is a runaway guard, not an editorial choice.
const LOG_HISTORY := 200
const CARD_SCALE := 1.2    # energy cards (base 94x128, owner +20%)
## Five abilities out at once (owner 2026-08-03, up from four) — more room to
## play. WIDTH BUDGET: 5x107 + 4x7 separation + 2x8 tray margin = 579 <= 582.
const SKILL_COLUMNS := 5
const SKILL_TRAY_SEP := 7
const SKILL_CARD_SIZE := Vector2(107, 134)

signal encounter_finished(state: CombatState)

## Drawn paw action-point pip. The generated paw art is a sparse speckled
## outline over a transparent interior — no modulate can make it read at
## 44px on parchment — so the pips are drawn (swap in art when a solid
## version exists).
## Drawn energy-cost pips: one circle per point of cost. An allocated point
## shows the ENERGY'S OWN GLYPH inside its circle (owner rule 2026-08-02 —
## clearer than an X); the X remains only as a no-glyph fallback.
class CostPips extends Control:
	var total := 0
	var marked := 0
	var color := Color.BLACK
	var radius := 9.0
	var glyph: Texture2D = null
	func _init(p_total: int, p_marked: int, p_color: Color, p_radius := 9.0,
			p_glyph: Texture2D = null) -> void:
		total = p_total
		marked = mini(p_marked, p_total)
		color = p_color
		radius = p_radius
		glyph = p_glyph
		custom_minimum_size = Vector2(
			total * (radius * 2.0 + 8.0), radius * 2.0 + 6.0)
	func _draw() -> void:
		var step := radius * 2.0 + 8.0
		var start_x := (size.x - (step * total - 8.0)) / 2.0 + radius
		var cy := size.y / 2.0
		for i in total:
			var c := Vector2(start_x + step * i, cy)
			if i < marked:
				# FILLED, not a glyph floating in an outline (owner defect:
				# energy fed onto a card still read as "empty circle yet to be
				# filled" — a small dark claw inside a ring is not a fill).
				# The glyph rides on top in parchment, so which humour paid is
				# still legible.
				draw_circle(c, radius, color)
				if glyph != null:
					var g := radius * 1.3
					draw_texture_rect(glyph,
						Rect2(c - Vector2(g, g) / 2.0, Vector2(g, g)), false,
						UITheme.PARCHMENT)
			draw_arc(c, radius, 0.0, TAU, 24, color, 2.0, true)


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
	"mysticism": "ui/ui_frame_card_blue",
}
const HUMOUR_GLYPH := {
	"ferocity": "energy_claw",
	"guile": "energy_eye",
	"shadow": "energy_shade",
	"mysticism": "energy_moon",
}
const HUMOUR_COLORS := {
	"ferocity": Color("c2472e"),
	"guile": Color("5a7a3a"),
	"shadow": Color("4a4258"),
	"mysticism": Color("6a82a8"),
}
const APPROACH_DESC := {
	"stalk": "Begin hidden. Its first move misses. First hit +1.",
	"ambush": "Strike first for 3. It comes up angry.",
	"case": "Study it, draw 2 — it studies you back: +1 first hit.",
	"ward": "Block 4 that holds through its first turn.",
}


## Max 3 options ever shown (owner readability rule): 2 approaches + Walk In.
## The title names the PRICE in words — "Stalk — Shadow 2" read as a stat, not
## as a bill (owner defect list). Costs are the environment-adjusted ones, so
## the fog discount on Needle Lane is visible before you commit, not after.
func _approach_title(mode: String) -> String:
	var cost: Dictionary = CombatState.APPROACHES[mode]["cost"]
	var parts: Array[String] = []
	for humour in cost:
		parts.append("%d %s" % [int(cost[humour]), Catalog.humour_name(String(humour))])
	return "%s — Spend %s Energy" % [
		CombatState.APPROACHES[mode]["name"], ", ".join(parts)]

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
var _coach_pending := false
var skill_buttons: Dictionary = {}
var end_turn_button: Button
var slip_button: Button

var _last_hint_turn := -1
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
var paws_label: Label
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
var log_scroll: ScrollContainer
var hp_label: Label
var block_label: Label
var deck_label: Label
var turn_label: Label
var banked_row: HBoxContainer
var hand_fan: Control
## The fanned cards live in their own layer so refreshing the hand cannot free
## banked_row along with them (see _refresh_hand_fan).
var hand_cards: Control
## Status-strip chips the coach spotlights by name ("hp", "guard", "deck").
var status_chips: Dictionary = {}
var skills_grid: GridContainer
var detail_overlay: Control
var detail_panel: PanelContainer
var detail_title: Label
var detail_pips: HBoxContainer
var detail_uses: Label
var detail_label: Label
var detail_flavor: Label
var detail_art: TextureRect
var detail_charge: Button
var detail_use: Button
var approach_overlay: Control
var approach_panel: Control
var no_escape_overlay: Control
var no_escape_label: Label
var withdraw_overlay: Control
var withdraw_label: Label
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
	# Whether there is a way out is a property of the ENCOUNTER, not of the
	# scene that launched it — so a scenario or a quest reusing it inherits
	# the same locked door.
	full_config["no_retreat"] = encounter_def.get("no_retreat", false)
	full_config["hp_floor"] = encounter_def.get("hp_floor", 0)
	full_config["doom_turn"] = encounter_def.get("doom_turn", 0)
	# Seed comes from config when a test/scenario needs a reproducible fight;
	# live play stays clock-random.
	var seed_value := int(config.get("seed", int(Time.get_ticks_usec()) % 1000000007))
	state = CombatState.create(catalog, seed_value, full_config)


## Loads project art if it exists (art lands incrementally; placeholders fall back).
static func _art(image_id: String) -> Texture2D:
	return UITheme.tex(image_id)


func _ready() -> void:
	_build_ui()
	# The strip under the portrait opens with WHO this is (owner request);
	# combat lines take the strip over once the action starts.
	_log(String(catalog.enemies[state.enemy_id].get("flavor", encounter_def["name"])))
	_drain_events()
	_refresh()
	_maybe_offer_approach()
	# Coach starts AFTER the approach is chosen (owner fix: the loaf tip
	# used to cover the approach chooser) — unless it teaches the approach.
	if not coach_steps.is_empty():
		var first_target := String(coach_steps[0].get("target", ""))
		if approach_overlay.visible and first_target != "approach":
			_coach_pending = true
		else:
			_start_coach()
	_start_ambient_animation()


func _start_coach() -> void:
	_coach_pending = false
	coach = Coach.new(coach_steps, _coach_target)
	add_child(coach)


func _coach_target(key: String) -> Control:
	if key.begins_with("skill:"):
		# Only offer the card while it can actually be played. A coach step
		# that says "tap SLINK" waits for the tap, so an unplayable target
		# would be a wall; returning null tells the Coach the step is
		# impossible and any tap may pass it (engineering law 13).
		# ...but only for a step that WAITS. A note ABOUT a card — "look how
		# few uses Pounce has left" — must still point at the card even when
		# it is unaffordable, which is usually the very moment worth pointing
		# at (owner 2026-08-04: the charges lesson spotlit nothing).
		var skill_id := key.trim_prefix("skill:")
		if coach != null and coach.waits_for_action() and not _skill_playable(skill_id):
			return null
		return skill_buttons.get(skill_id, null)
	# The status strip's chips are spotlit individually (owner defect: the
	# heart, shield and spool steps resolved to nothing, so the tutorial
	# explained them while highlighting the middle of the screen).
	if status_chips.has(key):
		return status_chips[key]
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
	if _coach_pending:
		_start_coach()
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
		cost_parts.append("%d %s" % [cost[humour], Catalog.humour_name(String(humour))])
	var title_text: String = "%s — %s" % [def["name"], "free, once per turn" if is_instinct
		else ("needs " + ", ".join(cost_parts) if not cost_parts.is_empty() else "free")]
	detail_title.text = title_text
	# How many uses are left has to be readable HERE, magnified (owner
	# 2026-08-04) — the tray badge is a corner glance, not an answer.
	var runtime_uses := state.skill_state(skill_id)
	if is_instinct:
		detail_uses.text = "Always there. Once a turn."
	else:
		var left := int(runtime_uses.get("charges_left", 0))
		detail_uses.text = "No uses left tonight" if left <= 0 \
			else ("%d use left tonight" % left if left == 1 else "%d uses left tonight" % left)
	detail_uses.add_theme_color_override("font_color",
		Color("8a2f22") if (not is_instinct and int(runtime_uses.get("charges_left", 0)) <= 0)
		else UITheme.INK_SOFT)
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
		detail_pips.add_child(CostPips.new(int(cost[humour]),
			powered, HUMOUR_COLORS.get(humour, UITheme.INK_SOFT), 15.0,
			UITheme.cropped_tex(HUMOUR_GLYPH.get(humour, ""))))
	detail_pips.visible = not cost.is_empty()
	var wrap := 620.0 - 32.0 - 200.0 - 16.0
	var effect_text := _effect_summary(def)
	detail_label.text = effect_text
	detail_label.custom_minimum_size = Vector2(wrap, UITheme.measure_text(
		effect_text, UITheme.body_font(), 26, wrap).y + 4)
	var flavor_text := String(def.get("flavor", ""))
	detail_flavor.text = flavor_text
	detail_flavor.visible = flavor_text != ""
	detail_flavor.custom_minimum_size = Vector2(wrap, UITheme.measure_text(
		flavor_text, UITheme.italic_font(), 24, wrap).y + 4)
	detail_art.texture = UITheme.tex("sk_" + skill_id)
	var next_humour := ""
	for humour in state.remaining_cost(skill_id):
		next_humour = humour
		break
	detail_charge.visible = not is_instinct and not cost.is_empty()
	if detail_charge.visible:
		detail_charge.text = ("Add %s" % Catalog.humour_name(String(next_humour))) \
			if next_humour != "" else "Powered"
		detail_charge.disabled = next_humour == "" or _charge_pick(next_humour).is_empty() \
			or state.paws_left < 1 or not _skill_playable(skill_id)
	detail_use.disabled = not _skill_ready(skill_id)


## The best card to feed: smallest matching value wastes the least on
## overshoot; hand is preferred over bank on ties. Exact humour beats a
## mysticism wild — wilds are too precious to spend when a match exists.
func _charge_pick(humour: String) -> Dictionary:
	var best := {}
	var best_wild := {}
	for source in ["hand", "bank"]:
		var pool: Array = state.hand if source == "hand" else state.banked
		for i in pool.size():
			var card: Dictionary = catalog.energy_cards[pool[i]]
			var pick := {"source": source, "index": i, "value": int(card["value"])}
			if card["humour"] == humour and \
					(best.is_empty() or int(card["value"]) < int(best["value"])):
				best = pick
			elif card["humour"] == CombatState.WILD_HUMOUR and \
					(best_wild.is_empty() or int(card["value"]) < int(best_wild["value"])):
				best_wild = pick
	return best if not best.is_empty() else best_wild


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
		_log("Fed %s to %s." % [Catalog.humour_name(String(next_humour)),
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
	if not result["ok"]:
		_log(result["error"])  # the journal records what succeeded
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
	var humour := Catalog.humour_name(String(card["humour"]))
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
		b.text = "%s — %d spent" % [Catalog.humour_name(String(humour)), counts[humour]]
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
		_log("Ash stares at nothing. A %s comes back." % Catalog.humour_name(String(humour)))
	else:
		_log(result["error"])
	_after_command()


func _on_end_turn() -> void:
	if coach != null:
		coach.notify("end_turn")
	_close_detail()
	_log("— turn %d —" % state.turn)
	state.do_command({"type": "end_turn"})
	_after_command()


func _on_slip_away() -> void:
	if coach != null:
		coach.notify("slip")
	_close_detail()
	var result := state.do_command({"type": "slip_away"})
	if not result["ok"]:
		# There is no door. Say so in the creature's own terms and put the
		# player back in the room (owner rule 2026-08-04) — a button that
		# silently does nothing reads as a broken button, not a locked one.
		_show_no_escape()
		return
	_after_command()


## Refusal card for a no_retreat fight. Flavour comes from the encounter so
## each locked room can explain itself in its own voice.
func _show_no_escape() -> void:
	no_escape_label.text = String(encounter_def.get("no_retreat_text",
		"There is nowhere that is not also here."))
	var wrap := 520.0 - 32.0
	no_escape_label.custom_minimum_size = Vector2(wrap, UITheme.measure_text(
		no_escape_label.text, UITheme.italic_font(), 30, wrap).y)
	no_escape_overlay.visible = true


func _after_command() -> void:
	_drain_events()
	_refresh()
	if state.outcome != CombatState.Outcome.ONGOING:
		_show_outcome()
		return
	_maybe_insist_on_withdrawing()


## Some fights are lessons about leaving. Once the encounter's `withdraw_after`
## turn has passed, the game stops hinting and says it (owner rule
## 2026-08-04): the only button is Slip Away. Paired with `hp_floor` in the
## rules, so the lesson can be slow to land without being fatal.
func _maybe_insist_on_withdrawing() -> void:
	var after := int(encounter_def.get("withdraw_after", 0))
	if after <= 0 or state.turn <= after or withdraw_overlay.visible:
		return
	withdraw_label.text = String(encounter_def.get("withdraw_text",
		"This is not a fight. It is a weather. Go around it."))
	var wrap := 520.0 - 32.0
	withdraw_label.custom_minimum_size = Vector2(wrap, UITheme.measure_text(
		withdraw_label.text, UITheme.italic_font(), 30, wrap).y)
	withdraw_overlay.visible = true


func _drain_events() -> void:
	# The mechanical record first (what an action actually DID), then the
	# flavour events. Core owns the numbers; the scene owns the voice.
	for line in state.take_journal():
		_log(line)
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
			"parting_shot": _log("You turn your back. It takes its turn anyway.")
			"loaf_guarded": _log("It paws at a cat with nothing loose. Nothing gives.")
			"night_presses": _log("The night presses. It grows bolder.")
			"undone": _log("It finishes the sentence it started.")
			"concentrated": pass  # the chooser handler already narrates it


func _maybe_offer_approach() -> void:
	if no_approach or not state.can_approach():
		return
	for mode in CombatState.APPROACHES:
		if state.can_pay(CombatState.APPROACHES[mode]["cost"]):
			approach_overlay.visible = true
			return


func _show_outcome() -> void:
	match state.outcome:
		CombatState.Outcome.VICTORY:
			overlay_label.text = "%s: dealt with." % catalog.enemies[state.enemy_id]["name"]
			overlay_button.text = "Continue"
		CombatState.Outcome.DEFEAT:
			overlay_label.text = "The dark comes up like a floor."
			overlay_button.text = "Get up"
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

func _plate(min_height: float = 0.0, content_margin: float = 12.0) -> PanelContainer:
	# Parchment plate (flat stylebox — the strip texture carries transparent
	# padding that breaks 9-patch fills, so plates are drawn, not textured).
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("efe0c2")
	style.set_border_width_all(2)
	style.border_color = Color("4a3b2c")
	style.set_corner_radius_all(10)
	style.set_content_margin_all(content_margin)
	plate.add_theme_stylebox_override("panel", style)
	if min_height > 0:
		plate.custom_minimum_size = Vector2(0, min_height)
	return plate


func _build_ui() -> void:
	var margin := UITheme.page_scaffold(self)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", ZONE_SEP)
	margin.add_child(root)

	# --- Zone A: header — location banner left, rule card right -----------
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.custom_minimum_size = Vector2(0, ZONE_HEADER)
	root.add_child(header)
	var banner := _plate()
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(banner)
	banner_plate = banner
	# WIDTH BUDGET (law 5, step 3): the banner gets whatever the fixed rule
	# card leaves. A plain Label reports its minimum width as the WHOLE
	# unwrapped string, so "The Shambles, After Hours" at 30pt demanded ~400px
	# and grew the page to 820 in a 720 window — every zone off the right edge
	# of the book. The type size is now picked from the box.
	var banner_box := Vector2(
		UITheme.CONTENT_WIDTH - 12.0 - RULE_CARD_WIDTH - 32.0, ZONE_HEADER - 20.0)
	var loc := UITheme.fitted_label(environment_def["name"], [30, 27, 24, 21],
		banner_box, UITheme.display_font())
	loc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(loc)
	var rule_card := PanelContainer.new()
	rule_card.custom_minimum_size = Vector2(RULE_CARD_WIDTH, 0)
	header.add_child(rule_card)
	rule_plate = rule_card
	var rule_label := Label.new()
	rule_label.text = environment_def.get("rule_text", "")
	rule_label.add_theme_font_size_override("font_size", 20)
	rule_label.add_theme_color_override("font_color", UITheme.INK)
	rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Label width is pinned EQUAL to the measured wrap width (law #2): the
	# panel's flat stylebox has 16px margins each side.
	var rule_wrap := RULE_CARD_WIDTH - 32.0
	var rule_measured := UITheme.measure_text(
		rule_label.text, UITheme.body_font(), 20, rule_wrap)
	rule_label.custom_minimum_size = Vector2(rule_wrap, rule_measured.y + 4)
	rule_card.add_child(rule_label)

	# --- Zone B: opponent -------------------------------------------------
	# (Hints render as chronicle lines — a floating label broke the budget.)
	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 12)
	enemy_row.custom_minimum_size = Vector2(0, ZONE_OPPONENT)
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
	enemy_label.add_theme_font_size_override("font_size", 30)
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

	# --- Zone C: chronicle — the WHOLE fight, scrollable -------------------
	# Owner 2026-08-04: the strip used to keep only the last five lines, which
	# meant the turn you wanted to check had already scrolled off. It now
	# holds everything and scrolls, pinned to the bottom as lines arrive.
	log_plate = _plate(ZONE_CHRONICLE, 6)
	root.add_child(log_plate)
	log_scroll = ScrollContainer.new()
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	log_plate.add_child(log_scroll)
	log_label = Label.new()
	log_label.add_theme_font_override("font", UITheme.italic_font())
	log_label.add_theme_font_size_override("font_size", 22)
	log_label.add_theme_color_override("font_color", UITheme.INK_SOFT)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_scroll.add_child(log_label)

	# --- Zone D: status strip ---------------------------------------------
	# WIDTH BUDGET: the strip is the widest zone; its minimum width must stay
	# under 592 or the parent VBox stretches EVERY plate past the right
	# stitching (the all-boxes-overflow bug). Icons 48, separation 8,
	# one paw + a count (owner rule), short labels.
	status_plate = _plate(0, 8)
	root.add_child(status_plate)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_plate.add_child(status_row)
	hp_label = _status_chip(status_row, "ui/ui_heart_full", "hp")
	_divider(status_row)
	block_label = _status_chip(status_row, "ui/ui_shield", "guard")
	_divider(status_row)
	deck_label = _status_chip(status_row, "ui/ui_spool", "deck")
	_divider(status_row)
	# Paw action points: one paw icon + how many placements remain.
	paws_row = HBoxContainer.new()
	paws_row.add_theme_constant_override("separation", 6)
	paws_row.tooltip_text = "Actions left this turn — each energy placed costs a paw"
	status_row.add_child(paws_row)
	paws_row.add_child(PawIcon.new(true))
	paws_label = Label.new()
	paws_label.add_theme_font_size_override("font_size", 28)
	paws_label.add_theme_color_override("font_color", UITheme.INK)
	paws_row.add_child(paws_label)
	_divider(status_row)
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 26)
	turn_label.add_theme_color_override("font_color", UITheme.INK_SOFT)
	status_row.add_child(turn_label)

	# --- Zone E: fanned hand (banked cards overlay its top-left corner) ---
	hand_fan = Control.new()
	hand_fan.custom_minimum_size = Vector2(0, ZONE_HAND)
	root.add_child(hand_fan)
	banked_row = HBoxContainer.new()
	banked_row.add_theme_constant_override("separation", 4)
	banked_row.position = Vector2(2, -6)
	hand_fan.add_child(banked_row)
	# Cards get their OWN layer. Rebuilding the fan used to clear hand_fan
	# wholesale, which freed banked_row with it — and every _refresh() after
	# the first then died on the freed node, half-done: the counters updated
	# but the hand never shrank, spent skills never faded and fed pips never
	# filled. One line of blast radius, six entries on the defect list.
	hand_cards = Control.new()
	hand_cards.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_fan.add_child(hand_cards)

	# --- Zone F: skills tray ----------------------------------------------
	# WIDTH BUDGET: 4 cards at 134 + 3x8 sep + 2x8 tray margin = 566 <= 582.
	var tray := PanelContainer.new()
	var tray_style := UITheme.panel_stylebox(8)
	tray.add_theme_stylebox_override("panel", tray_style)
	root.add_child(tray)
	skills_grid = GridContainer.new()
	skills_grid.columns = SKILL_COLUMNS
	skills_grid.add_theme_constant_override("h_separation", SKILL_TRAY_SEP)
	skills_grid.add_theme_constant_override("v_separation", SKILL_TRAY_SEP)
	tray.add_child(skills_grid)

	# Detail popup: a centered modal over a DIMMED battle — the card close-up
	# is the only bright thing on screen (owner rule). Magnified art left,
	# measured text right, energy-requirement pips, and the powering flow:
	# feed energy onto the card; Use unlocks only once fully powered.
	var detail_modal := UITheme.modal(self, 620.0)
	detail_overlay = detail_modal["overlay"]
	detail_panel = detail_modal["panel"]
	var detail_box: VBoxContainer = detail_modal["box"]
	detail_title = Label.new()
	detail_title.add_theme_font_override("font", UITheme.display_font())
	detail_title.add_theme_font_size_override("font_size", 34)
	detail_title.add_theme_color_override("font_color", UITheme.INK)
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(detail_title)
	detail_uses = Label.new()
	detail_uses.add_theme_font_override("font", UITheme.smallcaps_font())
	detail_uses.add_theme_font_size_override("font_size", 26)
	detail_uses.add_theme_color_override("font_color", UITheme.INK_SOFT)
	detail_uses.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_box.add_child(detail_uses)
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
	var detail_text_col := VBoxContainer.new()
	detail_text_col.add_theme_constant_override("separation", 10)
	detail_text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	detail_body.add_child(detail_text_col)
	detail_label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 26)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_text_col.add_child(detail_label)
	# Flavor is ITALIC and softer — clearly voice, not rules (owner rule).
	detail_flavor = Label.new()
	detail_flavor.add_theme_font_override("font", UITheme.italic_font())
	detail_flavor.add_theme_font_size_override("font_size", 24)
	detail_flavor.add_theme_color_override("font_color", UITheme.INK_SOFT)
	detail_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_text_col.add_child(detail_flavor)
	var detail_buttons := HBoxContainer.new()
	detail_buttons.add_theme_constant_override("separation", 12)
	detail_box.add_child(detail_buttons)
	detail_charge = UITheme.amber_button("", 30)
	detail_charge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_charge.pressed.connect(_on_detail_charge)
	detail_buttons.add_child(detail_charge)
	detail_use = UITheme.amber_button("Use", 34, Vector2(150, UITheme.BUTTON_HEIGHT))
	detail_use.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_use.pressed.connect(_on_detail_use)
	detail_buttons.add_child(detail_use)
	var detail_cancel := Button.new()
	detail_cancel.text = "Not now"
	detail_cancel.custom_minimum_size = Vector2(170, UITheme.BUTTON_HEIGHT)
	detail_cancel.pressed.connect(_close_detail)
	detail_buttons.add_child(detail_cancel)

	# --- Zone G: actions ---------------------------------------------------
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	action_row.custom_minimum_size = Vector2(0, ZONE_ACTIONS)
	root.add_child(action_row)
	end_turn_button = UITheme.amber_button("End Turn", 40, Vector2(0, ZONE_ACTIONS))
	end_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_turn_button.pressed.connect(_on_end_turn)
	action_row.add_child(end_turn_button)
	concentrate_button = Button.new()
	concentrate_button.text = "Concentrate"
	concentrate_button.custom_minimum_size = Vector2(148, ZONE_ACTIONS)
	concentrate_button.add_theme_font_override("font", UITheme.smallcaps_font())
	concentrate_button.add_theme_font_size_override("font_size", 22)
	concentrate_button.tooltip_text = "Give up the turn to will one spent energy back"
	concentrate_button.pressed.connect(_on_concentrate_pressed)
	action_row.add_child(concentrate_button)
	slip_button = UITheme.dark_button("Slip Away", 24, Vector2(148, ZONE_ACTIONS))
	slip_button.add_theme_font_override("font", UITheme.smallcaps_font())
	slip_button.tooltip_text = \
		"Leave now — but it gets its telegraphed move in as you go"
	slip_button.pressed.connect(_on_slip_away)
	action_row.add_child(slip_button)
	# The button STAYS in a no_retreat fight (owner 2026-08-04): reaching for
	# the door and finding the room has no outside is the beat. Tapping it
	# explains, then hands the player back to the fight.

	approach_overlay = _build_approach_overlay()
	overlay = _build_outcome_overlay()
	card_overlay = _build_card_overlay()
	concentrate_overlay = _build_concentrate_overlay()
	no_escape_overlay = _build_no_escape_overlay()
	withdraw_overlay = _build_withdraw_overlay()


func _divider(parent: Container) -> void:
	var divider := Label.new()
	divider.text = "|"
	divider.add_theme_font_size_override("font_size", 30)
	divider.add_theme_color_override("font_color", UITheme.INK_FADED)
	parent.add_child(divider)


func _build_approach_overlay() -> Control:
	var modal := UITheme.modal(self, 560.0, 10)
	approach_panel = modal["panel"]
	var box: VBoxContainer = modal["box"]
	var title := Label.new()
	title.text = "How does Ash go in?"
	title.add_theme_font_override("font", UITheme.display_font())
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var affordable: Array[String] = []
	for mode in CombatState.APPROACHES:
		if affordable.size() < 2 and \
				state.can_pay(CombatState.APPROACHES[mode]["cost"]):
			affordable.append(mode)
	for mode in affordable:
		box.add_child(_approach_button(_approach_title(mode), APPROACH_DESC[mode], mode))
	box.add_child(_approach_button("Walk In", "Spend nothing. A door is a door.", ""))
	return modal["overlay"]


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
	var modal := UITheme.modal(self, 480.0, 20)
	overlay_label = Label.new()
	overlay_label.add_theme_font_override("font", UITheme.display_font())
	overlay_label.add_theme_font_size_override("font_size", 34)
	overlay_label.add_theme_color_override("font_color", UITheme.INK)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal["box"].add_child(overlay_label)
	overlay_button = UITheme.amber_button("", 30, Vector2(300, 104))
	overlay_button.pressed.connect(_on_overlay_continue)
	modal["box"].add_child(overlay_button)
	return modal["overlay"]


## Close-up for a tapped hand card: Bank it, Discard it, or back out.
func _build_card_overlay() -> Control:
	var modal := UITheme.modal(self, 560.0)
	var box: VBoxContainer = modal["box"]
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
	card_bank = UITheme.amber_button("Bank", 30)
	card_bank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_bank.pressed.connect(_on_card_bank)
	buttons.add_child(card_bank)
	card_discard = UITheme.dark_button("Discard")
	card_discard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_discard.pressed.connect(_on_card_discard)
	buttons.add_child(card_discard)
	var cancel := Button.new()
	cancel.text = "Not now"
	cancel.custom_minimum_size = Vector2(150, UITheme.BUTTON_HEIGHT)
	cancel.pressed.connect(_close_card)
	buttons.add_child(cancel)
	return modal["overlay"]


## "There is no out." Shown when a no_retreat fight refuses Slip Away; the
## only button puts the player back where they were.
func _build_no_escape_overlay() -> Control:
	var modal := UITheme.modal(self, 520.0, 18)
	var box: VBoxContainer = modal["box"]
	var title := Label.new()
	title.text = "No."
	title.add_theme_font_override("font", UITheme.display_font())
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UITheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	no_escape_label = Label.new()
	no_escape_label.add_theme_font_override("font", UITheme.italic_font())
	no_escape_label.add_theme_font_size_override("font_size", 30)
	no_escape_label.add_theme_color_override("font_color", UITheme.INK)
	no_escape_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	no_escape_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(no_escape_label)
	var back := UITheme.amber_button("Turn and face it", 30)
	back.pressed.connect(func() -> void: no_escape_overlay.visible = false)
	box.add_child(back)
	return modal["overlay"]


## The scripted withdrawal. A fight the story means you to leave says so out
## loud once it has been made (owner rule 2026-08-04) — and the only way on
## is out, so the lesson cannot be failed to death.
func _build_withdraw_overlay() -> Control:
	var modal := UITheme.modal(self, 520.0, 18)
	var box: VBoxContainer = modal["box"]
	var title := Label.new()
	title.text = "Not tonight."
	title.add_theme_font_override("font", UITheme.display_font())
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UITheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	withdraw_label = Label.new()
	withdraw_label.add_theme_font_override("font", UITheme.italic_font())
	withdraw_label.add_theme_font_size_override("font_size", 30)
	withdraw_label.add_theme_color_override("font_color", UITheme.INK)
	withdraw_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	withdraw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(withdraw_label)
	var go := UITheme.amber_button("Slip Away", 32)
	go.pressed.connect(func() -> void:
		withdraw_overlay.visible = false
		_on_slip_away())
	box.add_child(go)
	return modal["overlay"]


## Concentrate chooser: which spent energy does Ash stare back into being?
func _build_concentrate_overlay() -> Control:
	var modal := UITheme.modal(self, 560.0, 12)
	var box: VBoxContainer = modal["box"]
	var title := Label.new()
	title.text = "Stare at nothing?"
	title.add_theme_font_override("font", UITheme.display_font())
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", UITheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var blurb := UITheme.measured_label(
		"Will one spent energy back to the top of the deck. It costs the whole turn — the enemy acts.",
		26, 560.0 - 32.0, null, UITheme.INK_SOFT)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(blurb)
	concentrate_box = VBoxContainer.new()
	concentrate_box.add_theme_constant_override("separation", 10)
	box.add_child(concentrate_box)
	var cancel := Button.new()
	cancel.text = "Not now"
	cancel.custom_minimum_size = Vector2(0, UITheme.BUTTON_HEIGHT)
	cancel.pressed.connect(func() -> void: concentrate_overlay.visible = false)
	box.add_child(cancel)
	return modal["overlay"]


func _framed_portrait(image_id: String, description: String) -> Control:
	# The opponent is the biggest thing on the page (owner rule, thrice now).
	var holder := Control.new()
	holder.custom_minimum_size = PORTRAIT_SIZE
	var art := UITheme.art_or_placeholder(image_id, description)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Frame-art insets scale with the frame (base 38/36/38/52 at 300x366).
	var inset_scale := PORTRAIT_SIZE.x / 300.0
	art.set_offset(SIDE_LEFT, 38 * inset_scale)
	art.set_offset(SIDE_TOP, 36 * inset_scale)
	art.set_offset(SIDE_RIGHT, -38 * inset_scale)
	art.set_offset(SIDE_BOTTOM, -52 * inset_scale)
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


func _status_chip(parent: Container, icon_id: String, coach_key := "") -> Label:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 6)
	parent.add_child(chip)
	if coach_key != "":
		status_chips[coach_key] = chip
	var icon := TextureRect.new()
	# Cropped to opaque content: the generated icons float in transparent
	# padding, so the raw texture drew a glyph half the size of its box.
	icon.texture = UITheme.cropped_tex(icon_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(40, 40)
	chip.add_child(icon)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", UITheme.INK)
	chip.add_child(label)
	return label


# ------------------------------------------------------------------ refresh

func _refresh() -> void:
	var enemy: Dictionary = catalog.enemies[state.enemy_id]
	# display_name may carry a deliberate line break (e.g. "The Dog\n(On a
	# Chain)") — autowrap alone broke names badly.
	enemy_label.text = String(enemy.get("display_name", enemy["name"]))
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
	# Hints join the chronicle (a floating label broke the zone budget).
	var hint_key := str(state.turn)
	if hints.has(hint_key) and _last_hint_turn != state.turn:
		_last_hint_turn = state.turn
		_log("❋ " + String(hints[hint_key]))
	hp_label.text = "%d/%d" % [maxi(state.player_hp, 0), state.player_max_hp]
	block_label.text = str(state.player_block)
	deck_label.text = str(state.deck.size())
	paws_label.text = str(state.paws_left)
	turn_label.text = "turn %d" % state.turn
	log_label.text = "\n".join(log_lines)

	_clear(banked_row)
	for card_id in state.banked:
		var b := _card_button(card_id, 0.75)
		b.disabled = true
		banked_row.add_child(b)
	_refresh_hand_fan()
	_clear(skills_grid)
	skill_buttons.clear()
	# Scratch ALWAYS occupies the first slot, then the loadout in its own
	# order (owner defect: a battle that pinned its skills without naming
	# Scratch pushed it to the far right, so the tray reshuffled between
	# fights). The tray is muscle memory — it does not move.
	var shown: Array[String] = ["scratch"]
	for skill_id in skill_ids:
		if not shown.has(skill_id):
			shown.append(skill_id)
	# Loadout law (owner 2026-08-03): at most SaveService.LOADOUT_SIZE
	# abilities out at a time, Scratch included. Battle configs must respect
	# this; clamp defensively.
	if shown.size() > SaveService.LOADOUT_SIZE:
		push_warning("battle: %d abilities configured, loadout max is %d" % [
			shown.size(), SaveService.LOADOUT_SIZE])
		shown = shown.slice(0, SaveService.LOADOUT_SIZE)
	for skill_id in shown:
		var button := _skill_button(skill_id)
		skill_buttons[skill_id] = button
		skills_grid.add_child(button)


## The hand as a fan (objective mock): overlapped, slightly rotated cards.
func _refresh_hand_fan() -> void:
	_clear(hand_cards)
	var n := state.hand.size()
	if n == 0:
		return
	var card_size := Vector2(94, 128) * CARD_SCALE
	var overlap_step := 98.0
	var total_width := overlap_step * (n - 1) + card_size.x
	var start_x: float = (hand_fan.size.x - total_width) / 2.0
	if hand_fan.size.x <= 1:  # first layout pass: estimate from zone width
		start_x = (float(UITheme.CONTENT_WIDTH) - total_width) / 2.0
	var center := (n - 1) / 2.0
	for i in n:
		var b := _card_button(state.hand[i], CARD_SCALE)
		b.tooltip_text = "Tap to bank or discard"
		b.pressed.connect(_on_card_pressed.bind(i))
		hand_cards.add_child(b)
		var offset := i - center
		# Tucked up slightly: the cards may overhang the zone gap above,
		# never the tray below.
		b.position = Vector2(start_x + overlap_step * i,
			-10.0 + 3.0 * absf(offset) * absf(offset))
		b.rotation_degrees = offset * 3.0
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
	name_label.text = Catalog.humour_name(String(humour))
	name_label.add_theme_font_size_override("font_size", int(17 * scale))
	name_label.add_theme_color_override("font_color", UITheme.INK)
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# Raised band: the hand fan tucks card bottoms under the skill tray
	# (ZONE_HAND < card height), and the old -34..-14 band left the name
	# half-swallowed by the tuck + frame border (owner defect list).
	name_label.set_offset(SIDE_TOP, -46 * scale)
	name_label.set_offset(SIDE_BOTTOM, -26 * scale)
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
	b.custom_minimum_size = SKILL_CARD_SIZE
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
	# Art must STOP above the pips band — art bleeding behind the hollow
	# circles read as phantom X marks.
	art.set_offset(SIDE_BOTTOM, -56)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)

	var runtime := state.skill_state(skill_id)
	var is_instinct: bool = def.get("instinct", false)
	var humour := ""
	for key in def.get("cost", {}):
		humour = key
		break
	var pip_color: Color = HUMOUR_COLORS.get(humour, UITheme.INK_SOFT)

	var jammed: bool = not is_instinct and int(runtime.get("jammed_turns", 0)) > 0
	var charges_left := int(runtime.get("charges_left", 0))
	var out_of_charges: bool = not is_instinct and charges_left <= 0
	var cost := state.effective_cost(def.get("cost", {}))
	# The status band under the art says the ONE thing that is stopping you.
	# Order matters: "free" used to win over "no charges left", so a Slink
	# discounted to free by the fog read as playable while refusing every tap
	# (owner defect: "even though slink is free, I can't play it").
	var band := ""
	if jammed:
		band = "jammed"
	elif out_of_charges:
		band = "used up"
	elif is_instinct:
		band = "free" if not state.instinct_used else "spent"
	elif cost.is_empty():
		band = "free here" if not runtime.get("free_used", false) else "spent"
	if band != "":
		var pips_label := Label.new()
		pips_label.text = band
		pips_label.add_theme_font_size_override("font_size", 22)
		pips_label.add_theme_color_override("font_color", pip_color)
		pips_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		pips_label.set_offset(SIDE_TOP, -50)
		pips_label.set_offset(SIDE_BOTTOM, -28)
		pips_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pips_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pips_label)
	else:
		# Cost pips: circles = energy needed, filled = already fed.
		var cost_total := 0
		var allocated := 0
		var powered: Dictionary = runtime.get("powered", {})
		for key in cost:
			cost_total += int(cost[key])
			allocated += mini(int(powered.get(key, 0)), int(cost[key]))
		var pips := CostPips.new(cost_total, allocated, pip_color, 9.0,
			UITheme.cropped_tex(HUMOUR_GLYPH.get(humour, "")))
		pips.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		pips.set_offset(SIDE_TOP, -50)
		pips.set_offset(SIDE_BOTTOM, -28)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pips)
	# Remaining uses, ALWAYS shown for a charged skill — including one the
	# environment discounted to free, which is exactly the card whose last
	# charge used to vanish without a word.
	if not is_instinct:
		var uses := Label.new()
		uses.text = "×%d" % charges_left
		# 20 -> 26 -> 32 (owner, twice): how many uses are left is one of the
		# two numbers on the card that change, and at arm's length the small
		# badge read as decoration. It is now the same size as the skill's
		# name, because it matters as much.
		uses.add_theme_font_override("font", UITheme.display_font())
		uses.add_theme_font_size_override("font_size", 32)
		uses.add_theme_color_override("font_color",
			UITheme.INK if charges_left > 0 else Color("8a2f22"))
		uses.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		uses.set_offset(SIDE_LEFT, -54)
		uses.set_offset(SIDE_RIGHT, -6)
		uses.set_offset(SIDE_TOP, 2)
		uses.set_offset(SIDE_BOTTOM, 32)
		uses.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		uses.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(uses)

	var name_label := Label.new()
	name_label.text = String(def["name"])
	name_label.add_theme_font_override("font", UITheme.smallcaps_font())
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", UITheme.INK)
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.set_offset(SIDE_TOP, -28)
	name_label.set_offset(SIDE_BOTTOM, -6)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
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
			"self_stun": parts.append(
				"You cannot act next turn — and nothing can be stolen from your paws")
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


## Chronicle wrap width: the plate's 6px content margins either side, less
## room for the scrollbar. The label's min size is pinned to the MEASURED
## height of that wrap (law 2) — a ScrollContainer scrolls its child's
## minimum size, and an autowrap Label reports none of its own.
const LOG_WRAP := float(UITheme.CONTENT_WIDTH) - 12.0 - 16.0


func _log(line: String) -> void:
	log_lines.append(line)
	while log_lines.size() > LOG_HISTORY:
		log_lines.remove_at(0)
	if log_label == null:
		return
	var text := "\n".join(log_lines)
	log_label.text = text
	var measured := UITheme.measure_text(
		text, UITheme.italic_font(), 22, LOG_WRAP)
	log_label.custom_minimum_size = Vector2(LOG_WRAP, measured.y)
	# Pin to the newest line. The scroll range only updates after the
	# container has re-laid out, so ask for more than exists and let the
	# ScrollContainer clamp.
	if log_scroll != null:
		log_scroll.scroll_vertical = int(measured.y)


func _clear(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
