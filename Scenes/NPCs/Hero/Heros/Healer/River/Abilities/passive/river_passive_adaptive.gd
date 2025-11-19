extends AbilityBase
class_name RiverPassiveAdaptive

@export var speed_boost_multiplier: float = 1.5
@export var boost_duration: float = 3.0

var is_boosted: bool = false
var boost_timer: float = 0.0
var last_health: float = 0.0

func _init() -> void:
	ability_name = "Adaptive Movement"
	ability_type = AbilityType.PASSIVE
	description = "After taking damage, gain 50% movement speed for 3 seconds"

func on_passive_update(caster: Node2D, delta: float) -> void:
	if not caster.has_method("get_health"):
		return
	
	var current_health = caster.get_health()
	
	# Detect damage taken
	if last_health > 0.0 and current_health < last_health:
		_activate_boost()
	
	last_health = current_health
	
	# Update boost timer
	if is_boosted:
		boost_timer -= delta
		if boost_timer <= 0.0:
			is_boosted = false

func _activate_boost() -> void:
	is_boosted = true
	boost_timer = boost_duration

func get_attack_speed_multiplier(_caster: Node2D) -> float:
	return speed_boost_multiplier if is_boosted else 1.0

# Used by hero stats to get movement speed bonus
func get_speed_multiplier() -> float:
	return speed_boost_multiplier if is_boosted else 1.0
