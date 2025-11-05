# ============================================
# MOB BASE CLASS (Simple Enemies)
# Save as: res://characters/base/mob_base_class.gd
#
# For simple trash mob enemies with:
# - Simple stats (no complex stat system)
# - Basic attack only (no abilities)
# - Fast to create and lightweight
# ============================================
extends EntityBase
class_name MobBase

# Simple exported stats (just set in Inspector)
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

var current_health: float
var attack_timer: float = 0.0

func _ready() -> void:
	current_health = max_health
	super._ready()

func _process(delta: float) -> void:
	# Update attack cooldown
	if attack_timer > 0.0:
		attack_timer -= delta

# ============================================
# Override EntityBase virtual methods
# ============================================

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

# ============================================
# Implement EntityBase abstract methods
# ============================================

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

# ============================================
# Simple combat (no ability system needed)
# ============================================

func _on_fight_logic(delta: float) -> void:
	# Simple attack on cooldown
	if attack_timer <= 0.0 and is_target_valid():
		_perform_basic_attack()
		attack_timer = attack_cooldown

func _perform_basic_attack() -> void:
	if not target_entity or not target_entity.has_method("take_damage"):
		return
	
	var distance = global_position.distance_to(target_entity.global_position)
	if distance <= base_attack_range:
		target_entity.take_damage(base_attack_damage)
		print(name + " attacked for " + str(base_attack_damage) + " damage")

# ============================================
# Optional: Override for death effects
# ============================================

func _on_dead_state_entered() -> void:
	# Optional: Add death animation, drop loot, etc.
	_on_mob_death()
	super._on_dead_state_entered()  # Calls queue_free()

# Override this in specific mobs for custom death behavior
func _on_mob_death() -> void:
	pass
