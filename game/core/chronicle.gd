class_name Chronicle
extends RefCounted
## Everything the player has done, as FACTS rather than as sentences.
##
## The journal used to be an array of finished prose: `"Found: The candle
## stub"`, appended at the moment it happened. That is a lossy record. A
## sentence cannot be re-rendered when the wording changes, cannot be filtered
## ("show me only the deaths"), cannot be counted, cannot be translated, and
## cannot be turned back into the state it describes. It also meant player-
## facing prose was being written inside .gd files, which law 20 forbids for
## exactly this reason.
##
## So an event records WHAT HAPPENED — a kind, the ids involved, the numbers
## involved — and the words are produced at read time from
## story/interface.json. The same event can render as a journal line today, a
## statistic tomorrow, and a different sentence after a rewrite, with no
## migration.
##
## Pure core: no Node, no FileAccess, and no Strings. `describe()` returns
## render REQUESTS ({key, args}); turning those into sentences is the scene
## layer's job, because that is the layer allowed to read the prose file.

## Kinds, and the ids each one carries. Adding a kind means adding it here AND
## adding `chronicle_log.<kind>` to story/interface.json — tests/unit/
## test_chronicle.gd fails if a kind has no template or a template has no kind.
const KINDS := {
	"prologue_done": {"ids": [], "nums": []},
	"evidence_found": {"ids": ["evidence"], "nums": []},
	"life_spent": {"ids": ["enemy"], "nums": []},
	"court_refused": {"ids": ["enemy"], "nums": []},
	"choice_made": {"ids": [], "nums": [], "texts": ["choice"]},
	"quest_done": {"ids": ["quest"], "nums": ["gleam"]},
	"quest_done_quiet": {"ids": ["quest"], "nums": []},
	"quest_withdrawn": {"ids": ["quest"], "nums": []},
	"skill_gained": {"ids": ["skill"], "nums": []},
	"favor_tied": {"ids": ["favor"], "nums": []},
}

## A long game should not grow an unbounded save file, but the log is small
## (a few dozen bytes an event) and losing history is worse than a big file, so
## this is a runaway guard rather than an editorial choice.
const LIMIT := 500

var events: Array = []
var _next_seq := 1


## Records something that happened. `texts` carries strings that ARE the
## content rather than a reference to it — a chosen option's own label has no
## id to resolve, because the choice was authored inline in the scene.
func record(kind: String, ids: Dictionary = {}, nums: Dictionary = {},
		texts: Dictionary = {}) -> void:
	if not KINDS.has(kind):
		push_error("Chronicle: unknown event kind '%s'" % kind)
		return
	var event := {"seq": _next_seq, "kind": kind}
	_next_seq += 1
	if not ids.is_empty():
		event["ids"] = ids.duplicate()
	if not nums.is_empty():
		event["nums"] = nums.duplicate()
	if not texts.is_empty():
		event["texts"] = texts.duplicate()
	events.append(event)
	if events.size() > LIMIT:
		# Drop the OLDEST. The recent past is what a player is trying to
		# remember when they open the Casebook.
		events = events.slice(events.size() - LIMIT)


## How many times something happened. The prose log could never answer this.
func count(kind: String) -> int:
	var total := 0
	for event in events:
		if String(event.get("kind", "")) == kind:
			total += 1
	return total


## Every event of one kind, oldest first — "show me only the deaths".
func of_kind(kind: String) -> Array:
	var out: Array = []
	for event in events:
		if String(event.get("kind", "")) == kind:
			out.append(event)
	return out


func last_of(kind: String) -> Dictionary:
	var found := of_kind(kind)
	return found[found.size() - 1] if not found.is_empty() else {}


## Render REQUESTS, newest first (the order the Casebook reads).
##
## Each is {key, args}: the scene calls Strings.line(key, args). Ids are
## resolved to display names HERE, against the catalog, which is what makes an
## event re-renderable — the name of a quest can change and every past entry
## picks up the new one.
func describe(catalog: Catalog) -> Array:
	var out: Array = []
	for i in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[i]
		var kind := String(event.get("kind", ""))
		if not KINDS.has(kind):
			continue  # an event written by a newer build than this one
		var args: Array = []
		for id_field in KINDS[kind].get("ids", []):
			args.append(_name_of(catalog, String(id_field),
				String(event.get("ids", {}).get(id_field, ""))))
		for text_field in KINDS[kind].get("texts", []):
			args.append(String(event.get("texts", {}).get(text_field, "")))
		for num_field in KINDS[kind].get("nums", []):
			args.append(int(event.get("nums", {}).get(num_field, 0)))
		out.append({"key": "chronicle_log." + kind, "args": args, "kind": kind})
	return out


## An id's display name. Falls back to the id itself rather than to an empty
## string: a journal line reading "Found: ev_ledger" is ugly, but a line
## reading "Found: " looks like the game lost the entry.
static func _name_of(catalog: Catalog, field: String, id: String) -> String:
	if id.is_empty():
		return ""
	var table: Dictionary = {}
	match field:
		"enemy": table = catalog.enemies
		"quest": table = catalog.quests
		"skill": table = catalog.skills
		"favor": table = catalog.favors
		"evidence":
			for case_id in catalog.cases:
				for entry in catalog.cases[case_id].get("evidence", []):
					if String(entry.get("id", "")) == id:
						return String(entry.get("name", id))
			return id
	return String(table.get(id, {}).get("name", id))


# ------------------------------------------------------------- serialisation

func to_list() -> Array:
	return events.duplicate(true)


static func from_list(saved: Variant) -> Chronicle:
	var chronicle := Chronicle.new()
	if not (saved is Array):
		return chronicle
	var highest := 0
	for event in saved:
		if not (event is Dictionary) or not (event as Dictionary).has("kind"):
			continue  # a corrupt entry loses one line, not the whole history
		chronicle.events.append(event)
		highest = maxi(highest, int((event as Dictionary).get("seq", 0)))
	chronicle._next_seq = highest + 1
	return chronicle
