extends TestCase

## Monster strategy layer (hide & farm → ambush → hunt, retreat) and combos.
## AIs are frozen with TickScheduler.unregister so each rule is driven by hand.

const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"
const AREA := "res://Scenes/World/MobSpawnArea/MobSpawnArea.tscn"


func test_strategy_follows_stage() -> void:
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.FARM, "stage 1 hides and farms")
	g.gain_xp(1000.0)
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.AMBUSH, "stage 2 ambushes")
	g.gain_xp(0.0)
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.HUNT, "stage 3 hunts")
	g.queue_free()


func test_hurt_early_monster_retreats_but_stage_3_hunts() -> void:
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	var a := await spawn_frozen(VLAD, Vector2(200, 0))
	var b := await spawn_frozen(VLAD, Vector2(-200, 0))
	g.current_health = 0.2 * g.get_max_health()
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.RETREAT)
	g.gain_xp(1000.0)
	g.gain_xp(0.0)
	g.current_health = 0.2 * g.get_max_health()
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.HUNT, "retreat only up to retreat_max_stage")
	for n in [g, a, b]:
		n.queue_free()


func test_farming_monster_ignores_heroes_unless_cornered() -> void:
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	var v := await spawn_frozen(VLAD, Vector2(150, 0))
	g._update_strategy()
	assert_true(g._score_target(v) < 0.0, "a hero 150 px away is not engaged at stage 1")
	v.global_position = Vector2(50, 0)
	assert_true(g._score_target(v) > 0.0, "cornered (≤ 70 px): fight back")
	g.queue_free()
	v.queue_free()


func test_ambush_only_engages_isolated_heroes() -> void:
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	g.gain_xp(1000.0)
	var lone := await spawn_frozen(VLAD, Vector2(200, 0))
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.AMBUSH)
	assert_true(g._may_engage_hero(lone), "isolated hero")
	var b := await spawn_frozen(VLAD, Vector2(250, 50))
	var c := await spawn_frozen(VLAD, Vector2(250, -50))
	assert_false(g._may_engage_hero(lone), "three heroes together are not ambushed")
	for n in [g, lone, b, c]:
		n.queue_free()


func test_the_monster_activates_camps_so_it_can_farm() -> void:
	var mgr := SpawnManager.new()
	mgr.auto_activate_on_ready = false
	add_child(mgr)
	var area := (load(AREA) as PackedScene).instantiate() as MobSpawnArea
	area.mob_scene = load(BAT)
	area.mob_count = 3
	area.auto_spawn_on_ready = false
	area.position = Vector2(5000, 5000)
	mgr.add_child(area)
	area.virtual_count = 3
	mgr.active_spawn_areas.append(area)
	var g := await spawn_frozen(GROUNT, Vector2(5000, 5000))
	await wait_seconds(0.4)
	assert_true(area.is_active, "a camp next to the monster activates (no hero needed)")
	assert_eq(area.spawned_mobs.size(), 3)
	g.queue_free()
	mgr.queue_free()


func test_ram_dash_stops_in_cleave_range_instead_of_overshooting() -> void:
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	var v := await spawn_frozen(VLAD, Vector2(220, 0))
	g.target = v.get_node("Body")
	g.target_entity = v
	assert_true(g._cast("ability_2", g.ability_2, v))
	assert_true(g._is_busy(), "dashing")
	await wait_seconds(0.8)
	var d: float = g.global_position.distance_to(v.global_position)
	assert_true(d <= g.attack_range, "landed in cleave range (%.0f px)" % d)
	assert_true(g.global_position.x < v.global_position.x, "did not run past the target")
	g.queue_free()
	v.queue_free()


func test_ground_slam_keeps_the_evolved_scale_and_stage_radius() -> void:
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	g.gain_xp(1000.0)
	g.gain_xp(0.0)
	assert_eq(g.current_stage, 3)
	await wait_seconds(0.7)  # stage scale tween
	var slam: AbilityBase = g.ability_3
	assert_near(float(slam.get("slam_radius")), 180.0, 0.5, "stage-3 radius from aoe_per_stage")
	slam.execute(g, null, 0.0)
	assert_true(slam.is_channeling())
	await wait_seconds(1.3)
	assert_false(slam.is_channeling())
	assert_true(g.scale.is_equal_approx(g.monster_stats.stage_3_scale), "scale %s after the slam" % str(g.scale))
	g.queue_free()


func test_cast_lock_allows_one_ability_per_lock_window() -> void:
	# Start with ONE hero in range so the first cast is the non-channeling
	# Front Cleave: only the cast lock (not a dash/leap in progress) can then
	# refuse the slam that becomes possible in the same frame.
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	g.gain_xp(1000.0)
	g.gain_xp(0.0)
	var v := await spawn_frozen(VLAD, Vector2(40, 0))
	g.target = v.get_node("Body")
	g.target_entity = v
	await wait_seconds(0.7)
	g._choose_and_use_ability_combo()
	assert_false(g.is_ability_ready("ability_1"), "Front Cleave fired on the lone hero")
	assert_true(g._cast_lock > 0.0, "the cast started the lock")
	var w := await spawn_frozen(VLAD, Vector2(40, 30))
	g._cast_lock = g.strategy_profile.cast_lock_time  # spawning took frames
	g._choose_and_use_ability_combo()
	assert_true(g.is_ability_ready("ability_3"), "slam refused while the lock runs")
	await wait_seconds(g.strategy_profile.cast_lock_time + 0.05)
	g._choose_and_use_ability_combo()
	assert_false(g.is_ability_ready("ability_3"), "slam fires once the lock expired")
	for n in [g, v, w]:
		n.queue_free()


func test_taunt_overrides_strategy() -> void:
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	var v := await spawn_frozen(VLAD, Vector2(300, 0))
	var fx := Node.new()
	fx.name = "TauntEffect"
	fx.set_meta("taunter", v)
	g.add_child(fx)
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.FARM)
	assert_true(g._score_target(v) >= 10000.0, "taunted: the taunter is the only target")
	g.queue_free()
	v.queue_free()


func test_low_hp_monster_rests_ignores_mobs_and_regenerates() -> void:
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	var bat := await spawn_frozen(BAT, Vector2(100, 0))
	g._update_strategy()
	assert_true(g._score_target(bat) > 0.0, "a healthy farming monster takes mob fights")
	var max_hp: float = g.get_max_health()
	g.current_health = 0.3 * max_hp
	g._pre_tick(0.1)
	assert_true(g.is_resting(), "below rest_hp_pct")
	bat.target_entity = null  # it may have spotted the monster already
	assert_true(g._score_target(bat) < 0.0, "resting: no new mob fights")
	bat.target_entity = g
	assert_true(g._score_target(bat) > 0.0, "resting, but a mob going for it gets fought back")
	var hog := await spawn_frozen(HOG, Vector2(-100, 0))
	hog.target_entity = g
	assert_true(g._score_target(hog) < 0.0, "a mob above the stage-1 farming gate is still walked away from")
	hog.queue_free()
	bat.target_entity = null
	g._since_damage = 0.0
	var hp: float = g.current_health
	g._pre_tick(1.0)
	assert_eq(g.current_health, hp, "no regeneration within regen_delay of a hit")
	g._pre_tick(5.0)
	assert_true(g.current_health > hp, "regenerates once out of combat")
	g.current_health = 0.85 * max_hp
	g._pre_tick(0.1)
	assert_false(g.is_resting(), "back to farming at resume_hp_pct")
	g.queue_free()
	bat.queue_free()


func test_stage_1_monster_flees_hogs_attacking_it_instead_of_farming_beside_them() -> void:
	# Sim: Hogs pounded a stage-1 Grount to death while it kept farming the Bats
	# next to them (~1 match in 8); fighting the Hogs back lost even more HP.
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	var bat := await spawn_frozen(BAT, Vector2(60, 0))
	var hog := await spawn_frozen(HOG, Vector2(-60, 0))
	bat.target_entity = null
	hog.target_entity = null
	g._update_strategy()
	assert_true(g._score_target(bat) > 0.0, "farming Bats while nothing tough is on it")
	hog.target_entity = g
	g._update_strategy()
	assert_eq(g._mob_threats.size(), 1, "the attacking Hog is a threat")
	assert_true(g._score_target(bat) < 0.0, "no Bat fights while a Hog is on it")
	assert_true(g._score_target(hog) < 0.0, "and no Hog fight either (above the stage-1 farming gate)")
	var dest: Vector2 = g._get_smart_idle_destination()
	assert_true(dest.x > 0.0, "flees away from the Hog: %s" % str(dest))
	hog.target_entity = null
	g._update_strategy()
	assert_true(g._mob_threats.is_empty(), "threat over once the Hog gives up")
	assert_true(g._score_target(bat) > 0.0, "back to farming")
	for n in [g, bat, hog]:
		n.queue_free()


func _camp(mgr: SpawnManager, mob_path: String, pos: Vector2) -> MobSpawnArea:
	var area := (load(AREA) as PackedScene).instantiate() as MobSpawnArea
	area.mob_scene = load(mob_path)
	area.mob_count = 3
	area.auto_spawn_on_ready = false
	area.position = pos
	mgr.add_child(area)
	area.virtual_count = 3
	mgr.active_spawn_areas.append(area)
	return area


func test_stage_1_farms_bats_and_leaves_hogs_alone() -> void:
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	var bat := await spawn_frozen(BAT, Vector2(100, 0))
	var hog := await spawn_frozen(HOG, Vector2(-100, 0))
	bat.target_entity = null  # frozen, but their DetectionAreas may have spotted it
	hog.target_entity = null  # (an attacking Hog makes the monster flee instead)
	g._update_strategy()
	assert_true(g._score_target(bat) > 0.0, "bats are stage-1 food")
	assert_true(g._score_target(hog) < 0.0, "a 100-HP hog is too tough at stage 1")
	var mgr := SpawnManager.new()
	mgr.auto_activate_on_ready = false
	mgr.add_to_group(&"SpawnManager")
	add_child(mgr)
	var bats := _camp(mgr, BAT, Vector2(4000, 0))
	_camp(mgr, HOG, Vector2(-2500, 0))
	assert_eq(g._pick_camp(), bats, "the nearer hog camp is skipped")
	g.gain_xp(1000.0)
	g._update_strategy()
	assert_true(g._score_target(hog) > 0.0, "stage 2 farms hogs")
	for n in [g, bat, hog, mgr]:
		n.queue_free()



func test_random_reachable_point_skips_unreachable_islands() -> void:
	var region := NavigationRegion2D.new()
	var poly := NavigationPolygon.new()
	poly.agent_radius = 0.0
	var src := NavigationMeshSourceGeometryData2D.new()
	src.add_traversable_outline(PackedVector2Array([Vector2(0, 0), Vector2(1000, 0), Vector2(1000, 200), Vector2(0, 200)]))
	src.add_traversable_outline(PackedVector2Array([Vector2(2000, 0), Vector2(2100, 0), Vector2(2100, 100), Vector2(2000, 100)]))
	NavigationServer2D.bake_from_source_geometry_data(poly, src)
	region.navigation_polygon = poly
	add_child(region)
	await wait_physics_frames(6)  # polygons land one map sync after the region
	var w := region.get_world_2d()
	assert_true(GameUtils.usable_nav_map(w).is_valid(), "test map synced")
	for i in range(20):
		var p := GameUtils.random_reachable_point(w, Rect2(500, 0, 1700, 200), Vector2(10, 10), Vector2(-1, -1))
		assert_true(p.x >= 499.0 and p.x <= 1000.5, "only the reachable part of the zone: %s" % str(p))
	assert_eq(GameUtils.random_reachable_point(w, Rect2(1990, 0, 200, 100), Vector2(10, 10), Vector2(-1, -1)),
		Vector2(-1, -1), "a zone that only covers an island falls back")
	region.queue_free()
	await wait_physics_frames(6)
	assert_false(GameUtils.usable_nav_map(w).is_valid(), "map back to empty for the other tests")


func test_flee_slides_along_a_wall_instead_of_freezing() -> void:
	var region := await bake_nav_rect(Rect2(0, 0, 1000, 1000))
	var g := await spawn_frozen(GROUNT, Vector2(30, 30))
	var a := await spawn_frozen(VLAD, Vector2(230, 230))
	var b := await spawn_frozen(VLAD, Vector2(250, 200))
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.FARM)
	var dest: Vector2 = g._get_smart_idle_destination()
	assert_true(dest.distance_to(g.global_position) > 16.0, "cornered flee still moves (got %s)" % str(dest))
	for n in [g, a, b, region]:
		n.queue_free()
	await wait_physics_frames(6)


func test_gap_close_refuses_a_target_the_strategy_rejects() -> void:
	var g := await spawn_frozen(GROUNT, Vector2(0, 0))
	g.gain_xp(1000.0)
	g._update_strategy()
	assert_eq(g.strategy, MonsterBase.Strategy.AMBUSH)
	var h := await spawn_frozen(VLAD, Vector2(250, 0))
	var b := await spawn_frozen(VLAD, Vector2(300, 40))
	var c := await spawn_frozen(VLAD, Vector2(300, -40))
	g.target = h.get_node("Body")
	g.target_entity = h
	assert_true(g._score_target(h) < 0.0, "three heroes together: not an ambush target")
	assert_false(g._try_gap_close(), "no dash into a group the strategy avoids")
	for n in [g, h, b, c]:
		n.queue_free()
