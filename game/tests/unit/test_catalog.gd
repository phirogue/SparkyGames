extends TestCase
## Content sanity: the shipped JSON must always validate.

func test_shipped_content_is_valid() -> void:
	var catalog := DataLoader.load_catalog()
	var problems := catalog.validate()
	assert_eq(problems.size(), 0, "catalog problems: %s" % str(problems))
	assert_true(catalog.energy_cards.size() >= 12, "expected the 12 starter energy cards")
	assert_true(catalog.skills.has("scratch"), "instinct 'scratch' must exist")
	assert_true(catalog.enemies.has("the_unpicked"), "prologue boss must exist")

func test_validation_catches_bad_content() -> void:
	var bad := Catalog.new({
		"energy_cards": {"x": {"id": "x", "humour": "cheese", "value": 0}},
		"skills": {"s": {"id": "s", "cost": {"cheese": 1}, "charges": 0}},
		"enemies": {"e": {"id": "e", "hp": 0, "intents": []}},
		"encounters": {"q": {"id": "q", "enemies": ["ghost_of_nobody"]}},
	})
	var problems := bad.validate()
	assert_true(problems.size() >= 6, "expected >=6 problems, got %d: %s" % [problems.size(), str(problems)])
