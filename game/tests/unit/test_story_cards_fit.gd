extends TestCase
## Every story card must fit the page it is drawn on.
##
## StoryScreen._retire_overflow() already keeps a scene inside its text zone by
## hiding the OLDEST lines until what remains measures small enough. It cannot
## help with a single line that is on its own too tall: the loop stops while
## `_first_visible < _revealed - 1`, so one line always survives, and if that
## one line overruns the zone it is drawn straight through the bottom of the
## page and out past the stitching.
##
## Which is what shipped. The 2026-08-18 compression round merged narration to
## cut the number of cards a player taps through, and traded card COUNT for
## card DENSITY without noticing: a 258-character card wrapped to seven lines
## where 243 wrapped to six, and the seventh line pushed the tap hint off the
## page. Found by reading a screenshot, which is the only reason it was found.
##
## So: measure every player-facing narration line the way StoryScreen actually
## draws it, and fail on any line that cannot fit its page by itself.
##
## SCOPE, stated honestly. This checks scenes WITHOUT choices, where the budget
## below is _retire_overflow's own arithmetic and was confirmed against real
## screenshots at both ends: a line measuring 306px sits comfortably on the
## page, and one measuring 354px against the same 324px zone is the card that
## overran. Choice scenes are skipped, because there the art block and the
## choice plates are laid out at their own sizes rather than at the constants
## used here, and applying this budget to them reports overflows that the
## screen plainly does not have. Photograph those; do not trust arithmetic
## this test cannot do.

const ART_HEIGHT := 680.0
const ART_HEIGHT_THREE_CHOICES := 572.0
const CHOICE_HEIGHT := 108.0


## StoryScreen._retire_overflow's budget, for a scene with this many choices.
func _budget(choice_count: int, has_heading: bool) -> float:
	var art: float = ART_HEIGHT_THREE_CHOICES if choice_count >= 3 else ART_HEIGHT
	var budget := float(UITheme.CONTENT_HEIGHT) - art - 40.0 - 60.0
	if has_heading:
		budget -= 50.0
	if choice_count > 0:
		budget -= float(choice_count) * CHOICE_HEIGHT
	return budget


## One line, measured in the face and size it is drawn in.
func _height_of(line: Variant) -> float:
	if line is Array:                      # verse: author's own breaks
		var tallest := 0.0
		for part in line:
			tallest += UITheme.measure_text(String(part), UITheme.italic_font(),
				46, float(UITheme.CONTENT_WIDTH)).y
		return tallest + 18.0
	if line is Dictionary:                 # a rule card, set in smallcaps
		return UITheme.measure_text(String(line.get("text", "")),
			UITheme.smallcaps_font(), 32, float(UITheme.CONTENT_WIDTH)).y + 18.0
	return UITheme.measure_text(String(line), UITheme.italic_font(),
		37, float(UITheme.CONTENT_WIDTH)).y + 18.0


func _check_scene(where: String, scene: Dictionary, bad: Array) -> void:
	if String(scene.get("type", "story")) not in ["story", "flashback"]:
		return
	var choice_count: int = (scene.get("choices", []) as Array).size()
	if choice_count > 0:
		return  # see SCOPE above
	var budget := _budget(choice_count, String(scene.get("title", "")) != "")
	for i in (scene.get("lines", []) as Array).size():
		var line: Variant = scene["lines"][i]
		var height := _height_of(line)
		if height > budget:
			var text := String(line) if line is String else str(line)
			bad.append("%s line %d: %.0fpx of a %.0fpx zone — \"%s...\"" % [
				where, i, height, budget, text.substr(0, 60)])


func test_every_story_card_fits_its_page() -> void:
	var bad: Array = []
	var catalog := DataLoader.load_catalog()

	for quest_id in catalog.quests:
		var steps: Array = catalog.quests[quest_id].get("steps", [])
		for i in steps.size():
			_check_scene("%s[%d]" % [quest_id, i], steps[i], bad)

	var book := StoryLoader.load_prologue()
	var scenes: Array = book.get("scenes", [])
	for i in scenes.size():
		_check_scene("prologue[%d]" % i, scenes[i], bad)

	assert_eq(bad.size(), 0,
		"story cards that overrun the page:\n  " + "\n  ".join(bad))
