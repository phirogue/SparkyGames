extends Node
## Why is this screen the wrong shape? Dumps every visible Control's real
## rect, then PageGuard's verdict.
##
##   godot --path game -- --rect-probe --scene battle:q_magpie_gutter
##   godot --path game -- --rect-probe --scene story:6
##
## Engineering law 9 as a tool: when a layout is wrong, ASK THE ENGINE what
## the rects are instead of guessing at the code. This is how the page-wide
## overflow was found — one glance at
##   PageContent [MarginContainer] rect=(0, 0, 820, 1282)
## in a 720x1280 window said everything the screenshots could not.
##
## Exits 2 when PageGuard finds anything, so it can gate a fix.

const SETTLE := 1.2   # let containers sort and the fade-in tweens land


func _ready() -> void:
	await get_tree().create_timer(SETTLE).timeout
	var game := get_parent()
	print("PAGE: ", PageGuard.content_rect())
	_dump(game, 0)
	var problems := PageGuard.violations(game)
	print("VIOLATIONS: ", problems.size())
	for problem in problems:
		print("   ", problem)
	get_tree().quit(0 if problems.is_empty() else 2)


func _dump(node: Node, depth: int) -> void:
	if depth > 5:
		return
	if node is Control:
		var control := node as Control
		if control.is_visible_in_tree():
			print("%s%s [%s] clip=%s rect=%s" % ["  ".repeat(depth), control.name,
				control.get_class(), control.clip_contents, control.get_global_rect()])
	for child in node.get_children():
		_dump(child, depth + 1)
