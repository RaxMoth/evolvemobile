class_name TestCase
extends Node

## Base class for headless tests (see test/run_tests.gd). Each `test_*` method
## runs in tree order; async tests may `await`. Assertions report to the runner
## instead of aborting, so one failing check does not hide the others.

var runner: Object = null  # the SceneTree-derived runner (test/run_tests.gd)


func before_each() -> void:
	pass


func after_each() -> void:
	pass


# ---------- assertions ----------

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		runner.call("record_failure", "expected true" + _suffix(msg))


func assert_false(cond: bool, msg: String = "") -> void:
	if cond:
		runner.call("record_failure", "expected false" + _suffix(msg))


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		runner.call("record_failure", "expected %s, got %s%s" % [str(expected), str(actual), _suffix(msg)])


func assert_near(actual: float, expected: float, eps: float = 0.001, msg: String = "") -> void:
	if absf(actual - expected) > eps:
		runner.call("record_failure", "expected ~%s, got %s%s" % [str(expected), str(actual), _suffix(msg)])


func skip(reason: String) -> void:
	runner.call("record_skip", reason)


# ---------- helpers ----------

func wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func wait_seconds(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## Name of the active atomic state of an EntityBase's chart ("Idle", "Dead", …).
func active_state_of(entity: Node) -> String:
	var chart: Node = entity.get_node_or_null("%StateChart")
	if chart == null or chart.get_child_count() == 0:
		return ""
	for child in chart.get_child(0).get_children():
		if "active" in child and child.get("active"):
			return String(child.name)
	return ""


## Instantiate a scene, add it under the runner's sandbox and wait for the
## entity's awaited _ready (two physics frames) to finish.
func spawn_entity(scene_path: String, pos: Vector2 = Vector2.ZERO) -> Node2D:
	var inst := (load(scene_path) as PackedScene).instantiate() as Node2D
	inst.position = pos
	add_child(inst)
	await wait_physics_frames(4)
	await wait_frames(1)
	return inst


func _suffix(msg: String) -> String:
	return "" if msg.is_empty() else " — " + msg
