class_name Strings
extends RefCounted
## Player-facing prose that is not part of a scripted scene, looked up by key
## from story/interface.json.
##
## Owner rule 2026-08-05: "story elements must not be embedded in the code,
## but stored in a collection of JSON objects, making it easier to make
## changes without changing the underlying program." A line living in a .gd
## file is a line a writer cannot touch, no content tool can see, and no
## validator can check.
##
##   Strings.line("prowl.press_on.wager")
##   Strings.line("chronicle.fed", [humour_name, skill_name])
##   Strings.lines("prowl.finish", [banked, satchel, bonus])
##
## A missing key does NOT crash and does NOT silently vanish: it returns a
## visible "«key»" marker and pushes an error, so a typo shows up in the
## first screenshot rather than as a blank label. tests/unit/test_strings.gd
## scans the scripts for every key asked for and fails if one is absent.

const PATH := "res://story/interface.json"

static var _data: Dictionary = {}


static func _table() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file == null:
			push_error("missing %s" % PATH)
			return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		_data = parsed if parsed is Dictionary else {}
		if _data.is_empty():
			push_error("malformed %s" % PATH)
	return _data


## Reload after an edit — used by the tests, which read the file from disk.
static func reset() -> void:
	_data = {}


static func _at(key: String) -> Variant:
	var node: Variant = _table()
	for part in key.split("."):
		if not (node is Dictionary) or not node.has(part):
			return null
		node = node[part]
	return node


static func has(key: String) -> bool:
	return _at(key) != null


## One line. `args` fills %s/%d placeholders positionally.
static func line(key: String, args: Array = []) -> String:
	var found: Variant = _at(key)
	if found is Array and not found.is_empty():
		found = found[0]
	if not (found is String):
		push_error("interface.json has no string at '%s'" % key)
		return "«%s»" % key
	return _fill(String(found), args)


## A block of lines, each formatted with the SAME argument list — so a
## rewrite may move a number from one line to another without touching code.
static func lines(key: String, args: Array = []) -> Array:
	var found: Variant = _at(key)
	if found is String:
		found = [found]
	if not (found is Array):
		push_error("interface.json has no lines at '%s'" % key)
		return ["«%s»" % key]
	var out: Array = []
	for entry in found:
		out.append(_fill(String(entry), args))
	return out


## Formatting is OPTIONAL per line. `lines()` hands the same arguments to a
## whole block so a rewrite can move a number from one line to another
## without touching code — but a line with no placeholder must survive being
## handed arguments it does not want, which raw `%` does not.
static func _fill(text: String, args: Array) -> String:
	if args.is_empty() or not (text.contains("%s") or text.contains("%d")
			or text.contains("%.")):
		return text
	return text % args
