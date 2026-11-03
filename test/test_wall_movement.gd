extends TestCase

## Fighters never walk through walls (direct moves stop where the navigation
## mesh does), and exploring heroes never park in a corner facing a goal they
## cannot reach.

const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const CTRL := "res://Scenes/NPCs/Hero/HeroExplorationController.tscn"


func test_direct_moves_and_strafing_stop_at_the_wall() -> void:
	var region := await bake_nav_rect(Rect2(0, 0, 400, 400))
	var river := await spawn_frozen(RIVER, Vector2(390, 200))
	var e := river as EntityBase
	assert_true(e.move_toward_point(Vector2(700, 200), 300.0, 0.5), "moves up to the wall")
	assert_true(river.global_position.x <= 402.0, "stopped at the wall, not inside it: %s" % str(river.global_position))
	assert_false(e.move_toward_point(Vector2(700, 200), 300.0, 0.5), "a wall blocks the whole step")
	# Strafing along the wall: a blocked step turns the circle around.
	var mob := await spawn_frozen(BAT, Vector2(300, 200))
	e.target = mob.get_node("Body")
	e.target_entity = mob
	e.global_position = Vector2(398, 200)
	e.strafe_direction = 1
	assert_true(e.is_target_valid(), "strafing around a real enemy")
	var dir: Vector2 = (mob.global_position - river.global_position).normalized()
	for i in range(30):
		e._strafe_around_target(0.1, dir)
		assert_true(river.global_position.x <= 402.0, "strafing stays on the mesh: %s" % str(river.global_position))
	for n in [river, mob, region]:
		n.queue_free()
	await wait_physics_frames(6)


func test_an_entity_off_the_mesh_still_moves() -> void:
	var region := await bake_nav_rect(Rect2(0, 0, 400, 400))
	var river := await spawn_frozen(RIVER, Vector2(600, 200))
	assert_true((river as EntityBase).move_toward_point(Vector2(300, 200), 100.0, 0.5), "never frozen outside the mesh")
	assert_near(river.global_position.x, 550.0, 0.01)
	river.queue_free()
	region.queue_free()
	await wait_physics_frames(6)


func test_exploration_skips_a_waypoint_on_an_unreachable_island() -> void:
	# Main area plus a sealed 16 px island 1000 px east (a lone walkable tile).
	var region := NavigationRegion2D.new()
	var poly := NavigationPolygon.new()
	poly.agent_radius = 0.0
	var src := NavigationMeshSourceGeometryData2D.new()
	src.add_traversable_outline(PackedVector2Array([Vector2(0, 0), Vector2(1000, 0), Vector2(1000, 1000), Vector2(0, 1000)]))
	src.add_traversable_outline(PackedVector2Array([Vector2(2000, 500), Vector2(2016, 500), Vector2(2016, 516), Vector2(2000, 516)]))
	NavigationServer2D.bake_from_source_geometry_data(poly, src)
	region.navigation_polygon = poly
	add_child(region)
	await wait_physics_frames(6)
	var vlad := await spawn_frozen(VLAD, Vector2(500, 500))
	var ctrl := (load(CTRL) as PackedScene).instantiate() as HeroExplorationController
	add_child(ctrl)
	await wait_frames(2)
	ctrl.set_process(false)
	var island := Vector2(2008, 508)
	var reachable := Vector2(900, 500)
	assert_eq(ctrl._first_reachable([island, reachable]), reachable, "the island is skipped")
	assert_true(ctrl._is_abandoned(island), "and remembered as unreachable")
	assert_eq(ctrl._first_reachable([island]), Vector2.ZERO, "nothing reachable: no waypoint")
	for n in [vlad, ctrl, region]:
		n.queue_free()
	await wait_physics_frames(6)


func test_a_hero_jittering_in_a_corner_gets_a_detour_formation_keeps() -> void:
	var vlad := await spawn_frozen(VLAD, Vector2(0, 0))
	var ctrl := (load(CTRL) as PackedScene).instantiate() as HeroExplorationController
	add_child(ctrl)
	await wait_frames(2)
	ctrl.set_process(false)
	ctrl.hero_stuck_anchor.clear()
	(vlad as HeroBase).set_exploration_target(Vector2(5000, 0))
	# Twitching 10 px back and forth: the old 5 px circle never called it stuck.
	for i in range(400):
		vlad.global_position = Vector2(10.0 if i % 2 == 0 else -10.0, 0.0)
		ctrl._check_stuck_heroes(1.0 / 60.0)
	var detour: Vector2 = (vlad as HeroBase).exploration_target
	assert_true(detour != Vector2(5000, 0), "a jittering hero is stuck too")
	assert_true(ctrl._detours.has(vlad), "the detour is remembered")
	ctrl._recalculate_boids()
	ctrl._apply_cached_boids(vlad)
	assert_eq((vlad as HeroBase).exploration_target, detour, "formation does not overwrite the detour")
	vlad.global_position = detour
	ctrl._check_stuck_heroes(1.0 / 60.0)
	assert_false(ctrl._detours.has(vlad), "detour reached: formation takes over again")
	vlad.queue_free()
	ctrl.queue_free()
