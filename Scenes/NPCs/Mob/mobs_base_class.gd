# ============================================
# MOB BASE CLASS (Simple Enemies)
# Save as: res://characters/base/mob_base_class.gd
#
# For simple trash mob enemies with:
# - Simple stats (no complex stat system)
# - Basic attack only (no abilities)
# - Fast to create and lightweight
# - Spawn area support for roaming boundaries
# ============================================
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
var attacking: bool = false

# Spawn area reference (set by MonsterSpawnArea)
var spawn_area: Node = null
var spawn_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	current_health = max_health
	attack_timer.wait_time = attack_cooldown
	# Update health bar if it exists
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	super._ready()

func _process(_delta: float) -> void:
	# Check if mob has wandered too far from spawn area
	if spawn_area and spawn_area.has_method("is_position_in_area"):
		if not spawn_area.is_position_in_area(global_position):
			_handle_out_of_bounds()

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
	
	# Update health bar
	if health_bar:
		health_bar.value = current_health
	
	if current_health <= 0.0:
		current_health = 0.0
		state_chart.send_event("self_dead")
	else:
		print(name + " took " + str(amount) + " damage")

# ============================================
# Spawn Area Integration
# ============================================

func _handle_out_of_bounds() -> void:
	# Mob wandered outside spawn area, return to spawn
	if spawn_area and spawn_area.has_method("clamp_position_to_area"):
		global_position = spawn_area.clamp_position_to_area(global_position)
	
	# If too far, reset to spawn position
	if spawn_position != Vector2.ZERO:
		var distance_from_spawn = global_position.distance_to(spawn_position)
		if distance_from_spawn > base_idle_wander_radius * 2:
			_reset_to_spawn()

func _reset_to_spawn() -> void:
	# Teleport back to spawn
	global_position = spawn_position
	
	# Reset combat state
	target = null
	target_entity = null
	attacking = false
	attack_timer.stop()
	
	# Heal to full
	current_health = max_health
	if health_bar:
		health_bar.value = current_health
	
	# Return to idle
	if state_chart:
		state_chart.send_event("enemie_exited")
	
	print(name + " returned to spawn position")

# Override idle to respect spawn area
func _on_idle_state_processing(delta: float) -> void:
	if not is_instance_valid(navigation_agent_2d):
		return
		
	_idle_timer -= delta
	if _idle_timer <= 0.0 or global_position.distance_to(_idle_goal) < 8.0:
		_idle_timer = idle_retarget_time
		
		# Use spawn area if available, otherwise random wander
		if spawn_area and spawn_area.has_method("get_random_roam_position"):
			_idle_goal = spawn_area.get_random_roam_position()
		else:
			# Default random wander (limited by base_idle_wander_radius)
			var angle := randf() * TAU
			var dir := Vector2.from_angle(angle)
			var dist := randf_range(base_idle_wander_radius * 0.2, base_idle_wander_radius)
			_idle_goal = global_position + dir * dist
			
			# Clamp to spawn area if available
			if spawn_area and spawn_area.has_method("clamp_position_to_area"):
				_idle_goal = spawn_area.clamp_position_to_area(_idle_goal)
		
		navigation_agent_2d.target_position = _idle_goal

	_steer_along_nav(move_speed, delta)

# ============================================
# Simple combat (no ability system needed)
# ============================================

func _on_fight_logic(_delta: float) -> void:
	if not attacking:
		attacking = true
		attack_timer.start()

func _perform_basic_attack() -> void:
	if not target_entity or not target_entity.has_method("take_damage"):
		attacking = false
		return
	
	var distance = global_position.distance_to(target_entity.global_position)
	if distance <= base_attack_range:
		target_entity.take_damage(base_attack_damage)
		print(name + " attacked for " + str(base_attack_damage) + " damage")
	
	attacking = false

func _on_attack_timer_timeout() -> void:
	if is_target_valid():
		_perform_basic_attack()

# ============================================
# Optional: Override for death effects
# ============================================

func _on_dead_state_entered() -> void:
	_on_mob_death()
	super._on_dead_state_entered() # Calls queue_free()

# Override this in specific mobs for custom death behavior
func _on_mob_death() -> void:
	pass
