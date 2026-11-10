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


## spawn_entity with the AI frozen (unregistered from TickScheduler), so the
## test drives every rule by hand.
func spawn_frozen(scene_path: String, pos: Vector2) -> Node2D:
	var e := await spawn_entity(scene_path, pos)
	# By node path: the -s runner compiles TestCase before autoload names exist
	# as globals, so TestCase names no autoload and no project class.
	get_tree().root.get_node(^"TickScheduler").unregister(e)
	return e


# ---------- fixtures ----------

## Plays `side` (MatchRewards.Side: 0 the heroes, 1 the monster) for this
## test: GameManager.chosen_side. Only the played side applies the save's
## skill trees, the other one the AI build (README "Opponent Threat"), so a
## test that seeds a monster tree and spawns the monster plays the monster.
## The runner restores the side after every test.
func play_side(side: int) -> void:
	get_tree().root.get_node(^"GameManager").set("chosen_side", side)


## True when user:// is the throwaway dir tools/run_tests.sh sets up, so the
## test may wipe and rewrite the save file.
func is_isolated() -> bool:
	return OS.get_user_data_dir().contains("evolvemobile_tests")


## Guard for tests that write the save file: skips the test and returns false
## unless user:// is the isolated test dir.
func require_isolated() -> bool:
	if is_isolated():
		return true
	skip("user:// is not the isolated test dir")
	return false


## A SpawnManager (no auto or lazy activation) under the sandbox whose only
## child, get_child(0), is a Bat MobSpawnArea at area_pos: world-eligible but
## not activated yet. Returned as Node, its script loaded by path (see
## spawn_frozen).
func make_spawn_manager(mob_count: int, respawn_time: float, area_pos: Vector2 = Vector2.ZERO) -> Node:
	var mgr: Node = (load("res://Scenes/World/spawns.gd") as GDScript).new()
	mgr.auto_activate_on_ready = false
	mgr.enable_lazy_activation = false
	add_child(mgr)
	var area := (load("res://Scenes/World/MobSpawnArea/MobSpawnArea.tscn") as PackedScene).instantiate() as Node2D
	area.mob_scene = load("res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn")
	area.mob_count = mob_count
	area.auto_spawn_on_ready = false
	area.respawn_time = respawn_time
	area.position = area_pos
	mgr.add_child(area)
	area.virtual_count = mob_count  # what SpawnManager._make_spawn_world_eligible does
	return mgr


## A NavigationRegion2D baked from one traversable outline, added under the
## sandbox; free it (and wait 6 physics frames) to empty the map again.
func bake_nav_outline(points: PackedVector2Array) -> NavigationRegion2D:
	var region := NavigationRegion2D.new()
	var poly := NavigationPolygon.new()
	poly.agent_radius = 0.0
	var src := NavigationMeshSourceGeometryData2D.new()
	src.add_traversable_outline(points)
	NavigationServer2D.bake_from_source_geometry_data(poly, src)
	region.navigation_polygon = poly
	add_child(region)
	await wait_physics_frames(6)  # polygons land one map sync after the region
	return region


func bake_nav_rect(rect: Rect2) -> NavigationRegion2D:
	return await bake_nav_outline(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)]))


func _suffix(msg: String) -> String:
	return "" if msg.is_empty() else " — " + msg
