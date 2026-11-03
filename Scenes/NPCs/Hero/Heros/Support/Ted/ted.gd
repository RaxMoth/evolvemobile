extends HeroBase
class_name Ted

func get_pet() -> Node2D:
	if ability_system and ability_system.passive_ability:
		if "pet_instance" in ability_system.passive_ability:
			return ability_system.passive_ability.pet_instance
	return null
