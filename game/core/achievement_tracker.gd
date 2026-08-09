class_name AchievementTracker
extends RefCounted
## Lifetime stats + achievement unlocks. Pure core: the scene layer displays
## what this reports; SaveService persists to_dict()/from_dict().
##
## Achievements are data (game/data/achievements.json): each one watches a
## single stat and unlocks at a threshold. Stats are free-form counters —
## systems feed them via increment() or record_encounter().

var catalog: Catalog
var stats: Dictionary = {}            # stat name -> int
var unlocked: Array = []              # achievement ids, in unlock order

func _init(p_catalog: Catalog) -> void:
	catalog = p_catalog


## Bump a stat; returns ids of achievements newly unlocked by this change.
func increment(stat: String, amount: int = 1) -> Array:
	if amount <= 0:
		return []
	stats[stat] = int(stats.get(stat, 0)) + amount
	var newly: Array = []
	for id in catalog.achievements:
		var def: Dictionary = catalog.achievements[id]
		if def["stat"] == stat and not unlocked.has(id) \
				and int(stats[stat]) >= int(def["threshold"]):
			unlocked.append(id)
			newly.append(id)
	return newly


## Digest a finished encounter into stats. Returns newly unlocked ids.
func record_encounter(state: CombatState) -> Array:
	var newly: Array = []
	var flags: Dictionary = state.flags
	match state.outcome:
		CombatState.Outcome.VICTORY:
			newly.append_array(increment("encounters_won"))
			newly.append_array(increment("defeated_" + state.enemy_id))
			if int(flags["damage_taken"]) == 0:
				newly.append_array(increment("flawless_wins"))
			if state.deck.is_empty():
				newly.append_array(increment("exhausted_wins"))
			if flags["killing_skill"] == "shelf_justice":
				newly.append_array(increment("shelf_justice_kills"))
			var used: Dictionary = flags["skills_used"]
			if used.size() == 1 and used.has("scratch"):
				newly.append_array(increment("scratch_only_wins"))
			if state.stealth_threshold > 0 and not state.spotted:
				newly.append_array(increment("unspotted_wins"))
		CombatState.Outcome.DEFEAT:
			newly.append_array(increment("lives_spent"))
			newly.append_array(increment("felled_by_" + state.enemy_id))
		CombatState.Outcome.RETREATED:
			newly.append_array(increment("retreats"))
	newly.append_array(increment("energy_spent", int(flags["energy_paid"])))
	newly.append_array(increment("hand_cards_lost", int(flags["hand_lost"])))
	if flags["purr_completed"]:
		newly.append_array(increment("purrs_completed"))
	return newly


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


func to_dict() -> Dictionary:
	return {
		"schema_version": 1,
		"stats": stats.duplicate(),
		"unlocked": unlocked.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	stats = data.get("stats", {}).duplicate()
	unlocked = data.get("unlocked", []).duplicate()
