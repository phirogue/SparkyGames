extends TestCase
## Rewards that must actually REACH the player: quest-level growth, and the
## paw a growth reward can grant. Both were written by the engine and read
## by nothing until 2026-08-31 (ship-readiness chaos review).


## Every grant_growth in the catalog must sit where the engine applies it.
## game.gd applies growth on story STEPS and, since 2026-08-31, on quest
## completion. A grant_growth anywhere else is content that silently pays
## nothing — which is how the chapter finale's +2 lives went missing.
func test_every_grant_growth_sits_where_the_engine_applies_it() -> void:
	var catalog := DataLoader.load_catalog()
	var stranded: Array[String] = []
	for quest_id in catalog.quests:
		var quest: Dictionary = catalog.quests[quest_id]
		for step in quest.get("steps", []):
			if not (step is Dictionary):
				continue
			if step.has("grant_growth") and String(step.get("type", "")) != "story":
				stranded.append("%s: growth on a '%s' step" %
					[quest_id, String(step.get("type", "?"))])
	assert_eq(stranded.size(), 0,
		"growth granted where nothing applies it: %s" % str(stranded))


## The profile key exists, so a granted paw survives a save/load round trip.
func test_paws_is_a_registered_profile_key() -> void:
	assert_true(SaveService.DEFAULT_PROFILE.has("paws"),
		"paws must be in DEFAULT_PROFILE (law 14) or a grant cannot persist")
	assert_eq(int(SaveService.DEFAULT_PROFILE["paws"]), 3, "shipped default is 3")
	var old_save := SaveService._migrate({"schema_version": 2, "gleam": 5})
	assert_eq(int(old_save["paws"]), 3, "an old save implies the shipped three")


## A granted paw reaches the rules: CombatState must honour the config key,
## not fall back to the rules.json default forever.
func test_a_granted_paw_reaches_combat() -> void:
	var catalog := DataLoader.load_catalog()
	var state := CombatState.create(catalog, 1234, {
		"enemy": "gutter_wisp",
		"deck": ["ferocity_1", "guile_1", "shadow_1", "shadow_1"],
		"skills": ["scratch"],
		"paws": 4,
	})
	assert_eq(state.paw_limit, 4, "a fourth paw must reach the fight")
