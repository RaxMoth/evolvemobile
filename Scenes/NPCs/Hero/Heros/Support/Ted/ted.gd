extends HeroBase
class_name Ted

func _ready() -> void:
	super._ready()

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
