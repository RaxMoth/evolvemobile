extends Node2D
class_name NPCBaseClass

@export var move_speed: float = 80.0
@export var approach_speed: float = 110.0
@export var attack_range: float = 32.0
@export var attack_damage: float = 3.0
@export var max_health: float = 10.0
@export var idle_retarget_time: float = 1.2
@export var idle_wander_radius: float = 160.0
@export var keep_distance: float = 24.0
@export var attack_interval: float = 0.8

@onready var collision_shape_2d: CollisionShape2D = $DetectionArea/CollisionShape2D
@onready var attack_timer: Timer = %AttackTimer
@onready var sprite: Node2D = $Sprite2D
@onready var state_chart: StateChart = %StateChart
@onready var navigation_agent_2d: NavigationAgent2D = %NavigationAgent2D

var _idle_timer := 0.0
var _idle_goal := Vector2.ZERO
var health: float
var target: Node2D = null

func _ready() -> void:
	health = max_health
	var tilemap_layer := get_parent().get_node("Ground")
	if tilemap_layer:
		print("connected")
		var nav_map = tilemap_layer.get_navigation_map()
		navigation_agent_2d.set_navigation_map(nav_map)
	
func is_alive() -> bool:
	return health > 0.0

func get_health() -> float:
	return health

func is_target_valid() -> bool:
	return is_instance_valid(target)

func distance_to_target() -> float:
	if not is_target_valid():
		return INF
	return global_position.distance_to(target.global_position)
	
func _steer_along_nav(speed: float, delta: float) -> void:
	if navigation_agent_2d.is_navigation_finished():
		return
	var next_pos := navigation_agent_2d.get_next_path_position()
	var dir := next_pos - global_position
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	global_position += dir * speed * delta
	sprite.rotation = dir.angle()
	
func move_toward_point(p: Vector2, speed: float, delta: float) -> void:
	var dir := (p - global_position)
	if dir.length() <= 0.001:
		return
	dir = dir.normalized()
	global_position += dir * speed * delta
	sprite.rotation = dir.angle()

func take_damage(amount: float) -> void:
	if not is_alive():
		return 

	health -= amount
	if health <= 0.0:
		health = 0.0
		attack_timer.stop()
		state_chart.send_event("self_dead")
	else:
		print(amount, " aua ")


func _on_detection_area_area_exited(area: Area2D) -> void:
	state_chart.send_event("enemie_exited")
	if target == area:
		target = null
		
func _on_detection_area_area_entered(area: Area2D) -> void:
	if area.get_owner() == self or area.get_parent() == self:
		return

	var root := area.get_owner()
	if root and root.is_in_group("Enemy"):
		target = area
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
	_idle_timer -= delta
	if _idle_timer <= 0.0 or global_position.distance_to(_idle_goal) < 8.0:
		_idle_timer = idle_retarget_time
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		if dir == Vector2.ZERO: dir = Vector2.RIGHT
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
	attack_timer.wait_time = attack_interval
	attack_timer.start()                     

func _on_fight_state_exited() -> void:
	attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	if is_target_valid() and distance_to_target() <= max(attack_range, keep_distance):
		var p := target.get_parent()
		if p and p.has_method("take_damage"):
			var alive :bool = false

			if p.has_method("is_alive"):
				alive = p.is_alive()
			elif p.has_method("get_health"):
				var gh = p.get_health()
				if typeof(gh) == TYPE_FLOAT:
					alive = gh > 0.0
				else:
					alive = bool(gh)

			if alive:
				p.take_damage(attack_damage)
			else:
				state_chart.send_event("target_lost")
 

	


func _on_dead_state_entered() -> void:
	queue_free()
