class_name ProwlScript
extends RefCounted
## What a quest actually plays, step by step.
##
## A prowl used to be a list of fights and nothing else, which made every
## quest the same shape and left the five minigame modules with nowhere to
## live except the prologue. A quest now carries `steps`: an ordered script
## of fights, story beats, minigames and lessons, so "ask the rats what they
## saw" can be a conversation and "sharpen the claws" can be training.
##
## Step types:
##   battle    {"encounter": id}                       — a fight
##   story     {...story scene fields...}              — a page (or a choice)
##   flashback {"title", "environment", "lines"}      — a Remembered Day:
##             a story page, tinted and headed, that can offer no choices
##             (you cannot re-decide a memory)
##   minigame  {"module": stitch|testimony|ward|lattice|crossing, "id": ...}
##   lesson    {"lesson": id}                          — teach once, then skip
##   notice    {"notes": [...]}                        — the rules card
##
## Old quests that carry only `encounters` still work: they compile to one
## battle step each. That is not a transition state — a straight fight-chain
## IS a legal prowl and most side work stays that way.

const BATTLE := "battle"
const STORY := "story"
const FLASHBACK := "flashback"
const MINIGAME := "minigame"
const LESSON := "lesson"
const NOTICE := "notice"

const MODULES := ["stitch", "testimony", "ward", "lattice", "crossing"]


## The quest's script. `encounters` compiles to battle steps; an explicit
## `steps` array wins and may contain battle steps of its own.
static func steps_of(quest: Dictionary) -> Array:
	if quest.has("steps"):
		return Array(quest["steps"])
	var compiled: Array = []
	for encounter_id in quest.get("encounters", []):
		compiled.append({"type": BATTLE, "encounter": String(encounter_id)})
	return compiled


static func type_of(step: Dictionary) -> String:
	return String(step.get("type", BATTLE))


## Every fight in the script, in order. The satchel maths and the Press On
## offer count FIGHTS, not steps — walking to the Ratsmeet is not depth, and
## the multiplier must not grow because a story page went by.
static func battles_of(quest: Dictionary) -> Array:
	var out: Array = []
	for step in steps_of(quest):
		if type_of(step) == BATTLE:
			out.append(String(step["encounter"]))
	return out


## How many fights have been finished by the time we reach `index`. This is
## the Press On depth: the first fight is depth 0 whether it is step 0 or
## step 4.
static func depth_at(quest: Dictionary, index: int) -> int:
	var depth := 0
	var script := steps_of(quest)
	for i in mini(index, script.size()):
		if type_of(script[i]) == BATTLE:
			depth += 1
	return depth


## Is there another fight after `index`? Press On is only offered when there
## is somewhere deeper to press to; a quest that ends on a conversation
## banks at the conversation instead of asking a question with one answer.
static func has_battle_after(quest: Dictionary, index: int) -> bool:
	var script := steps_of(quest)
	for i in range(index + 1, script.size()):
		if type_of(script[i]) == BATTLE:
			return true
	return false


## A story step may be keyed to how the previous MINIGAME ended
## (`"when_minigame": "success"` or `"loss"`), the way post-battle prologue
## scenes key on `when_outcome`. A quest that narrates the same confession
## after a won and a lost testimony is a canon bug — law 17's class, and the
## reason this gate exists. Steps without the key always play.
static func minigame_gate_blocks(step: Dictionary, last_won: bool) -> bool:
	if not step.has("when_minigame"):
		return false
	return (String(step["when_minigame"]) == "success") != last_won


## The next fight's encounter id after `index`, or "" — what the Press On
## card previews.
static func next_battle_after(quest: Dictionary, index: int) -> String:
	var script := steps_of(quest)
	for i in range(index + 1, script.size()):
		if type_of(script[i]) == BATTLE:
			return String(script[i]["encounter"])
	return ""
