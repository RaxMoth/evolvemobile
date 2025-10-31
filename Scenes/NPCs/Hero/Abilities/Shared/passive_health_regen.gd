extends AbilityBase
class_name PassiveHealthRegen

func _init() -> void:
	ability_name = "Health Regeneration"
	ability_type = AbilityType.PASSIVE
	heal_amount = 0.5  

func on_passive_update(caster: Node2D, delta: float) -> void:
	if caster.has_method("get_health") and caster.has_method("take_damage"):
		var current_health = caster.get_health()
		var max_health = caster.max_health if "max_health" in caster else 100.0
		
		if current_health < max_health:
			caster.health = min(current_health + heal_amount * delta, max_health)
