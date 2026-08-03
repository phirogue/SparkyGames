class_name Minigame
extends RefCounted
## What every mission module shares (docs/design/minigames.md).
##
## The five modules are separate rule-sets, but they must agree on three
## things or the story layer cannot treat them uniformly:
##
##   1. **Outcomes.** Failure is never a game-over — it is one of three
##      story outcomes, and every module's scene data carries `when_outcome`
##      prose for all three.
##   2. **The command shape.** Same `do_command()` contract as CombatState:
##      one entry point, {ok, error}, nothing mutates on a rejection, and a
##      CommandLog + seed reproduce a session exactly.
##   3. **Gap effects.** Patch the Ward leaves gaps; the Unpicking tears
##      them. Same vocabulary, opposite direction — one table, so a designer
##      writing either module picks from the same list.

enum Outcome {
	ONGOING,
	SUCCESS,   # the working holds
	PARTIAL,   # it half-holds: the lead continues, poorer
	WALKED,    # abandoned; retry allowed, the story notes it
}

## Effects a failed or incomplete working carries into the next encounter.
## These are the shared vocabulary of Patch the Ward's uncovered cells and
## the Unpicking's mis-pulls. Values are documentation for content authors;
## the combat layer reads the id.
const GAP_EFFECTS := {
	"draft": "The ward lets a draft through: the next enemy's first hit is +1.",
	"cold": "Cold gets in: start the next encounter one card down.",
	"loose": "A loose end trails: the next encounter starts with +1 Alarm.",
	"thin": "The mend is thin: start the next encounter with 1 less block.",
}

## Effects a perfect working grants. `warmed` and `sharpened` already exist
## as combat lingering ids, so a perfect mend feeds the existing system
## rather than inventing a parallel one.
const BOON_EFFECTS := {
	"warmed": "The mend holds warm: +2 hp into the next encounter.",
	"sharpened": "Neat work sharpens the paws: the next damage effect is +1.",
	"quiet": "The seam sits quiet: the next encounter starts hidden.",
}


static func outcome_name(outcome: int) -> String:
	match outcome:
		Outcome.SUCCESS: return "success"
		Outcome.PARTIAL: return "partial"
		Outcome.WALKED: return "walk-away"
	return "ongoing"


## Every module's data block names its outcome prose the same way, so the
## story layer can resolve any module's ending without knowing which module
## it was: {"success": "<text id>", "partial": ..., "walk_away": ...}
static func outcome_key(outcome: int) -> String:
	match outcome:
		Outcome.SUCCESS: return "success"
		Outcome.PARTIAL: return "partial"
		Outcome.WALKED: return "walk_away"
	return ""


static func is_over(outcome: int) -> bool:
	return outcome != Outcome.ONGOING


## Shared validation helper: every module's data must name effects that
## actually exist, or a working resolves into silence.
static func unknown_effects(effect_ids: Array, table: Dictionary) -> Array[String]:
	var unknown: Array[String] = []
	for effect_id in effect_ids:
		if not table.has(String(effect_id)):
			unknown.append(String(effect_id))
	return unknown
