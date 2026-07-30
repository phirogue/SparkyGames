class_name CommandLog
extends RefCounted
## Append-only record of every player command in a run. Together with the run
## seed this fully reproduces a run (replays, bug repro, daily seeds, and the
## future PvP server-validation path). Never mutate past entries.

var entries: Array[Dictionary] = []

func record(turn: int, command: Dictionary) -> void:
	var entry := command.duplicate(true)
	entry["turn"] = turn
	entries.append(entry)

func to_array() -> Array[Dictionary]:
	return entries.duplicate(true)

func size() -> int:
	return entries.size()
