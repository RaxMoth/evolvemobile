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
	# spawn_frozen lets the AI tick once or twice before it freezes: start from
	# a known spot so the step is measured, not her own wandering.
	river.global_position = Vector2(600, 200)
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


func test_exploration_never_picks_the_ground_the_group_stands_on() -> void:
	# Past the map's walkable edge the fog stays unexplored for good. Samples
	# out there snapped back onto the group's own spot, the group "reached"
	# that waypoint at once and stood at the east edge for 490 s (Nyxa seed 15).
	var region := NavigationRegion2D.new()
	var poly := NavigationPolygon.new()
	poly.agent_radius = 0.0
	var src := NavigationMeshSourceGeometryData2D.new()
	src.add_traversable_outline(PackedVector2Array([Vector2(0, 0), Vector2(1000, 0), Vector2(1000, 1000), Vector2(0, 1000)]))
	NavigationServer2D.bake_from_source_geometry_data(poly, src)
	region.navigation_polygon = poly
	add_child(region)
	await wait_physics_frames(6)
	var vlad := await spawn_frozen(VLAD, Vector2(960, 500))
	var ctrl := (load(CTRL) as PackedScene).instantiate() as HeroExplorationController
	add_child(ctrl)
	await wait_frames(2)
	ctrl.set_process(false)
	var past_edge := Vector2(1400, 500)  # snaps to (1000, 500), 40 px from the group
	var inland := Vector2(500, 500)
	assert_eq(ctrl._first_reachable([past_edge, inland]), inland, "a sample that snaps onto the group is no waypoint")
	assert_false(ctrl._is_abandoned(Vector2(1000, 500)), "and not marked unreachable: it is reachable")
	ctrl.explored_targets.append(Vector2(500, 500))
	var beside := Vector2(300, 500)
	assert_eq(ctrl._first_reachable([Vector2(560, 520), beside]), beside, "nor a point the group reached lately")
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


const FOG := "res://Scenes/World/FogOfWar/FogOfWarSystem.tscn"


## A fog system over `size` px from the origin, every disc of `reveals`
## ([centre, radius]) explored for the AI.
func _fog(size: Vector2, reveals: Array) -> FogOfWarSystem:
	var fog := (load(FOG) as PackedScene).instantiate() as FogOfWarSystem
	fog.world_size = size
	add_child(fog)
	for r: Array in reveals:
		fog.reveal_area(r[0], r[1], false)
	return fog


## The controller for `fog`, with the AI's first two exploration updates
## done (the second one reads the walk mask): its waypoint.
func _explore(fog: FogOfWarSystem) -> HeroExplorationController:
	var ctrl := (load(CTRL) as PackedScene).instantiate() as HeroExplorationController
	add_child(ctrl)
	await wait_frames(2)
	ctrl.set_process(false)
	ctrl.fog_system = fog
	ctrl._update_exploration_targets()
	ctrl._update_exploration_targets()
	return ctrl


## Past the map's walkable edge the fog stays unexplored for good, and a
## sample out there outscored every real waypoint: the group paced the
## explored east for minutes while the west third stayed fog (Nyxa seeds 3
## and 27, no contact). Only walkable fog counts now.
func test_exploration_counts_only_walkable_fog() -> void:
	# A corridor x 0-1400, y 0-300; the fog goes on past its east end and
	# below it (the void). Explored around the group at its east end.
	var region := await bake_nav_rect(Rect2(0, 0, 1400, 300))
	var vlad := await spawn_frozen(VLAD, Vector2(1250, 150))
	var fog := _fog(Vector2(2560, 1280), [[Vector2(1250, 150), 500.0]])
	var ctrl := await _explore(fog)
	var waypoint: Vector2 = ctrl.current_group_target
	assert_true(waypoint.x < 1250.0, "the void east of the corridor never wins: %s" % str(waypoint))
	var nav_map: RID = GameUtils.usable_nav_map(ctrl.get_viewport().world_2d)
	var walkable_fog: int = 0
	for off: Vector2 in ctrl._disc_grid(150.0, 64):
		var p: Vector2 = waypoint + off
		if not fog.is_tile_explored(p) and NavigationServer2D.map_get_closest_point(nav_map, p).distance_to(p) <= 32.0:
			walkable_fog += 1
	assert_true(walkable_fog > 0, "walkable unexplored ground within 150 px of %s" % str(waypoint))
	assert_true(ctrl.debug_line().begins_with("Explore: mask 100%  walkable fog "), ctrl.debug_line())
	for n in [vlad, ctrl, fog, region]:
		n.queue_free()
	await wait_physics_frames(6)


## No walkable fog within reach of the samples (the explored east, the void
## past it): the group heads for the nearest walkable fog anywhere on the
## map instead of a random point, or the void at its own edge.
func test_without_local_fog_the_group_heads_for_the_nearest_walkable_unexplored_cell() -> void:
	var region := await bake_nav_rect(Rect2(0, 0, 3000, 300))
	var vlad := await spawn_frozen(VLAD, Vector2(2800, 150))
	var reveals: Array = []
	for x in range(1600, 3201, 200):
		reveals.append([Vector2(x, 150), 400.0])
	var fog := _fog(Vector2(3200, 640), reveals)
	var ctrl := await _explore(fog)
	var waypoint: Vector2 = ctrl.current_group_target
	assert_true(waypoint.x > 1000.0 and waypoint.x < 1250.0 and waypoint.y >= 0.0 and waypoint.y <= 300.0,
			"the nearest walkable fog, the corridor west of x 1200: %s" % str(waypoint))
	for n in [vlad, ctrl, fog, region]:
		n.queue_free()
	await wait_physics_frames(6)
