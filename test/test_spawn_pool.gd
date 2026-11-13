extends TestCase

## MobSpawnArea accounting + SpawnManager pooling (P0d / P5b regressions).

var mgr: SpawnManager
var area: MobSpawnArea
var vlad: Node2D


func before_each() -> void:
	mgr = make_spawn_manager(3, 0.2) as SpawnManager
	area = mgr.get_child(0) as MobSpawnArea


func after_each() -> void:
	if is_instance_valid(vlad):
		vlad.queue_free()
	mgr.queue_free()


func _ids(list: Array) -> Array:
	var out: Array = []
	for m in list:
		out.append(m.get_instance_id())
	out.sort()
	return out


## A second Bat camp under the same manager, set up like make_spawn_manager's.
func _add_area(pos: Vector2) -> MobSpawnArea:
	var extra := (load("res://Scenes/World/MobSpawnArea/MobSpawnArea.tscn") as PackedScene).instantiate() as MobSpawnArea
	extra.mob_scene = area.mob_scene
	extra.mob_count = area.mob_count
	extra.auto_spawn_on_ready = false
	extra.respawn_time = area.respawn_time
	extra.position = pos
	mgr.add_child(extra)
	extra.virtual_count = extra.mob_count
	return extra


func _prewarmed_ids() -> Array:
	var all: Array = []
	for bucket in mgr._prewarmed.values():
		all.append_array(bucket)
	return _ids(all)


func test_prewarm_fills_the_pool_and_feeds_the_first_activation() -> void:
	assert_eq(mgr.get_pooled_count(), 0, "no prewarm without auto_activate_on_ready")
	mgr.active_spawn_areas.append(area)  # what randomize_spawns picks
	mgr.pool_prewarm_per_scene = 2
	mgr.prewarm_pool()
	assert_eq(mgr.get_pooled_count(), 2, "pool_prewarm_per_scene instances before any activation")
	mgr.pool_prewarm_per_scene = 10
	mgr.prewarm_pool()
	assert_eq(mgr.get_pooled_count(), 3, "topped up, but never past the camp's 3 slots")
	for m in mgr._prewarmed[area.mob_scene.resource_path]:
		assert_false(m.is_inside_tree(), "prewarmed mobs wait out of the tree")
		assert_false(m.is_parked)
		assert_eq(m.pool_key, area.mob_scene.resource_path)
		assert_eq(m.spawn_manager, mgr)
	var warm_ids := _prewarmed_ids()
	area.activate()
	await wait_physics_frames(4)
	assert_eq(_ids(area.spawned_mobs), warm_ids, "the first activation took the prewarmed instances")
	assert_eq(mgr.get_pooled_count(), 0)
	for m in area.spawned_mobs:
		assert_true(m.is_inside_tree() and m.is_alive())
		assert_eq(active_state_of(m), "Idle")


func test_prewarmed_mobs_do_not_count_toward_the_pool_cap() -> void:
	var other := _add_area(Vector2(3000, 0))
	mgr.active_spawn_areas.append_array([area, other])
	mgr.pool_cap_per_scene = 2
	mgr.pool_prewarm_per_scene = 6
	mgr.prewarm_pool()
	assert_eq(mgr.get_pooled_count(), 6)
	area.activate()
	await wait_physics_frames(4)
	assert_eq(mgr.get_pooled_count(), 3, "three prewarmed left for the other camp")
	var released_ids := _ids(area.spawned_mobs)
	area.deactivate()
	await wait_frames(1)
	var parked: Array = mgr._pool[area.mob_scene.resource_path]
	assert_eq(parked.size(), 2, "released mobs park up to the cap, as without a prewarm")
	assert_eq(mgr.get_pooled_count(), 5, "2 parked + 3 prewarmed")
	var parked_ids := _ids(parked)
	for id in parked_ids:
		assert_true(released_ids.has(id))
	other.activate()
	await wait_physics_frames(4)
	var used := _ids(other.spawned_mobs)
	for id in parked_ids:
		assert_true(used.has(id), "released mobs are reused before prewarmed ones")
	assert_eq(mgr.get_pooled_count(), 2, "one prewarmed instance taken")


func test_toggling_activation_keeps_population_and_reuses_instances() -> void:
	area.activate()
	await wait_physics_frames(4)
	assert_eq(area.spawned_mobs.size(), 3)
	assert_eq(area.total_mob_count(), 3)
	var first_ids := _ids(area.spawned_mobs)
	for i in 5:
		area.deactivate()
		await wait_frames(1)
		assert_eq(area.spawned_mobs.size(), 0)
		assert_eq(area.total_mob_count(), 3, "deactivate must not inflate the population")
		assert_eq(mgr.get_pooled_count(), 3, "released mobs are parked, not freed")
		assert_eq(EntityRegistry.mobs.size(), 0, "parked mobs left the registry")
		area.activate()
		await wait_frames(1)
		assert_eq(area.spawned_mobs.size(), 3)
		assert_eq(mgr.get_pooled_count(), 0)
	assert_eq(_ids(area.spawned_mobs), first_ids, "the same three nodes were reused")
	for m in area.spawned_mobs:
		assert_true(m.is_inside_tree() and m.is_alive())
		assert_eq(active_state_of(m), "Idle")
		assert_false(m.is_parked)


func test_dead_mob_respawns_from_the_pool_with_full_hp() -> void:
	vlad = await spawn_entity("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn", Vector2(4000, 4000))
	area.activate()
	await wait_physics_frames(4)
	var victim: MobBase = area.spawned_mobs[0]
	var victim_id := victim.get_instance_id()
	var life_before: int = victim.life_id
	EventBus.deal_damage(vlad, victim, 9999.0)
	assert_eq(active_state_of(victim), "Dead")
	await wait_frames(2)  # deferred release_mob
	assert_true(is_instance_valid(victim), "pooled mob is parked, not freed")
	assert_true(victim.is_parked)
	assert_false(victim.is_inside_tree())
	assert_eq(area.spawned_mobs.size(), 2)
	assert_eq(area.total_mob_count(), 3, "dead slot counted as a pending respawn")
	assert_eq(mgr.get_pooled_count(), 1)
	await wait_seconds(0.5)
	assert_eq(area.spawned_mobs.size(), 3, "respawned after respawn_time")
	assert_eq(area.total_mob_count(), 3)
	assert_true(_ids(area.spawned_mobs).has(victim_id), "the dead node itself was reused")
	assert_true(victim.is_inside_tree())
	assert_false(victim.is_parked)
	assert_true(victim.is_alive())
	assert_near(victim.get_health(), victim.get_max_health())
	assert_eq(active_state_of(victim), "Idle", "RESET drove the chart Dead -> Idle")
	assert_true(victim.life_id > life_before)
	assert_true(victim.target_entity == null and victim.target == null)


func test_reset_population_cancels_pending_respawn() -> void:
	vlad = await spawn_entity("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn", Vector2(4000, 4000))
	area.activate()
	await wait_physics_frames(4)
	EventBus.deal_damage(vlad, area.spawned_mobs[0], 9999.0)
	await wait_frames(2)
	area.reset_population()  # what Shift+R does for every camp
	assert_eq(area.total_mob_count(), 0)
	# Re-arm the camp the way SpawnManager._make_spawn_world_eligible does,
	# BEFORE the stale respawn timer fires.
	area.virtual_count = area.mob_count
	area.activate()
	await wait_frames(1)
	assert_eq(area.spawned_mobs.size(), area.mob_count)
	await wait_seconds(0.5)
	assert_eq(area.spawned_mobs.size(), area.mob_count, "the stale respawn coroutine must not add a mob (epoch changed)")
	assert_eq(area._pending_respawns, 0)
	assert_eq(area.total_mob_count(), area.mob_count)


func test_deactivate_activate_inside_the_respawn_window_keeps_population() -> void:
	# The dead slot waits out its respawn_time through a deactivate() and an
	# activate(): a revisit no longer refills the camp at once.
	vlad = await spawn_entity("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn", Vector2(4000, 4000))
	area.respawn_time = 0.5
	area.activate()
	await wait_physics_frames(4)
	EventBus.deal_damage(vlad, area.spawned_mobs[0], 9999.0)
	await wait_frames(2)
	area.deactivate()
	area.activate()
	assert_eq(area.spawned_mobs.size(), 2, "the two survivors come back, not the dead one")
	assert_eq(area._pending_respawns, 1, "the dead slot is still pending")
	assert_eq(area.total_mob_count(), area.mob_count)
	await wait_seconds(0.7)
	assert_eq(area.spawned_mobs.size(), area.mob_count, "dead slot respawned live, exactly once")
	assert_eq(area._pending_respawns, 0)
	assert_eq(area.total_mob_count(), area.mob_count)


func test_a_cleared_deactivated_camp_refills_virtually_on_time() -> void:
	# A camp cleared and left read as empty to the monster's camp choice until
	# someone walked past it again (the deactivation cancelled its respawns).
	vlad = await spawn_entity("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn", Vector2(4000, 4000))
	area.respawn_time = 0.5
	area.activate()
	await wait_physics_frames(4)
	for mob: MobBase in area.spawned_mobs.duplicate():
		EventBus.deal_damage(vlad, mob, 9999.0)
	await wait_frames(2)
	assert_eq(area.spawned_mobs.size(), 0, "cleared")
	area.deactivate()
	assert_eq(area.virtual_count, 0, "nothing to refill yet")
	await wait_seconds(0.7)
	assert_false(area.is_active, "nobody came back")
	assert_eq(area.virtual_count, area.mob_count, "refilled on its respawn_time, virtually")
	assert_eq(area._pending_respawns, 0)
	area.activate()
	assert_eq(area.spawned_mobs.size(), area.mob_count, "and spawned when someone comes")


func test_mob_combat_defaults_come_from_the_base_scene() -> void:
	# strafe_speed / alert_allies_radius live on the mobs_base_class.tscn root;
	# _ready only derives the melee spacing from base_attack_range (40).
	var x := 4000.0
	for path in ["res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn", "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"]:
		var m := await spawn_frozen(path, Vector2(x, 4000))
		x += 3000.0
		var file: String = path.get_file()
		assert_near(m.strafe_speed, 48.0, 0.001, file + " strafe_speed")
		assert_near(m.alert_allies_radius, 200.0, 0.001, file + " alert_allies_radius")
		assert_near(m.strafe_change_interval, 3.0, 0.001, file + " strafe_change_interval")
		assert_near(m.preferred_distance, 32.0, 0.001, file + " preferred_distance")
		assert_near(m.min_distance, 20.0, 0.001, file + " min_distance")
		assert_near(m.max_distance, 60.0, 0.001, file + " max_distance")
		m.queue_free()


func test_a_mob_scene_can_override_the_combat_defaults() -> void:
	# Values set before _ready (what a mob scene's root does) survive it.
	var m := (load("res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn") as PackedScene).instantiate() as Node2D
	m.strafe_speed = 55.0
	m.alert_allies_radius = 120.0
	m.position = Vector2(4000, 4000)
	add_child(m)
	await wait_physics_frames(4)
	await wait_frames(1)
	assert_near(m.strafe_speed, 55.0, 0.001, "scene strafe_speed kept")
	assert_near(m.alert_allies_radius, 120.0, 0.001, "scene alert_allies_radius kept")
	m.queue_free()


## monsters-2: a cleared camp respawns in match time. The pause menu's pause
## holds the respawn (a pausable timer), and it runs with the match speed:
## at the fast speed (x2.4) 1.2 game seconds pass in 30 frames.
func test_a_pause_holds_the_respawn_and_it_runs_in_game_time() -> void:
	vlad = await spawn_frozen("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn", Vector2(4000, 4000))
	area.respawn_time = 1.2
	area.activate()
	await wait_physics_frames(4)
	EventBus.deal_damage(vlad, area.spawned_mobs[0], 9999.0)
	await wait_frames(2)
	assert_eq(area.spawned_mobs.size(), 2, "one dead")
	get_tree().paused = true
	await wait_seconds(3.0)  # an always-processing timer: runs on the paused tree
	var live_while_paused := area.spawned_mobs.size()
	var pending_while_paused := area._pending_respawns
	get_tree().paused = false
	assert_eq(live_while_paused, 2, "3 s of pause: no respawn")
	assert_eq(pending_while_paused, 1, "it is still pending")
	await wait_seconds(1.4)
	assert_eq(area.spawned_mobs.size(), 3, "running again, it respawns")
	# The fast match speed: Engine.time_scale 2.4, a frame is 0.04 game seconds.
	var scaling_before := GameManager.speed_scaling
	var fast_before := GameManager.match_fast
	GameManager.speed_scaling = true
	GameManager._match_time = 0.0
	GameManager._match_active = true
	GameManager.match_ended_flag = false
	GameManager.set_match_fast(true, false)
	assert_near(Engine.time_scale, GameManager.MATCH_BASE_SPEED * GameManager.MATCH_FAST_FACTOR, 0.0001)
	EventBus.deal_damage(vlad, area.spawned_mobs[0], 9999.0)
	await wait_frames(24)
	var live_early := area.spawned_mobs.size()
	await wait_frames(12)
	var live_late := area.spawned_mobs.size()
	GameManager.abort_match()
	GameManager.match_ended_flag = true
	GameManager.speed_scaling = scaling_before
	GameManager.set_match_fast(fast_before, false)
	Engine.time_scale = 1.0
	assert_eq(live_early, 2, "24 frames are 0.96 game seconds: not yet")
	assert_eq(live_late, 3, "36 frames are 1.44 game seconds: respawned")
