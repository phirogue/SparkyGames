class_name SkillText
extends RefCounted
## Renders a skill's RULES into words — one code path for every screen that
## shows a card close up (the battle detail popup, the loadout close-up).
## The templates are writing and live in story/interface.json (law 20); this
## class only fills the numbers in.


static func effect_summary(def: Dictionary) -> String:
	var parts: Array[String] = []
	for effect in def.get("effects", []):
		var kind := String(effect.get("type", ""))
		match kind:
			"damage", "block", "heal", "draw":
				parts.append(Strings.line("skill_rules." + kind, [int(effect["amount"])]))
			"channel_heal":
				parts.append(Strings.line("skill_rules.channel_heal",
					[int(effect["amount"]), int(effect.get("turns", 2))]))
			"self_stun":
				parts.append(Strings.line("skill_rules.self_stun"))
	return " · ".join(parts)


## The cost as a sentence fragment: "needs 2 Ferocity", "free", or the
## instinct line. Reads the RAW definition — battle keeps its own copy of
## this because its costs move with environment discounts mid-fight.
static func cost_line(def: Dictionary) -> String:
	if def.get("instinct", false):
		return Strings.line("skill_rules.instinct")
	var parts: Array[String] = []
	for humour in def.get("cost", {}):
		parts.append("%d %s" % [int(def["cost"][humour]), Catalog.humour_name(String(humour))])
	if parts.is_empty():
		return Strings.line("skill_rules.free")
	return Strings.line("skill_rules.needs", [", ".join(parts)])


static func charges_line(def: Dictionary) -> String:
	if def.get("instinct", false):
		return Strings.line("skill_rules.instinct_uses")
	return Strings.line("skill_rules.charges", [int(def.get("charges", 0))])
