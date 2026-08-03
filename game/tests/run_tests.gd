extends SceneTree
## Headless test runner:
##   godot --headless --path game -s tests/run_tests.gd
## Exits 0 when green, 1 when any test fails.

const TEST_SCRIPTS: Array[String] = [
	"res://tests/unit/test_catalog.gd",
	"res://tests/unit/test_combat.gd",
	"res://tests/unit/test_achievements.gd",
	"res://tests/unit/test_environment.gd",
	"res://tests/unit/test_approach.gd",
	"res://tests/unit/test_save.gd",
	"res://tests/unit/test_chapter_spine.gd",
	"res://tests/unit/test_chaos.gd",
]

func _initialize() -> void:
	var total := 0
	var failed: Array[String] = []
	for script_path in TEST_SCRIPTS:
		var script: GDScript = load(script_path)
		var case: TestCase = script.new()
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			case._current = "%s.%s" % [script_path.get_file(), method_name]
			case.call(method_name)
		failed.append_array(case.failures)
	print("")
	print("tests run: %d, failures: %d" % [total, failed.size()])
	for failure in failed:
		printerr("  FAIL  " + failure)
	if failed.is_empty():
		print("ALL GREEN")
	quit(0 if failed.is_empty() else 1)
