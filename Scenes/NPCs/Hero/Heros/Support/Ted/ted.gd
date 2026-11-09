extends HeroBase
class_name Ted

## The pets live on this Ted's own copy of the Pet passive (TedPassivePet):
## the ones alive right now, in slot order (Pack of Two keeps two).
func get_pets() -> Array[TedPassivePet.PetScript]:
	var pet_passive: TedPassivePet = (ability_system.passive_ability as TedPassivePet) if ability_system else null
	return pet_passive.living_pets() if pet_passive else ([] as Array[TedPassivePet.PetScript])
