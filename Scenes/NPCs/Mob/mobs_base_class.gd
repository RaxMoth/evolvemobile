extends EntityBase
class_name MobBase

@export_group("Mob Stats")
@export var max_health: float = 50.0
@export var base_move_speed: float = 70.0
@export var base_approach_speed: float = 90.0
@export var base_attack_range: float = 40.0
@export var base_attack_damage: float = 5.0
@export var attack_cooldown: float = 1.5

@export_group("Mob Behavior")
@export var base_idle_retarget_time: float = 1.2
@export var base_idle_wander_radius: float = 120.0
@export var base_keep_distance: float = 20.0

@onready var attack_timer: Timer = %AttackTimer
var current_health: float

func _ready() -> void:
	current_health = max_health
	attack_timer.wait_time = attack_cooldown
	super._ready()

func _get_move_speed() -> float:
	return base_move_speed

func _get_approach_speed() -> float:
	return base_approach_speed

func _get_attack_range() -> float:
	return base_attack_range

func _get_idle_retarget_time() -> float:
	return base_idle_retarget_time

func _get_idle_wander_radius() -> float:
	return base_idle_wander_radius

func _get_keep_distance() -> float:
	return base_keep_distance

func is_alive() -> bool:
	return current_health > 0.0

func get_health() -> float:
	return current_health

func take_damage(amount: float) -> void:
	if not is_alive():
		return
	
	current_health -= amount
	
	if current_health <= 0.0:
		current_health = 0.0
		state_chart.send_event("self_dead")
	else:
		print(name + " took " + str(amount) + " damage")


func _on_fight_logic(_delta: float) -> void:
	print("bla")
	attack_timer.start()

func _perform_basic_attack() -> void:
	print("ahaah")
	if not target_entity or not target_entity.has_method("take_damage"):
		return
	
	var distance = global_position.distance_to(target_entity.global_position)
	if distance <= base_attack_range:
		target_entity.take_damage(base_attack_damage)
		print(name + " attacked for " + str(base_attack_damage) + " damage")


func _on_dead_state_entered() -> void:
	_on_mob_death()
	super._on_dead_state_entered()  

func _on_mob_death() -> void:
	pass

func _on_attack_timer_timeout() -> void:
	print("ding sding")
	if is_target_valid():
		_perform_basic_attack()
