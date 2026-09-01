extends TestCase
## THE TYPE FLOOR, enforced (owner standing order, 2026-08-09: "the text size
## is a consistent issue — make it something that is actively corrected so I
## don't need to comment on it each time").
##
## Every review before this rule flagged the same defect: some screen's
## captions set at 17-20px, unreadable at arm's length on a phone. The scale
## now lives in UITheme (TYPE_TITLE 44 / HEADING 34 / BODY 30 / SUPPORT 26 /
## FLOOR 22) with the battle screen as the calibration reference, and this
## test reads font sizes straight out of the scene sources — a size below
## UITheme.TYPE_FLOOR is a red test, not a review comment.
##
## Mechanics: a line is inspected when it styles text — it contains
## `_label(` or `font_size`, or continues a `_label(` call opened on the
## line above. Integer literals between 8 and FLOOR-1 on such a line fail.
## A deliberate exception carries `# type-floor-exempt: <why>` on the line.

const SOURCE_DIRS := ["res://scenes", "res://scenes/minigames", "res://ui"]

## Files written before the rule and not yet brought up to the scale. BURN
## THIS LIST DOWN — a file may leave it, never join it (adding one here is
## the review cycle this test exists to prevent). Each entry is asserted to
## still exist so the list cannot rot into fiction.
const LEGACY_DEBT: Array[String] = []


func _source_files() -> Array[String]:
	var out: Array[String] = []
	for dir_path in SOURCE_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file_name in dir.get_files():
			if file_name.ends_with(".gd"):
				out.append(dir_path + "/" + file_name)
	return out


func test_no_player_facing_text_below_the_floor() -> void:
	var floor_size := UITheme.TYPE_FLOOR
	var number := RegEx.new()
	number.compile("\\b(\\d+)\\b")
	var offenders: Array[String] = []
	for path in _source_files():
		if LEGACY_DEBT.has(path.get_file()):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var previous := ""
		var line_number := 0
		for line in file.get_as_text().split("\n"):
			line_number += 1
			var opened_above := previous.strip_edges().ends_with("_label(")
			previous = line
			var styles_text := line.contains("_label(") or line.contains("font_size")
			if not (styles_text or opened_above):
				continue
			if line.contains("type-floor-exempt:"):
				continue
			var code := line.get_slice("#", 0)  # sizes in comments are prose
			for found in number.search_all(code):
				var value := int(found.get_string(1))
				if value >= 8 and value < floor_size:
					offenders.append("%s:%d has %d (floor is %d): %s" % [
						path.get_file(), line_number, value, floor_size,
						code.strip_edges().substr(0, 60)])
					break
	assert_true(offenders.is_empty(),
		"text below the type floor (owner standing order 2026-08-09) — raise "
		+ "it or mark the line `# type-floor-exempt: <why>`:\n  "
		+ "\n  ".join(offenders))


func test_the_debt_list_cannot_rot() -> void:
	for file_name in LEGACY_DEBT:
		var found := false
		for path in _source_files():
			if path.get_file() == file_name:
				found = true
				break
		assert_true(found,
			"LEGACY_DEBT names '%s', which no longer exists — strike it" % file_name)


## THE CARD NAME FITS THE CARD (owner defect, 2026-08-30: "the energy cards
## for the long way home minigame are too small to fit the name of the energy
## type on them").
##
## A size test rather than a review comment, because this one is invisible in
## code: every number involved was individually reasonable, and the name only
## overflowed once you multiplied the card's width by the fraction of it the
## art actually leaves blank. "Moonlight" is the long one — 94px at the type
## floor — and it is the fourth humour, so it is also the one least likely to
## be on screen when somebody eyeballs a screenshot.
func test_the_widest_humour_name_fits_the_card_it_is_printed_on() -> void:
	var widest := ""
	var widest_px := 0.0
	for humour in Catalog.HUMOURS:
		var text := Catalog.humour_name(String(humour))
		var px := UITheme.measure_text(text, UITheme.body_font(),
			UITheme.TYPE_FLOOR, 4000.0).x
		if px > widest_px:
			widest_px = px
			widest = text
	assert_true(widest_px > 0.0, "the humour names measure to something")
	var card_width: float = load("res://scenes/minigames/crossing_screen.gd") \
		.get_script_constant_map()["CARD_SIZE"].x
	var face := card_width * UITheme.CARD_NAME_BAND
	assert_true(face >= widest_px,
		"the crossing's card is %.0f wide, leaving a %.0f face, and '%s' is %.0f at the type floor"
			% [card_width, face, widest, widest_px])


## THE ACTION NAME FITS THE ACTION CARD (2026-08-31).
##
## Same class of defect as the one above, one screen over. The tray fans its
## cards because five 132-wide cards do not fit across 582px of page, so the
## right ~20px of every card but the last is behind its neighbour — and a name
## that overruns it is not merely tight, it is TRUNCATED, which reads as a
## design choice rather than as a bug. "Shelf Justice" drew as "Shelf Justic"
## for a chapter; "Bite Down", "Long Shadow" and "Her Thread" shipped into the
## same trap the day the roster grew and were renamed off the back of this
## test rather than off a screenshot.
##
## The budget enforced here is THE CARD at the TYPE FLOOR — the last size the
## label is allowed to step down to (UITheme.skill_name_label). Past that the
## name is truncated on every screen it appears on, which is a build-breaking
## content bug.
##
## KNOWN GAP, stated rather than asserted away: the fan's visible band is
## narrower still (~105px), and "Shelf Justice" is 125 at the floor. It fits
## its card and loses about 19px whenever another card is fanned over it.
## Tightening this test to the fan band would fail on shipped, owner-named
## content, and renaming that card is the owner's call, not a test's — so the
## test guards the line that can be defended (a name must at least fit its own
## card) and the residue is written down here where the next person will find
## it. The fix, when it is wanted, is a shorter name: nothing about the page
## geometry can be moved to buy 20px.
func test_every_action_name_fits_its_card() -> void:
	var card: Dictionary = load("res://scenes/battle.gd").get_script_constant_map()
	var band: float = card["NAME_BAND_WIDTH"]
	var catalog := DataLoader.load_catalog()
	for id in catalog.skills:
		var skill_name := String(catalog.skills[id]["name"])
		var px := UITheme.smallcaps_font().get_string_size(
			skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.TYPE_FLOOR).x
		assert_true(px <= band,
			"'%s' is %.0fpx at the type floor; the card's name band is %.0f"
				% [skill_name, px, band])
