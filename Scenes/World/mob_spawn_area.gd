# ============================================
# MOB SPAWN AREA
# Save as: res://characters/base/mob_spawn_area.gd
#
# Defines a region where MOBS (simple enemies) can roam
# For bosses/monsters, place them manually in the scene
# ============================================
extends Area2D
class_name MobSpawnArea

signal mob_left_area(mob: MobBase)
signal mob_respawned(mob: MobBase)

@export_group("Spawn Settings")
@export var mob_scene: PackedScene  # The mob to spawn (goblin, skeleton, etc.)
@export var mob_count: int = 1  # How many mobs in this area
@export var respawn_time: float = 10.0  # Seconds until respawn
@export var auto_spawn_on_ready: bool = true

@export_group("Area Behavior")
@export var enforce_boundaries: bool = true  # Mobs can't leave
@export var leash_distance: float = 500.0  # Max distance from area center
@export var return_to_center_on_reset: bool = true

@export_group("Visual Debug")
@export var show_debug_area: bool = false
@export var debug_color: Color = Color(1, 0, 0, 0.2)

var spawned_mobs: Array[MobBase] = []
var area_center: Vector2
var area_radius: float = 200.0

func _ready() -> void:
	print("=== MobSpawnArea._ready() called ===")
	print("Node name: ", name)
	print("Position: ", global_position)
	
	area_center = global_position
	
	# Get radius from CollisionShape2D
	if has_node("CollisionShape2D"):
		var collision = $CollisionShape2D
		print("Found CollisionShape2D")
		if collision.shape is CircleShape2D:
			area_radius = collision.shape.radius
			print("Circle radius: ", area_radius)
		elif collision.shape is RectangleShape2D:
			area_radius = collision.shape.size.length() / 2.0
			print("Rectangle size: ", collision.shape.size)
	else:
		push_warning("MobSpawnArea: No CollisionShape2D found! Add one as a child.")
	
	# Connect signals
	body_exited.connect(_on_body_exited)
	area_exited.connect(_on_area_exited)
	
	# Check settings
	print("Mob Scene: ", mob_scene)
	print("Mob Count: ", mob_count)
	print("Auto Spawn: ", auto_spawn_on_ready)
	
	# Spawn mobs AFTER ready is complete
	if auto_spawn_on_ready:
		print("Auto-spawning mobs (deferred)...")
		spawn_mobs.call_deferred()
	else:
		print("Auto-spawn disabled")
	
	# Debug visualization
	if show_debug_area:
		queue_redraw()
	
	print("=== MobSpawnArea._ready() complete ===\n")

func _draw() -> void:
	if show_debug_area:
		draw_circle(Vector2.ZERO, area_radius, debug_color)
		draw_arc(Vector2.ZERO, area_radius, 0, TAU, 32, Color.RED, 2.0)

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
	
	# Add to scene
	get_parent().add_child(mob)
	
	# Random position within area
	var spawn_pos = _get_random_position_in_area()
	mob.global_position = spawn_pos
	
	# Register the spawn area with the mob
	mob.spawn_area = self
	mob.spawn_position = spawn_pos
	
	# Track mob
	spawned_mobs.append(mob)
	
	# Connect to mob death
	if mob.has_signal("tree_exiting"):
		mob.tree_exiting.connect(_on_mob_died.bind(mob))
	
	print("Spawned " + mob.name + " in spawn area")
	return mob

func _get_random_position_in_area() -> Vector2:
	# Random position within circle
	var angle = randf() * TAU
	var distance = randf() * area_radius * 0.8  # Keep away from edges
	return area_center + Vector2(cos(angle), sin(angle)) * distance

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
		# Teleport mob back to center or prevent leaving
		_handle_leash(mob)
	
	mob_left_area.emit(mob)

func _handle_leash(mob: MobBase) -> void:
	# Check distance from center
	var distance = mob.global_position.distance_to(area_center)
	
	if distance > leash_distance:
		# Reset mob to spawn position
		print(mob.name + " reached leash distance, returning to spawn")
		mob.global_position = mob.spawn_position
		
		# Reset mob state
		mob.target = null
		mob.target_entity = null
		if mob.state_chart:
			mob.state_chart.send_event("enemie_exited")
		
		# Heal to full
		mob.current_health = mob.max_health
		if mob.health_bar:
			mob.health_bar.value = mob.max_health

func _on_mob_died(mob: MobBase) -> void:
	spawned_mobs.erase(mob)
	
	# Respawn after delay
	if respawn_time > 0.0:
		await get_tree().create_timer(respawn_time).timeout
		var new_mob = spawn_single_mob()
		if new_mob:
			mob_respawned.emit(new_mob)

func is_position_in_area(pos: Vector2) -> bool:
	return area_center.distance_to(pos) <= area_radius

func get_random_roam_position() -> Vector2:
	return _get_random_position_in_area()

# Helper for mobs to check if they can wander to a position
func clamp_position_to_area(pos: Vector2) -> Vector2:
	var to_pos = pos - area_center
	if to_pos.length() > area_radius:
		to_pos = to_pos.normalized() * area_radius
	return area_center + to_pos
