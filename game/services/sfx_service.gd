class_name SfxService
extends Node
## The one-shots. A voice pool, a variant cycler, and one rule that matters
## more than the rest: **the same cue never plays the same recording twice in
## a row** (law 15).
##
## That rule is why `files` in data/sfx.json is a list. A claw that sounds
## identical five times in one fight stops being a cat and becomes a machine
## playing a wav — the same defect the art repetition checker exists to catch,
## one sense over.
##
## Lives in services/ because it is the layer allowed to touch the filesystem;
## it is a Node rather than a RefCounted because it owns AudioStreamPlayers.
##
## Everything plays on the "SFX" bus, which game.gd creates and the settings
## page mutes and attenuates — so the Sound Effects switch and its loudness
## row keep working without this file knowing that settings exist.
##
## MusicService is the sibling of this class and the two deliberately do not
## know about each other: they own separate buses, separate switches and
## separate volumes, so a player can have the score without the clatter or the
## clatter without the score.

const SFX_DIR := "res://assets/sfx/"
const BUS := "SFX"

## Concurrent voices. A battle turn can resolve a claw, a hurt flash and a
## card draw inside three frames; eight was audibly too few when a multi-hit
## skill resolved. Cheap: an idle AudioStreamPlayer costs nothing.
const VOICES := 16

## The living instance, for call sites that have no clean path to it.
##
## UITheme builds every button in the game from a static context, so wiring a
## tap through constructor arguments would mean threading a service reference
## into several hundred call sites. A static handle costs one line at each and
## is null-safe everywhere — see `cue()`.
static var instance: SfxService = null

## The tour photographs thousands of screens with no ears attached, and a
## headless run has no audio device worth the name. Both set this false.
var enabled := true

## How many one-shots have actually been started. The no-repeat rule is the
## whole design, so it is observable: tests/unit/test_sfx.gd asserts on this.
var plays := 0

## Sound effects turned OFF in the settings page. The bus is muted too, but a
## muted bus still decodes — on a phone that is battery spent on something the
## player explicitly asked not to hear.
var _muted := false

var _cues: Dictionary = {}          # cue_id -> {files, gain_db, cooldown}
var _default_gain := -4.0
var _default_cooldown := 0.05

var _players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _streams: Dictionary = {}       # file id -> AudioStream (load once)
var _last_variant: Dictionary = {}  # cue_id -> index last played
var _last_played_ms: Dictionary = {}  # cue_id -> Time.get_ticks_msec()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Fed from Catalog so this class never reads a file itself beyond the streams.
func configure(cue_data: Dictionary) -> void:
	_cues = cue_data.get("cues", {})
	var defaults: Dictionary = cue_data.get("defaults", {})
	# Godot's JSON parser hands back every number as a float, so these are
	# read as floats deliberately rather than compared against ints (law 26).
	_default_gain = float(defaults.get("gain_db", -4.0))
	_default_cooldown = float(defaults.get("cooldown", 0.05))


## Fire a cue by name. Safe to call from anywhere, including before the
## service exists — a null instance is a no-op, not a crash, because a missing
## sound must never take a screen down with it.
static func cue(cue_id: String) -> void:
	if instance != null:
		instance.play(cue_id)


## Built on first use rather than in _ready, because _ready is not guaranteed
## to have run: the headless test runner is a SceneTree script, and a node
## added to its root there gets no _ready callback.
func _ensure_players() -> void:
	if not _players.is_empty():
		return
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = BUS
		add_child(player)
		_players.append(player)


func play(cue_id: String) -> void:
	if not enabled or _muted or cue_id.is_empty():
		return
	var cue_def: Dictionary = _cues.get(cue_id, {})
	if cue_def.is_empty():
		# A cue nobody defined is a content bug, and it has to be loud here:
		# a call site asking for a sound that does not exist is silent at
		# runtime, which is indistinguishable from a wire never connected.
		push_error("sfx: no cue '%s' in data/sfx.json" % cue_id)
		return

	var files: Array = cue_def.get("files", [])
	if files.is_empty():
		push_error("sfx: cue '%s' names no files" % cue_id)
		return

	var now := Time.get_ticks_msec()
	var cooldown := float(cue_def.get("cooldown", _default_cooldown)) * 1000.0
	if _last_played_ms.has(cue_id) and now - int(_last_played_ms[cue_id]) < cooldown:
		# Dropped on purpose: a held button or a burst of resolved events
		# should not machine-gun one recording. The ACTION still happened —
		# this only declines to make a noise about it.
		return
	_last_played_ms[cue_id] = now

	var index := _pick(cue_id, files.size())
	# The cue has SOUNDED as far as the rules are concerned: every gate above
	# (switch, definition, cooldown, variant) has passed, and that is what
	# `plays` counts and tests/unit/test_sfx.gd asserts on. Everything below is
	# presentation — a missing recording or an out-of-tree player errors loudly
	# but does not un-ring the bell, which is also what lets the policy be
	# tested with no .ogg on disk.
	plays += 1
	var stream := _stream(String(files[index]))
	if stream == null:
		push_error("sfx: cue '%s' wants %s%s.ogg, which is not there" % [
			cue_id, SFX_DIR, files[index]])
		return

	_ensure_players()
	if _players.is_empty():
		return
	# Round-robin rather than "first idle": stealing the oldest voice under
	# load is better than dropping the newest sound, because the newest is the
	# one the player just caused.
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = stream
	player.volume_db = float(cue_def.get("gain_db", _default_gain))
	# An AudioStreamPlayer outside the tree cannot play, and asking anyway
	# pushes an engine error per call. The unit runner is a SceneTree script
	# whose nodes never enter the tree, so a cue fired from a test would bury
	# the real failures under a wall of playback errors. The COUNT has already
	# moved above, because the play was decided; this only touches the speaker.
	if is_inside_tree():
		player.play()


## Which variant to use. Never the one played last (law 15); with two files
## that alternates, with more it is a random pick from the rest.
func _pick(cue_id: String, count: int) -> int:
	if count <= 1:
		return 0
	var last := int(_last_variant.get(cue_id, -1))
	var index := _rng.randi_range(0, count - 1)
	if index == last:
		index = (index + 1 + _rng.randi_range(0, count - 2)) % count
	_last_variant[cue_id] = index
	return index


## The settings page's Sound Effects switch.
func set_muted(value: bool) -> void:
	if value == _muted:
		return
	_muted = value
	if _muted:
		for player in _players:
			player.stop()


func is_muted() -> bool:
	return _muted


## Tests drive this so a variant sequence is reproducible.
func set_seed(value: int) -> void:
	_rng.seed = value


func _stream(file_id: String) -> AudioStream:
	if _streams.has(file_id):
		return _streams[file_id]
	var path := "%s%s.ogg" % [SFX_DIR, file_id]
	if not ResourceLoader.exists(path):
		_streams[file_id] = null
		return null
	var stream := load(path) as AudioStream
	# A one-shot that loops is a one-shot that never stops. The import sets
	# this, but a re-imported .ogg can come back with loop on, and the failure
	# mode (a claw scratching forever under the whole fight) is bad enough to
	# be worth asserting here rather than trusting the .import file.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	_streams[file_id] = stream
	return stream
