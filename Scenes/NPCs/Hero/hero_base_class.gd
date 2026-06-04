extends EntityBase
class_name HeroBase

@export_group("Ultimate Auto-Cast")
@export var auto_use_ultimate: bool = true
## Don't auto-fire the ult unless at least this many enemies are within
## auto_ult_radius. Prevents Vlad from nuking a single bat with Blood Bomb.
@export var auto_ult_min_enemies: int = 3
@export var auto_ult_radius: float = 200.0
## OR: auto-fire if any ally is below this HP fraction (panic ult).
@export var auto_ult_panic_hp_pct: float = 0.25
## How often to evaluate the auto-ult conditions. 4 Hz is plenty.
@export var auto_ult_check_interval: float = 0.25

@onready var stats: HeroStatsComponent = %HeroStats
@onready var ability_system: AbilitySystem = %AbilitySystem

var max_health: float:
	get: return stats.get_max_health() if stats else 100.0

var health: float:
	get: return stats.get_current_health() if stats else 0.0

var _auto_ult_timer: float = 0.0

func _ready() -> void:
	if not stats or not stats.base_stats:
		push_error(name + " requires HeroStatsComponent with base_stats!")
		return

	if stats:
		stats.health_changed.connect(_on_health_changed)
	_setup_combat_role_from_stats()

	# Apply permanent meta-skill upgrades to this hero's stats BEFORE
	# super._ready() so the EntityBase HUD setup reads the post-bonus
	# max_health for the floating HP bar.
	MetaSkillManager.apply_unlocked_to_hero(self)

	super._ready()

func _process(delta: float) -> void:
	if not auto_use_ultimate:
		return
	# Throttle the ult-check; condition evaluation walks groups.
	_auto_ult_timer -= delta
	if _auto_ult_timer > 0.0:
		return
	_auto_ult_timer = auto_ult_check_interval
	if is_ultimate_ready() and _should_auto_use_ultimate():
		use_ultimate()

func _should_auto_use_ultimate() -> bool:
	"""Smarter ult auto-cast: fire when worth it, not just because it's ready.
	Subclasses (River, Ted) can override for healer/support semantics."""
	# Panic case: any ally critically low → fire even on a single enemy.
	var team := TeamRegistry.get_team(TeamRegistry.HEROES)
	if team and team.find_lowest_hp_ally(auto_ult_panic_hp_pct, self) != null:
		return true
	# Otherwise: need enough enemies clustered to be worth the cooldown.
	if not is_target_valid():
		return false
	var nearby_enemies := 0
	var r_sq := auto_ult_radius * auto_ult_radius
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		if target_entity.global_position.distance_squared_to(enemy.global_position) <= r_sq:
			nearby_enemies += 1
			if nearby_enemies >= auto_ult_min_enemies:
				return true
	return false
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

func _get_entity_level() -> int:
	if stats:
		return stats.level
	return 1

func _on_level_changed(new_level: int) -> void:
	if lv_label:
		lv_label.text = str(new_level)

func _get_move_speed() -> float:
	return stats.get_move_speed() if stats else 80.0

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

func _receive_damage(packet: DamagePacket) -> void:
	if not is_alive() or not stats:
		return

	last_attacker = packet.source if packet.source is Node2D else null
	stats.take_damage(packet.amount)

	if not stats.is_alive():
		state_chart.send_event(CombatEvents.SELF_DEAD)

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
		
	if not is_target_valid():
		return false
	return ability_system.use_active(target_entity)

func use_ultimate() -> bool:
	if not ability_system or ability_system.is_on_cooldown(AbilityBase.AbilityType.ULTIMATE):
		return false
		
	if not is_target_valid():
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
