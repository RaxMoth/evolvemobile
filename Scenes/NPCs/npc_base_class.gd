extends Node2D
class_name NPCBaseClass

@export var move_speed: float = 80.0
@export var approach_speed: float = 110.0
@export var attack_range: float = 32.0
@export var max_health: float = 10.0
@export var idle_retarget_time: float = 1.2
@export var idle_wander_radius: float = 160.0
@export var keep_distance: float = 24.0

@onready var collision_shape_2d: CollisionShape2D = $DetectionArea/CollisionShape2D
@onready var sprite: Node2D = $Sprite2D
@onready var state_chart: StateChart = %StateChart
@onready var navigation_agent_2d: NavigationAgent2D = %NavigationAgent2D
@onready var ability_system: AbilitySystem = %AbilitySystem

var _idle_timer := 0.0
var _idle_goal := Vector2.ZERO
var health: float
var target: Node2D = null
var target_entity: Node = null

func _ready() -> void:
	health = max_health
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var tilemap_layer := get_parent().get_node_or_null("Ground")
	if tilemap_layer and tilemap_layer.has_method("get_navigation_map"):
		var nav_map = tilemap_layer.get_navigation_map()
		if nav_map.is_valid():
			navigation_agent_2d.set_navigation_map(nav_map)
		else:
			push_warning("Navigation map is invalid")
	else:
		push_warning("Ground tilemap not found or has no navigation")
	
	navigation_agent_2d.path_desired_distance = 4.0
	navigation_agent_2d.target_desired_distance = 4.0
	navigation_agent_2d.avoidance_enabled = false

func is_alive() -> bool:
	return health > 0.0

func get_health() -> float:
	return health

func is_target_valid() -> bool:
	return is_instance_valid(target) and is_instance_valid(target_entity)

func distance_to_target() -> float:
	if not is_target_valid():
		return INF
	return global_position.distance_to(target.global_position)

func _steer_along_nav(speed: float, delta: float) -> void:
	if not is_instance_valid(navigation_agent_2d) or navigation_agent_2d.is_navigation_finished():
		return
	
	var next_pos := navigation_agent_2d.get_next_path_position()
	var dir := (next_pos - global_position).normalized()
	
	if dir.length() < 0.001:
		return
	
	position += dir * speed * delta
	sprite.rotation = dir.angle()

func move_toward_point(p: Vector2, speed: float, delta: float) -> void:
	var dir := (p - global_position).normalized()
	if dir.length() <= 0.001:
		return
	
	position += dir * speed * delta
	sprite.rotation = dir.angle()

func take_damage(amount: float) -> void:
	if not is_alive():
		return 

	health -= amount
	if health <= 0.0:
		health = 0.0
		state_chart.send_event("self_dead")
	else:
		print(amount, " damage taken")

func _on_detection_area_area_exited(area: Area2D) -> void:
	if target == area:
		target = null
		target_entity = null
		state_chart.send_event("enemie_exited")

func _on_detection_area_area_entered(area: Area2D) -> void:
	if area.get_owner() == self or area.get_parent() == self:
		return

	var root := area.get_owner()
	if root and root.is_in_group("Enemy"):
		target = area
		target_entity = area.get_parent()
		state_chart.send_event("enemie_entered")

func _on_approach_state_processing(delta: float) -> void:
	if distance_to_target() <= max(attack_range, keep_distance):
		state_chart.send_event("enemy_fight")
		return
	move_toward_point(target.global_position, approach_speed, delta)

func _on_approach_state_entered() -> void:
	if not is_target_valid():
		state_chart.send_event("enemie_exited")

func _on_idle_state_processing(delta: float) -> void:
	if not is_instance_valid(navigation_agent_2d):
		return
		
	_idle_timer -= delta
	if _idle_timer <= 0.0 or global_position.distance_to(_idle_goal) < 8.0:
		_idle_timer = idle_retarget_time
		
		var angle := randf() * TAU
		var dir := Vector2.from_angle(angle)
		var dist := randf_range(idle_wander_radius * 0.2, idle_wander_radius)
		_idle_goal = global_position + dir * dist
		
		navigation_agent_2d.target_position = _idle_goal

	_steer_along_nav(move_speed, delta)

func _on_idle_state_entered() -> void:
	_idle_timer = 0.0
	_idle_goal = global_position

func _on_fight_state_physics_processing(_delta: float) -> void:
	if not is_target_valid():
		state_chart.send_event("target_lost")
		return

	if distance_to_target() > max(attack_range, keep_distance):
		state_chart.send_event("re_approach")
		return

	var dir := (target.global_position - global_position).normalized()
	sprite.rotation = dir.angle()

func _on_fight_state_entered() -> void:
	if not is_target_valid():
		state_chart.send_event("target_lost")
		return
	
	# Use basic attack ability if available
	if ability_system:
		ability_system.use_basic_attack(target_entity)

func _on_fight_state_exited() -> void:
	pass

func _on_dead_state_entered() -> void:
	queue_free()
