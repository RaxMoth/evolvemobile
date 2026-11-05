extends HeroBase
class_name Ted

## The pet lives on this Ted's own copy of the Pet passive (TedPassivePet).
func get_pet() -> Node2D:
	var pet_passive: TedPassivePet = (ability_system.passive_ability as TedPassivePet) if ability_system else null
	return pet_passive.pet_instance if pet_passive else null
