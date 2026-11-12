@tool
extends Area2D
class_name MobSpawnArea

## MobSpawnArea — lazy/virtual spawn region with visual zones.
##
## Zones (all visible in the scene tree as children):
##   • CollisionShape2D — the wander zone (mobs spawn and wander here).
##                        This is the actual physics shape.
##   • LeashZone        — beyond this, mobs are forced back to spawn.
##   • ActivationZone   — heroes within this distance instantiate the mobs.
##   • DeactivationZone — heroes outside this distance despawn the mobs.
##                        Must be larger than ActivationZone (hysteresis).
##
## Editing model:
##   • The three radii are @export properties on this node. Edit them in
##     the inspector — every BatArea instance can override them individually
##     for per-spawn tuning (small camp vs big arena vs boss room, etc.).
##   • Each radius automatically pushes to its matching child SpawnZone
##     for visualization. Designers see the colored rings in the editor;
##     the parent inspector remains the single editing surface.
##   • Backward compat: legacy code that reads `area.leash_distance` etc.
##     still works — these are real exported variables.
##
## Lazy spawning unchanged: the area holds a virtual_count when no hero is
## near, instantiates real nodes on activate(), despawns on deactivate().

signal mob_left_area(mob: MobBase)
signal mob_respawned(mob: MobBase)
signal area_activated
signal area_deactivated

@export_group("Spawn Settings")
@export var mob_scene: PackedScene
@export var mob_count: int = 1
@export var respawn_time: float = 10.0
## Seeds virtual_count with mob_count in _ready. Under a SpawnManager that
## randomizes on ready (the World), the manager owns eligibility: its
## randomize_spawns() resets every area after this _ready and re-seeds only
## the camps it picks, so this flag has no effect there. It is honoured for
## standalone areas and for areas added to a manager that does not randomize.
@export var auto_spawn_on_ready: bool = true

@export_group("Lazy Spawning")
## If true, mobs are only instantiated when a hero is within the
## ActivationZone. When no hero is near, the area just tracks how many
## SHOULD exist.
@export var lazy_spawning: bool = true

@export_group("Area Behavior")
@export var enforce_boundaries: bool = true
@export var return_to_center_on_reset: bool = true

@export_group("Zone Radii")
## Per-instance configurable radii. These are the source of truth — when set,
## they automatically push to the matching child SpawnZone for visualization.
## Any BatArea instance can override any of these in the inspector to be
## individually tuned (small camp, big arena, etc.) without expanding the
## scene tree.
@export var leash_distance: float = 500.0:
	set(value):
		leash_distance = maxf(0.0, value)
		_sync_zone(&"LeashZone", leash_distance)
		update_configuration_warnings()

@export var activation_radius: float = 900.0:
	set(value):
		activation_radius = maxf(0.0, value)
		_sync_zone(&"ActivationZone", activation_radius)
		update_configuration_warnings()

@export var deactivation_radius: float = 1200.0:
	set(value):
		deactivation_radius = maxf(0.0, value)
		_sync_zone(&"DeactivationZone", deactivation_radius)
		update_configuration_warnings()

@export_group("Visual Debug")
## When true, runtime _draw() outlines the wander shape (the zones
## themselves still render via SpawnZone's own visible_in_game flag).
@export var show_debug_area: bool = false:
	set(value):
		show_debug_area = value
		queue_redraw()
@export var debug_color: Color = Color(1, 0, 0, 0.2):
	set(value):
		debug_color = value
		queue_redraw()

# ============================================
# State
# ============================================
var spawned_mobs: Array[MobBase] = []
var area_center: Vector2
var area_radius: float = 200.0  ## Wander radius (read from CollisionShape2D in _ready)

# Lazy state
var virtual_count: int = 0
var is_active: bool = false
var _pending_respawns: int = 0
## Bumped by deactivate()/reset_population(). A respawn coroutine captures
## the epoch before it awaits and bails if it changed, so respawns never
## leak across a deactivation or a Shift+R re-randomize.
var _epoch: int = 0
## mob -> bound Callable connected ONE_SHOT to its `died` signal (not
## tree_exiting: pooled mobs leave the tree on every release). deactivate()
## detaches the hook before releasing so a deactivation never counts as a
## death (the old deferred-free version inflated virtual_count by one per mob).
var _death_hooks: Dictionary = {}


func _ready() -> void:
	# Push current export radii to the visual zone children. We do this in
	# both editor and runtime contexts so designers see the right rings the
	# moment they open a scene, and the prefab default radii get overridden
	# correctly by per-instance values.
	_sync_zone(&"LeashZone", leash_distance)
	_sync_zone(&"ActivationZone", activation_radius)
	_sync_zone(&"DeactivationZone", deactivation_radius)

	# In the editor we only want the visualization side-effects; bail before
	# any runtime spawn / signal logic kicks in.
	if Engine.is_editor_hint():
		queue_redraw()
		return

	area_center = global_position

	# Read wander radius from the actual physics shape.
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		if collision.shape is CircleShape2D:
			area_radius = (collision.shape as CircleShape2D).radius
		elif collision.shape is RectangleShape2D:
			area_radius = (collision.shape as RectangleShape2D).size.length() / 2.0

	body_exited.connect(_on_body_exited)
	area_exited.connect(_on_area_exited)

	if mob_scene and auto_spawn_on_ready:
		# Seed the virtual count; SpawnManager will activate when a hero is near.
		virtual_count = mob_count
		if not lazy_spawning:
			activate()

	if show_debug_area:
		queue_redraw()


func _draw() -> void:
	# In-game wander outline (only if show_debug_area is on). The three
	# distance zones draw themselves (SpawnZone._draw).
	if not show_debug_area and not Engine.is_editor_hint():
		return
	if area_radius <= 0.0 and Engine.is_editor_hint():
		# Editor: try to read radius from the collision shape so the wander
		# circle is visible even before _ready() runs.
		var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision and collision.shape is CircleShape2D:
			area_radius = (collision.shape as CircleShape2D).radius
	if area_radius > 0.0:
		draw_circle(Vector2.ZERO, area_radius, debug_color)
		draw_arc(Vector2.ZERO, area_radius, 0, TAU, 32, Color.RED, 2.0)


func _get_zone(zone_name: StringName) -> SpawnZone:
	## Tool-safe child lookup. @onready vars don't initialize in the editor.
	return get_node_or_null(NodePath(String(zone_name))) as SpawnZone


func _sync_zone(zone_name: StringName, radius: float) -> void:
	## Push the @export radius onto the matching child SpawnZone so the
	## visualization stays in lock-step with whatever the inspector has.
	## Setters call this whenever a radius changes; _ready() also calls it
	## once on load so instance overrides take effect.
	var z := _get_zone(zone_name)
	if z:
		z.radius = radius


# ============================================
# Lazy Activation API (called by SpawnManager)
# ============================================

func update_activation(closest_hero_distance: float) -> void:
	if not lazy_spawning:
		return
	if is_active:
		if closest_hero_distance > deactivation_radius:
			deactivate()
	else:
		if closest_hero_distance <= activation_radius:
			activate()


func activate() -> void:
	if is_active or not mob_scene:
		return
	is_active = true

	virtual_count += _pending_respawns
	_pending_respawns = 0

	var to_spawn := virtual_count
	virtual_count = 0
	for i in range(to_spawn):
		spawn_single_mob()
	area_activated.emit()


func deactivate() -> void:
	if not is_active:
		return
	is_active = false
	_epoch += 1

	# Take the list first: parking a mob removes its Body from the tree, which
	# fires our area_exited synchronously — the leash must not see it any more.
	var to_release: Array[MobBase] = spawned_mobs.duplicate()
	spawned_mobs.clear()
	virtual_count = to_release.size()
	for mob in to_release:
		if is_instance_valid(mob):
			_detach_death_hook(mob)
			_release(mob)
	area_deactivated.emit()


func reset_population() -> void:
	## SpawnManager.randomize_spawns: drop real mobs, forget pending respawns
	## and invalidate any respawn coroutine still waiting on its timer.
	deactivate()
	_epoch += 1
	virtual_count = 0
	_pending_respawns = 0


func _detach_death_hook(mob: MobBase) -> void:
	if not _death_hooks.has(mob):
		return
	var hook: Callable = _death_hooks[mob]
	_death_hooks.erase(mob)
	if mob.died.is_connected(hook):
		mob.died.disconnect(hook)


func _release(mob: MobBase) -> void:
	var mgr := get_parent() as SpawnManager
	if mgr:
		mgr.release_mob(mob)
	else:
		mob.queue_free()


# ============================================
# Spawning
# ============================================

func spawn_single_mob() -> MobBase:
	var mob := _acquire_mob()
	if not mob:
		push_error("MobSpawnArea: Scene is not a MobBase!")
		return null

	var spawn_pos := _get_random_position_in_area()

	# Per-life state (spawn area, leash, position) — valid before the mob is
	# in the tree; also pre-seeds the LOCAL position so a synchronous _ready
	# never sees (0, 0).
	mob.reset_for_spawn(self, spawn_pos, leash_distance)
	spawned_mobs.append(mob)
	var death_hook := _on_mob_died.bind(mob)
	_death_hooks[mob] = death_hook
	mob.died.connect(death_hook, CONNECT_ONE_SHOT)

	var parent_node := get_parent()
	if not parent_node:
		return null

	# Hot path: parent is fully set up. Attach synchronously.
	if parent_node.is_node_ready():
		parent_node.add_child(mob)
		mob.on_spawned(spawn_pos)
		return mob

	# Parent is busy (scene-load cascade) — defer the attach.
	_attach_mob_deferred.call_deferred(mob, spawn_pos)
	return mob


func _acquire_mob() -> MobBase:
	## Pooled instance from the SpawnManager when we are parented to one,
	## else a fresh instantiate (world_test / areas placed elsewhere).
	var mgr := get_parent() as SpawnManager
	if mgr:
		return mgr.acquire_mob(mob_scene)
	return mob_scene.instantiate() as MobBase


func _attach_mob_deferred(mob: MobBase, pos: Vector2) -> void:
	# The area may have been reset/deactivated before this deferred call ran.
	if not is_instance_valid(mob) or mob.is_parked or not spawned_mobs.has(mob):
		return
	var parent_node := get_parent()
	if not is_instance_valid(parent_node):
		mob.queue_free()
		return
	parent_node.add_child(mob)
	mob.on_spawned(pos)


func _get_random_position_in_area() -> Vector2:
	var angle := randf() * TAU
	var distance := randf() * area_radius * 0.8
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
	var mob := node as MobBase
	if mob.is_parked or not spawned_mobs.has(mob):
		return
	if enforce_boundaries:
		_check_leash_distance(mob)
	mob_left_area.emit(mob)


func _check_leash_distance(mob: MobBase) -> void:
	var distance := mob.global_position.distance_to(area_center)
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
	mob.clear_target()
	mob.is_in_combat = false
	if mob.state_chart:
		mob.state_chart.send_event(CombatEvents.ENEMY_EXITED)
	mob.current_health = mob.max_health
	mob.set_hp_display(mob.max_health, mob.max_health)


# ============================================
# Respawning
# ============================================

func _on_mob_died(mob: MobBase) -> void:
	spawned_mobs.erase(mob)
	_death_hooks.erase(mob)

	if respawn_time <= 0.0:
		return

	# Carry the dead slot as a pending respawn: total_mob_count() stays flat
	# while the timer runs, and a deactivate() during the wait folds it back
	# into virtual_count on the next activate().
	_pending_respawns += 1
	var epoch := _epoch
	# Pausable (process_always false): the pause menu and the result screen
	# hold the respawn with the match clock (it runs in game time).
	await get_tree().create_timer(respawn_time, false).timeout
	if epoch != _epoch or not is_inside_tree():
		return
	_pending_respawns -= 1

	if is_active:
		var new_mob := spawn_single_mob()
		if new_mob:
			mob_respawned.emit(new_mob)
	else:
		virtual_count += 1


# ============================================
# Helpers
# ============================================

func is_position_in_area(pos: Vector2) -> bool:
	return area_center.distance_to(pos) <= area_radius


func get_random_roam_position() -> Vector2:
	return _get_random_position_in_area()


func clamp_position_to_area(pos: Vector2) -> Vector2:
	var to_pos := pos - area_center
	if to_pos.length() > area_radius:
		to_pos = to_pos.normalized() * area_radius
	return area_center + to_pos


func total_mob_count() -> int:
	return spawned_mobs.size() + virtual_count + _pending_respawns


# ============================================
# Editor convenience: warn if zone hierarchy doesn't make sense
# ============================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	# Visual zone children are nice-to-have but not strictly required —
	# the radii are owned by the parent's exports.
	if not get_node_or_null("LeashZone"):
		warnings.append("Missing child 'LeashZone' (SpawnZone). The leash radius still works, but you won't see it in the editor.")
	if not get_node_or_null("ActivationZone"):
		warnings.append("Missing child 'ActivationZone' (SpawnZone). Activation still works, but no visual indicator.")
	if not get_node_or_null("DeactivationZone"):
		warnings.append("Missing child 'DeactivationZone' (SpawnZone). Deactivation still works, but no visual indicator.")
	# Logical-ordering checks (read from @export values, not zone state).
	if deactivation_radius <= activation_radius:
		warnings.append("deactivation_radius should be larger than activation_radius (hysteresis prevents thrashing on the boundary).")
	if activation_radius < leash_distance:
		warnings.append("activation_radius is smaller than leash_distance — mobs may get leashed before heroes can engage them.")
	return warnings
