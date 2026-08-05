extends TestCase
## Player-facing prose lives in JSON, not in .gd (CLAUDE.md law 20, owner
## rule 2026-08-05). Two things have to stay true for that to be safe:
##
##   1. Every key the code asks for exists — otherwise the screen shows
##      "«prowl.finish»" and nobody notices until a screenshot.
##   2. No new prose sneaks back into the scripts.
##
## Both are checked by reading the source, because a string constant is
## invisible to every other kind of test we have.

const STRINGS_PATH := "res://story/interface.json"

## Scripts allowed to hold player-facing literals, and why.
##  - strings.gd itself holds the "«missing»" marker.
##  - game.gd's _fatal page is the damaged-install screen: it must render
##    when the content bundle is exactly what cannot be trusted.
const PROSE_EXEMPT := ["strings.gd", "test_strings.gd"]


func _source_files() -> Array[String]:
	var out: Array[String] = []
	for dir_path in ["res://scenes", "res://scenes/minigames", "res://ui",
			"res://core", "res://services"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file_name in dir.get_files():
			if file_name.ends_with(".gd") and not PROSE_EXEMPT.has(file_name):
				out.append(dir_path + "/" + file_name)
	return out


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


func test_every_key_the_code_asks_for_exists() -> void:
	Strings.reset()
	var pattern := RegEx.new()
	pattern.compile('Strings\\.(?:line|lines)\\("([a-z_.]+)"')
	var asked := 0
	for path in _source_files():
		for found in pattern.search_all(_read(path)):
			var key := found.get_string(1)
			# A key built at runtime — Strings.line("battle.approach." + mode)
			# — cannot be checked here; the content it reaches is covered by
			# the validator that owns that data instead.
			if key.ends_with("."):
				continue
			asked += 1
			assert_true(Strings.has(key),
				"%s asks for '%s', which interface.json does not have"
					% [path.get_file(), key])
	assert_true(asked > 20,
		"only %d string lookups found — did the extraction get reverted?" % asked)


func test_the_strings_file_parses_and_has_no_empty_entries() -> void:
	var parsed: Variant = JSON.parse_string(_read(STRINGS_PATH))
	assert_true(parsed is Dictionary, "interface.json must parse as an object")
	_no_blanks(parsed, "")


func _no_blanks(node: Variant, path: String) -> void:
	if node is String:
		assert_true(not String(node).strip_edges().is_empty(),
			"interface.json has an empty string at '%s'" % path)
		return
	if node is Array:
		for i in (node as Array).size():
			_no_blanks(node[i], "%s[%d]" % [path, i])
		return
	if node is Dictionary:
		for key in node:
			if String(key).begins_with("_"):
				continue   # editor notes, not content
			_no_blanks(node[key], path + "." + String(key))


## A line handed the wrong number of arguments renders as a Godot format
## error in the middle of the page, which reads as corruption.
func test_placeholders_survive_being_formatted() -> void:
	Strings.reset()
	assert_eq(Strings.line("prowl.press_on.wager", []),
		Strings.line("prowl.press_on.wager"),
		"a line with no placeholders must survive an empty argument list")
	# lines() hands the SAME arguments to a whole block, so a block that
	# mixes formatted and unformatted lines must not throw on the plain ones.
	var block := Strings.lines("prowl.finish", [10, 6, 4])
	assert_true(block.size() >= 2, "prowl.finish is a block of lines")
	for entry in block:
		assert_true(not String(entry).contains("%d"),
			"unfilled placeholder left in '%s'" % entry)


## The point of the exercise: prose stopped living in the scripts. This is a
## smell test, not a parser — it looks for long English sentences in string
## literals, which is what player-facing prose looks like and what code
## almost never does.
func test_no_new_prose_hides_in_the_scripts() -> void:
	var pattern := RegEx.new()
	# A quoted run of 30+ chars containing a sentence-ending period followed
	# by a space and a capital — two sentences in one literal. NEWLINES ARE
	# EXCLUDED, or the match runs from one string across half a file into the
	# next one and reports code as prose.
	pattern.compile('"[^"\\n]{30,}\\. [A-Z][^"\\n]{10,}"')
	var offenders: Array[String] = []
	for path in _source_files():
		var text := _read(path)
		for found in pattern.search_all(text):
			var literal := found.get_string(0)
			# Doc comments and push_error/push_warning are developer-facing.
			if literal.contains("%s: ") or literal.begins_with('"res://'):
				continue
			var line_start := text.rfind("\n", found.get_start()) + 1
			var line := text.substr(line_start, 200).split("\n")[0].strip_edges()
			if line.begins_with("#") or line.begins_with("##") \
					or line.contains("push_error") or line.contains("push_warning") \
					or line.contains("assert"):
				continue
			offenders.append("%s: %s" % [path.get_file(), literal.substr(0, 70)])
	assert_true(offenders.is_empty(),
		"player-facing prose belongs in JSON (law 20), found:\n  " +
			"\n  ".join(offenders))
