extends Control
## Battle screen, matched to assets/library/mockups/ui_objective.png:
## banner header + rule card · framed portrait (dominant) beside a name-plate
## holding the thread-of-life · framed intent chip · chronicle strip · icon
## status strip · fanned energy hand · fanned skill cards · amber End Turn
## with a dark Slip Away card. All rules live in CombatState.
##
## ZONE TEMPLATE (owner rule: fixed template, nothing moves again).
## Content is 576x1104 inside the calibrated stitch margins
## (UITheme.PAGE_MARGIN_* = 68/40/76/136). Zone heights are REAL heights
## (content + plate margins); the sum plus separations must equal
## CONTENT_HEIGHT exactly. Verified with tests/calibrate.gd -- zones battle.
const ZONE_SEP := 3        # root VBox separation (6 gaps)
const ZONE_HEADER := 98    # banner 30px | rule card 300 wide, 20px text
const ZONE_OPPONENT := 410 # portrait 396x410 | name(thread)+intent col 162
const ZONE_CHRONICLE := 134 # ~3 log lines at 30px visible; whole fight scrolls
const ZONE_STATUS := 58    # icons 40, labels 28, margin 8 (measured: 58)
const ZONE_HAND := 140     # fanned cards 113x154 tuck up over the gap
const ZONE_SKILLS := 150   # fanned action cards 132x162 tuck up over the gap
const ZONE_ACTIONS := 96   # tap-target floor
# 98+410+134+58+140+150+96 = 1086; + 6*3 = 1104 = CONTENT_HEIGHT
# The status strip MEASURES 58, not the 56 it was declared at, so the
# template overran the page by 2px on every battle screen ever shot (owner
# tour, 2026-08-05). Two came off the opponent zone. Law 12: the numbers are
# the contract -- when reality disagrees, change the template, not the sum.

## Grown 2026-08-08 (owner: "the image of the opponent should be larger, that
## frame should take up most of the area") — the chronicle gave up its extra
## lines (3 visible now, bigger type) and the freed rows went to the portrait.
const PORTRAIT_SIZE := Vector2(396, 410)
const RULE_CARD_WIDTH := 300.0
## The chronicle keeps the whole fight and scrolls (owner 2026-08-04). The
## cap is a runaway guard, not an editorial choice.
const LOG_HISTORY := 200
## "The text showing what just happened should be way larger (maybe only 3
## lines visible at a time)" — owner 2026-08-08.
const LOG_FONT_SIZE := 30
const CARD_SCALE := 1.2    # energy cards (owner +20%)
## The energy card, sized FROM the name it has to carry (2026-08-30). It was
## 94x128, drawing at 113x154, whose printed face (UITheme.CARD_NAME_BAND) is
## 82px — and "Moonlight" is 94 at the type floor, so the longest of the four
## humour names ran off the card and the neighbour overlapping it took another
## letter off. 117 draws at 140, giving a 102px face.
##
## CARD_STEP moved with it. At the old 98 a 140-wide card would have been
## covered 42px deep by its neighbour, which is straight through the end of
## the name; 110 leaves the fan overlapping by 30 and still fits five across
## (4 x 110 + 140 = 580, against CONTENT_WIDTH 582).
##
## The height is short of the art's own proportions on purpose, the same trade
## the crossing board took: a true 140-wide card is 197 tall and would push
## the fan's tuck through the skill tray below it.
const CARD_BASE := Vector2(117, 133)
## The widest the fan lets two neighbours sit apart: the card less a hair, so
## a hand small enough to spread covers nothing at all.
const CARD_STEP := 125.0
## What the fan has to fit inside. CONTENT_WIDTH less a little, so the outer
## cards of a full hand do not sit on the page's stitching.
const FAN_WIDTH := 570.0
## Where a hand card's bottom edge sits inside ZONE_HAND. Measured from the
## layout the tuck was tuned against (a 154-tall card resting at -10); the
## fan is positioned from it so the tuck stays put whatever the card's height
## becomes.
const HAND_CARD_BOTTOM := 144.0
## Five abilities out at once, ALL visible, NO sideways scroll (owner
## 2026-08-08: "not where you need to scroll left and right, maybe have it as
## a fanned hand where clicking a specific card opens it up"). The cards fan
## with a slight overlap like the energy hand; the closed card carries the
## art whole (KEEP_ASPECT, never cropped) and the full text lives in the
## popup the tap opens.
const SKILL_CARD_SIZE := Vector2(132, 162)
## The card's ink border, and the widest a name may be drawn inside one.
## Shared shape with the loadout tray (UITheme.skill_name_label).
const CARD_BORDER := 3.0
const NAME_BAND_WIDTH := SKILL_CARD_SIZE.x - CARD_BORDER * 2.0

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

# The humour colour/glyph/frame vocabulary lives in UITheme.HUMOUR_* — one
# copy for every screen (three "shared verbatim" copies had drifted apart).
## Approach copy lives in story/interface.json (law 20) -- what an approach
## COSTS is a rule in CombatState; what it reads like is writing.
static func approach_desc(mode: String) -> String:
	return Strings.line("battle.approach." + mode)


## An approach's NAME is writing (story/interface.json); its PRICE is a rule
## (data/rules.json, reached through the live state). Neither belongs here.
static func approach_name(mode: String) -> String:
	return Strings.line("battle.approach_name." + mode)


## Max 3 options ever shown (owner readability rule): 2 approaches + Walk In.
## The title names the PRICE in words — "Stalk — Shadow 2" read as a stat, not
## as a bill (owner defect list). Costs are the environment-adjusted ones, so
## the fog discount on Needle Lane is visible before you commit, not after.
func _approach_title(mode: String) -> String:
	var cost: Dictionary = state.approaches[mode]["cost"]
	var parts: Array[String] = []
	for humour in cost:
		parts.append("%d %s" % [int(cost[humour]), Catalog.humour_name(String(humour))])
	return "%s — Spend %s Energy" % [approach_name(mode), ", ".join(parts)]

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
var card_panel: Control
var card_title: Label
var card_body: Label
var card_slot: Control
var selected_card := -1
var alarm_label: Label
var log_label: Label
var log_scroll: ScrollContainer
var hp_label: Label
var block_label: Label
var deck_label: Label
var turn_label: Label
var hand_fan: Control
## The fanned cards live in their own layer so a refresh only ever frees what
## a refresh rebuilds (engineering law: rebuildable content gets its own child
## layer — one shared clear once produced six defects from one line).
var hand_cards: Control
## Status-strip chips the coach spotlights by name ("hp", "guard", "deck").
var status_chips: Dictionary = {}
var skill_fan: Control
## Hit-feedback overlay (full page red wash) — built once, animated on "hurt".
var hit_flash: ColorRect
## Damage floats and flying card ghosts live HERE, a layer created BEFORE the
## modal overlays: tree order then keeps them above the board and UNDER every
## dialog. They used z_index 60, which put "-3" drifting across the outcome
## card (screenshot review 2026-08-31).
var floater_layer: Control
## Hand snapshot from the previous refresh: the diff drives the draw/steal
## animations without the rules layer having to know the UI exists.
var _prev_hand: Array = []
var _pending_steals := 0
## Animations only fire after the first laid-out frame — before that, chip
## positions are (0,0) and a "draw" tween would fly in from the page corner.
var _booted := false
## Damage at or above which a hit sounds like a BLOW instead of a hit. Read
## from rules.json presentation.heavy_hit so it moves when enemy damage does.
var _heavy_hit := 4
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
var spool_overlay: Control
var spool_panel: Control
var spool_box: VBoxContainer
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
	_heavy_hit = catalog.rules.count("presentation.heavy_hit")
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
	# Whether losing here spends a LIFE is a property of the encounter too
	# (docs/design/death-and-lives.md): only a `mortal` beat can kill Ash.
	full_config["mortal"] = encounter_def.get("mortal", false)
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
	await get_tree().process_frame
	_booted = true


func _start_coach() -> void:
	_coach_pending = false
	coach = Coach.new(coach_steps, _coach_target)
	coach.text_resolver = _coach_text
	add_child(coach)


## Lets a lesson say the true thing about the state the player is actually
## in. A step may carry `text_by_approach`, keyed by the approach taken
## ("stalk", "ambush", "case", "ward", or "walk_in" for none), with `text` as
## the fallback. Written once for all states, the wisp lesson told a player
## who had walked in that "two Shadow went on the entrance" — they had spent
## nothing, and the tutorial was simply wrong at them (owner 2026-08-05).
func _coach_text(step: Dictionary) -> String:
	var variants: Dictionary = step.get("text_by_approach", {})
	if variants.is_empty():
		return ""
	var taken := state.approach if state.approach != "" else "walk_in"
	return String(variants.get(taken, step.get("text", "")))


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
		_log(Strings.line("chronicle.walked_in"))
	else:
		var result := _command({"type":"approach", "mode": mode})
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
	_open_modal(detail_overlay, detail_panel)


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
		title_text, UITheme.display_font(), 38, title_wrap).y)
	# Energy requirement as pips: one circle per point of cost, colored by
	# humour, filled as the card is powered.
	_clear(detail_pips)
	var runtime := state.skill_state(skill_id)
	for humour in cost:
		var powered := int(runtime.get("powered", {}).get(humour, 0))
		detail_pips.add_child(CostPips.new(int(cost[humour]),
			powered, UITheme.HUMOUR_COLORS.get(humour, UITheme.INK_SOFT), 15.0,
			UITheme.cropped_tex(UITheme.HUMOUR_GLYPH.get(humour, ""))))
	detail_pips.visible = not cost.is_empty()
	# Rule text at DOUBLE its old size (owner 2026-08-08) — the art moved up
	# beside the pips so the words get the panel's full width to be big in.
	var wrap := 620.0 - 32.0
	var effect_text := _effect_summary(def)
	detail_label.text = effect_text
	detail_label.custom_minimum_size = Vector2(wrap, UITheme.measure_text(
		effect_text, UITheme.body_font(), 40, wrap).y + 4)
	var flavor_text := String(def.get("flavor", ""))
	detail_flavor.text = flavor_text
	detail_flavor.visible = flavor_text != ""
	detail_flavor.custom_minimum_size = Vector2(wrap, UITheme.measure_text(
		flavor_text, UITheme.italic_font(), 30, wrap).y + 4)
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


## The best hand card to feed: smallest matching value wastes the least on
## overshoot. Exact humour beats a mysticism wild — wilds are too precious to
## spend when a match exists.
func _charge_pick(humour: String) -> Dictionary:
	var best := {}
	var best_wild := {}
	for i in state.hand.size():
		var card: Dictionary = catalog.energy_cards[state.hand[i]]
		var pick := {"source": "hand", "index": i, "value": int(card["value"])}
		if card["humour"] == humour and \
				(best.is_empty() or int(card["value"]) < int(best["value"])):
			best = pick
		elif card["humour"] == state.wild_humour and \
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
	var result := _command({"type":"charge_skill", "skill_id": skill_id,
		"source": pick["source"], "index": pick["index"]})
	if result["ok"]:
		# A plucked string for spending off the spool — the thread being drawn
		# tight. The rejected case already sounded in _command().
		SfxService.cue("charge")
		_log(Strings.line("chronicle.fed", [Catalog.humour_name(String(next_humour)),
			catalog.skills[skill_id]["name"]]))
	else:
		_log(result["error"])
	_drain_events()
	_refresh()
	_refresh_detail()


func _on_detail_use() -> void:
	if selected_skill == "":
		return  # a tap that raced the closing animation
	if coach != null:
		coach.notify("use")
	var skill_id := selected_skill
	_close_detail()
	var result := _command({"type":"play_skill", "skill_id": skill_id})
	if result["ok"]:
		# Cloth: the swish of a cat committing to something. The hit it causes
		# has its own sound a moment later, off the resolved event — this is
		# the ACT, not the landing.
		SfxService.cue("play_skill")
	else:
		_log(result["error"])  # the journal records what succeeded
	_after_command()


func _close_detail() -> void:
	selected_skill = ""
	_close_modal(detail_overlay, detail_panel)


func _on_card_pressed(hand_index: int) -> void:
	if coach != null:
		coach.notify("hand")
	selected_card = hand_index
	var card_id: String = state.hand[hand_index]
	var card: Dictionary = catalog.energy_cards[card_id]
	var humour := Catalog.humour_name(String(card["humour"]))
	card_title.text = Strings.line("battle.card_title", [humour, int(card["value"])])
	_clear(card_slot)
	var big := _card_button(card_id, 1.8)
	big.disabled = true
	card_slot.add_child(big)
	var body_text := Strings.line("battle.card_desc")
	card_body.text = body_text
	var wrap := 560.0 - 32.0
	card_body.custom_minimum_size = Vector2(wrap, UITheme.measure_text(
		body_text, UITheme.body_font(), 26, wrap).y)
	_open_modal(card_overlay, card_panel)


func _close_card() -> void:
	selected_card = -1
	_close_modal(card_overlay, card_panel)


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
		b.add_theme_color_override("font_color", UITheme.HUMOUR_COLORS.get(humour, UITheme.INK))
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
	var result := _command({"type":"concentrate", "humour": humour})
	if result["ok"]:
		SfxService.cue("concentrate")
		_log(Strings.line("chronicle.concentrate", [Catalog.humour_name(String(humour))]))
	else:
		_log(result["error"])
	_after_command()


func _on_end_turn() -> void:
	if coach != null:
		coach.notify("end_turn")
	_close_detail()
	_log(Strings.line("chronicle.turn", [state.turn]))
	SfxService.cue("end_turn")
	_command({"type":"end_turn"})
	_after_command()


func _on_slip_away() -> void:
	if coach != null:
		coach.notify("slip")
	_close_detail()
	var result := _command({"type":"slip_away"})
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


## Every player action in this scene goes through here, so a REFUSED one
## always says so out loud.
##
## Law 19's chief invariant is that a rejected command changes nothing — and
## for a long time that included changing nothing AUDIBLE, which made a
## refused tap indistinguishable from a tap the game never received. The
## player re-taps, and a fumbled tap that costs nothing starts to feel like a
## game that is ignoring them. The refusal is still silent in the JOURNAL
## sense — `result["error"]` is logged by the caller, which knows what it was
## trying to do — this only guarantees the noise.
func _command(command: Dictionary) -> Dictionary:
	var result := state.do_command(command)
	if not result["ok"]:
		SfxService.cue("ui_reject")
	return result


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
		Strings.line("battle.withdraw_default")))
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
		# Structured feedback events ("hurt:3") drive the hit animations; the
		# bare words below stay the chronicle's flavour lines.
		if event.begins_with("hurt:"):
			_anim_player_hurt(int(event.get_slice(":", 1)))
			continue
		if event.begins_with("blocked:"):
			_anim_player_blocked(int(event.get_slice(":", 1)))
			continue
		if event.begins_with("enemy_hurt:"):
			_anim_enemy_hurt(int(event.get_slice(":", 1)))
			continue
		if event == "stolen":
			_pending_steals += 1
			continue
		match event:
			"sunbeam": _log(Strings.line("chronicle.sunbeam"))
			"spotted": _log(Strings.line("chronicle.spotted"))
			"warmed": _log(Strings.line("chronicle.warmed"))
			"sharpened": _log(Strings.line("chronicle.sharpened"))
			"sharpened_strike": _log(Strings.line("chronicle.sharpened_strike"))
			"hidden_wasted": _log(Strings.line("chronicle.hidden_wasted"))
			"approach_stalk": _log(Strings.line("chronicle.approach_stalk"))
			"approach_ambush": _log(Strings.line("chronicle.approach_ambush"))
			"approach_case": _log(Strings.line("chronicle.approach_case"))
			"approach_ward": _log(Strings.line("chronicle.approach_ward"))
			"parting_shot": _log(Strings.line("chronicle.parting_shot"))
			"loaf_guarded": _log(Strings.line("chronicle.loaf_guarded"))
			"night_presses": _log(Strings.line("chronicle.night_presses"))
			"undone": _log(Strings.line("chronicle.undone"))
			"concentrated": pass  # the chooser handler already narrates it


func _maybe_offer_approach() -> void:
	if no_approach or not state.can_approach():
		return
	# The chooser opens even when nothing is affordable (owner 2026-08-10): an
	# entrance you cannot pay for is shown INACTIVE, so the price is a fact you
	# learn rather than an option that silently vanished.
	if not _offered_approaches().is_empty():
		approach_overlay.visible = true


## Which entrances this fight allows. An encounter may name `approaches`, and
## the rag-wraith does (owner 2026-08-05): the story has it coming STRAIGHT
## AT Ash down the middle of the lane, so "Ambush" and "Case It" describe a
## fight nobody is having. You can still try to melt into the fog, or you can
## walk in. What the fiction says has happened limits what the UI may offer.
func _offered_approaches() -> Array:
	var allowed: Array = encounter_def.get("approaches", [])
	if allowed.is_empty():
		return state.approaches.keys()
	var out: Array = []
	for mode in state.approaches:
		if allowed.has(mode):
			out.append(mode)
	return out


func _show_outcome() -> void:
	match state.outcome:
		CombatState.Outcome.VICTORY:
			overlay_label.text = "%s: dealt with." % catalog.enemies[state.enemy_id]["name"]
			overlay_button.text = "Continue"
			SfxService.cue("sting_victory")
		CombatState.Outcome.DEFEAT:
			overlay_label.text = "The dark comes up like a floor."
			overlay_button.text = "Get up"
			SfxService.cue("sting_defeat")
		CombatState.Outcome.RETREATED:
			overlay_label.text = "You were never here."
			overlay_button.text = "Slip Away"
			# Deliberately NOT the defeat sting. Slipping away is a thing the
			# game teaches on purpose (encounters carry `withdraw_after`), and
			# scoring it as a loss would argue with the lesson.
			SfxService.cue("ash_trill")
	# Autowrap labels reserve no height in a VBox: measure at the label's
	# true wrap width (panel 480 minus 16px margins each side) so the plate
	# always encases title and button.
	var outcome_wrap := 480.0 - 32.0
	overlay_label.custom_minimum_size = Vector2(outcome_wrap, UITheme.measure_text(
		overlay_label.text, UITheme.display_font(), 34, outcome_wrap).y)
	overlay.visible = true


## Guards the outcome overlay's continue against a double-tap: the flow
## digests this signal (rewards, chronicle, save), so it must fire once.
var _outcome_reported := false


func _on_overlay_continue() -> void:
	if _outcome_reported:
		return
	_outcome_reported = true
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
	var loc := UITheme.fitted_label(environment_def["name"], [30, 27, 24, 22],
		banner_box, UITheme.display_font())
	loc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(loc)
	var rule_card := PanelContainer.new()
	rule_card.custom_minimum_size = Vector2(RULE_CARD_WIDTH, 0)
	header.add_child(rule_card)
	rule_plate = rule_card
	# Sized from a ladder (owner 2026-08-09: "make the text in the top right
	# corner a bit bigger"): a short rule renders at 24, a long one steps
	# down until it fits the header's fixed box instead of growing the zone.
	var rule_label := UITheme.fitted_label(environment_def.get("rule_text", ""),
		[24, 22, 20, 18], Vector2(RULE_CARD_WIDTH - 32.0, ZONE_HEADER - 32.0))
	rule_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rule_card.add_child(rule_label)

	# --- Zone B: opponent -------------------------------------------------
	# (Hints render as chronicle lines — a floating label broke the budget.)
	# The portrait is 396 wide of the 582 (owner 2026-08-08: "the image of the
	# opponent should be larger") — the name/intent column keeps a slim 174.
	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 12)
	enemy_row.custom_minimum_size = Vector2(0, ZONE_OPPONENT)
	root.add_child(enemy_row)
	enemy_art = _framed_portrait(catalog.enemies[state.enemy_id].get("image", ""),
		String(catalog.enemies[state.enemy_id]["name"]))
	enemy_row.add_child(enemy_art)
	var enemy_col := VBoxContainer.new()
	enemy_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_col.add_theme_constant_override("separation", 12)
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
	enemy_label.add_theme_font_size_override("font_size", 26)
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
	intent_label.add_theme_font_size_override("font_size", 24)
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
	log_label.add_theme_font_size_override("font_size", LOG_FONT_SIZE)
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
	# The spool chip answers taps (owner 2026-08-10: "I should be able to
	# click on the spool to see how many of each energy I still have left").
	# It sits in a PanelContainer so the tap layer stretches over the whole
	# chip — a box container would lay the button out as another sibling.
	var spool_wrap := PanelContainer.new()
	spool_wrap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	status_row.add_child(spool_wrap)
	deck_label = _status_chip(spool_wrap, "ui/ui_spool", "deck")
	UITheme.tap_layer(spool_wrap).pressed.connect(_open_spool_popup)
	_divider(status_row)
	# Paw action points: one paw icon + how many placements remain.
	# No tooltips anywhere in the battle (owner 2026-08-09: this is a mobile
	# game, only clicks are registered) — what a thing does is taught by the
	# coach and said by its own close-up.
	paws_row = HBoxContainer.new()
	paws_row.add_theme_constant_override("separation", 6)
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

	# --- Zone E: fanned energy hand ---------------------------------------
	hand_fan = Control.new()
	hand_fan.custom_minimum_size = Vector2(0, ZONE_HAND)
	root.add_child(hand_fan)
	# Cards get their OWN layer (engineering law: rebuildable content gets its
	# own child layer — a shared clear once produced six defects from one line).
	hand_cards = Control.new()
	hand_cards.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_fan.add_child(hand_cards)

	# --- Zone F: fanned action cards --------------------------------------
	# All five out at once, slightly overlapped like the energy hand, no
	# sideways scroll (owner 2026-08-08). Tapping a card opens the close-up,
	# which is where the full text lives.
	skill_fan = Control.new()
	skill_fan.custom_minimum_size = Vector2(0, ZONE_SKILLS)
	root.add_child(skill_fan)

	# Floaters' layer FIRST, before any modal is built: later siblings draw on
	# top, so everything parented here stays under every dialog with no z_index
	# arithmetic at all.
	floater_layer = Control.new()
	floater_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	floater_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floater_layer)

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
	detail_title.add_theme_font_size_override("font_size", 38)
	detail_title.add_theme_color_override("font_color", UITheme.INK)
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(detail_title)
	detail_uses = Label.new()
	detail_uses.add_theme_font_override("font", UITheme.smallcaps_font())
	detail_uses.add_theme_font_size_override("font_size", 30)
	detail_uses.add_theme_color_override("font_color", UITheme.INK_SOFT)
	detail_uses.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_box.add_child(detail_uses)
	# Art centered beside the pips; the rule text below gets the panel's full
	# width, which is what lets it run at double size (owner 2026-08-08).
	var detail_body := HBoxContainer.new()
	detail_body.add_theme_constant_override("separation", 16)
	detail_body.alignment = BoxContainer.ALIGNMENT_CENTER
	detail_box.add_child(detail_body)
	var art_holder := PanelContainer.new()
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color("f4e7cd")
	art_style.set_border_width_all(3)
	art_style.border_color = UITheme.INK
	art_style.set_corner_radius_all(12)
	art_style.set_content_margin_all(6)
	art_holder.add_theme_stylebox_override("panel", art_style)
	art_holder.custom_minimum_size = Vector2(220, 220)
	art_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail_body.add_child(art_holder)
	detail_art = TextureRect.new()
	detail_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_holder.add_child(detail_art)
	detail_pips = HBoxContainer.new()
	detail_pips.add_theme_constant_override("separation", 10)
	detail_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	detail_body.add_child(detail_pips)
	detail_label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 40)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(detail_label)
	# Flavor is ITALIC and softer — clearly voice, not rules (owner rule).
	detail_flavor = Label.new()
	detail_flavor.add_theme_font_override("font", UITheme.italic_font())
	detail_flavor.add_theme_font_size_override("font_size", 30)
	detail_flavor.add_theme_color_override("font_color", UITheme.INK_SOFT)
	detail_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(detail_flavor)
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
	concentrate_button.custom_minimum_size = Vector2(148, ZONE_ACTIONS)
	concentrate_button.add_theme_font_override("font", UITheme.smallcaps_font())
	concentrate_button.add_theme_font_size_override("font_size", 22)
	concentrate_button.pressed.connect(_on_concentrate_pressed)
	action_row.add_child(concentrate_button)
	slip_button = UITheme.dark_button("Slip Away", 24, Vector2(148, ZONE_ACTIONS))
	slip_button.add_theme_font_override("font", UITheme.smallcaps_font())
	slip_button.pressed.connect(_on_slip_away)
	action_row.add_child(slip_button)
	# The button STAYS in a no_retreat fight (owner 2026-08-04): reaching for
	# the door and finding the room has no outside is the beat. Tapping it
	# explains, then hands the player back to the fight.

	approach_overlay = _build_approach_overlay()
	_build_spool_popup()
	overlay = _build_outcome_overlay()
	card_overlay = _build_card_overlay()
	concentrate_overlay = _build_concentrate_overlay()
	no_escape_overlay = _build_no_escape_overlay()
	withdraw_overlay = _build_withdraw_overlay()

	# Red wash for "you have been attacked" — invisible until a hurt event.
	hit_flash = ColorRect.new()
	hit_flash.color = Color(0.55, 0.08, 0.05, 0.0)
	hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hit_flash)


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
	var note := Label.new()
	note.text = Strings.line("battle.approach.spool_note")
	note.add_theme_font_size_override("font_size", 24)
	note.add_theme_color_override("font_color", UITheme.INK_SOFT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	# Max 3 options ever shown (owner readability rule): 2 approaches + Walk
	# In. Affordable entrances take the slots first; an unaffordable one may
	# still fill a slot, DISABLED, with the shortfall said plainly (owner
	# 2026-08-10) — and only entrances the fiction allows are considered.
	var offered: Array = _offered_approaches()
	var shown: Array[String] = []
	for mode in offered:
		if shown.size() < 2 and state.can_pay_approach(mode):
			shown.append(mode)
	for mode in offered:
		if shown.size() < 2 and not shown.has(mode):
			shown.append(mode)
	for mode in shown:
		var affordable := state.can_pay_approach(mode)
		var desc := approach_desc(mode) if affordable \
			else "%s %s" % [approach_desc(mode), Strings.line("battle.approach.spool_short")]
		var button := _approach_button(_approach_title(mode), desc, mode)
		button.disabled = not affordable
		box.add_child(button)
	box.add_child(_approach_button(Strings.line("battle.approach.walk_in_title"),
		Strings.line("battle.approach.walk_in_desc"), ""))
	return modal["overlay"]


## The spool close-up (owner 2026-08-10): what is still wound on, by humour
## and BY WORTH — a spool holding three 1s reads differently from one holding
## a single 3, and mid-fight that difference is the plan.
func _build_spool_popup() -> void:
	var modal := UITheme.modal(self, 560.0)
	spool_overlay = modal["overlay"]
	spool_panel = modal["panel"]
	spool_box = modal["box"]
	# Law 13: dim-tap closes; the modal never traps.
	UITheme.modal_escape(modal, func() -> void:
		UITheme.close_modal(spool_overlay, spool_panel))


func _open_spool_popup() -> void:
	for child in spool_box.get_children():
		spool_box.remove_child(child)
		child.queue_free()
	var wrap := 528.0
	var title := UITheme.measured_label(Strings.line("battle.spool.title"), 36,
		wrap, UITheme.display_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spool_box.add_child(title)
	spool_box.add_child(UITheme.measured_label(Strings.line("battle.spool.blurb"),
		24, wrap, UITheme.italic_font(), UITheme.INK_SOFT))
	var counts := {}
	for card_id in state.deck:
		var card: Dictionary = catalog.energy_cards[card_id]
		var humour := String(card["humour"])
		var by_value: Dictionary = counts.get(humour, {})
		by_value[int(card["value"])] = int(by_value.get(int(card["value"]), 0)) + 1
		counts[humour] = by_value
	# All four humours always: knowing a colour has RUN OUT is the reading
	# that changes the plan.
	for humour in Catalog.HUMOURS:
		spool_box.add_child(_spool_row(String(humour), counts.get(humour, {})))
	var total := UITheme.measured_label(
		Strings.line("battle.spool.total", [state.deck.size()]), 26, wrap,
		UITheme.body_font(), UITheme.INK_SOFT)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spool_box.add_child(total)
	_open_modal(spool_overlay, spool_panel)


func _spool_row(humour: String, by_value: Dictionary) -> Control:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UITheme.panel_stylebox(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	var glyph := UITheme.icon(String(UITheme.HUMOUR_GLYPH.get(humour, "")), 44.0)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var name_label := UITheme.measured_label(Catalog.humour_name(humour), 30,
		200.0, UITheme.display_font(), UITheme.HUMOUR_COLORS.get(humour, UITheme.INK))
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_FILL
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var parts: Array[String] = []
	var values: Array = by_value.keys()
	values.sort()
	for value in values:
		parts.append(Strings.line("battle.spool.count",
			[int(by_value[value]), int(value)]))
	var counts_text := " · ".join(parts) if not parts.is_empty() \
		else Strings.line("battle.spool.none")
	var counts_label := UITheme.measured_label(counts_text, 28, 240.0,
		UITheme.body_font(),
		UITheme.INK if not parts.is_empty() else UITheme.INK_FADED)
	counts_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	counts_label.size_flags_vertical = Control.SIZE_FILL
	counts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(counts_label)
	return plate


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


## Close-up for a tapped hand card: a look, nothing more. Feeding energy to a
## skill happens from the skill's own close-up; banking and discarding are
## both gone (owner 2026-08-08/09 — neither ever benefited the player).
func _build_card_overlay() -> Control:
	var modal := UITheme.modal(self, 560.0)
	card_panel = modal["panel"]
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
	var back := UITheme.amber_button("Back to the fight", 30)
	back.pressed.connect(_close_card)
	box.add_child(back)
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
		Strings.line("battle.concentrate_desc"),
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
	var frame := UITheme.tex("ui/ui_frame_portrait_thin")
	if frame != null:
		# The frame texture floats in transparent padding (a whole empty band
		# below the drawn wood), so stretched raw it ended two finger-widths
		# above the image's bottom edge (owner 2026-08-09: "the image of the
		# opponent is a little bigger than the frame it is in"). Law 22: the
		# frame is drawn CROPPED to its opaque bounds so the visible wood
		# fills the holder exactly, and the art window comes from the
		# MEASURED aperture inside it, tucked a few px under the border.
		var opaque := UITheme.content_region(frame, "ui/ui_frame_portrait_thin")
		var aperture := UITheme.frame_aperture("ui/ui_frame_portrait_thin")
		var sx := PORTRAIT_SIZE.x / opaque.size.x
		var sy := PORTRAIT_SIZE.y / opaque.size.y
		var tuck := 6.0
		art.set_offset(SIDE_LEFT, (aperture.position.x - opaque.position.x) * sx - tuck)
		art.set_offset(SIDE_TOP, (aperture.position.y - opaque.position.y) * sy - tuck)
		art.set_offset(SIDE_RIGHT, -(opaque.end.x - aperture.end.x) * sx + tuck)
		art.set_offset(SIDE_BOTTOM, -(opaque.end.y - aperture.end.y) * sy + tuck)
	else:
		# No frame texture (bare dev checkout): the old measured insets.
		art.set_offset(SIDE_LEFT, 38 * PORTRAIT_SIZE.x / 300.0)
		art.set_offset(SIDE_TOP, 36 * PORTRAIT_SIZE.y / 366.0)
		art.set_offset(SIDE_RIGHT, -38 * PORTRAIT_SIZE.x / 300.0)
		art.set_offset(SIDE_BOTTOM, -52 * PORTRAIT_SIZE.y / 366.0)
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
	# "(+N)" is its raised guard — kept terse so the label never outgrows the
	# slim column; the intent chip and chronicle carry the words.
	enemy_hp_label.text = "%d/%d (+%d)" % [maxi(state.enemy_hp, 0),
		state.enemy_max_hp, state.enemy_block] if state.enemy_block > 0 \
		else "%d / %d" % [maxi(state.enemy_hp, 0), state.enemy_max_hp]
	thread_bar.set_health(maxi(state.enemy_hp, 0), state.enemy_max_hp)
	var intent := state.current_intent()
	# A masked intent stays masked in EVERY branch — leaking the name through
	# the stalk or spotted lines would undo the whole mechanic.
	if intent.is_empty():
		# Broken content (core already push_errored); the chip must not crash.
		intent_label.text = ""
	elif state.intent_masked(intent):
		intent_label.text = Strings.line("battle.intent_masked")
	elif state.hidden:
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
		_log(Strings.line("chronicle.hint", [String(hints[hint_key])]))
	# Concentrate is limited and it SAYS so (owner 2026-08-05: it gave the
	# energy back "any number of times" and read as free). The count is on the
	# button, and it greys out when the last one is gone.
	concentrate_button.text = Strings.line("battle.concentrate_label",
		[state.concentrate_left])
	concentrate_button.disabled = state.concentrate_left <= 0 \
		or not state.channel.is_empty() or state.statuses.get("loafed", 0) > 0
	hp_label.text = "%d/%d" % [maxi(state.player_hp, 0), state.player_max_hp]
	block_label.text = str(state.player_block)
	deck_label.text = str(state.deck.size())
	paws_label.text = str(state.paws_left)
	turn_label.text = "turn %d" % state.turn
	log_label.text = "\n".join(log_lines)

	_refresh_hand_fan()
	_refresh_skill_fan()


## The hand as a fan (objective mock): overlapped, slightly rotated cards.
## Newly drawn cards slide in from the deck chip; stolen cards fly to the
## opponent as fading ghosts (owner 2026-08-08: draws and thefts animate).
func _refresh_hand_fan() -> void:
	var stolen := _removed_cards(_prev_hand, state.hand) if _pending_steals > 0 else []
	var drawn_from := _prev_hand.size()
	var is_plain_draw: bool = state.hand.size() > _prev_hand.size() \
		and state.hand.slice(0, _prev_hand.size()) == _prev_hand
	_clear(hand_cards)
	var n := state.hand.size()
	var card_size := CARD_BASE * CARD_SCALE
	# The fan spreads as wide as the hand allows and only overlaps when it has
	# to. A fixed step overlapped a two-card hand exactly as hard as a
	# five-card one, which took the end off a name for no reason -- the width
	# was there and unused. CARD_STEP is the cap: past it the cards stop
	# separating, because a hand strung right across the page stops reading as
	# a hand. It is the card's width less a hair, so at the cap nothing is
	# covered at all.
	var overlap_step := CARD_STEP
	if n > 1:
		overlap_step = clampf((FAN_WIDTH - card_size.x) / float(n - 1),
			0.0, CARD_STEP)
	var total_width := overlap_step * (n - 1) + card_size.x
	var start_x: float = (hand_fan.size.x - total_width) / 2.0
	if hand_fan.size.x <= 1:  # first layout pass: estimate from zone width
		start_x = (float(UITheme.CONTENT_WIDTH) - total_width) / 2.0
	var center := (n - 1) / 2.0
	for i in n:
		var b := _card_button(state.hand[i], CARD_SCALE)
		b.pressed.connect(_on_card_pressed.bind(i))
		hand_cards.add_child(b)
		var offset := i - center
		# Tucked up slightly: the cards may overhang the zone gap above,
		# never the tray below.
		# Pinned by its BOTTOM, not its top. The fan tucks card bottoms under
		# the skill tray, so a card that grows downward grows straight into
		# it: sizing the card from its name on 2026-08-30 made it 6px taller
		# and buried the very name it had been widened for. HAND_CARD_BOTTOM
		# is where the bottom edge has always sat; the card may overhang the
		# gap ABOVE, which is empty.
		var rest := Vector2(start_x + overlap_step * i,
			HAND_CARD_BOTTOM - card_size.y + 3.0 * absf(offset) * absf(offset))
		b.position = rest
		b.rotation_degrees = offset * 3.0
		b.pivot_offset = card_size / 2.0
		if _booted and is_plain_draw and i >= drawn_from:
			_anim_draw(b, rest)
	if _booted:
		for card_id in stolen:
			_anim_steal(String(card_id))
	_pending_steals = 0
	_prev_hand = state.hand.duplicate()


## Multiset difference: which card ids left the hand since the last refresh.
func _removed_cards(before: Array, after: Array) -> Array:
	var remaining := after.duplicate()
	var removed: Array = []
	for card_id in before:
		var at := remaining.find(card_id)
		if at >= 0:
			remaining.remove_at(at)
		else:
			removed.append(card_id)
	return removed


## The five action cards as a fan: all visible, slight overlap, no scroll
## (owner 2026-08-08). Scratch ALWAYS occupies the first slot, then the
## loadout in its own order (owner defect: a battle that pinned its skills
## without naming Scratch pushed it to the far right, so the tray reshuffled
## between fights). The fan is muscle memory — it does not move.
func _refresh_skill_fan() -> void:
	_clear(skill_fan)
	skill_buttons.clear()
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
	var n := shown.size()
	if n == 0:
		return
	var fan_width := skill_fan.size.x
	if fan_width <= 1:  # first layout pass: estimate from zone width
		fan_width = float(UITheme.CONTENT_WIDTH)
	var step: float = SKILL_CARD_SIZE.x + 8.0
	if n > 1:
		step = minf(step, (fan_width - SKILL_CARD_SIZE.x) / float(n - 1))
	var total_width: float = step * (n - 1) + SKILL_CARD_SIZE.x
	var start_x := (fan_width - total_width) / 2.0
	var center := (n - 1) / 2.0
	# What the next card in the fan sits on top of. Zero when the tray has
	# room to lay flat; on a full five-wide tray it is about 20px, and a name
	# measured without it is measured partly in pixels nobody can see.
	var covered := maxf(SKILL_CARD_SIZE.x - step, 0.0)
	for i in n:
		var button := _skill_button(shown[i], covered if i < n - 1 else 0.0)
		skill_buttons[shown[i]] = button
		skill_fan.add_child(button)
		var offset := i - center
		# Tucked up over the gap above, never past the buttons below.
		button.position = Vector2(start_x + step * i,
			-14.0 + 2.5 * absf(offset) * absf(offset))
		button.rotation_degrees = offset * 2.5
		button.pivot_offset = SKILL_CARD_SIZE / 2.0


func _card_button(card_id: String, scale := 1.0) -> Button:
	var card: Dictionary = catalog.energy_cards[card_id]
	var humour: String = card["humour"]
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = CARD_BASE * scale
	b.size = b.custom_minimum_size
	var frame := TextureRect.new()
	frame.texture = UITheme.tex(UITheme.HUMOUR_CARD_FRAME.get(humour, ""))
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(frame)
	var glyph := TextureRect.new()
	glyph.texture = UITheme.tex(UITheme.HUMOUR_GLYPH.get(humour, ""))
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	# FRACTIONS of the card, not pixels: the card grew on 2026-08-30 and fixed
	# insets tuned for a 94x128 one would have left the glyph in a corner of
	# it. Same numbers the crossing board's chip uses, so a card is still the
	# same card on both screens.
	glyph.set_offset(SIDE_LEFT, CARD_BASE.x * scale * 0.16)
	glyph.set_offset(SIDE_RIGHT, -CARD_BASE.x * scale * 0.16)
	glyph.set_offset(SIDE_TOP, CARD_BASE.y * scale * 0.17)
	glyph.set_offset(SIDE_BOTTOM, -CARD_BASE.y * scale * 0.34)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(glyph)
	var value := Label.new()
	value.text = str(int(card["value"]))
	value.add_theme_font_override("font", UITheme.display_font())
	value.add_theme_font_size_override("font_size", int(30 * scale))
	value.add_theme_color_override("font_color", UITheme.INK)
	value.position = Vector2(CARD_BASE.x * 0.13, CARD_BASE.y * 0.06) * scale
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(value)
	var name_label := Label.new()
	name_label.text = Catalog.humour_name(String(humour))
	# Fitted to the card's printed FACE, not hung across its whole width.
	# 2026-08-30: the name was set at a flat 22*scale and anchored edge to
	# edge, so "Ferocity" and "Shadow" ran onto the border ink and "Moonlight"
	# ran off it. The face is UITheme.CARD_NAME_BAND of the card, and the size
	# now steps down to whatever fits inside that — never below TYPE_FLOOR.
	#
	# KNOWN, and it needs the owner: at this card width (94*scale) the face is
	# ~82px and "Moonlight" is 94 at the floor, so the longest of the four
	# still touches the border. Closing that means a 140-wide card, which
	# means re-budgeting ZONE_HAND and the fan's overlap — a layout pass of
	# its own, not a line here. The crossing board took that pass on
	# 2026-08-30; this one has not.
	var face: float = CARD_BASE.x * scale * UITheme.CARD_NAME_BAND
	name_label.add_theme_font_size_override("font_size",
		UITheme.fit_font_size(name_label.text, UITheme.body_font(),
			[int(22 * scale), 24, UITheme.TYPE_FLOOR],
			Vector2(face, 40.0 * scale)))
	name_label.add_theme_color_override("font_color", UITheme.INK)
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	var inset: float = CARD_BASE.x * scale * (1.0 - UITheme.CARD_NAME_BAND) * 0.5
	name_label.set_offset(SIDE_LEFT, inset)
	name_label.set_offset(SIDE_RIGHT, -inset)
	# Raised band: the hand fan tucks card bottoms under the skill tray
	# (ZONE_HAND < card height), and the old -34..-14 band left the name
	# half-swallowed by the tuck + frame border (owner defect list).
	# RAISED band, and deliberately NOT the art's printed one. The hand fan
	# tucks card bottoms under the skill tray (ZONE_HAND < card height), so
	# the bottom fifth of a hand card is never visible — the old -34..-14 band
	# left the name half-swallowed, and centring it on the art's ruled band
	# (which is where the crossing board puts it, correctly, because nothing
	# covers a card there) buried it again on 2026-08-30. The tray is the
	# constraint on this screen, not the picture on the card.
	name_label.set_offset(SIDE_TOP, -46 * scale)
	name_label.set_offset(SIDE_BOTTOM, -26 * scale)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_label)
	return b


## `covered_right` is how much of this card the NEXT one in the fan covers;
## the name band shrinks and shifts left by that much so the word is centred
## in what the player can see rather than in the card's geometry.
func _skill_button(skill_id: String, covered_right: float = 0.0) -> Button:
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
	# KEEP_ASPECT, not COVERED: the whole picture shows in the closed state
	# (owner 2026-08-08: "the card pictures ... are a bit cut off"). The card
	# art is a subject on plain parchment, so fitting it leaves parchment
	# margins, not letterbox bars.
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.set_offset(SIDE_LEFT, 6)
	art.set_offset(SIDE_RIGHT, -6)
	art.set_offset(SIDE_TOP, 6)
	# Art must STOP above the pips band — art bleeding behind the hollow
	# circles read as phantom X marks.
	art.set_offset(SIDE_BOTTOM, -58)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)

	var runtime := state.skill_state(skill_id)
	var is_instinct: bool = def.get("instinct", false)
	var humour := ""
	for key in def.get("cost", {}):
		humour = key
		break
	var pip_color: Color = UITheme.HUMOUR_COLORS.get(humour, UITheme.INK_SOFT)

	var jammed: bool = not is_instinct and int(runtime.get("jammed_turns", 0)) > 0
	var charges_left := int(runtime.get("charges_left", 0))
	var out_of_charges: bool = not is_instinct and charges_left <= 0
	var cost := state.effective_cost(def.get("cost", {}))
	# The status band under the art says the ONE thing that is stopping you.
	# Order matters: "free" used to win over "no charges left", so a Slink
	# discounted to free by the fog read as playable while refusing every tap
	# (owner defect: "even though slink is free, I can't play it").
	var band := ""
	var channeling: bool = not state.channel.is_empty() and def.get("effects", []).any(
		func(e): return e.get("type", "") == "channel_heal")
	if channeling:
		band = "purring"
	elif jammed:
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
		pips_label.add_theme_font_size_override("font_size", 24)
		pips_label.add_theme_color_override("font_color", pip_color)
		pips_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		pips_label.set_offset(SIDE_TOP, -58)
		pips_label.set_offset(SIDE_BOTTOM, -32)
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
			UITheme.cropped_tex(UITheme.HUMOUR_GLYPH.get(humour, "")))
		pips.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		pips.set_offset(SIDE_TOP, -58)
		pips.set_offset(SIDE_BOTTOM, -32)
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
		# Top-LEFT, not top-right: the fan overlaps each card's right edge
		# with its neighbour, and a count you cannot see is a count that
		# does not exist (owner rule: this number matters at arm's length).
		uses.set_anchors_preset(Control.PRESET_TOP_LEFT)
		uses.set_offset(SIDE_LEFT, 8)
		uses.set_offset(SIDE_RIGHT, 62)
		uses.set_offset(SIDE_TOP, 2)
		uses.set_offset(SIDE_BOTTOM, 34)
		uses.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		uses.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(uses)

	var name_label := UITheme.skill_name_label(String(def["name"]),
		NAME_BAND_WIDTH - covered_right)
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.set_offset(SIDE_LEFT, CARD_BORDER)
	name_label.set_offset(SIDE_RIGHT, -(CARD_BORDER + covered_right))
	name_label.set_offset(SIDE_TOP, -32)
	name_label.set_offset(SIDE_BOTTOM, -6)
	b.add_child(name_label)

	# Unplayable cards go DIM, never transparent (owner 2026-08-09: "the
	# edges should not be transparent, let them feel like actual cards" —
	# in a fan, a see-through card shows the neighbour through itself).
	b.modulate = Color.WHITE if _skill_playable(skill_id) else Color(0.62, 0.6, 0.57)
	b.pressed.connect(_on_skill_selected.bind(skill_id))
	return b


## Can the player DO anything with this skill right now — use it, or feed
## at least one energy onto it? Drives tray dimming and popup opening.
func _skill_playable(skill_id: String) -> bool:
	var def: Dictionary = catalog.skills[skill_id]
	var runtime := state.skill_state(skill_id)
	if state.statuses.get("loafed", 0) > 0 or not state.channel.is_empty():
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


## One code path with the loadout close-up (ui/skill_text.gd); the templates
## themselves live in story/interface.json under skill_rules (law 20).
func _effect_summary(def: Dictionary) -> String:
	return SkillText.effect_summary(def)


func _intent_text(intent: Dictionary) -> String:
	match intent["target"]:
		"health": return "%d damage" % int(intent["amount"])
		"skills": return "burns away 1 use of an action, for good" \
			if intent.get("mode", "jam") == "burn" else "jams an action for a turn"
		"hand": return "steals a card" if int(intent["amount"]) == 1 \
			else "steals %d cards" % int(intent["amount"])
		"block": return "guards itself +%d" % int(intent["amount"])
		"heal": return "mends itself %d" % int(intent["amount"])
	return "?"


func _start_ambient_animation() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(enemy_art, "modulate",
		Color(1.08, 1.08, 1.08), 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(enemy_art, "modulate",
		Color(0.9, 0.9, 0.9), 0.9).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------------ feedback
# Purely visual: nothing below reads or writes rules state. The scene layer
# reacts to core's informational events ("hurt:3") and to hand diffs.

## Guards against a stale close callback hiding a modal that was re-opened
## while its closing tween was still running.
var _modal_seq: Dictionary = {}


## Card-up: the popup grows out of the tap instead of appearing (owner
## 2026-08-08: "add some visualization element so it looks smooth when you
## bring up an action card and when it removed").
func _open_modal(modal_overlay: Control, panel: Control) -> void:
	_modal_seq[modal_overlay] = int(_modal_seq.get(modal_overlay, 0)) + 1
	modal_overlay.visible = true
	modal_overlay.modulate.a = 0.0
	panel.scale = Vector2(0.72, 0.72)
	await get_tree().process_frame
	if not modal_overlay.visible:
		return  # closed before it finished appearing
	panel.pivot_offset = panel.size / 2.0
	# Durations doubled across every animation here (owner 2026-08-09:
	# "run for just a little bit longer... so they are easier to see").
	var tween := create_tween().set_parallel()
	tween.tween_property(modal_overlay, "modulate:a", 1.0, 0.32)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.48) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_modal(modal_overlay: Control, panel: Control) -> void:
	if not modal_overlay.visible:
		return
	_modal_seq[modal_overlay] = int(_modal_seq.get(modal_overlay, 0)) + 1
	var seq: int = _modal_seq[modal_overlay]
	panel.pivot_offset = panel.size / 2.0
	var tween := create_tween().set_parallel()
	tween.tween_property(modal_overlay, "modulate:a", 0.0, 0.24)
	tween.tween_property(panel, "scale", Vector2(0.8, 0.8), 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		if int(_modal_seq.get(modal_overlay, 0)) != seq:
			return  # re-opened mid-close; leave it alone
		modal_overlay.visible = false
		modal_overlay.modulate.a = 1.0
		panel.scale = Vector2.ONE)


## A number that drifts up and fades — the classic hit read. Damage numbers
## run WAY larger than the word floats (owner 2026-08-09).
func _float_text(text: String, color: Color, at_global: Vector2,
		font_size := 48) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UITheme.display_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floater_layer.add_child(label)
	label.global_position = at_global
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 64.0, 1.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func _control_center(control: Control) -> Vector2:
	return control.global_position + control.size / 2.0


## You have been attacked: red wash, the number lost, over the heart chip.
func _anim_player_hurt(amount: int) -> void:
	if not _booted:
		return
	# A big hit is a different sound, not the same sound louder. The threshold
	# is a rules dial rather than a literal so the fights and the feedback
	# cannot drift apart (law 10).
	SfxService.cue("heavy_blow" if amount >= _heavy_hit else "enemy_hit")
	var tween := create_tween()
	tween.tween_property(hit_flash, "color:a", 0.3, 0.12)
	tween.tween_property(hit_flash, "color:a", 0.0, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var hp_chip: Control = status_chips.get("hp", status_plate)
	_float_text("-%d" % amount, Color("8a2f22"),
		_control_center(hp_chip) - Vector2(28, 92), 84)


## The defense worked: the guard chip swells and says how much it soaked.
func _anim_player_blocked(amount: int) -> void:
	if not _booted:
		return
	SfxService.cue("blocked")
	var guard_chip: Control = status_chips.get("guard", status_plate)
	guard_chip.pivot_offset = guard_chip.size / 2.0
	var tween := create_tween()
	tween.tween_property(guard_chip, "scale", Vector2(1.25, 1.25), 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(guard_chip, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_float_text("Blocked %d" % amount, Color("3a5a7a"),
		_control_center(guard_chip) - Vector2(48, 56))


## Your hit landed: the portrait flinches, flashes, and shows the number.
## The hurt-shake's single home and single live tween (see _anim_enemy_hurt).
var _enemy_shake: Tween = null
var _enemy_home := Vector2.ZERO


func _anim_enemy_hurt(amount: int) -> void:
	if not _booted or enemy_art == null:
		return
	# Ash fights with his claws, so a landed hit IS the claw. Five variants,
	# never twice running — a fight is where law 15 is most audible.
	SfxService.cue("ash_claw")
	# Containers own positions (see UITheme's fade rule), so the shake keeps
	# ONE home: a second hit landing mid-shake used to capture a displaced
	# origin as its base, and the portrait drifted until the next relayout.
	if _enemy_shake != null and _enemy_shake.is_valid():
		_enemy_shake.kill()
		enemy_art.position = _enemy_home
	else:
		_enemy_home = enemy_art.position
	var base := _enemy_home
	_enemy_shake = create_tween()
	_enemy_shake.tween_property(enemy_art, "position", base + Vector2(9, -4), 0.1)
	_enemy_shake.tween_property(enemy_art, "position", base + Vector2(-8, 3), 0.1)
	_enemy_shake.tween_property(enemy_art, "position", base + Vector2(5, -2), 0.1)
	_enemy_shake.tween_property(enemy_art, "position", base, 0.12)
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.96, 0.85, 0.4)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_art.add_child(flash)
	var fade := create_tween()
	fade.tween_property(flash, "color:a", 0.0, 0.56)
	fade.tween_callback(flash.queue_free)
	_float_text("-%d" % amount, Color("8a2f22"),
		_control_center(enemy_art) - Vector2(40, 60), 84)


## A drawn card slides in from the deck chip on the status strip.
func _anim_draw(card: Control, rest: Vector2) -> void:
	var deck_chip: Control = status_chips.get("deck", null)
	if deck_chip == null:
		return
	# Rate-limited in sfx.json rather than here: a turn that draws three cards
	# animates them together, and three card sounds on one frame is a shuffle,
	# not three draws.
	SfxService.cue("card_draw")
	var from := hand_cards.get_global_transform().affine_inverse() \
		* _control_center(deck_chip)
	card.position = from
	card.scale = Vector2(0.5, 0.5)
	card.modulate.a = 0.35
	var tween := create_tween().set_parallel()
	tween.tween_property(card, "position", rest, 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.56)


## A stolen card flies from the hand to the thief and fades out.
func _anim_steal(card_id: String) -> void:
	# Claws on cloth — something being taken off you, not a card being played.
	SfxService.cue("card_stolen")
	var ghost := _card_button(card_id, CARD_SCALE)
	ghost.disabled = true
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floater_layer.add_child(ghost)
	ghost.global_position = _control_center(hand_fan) - Vector2(56, 76)
	var target := _control_center(enemy_art) - ghost.size / 2.0 \
		- global_position
	var tween := create_tween().set_parallel()
	tween.tween_property(ghost, "position", target, 1.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(ghost, "scale", Vector2(0.45, 0.45), 1.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(ghost, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(ghost.queue_free)


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
		text, UITheme.italic_font(), LOG_FONT_SIZE, LOG_WRAP)
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
