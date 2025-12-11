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
	
	get_parent().add_child(mob)
	
	var spawn_pos = _get_random_position_in_area()
	mob.global_position = spawn_pos
	mob.spawn_area = self
	mob.spawn_position = spawn_pos
	
	spawned_mobs.append(mob)
	
	if mob.has_signal("tree_exiting"):
		mob.tree_exiting.connect(_on_mob_died.bind(mob))
	
	return mob

func _get_random_position_in_area() -> Vector2:
	var angle = randf() * TAU
	var distance = randf() * area_radius * 0.8
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
		_handle_leash(mob)
	
	mob_left_area.emit(mob)

func _handle_leash(mob: MobBase) -> void:
	var distance = mob.global_position.distance_to(area_center)
	
	if distance > leash_distance:
		mob.global_position = mob.spawn_position
		mob.target = null
		mob.target_entity = null
		
		if mob.state_chart:
			mob.state_chart.send_event("enemie_exited")
		
		mob.current_health = mob.max_health
		if mob.health_bar:
			mob.health_bar.value = mob.max_health

func _on_mob_died(mob: MobBase) -> void:
	spawned_mobs.erase(mob)
	
	if respawn_time > 0.0:
		await get_tree().create_timer(respawn_time).timeout
		var new_mob = spawn_single_mob()
		if new_mob:
			mob_respawned.emit(new_mob)

func is_position_in_area(pos: Vector2) -> bool:
	return area_center.distance_to(pos) <= area_radius

func get_random_roam_position() -> Vector2:
	return _get_random_position_in_area()

func clamp_position_to_area(pos: Vector2) -> Vector2:
	var to_pos = pos - area_center
	if to_pos.length() > area_radius:
		to_pos = to_pos.normalized() * area_radius
	return area_center + to_pos
