extends TestCase
## A small, fixed slice of the irregular-play sweep, so edge cases are
## checked on every commit rather than only when someone remembers to run
## the fuzzer. The full matrix lives in tests/fuzz.gd.
##
## If one of these fails, reproduce it with the seed it names:
##   godot --headless --path game -s tests/fuzz.gd -- --persona <name> --encounter <id>

## Deliberately spread: a tutorial fight, a punishing one, the three-answer
## puzzle, a stealth/Alarm environment, and the boss.
const ENCOUNTERS: Array[String] = [
	"prologue_vole", "prologue_dog", "prologue_wraith",
	"q_garden_watch_deep", "prologue_parlor",
]
const SEEDS: Array[int] = [11, 2027, 90210]


func _sweep(personas: Array) -> Array[String]:
	var harness := ChaosPlay.new(DataLoader.load_catalog())
	for encounter_id in ENCOUNTERS:
		for persona in personas:
			for seed_value in SEEDS:
				harness.play(encounter_id, persona, seed_value)
	return harness.violations


func test_random_play_never_breaks_the_rules() -> void:
	var violations := _sweep(["random_legal", "slipper"])
	assert_eq(violations.size(), 0, "random play broke: %s" % str(violations))


## The one that matters most: a rejected command must leave the state
## untouched. A half-applied illegal action is how free-resource bugs happen.
func test_illegal_commands_are_refused_without_side_effects() -> void:
	var violations := _sweep(["chaos_illegal"])
	assert_eq(violations.size(), 0, "illegal commands leaked: %s" % str(violations))


## Degenerate strategies: never firing, throwing everything away, feeding a
## powered skill forever, giving up every turn, and doing nothing at all.
func test_degenerate_strategies_survive_the_rules() -> void:
	var violations := _sweep(["hoarder", "discarder", "overcharger",
		"concentrator", "instinct_only", "pacifist"])
	assert_eq(violations.size(), 0, "a degenerate strategy broke: %s" % str(violations))


## Approaches are turn-1 only and lock on the first real action. Spamming
## them must not pay their cost twice or re-open the window.
func test_approach_spam_cannot_reopen_the_window() -> void:
	var violations := _sweep(["approach_spammer"])
	assert_eq(violations.size(), 0, "approach spam broke: %s" % str(violations))


## Doing nothing must still end: the night presses from turn 8, so a
## pacifist dies rather than sitting in a fight forever.
func test_doing_nothing_still_ends_the_fight() -> void:
	var harness := ChaosPlay.new(DataLoader.load_catalog())
	var summary := harness.play("prologue_dog", "pacifist", 4242)
	assert_eq(harness.violations.size(), 0,
		"pacifist run broke: %s" % str(harness.violations))
	assert_eq(int(summary["outcome"]), CombatState.Outcome.DEFEAT,
		"a cat that never acts is a cat that loses")
	assert_true(int(summary["turns"]) <= 15,
		"the night presses must end it, not the turn cap (turns: %d)" % summary["turns"])
