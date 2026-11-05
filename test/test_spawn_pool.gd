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
	vlad = await spawn_entity("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn", Vector2(4000, 4000))
	area.activate()
	await wait_physics_frames(4)
	EventBus.deal_damage(vlad, area.spawned_mobs[0], 9999.0)
	await wait_frames(2)
	area.deactivate()
	area.activate()
	await wait_seconds(0.5)
	assert_eq(area.spawned_mobs.size(), area.mob_count, "dead slot carried through deactivate/activate exactly once")
	assert_eq(area._pending_respawns, 0)
	assert_eq(area.total_mob_count(), area.mob_count)


func test_mob_combat_defaults_come_from_the_base_scene() -> void:
	# strafe_speed / alert_allies_radius live on the mobs_base_class.tscn root;
	# _ready only derives the melee spacing from base_attack_range (40).
	var x := 4000.0
	for path in ["res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn", "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"]:
		var m := await spawn_frozen(path, Vector2(x, 4000))
		x += 3000.0
		var file: String = path.get_file()
		assert_near(m.strafe_speed, 40.0, 0.001, file + " strafe_speed")
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
