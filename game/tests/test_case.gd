class_name TestCase
extends RefCounted
## Minimal assertion base for headless tests. Runner calls every `test_*`
## method; failures accumulate instead of aborting so one run reports all.

var failures: Array[String] = []
var _current: String = ""

func _record(message: String) -> void:
	failures.append("%s: %s" % [_current, message])

func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		_record(message)

func assert_eq(actual: Variant, expected: Variant, label: String = "") -> void:
	if actual != expected:
		_record("%s expected %s, got %s" % [label, str(expected), str(actual)])

func assert_ok(result: Dictionary, label: String = "command") -> void:
	if not result.get("ok", false):
		_record("%s failed: %s" % [label, result.get("error", "?")])

func assert_rejected(result: Dictionary, label: String = "command") -> void:
	if result.get("ok", false):
		_record("%s should have been rejected but succeeded" % label)
