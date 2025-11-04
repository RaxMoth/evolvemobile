extends Node2D
class_name NPCBaseClass

@export var auto_use_ultimate: bool = true  # Automatically use ultimate when off cooldown

@onready var collision_shape_2d: CollisionShape2D = $DetectionArea/CollisionShape2D
@onready var sprite: Node2D = $Sprite2D
@onready var state_chart: StateChart = %StateChart
@onready var navigation_agent_2d: NavigationAgent2D = %NavigationAgent2D
@onready var ability_system: AbilitySystem = %AbilitySystem
@onready var stats: HeroStatsComponent = %HeroStats

var _idle_timer := 0.0
var _idle_goal := Vector2.ZERO
var target: Node2D = null
var target_entity: Node = null

var move_speed: float:
	get: return stats.get_move_speed() if stats else 80.0

var approach_speed: float:
	get: return stats.get_approach_speed() if stats else 110.0

var attack_range: float:
	get: return stats.get_attack_range() if stats else 50.0

var max_health: float:
	get: return stats.get_max_health() if stats else 20.0

var health: float:
	get: return stats.get_current_health() if stats else 0.0

var idle_retarget_time: float:
	get: return stats.base_stats.idle_retarget_time if stats and stats.base_stats else 1.2

var idle_wander_radius: float:
	get: return stats.base_stats.idle_wander_radius if stats and stats.base_stats else 160.0

var keep_distance: float:
	get: return stats.base_stats.keep_distance if stats and stats.base_stats else 24.0

func _ready() -> void:
	if not stats or not stats.base_stats:
		push_error(name + " requires HeroStatsComponent with base_stats resource!")
		return
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	_setup_navigation()

func _setup_navigation() -> void:
	var tilemap_layer := get_parent().get_node_or_null("Ground")
	if not tilemap_layer:
		push_warning(name + ": Ground tilemap not found")
		return
	
	if not tilemap_layer.has_method("get_navigation_map"):
		push_warning(name + ": Ground tilemap has no navigation")
		return
	
	var nav_map = tilemap_layer.get_navigation_map()
	if not nav_map.is_valid():
		push_warning(name + ": Navigation map is invalid")
		return
	
	navigation_agent_2d.set_navigation_map(nav_map)
	navigation_agent_2d.path_desired_distance = 4.0
	navigation_agent_2d.target_desired_distance = 4.0
	navigation_agent_2d.avoidance_enabled = false
	
	await get_tree().create_timer(0.1).timeout
	print(name + ": Navigation setup complete")

func _process(delta: float) -> void:
	# Update passive ability every frame (always active)
	if ability_system and ability_system.passive_ability:
		ability_system.passive_ability.on_passive_update(self, delta)
	
	# Auto-use ultimate when off cooldown (if enabled)
	if auto_use_ultimate and is_ultimate_ready():
		use_ultimate()

func is_alive() -> bool:
	return stats.is_alive() if stats else false

func get_health() -> float:
	return stats.get_current_health() if stats else 0.0

func is_target_valid() -> bool:
	return is_instance_valid(target) and is_instance_valid(target_entity)

func distance_to_target() -> float:
	if not is_target_valid():
		return INF
	return global_position.distance_to(target.global_position)

func _steer_along_nav(speed: float, delta: float) -> void:
	if not is_instance_valid(navigation_agent_2d) or navigation_agent_2d.is_navigation_finished():
		return
	
	var next_pos := navigation_agent_2d.get_next_path_position()
	var dir := (next_pos - global_position).normalized()
	
	if dir.length() < 0.001:
		return
	
	position += dir * speed * delta
	sprite.rotation = dir.angle()

func move_toward_point(p: Vector2, speed: float, delta: float) -> void:
	var dir := (p - global_position).normalized()
	if dir.length() <= 0.001:
		return
	
	position += dir * speed * delta
	sprite.rotation = dir.angle()

func take_damage(amount: float) -> void:
	if not is_alive() or not stats:
		return 
	
	stats.take_damage(amount)
	
	if not stats.is_alive():
		state_chart.send_event("self_dead")
	else:
		print(name + " took " + str(amount) + " damage")

# ============================================
# ABILITY TRIGGERS (Called externally or automatically)
# ============================================

func use_active_ability() -> bool:
	if not ability_system:
		return false
	
	var success = ability_system.use_active(target_entity)
	if success:
		print(name + " used active ability!")
	return success

func use_ultimate() -> bool:
	if not ability_system:
		return false
	
	if ability_system.is_on_cooldown(AbilityBase.AbilityType.ULTIMATE):
		return false
	
	var success = ability_system.use_ultimate(target_entity)
	if success:
		print(name + " used ULTIMATE!")
	return success

func is_active_ready() -> bool:
	if not ability_system:
		return false
	return not ability_system.is_on_cooldown(AbilityBase.AbilityType.ACTIVE)

func is_ultimate_ready() -> bool:
	if not ability_system:
		return false
	return not ability_system.is_on_cooldown(AbilityBase.AbilityType.ULTIMATE)

func get_active_cooldown() -> float:
	if not ability_system:
		return 0.0
	return ability_system.get_cooldown_remaining(AbilityBase.AbilityType.ACTIVE)

func get_ultimate_cooldown() -> float:
	if not ability_system:
		return 0.0
	return ability_system.get_cooldown_remaining(AbilityBase.AbilityType.ULTIMATE)

# ============================================
# STATE MACHINE CALLBACKS
# ============================================

func _on_detection_area_area_exited(area: Area2D) -> void:
	if target == area:
		target = null
		target_entity = null
		state_chart.send_event("enemie_exited")

func _on_detection_area_area_entered(area: Area2D) -> void:
	if area.get_owner() == self or area.get_parent() == self:
		return

	var root := area.get_owner()
	if root and root.is_in_group("Enemy"):
		target = area
		target_entity = area.get_parent()
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
	if not is_instance_valid(navigation_agent_2d):
		return
		
	_idle_timer -= delta
	if _idle_timer <= 0.0 or global_position.distance_to(_idle_goal) < 8.0:
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

	if distance_to_target() > max(attack_range, keep_distance):
		state_chart.send_event("re_approach")
		return

	var dir := (target.global_position - global_position).normalized()
	sprite.rotation = dir.angle()
	
	if ability_system:
		ability_system.use_basic_attack(target_entity)

func _on_fight_state_entered() -> void:
	if not is_target_valid():
		state_chart.send_event("target_lost")
		return

func _on_fight_state_exited() -> void:
	pass

func _on_dead_state_entered() -> void:
	queue_free()
