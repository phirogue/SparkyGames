class_name Rules
extends RefCounted
## The tuning dials, read from data/rules.json.
##
## Every number the game BALANCES on used to be a `const` in whichever .gd
## file happened to use it first: the satchel multiplier in a scene script,
## the hand limit in combat, the Magpie's prices in his screen. That made a
## balance pass a programming task and put the shipped numbers somewhere the
## sims could disagree with.
##
## The values here are the same numbers, in one file a designer can edit. The
## DEFAULTS below are the shipped balance: a key missing from rules.json falls
## back to its default instead of crashing, so a half-written file degrades to
## the game we shipped rather than to a black screen. tests/unit/test_rules.gd
## asserts the file and these defaults still agree, so the fallback can never
## quietly become the real balance.
##
## Pure: no Node, no FileAccess. DataLoader reads the JSON; this class only
## interprets it.

## Shipped balance. Keep in sync with data/rules.json — the test enforces it.
const DEFAULTS := {
	"combat": {
		"hand_limit": 5,
		"paws": 3,
		"opening_hand": 3,
		"concentrate_uses": 2,
		"loadout_size": 5,
		"wild_humour": "mysticism",
	},
	"approaches": {
		"stalk": {"cost": {"shadow": 2}},
		"ambush": {"cost": {"ferocity": 2}},
		"case": {"cost": {"guile": 2}},
		"ward": {"cost": {"mysticism": 2}},
	},
	"prowl": {
		"press_on_mult": 0.25,
		"slip_forfeit": 0.5,
		"toll_rate": 0.25,
		"refusal_rate": 0.1,
	},
	"start": {
		"max_hp": 10,
		"skills": ["scratch"],
		"deck": [
			"ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1", "ferocity_1",
			"guile_1", "guile_1", "guile_1",
			"shadow_1", "shadow_1", "shadow_1", "shadow_1",
			"mysticism_1", "mysticism_1", "mysticism_1",
		],
		"prologue_skills": ["scratch", "pounce", "slink", "purr", "loaf"],
		"lessons_implied_by_prologue": ["growing_stronger"],
	},
	"exchange": {
		"max_hp_cap": 30,
		"deck_floor": 10,
		"tonic_hp": 2,
		"goods": [
			{"mode": "plain", "cost": 6, "seal": "ui/ui_seal_blue"},
			{"mode": "add", "cost": 16, "seal": "ui/ui_seal_red"},
			{"mode": "rare", "cost": 36, "seal": "ui/ui_seal_gold"},
			{"mode": "tonic", "cost": 25, "seal": "ui/ui_seal_red"},
		],
		"humour_mult": {"mysticism": 2.0},
	},
	"minigames": {
		"crossing": {"night_presses_turn": 8},
	},
	"presentation": {
		"recap_line_max": 70,
		"flashback_tint": "#d9b689",
		"music_fade": 1.2,
		"heavy_hit": 4,
	},
}

var _data: Dictionary = {}


func _init(data: Dictionary = {}) -> void:
	_data = data


## Reads a dotted path ("combat.hand_limit", "minigames.crossing.night_presses_turn")
## from the file, falling back to the shipped default. Returns null only when
## the path is not a dial at all — which is a programming error, not a content
## one, so it pushes an error rather than failing silently.
func get_value(path: String) -> Variant:
	var from_file: Variant = _walk(_data, path)
	if from_file != null:
		return from_file
	var from_default: Variant = _walk(DEFAULTS, path)
	if from_default == null:
		push_error("Rules: '%s' is not a known dial" % path)
	return from_default


func _walk(source: Dictionary, path: String) -> Variant:
	var node: Variant = source
	for step in path.split("."):
		if not (node is Dictionary) or not (node as Dictionary).has(step):
			return null
		node = (node as Dictionary)[step]
	return node


func num(path: String) -> float:
	return float(get_value(path))


func count(path: String) -> int:
	return int(get_value(path))


func text(path: String) -> String:
	return String(get_value(path))


## Arrays and dictionaries are handed out as COPIES. A caller that mutates a
## starting deck must not edit the tuning table every later caller reads.
func list(path: String) -> Array:
	var value: Variant = get_value(path)
	return (value as Array).duplicate(true) if value is Array else []


func table(path: String) -> Dictionary:
	var value: Variant = get_value(path)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


## The approach table in the shape CombatState and the battle screen want:
## mode -> {cost}. Notes keys ("_notes") are already stripped by DataLoader at
## the top level, but this table is nested, so they are stripped again here.
func approaches() -> Dictionary:
	var out := {}
	for mode in table("approaches"):
		if String(mode).begins_with("_"):
			continue
		out[mode] = table("approaches." + String(mode))
	return out


## Returns the problems with these dials; empty means coherent. Called from
## Catalog.validate(), so a nonsense balance file stops at boot with a
## readable page rather than dividing by zero four screens later.
func validate() -> Array[String]:
	var problems: Array[String] = []
	for path in ["combat.hand_limit", "combat.paws", "combat.opening_hand",
			"combat.loadout_size"]:
		if count(path) < 1:
			problems.append("rules: %s must be at least 1 (is %d)" % [path, count(path)])
	if count("combat.opening_hand") > count("combat.hand_limit"):
		problems.append("rules: combat.opening_hand (%d) exceeds combat.hand_limit (%d)"
			% [count("combat.opening_hand"), count("combat.hand_limit")])
	for path in ["prowl.press_on_mult", "prowl.slip_forfeit", "prowl.toll_rate",
			"prowl.refusal_rate"]:
		var rate := num(path)
		if rate < 0.0 or rate > 1.0:
			problems.append("rules: %s is %.2f — rates run 0.0 to 1.0" % [path, rate])
	if count("start.max_hp") < 1:
		problems.append("rules: start.max_hp must be at least 1")
	if list("start.deck").is_empty():
		problems.append("rules: start.deck is empty — Ash would open with no energy")
	if list("start.skills").is_empty():
		problems.append("rules: start.skills is empty — Ash would open with no actions")
	# A deck floor above the starting deck size means the Magpie refuses to
	# thin a deck that has never been thickened: a good the player can buy but
	# never use, which reads as a broken button.
	if count("exchange.deck_floor") > list("start.deck").size():
		problems.append("rules: exchange.deck_floor (%d) is above the starting deck size (%d)"
			% [count("exchange.deck_floor"), list("start.deck").size()])
	if count("exchange.max_hp_cap") < count("start.max_hp"):
		problems.append("rules: exchange.max_hp_cap (%d) is below start.max_hp (%d)"
			% [count("exchange.max_hp_cap"), count("start.max_hp")])
	for good in list("exchange.goods"):
		if int((good as Dictionary).get("cost", 0)) < 1:
			problems.append("rules: exchange good '%s' costs nothing"
				% (good as Dictionary).get("mode", "?"))
	# A humour multiplier below 1 would make the rare humour the CHEAP one —
	# the exact opposite of why the dial exists.
	var mults := table("exchange.humour_mult")
	for humour in mults:
		if float(mults[humour]) < 1.0:
			problems.append("rules: exchange.humour_mult.%s is %.2f — must be at least 1.0"
				% [humour, float(mults[humour])])
	if count("exchange.tonic_hp") < 1:
		problems.append("rules: exchange.tonic_hp must add at least one life")
	if count("presentation.recap_line_max") < 20:
		problems.append("rules: presentation.recap_line_max is too small to hold a sentence")
	return problems
