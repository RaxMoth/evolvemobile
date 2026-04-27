extends Area2D
class_name MobSpawnArea

## MobSpawnArea — lazy/virtual spawn region.
##
## Default behavior is now LAZY: this area holds an integer "virtual_count"
## (how many mobs should exist here). It only instantiates real mob nodes
## when a hero gets within `activation_radius`. When all heroes leave
## `deactivation_radius`, real mobs are converted back to virtual count
## (and freed). On-death respawn just increments virtual_count when the
## area is inactive — no node is created until a hero comes back.
##
## The SpawnManager (`spawns.gd`) drives activation by polling hero
## proximity at a low frequency (e.g. 4 Hz), so each spawn area no
## longer runs its own _process loop.

signal mob_left_area(mob: MobBase)
signal mob_respawned(mob: MobBase)
signal area_activated
signal area_deactivated

@export_group("Spawn Settings")
@export var mob_scene: PackedScene
@export var mob_count: int = 1
@export var respawn_time: float = 10.0
@export var auto_spawn_on_ready: bool = true

@export_group("Lazy Spawning")
## If true, mobs are only instantiated when a hero is within activation_radius.
## When no hero is near, the area just tracks how many SHOULD exist.
@export var lazy_spawning: bool = true
## Hero distance at which the area instantiates its mobs.
@export var activation_radius: float = 900.0
## Hero distance at which the area despawns and goes virtual again.
## Must be larger than activation_radius (hysteresis to prevent thrashing).
@export var deactivation_radius: float = 1200.0

@export_group("Area Behavior")
@export var enforce_boundaries: bool = true
@export var leash_distance: float = 500.0
@export var return_to_center_on_reset: bool = true

@export_group("Visual Debug")
@export var show_debug_area: bool = false
@export var debug_color: Color = Color(1, 0, 0, 0.2)

var spawned_mobs: Array[MobBase] = []
var area_center: Vector2
var area_radius: float = 200.0

# Lazy state
var virtual_count: int = 0   ## How many mobs SHOULD exist (sum of: real spawned + queued respawns).
var is_active: bool = false  ## True when real nodes are alive in the scene.
var _pending_respawns: int = 0  ## Pending respawns scheduled while inactive.
var _deactivating: bool = false  ## True during a deactivate() call so _on_mob_died can ignore the cascade of tree_exiting signals.

func _ready() -> void:
	area_center = global_position

	if has_node("CollisionShape2D"):
		var collision = $CollisionShape2D
		if collision.shape is CircleShape2D:
			area_radius = collision.shape.radius
		elif collision.shape is RectangleShape2D:
			area_radius = collision.shape.size.length() / 2.0

	body_exited.connect(_on_body_exited)
	area_exited.connect(_on_area_exited)

	if mob_scene and auto_spawn_on_ready:
		# Seed the virtual count with the configured mob count. Real nodes
		# are only instantiated when activate() is called by SpawnManager.
		virtual_count = mob_count
		if not lazy_spawning:
			# Backward-compat: spawn immediately.
			activate()

	if show_debug_area:
		queue_redraw()

func _draw() -> void:
	if show_debug_area:
		draw_circle(Vector2.ZERO, area_radius, debug_color)
		draw_arc(Vector2.ZERO, area_radius, 0, TAU, 32, Color.RED, 2.0)
		draw_arc(Vector2.ZERO, leash_distance, 0, TAU, 64, Color.ORANGE, 1.0, true)

# ============================================
# Lazy Activation API (called by SpawnManager)
# ============================================

## Called by SpawnManager with the distance to the closest hero.
## Activates / deactivates this area with hysteresis.
func update_activation(closest_hero_distance: float) -> void:
	if not lazy_spawning:
		return  # Behaves like the old always-on system.

	if is_active:
		if closest_hero_distance > deactivation_radius:
			deactivate()
	else:
		if closest_hero_distance <= activation_radius:
			activate()

## Spawn the virtual mobs as real nodes.
func activate() -> void:
	if is_active or not mob_scene:
		return
	is_active = true

	# Resolve any respawns queued while we were inactive.
	virtual_count += _pending_respawns
	_pending_respawns = 0

	var to_spawn := virtual_count
	virtual_count = 0
	for i in range(to_spawn):
		spawn_single_mob()
	area_activated.emit()

## Despawn all real mobs back into a virtual count.
func deactivate() -> void:
	if not is_active:
		return
	is_active = false
	_deactivating = true

	# Count surviving mobs as virtual BEFORE freeing them. The cascade of
	# tree_exiting signals will fire _on_mob_died for each, but the flag
	# tells the handler to skip the respawn-and-virtual-bump logic since
	# we've already accounted for them here.
	virtual_count = spawned_mobs.size()
	for mob in spawned_mobs:
		if is_instance_valid(mob):
			mob.queue_free()
	spawned_mobs.clear()

	# Reset the flag next frame, after queue_free has fired all signals.
	_clear_deactivating_flag.call_deferred()
	area_deactivated.emit()

func _clear_deactivating_flag() -> void:
	_deactivating = false

# ============================================
# Spawning (now only called when active)
# ============================================

func spawn_mobs() -> void:
	## Public method retained for backward-compat / SpawnManager activation.
	if not mob_scene:
		push_error("MobSpawnArea: No mob scene assigned!")
		return
	for i in range(mob_count):
		spawn_single_mob()

func spawn_single_mob() -> MobBase:
	var mob = mob_scene.instantiate() as MobBase
	if not mob:
		push_error("MobSpawnArea: Scene is not a MobBase!")
		return null

	get_parent().add_child(mob)

	var spawn_pos = _get_random_position_in_area()
	mob.global_position = spawn_pos
	mob.spawn_area = self
	mob.spawn_position = spawn_pos
	mob.chase_distance = leash_distance

	spawned_mobs.append(mob)

	# Bind self so the handler can detect deactivation-vs-real-death.
	mob.tree_exiting.connect(_on_mob_died.bind(mob))
	return mob

func _get_random_position_in_area() -> Vector2:
	var angle = randf() * TAU
	var distance = randf() * area_radius * 0.8
	return area_center + Vector2(cos(angle), sin(angle)) * distance

# ============================================
# Leashing
# ============================================

func _on_body_exited(body: Node2D) -> void:
	_check_mob_exit(body)

func _on_area_exited(area: Area2D) -> void:
	_check_mob_exit(area.get_parent())

func _check_mob_exit(node: Node) -> void:
	if not node is MobBase:
		return
	var mob = node as MobBase
	if not spawned_mobs.has(mob):
		return
	if enforce_boundaries:
		_check_leash_distance(mob)
	mob_left_area.emit(mob)

func _check_leash_distance(mob: MobBase) -> void:
	var distance = mob.global_position.distance_to(area_center)
	if distance > leash_distance:
		_handle_hard_leash(mob)

func _handle_hard_leash(mob: MobBase) -> void:
	if not mob.is_in_combat:
		_reset_mob_to_spawn(mob)

func _reset_mob_to_spawn(mob: MobBase) -> void:
	if return_to_center_on_reset:
		mob.global_position = area_center
	else:
		mob.global_position = mob.spawn_position
	mob.target = null
	mob.target_entity = null
	mob.is_in_combat = false
	if mob.state_chart:
		mob.state_chart.send_event(CombatEvents.ENEMY_EXITED)
	mob.current_health = mob.max_health
	if mob.health_bar:
		mob.health_bar.value = mob.max_health

# ============================================
# Respawning
# ============================================

func _on_mob_died(mob: MobBase) -> void:
	spawned_mobs.erase(mob)

	# Cascade from deactivate() — the despawned mobs are already counted
	# in virtual_count, so don't schedule a respawn or double-count.
	if _deactivating:
		return

	if respawn_time <= 0.0:
		return

	# If the area is currently active, schedule a real respawn.
	# If inactive (mob died of natural causes while we already despawned),
	# just bump virtual_count so the next activation restores them.
	await get_tree().create_timer(respawn_time).timeout

	if is_active:
		var new_mob = spawn_single_mob()
		if new_mob:
			mob_respawned.emit(new_mob)
	else:
		virtual_count += 1

# ============================================
# Helper Methods
# ============================================

func is_position_in_area(pos: Vector2) -> bool:
	return area_center.distance_to(pos) <= area_radius

func get_random_roam_position() -> Vector2:
	return _get_random_position_in_area()

func clamp_position_to_area(pos: Vector2) -> Vector2:
	var to_pos = pos - area_center
	if to_pos.length() > area_radius:
		to_pos = to_pos.normalized() * area_radius
	return area_center + to_pos

## Total mobs accounted for (real nodes + virtual). Useful for HUD/analytics.
func total_mob_count() -> int:
	return spawned_mobs.size() + virtual_count + _pending_respawns
