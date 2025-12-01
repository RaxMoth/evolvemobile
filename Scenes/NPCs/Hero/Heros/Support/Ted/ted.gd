extends HeroBase
class_name Ted

var attack_speed_boost: float = 1.0
var boost_timer: float = 0.0

func _ready() -> void:
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)
	
	if boost_timer > 0:
		boost_timer -= delta
		if boost_timer <= 0:
			attack_speed_boost = 1.0

func get_attack_speed_boost() -> float:
	return attack_speed_boost

func apply_attack_speed_boost(multiplier: float, duration: float) -> void:
	attack_speed_boost = multiplier
	boost_timer = duration
	if ability_system:
		pass

func _on_fight_logic(delta: float) -> void:
	if not ability_system:
		return
	ability_system.use_basic_attack(target_entity)

func _get_keep_distance() -> float:
	return 50.0

func get_pet() -> Node2D:
	if ability_system and ability_system.passive_ability:
		if "pet_instance" in ability_system.passive_ability:
			return ability_system.passive_ability.pet_instance
	return null

func has_active_pet() -> bool:
	var pet = get_pet()
	return is_instance_valid(pet) and pet.has_method("is_alive") and pet.is_alive()
