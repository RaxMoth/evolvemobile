extends EntityBase
class_name HeroBase

@export var auto_use_ultimate: bool = true

@onready var stats: HeroStatsComponent = %HeroStats
@onready var ability_system: AbilitySystem = %AbilitySystem

var max_health: float:
	get: return stats.get_max_health() if stats else 100.0

var health: float:
	get: return stats.get_current_health() if stats else 0.0

func _ready() -> void:
	if not stats or not stats.base_stats:
		push_error(name + " requires HeroStatsComponent with base_stats!")
		return
	
	if stats:
		stats.health_changed.connect(_on_health_changed)
	_setup_combat_role_from_stats()
	super._ready()

func _process(_delta: float) -> void:
	if auto_use_ultimate and is_ultimate_ready():
		use_ultimate()
# Add to HeroBase class
var exploration_target: Vector2 = Vector2.ZERO
var use_exploration_target: bool = false
var exploration_target_smooth: Vector2 = Vector2.ZERO # Smoothed target
var target_smooth_speed: float = 5.0 # How fast to smooth

func set_exploration_target(target: Vector2) -> void:
	exploration_target = target
	use_exploration_target = true

func _setup_combat_role_from_stats() -> void:
	if not stats or not stats.base_stats:
		return
	
	# Read from HeroStats resource
	combat_role = stats.base_stats.combat_role
	preferred_distance = stats.base_stats.preferred_distance
	min_distance = stats.base_stats.min_distance
	max_distance = stats.base_stats.max_distance
	strafe_enabled = stats.base_stats.strafe_enabled
	strafe_speed = stats.base_stats.strafe_speed
	strafe_change_interval = stats.base_stats.strafe_change_interval


func _is_attack_ready() -> bool:
	if not ability_system:
		return true
	
	# Check if basic attack is off cooldown
	var basic_cooldown = ability_system.cooldowns.get(AbilityBase.AbilityType.BASIC_ATTACK, 0.0)
	return basic_cooldown <= 0.0

func _on_idle_state_processing(delta: float) -> void:
	if not is_instance_valid(navigation_agent_2d):
		return
	
	# Check if we should use exploration target
	if use_exploration_target:
		# Smooth the target for fluid movement
		exploration_target_smooth = exploration_target_smooth.lerp(exploration_target, target_smooth_speed * delta)
		
		# Check if close enough to target
		if global_position.distance_to(exploration_target) < 80.0:
			# Reached target, wait for new one
			use_exploration_target = false
		else:
			navigation_agent_2d.target_position = exploration_target_smooth
			_steer_along_nav(move_speed * 0.8, delta) # Slightly slower for more control
			return
	
	# Fallback to original idle behavior
	_idle_timer -= delta
	if _idle_timer <= 0.0 or global_position.distance_squared_to(_idle_goal) < 64.0:
		_idle_timer = idle_retarget_time
		
		var angle := randf() * TAU
		var dir := Vector2.from_angle(angle)
		var dist := randf_range(idle_wander_radius * 0.2, idle_wander_radius)
		_idle_goal = global_position + dir * dist
		
		navigation_agent_2d.target_position = _idle_goal

	_steer_along_nav(move_speed, delta)
	
func _get_move_speed() -> float:
	return stats.get_move_speed() if stats else 80.0

func _get_approach_speed() -> float:
	return stats.get_approach_speed() if stats else 110.0

func _get_attack_range() -> float:
	return stats.get_attack_range() if stats else 50.0

func _get_idle_retarget_time() -> float:
	return stats.base_stats.idle_retarget_time if stats and stats.base_stats else 1.2

func _get_idle_wander_radius() -> float:
	return stats.base_stats.idle_wander_radius if stats and stats.base_stats else 160.0

func _get_keep_distance() -> float:
	return stats.base_stats.keep_distance if stats and stats.base_stats else 24.0

func is_alive() -> bool:
	return stats.is_alive() if stats else false

func get_health() -> float:
	return stats.get_current_health() if stats else 0.0

func take_damage(amount: float) -> void:
	if not is_alive() or not stats:
		return
	
	stats.take_damage(amount)
	
	if not stats.is_alive():
		state_chart.send_event("self_dead")

func _on_health_changed(current: float, max_hp: float) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current

func _on_fight_logic(_delta: float) -> void:
	if ability_system:
		ability_system.use_basic_attack(target_entity)

func use_active_ability() -> bool:
	if not ability_system:
		return false
	return ability_system.use_active(target_entity)

func use_ultimate() -> bool:
	if not ability_system or ability_system.is_on_cooldown(AbilityBase.AbilityType.ULTIMATE):
		return false
	return ability_system.use_ultimate(target_entity)

func is_active_ready() -> bool:
	return ability_system and not ability_system.is_on_cooldown(AbilityBase.AbilityType.ACTIVE)

func is_ultimate_ready() -> bool:
	return ability_system and not ability_system.is_on_cooldown(AbilityBase.AbilityType.ULTIMATE)

func get_active_cooldown() -> float:
	return ability_system.get_cooldown_remaining(AbilityBase.AbilityType.ACTIVE) if ability_system else 0.0

func get_ultimate_cooldown() -> float:
	return ability_system.get_cooldown_remaining(AbilityBase.AbilityType.ULTIMATE) if ability_system else 0.0
