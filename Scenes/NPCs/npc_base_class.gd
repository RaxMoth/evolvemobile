extends Node2D
class_name EntityBase

@onready var sprite: Node2D = $Sprite2D
@onready var state_chart: StateChart = %StateChart
@onready var navigation_agent_2d: NavigationAgent2D = %NavigationAgent2D
@onready var health_bar: ProgressBar = %HealthBar

var _idle_timer := 0.0
var _idle_goal := Vector2.ZERO
var target: Node2D = null
var target_entity: Node = null

var move_speed: float:
	get: return _get_move_speed()
var approach_speed: float:
	get: return _get_approach_speed()
var attack_range: float:
	get: return _get_attack_range()
var idle_retarget_time: float:
	get: return _get_idle_retarget_time()
var idle_wander_radius: float:
	get: return _get_idle_wander_radius()
var keep_distance: float:
	get: return _get_keep_distance()

func _get_move_speed() -> float:
	return 80.0

func _get_approach_speed() -> float:
	return 110.0

func _get_attack_range() -> float:
	return 50.0

func _get_idle_retarget_time() -> float:
	return 1.2

func _get_idle_wander_radius() -> float:
	return 160.0

func _get_keep_distance() -> float:
	return 24.0

func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	if health_bar:
		health_bar.max_value = get_health()
		health_bar.value = get_health()
	
	_setup_navigation()

func _setup_navigation() -> void:
	var tilemap_layer := get_parent().get_node_or_null("Ground")
	if not tilemap_layer or not tilemap_layer.has_method("get_navigation_map"):
		return
	
	var nav_map = tilemap_layer.get_navigation_map()
	if not nav_map.is_valid():
		return
	
	navigation_agent_2d.set_navigation_map(nav_map)
	navigation_agent_2d.path_desired_distance = 6.0
	navigation_agent_2d.simplify_path = true
	navigation_agent_2d.target_desired_distance = 4.0
	navigation_agent_2d.avoidance_enabled = false

func is_alive() -> bool:
	push_error("is_alive() not implemented in " + name)
	return false

func take_damage(_amount: float) -> void:
	push_error("take_damage() not implemented in " + name)

func get_health() -> float:
	push_error("get_health() not implemented in " + name)
	return 0.0

func is_target_valid() -> bool:
	return is_instance_valid(target) and is_instance_valid(target_entity)

func distance_to_target() -> float:
	return target.global_position.distance_to(global_position) if is_target_valid() else INF

func _steer_along_nav(speed: float, delta: float) -> void:
	if not is_instance_valid(navigation_agent_2d) or navigation_agent_2d.is_navigation_finished():
		return
	
	var next_pos := navigation_agent_2d.get_next_path_position()
	var dir := (next_pos - global_position).normalized()
	
	if dir.length_squared() < 0.000001:
		return
	
	position += dir * speed * delta
	sprite.rotation = dir.angle()

func move_toward_point(target_pos: Vector2, speed: float, delta: float) -> void:
	var dir := (target_pos - global_position).normalized()
	if dir.length_squared() < 0.000001:
		return
	
	position += dir * speed * delta
	sprite.rotation = dir.angle()

func _on_detection_area_area_exited(area: Area2D) -> void:
	if target == area:
		target = null
		target_entity = null
		state_chart.send_event("enemie_exited")

func _on_detection_area_area_entered(area: Area2D) -> void:
	if area.get_owner() == self or area.get_parent() == self:
		return

	var root := area.get_owner()
	if not root:
		return
	
	var can_target := false
	
	if is_in_group("Enemy") and root.is_in_group("Hero"):
		can_target = true
	elif is_in_group("Hero") and root.is_in_group("Enemy"):
		can_target = true
	
	if can_target:
		target = area
		target_entity = area.get_parent()
		state_chart.send_event("enemie_entered")

func _on_approach_state_processing(delta: float) -> void:
	if not is_target_valid():
		state_chart.send_event("enemie_exited")
		return
	
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
	if _idle_timer <= 0.0 or global_position.distance_squared_to(_idle_goal) < 64.0:
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

func _on_fight_state_processing(delta: float) -> void:
	if not is_target_valid():
		state_chart.send_event("target_lost")
		return

	if distance_to_target() > max(attack_range, keep_distance):
		state_chart.send_event("re_approach")
		return

	var dir := (target.global_position - global_position).normalized()
	sprite.rotation = dir.angle()
	_on_fight_logic(delta)

func _on_fight_logic(_delta: float) -> void:
	pass

func _on_fight_state_entered() -> void:
	if not is_target_valid():
		state_chart.send_event("target_lost")

func _on_dead_state_entered() -> void:
	queue_free()
