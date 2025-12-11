extends Area2D
class_name MobSpawnArea

signal mob_left_area(mob: MobBase)
signal mob_respawned(mob: MobBase)

@export_group("Spawn Settings")
@export var mob_scene: PackedScene
@export var mob_count: int = 1
@export var respawn_time: float = 10.0
@export var auto_spawn_on_ready: bool = true

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
	
	if auto_spawn_on_ready and mob_scene:
		spawn_mobs.call_deferred()
	
	if show_debug_area:
		queue_redraw()

func _draw() -> void:
	if show_debug_area:
		# Draw spawn area (wander radius)
		draw_circle(Vector2.ZERO, area_radius, debug_color)
		draw_arc(Vector2.ZERO, area_radius, 0, TAU, 32, Color.RED, 2.0)
		
		# Draw leash distance (chase radius)
		draw_arc(Vector2.ZERO, leash_distance, 0, TAU, 64, Color.ORANGE, 1.0, true)

func spawn_mobs() -> void:
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
	
	# Set mob's chase distance to match leash distance
	mob.chase_distance = leash_distance
	
	spawned_mobs.append(mob)
	
	if mob.has_signal("tree_exiting"):
		mob.tree_exiting.connect(_on_mob_died.bind(mob))
	
	return mob

func _get_random_position_in_area() -> Vector2:
	var angle = randf() * TAU
	var distance = randf() * area_radius * 0.8
	return area_center + Vector2(cos(angle), sin(angle)) * distance

# ============================================
# FIXED: Smarter Leashing - Check mob's is_in_combat flag
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
	
	# Check if mob is too far (leash distance)
	if enforce_boundaries:
		_check_leash_distance(mob)
	
	mob_left_area.emit(mob)

func _check_leash_distance(mob: MobBase) -> void:
	var distance = mob.global_position.distance_to(area_center)
	
	# Only hard leash if beyond leash distance
	if distance > leash_distance:
		_handle_hard_leash(mob)

func _handle_hard_leash(mob: MobBase) -> void:
	# Check mob's is_in_combat flag (set by mob itself in state enter/exit)
	if not mob.is_in_combat:
		# Not in combat, safe to leash immediately
		_reset_mob_to_spawn(mob)
		print(mob.name + " leashed (idle, out of bounds)")
	else:
		# In combat, let the mob's own chase distance handle it
		pass

func _reset_mob_to_spawn(mob: MobBase) -> void:
	if return_to_center_on_reset:
		mob.global_position = area_center
	else:
		mob.global_position = mob.spawn_position
	
	mob.target = null
	mob.target_entity = null
	mob.is_in_combat = false
	
	if mob.state_chart:
		mob.state_chart.send_event("enemie_exited")
	
	# Heal to full on leash
	mob.current_health = mob.max_health
	if mob.health_bar:
		mob.health_bar.value = mob.max_health

# ============================================
# Respawning
# ============================================

func _on_mob_died(mob: MobBase) -> void:
	spawned_mobs.erase(mob)
	
	if respawn_time > 0.0:
		await get_tree().create_timer(respawn_time).timeout
		var new_mob = spawn_single_mob()
		if new_mob:
			mob_respawned.emit(new_mob)

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
