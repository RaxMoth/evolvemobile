extends AbilityBase
class_name IreliaPassiveRegeneration

func on_passive_update(caster: Node2D, delta: float) -> void:
	var hero := caster as HeroBase
	if not hero:
		return
	var current_health: float = hero.get_health()
	if current_health < hero.get_max_health() and current_health > 0.0:
		hero.heal(heal_amount * delta)
