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
@export var chase_distance: float = 400.0

@onready var attack_timer: Timer = %AttackTimer

var current_health: float
var attacking: bool = false
var spawn_area: Node = null
var spawn_position: Vector2 = Vector2.ZERO

# ============================================
# STATE TRACKING - Instead of get_active_state()
# ============================================
var is_in_combat: bool = false  # Track if in Approach or Fight state

func _ready() -> void:
	_setup_mob_combat_role()
	current_health = max_health
	attack_timer.wait_time = attack_cooldown
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	super._ready()

# ============================================
# STATE TRACKING - Set flags when entering states
# ============================================

func _on_idle_state_entered() -> void:
	is_in_combat = false
	super._on_idle_state_entered()

func _on_approach_state_entered() -> void:
	is_in_combat = true
	super._on_approach_state_entered()

func _on_fight_state_entered() -> void:
	is_in_combat = true
	super._on_fight_state_entered()

func _on_dead_state_entered() -> void:
	is_in_combat = false
	_on_mob_death()
	super._on_dead_state_entered()

# ============================================
# FIXED: Only enforce boundaries when NOT in combat
# ============================================

func _process(_delta: float) -> void:
	# Only check boundaries if we're NOT in combat
	if not is_in_combat:
		if spawn_area and spawn_area.has_method("is_position_in_area"):
			if not spawn_area.is_position_in_area(global_position):
				_handle_out_of_bounds()

func _handle_out_of_bounds() -> void:
	# Clamp to spawn area during idle wandering
	if spawn_area and spawn_area.has_method("clamp_position_to_area"):
		global_position = spawn_area.clamp_position_to_area(global_position)
	
	# Check if too far from spawn (even during combat)
	if spawn_position != Vector2.ZERO:
		var distance_from_spawn = global_position.distance_to(spawn_position)
		
		# If beyond chase distance, force reset
		if distance_from_spawn > chase_distance:
			_reset_to_spawn()

func _reset_to_spawn() -> void:
	print(name + " leashed back to spawn (too far from home)")
	
	global_position = spawn_position
	target = null
	target_entity = null
	attacking = false
	attack_timer.stop()
	is_in_combat = false
	
	# Heal to full on reset
	current_health = max_health
	if health_bar:
		health_bar.value = current_health
	
	# Return to idle
	if state_chart:
		state_chart.send_event("enemie_exited")

# ============================================
# Combat Role
# ============================================

func _setup_mob_combat_role() -> void:
	combat_role = Types.CombatRole.MELEE
	preferred_distance = base_attack_range * 0.8
	min_distance = 20.0
	max_distance = base_attack_range * 1.5
	strafe_enabled = true
	strafe_speed = 40.0
	strafe_change_interval = 3.0

func _is_attack_ready() -> bool:
	return not attacking

# ============================================
# EntityBase Overrides
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

func is_alive() -> bool:
	return current_health > 0.0

func get_health() -> float:
	return current_health

func take_damage(amount: float, attacker: Node2D = null) -> void:
	if not is_alive():
		return
	
	last_attacker = attacker
	current_health = max(0.0, current_health - amount)
	
	if health_bar:
		health_bar.value = current_health
	
	if current_health <= 0.0:
		state_chart.send_event("self_dead")

# ============================================
# Idle Wandering (Restricted to Spawn Area)
# ============================================

func _on_idle_state_processing(delta: float) -> void:
	if not is_instance_valid(navigation_agent_2d):
		return
		
	_idle_timer -= delta
	if _idle_timer <= 0.0 or global_position.distance_squared_to(_idle_goal) < 64.0:
		_idle_timer = idle_retarget_time
		
		# Get random position within spawn area
		if spawn_area and spawn_area.has_method("get_random_roam_position"):
			_idle_goal = spawn_area.get_random_roam_position()
		else:
			var angle := randf() * TAU
			var dir := Vector2.from_angle(angle)
			var dist := randf_range(base_idle_wander_radius * 0.2, base_idle_wander_radius)
			_idle_goal = global_position + dir * dist
			
			# Clamp to spawn area
			if spawn_area and spawn_area.has_method("clamp_position_to_area"):
				_idle_goal = spawn_area.clamp_position_to_area(_idle_goal)
		
		navigation_agent_2d.target_position = _idle_goal

	_steer_along_nav(move_speed, delta)

# ============================================
# Combat
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
	
	attacking = false

func _on_attack_timer_timeout() -> void:
	if is_target_valid():
		_perform_basic_attack()

# ============================================
# Death
# ============================================

func _on_mob_death() -> void:
	queue_free()
