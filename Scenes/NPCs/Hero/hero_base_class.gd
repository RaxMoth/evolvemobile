# ============================================
# HERO BASE CLASS
# Save as: res://characters/base/hero_base_class.gd
#
# For player-controlled or AI heroes with:
# - Full stats system (HeroStatsComponent)
# - 4 abilities (passive, active, basic, ultimate)
# - Level progression
# - Auto-use ultimate option
# ============================================
extends EntityBase
class_name HeroBase

@export var auto_use_ultimate: bool = true

@onready var stats: HeroStatsComponent = %HeroStats
@onready var ability_system: AbilitySystem = %AbilitySystem

func _ready() -> void:
	if not stats or not stats.base_stats:
		push_error(name + " requires HeroStatsComponent with base_stats!")
		return
	
	super._ready()

func _process(delta: float) -> void:
	# Update passive ability every frame
	if ability_system and ability_system.passive_ability:
		ability_system.passive_ability.on_passive_update(self, delta)
	
	# Auto-use ultimate when ready
	if auto_use_ultimate and is_ultimate_ready():
		use_ultimate()

# ============================================
# Override stat getters from EntityBase
# ============================================

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

# ============================================
# Implement required EntityBase methods
# ============================================

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
	else:
		print(name + " took " + str(amount) + " damage")

# ============================================
# Combat logic (override from EntityBase)
# ============================================

func _on_fight_logic(_delta: float) -> void:
	# Heroes use ability system for attacks
	if ability_system:
		ability_system.use_basic_attack(target_entity)

# ============================================
# Hero-specific ability methods
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
# Convenience properties (for backward compatibility)
# ============================================

var max_health: float:
	get: return stats.get_max_health() if stats else 100.0

var health: float:
	get: return stats.get_current_health() if stats else 0.0
