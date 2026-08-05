class_name PageGuard
extends RefCounted
## Does anything on screen fall outside the page?
##
## Owner defect, 2026-08-05: in the Magpie quest "all the cards break over the
## border of the background and go off screen." That is not a subtle thing to
## miss — it is missed because nobody photographs the quests, and because a
## human reading a screenshot is the only check we had.
##
## So the check is mechanical and exact. Godot knows every Control's global
## rect; the page's content box is a constant (UITheme.PAGE_MARGIN_*). A
## visible widget whose rect leaves that box is a defect, full stop, and the
## tour fails on it rather than saving a pretty picture of it.
##
## What is deliberately NOT flagged:
##   - invisible or zero-size nodes (they draw nothing)
##   - the page scaffold itself and full-screen scrims, which are SUPPOSED to
##     cover the whole window (dims, tap catchers, the coach overlay)
##   - anything inside a clipping ancestor: a ScrollContainer's children are
##     allowed to be huge, that is the entire point of scrolling
##
## Used by tests/tour.gd after every shot, so a broken layout is reported
## against the screenshot that shows it.

## Names that are meant to span the window. Matched on the node's name, which
## is why the scaffold and overlays set explicit names.
const FULL_SCREEN_OK := [
	"PageScaffold", "PageArt", "Scrim", "Dim", "TapCatcher", "Coach",
	"NoticeScreen", "LampDim", "SettingsLayer", "Chrome",
]

const SLACK := 1.5   # sub-pixel rounding in centred layouts


static func content_rect() -> Rect2:
	return Rect2(UITheme.PAGE_MARGIN_LEFT, UITheme.PAGE_MARGIN_TOP,
		UITheme.CONTENT_WIDTH, UITheme.CONTENT_HEIGHT)


## Every visible Control under `root` that sticks out of the page, as
## human-readable lines. Empty means the screen is inside its own borders.
static func violations(root: Node) -> Array[String]:
	var page := content_rect().grow(SLACK)
	var found: Array[String] = []
	_walk(root, page, false, false, "", found)
	return found


static func _walk(node: Node, page: Rect2, clipped: bool, exempt: bool,
		path: String, found: Array[String]) -> void:
	var here := path
	if node is Control:
		var control := node as Control
		if not control.is_visible_in_tree():
			return
		here = path + "/" + control.name
		# Exemption is INHERITED: the settings button is allowed to live in
		# the margin, so the glyph drawn inside it is allowed there too.
		exempt = exempt or _is_full_screen_ok(control)
		var rect := control.get_global_rect()
		if not clipped and not exempt and rect.size.x > 1.0 and rect.size.y > 1.0 \
				and not page.encloses(rect):
			found.append("%s  %s  outside the page (%s)"
				% [here, _describe(control), _how(rect, page)])
		# A clipping ancestor makes everything below it legal — a scroll view
		# holding a tall list is correct, not broken.
		clipped = clipped or control.clip_contents or control is ScrollContainer
	for child in node.get_children():
		_walk(child, page, clipped, exempt, here, found)


static func _is_full_screen_ok(control: Control) -> bool:
	for name in FULL_SCREEN_OK:
		if control.name.begins_with(name):
			return true
	# Anything anchored to the whole viewport and sized to it is chrome.
	var rect := control.get_global_rect()
	return rect.position.x <= 0.5 and rect.position.y <= 0.5 \
		and rect.size.x >= 719.0 and rect.size.y >= 1279.0


static func _describe(control: Control) -> String:
	if control is Label:
		return "Label '%s'" % (control as Label).text.substr(0, 28)
	if control is Button and not (control as Button).text.is_empty():
		return "Button '%s'" % (control as Button).text.substr(0, 28)
	return control.get_class()


static func _how(rect: Rect2, page: Rect2) -> String:
	var out: Array[String] = []
	if rect.position.x < page.position.x:
		out.append("%.0fpx off the left" % (page.position.x - rect.position.x))
	if rect.position.y < page.position.y:
		out.append("%.0fpx off the top" % (page.position.y - rect.position.y))
	if rect.end.x > page.end.x:
		out.append("%.0fpx off the right" % (rect.end.x - page.end.x))
	if rect.end.y > page.end.y:
		out.append("%.0fpx off the bottom" % (rect.end.y - page.end.y))
	return ", ".join(out)
