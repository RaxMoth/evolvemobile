extends Node2D
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
## The monster also counts as an activation anchor, so a monster hiding away
## from the heroes finds live camps to farm (README "Hide & Farm").
@export var monster_activates_camps: bool = true

@export_group("Pooling")
## Dead / deactivated mobs are parked out of the tree and reused instead of
## instantiating a ~25-node scene per respawn (spawn hitches at camp edges).
@export var pool_enabled: bool = true
@export var pool_cap_per_scene: int = 48
## Fresh mobs per scene instantiated during load (after randomize_spawns in
## _ready), so a camp's first activation takes them from the pool instead of
## instantiating its scenes inside the 4 Hz activation tick. Never more than
## the eligible camps of that scene hold; 0 = off. Headless matches (seeds
## 1-3, both sides) peak at 6 live Bats and 3 live Hogs and never need more
## instances, so 9 covers that plus one more 3-mob camp for ~2-3 ms of load.
@export var pool_prewarm_per_scene: int = 9

@export_group("Stress Test")
## Multiplies every eligible area's population (1 = designed). Combine with
## enable_lazy_activation = false and min/max_active_spawns = 39 to profile
## the worst case (116 mobs at 1, 232 at 2). Leave at 1 for real play.
@export var stress_mob_multiplier: int = 1

var all_spawn_areas: Array[MobSpawnArea] = []
var active_spawn_areas: Array[MobSpawnArea] = []  # World-eligible (random subset).
var _check_timer: float = 0.0
var _pool: Dictionary = {}  # scene resource_path -> Array of parked MobBase (out of tree)
## scene resource_path -> Array of never-spawned MobBase from prewarm_pool().
## Kept apart from _pool so they never count toward pool_cap_per_scene:
## release_mob parks or frees exactly as it would without the prewarm.
var _prewarmed: Dictionary = {}

func _ready() -> void:
	if auto_activate_on_ready:
		randomize_spawns()
		prewarm_pool()

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
	# Heroes + pets (+ the monster), kept current by EntityRegistry (no tree walk).
	var anchors: Array[Node2D] = EntityRegistry.hero_side.duplicate()
	if monster_activates_camps:
		anchors.append_array(EntityRegistry.monsters)
	if anchors.is_empty() or active_spawn_areas.is_empty():
		return

	for spawn in active_spawn_areas:
		if not is_instance_valid(spawn):
			continue
		var closest_dist := INF
		var spawn_pos := spawn.global_position
		for anchor in anchors:
			if not is_instance_valid(anchor):
				continue
			closest_dist = minf(closest_dist, spawn_pos.distance_to(anchor.global_position))
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
	# Disable everything by default; _activate_random_spawns picks the winners
	# next. This runs after every area's _ready, so it also overrides any
	# population an area seeded from its own auto_spawn_on_ready.
	for spawn in all_spawn_areas:
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
	"""A parked instance of `scene` if one exists (the last released first,
	then a prewarmed one), else a fresh instantiate.
	The caller must reset_for_spawn() + add_child() + on_spawned()."""
	var key := scene.resource_path
	if pool_enabled and key != "":
		var mob := _take(_pool, key)
		if mob == null:
			mob = _take(_prewarmed, key)
		if mob:
			return mob
	return _instantiate_mob(scene, key)

func prewarm_pool() -> void:
	"""Instantiate up to pool_prewarm_per_scene mobs per scene of the eligible
	camps (capped at their slots still waiting to spawn) and keep them out of
	the tree. instantiate() runs no game code (the mob scripts have no _init;
	_enter_tree, _ready and the auto-name come with add_child), so this moves
	the cost into load without touching the RNG."""
	if not pool_enabled or pool_prewarm_per_scene <= 0:
		return
	var slots: Dictionary = {}  # PackedScene -> mob slots still to spawn
	for spawn in active_spawn_areas:
		if spawn.mob_scene and spawn.virtual_count > 0:
			slots[spawn.mob_scene] = int(slots.get(spawn.mob_scene, 0)) + spawn.virtual_count
	for scene: PackedScene in slots:
		var key := scene.resource_path
		if key == "":
			continue
		var stash: Array = _prewarmed.get_or_add(key, [])
		var wanted := mini(pool_prewarm_per_scene, int(slots[scene]))
		while stash.size() < wanted:
			var mob := _instantiate_mob(scene, key)
			if mob == null:
				break
			stash.append(mob)

func _instantiate_mob(scene: PackedScene, key: String) -> MobBase:
	var mob := scene.instantiate() as MobBase
	if mob:
		mob.pool_key = key if (pool_enabled and key != "") else ""
		mob.spawn_manager = self
	return mob

func _take(buckets: Dictionary, key: String) -> MobBase:
	"""Pop the newest live instance of `key` from `buckets` (LIFO), or null."""
	if not buckets.has(key):
		return null
	var bucket: Array = buckets[key]
	while not bucket.is_empty():
		var parked: MobBase = bucket.pop_back()
		if is_instance_valid(parked):
			return parked
	return null

func release_mob(mob: MobBase) -> void:
	"""Park a dead or deactivated mob: scrub its per-life state, remove it from
	the tree (which unregisters it everywhere via _exit_tree) and keep it for
	the next acquire_mob(). Over the cap it is freed instead."""
	if not is_instance_valid(mob) or mob.is_parked:
		return
	# A manager on its way out (the match ends in the same frame a mob dies:
	# the deferred release lands after _exit_tree emptied the pool) frees
	# instead of parking, or the mob would leak out of the tree.
	if not pool_enabled or mob.pool_key == "" or not is_inside_tree() or is_queued_for_deletion():
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
	"""Mobs waiting out of the tree: parked and prewarmed."""
	var n := 0
	for buckets: Dictionary in [_pool, _prewarmed]:
		for bucket in buckets.values():
			n += (bucket as Array).size()
	return n

func _exit_tree() -> void:
	_free_pooled()

## Parked and prewarmed mobs have no parent: they go together with the manager
## (match end / scene change), when it leaves the tree and again when it is
## deleted (a release that landed in between), or they would leak.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_free_pooled()

func _free_pooled() -> void:
	for buckets: Dictionary in [_pool, _prewarmed]:
		for bucket in buckets.values():
			for m in bucket:
				if is_instance_valid(m):
					m.queue_free()
		buckets.clear()

# ============================================
# Public API
# ============================================

func get_active_spawns() -> Array[MobSpawnArea]:
	return active_spawn_areas

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and event.shift_pressed:
			Globals.debug_log("Re-randomizing spawns...")
			randomize_spawns()
