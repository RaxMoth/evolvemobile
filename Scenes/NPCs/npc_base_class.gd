extends Node2D
class_name EntityBase

@export_group("XP System")

@export var xp_value: float = 0.0
var last_attacker: Node2D = null


@onready var sprite: Node2D = $Sprite2D
@onready var state_chart: StateChart = %StateChart
@onready var navigation_agent_2d: NavigationAgent2D = %NavigationAgent2D
@onready var health_bar: ProgressBar = %HealthBar

@export_group("Combat Behavior")
@export var combat_role: Globals.CombatRole = Globals.CombatRole.MELEE
@export var preferred_distance: float = 50.0
@export var min_distance: float = 30.0
@export var max_distance: float = 150.0
@export var strafe_enabled: bool = true
@export var strafe_speed: float = 60.0

var strafe_direction: int = 1
var strafe_timer: float = 0.0
var strafe_change_interval: float = 2.0
var is_on_cooldown: bool = false


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

func _is_attack_ready() -> bool:
	return not is_on_cooldown

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
	
	# TARGETING RULES:
	# - Monsters can target: Heroes AND Mobs
	# - Mobs can target: Heroes AND Monsters (defend themselves!)
	# - Heroes can target: Mobs AND Monsters
	# - Nobody targets their own type (no Mob-on-Mob, no Monster-on-Monster)
	

	var can_target := false
	
	if is_in_group("Monster"):
		# Monsters attack both Heroes and Mobs (but not other Monsters)
		if root.is_in_group("Hero"):
			can_target = true
		elif root.is_in_group("Enemy") and not root.is_in_group("Monster"):
			can_target = true
	
	elif is_in_group("Enemy"):
		# Mobs attack Heroes AND Monsters (but not other Mobs)
		if root.is_in_group("Hero"):
			can_target = true
		elif root.is_in_group("Monster"):
			can_target = true # Defend against Monsters!
	
	elif is_in_group("Hero"):
		# Heroes attack all enemies (Mobs and Monsters)
		if root.is_in_group("Enemy"):
			can_target = true
	
	if can_target:
		target = area
		target_entity = area.get_parent()
		state_chart.send_event("enemie_entered")

func _on_approach_state_processing(delta: float) -> void:
	# CRITICAL: Check if target is still valid before accessing it
	if not is_target_valid():
		state_chart.send_event("enemie_exited")
		return
	
	if distance_to_target() <= max(attack_range, keep_distance):
		state_chart.send_event("enemy_fight")
		return
	
	# FIXED: Use navigation system instead of direct movement
	if is_instance_valid(navigation_agent_2d):
		navigation_agent_2d.target_position = target.global_position
		_steer_along_nav(approach_speed, delta)
	else:
		# Fallback if navigation fails
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
	
	var distance = distance_to_target()
	
	# Check if too far
	if distance > max_distance:
		state_chart.send_event("re_approach")
		return
	
	# Point toward target
	var dir := (target.global_position - global_position).normalized()
	sprite.rotation = dir.angle()
	
	# Execute combat behavior based on role
	match combat_role:
		Globals.CombatRole.MELEE:
			_melee_combat_behavior(delta, distance, dir)
		Globals.CombatRole.RANGED:
			_ranged_combat_behavior(delta, distance, dir)
		Globals.CombatRole.SUPPORT:
			_support_combat_behavior(delta, distance, dir)
	
	# Call child class fight logic
	_on_fight_logic(delta)

# ============================================
# MELEE BEHAVIOR - Close and strafe
# ============================================

func _melee_combat_behavior(delta: float, distance: float, dir: Vector2) -> void:
	if distance > preferred_distance + 10.0:
		# Too far, move closer
		_move_toward_target(approach_speed, delta)
	elif distance < preferred_distance - 10.0:
		# Too close, back up a bit
		_move_away_from_target(move_speed * 0.5, delta)
	else:
		# At ideal distance, strafe if on cooldown
		if strafe_enabled and not _is_attack_ready():
			_strafe_around_target(delta, dir)

# ============================================
# RANGED BEHAVIOR - Kite and maintain distance
# ============================================

func _ranged_combat_behavior(delta: float, distance: float, dir: Vector2) -> void:
	# KITING: If enemy too close, back away!
	if distance < min_distance:
		_kite_away_from_target(approach_speed, delta)
	elif distance < preferred_distance - 20.0:
		# Still too close, maintain distance
		_kite_away_from_target(move_speed, delta)
	elif distance > preferred_distance + 30.0:
		# Too far, move closer
		_move_toward_target(move_speed * 0.7, delta)
	else:
		# At good distance, strafe
		if strafe_enabled:
			_strafe_around_target(delta, dir)

# ============================================
# SUPPORT BEHAVIOR - Default to ranged
# ============================================

func _support_combat_behavior(delta: float, distance: float, dir: Vector2) -> void:
	_ranged_combat_behavior(delta, distance, dir)

# ============================================
# MOVEMENT FUNCTIONS
# ============================================

func _move_toward_target(speed: float, delta: float) -> void:
	if not is_target_valid():
		return
	navigation_agent_2d.target_position = target.global_position
	_steer_along_nav(speed, delta)

func _move_away_from_target(speed: float, delta: float) -> void:
	if not is_target_valid():
		return
	var away_dir = (global_position - target.global_position).normalized()
	var away_point = global_position + away_dir * 100.0
	navigation_agent_2d.target_position = away_point
	_steer_along_nav(speed, delta)

func _kite_away_from_target(speed: float, delta: float) -> void:
	if not is_target_valid():
		return
	var away_dir = (global_position - target.global_position).normalized()
	var perpendicular = Vector2(-away_dir.y, away_dir.x) * strafe_direction
	var kite_dir = (away_dir + perpendicular * 0.3).normalized()
	var kite_point = global_position + kite_dir * 80.0
	navigation_agent_2d.target_position = kite_point
	_steer_along_nav(speed, delta)

func _strafe_around_target(delta: float, dir: Vector2) -> void:
	if not is_target_valid():
		return
	
	strafe_timer += delta
	if strafe_timer >= strafe_change_interval:
		strafe_timer = 0.0
		if randf() > 0.5:
			strafe_direction *= -1
	
	var perpendicular = Vector2(-dir.y, dir.x) * strafe_direction
	var strafe_point = global_position + perpendicular * strafe_speed * delta
	navigation_agent_2d.target_position = strafe_point
	_steer_along_nav(strafe_speed, delta)

func _on_fight_logic(_delta: float) -> void:
	pass

func _on_fight_state_entered() -> void:
	if not is_target_valid():
		state_chart.send_event("target_lost")

func _on_dead_state_entered() -> void:
	# Grant XP to killer before dying
	_grant_xp_to_killer()
	
	queue_free()

# ============================================
# XP SYSTEM - Grant XP to whoever killed this entity
# ============================================

func _grant_xp_to_killer() -> void:
	# Check if we have a valid target that killed us
	if not is_instance_valid(target_entity):
		return
	
	# Check if killer can gain XP
	if not target_entity.has_method("gain_xp"):
		return
	
	# Grant XP based on this entity's value
	if xp_value > 0:
		target_entity.gain_xp(xp_value)
		print(name + " granted " + str(xp_value) + " XP to " + target_entity.name)
