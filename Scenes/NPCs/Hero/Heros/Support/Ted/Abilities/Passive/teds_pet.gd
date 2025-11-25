extends CharacterBody2D
class_name TedsPet

signal pet_died

@export var max_health: float = 50.0
@export var move_speed: float = 120.0
@export var attack_damage: float = 8.0
@export var attack_range: float = 60.0
@export var attack_cooldown: float = 1.0

var current_health: float
var owner_entity: Node2D = null  # FIXED: Renamed from 'owner'
var target: Node2D = null
var attack_timer: float = 0.0
var attack_speed_multiplier: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func _process(delta: float) -> void:
	if attack_timer > 0:
		attack_timer -= delta * attack_speed_multiplier

func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	
	# Find target if we don't have one
	if not is_instance_valid(target) or not target.has_method("is_alive") or not target.is_alive():
		target = _find_nearest_enemy()
	
	if target:
		_move_and_attack(delta)
	else:
		_follow_owner(delta)

func _find_nearest_enemy() -> Node2D:
	if not owner_entity:
		return null
	
	var enemies = get_tree().get_nodes_in_group("Enemy")
	var nearest: Node2D = null
	var nearest_dist := INF
	
	for enemy in enemies:
		if enemy.is_in_group("Hero"):  # Don't attack heroes
			continue
		
		if not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist and dist < 400.0:  # Search radius
			nearest_dist = dist
			nearest = enemy
	
	return nearest

func _move_and_attack(delta: float) -> void:
	if not is_instance_valid(target):
		return
	
	var distance = global_position.distance_to(target.global_position)
	
	if distance <= attack_range:
		# In range, attack
		if attack_timer <= 0:
			_perform_attack()
			attack_timer = attack_cooldown
		
		# Face target
		var dir: Vector2 = (target.global_position - global_position).normalized()
		sprite.rotation = dir.angle()
	else:
		# Move toward target
		var dir: Vector2 = (target.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		sprite.rotation = dir.angle()

func _follow_owner(delta: float) -> void:
	if not is_instance_valid(owner_entity):
		return
	
	var distance = global_position.distance_to(owner_entity.global_position)
	
	if distance > 100.0:  # Stay within 100 units of Ted
		var dir: Vector2 = (owner_entity.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		sprite.rotation = dir.angle()
	else:
		velocity = Vector2.ZERO

func _perform_attack() -> void:
	if not target or not target.has_method("take_damage"):
		return
	
	target.take_damage(attack_damage)
	
	# Visual effect
	_create_attack_effect()

func _create_attack_effect() -> void:
	if not is_instance_valid(target):
		return
	
	var line = Line2D.new()
	get_parent().add_child(line)
	line.add_point(global_position)
	line.add_point(target.global_position)
	line.default_color = Color(0.8, 0.6, 0.2)  # Orange-brown
	line.width = 2.0
	line.z_index = 10
	
	var tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)

func set_attack_speed_boost(multiplier: float) -> void:
	attack_speed_multiplier = multiplier

func take_damage(amount: float) -> void:
	if not is_alive():
		return
	
	current_health = max(0.0, current_health - amount)
	
	if health_bar:
		health_bar.value = current_health
	
	if current_health <= 0.0:
		_die()

func is_alive() -> bool:
	return current_health > 0.0

func _die() -> void:
	pet_died.emit()
	
	# Visual death effect
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
