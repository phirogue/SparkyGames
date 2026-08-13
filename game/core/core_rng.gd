class_name CoreRng
extends RefCounted
## Seeded RNG wrapper. ALL randomness in core/ must flow through one of these
## so runs are reproducible from (seed, command log) alone.

var _rng := RandomNumberGenerator.new()
var initial_seed: int

func _init(seed_value: int) -> void:
	initial_seed = seed_value
	_rng.seed = seed_value

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func pick_index(count: int) -> int:
	assert(count > 0, "pick_index needs a non-empty range")
	return _rng.randi_range(0, count - 1)

## A weighted coin off the same seeded stream. Drawn in tenths of a percent
## rather than as a float so the roll is an integer comparison and a replay
## can never disagree with the original over a rounding bit.
func chance(odds: float) -> bool:
	if odds <= 0.0:
		return false
	if odds >= 1.0:
		return true
	return _rng.randi_range(0, 999) < int(round(odds * 1000.0))

func shuffle(arr: Array) -> void:
	# Fisher-Yates using our seeded stream (Array.shuffle() uses global RNG).
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
