extends CharacterBody2D

signal died

@export var max_health: float = 50.0
@export var move_speed: float = 120.0
@export var attack_damage: float = 9.0
@export var attack_range: float = 60.0
@export var attack_cooldown: float = 1.2

var owner_entity: Node2D = null 
var current_health: float
var current_target: Node2D = null
var attack_timer: float = 0.0

const FOLLOW_DISTANCE: float = 100.0
const SEARCH_RADIUS: float = 400.0

func _ready() -> void:
	current_health = max_health
	
func set_owner_entity(new_owner: Node2D) -> void:
	owner_entity = new_owner
	print("Pet owner set to: " + owner_entity.name)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_entity):
		queue_free()
		return
	
	attack_timer = max(0.0, attack_timer - delta)
	
	# Find or maintain target
	if not is_instance_valid(current_target):
		_find_target()
	
	# Behavior
	if current_target and is_instance_valid(current_target):
		_attack_target(delta)
	else:
		_follow_owner(delta)
	
	move_and_slide()

func _follow_owner(delta: float) -> void:
	var distance = global_position.distance_to(owner_entity.global_position)
	
	if distance > FOLLOW_DISTANCE:
		var direction = (owner_entity.global_position - global_position).normalized()
		velocity = direction * move_speed
	else:
		velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)

func _find_target() -> void:
	var enemies = get_tree().get_nodes_in_group("Enemy")
	var closest_enemy: Node2D = null
	var closest_distance: float = SEARCH_RADIUS
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("is_alive"):
			continue
		
		if not enemy.is_alive():
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy
	
	current_target = closest_enemy

func _attack_target(delta: float) -> void:
	if not is_instance_valid(current_target):
		current_target = null
		return
	
	var distance = global_position.distance_to(current_target.global_position)
	
	if distance > attack_range:
		# Move toward target
		var direction = (current_target.global_position - global_position).normalized()
		velocity = direction * move_speed
	else:
		# Attack
		velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)
		
		if attack_timer <= 0.0:
			_perform_attack()
			attack_timer = attack_cooldown

func _perform_attack() -> void:
	if not is_instance_valid(current_target):
		return
	
	if current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)
		print("Pet attacked for " + str(attack_damage) + " damage!")

func take_damage(amount: float) -> void:
	current_health -= amount
	
	if current_health <= 0.0:
		died.emit()
		queue_free()

func is_alive() -> bool:
	return current_health > 0.0
