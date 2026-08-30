class_name MusicService
extends Node
## The score. Two players, one crossfade, and one rule that matters more than
## the rest: **asking for the track that is already playing does nothing.**
##
## The game swaps a whole screen on every page turn of a story beat. A naive
## "play the track for this screen" would restart the bed once a sentence,
## which reads as a stutter rather than as music. So `play()` compares against
## what is sounding and returns early — every caller can ask on every screen
## change without thinking about it, which is what makes the call sites in
## game.gd one line each.
##
## Lives in services/ because it is the layer allowed to touch the filesystem
## (it loads streams); it is a Node rather than a RefCounted because it owns
## AudioStreamPlayers and needs a tree to tween in.
##
## Everything plays on the "Music" bus, which game.gd creates and the settings
## page mutes — so the Music toggle keeps working without this file knowing
## that settings exist.

const MUSIC_DIR := "res://assets/music/"
const BUS := "Music"
## Fade floor. Not -80: a long tail into inaudibility sounds like the track
## was cut, and -40 dB under a phone speaker is already nothing.
const SILENT_DB := -40.0

## Crossfade length, seconds. Set from data/rules.json presentation.music_fade.
var fade_seconds := 1.2
## Where the score lands when an id has no file behind it — data/music.json's
## `defaults.story`. A room going abruptly quiet reads as a broken game; the
## wrong bed reads as a choice nobody loves. The wrong bed wins.
var fallback_track := ""
## The tour photographs 2,000 screens with no ears attached, and a headless
## run has no audio device worth the name. Both set this false.
var enabled := true

## How many times a stream has actually been started. The no-restart rule is
## the whole design, so it is observable: tests/unit/test_music.gd asserts
## this does not move when the same track is asked for twice.
var starts := 0

## Music turned OFF in the settings page. The bus is muted too, but muting a
## bus still decodes the stream behind it — on a phone that is battery spent
## on something the player explicitly asked not to hear. So playback stops
## outright, and the room the player is in is remembered: turning music back
## on starts THAT track, not whatever was playing when they turned it off.
var _muted := false
var _wanted_loop := true

var _players: Array[AudioStreamPlayer] = []
var _active := -1
var _current := ""
var _tween: Tween


## Built on first use rather than in _ready, because _ready is not guaranteed
## to have run: the headless test runner is a SceneTree script, and a node
## added to its root there gets no _ready callback. A service whose behaviour
## depends on a lifecycle callback firing is a service that works everywhere
## except where it is tested.
func _ensure_players() -> void:
	if not _players.is_empty():
		return
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = BUS
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)


## Tweens need the node in a tree. Outside one (or before the tree runs) the
## fade is skipped and levels are set outright — silent-but-working beats a
## null dereference on a nicety.
func _fade_tween() -> Tween:
	if not is_inside_tree():
		return null
	return create_tween().set_parallel(true)


## What is sounding right now ("" when nothing is).
func current_track() -> String:
	return _current


## Ask for a track. Same track as last time -> nothing happens. "" -> fade to
## silence, which only ever happens because a screen asked for it.
##
## An id with no file behind it is a content bug, and the recovery is the
## fallback bed rather than quiet: a missing file is exactly the kind of defect
## that ships, and it should sound wrong rather than sound like nothing.
func play(track_id: String, loop: bool = true) -> void:
	if not enabled or track_id == _current:
		return
	if _muted:
		# Still tracked, just not sounded: the score keeps following the
		# player through the game so unmuting lands them in the right room.
		_current = track_id
		_wanted_loop = loop
		return
	if track_id.is_empty():
		stop()
		return
	var stream := _load(track_id)
	if stream == null:
		push_error("music: no stream for '%s' (expected %s%s.ogg)" % [
			track_id, MUSIC_DIR, track_id])
		if fallback_track.is_empty() or track_id == fallback_track:
			stop()
		else:
			play(fallback_track, true)
		return
	# Godot exposes looping on the STREAM, not the player: an .ogg imported
	# without it plays once and leaves the room silent for the rest of the
	# scene. Set here rather than in the .import so the loop flag lives beside
	# the track's other content in data/music.json.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	_current = track_id
	_wanted_loop = loop
	_crossfade_to(stream)


## The settings page's Music switch. Off stops the audio and keeps the place;
## on starts the place's track again from the top.
func set_muted(value: bool) -> void:
	if value == _muted:
		return
	_muted = value
	if _muted:
		for player in _players:
			player.stop()
		_kill_tween()
		_active = -1
		return
	if _current.is_empty():
		return
	var resume := _current
	_current = ""      # a real change, so play() does not drop it as a repeat
	play(resume, _wanted_loop)


## Fade everything out. The track id is forgotten, so play() of the same track
## afterwards starts it again — "stop" means stop, not pause.
func stop() -> void:
	_current = ""
	_kill_tween()
	_active = -1
	if _players.is_empty():
		return
	var tween := _fade_tween()
	if tween == null:
		for player in _players:
			player.stop()
		return
	for player in _players:
		tween.tween_property(player, "volume_db", SILENT_DB, fade_seconds)
	tween.chain().tween_callback(func() -> void:
		for player in _players:
			player.stop())
	_tween = tween


func _crossfade_to(stream: AudioStream) -> void:
	_ensure_players()
	if _players.is_empty():
		return
	_kill_tween()
	var incoming: AudioStreamPlayer = _players[(_active + 1) % _players.size()]
	var outgoing: AudioStreamPlayer = _players[_active] if _active >= 0 else null
	_active = _players.find(incoming)

	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	starts += 1

	var tween := _fade_tween()
	if tween == null:
		incoming.volume_db = 0.0
		if outgoing != null:
			outgoing.stop()
		return
	tween.tween_property(incoming, "volume_db", 0.0, fade_seconds)
	if outgoing != null and outgoing.playing:
		tween.tween_property(outgoing, "volume_db", SILENT_DB, fade_seconds)
		# Stopping the old player is chained AFTER the fade rather than fired
		# on a timer: a timer that outlives a scene change stops the NEW track.
		tween.chain().tween_callback(outgoing.stop)
	_tween = tween


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _load(track_id: String) -> AudioStream:
	var path := "%s%s.ogg" % [MUSIC_DIR, track_id]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
