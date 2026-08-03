extends SceneTree
## Feasibility report for the five mission minigames (docs/design/minigames.md).
##
##   godot --headless --path game -s tests/minigames.gd
##   godot --headless --path game -s tests/minigames.gd -- --seeds 50
##
## Answers, per module and per piece of shipped content, three questions:
##   CAN IT BE PLAYED?   a solver bot finishes it using only the public rules
##   CAN IT BE BROKEN?   chaos bots + illegal commands vs the invariants
##   IS THE CONTENT OK?  deep validation, including the searches too slow
##                       to run at boot (exact-cover, loop checks, pull order)
##
## Exits 0 when every module is playable and unbroken.

const DEFAULT_SEEDS := 12

## A mixed pool so patch humours, gusts and payments all have something to
## bite on. Deliberately not the starter deck: minigames must work with the
## decks players actually build.
const TEST_DECK: Array = [
	"ferocity_1", "ferocity_1", "ferocity_2",
	"guile_1", "guile_1", "guile_2",
	"shadow_1", "shadow_1", "shadow_2",
	"mysticism_1", "mysticism_1", "mysticism_2",
]

var catalog: Catalog


func _initialize() -> void:
	catalog = DataLoader.load_catalog()
	var seeds := int(_arg("--seeds", str(DEFAULT_SEEDS)))

	print("mission minigames — feasibility report")
	print("")

	print("[1/3] content validation (boot checks + deep searches)")
	var problems := catalog.validate()
	problems.append_array(catalog.validate_minigames_deep())
	if problems.is_empty():
		print("      all minigame content valid")
	else:
		for problem in problems:
			printerr("      " + problem)
	print("")

	var bots := MinigameBots.new(catalog)

	print("[2/3] solvers — can each shipped puzzle actually be finished?")
	print("")
	print("      %-22s %-16s %s" % ["content", "result", "notes"])
	_report_stitch(bots)
	_report_testimony(bots)
	_report_ward(bots)
	_report_lattice(bots)
	_report_crossing(bots, seeds)
	print("")

	print("[3/3] chaos — random and illegal play against the invariants")
	var before := bots.violations.size()
	for i in seeds:
		var seed_value := 1000 + i * 7919
		for chart_id in catalog.stitch_charts:
			bots.chaos_stitch(chart_id, seed_value)
		for testimony_id in catalog.testimonies:
			bots.chaos_testimony(testimony_id, _all_evidence(), seed_value)
		for ward_id in catalog.wards:
			bots.chaos_ward(ward_id, TEST_DECK, seed_value)
		for lattice_id in catalog.lattices:
			bots.chaos_lattice(lattice_id, seed_value)
		for crossing_id in catalog.crossings:
			bots.chaos_crossing(crossing_id, TEST_DECK, seed_value)
	var chaos_bad := bots.violations.size() - before
	print("      %d chaos sessions, %d violations" % [
		seeds * (catalog.stitch_charts.size() + catalog.testimonies.size()
			+ catalog.wards.size() + catalog.lattices.size()
			+ catalog.crossings.size()), chaos_bad])
	print("")

	if problems.is_empty() and bots.violations.is_empty():
		print("VERDICT: all five modules are playable, and nothing broke them.")
		quit(0)
		return
	printerr("VERDICT: %d content problem(s), %d rule violation(s)" % [
		problems.size(), bots.violations.size()])
	var seen := {}
	for violation in bots.violations:
		var parts := violation.split(": ", true, 1)
		var message: String = parts[1] if parts.size() > 1 else violation
		if not seen.has(message):
			seen[message] = {"count": 0, "first": parts[0]}
		seen[message]["count"] = int(seen[message]["count"]) + 1
	for message in seen:
		printerr("  x%-4d %s" % [seen[message]["count"], message])
		printerr("        first seen: %s" % seen[message]["first"])
	quit(1)


func _all_evidence() -> Array:
	var held: Array = []
	for evidence_id in catalog.evidence_ids():
		held.append(evidence_id)
	held.sort()
	return held


func _row(content: String, result: String, notes: String) -> void:
	print("      %-22s %-16s %s" % [content, result, notes])


func _verdict(bots: MinigameBots, before: int) -> String:
	return "OK" if bots.violations.size() == before else "BROKEN"


func _report_stitch(bots: MinigameBots) -> void:
	print("      -- Seam & Stitch")
	for chart_id in catalog.stitch_charts:
		var before := bots.violations.size()
		var summary := bots.solve_stitch(chart_id)
		bots.probe_stitch_squint(chart_id)
		var chart: Dictionary = catalog.stitch_charts[chart_id]
		_row(chart_id, _verdict(bots, before), "%dx%d, %d stitches, %d clues%s" % [
			int(chart["width"]), int(chart["height"]), int(summary["commands"]),
			chart.get("clues", {}).size(),
			", mirrored" if bool(chart.get("mirrored", false)) else ""])


func _report_testimony(bots: MinigameBots) -> void:
	print("      -- Testimony")
	for testimony_id in catalog.testimonies:
		var before := bots.violations.size()
		var summary := bots.solve_testimony(testimony_id, _all_evidence())
		bots.probe_testimony_patience(testimony_id, _all_evidence())
		var testimony: Dictionary = catalog.testimonies[testimony_id]
		_row(testimony_id, _verdict(bots, before), "%d ribbons, patience %d, broke in %d moves" % [
			testimony.get("ribbons", []).size(), int(testimony.get("patience", 0)),
			int(summary["commands"])])


func _report_ward(bots: MinigameBots) -> void:
	print("      -- Patch the Ward")
	for ward_id in catalog.wards:
		var before := bots.violations.size()
		var summary := bots.solve_ward(ward_id, TEST_DECK)
		bots.probe_ward_lift(ward_id, TEST_DECK)
		var ward: Dictionary = catalog.wards[ward_id]
		_row(ward_id, _verdict(bots, before),
			"tear %d, greedy left %d open, spent %d cards" % [
				ward.get("hole", []).size(), int(summary["uncovered"]),
				int(summary["spent"])])


func _report_lattice(bots: MinigameBots) -> void:
	print("      -- The Unpicking")
	for lattice_id in catalog.lattices:
		var before := bots.violations.size()
		var summary := bots.solve_lattice(lattice_id)
		bots.probe_lattice_mistake(lattice_id)
		var lattice: Dictionary = catalog.lattices[lattice_id]
		_row(lattice_id, _verdict(bots, before), "%d threads, %d elastic rules, clean pull" % [
			lattice.get("threads", []).size(), lattice.get("elastic", []).size()])


func _report_crossing(bots: MinigameBots, seeds: int) -> void:
	print("      -- The Long Way Round")
	for crossing_id in catalog.crossings:
		var before := bots.violations.size()
		var crossed := 0
		var partial := 0
		var walked := 0
		var turn_sum := 0
		for i in seeds:
			var summary := bots.solve_crossing(crossing_id, TEST_DECK, 400 + i * 131)
			turn_sum += int(summary["turns"])
			match int(summary["outcome"]):
				Minigame.Outcome.SUCCESS: crossed += 1
				Minigame.Outcome.PARTIAL: partial += 1
				Minigame.Outcome.WALKED: walked += 1
		bots.probe_crossing_peek(crossing_id, TEST_DECK, 77)
		var rush_crossed := 0
		var rush_hp := 0
		for i in seeds:
			var summary := bots.rush_crossing(crossing_id, TEST_DECK, 400 + i * 131)
			rush_hp += int(summary["hp"])
			if int(summary["outcome"]) == Minigame.Outcome.SUCCESS:
				rush_crossed += 1
		_row(crossing_id, _verdict(bots, before),
			"careful %d%% cross (~%.1f turns) · reckless %d%% cross, ~%.1f hp left" % [
				100 * crossed / seeds, float(turn_sum) / seeds,
				100 * rush_crossed / seeds, float(rush_hp) / seeds])


func _arg(flag: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(flag)
	if index >= 0 and index + 1 < args.size():
		return args[index + 1]
	return fallback
