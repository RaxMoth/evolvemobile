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

var all_spawn_areas: Array[MobSpawnArea] = []
var active_spawn_areas: Array[MobSpawnArea] = []  # World-eligible (random subset).
var _check_timer: float = 0.0
var _hero_cache: Array[Node2D] = []
var _hero_cache_timer: float = 0.0
const HERO_CACHE_INTERVAL: float = 1.0

func _ready() -> void:
	if auto_activate_on_ready:
		randomize_spawns()

func _process(delta: float) -> void:
	if not enable_lazy_activation:
		return

	# Refresh hero cache infrequently — get_nodes_in_group walks the tree.
	_hero_cache_timer -= delta
	if _hero_cache_timer <= 0.0:
		_hero_cache_timer = HERO_CACHE_INTERVAL
		_refresh_hero_cache()

	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = activation_check_interval
		_update_activations()

func _refresh_hero_cache() -> void:
	_hero_cache.clear()
	for h in get_tree().get_nodes_in_group("Hero"):
		if h is Node2D:
			_hero_cache.append(h)

# ============================================
# Lazy Activation Loop
# ============================================

func _update_activations() -> void:
	if _hero_cache.is_empty() or active_spawn_areas.is_empty():
		return

	for spawn in active_spawn_areas:
		if not is_instance_valid(spawn):
			continue
		var closest_dist := INF
		var spawn_pos := spawn.global_position
		for hero in _hero_cache:
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

	print("SpawnManager: ", active_spawn_areas.size(), " of ", all_spawn_areas.size(),
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
		spawn.virtual_count = 0
		# If it had real mobs (e.g. randomize re-run), drop them.
		spawn.deactivate()

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
	spawn.virtual_count = spawn.mob_count
	# Real spawning happens when update_activation() decides a hero is close.
	# If lazy activation is disabled (debug), spawn immediately.
	if not enable_lazy_activation:
		spawn.activate()

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
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and event.shift_pressed:
			print("Re-randomizing spawns...")
			randomize_spawns()
