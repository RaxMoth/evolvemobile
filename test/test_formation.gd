extends TestCase

## Exploration formation: the tank leads and paces the group, melee flank,
## the healer trails, and slots turn with the direction of travel.

const CTRL := "res://Scenes/NPCs/Hero/HeroExplorationController.tscn"
const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const TED := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"


func test_tank_leads_healer_trails_and_followers_pace_on_the_leader() -> void:
	# Roster order puts the fast melee first: the old index-based slots made
	# Ted the "leader" and he reached every camp alone.
	var ted := await spawn_frozen(TED, Vector2(0, 0))
	var vlad := await spawn_frozen(VLAD, Vector2(40, 0))
	var river := await spawn_frozen(RIVER, Vector2(80, 0))
	var irelia := await spawn_frozen(IRELIA, Vector2(120, 0))
	var ctrl := (load(CTRL) as PackedScene).instantiate() as HeroExplorationController
	add_child(ctrl)
	await wait_frames(2)
	assert_eq(ctrl.get_formation_leader(), irelia, "formation_rank 0 leads")
	assert_false(ctrl._formation_slots.has(null))
	for hero in ctrl._formation_slots:
		assert_true(hero is HeroBase, "pets get no slot")

	ctrl.current_group_target = irelia.global_position + Vector2(0, 1000)  # travel south
	ctrl._update_formation_offsets()
	var spread: float = ctrl.formation_spread
	var rear: Vector2 = ctrl.hero_formation_offset[river]
	assert_true(rear.distance_to(Vector2(0, -1.4 * spread)) < 0.5, "healer trails behind the leader")
	var flank: Vector2 = ctrl.hero_formation_offset[ted]
	assert_near(absf(flank.x), spread, 0.5, "melee on a flank")
	assert_true(flank.y < 0.0, "flanks sit slightly behind the leader")

	ctrl._recalculate_boids()
	ctrl._apply_cached_boids(vlad)
	ctrl._apply_cached_boids(irelia)
	var slot: Vector2 = irelia.global_position + ctrl.hero_formation_offset[vlad]
	assert_true((vlad as HeroBase).exploration_target.distance_to(slot) < 150.0,
		"a follower heads for its slot next to the leader, not the far group target")
	assert_true((irelia as HeroBase).exploration_target.distance_to(ctrl.current_group_target) < 150.0,
		"the leader heads for the group target")

	# The leader really walks there: Irelia's own idle used to wander around
	# her allies and ignore the exploration target, stalling the whole group.
	irelia._idle_timer = 0.0
	irelia._on_idle_state_processing(0.016)
	assert_true(irelia._idle_goal.distance_to((irelia as HeroBase).exploration_target) < 1.0,
		"the leader's idle goal is the exploration target")

	irelia.queue_free()
	await wait_frames(2)
	ctrl._cleanup_freed_heroes()
	ctrl._recalculate_boids()
	assert_true(ctrl.get_formation_leader() == vlad or ctrl.get_formation_leader() == ted,
		"a flank takes over when the leader dies")
	for n in [ted, vlad, river, ctrl]:
		n.queue_free()


func test_walking_heroes_are_not_flagged_as_stuck() -> void:
	var vlad := await spawn_frozen(VLAD, Vector2(0, 0))
	var ctrl := (load(CTRL) as PackedScene).instantiate() as HeroExplorationController
	add_child(ctrl)
	await wait_frames(2)
	ctrl.set_process(false)
	ctrl.hero_stuck_anchor.clear()  # a hero seen for the first time
	(vlad as HeroBase).set_exploration_target(Vector2(5000, 0))
	for i in range(400):  # 6.7 s at 1.3 px per frame (a walking hero)
		vlad.global_position += Vector2(1.3, 0)
		ctrl._check_stuck_heroes(1.0 / 60.0)
	assert_true(float(ctrl.hero_stuck_timers.get(vlad, 0.0)) < 1.0, "moving, so never stuck")
	assert_eq((vlad as HeroBase).exploration_target, Vector2(5000, 0), "no detour written")
	for i in range(400):  # really stuck: same spot for 6.7 s
		ctrl._check_stuck_heroes(1.0 / 60.0)
	assert_true((vlad as HeroBase).exploration_target != Vector2(5000, 0), "a truly stuck hero gets a detour")
	vlad.queue_free()
	ctrl.queue_free()


func test_exploration_ignores_off_map_fog_and_abandons_stalled_waypoints() -> void:
	var fog := (load("res://Scenes/World/FogOfWar/FogOfWarSystem.tscn") as PackedScene).instantiate() as FogOfWarSystem
	fog.world_size = Vector2(3200, 3200)
	add_child(fog)
	var vlad := await spawn_frozen(VLAD, Vector2(100, 100))
	var ctrl := (load(CTRL) as PackedScene).instantiate() as HeroExplorationController
	add_child(ctrl)
	await wait_frames(2)
	ctrl.set_process(false)
	ctrl.fog_system = fog
	assert_eq(ctrl._count_unexplored_in_area(Vector2(-400, -400), 150.0, ctrl._fog_rect()), 0, "off-map tiles are not 'unexplored'")
	assert_true(ctrl._count_unexplored_in_area(Vector2(400, 400), 150.0, ctrl._fog_rect()) > 0, "in-map fog still counts")
	ctrl.current_group_target = Vector2(2000, 2000)
	for i in range(10):
		ctrl._track_stall(vlad.global_position)
	assert_true(ctrl._is_abandoned(Vector2(2000, 2000)), "a waypoint the group stopped approaching is abandoned")
	assert_false(ctrl._is_abandoned(Vector2(600, 600)))
	for n in [vlad, ctrl, fog]:
		n.queue_free()


## The precomputed disc offsets and the whole-disc-on-map shortcut count the
## same tiles as the old per-point distance and bounds test.
func test_unexplored_count_matches_the_per_point_version() -> void:
	var fog := (load("res://Scenes/World/FogOfWar/FogOfWarSystem.tscn") as PackedScene).instantiate() as FogOfWarSystem
	fog.world_size = Vector2(3200, 2400)
	fog.world_offset = Vector2(-500, 300)
	add_child(fog)
	var ctrl := (load(CTRL) as PackedScene).instantiate() as HeroExplorationController
	add_child(ctrl)
	await wait_frames(2)
	ctrl.set_process(false)
	ctrl.fog_system = fog
	var rng := RandomNumberGenerator.new()
	rng.seed = 39
	var area := Rect2(fog.world_offset - Vector2(400, 400), fog.world_size + Vector2(800, 800))
	for i in range(40):  # patchy explored fog
		fog.reveal_area(area.position + Vector2(rng.randf(), rng.randf()) * area.size, rng.randf_range(64.0, 320.0), false)
	var fog_rect: Rect2 = ctrl._fog_rect()
	var step: int = ctrl.exploration_tile_size * 2
	var partial: int = 0
	for i in range(200):
		var center := area.position + Vector2(rng.randf(), rng.randf()) * area.size
		var radius: float = 150.0 if i % 4 != 3 else 200.0  # the cache follows the radius
		var expected: int = _old_count_unexplored(fog, center, radius, step)
		assert_eq(ctrl._count_unexplored_in_area(center, radius, fog_rect), expected, "centre %s radius %s" % [center, radius])
		if expected > 0 and expected < ctrl._disc_grid(radius, step).size():
			partial += 1
	assert_true(partial > 20, "the samples cover partly explored and partly off-map discs")
	for n in [ctrl, fog]:
		n.queue_free()


## _count_unexplored_in_area before the disc offsets were precomputed.
func _old_count_unexplored(fog: FogOfWarSystem, center: Vector2, radius: float, step: int) -> int:
	var count := 0
	for x in range(-radius, radius, step):
		for y in range(-radius, radius, step):
			var check_pos := center + Vector2(x, y)
			if check_pos.distance_to(center) <= radius \
					and Rect2(fog.world_offset, fog.world_size).has_point(check_pos):
				if not fog.is_tile_explored(check_pos):
					count += 1
	return count
