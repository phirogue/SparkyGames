extends SceneTree
## Irregular-play sweep: every persona in ChaosPlay against every encounter,
## over many seeds, hunting states the rules should not allow.
##
##   godot --headless --path game -s tests/fuzz.gd
##   godot --headless --path game -s tests/fuzz.gd -- --seeds 200
##   godot --headless --path game -s tests/fuzz.gd -- --persona hoarder
##   godot --headless --path game -s tests/fuzz.gd -- --encounter prologue_dog
##
## Exits 0 when nothing broke, 1 with a list of violations when something
## did. Every violation names its encounter, persona and SEED, so the same
## run reproduces exactly — turn it into a unit test before fixing it.
##
## This is the edge-case counterpart to simulate.gd, which asks whether
## sensible play is balanced. This asks whether nonsense play is survivable.

const DEFAULT_SEEDS := 25

var catalog: Catalog


func _initialize() -> void:
	catalog = DataLoader.load_catalog()
	var problems := catalog.validate()
	if not problems.is_empty():
		printerr("content is not valid; fix that before fuzzing:")
		for problem in problems:
			printerr("  " + problem)
		quit(1)
		return

	var seeds := int(_arg("--seeds", str(DEFAULT_SEEDS)))
	var only_persona := _arg("--persona", "")
	var only_encounter := _arg("--encounter", "")
	var personas: Array = [only_persona] if only_persona != "" else ChaosPlay.PERSONAS
	var encounters: Array = [only_encounter] if only_encounter != "" \
		else catalog.encounters.keys()
	for persona in personas:
		if not ChaosPlay.PERSONAS.has(persona):
			printerr("unknown persona '%s'; known: %s" % [
				persona, ", ".join(ChaosPlay.PERSONAS)])
			quit(1)
			return
	for encounter_id in encounters:
		if not catalog.encounters.has(encounter_id):
			printerr("unknown encounter '%s'" % encounter_id)
			quit(1)
			return

	print("chaos playtest: %d encounters x %d personas x %d seeds = %d runs" % [
		encounters.size(), personas.size(), seeds,
		encounters.size() * personas.size() * seeds])
	print("")
	print("%-24s %-18s %6s %6s %6s %8s %6s" % [
		"encounter", "persona", "win%", "die%", "flee%", "rejected", "bad"])

	var harness := ChaosPlay.new(catalog)
	var total_runs := 0
	var stuck := 0
	for encounter_id in encounters:
		for persona in personas:
			var wins := 0
			var deaths := 0
			var flees := 0
			var rejected := 0
			var before := harness.violations.size()
			for i in seeds:
				# Seeds are spread by a prime stride so neighbouring cells do
				# not all replay the same shuffle.
				var summary := harness.play(encounter_id, persona, 5000 + i * 7919)
				total_runs += 1
				rejected += int(summary["rejected"])
				match summary["outcome"]:
					CombatState.Outcome.VICTORY: wins += 1
					CombatState.Outcome.DEFEAT: deaths += 1
					CombatState.Outcome.RETREATED: flees += 1
					_: stuck += 1
			var bad := harness.violations.size() - before
			print("%-24s %-18s %5.0f%% %5.0f%% %5.0f%% %8.1f %6d" % [
				encounter_id, persona,
				100.0 * wins / seeds, 100.0 * deaths / seeds, 100.0 * flees / seeds,
				float(rejected) / seeds, bad])
		print("")

	print("runs: %d" % total_runs)
	if stuck > 0:
		printerr("%d run(s) ended with no outcome at all" % stuck)
	if harness.violations.is_empty():
		print("NO VIOLATIONS — the rules held under %d irregular runs." % total_runs)
		quit(0)
		return
	printerr("")
	printerr("%d VIOLATION(S):" % harness.violations.size())
	# The same defect usually fires in every seed; show each distinct message
	# once with a count and one reproducing seed, so the report is readable.
	var seen := {}
	for violation in harness.violations:
		var parts := violation.split(": ", true, 1)
		var message: String = parts[1] if parts.size() > 1 else violation
		if not seen.has(message):
			seen[message] = {"count": 0, "first": parts[0]}
		seen[message]["count"] = int(seen[message]["count"]) + 1
	for message in seen:
		printerr("  x%-5d %s" % [seen[message]["count"], message])
		printerr("         first seen: %s" % seen[message]["first"])
	quit(1)


func _arg(flag: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(flag)
	if index >= 0 and index + 1 < args.size():
		return args[index + 1]
	return fallback
