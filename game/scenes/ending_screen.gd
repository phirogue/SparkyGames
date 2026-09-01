extends Control
## The First File — the one-time card that closes Chapter One's case.
##
## A full PAGE, not a popup: the chapter ends on a story beat, and a modal
## over the parlor would make the case closing read as a notification (owner:
## notifications never mix with narrative). Built like the book's covers
## (credits_screen.gd): a flat solemn field instead of the stitched page, the
## same calibrated margins, one way out.
##
## The Mantel decides WHEN this shows (profile "ending_seen", exactly once);
## this page owns only the words — all of which live in story/interface.json
## "ending" (law 9).

signal closed

## FIXED zone template (law 6): heights + separations == CONTENT_HEIGHT.
## 200 + 700 + 180 = 1080, plus 2 x 12 separation = 1104.
const SEPARATION := 12
const ZONE_HEADING := 200
const ZONE_LINES := 700
const ZONE_FOOTER := 180

const LINE_SEPARATION := 30

## Night colors: this is a cover, not a parlor. The field is the title card's
## dark; the ink is the same cream pair the Mantel reads its room by.
const FIELD := Color("1c2026")
const CREAM := Color("efe0c2")

var catalog: Catalog


func setup(p_catalog: Catalog) -> void:
	catalog = p_catalog


func _ready() -> void:
	var margin := UITheme.page_scaffold(self, {"backdrop": FIELD})
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)
	_build_heading(column)
	_build_lines(column)
	_build_footer(column)
	# The score's one non-looping track: the file closes once, and the music
	# says so once. Whoever dismisses this card restores their own bed.
	play_screen_music(self, catalog, "ending")


func _build_heading(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_HEADING)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(holder)
	var heading := UITheme.measured_label(Strings.line("ending.heading"),
		UITheme.TYPE_TITLE, UITheme.CONTENT_WIDTH, UITheme.display_font(), CREAM)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(heading)


func _build_lines(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_LINES)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", LINE_SEPARATION)
	column.add_child(holder)
	# Law 5: every paragraph is measured at the exact width it is pinned to.
	for paragraph in Strings.lines("ending.lines"):
		var line := UITheme.measured_label(String(paragraph), UITheme.TYPE_BODY,
			UITheme.CONTENT_WIDTH, UITheme.body_font(), CREAM)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(line)


func _build_footer(column: VBoxContainer) -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, ZONE_FOOTER)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(holder)
	var button := UITheme.amber_button(Strings.line("ending.button"),
		UITheme.TYPE_BODY)
	button.pressed.connect(func() -> void: closed.emit())
	holder.add_child(button)


## Ask the score for a screen's bed, from a scene that is not game.gd. The
## flow orchestrator owns music for the screens it swaps; this page is parked
## ON another screen, so it finds the one MusicService in the tree and asks
## directly. Null-safe: a component run without a score plays nothing, and
## MusicService itself already ignores a request for the track it is playing.
static func play_screen_music(from: Node, p_catalog: Catalog, key: String) -> void:
	if p_catalog == null or from == null or not from.is_inside_tree():
		return
	var music := from.get_tree().root.find_child("MusicService", true, false) \
		as MusicService
	if music == null:
		return
	var track := p_catalog.music_for_screen(key)
	music.play(track, p_catalog.music_loops(track))
