extends HeroBase
class_name Ted

var attack_speed_boost: float = 1.0
var boost_timer: float = 0.0

func _ready() -> void:
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)
	
	# Update boost timer
	if boost_timer > 0:
		boost_timer -= delta
		if boost_timer <= 0:
			attack_speed_boost = 1.0

# Expose attack speed boost to abilities and pet
func get_attack_speed_boost() -> float:
	return attack_speed_boost

func apply_attack_speed_boost(multiplier: float, duration: float) -> void:
	attack_speed_boost = multiplier
	boost_timer = duration
	
	# Update ability system's attack speed
	if ability_system:
		# The AbilitySystem already handles attack speed via get_attack_speed_multiplier
		pass

# Override to apply attack speed boost to cooldowns
func _on_fight_logic(delta: float) -> void:
	if not ability_system:
		return
	
	# Attack with boosted speed
	ability_system.use_basic_attack(target_entity)

# Ted stays moderate distance from enemies (not too close, not too far)
func _get_keep_distance() -> float:
	return 50.0

# Get pet reference for special interactions
func get_pet() -> Node2D:
	if ability_system and ability_system.passive_ability:
		if "pet_instance" in ability_system.passive_ability:
			return ability_system.passive_ability.pet_instance
	return null

# Check if pet is alive
func has_active_pet() -> bool:
	var pet = get_pet()
	return is_instance_valid(pet) and pet.has_method("is_alive") and pet.is_alive()
