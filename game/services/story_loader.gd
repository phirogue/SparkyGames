class_name StoryLoader
extends RefCounted
## Assembles a story book from its parts.
##
## The prologue used to be one 23KB file holding 33 scenes plus four page-sets,
## so every edit touched the same file and no filename told you where a beat
## was. It is now `story/prologue/` — an index naming the arcs in order, one
## file per arc, and the situational pages in their own file.
##
## What this class guarantees is that the SHAPE did not change: it returns
## exactly the dictionary game.gd used to parse out of prologue.json —
## `scenes` plus the interlude keys — so nothing downstream had to learn a new
## layout. Splitting the content was a filing decision, not an interface one.
##
## Services layer: this is one of the few places allowed to touch FileAccess.

const PROLOGUE_DIR := "res://story/prologue"


## The prologue as one book. Returns {} when the index is missing or malformed
## — the caller shows a readable "missing its story" page rather than
## null-dereferencing three screens later.
static func load_prologue(directory: String = PROLOGUE_DIR) -> Dictionary:
	var index := _read(directory + "/index.json")
	if index.is_empty():
		push_error("StoryLoader: cannot read %s/index.json" % directory)
		return {}
	var book := {"scenes": []}
	var scenes: Array = book["scenes"]
	for arc_file in index.get("arcs", []):
		var arc := _read("%s/%s" % [directory, String(arc_file)])
		if arc.is_empty():
			# A missing arc is a hole in the middle of the story. Failing loudly
			# beats silently playing a prologue with an act cut out of it.
			push_error("StoryLoader: arc '%s' is missing or malformed" % arc_file)
			return {}
		scenes.append_array(arc.get("scenes", []))
	var interludes_file := String(index.get("interludes", ""))
	if not interludes_file.is_empty():
		var interludes := _read("%s/%s" % [directory, interludes_file])
		for key in interludes:
			if not String(key).begins_with("_"):
				book[key] = interludes[key]
	return book


## Which arc a scene index falls in, and how far into it — for the developer
## menu and for error messages, so "scene 19" can be reported as somewhere a
## person can actually look ("04_the_way_home, beat 2").
static func locate(directory: String, scene_index: int) -> Dictionary:
	var index := _read(directory + "/index.json")
	var seen := 0
	for arc_file in index.get("arcs", []):
		var arc := _read("%s/%s" % [directory, String(arc_file)])
		var count: int = Array(arc.get("scenes", [])).size()
		if scene_index < seen + count:
			return {
				"arc": String(arc_file),
				"title": String(arc.get("_arc", arc_file)),
				"beat": scene_index - seen,
				"of": count,
			}
		seen += count
	return {}


static func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
