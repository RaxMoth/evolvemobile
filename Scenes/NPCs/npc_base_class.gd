extends Node2D
class_name EntityBase

@export_group("XP System")
@export var xp_value: float = 0.0

@export_group("Combat Behavior")
@export var combat_role: Types.CombatRole = Types.CombatRole.MELEE
@export var preferred_distance: float = 50.0
@export var min_distance: float = 30.0
@export var max_distance: float = 150.0
@export var strafe_enabled: bool = true
@export var strafe_speed: float = 60.0

@onready var sprite: Node2D = $Sprite2D
@onready var state_chart: StateChart = %StateChart
@onready var navigation_agent_2d: NavigationAgent2D = %NavigationAgent2D
@onready var health_bar: ProgressBar = %HealthBar
@onready var detection_area: Area2D = %DetectionArea

var strafe_direction: int = 1
var strafe_timer: float = 0.0
var strafe_change_interval: float = 2.0
var is_on_cooldown: bool = false
var last_attacker: Node2D = null
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

func _check_for_nearby_enemies() -> void:
	if not is_instance_valid(detection_area):
		return
	
	var areas_in_range = detection_area.get_overlapping_areas()
	
	for area in areas_in_range:
		if _can_target_area(area):
			target = area
			target_entity = area.get_parent()
			state_chart.send_event("enemie_entered")
			print(name + " found remaining enemy: " + target_entity.name)

func _can_target_area(area: Area2D) -> bool:
	if area.get_owner() == self or area.get_parent() == self:
		return false
	
	var root := area.get_owner()
	if not root:
		return false

	return GameUtils.can_entity_target(self, root)

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
		
	var can_target := _can_target_area(area)
	
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
		_check_for_nearby_enemies()

func _on_idle_state_processing(delta: float) -> void:
	if not is_instance_valid(navigation_agent_2d):
		return
		
	_idle_timer -= delta
	if _idle_timer <= 0.0 or global_position.distance_squared_to(_idle_goal) < 64.0:
		_idle_timer = idle_retarget_time
		_idle_goal = _get_smart_idle_destination()
		navigation_agent_2d.target_position = _idle_goal

	_steer_along_nav(move_speed, delta)

func _get_smart_idle_destination() -> Vector2:
	"""Get a smart idle destination that:
	1. For heroes: Prefers unexplored areas
	2. For all: Avoids walls and obstacles
	3. Picks the best of multiple samples
	"""
	
	# For heroes: Check if exploration controller has a target
	if is_in_group("Hero"):
		var exploration_target = _get_exploration_target()
		if exploration_target != Vector2.ZERO:
			return exploration_target
	
	# For monsters or heroes without exploration target: Smart random
	return _get_valid_random_destination()

func _get_exploration_target() -> Vector2:
	"""Get target from HeroExplorationController if available"""
	var exploration_controller = get_tree().get_first_node_in_group("HeroExplorationController")
	if not exploration_controller:
		return Vector2.ZERO
	
	# Check if we (as a hero) have a specific exploration target set
	# Use 'in' operator to check if the property exists, then use get() to access it safely
	if "exploration_target" in self:
		var hero_target = get("exploration_target")
		if hero_target is Vector2 and hero_target != Vector2.ZERO:
			return hero_target
	
	# Get the group's current target
	if exploration_controller.has_method("get_current_group_target"):
		return exploration_controller.get_current_group_target()
	
	return Vector2.ZERO

func _get_valid_random_destination() -> Vector2:
	"""Sample multiple random points and pick the best one"""
	var best_point = global_position
	var best_score = - INF
	var samples = 5 # Try 5 random points
	
	for i in range(samples):
		var candidate = _generate_random_point()
		var score = _score_destination(candidate)
		
		if score > best_score:
			best_score = score
			best_point = candidate
	
	return best_point

func _generate_random_point() -> Vector2:
	"""Generate a random point around current position"""
	var angle := randf() * TAU
	var dir := Vector2.from_angle(angle)
	
	# For heroes: larger exploration radius
	var radius = idle_wander_radius
	if is_in_group("Hero"):
		radius *= 1.5 # Heroes explore further
	
	var dist := randf_range(radius * 0.3, radius)
	return global_position + dir * dist

func _score_destination(point: Vector2) -> float:
	var score = 0.0
	if GameUtils.is_point_too_close_to_wall(get_world_2d(), point, 32.0, 1, 8):
		return -1000.0
	
	var current_facing = sprite.rotation if sprite else 0.0
	var to_point = (point - global_position).normalized()
	var point_angle = to_point.angle()
	var angle_diff = abs(GameUtils.angle_difference(current_facing, point_angle))
	score += (PI - angle_diff) * 50.0
	
	if is_in_group("Hero"):
		var fog_system = get_tree().get_first_node_in_group("FogOfWar")
		if GameUtils.is_position_explored(fog_system, point):
			score -= 50.0
		else:
			score += 200.0
	
	var nearby_walls = GameUtils.count_walls_in_radius(get_world_2d(), point, 50.0, 1, 12)
	score -= nearby_walls * 30.0
	
	return score

# ============================================
# HELPER FUNCTION
# ============================================


func _on_idle_state_entered() -> void:
	_idle_timer = 0.0
	_idle_goal = global_position
	_check_for_nearby_enemies()

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
		Types.CombatRole.MELEE:
			_melee_combat_behavior(delta, distance, dir)
		Types.CombatRole.RANGED:
			_ranged_combat_behavior(delta, distance, dir)
		Types.CombatRole.SUPPORT:
			_support_combat_behavior(delta, distance, dir)
	
	# Call child class fight logic
	_on_fight_logic(delta)

# ============================================
# MELEE BEHAVIOR - Close and strafe
# ============================================

func _melee_combat_behavior(delta: float, distance: float, dir: Vector2) -> void:
	# If attack is ready and we're in range, STOP MOVING and attack
	if _is_attack_ready() and distance <= attack_range:
		# Stand still to attack
		return
	
	# Attack on cooldown, reposition based on distance
	if distance > preferred_distance + 10.0:
		# Too far, move closer
		_move_toward_target(approach_speed, delta)
	elif distance < preferred_distance - 10.0:
		# Too close, back up a bit
		_move_away_from_target(move_speed * 0.5, delta)
	else:
		# At ideal distance, strafe while on cooldown
		if strafe_enabled:
			_strafe_around_target(delta, dir)

# ============================================
# RANGED BEHAVIOR - Kite and maintain distance
# ============================================

func _ranged_combat_behavior(delta: float, distance: float, dir: Vector2) -> void:
	# If attack is ready and we're in good range, STOP MOVING and attack
	if _is_attack_ready():
		if distance >= min_distance and distance <= attack_range:
			# Perfect range and attack ready - stand still!
			return
	
	# Attack on cooldown - need to reposition
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
		# At good distance but attack on cooldown, strafe
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
