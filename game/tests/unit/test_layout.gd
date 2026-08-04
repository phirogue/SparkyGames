extends TestCase
## Law 12, enforced instead of remembered: every screen with a FIXED zone
## template must have its ZONE_* heights, plus the separations between them,
## come to exactly UITheme.CONTENT_HEIGHT.
##
## This drifted by hand twice (a hint label, toast lines injected into story
## text) before it was a rule, and the symptom is always the same — the last
## zone slides off the bottom of the page where nothing catches it. Reading
## the constants straight off the scripts means a screen cannot be re-budgeted
## without this failing first.

const SCREENS := {
	"res://scenes/battle.gd": "ZONE_SEP",
	"res://scenes/case_board_screen.gd": "SEPARATION",
	"res://scenes/hub_screen.gd": "SEPARATION",
	"res://scenes/settings_screen.gd": "SEPARATION",
	"res://scenes/exchange_screen.gd": "SEPARATION",
	"res://scenes/loadout_screen.gd": "SEPARATION",
}


func test_zone_templates_fill_the_page_exactly() -> void:
	for path in SCREENS:
		var script: GDScript = load(path)
		assert_true(script != null, "%s must load" % path)
		if script == null:
			continue
		var constants := script.get_script_constant_map()
		var separation := int(constants.get(SCREENS[path], 0))
		assert_true(separation > 0, "%s needs a positive %s" % [path, SCREENS[path]])
		var total := 0
		var zones := 0
		for name in constants:
			if String(name).begins_with("ZONE_") and constants[name] is int \
					and String(name) != SCREENS[path]:
				total += int(constants[name])
				zones += 1
		assert_true(zones >= 3, "%s should declare a zone template" % path)
		var filled := total + (zones - 1) * separation
		assert_eq(filled, UITheme.CONTENT_HEIGHT,
			"%s: %d zones + %d separation = %d, page is %d" % [
				path, zones, separation, filled, UITheme.CONTENT_HEIGHT])


## The zone MAPS in tests/calibrate.gd are what the owner photographs when
## re-calibrating a screen; a map that disagrees with the screen it describes
## sends the next calibration pass off a cliff.
func test_calibrate_maps_match_their_screens() -> void:
	var maps: Dictionary = load("res://tests/calibrate.gd").get_script_constant_map()["ZONE_MAPS"]
	var pairs := {
		"battle": "res://scenes/battle.gd",
		"case": "res://scenes/case_board_screen.gd",
		"hub": "res://scenes/hub_screen.gd",
		"settings": "res://scenes/settings_screen.gd",
		"exchange": "res://scenes/exchange_screen.gd",
		"loadout": "res://scenes/loadout_screen.gd",
	}
	for key in pairs:
		assert_true(maps.has(key), "calibrate.gd needs a '%s' zone map" % key)
		if not maps.has(key):
			continue
		var mapped := 0
		for zone: Array in maps[key]:
			mapped += int(zone[1])
		var constants: Dictionary = load(pairs[key]).get_script_constant_map()
		var declared := 0
		for name in constants:
			if String(name).begins_with("ZONE_") and constants[name] is int \
					and String(name) != SCREENS[pairs[key]]:
				declared += int(constants[name])
		assert_eq(mapped, declared,
			"'%s' map totals %d but %s declares %d" % [key, mapped, pairs[key], declared])
