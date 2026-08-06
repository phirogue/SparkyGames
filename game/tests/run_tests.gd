extends SceneTree
## Headless test runner:
##   godot --headless --path game -s tests/run_tests.gd
## Exits 0 when green, 1 when any test fails.
##
## DISCOVERS its own tests. Every `test_*.gd` in tests/unit/ is found and run,
## sorted by filename so a failure list is stable between runs. There used to
## be a hand-maintained array here, which meant a new test file only ran if
## somebody remembered to add a line to a second file — and a test that never
## runs is worse than no test, because it reads like coverage. The registration
## step is gone; writing the file IS registering it.
##
## A file that discovery finds but cannot load is a HARD failure, not a skip:
## a test suite that quietly shrinks when a script stops compiling is a suite
## that goes green for the wrong reason.

const TEST_DIR := "res://tests/unit"


func _initialize() -> void:
	var script_paths := _discover()
	if script_paths.is_empty():
		printerr("no test files found in %s — is the path right?" % TEST_DIR)
		quit(1)
		return
	var total := 0
	var failed: Array[String] = []
	for script_path in script_paths:
		# A script with a parse error still LOADS — it comes back as a GDScript
		# that cannot be instantiated, and calling .new() on it takes the whole
		# runner down with a confusing "nonexistent function" instead of naming
		# the file that failed to compile. Ask before instantiating.
		var script: GDScript = load(script_path)
		if script == null or not script.can_instantiate():
			failed.append("%s: will not compile — fix the parse error above"
				% script_path.get_file())
			continue
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
	print("tests run: %d across %d files, failures: %d"
		% [total, script_paths.size(), failed.size()])
	for failure in failed:
		printerr("  FAIL  " + failure)
	if failed.is_empty():
		print("ALL GREEN")
	quit(0 if failed.is_empty() else 1)


## Every test_*.gd in tests/unit, sorted. `.remap` shows up instead of `.gd`
## in an exported build; tests never run from an export, but the suffix is
## handled anyway so a stray export cache cannot silently empty the suite.
func _discover() -> Array[String]:
	var found: Array[String] = []
	for file_name in DirAccess.get_files_at(TEST_DIR):
		var name := String(file_name).trim_suffix(".remap")
		if name.begins_with("test_") and name.ends_with(".gd"):
			found.append("%s/%s" % [TEST_DIR, name])
	found.sort()
	return found
