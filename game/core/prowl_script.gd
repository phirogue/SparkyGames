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
##   notice    {"notes": [...], "grant": [skill_id]}   — the rules card, and
##             the one place a quest hands Ash a new ACTION mid-prowl. A
##             skill learned in the middle of a job arrives on the parchment
##             card at the beat that earned it; `unlock_skill` on the quest
##             itself still means "the whole night taught you this".
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


## Every action this quest teaches: the notice steps that hand one over
## mid-prowl, plus the quest's own `unlock_skill` (paid at the end, meaning
## "the whole night taught you this"). One function so the boot-time
## reachability check and the law-7 save heal cannot drift apart — a quest
## that grants a skill in a way only ONE of them knows about is either dead
## content or a skill an old save can never be given.
static func skills_taught_by(quest: Dictionary) -> Array[String]:
	var taught: Array[String] = []
	if quest.has("unlock_skill"):
		taught.append(String(quest["unlock_skill"]))
	for step: Dictionary in steps_of(quest):
		for skill_id in step.get("grant", []):
			taught.append(String(skill_id))
	return taught


## A story step may be keyed to how the previous MINIGAME ended
## (`"when_minigame": "success"` or `"loss"`), the way post-battle prologue
## scenes key on `when_outcome`. A quest that narrates the same confession
## after a won and a lost testimony is a canon bug — law 17's class, and the
## reason this gate exists. Steps without the key always play.
static func minigame_gate_blocks(step: Dictionary, last_won: bool) -> bool:
	if not step.has("when_minigame"):
		return false
	return (String(step["when_minigame"]) == "success") != last_won


## A story step may be keyed to whether this quest has been TRIED before
## (`"when_attempt": "first"` or `"retry"`). A withdrawn or died-on quest
## comes back to the board, and replaying it identically is a continuity bug
## (owner 2026-08-10: "npcs met in the first pass should remember you") — so
## a retried quest swaps its first-meeting beats for remembering ones.
## `attempt` counts the times the quest was started before this run; steps
## without the key always play.
static func attempt_gate_blocks(step: Dictionary, attempt: int) -> bool:
	if not step.has("when_attempt"):
		return false
	return (String(step["when_attempt"]) == "first") != (attempt == 0)


## ------------------------------------------------------------------ facts
##
## FACTS are the durable configuration of what this Ash has seen, met and
## learned: `{"met_bodkin": 1, "heard_cardew_again": 1}`, kept in
## profile.facts. A step records facts with `"sets": {name: int}` the moment
## it is SHOWN, and any step may be keyed to them with `when_fact` — so a
## line that references something choice-gated or branch-gated can be
## PROVEN appropriate instead of remembered to be (the "Cardew said it"
## class of canon bug: a fact from one branch of one quest quoted
## unconditionally in another).
##
## `when_fact` is one clause or a list of clauses that must ALL hold:
##   {"fact": "met_bodkin", "is": 1}    plays only when the fact holds
##   {"fact": "met_bodkin", "not": 1}   plays only when it does not
## A missing fact matches every "not" and no "is". Values are ints only —
## Godot's JSON parser returns floats (CLAUDE.md trap 26), so clauses
## compare through int() and Catalog.validate() rejects anything fancier.
static func fact_gate_blocks(step: Dictionary, facts: Dictionary) -> bool:
	if not step.has("when_fact"):
		return false
	var clauses: Array = []
	if step["when_fact"] is Array:
		clauses = Array(step["when_fact"])
	else:
		clauses = [step["when_fact"]]
	for clause in clauses:
		var c: Dictionary = clause
		var held: Variant = facts.get(String(c.get("fact", "")), null)
		if c.has("is") and (held == null or int(held) != int(c["is"])):
			return true
		if c.has("not") and held != null and int(held) == int(c["not"]):
			return true
	return false


## The facts a step records when shown, int-coerced (trap 26).
static func facts_set_by(step: Dictionary) -> Dictionary:
	var out := {}
	for key in step.get("sets", {}):
		out[String(key)] = int(step["sets"][key])
	return out


## A profile's facts dictionary, made safe to gate on. Saves are player-owned
## files: a hand-edited or corrupted `facts` can hold strings, nulls, nested
## dictionaries — and `int("yes")` misgates silently while `int({})` is
## worse. Keep only numeric values, coerced to int; drop the rest, including
## nameless keys. Idempotent, so the heal can run it on every adopt.
static func sanitize_facts(facts: Variant) -> Dictionary:
	if not (facts is Dictionary):
		return {}
	var out := {}
	for key in facts:
		if String(key).is_empty():
			continue
		if facts[key] is int or facts[key] is float:
			out[String(key)] = int(facts[key])
	return out


## What an old save IMPLIES (law 7): a profile from before facts existed
## merges to facts = {}, and every "have we met?" would answer no to
## characters the player has known for chapters. So facts are re-derived
## from the quests already completed: walk each done quest's steps and
## apply the `sets` of every step that save would actually have shown —
## unconditional steps, first-attempt steps (a done quest was started),
## `when_flag` steps whose branch the profile's own flags confirm, and
## `when_fact` steps replayed against the facts accumulated so far (which
## is how "not yet met → sets met" first-meeting steps derive correctly:
## the gate passed the first time it played). Steps gated on minigame
## results are skipped — that outcome is unknowable after the fact, so
## nothing important may `sets` behind a minigame gate alone. Idempotent —
## run it on every adopt.
static func derive_facts(quests: Dictionary, done: Array,
		flags: Dictionary) -> Dictionary:
	var facts := {}
	for quest_id in done:
		if not quests.has(quest_id):
			continue
		for step in steps_of(quests[quest_id]):
			if not step.has("sets"):
				continue
			if step.has("when_minigame"):
				continue
			if step.has("when_attempt") \
					and String(step["when_attempt"]) != "first":
				continue
			if step.has("when_flag"):
				# .get, not direct index: a malformed gate must not crash
				# every adopt of every save that finished this quest.
				var gate: Dictionary = step["when_flag"] if step["when_flag"] is Dictionary else {}
				if int(flags.get(String(gate.get("flag", "")), -1)) != int(gate.get("value", -1)):
					continue
			if fact_gate_blocks(step, facts):
				continue
			facts.merge(facts_set_by(step), true)
	return facts


## The next fight's encounter id after `index`, or "" — what the Press On
## card previews.
static func next_battle_after(quest: Dictionary, index: int) -> String:
	var script := steps_of(quest)
	for i in range(index + 1, script.size()):
		if type_of(script[i]) == BATTLE:
			return String(script[i]["encounter"])
	return ""
