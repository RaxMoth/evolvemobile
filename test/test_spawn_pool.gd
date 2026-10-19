extends TestCase

## MobSpawnArea accounting + SpawnManager pooling (P0d / P5b regressions).

const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const AREA := "res://Scenes/World/MobSpawnArea/MobSpawnArea.tscn"

var mgr: SpawnManager
var area: MobSpawnArea
var vlad: Node2D


func before_each() -> void:
	mgr = SpawnManager.new()
	mgr.auto_activate_on_ready = false
	mgr.enable_lazy_activation = false
	add_child(mgr)
	area = (load(AREA) as PackedScene).instantiate() as MobSpawnArea
	area.mob_scene = load(BAT)
	area.mob_count = 3
	area.auto_spawn_on_ready = false
	area.respawn_time = 0.2
	mgr.add_child(area)
	area.virtual_count = area.mob_count  # what SpawnManager._make_spawn_world_eligible does


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
