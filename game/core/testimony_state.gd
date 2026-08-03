class_name TestimonyState
extends RefCounted
## Testimony — press the witness (docs/design/minigames.md #2).
## Lineage: Ace Attorney pressing, Golden Idol deduction. Pure rules.
##
## A statement lies on the page as ribbons. Two moves:
##   PRESS   — the witness elaborates; some elaborations spawn new ribbons.
##   PRESENT — put a piece of held evidence against the ribbon it contradicts.
##
## A wrong presentation spends patience and costs standing with the witness's
## guild. Patience out is the PARTIAL outcome: the witness clams up and the
## lead continues poorer. It never blocks — no minigame in this game is a
## wall (minigames.md shared rules).
##
## Fair play is enforced here, not left to authors: a ribbon only shimmers
## once the player actually holds the evidence that disproves it, so there is
## no pixel-hunting, and `contradicted_by` is validated to exist.

var testimony: Dictionary = {}
var ribbons: Dictionary = {}          # ribbon id -> data
var visible: Array[String] = []       # ribbon ids on the page, in order
var pressed: Dictionary = {}          # ribbon id -> true
var patience: int = 3
var outcome: int = Minigame.Outcome.ONGOING
var broken_ribbon: String = ""        # the one that gave way
var standing_cost: Dictionary = {}    # guild id -> negative int, applied by caller
var log: CommandLog

var _held: Array = []                 # evidence ids the player has
var _events: Array[String] = []


static func create(testimony_data: Dictionary, held_evidence: Array) -> TestimonyState:
	var state := TestimonyState.new()
	state.testimony = testimony_data
	state.patience = int(testimony_data.get("patience", 3))
	state._held = held_evidence.duplicate()
	state.log = CommandLog.new()
	for ribbon in testimony_data.get("ribbons", []):
		state.ribbons[String(ribbon["id"])] = ribbon
		if bool(ribbon.get("initial", false)):
			state.visible.append(String(ribbon["id"]))
	return state


func witness() -> Dictionary:
	return testimony.get("witness", {})


func guild() -> String:
	return String(witness().get("guild", ""))


func holds(evidence_id: String) -> bool:
	return _held.has(evidence_id)


func held_evidence() -> Array:
	return _held.duplicate()


## The loose-thread shimmer. A ribbon is only marked once the contradiction
## is actually PROVABLE from what the player holds — before that it reads as
## an ordinary statement, which is the fair-play rule made mechanical.
func is_shimmering(ribbon_id: String) -> bool:
	var ribbon: Dictionary = ribbons.get(ribbon_id, {})
	var key := String(ribbon.get("contradicted_by", ""))
	return key != "" and holds(key)


func can_press(ribbon_id: String) -> bool:
	return visible.has(ribbon_id) and not pressed.has(ribbon_id) \
		and String(ribbons.get(ribbon_id, {}).get("press_text", "")) != ""


# ------------------------------------------------------------------ commands

func do_command(command: Dictionary) -> Dictionary:
	if Minigame.is_over(outcome):
		return _fail("the witness has finished with you")
	var result: Dictionary
	match String(command.get("type", "")):
		"press":
			result = _cmd_press(String(command.get("ribbon", "")))
		"present":
			result = _cmd_present(String(command.get("ribbon", "")),
				String(command.get("evidence", "")))
		"leave":
			result = _cmd_leave()
		_:
			result = _fail("unknown command '%s'" % command.get("type", ""))
	if result["ok"]:
		log.record(0, command)
	return result


## Pressing is always safe — it costs no patience. The cost of pressing is
## that it is not an accusation: it can only ever bring more rope.
func _cmd_press(ribbon_id: String) -> Dictionary:
	if not ribbons.has(ribbon_id):
		return _fail("no such ribbon '%s'" % ribbon_id)
	if not visible.has(ribbon_id):
		return _fail("that has not been said yet")
	if pressed.has(ribbon_id):
		return _fail("they have said all they will about that")
	var ribbon: Dictionary = ribbons[ribbon_id]
	if String(ribbon.get("press_text", "")).is_empty():
		return _fail("there is nothing to press there")
	pressed[ribbon_id] = true
	_events.append("pressed")
	for spawned in ribbon.get("spawns", []):
		var spawn_id := String(spawned)
		if ribbons.has(spawn_id) and not visible.has(spawn_id):
			visible.append(spawn_id)
			_events.append("ribbon_spawned")
	return {"ok": true, "error": "", "said": String(ribbon.get("press_text", ""))}


func _cmd_present(ribbon_id: String, evidence_id: String) -> Dictionary:
	if not ribbons.has(ribbon_id):
		return _fail("no such ribbon '%s'" % ribbon_id)
	if not visible.has(ribbon_id):
		return _fail("that has not been said yet")
	if not holds(evidence_id):
		return _fail("you are not carrying that")
	var ribbon: Dictionary = ribbons[ribbon_id]
	if String(ribbon.get("contradicted_by", "")) == evidence_id:
		broken_ribbon = ribbon_id
		outcome = Minigame.Outcome.SUCCESS
		_events.append("thread_caught")
		return {"ok": true, "error": "", "broke": true,
			"said": String(ribbon.get("break_text", ""))}
	# Wrong, but honestly wrong: the witness is not lying, you are early.
	patience -= 1
	_events.append("patience_lost")
	var guild_id := guild()
	if guild_id != "":
		standing_cost[guild_id] = int(standing_cost.get(guild_id, 0)) - 1
	if patience <= 0:
		outcome = Minigame.Outcome.PARTIAL
		_events.append("clammed_up")
	return {"ok": true, "error": "", "broke": false,
		"said": String(ribbon.get("rebuff_text", ""))}


func _cmd_leave() -> Dictionary:
	outcome = Minigame.Outcome.WALKED
	_events.append("walked_away")
	return _ok()


# ------------------------------------------------------------------ results

## What a break hands back to the story layer: evidence found, leads closed,
## knots tied. Empty unless the testimony actually broke.
func break_effects() -> Dictionary:
	if outcome != Minigame.Outcome.SUCCESS or broken_ribbon == "":
		return {}
	return ribbons[broken_ribbon].get("break_effects", {})


## True when at least one visible ribbon can still be broken with what the
## player holds. The UI uses it to decide whether to offer a nudge; the bots
## use it to know a session is still winnable.
func breakable_now() -> Array[String]:
	var options: Array[String] = []
	for ribbon_id in visible:
		if is_shimmering(ribbon_id):
			options.append(ribbon_id)
	return options


func take_events() -> Array[String]:
	var events := _events.duplicate()
	_events.clear()
	return events


func _ok() -> Dictionary:
	return {"ok": true, "error": ""}


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
