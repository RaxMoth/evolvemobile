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


var _idle_timer := 0.0
var _idle_goal := Vector2.ZERO
var health: float
var target: Node2D = null

func _ready() -> void:
	health = max_health
	
func get_health() -> bool:
	return health >= 0.0

func is_target_valid() -> bool:
	return is_instance_valid(target)

func distance_to_target() -> float:
	if not is_target_valid():
		return INF
	return global_position.distance_to(target.global_position)
	

func move_toward_point(p: Vector2, speed: float, delta: float) -> void:
	var dir := (p - global_position)
	if dir.length() <= 0.001:
		return
	dir = dir.normalized()
	global_position += dir * speed * delta
	sprite.rotation = dir.angle()

func take_damage(amount: float) -> void:
	if health <= 0.0:
		attack_timer.stop()
		state_chart.send_event("self_dead")
	else:
		health -= amount
		print(amount, " aua ")


func _on_detection_area_area_exited(area: Area2D) -> void:
	state_chart.send_event("enemie_exited")
	if target == area:
		target = null
		
func _on_detection_area_area_entered(area: Area2D) -> void:
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
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		dir = dir.normalized()
		var dist := randf_range(idle_wander_radius * 0.2, idle_wander_radius)
		_idle_goal = global_position + dir * dist

	move_toward_point(_idle_goal, move_speed, delta)


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
		if target.get_parent().has_method("take_damage"):
			if target.get_parent().has_method("get_health"):
				if target.get_parent().get_health():
					target.get_parent().take_damage(attack_damage)
				else:
					state_chart.send_event("target_lost")
 

func _on_dead_state_entered() -> void:
	print("hier noch überreste einbauen")
