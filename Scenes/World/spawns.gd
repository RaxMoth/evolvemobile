extends Node
class_name SpawnManager

## SpawnManager — drives lazy activation of MobSpawnAreas based on hero
## proximity. Polls at a low frequency (default 4 Hz) instead of per-frame.
##
## Behavior:
##  - At startup, randomly selects which areas are "world-active" (eligible
##    to spawn at all). Inactive areas stay completely dark — virtual_count = 0.
##  - On the activation tick, computes the distance from each eligible area
##    to its closest hero. If close enough, the area instantiates its mobs.
##    If too far (with hysteresis), it despawns them back to a virtual count.
##  - This means at any moment only the spawn areas NEAR heroes have real
##    nodes. With ~80 mobs configured world-wide, you might have 6–15 alive
##    at once, dramatically reducing per-frame CPU.

@export_group("Spawn Configuration")
@export var min_active_spawns: int = 26
@export var max_active_spawns: int = 30
@export var auto_activate_on_ready: bool = true

@export_group("Lazy Activation")
## How often to poll hero distances and (de)activate areas.
## 4 Hz (0.25s) is plenty — heroes don't move that fast.
@export var activation_check_interval: float = 0.25
## Set false to disable lazy activation entirely (debug).
@export var enable_lazy_activation: bool = true

@export_group("Pooling")
## Dead / deactivated mobs are parked out of the tree and reused instead of
## instantiating a ~25-node scene per respawn (spawn hitches at camp edges).
@export var pool_enabled: bool = true
@export var pool_cap_per_scene: int = 48

@export_group("Stress Test")
## Multiplies every eligible area's population (1 = designed). Combine with
## enable_lazy_activation = false and min/max_active_spawns = 39 to profile
## the worst case (116 mobs at 1, 232 at 2). Leave at 1 for real play.
@export var stress_mob_multiplier: int = 1

var all_spawn_areas: Array[MobSpawnArea] = []
var active_spawn_areas: Array[MobSpawnArea] = []  # World-eligible (random subset).
var _check_timer: float = 0.0
var _pool: Dictionary = {}  # scene resource_path -> Array of parked MobBase (out of tree)

func _ready() -> void:
	if auto_activate_on_ready:
		randomize_spawns()

func _process(delta: float) -> void:
	if not enable_lazy_activation:
		return

	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = activation_check_interval
		_update_activations()

# ============================================
# Lazy Activation Loop
# ============================================

func _update_activations() -> void:
	# Heroes + pets, kept current by EntityRegistry (no tree walk, no 1 s cache lag).
	var anchors := EntityRegistry.hero_side
	if anchors.is_empty() or active_spawn_areas.is_empty():
		return

	for spawn in active_spawn_areas:
		if not is_instance_valid(spawn):
			continue
		var closest_dist := INF
		var spawn_pos := spawn.global_position
		for hero in anchors:
			if not is_instance_valid(hero):
				continue
			# distance_squared_to is cheaper than distance_to; we square the
			# threshold inside the spawn area's check by using the precomputed
			# radii. To keep the API simple, use distance_to (it's just one sqrt).
			var d := spawn_pos.distance_to(hero.global_position)
			if d < closest_dist:
				closest_dist = d
		spawn.update_activation(closest_dist)

# ============================================
# Original Random Selection (unchanged surface)
# ============================================

func randomize_spawns() -> void:
	"""Randomly select and mark spawns as world-eligible. The mobs are not
	actually instantiated until a hero gets close enough."""
	_collect_all_spawns()
	_deactivate_all_spawns()
	_activate_random_spawns()

	Globals.debug_log("SpawnManager: ", active_spawn_areas.size(), " of ", all_spawn_areas.size(),
		" spawns world-eligible (lazy activation: ", enable_lazy_activation, ")")

func _collect_all_spawns() -> void:
	all_spawn_areas.clear()
	for child in get_children():
		if child is MobSpawnArea:
			all_spawn_areas.append(child)

func _deactivate_all_spawns() -> void:
	# Disable everything by default — including making sure no auto-spawn
	# fires. Lazy activation will pick winners next.
	for spawn in all_spawn_areas:
		spawn.auto_spawn_on_ready = false
		spawn.visible = false
		# Drop real mobs, forget pending respawns and invalidate any respawn
		# coroutine still waiting (randomize re-run / Shift+R).
		spawn.reset_population()

func _activate_random_spawns() -> void:
	active_spawn_areas.clear()
	var num_to_activate = randi_range(min_active_spawns, max_active_spawns)
	num_to_activate = mini(num_to_activate, all_spawn_areas.size())

	var shuffled = all_spawn_areas.duplicate()
	shuffled.shuffle()

	for i in range(num_to_activate):
		var spawn: MobSpawnArea = shuffled[i]
		_make_spawn_world_eligible(spawn)
		active_spawn_areas.append(spawn)

func _make_spawn_world_eligible(spawn: MobSpawnArea) -> void:
	"""Mark this spawn as eligible — gives it a virtual count, but does NOT
	instantiate real nodes until a hero comes near."""
	spawn.visible = true
	spawn.virtual_count = spawn.mob_count * maxi(1, stress_mob_multiplier)
	# Real spawning happens when update_activation() decides a hero is close.
	# If lazy activation is disabled (debug), spawn immediately.
	if not enable_lazy_activation:
		spawn.activate()

# ============================================
# Mob pool
# ============================================

func acquire_mob(scene: PackedScene) -> MobBase:
	"""A parked instance of `scene` if one exists, else a fresh instantiate.
	The caller must reset_for_spawn() + add_child() + on_spawned()."""
	var key := scene.resource_path
	if pool_enabled and key != "" and _pool.has(key):
		var bucket: Array = _pool[key]
		while not bucket.is_empty():
			var parked: MobBase = bucket.pop_back()
			if is_instance_valid(parked):
				return parked
	var mob := scene.instantiate() as MobBase
	if mob:
		mob.pool_key = key if (pool_enabled and key != "") else ""
		mob.spawn_manager = self
	return mob

func release_mob(mob: MobBase) -> void:
	"""Park a dead or deactivated mob: scrub its per-life state, remove it from
	the tree (which unregisters it everywhere via _exit_tree) and keep it for
	the next acquire_mob(). Over the cap it is freed instead."""
	if not is_instance_valid(mob) or mob.is_parked:
		return
	if not pool_enabled or mob.pool_key == "":
		mob.queue_free()
		return
	mob.prepare_for_pool()
	var parent_node := mob.get_parent()
	if parent_node:
		parent_node.remove_child(mob)
	var bucket: Array = _pool.get_or_add(mob.pool_key, [])
	if bucket.size() >= pool_cap_per_scene:
		mob.queue_free()
	else:
		bucket.append(mob)

func get_pooled_count() -> int:
	var n := 0
	for bucket in _pool.values():
		n += (bucket as Array).size()
	return n

func _exit_tree() -> void:
	# Parked mobs have no parent; free them together with the manager
	# (match end / scene change) or they would leak.
	for bucket in _pool.values():
		for m in bucket:
			if is_instance_valid(m):
				m.queue_free()
	_pool.clear()

# ============================================
# Public API
# ============================================

func get_active_spawns() -> Array[MobSpawnArea]:
	return active_spawn_areas

func get_total_spawns() -> int:
	return all_spawn_areas.size()

func get_active_count() -> int:
	return active_spawn_areas.size()

## Total mob population across all eligible areas (real + virtual).
func get_total_mob_population() -> int:
	var total := 0
	for spawn in active_spawn_areas:
		if is_instance_valid(spawn):
			total += spawn.total_mob_count()
	return total

## Currently instantiated (real nodes) — useful for HUD or perf metrics.
func get_live_mob_count() -> int:
	var total := 0
	for spawn in active_spawn_areas:
		if is_instance_valid(spawn):
			total += spawn.spawned_mobs.size()
	return total

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and event.shift_pressed:
			Globals.debug_log("Re-randomizing spawns...")
			randomize_spawns()
