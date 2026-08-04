extends SceneTree
## Art consistency audit (owner request 2026-08-02): flags images that drift
## from the visual profile of their group so the owner can spot-correct
## before wiring them in.
##
##   godot --headless --path game -s tests/art_audit.gd
##   godot --headless --path game -s tests/art_audit.gd -- --dirs assets,../assets/incoming
##
## Groups are inferred from filename prefixes (bg_, en_, sc_, sk_, ui_, ...);
## consistency is judged WITHIN a group — a dark enemy portrait among dark
## enemy portraits is fine; one washed-out pastel enemy is not. The report
## prints here and is written to ../docs/design/art-audit-report.md.
##
## v1 features per image: an 8-bucket hue histogram (weighted by chroma, so
## grays don't vote), mean saturation, mean brightness. Outlier = distance
## from the group centroid beyond both an absolute floor and 1.7x the group's
## median distance. Deliberate style breaks will flag — the report is a
## shortlist for human eyes, not a verdict.

const HUE_BUCKETS := 8
const ABS_FLOOR := 0.16      # below this distance nothing flags, ever
const RELATIVE_GATE := 1.7   # ...and you must also be this odd for the group
const SAMPLE := 48           # images are resized to SAMPLE x SAMPLE first

# The raw art moved into assets/library/<kind>/ on 2026-08-03; incoming/ is now
# only a manual drop zone and incoming/procedural is gone. Scan the library so
# this audits what actually ships.
var _default_dirs := ["assets", "assets/ui",
	"../assets/library/backdrops", "../assets/library/characters",
	"../assets/library/enemies", "../assets/library/scenes",
	"../assets/library/skills", "../assets/library/energy",
	"../assets/library/logos", "../assets/library/ui",
	"../assets/incoming"]


func _initialize() -> void:
	var dirs := _default_dirs
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--dirs" and i + 1 < args.size():
			dirs = []
			for d in args[i + 1].split(","):
				dirs.append(String(d))
	var groups := {}  # prefix -> [{name, path, features}]
	for dir_path in dirs:
		for file in _png_files(dir_path):
			var image := Image.new()
			if image.load(dir_path.path_join(file)) != OK:
				continue
			var features := _features(image)
			if features.is_empty():
				continue  # fully transparent or unreadable
			var group := _group_of(file)
			if not groups.has(group):
				groups[group] = []
			groups[group].append({"name": file, "dir": dir_path, "f": features})
	var report := _audit(groups)
	print(report)
	var out := FileAccess.open("res://../docs/design/art-audit-report.md", FileAccess.WRITE)
	if out != null:
		out.store_string(report)
		print("report written to docs/design/art-audit-report.md")
	quit(0)


func _png_files(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.to_lower().ends_with(".png"):
			found.append(file)
		file = dir.get_next()
	return found


func _group_of(file: String) -> String:
	var stem := file.get_basename()
	if "_" in stem:
		return stem.split("_")[0] + "_"
	return "(other)"


## Hue histogram (chroma-weighted) + mean saturation + mean value, computed
## over opaque pixels of a downsampled copy.
func _features(image: Image) -> Dictionary:
	image.convert(Image.FORMAT_RGBA8)
	image.resize(SAMPLE, SAMPLE, Image.INTERPOLATE_BILINEAR)
	var hues := []
	hues.resize(HUE_BUCKETS)
	hues.fill(0.0)
	var hue_weight := 0.0
	var s_sum := 0.0
	var v_sum := 0.0
	var opaque := 0
	for y in SAMPLE:
		for x in SAMPLE:
			var c := image.get_pixel(x, y)
			if c.a < 0.5:
				continue
			opaque += 1
			s_sum += c.s
			v_sum += c.v
			var chroma := c.s * c.v
			if chroma > 0.03:
				hues[int(c.h * HUE_BUCKETS) % HUE_BUCKETS] += chroma
				hue_weight += chroma
	if opaque < SAMPLE * SAMPLE / 20:
		return {}
	if hue_weight > 0.0:
		for i in HUE_BUCKETS:
			hues[i] /= hue_weight
	return {"hues": hues, "s": s_sum / opaque, "v": v_sum / opaque}


func _distance(a: Dictionary, b: Dictionary) -> float:
	var d := 0.0
	for i in HUE_BUCKETS:
		d += absf(a["hues"][i] - b["hues"][i])
	return d * 0.5 + absf(a["s"] - b["s"]) + absf(a["v"] - b["v"])


func _centroid(entries: Array) -> Dictionary:
	var hues := []
	hues.resize(HUE_BUCKETS)
	hues.fill(0.0)
	var s := 0.0
	var v := 0.0
	for e in entries:
		for i in HUE_BUCKETS:
			hues[i] += e["f"]["hues"][i]
		s += e["f"]["s"]
		v += e["f"]["v"]
	var n := float(entries.size())
	for i in HUE_BUCKETS:
		hues[i] /= n
	return {"hues": hues, "s": s / n, "v": v / n}


func _describe_drift(f: Dictionary, c: Dictionary) -> String:
	var notes: Array[String] = []
	if f["v"] - c["v"] > 0.10:
		notes.append("much brighter than the group")
	elif c["v"] - f["v"] > 0.10:
		notes.append("much darker than the group")
	if f["s"] - c["s"] > 0.10:
		notes.append("more saturated")
	elif c["s"] - f["s"] > 0.10:
		notes.append("more washed-out")
	var names := ["red", "orange", "yellow", "green", "teal", "blue", "violet", "magenta"]
	var biggest := 0
	var biggest_delta := 0.0
	for i in HUE_BUCKETS:
		var delta: float = f["hues"][i] - c["hues"][i]
		if delta > biggest_delta:
			biggest_delta = delta
			biggest = i
	if biggest_delta > 0.15:
		notes.append("hue leans %s" % names[biggest])
	return "; ".join(notes) if not notes.is_empty() else "off-profile mix"


func _audit(groups: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# Art consistency audit")
	lines.append("")
	lines.append("Auto-generated by `tests/art_audit.gd` — flags are a shortlist")
	lines.append("for human review, not verdicts. Re-run after every art drop.")
	var flagged_total := 0
	var group_keys := groups.keys()
	group_keys.sort()
	for group in group_keys:
		var entries: Array = groups[group]
		if entries.size() < 3:
			continue  # no profile to drift from
		var centroid := _centroid(entries)
		var dists: Array[float] = []
		for e in entries:
			e["dist"] = _distance(e["f"], centroid)
			dists.append(e["dist"])
		dists.sort()
		var median: float = dists[dists.size() / 2]
		lines.append("")
		lines.append("## %s (%d images, median drift %.2f)" % [group, entries.size(), median])
		entries.sort_custom(func(a, b): return a["dist"] > b["dist"])
		var clean := true
		for e in entries:
			var is_flag: bool = e["dist"] > ABS_FLOOR \
				and e["dist"] > median * RELATIVE_GATE
			if is_flag:
				clean = false
				flagged_total += 1
				lines.append("- **FLAG** `%s/%s` (drift %.2f): %s" % [
					e["dir"], e["name"], e["dist"],
					_describe_drift(e["f"], centroid)])
		if clean:
			lines.append("- all consistent")
	lines.append("")
	lines.append("---")
	lines.append("%d image(s) flagged." % flagged_total)
	lines.append("")
	return "\n".join(lines)
